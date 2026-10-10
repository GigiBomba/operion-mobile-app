import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'endpoints/auth_endpoints.dart';
import 'token_refresher.dart';

/// Interceptor that attaches an Authorization header to every request and
/// handles 401 responses by attempting a token refresh.
///
/// When a 401 is received on a protected endpoint:
/// 1. The refresh token is exchanged for a new pair via the shared
///    [TokenRefresher] (single-flight across the whole app).
/// 2. The new tokens are persisted.
/// 3. The original request is retried with the new access token.
///
/// Only a definitive rejection of the refresh token (HTTP 400/401/403)
/// triggers [clearTokens] and [onForceLogout]. Transient failures (no
/// network, timeout, 5xx) forward the original error and keep the tokens so a
/// driver in a dead zone is never logged out.
///
/// 401s on public endpoints (login, refresh, forgot-password) are plain auth
/// failures and never enter the refresh/retry flow.
class AuthInterceptor extends QueuedInterceptor {
  final Future<String?> Function() getAccessToken;
  final Future<String?> Function()? getRefreshToken;
  final Future<void> Function(String access, String refresh)? saveTokens;
  final Future<void> Function()? clearTokens;
  final VoidCallback? onForceLogout;

  /// Optional shared [TokenRefresher]. When omitted the interceptor builds
  /// its own; the refresher's mutex is process-wide so every instance still
  /// shares a single in-flight refresh request.
  final TokenRefresher? tokenRefresher;

  TokenRefresher? _defaultRefresher;

  /// Endpoints that never carry an Authorization header and whose 401s must
  /// never trigger the refresh/force-logout machinery.
  static const _publicEndpoints = <String>{
    AuthEndpoints.loginPath,
    AuthEndpoints.refreshPath,
    '/api/v1/auth/forgot-password',
  };

  AuthInterceptor({
    required this.getAccessToken,
    this.getRefreshToken,
    this.saveTokens,
    this.clearTokens,
    this.onForceLogout,
    this.tokenRefresher,
  });

  /// The [TokenRefresher] to use — injected, or lazily created from this
  /// interceptor's callbacks (only reached once both are non-null).
  TokenRefresher get _refresher {
    final injected = tokenRefresher;
    if (injected != null) return injected;
    return _defaultRefresher ??= TokenRefresher(
      getRefreshToken: getRefreshToken!,
      saveTokens: saveTokens!,
    );
  }

  /// Whether [path] is a public endpoint that does not require auth.
  bool _isPublic(String path) {
    // Strip base URL prefix if present (e.g. "https://api.example.com/api/v1/auth/token")
    final normalized = _normalisePath(path);
    return _publicEndpoints.any((e) => normalized.endsWith(e));
  }

  String _normalisePath(String path) {
    try {
      final uri = Uri.parse(path);
      return uri.path;
    } on FormatException {
      return path;
    }
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options.path)) {
      final token = await getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only attempt refresh on 401 and when a refresh-token callback is
    // provided.
    if (err.response?.statusCode != 401 ||
        getRefreshToken == null ||
        saveTokens == null) {
      return handler.next(err);
    }

    // Public endpoints (login, refresh, forgot-password, ...) never enter the
    // refresh/retry flow. A 401 from the login endpoint is a plain auth
    // failure (e.g. wrong password) — not a session to refresh — and must not
    // flash the session-expired screen or loop the login screen.
    final path = _normalisePath(err.requestOptions.path);
    if (_isPublic(path)) {
      return handler.next(err);
    }

    final result = await _refresher.refresh(
      (refreshToken) => _postRefresh(err.requestOptions.baseUrl, refreshToken),
    );

    switch (result.outcome) {
      case TokenRefreshOutcome.success:
        final newAccess = result.accessToken!;

        // Retry the original request with the new token.
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        try {
          final response = await Dio(
            BaseOptions(baseUrl: err.requestOptions.baseUrl),
          ).fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (retryErr) {
          developer.log(
            'AuthInterceptor: retry failed – $retryErr',
            name: 'AuthInterceptor',
          );
          return handler.next(retryErr is DioException ? retryErr : err);
        }

      case TokenRefreshOutcome.rejected:
        // The refresh token itself was rejected — the session is over.
        return _forceLogout(err, handler);

      case TokenRefreshOutcome.transientError:
        // Transient failure during refresh (network, timeout, 5xx): keep the
        // tokens and surface the original error. The driver must not be
        // logged out for a dead zone.
        return handler.next(err);
    }
  }

  Future<Response> _postRefresh(String baseUrl, String refreshToken) {
    final refreshDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {'Content-Type': 'application/json'},
    ));
    return refreshDio.post(
      AuthEndpoints.refreshPath,
      data: {'refresh_token': refreshToken},
    );
  }

  void _forceLogout(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    clearTokens?.call();
    onForceLogout?.call();
    handler.next(err);
  }
}

typedef VoidCallback = void Function();
