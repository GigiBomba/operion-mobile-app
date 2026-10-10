import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// The outcome of a token-refresh attempt.
enum TokenRefreshOutcome {
  /// A new token pair was obtained and persisted.
  success,

  /// The refresh token was definitively rejected (HTTP 400/401/403, or no
  /// refresh token is available). The session is no longer valid and the
  /// caller should force a logout.
  rejected,

  /// The refresh failed for a transient reason (no network, timeout, 5xx,
  /// malformed response). The caller must keep its existing tokens and may
  /// retry later.
  transientError,
}

/// The result of a [TokenRefresher.refresh] attempt.
class TokenRefreshResult {
  /// Whether the refresh succeeded, was definitively rejected, or failed
  /// transiently.
  final TokenRefreshOutcome outcome;

  /// The new access token — non-null only when [outcome] is
  /// [TokenRefreshOutcome.success].
  final String? accessToken;

  /// The new refresh token — non-null only when [outcome] is
  /// [TokenRefreshOutcome.success]. Falls back to the token that was used for
  /// the refresh when the server does not rotate it.
  final String? refreshToken;

  const TokenRefreshResult._(
    this.outcome, {
    this.accessToken,
    this.refreshToken,
  });

  const TokenRefreshResult.success(String accessToken, String refreshToken)
      : this._(
          TokenRefreshOutcome.success,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

  const TokenRefreshResult.rejected() : this._(TokenRefreshOutcome.rejected);

  const TokenRefreshResult.transientError()
      : this._(TokenRefreshOutcome.transientError);
}

/// Process-wide single-flight token refresher shared by the auth interceptor
/// and `TokenManager`.
///
/// Why single-flight? With a rotating-refresh-token backend, two concurrent
/// refreshes sent with the SAME token race: the first succeeds and rotates
/// the token, the second is rejected with the now-invalidated token. If the
/// second caller treats that rejection as "session invalid", a perfectly good
/// session gets force-logged-out (the cold-start race between
/// `ModeRouter._restoreSession` and the auth interceptor).
///
/// [refresh] dedupes every in-flight refresh attempt process-wide: while a
/// refresh is running, each caller awaits the SAME underlying future instead
/// of issuing a second request. The future is created with the first caller's
/// callbacks; this is safe because every caller reads and writes the same
/// secure token store and hits the same `/auth/refresh` endpoint.
///
/// Classification: only a definitive rejection of the refresh token
/// (HTTP 400/401/403) yields [TokenRefreshOutcome.rejected]. Network errors,
/// timeouts, 5xx and malformed responses yield
/// [TokenRefreshOutcome.transientError] so the caller keeps its tokens.
class TokenRefresher {
  /// Reads the current refresh token from secure storage.
  final Future<String?> Function() getRefreshToken;

  /// Persists a freshly rotated token pair to secure storage.
  final Future<void> Function(String access, String refresh) saveTokens;

  static Future<TokenRefreshResult>? _inFlight;

  TokenRefresher({
    required this.getRefreshToken,
    required this.saveTokens,
  });

  /// Exchanges the current refresh token for a new pair.
  ///
  /// [performRefresh] performs the actual `POST /auth/refresh` network call.
  /// Concurrent calls share the same in-flight request.
  Future<TokenRefreshResult> refresh(
    Future<Response> Function(String refreshToken) performRefresh,
  ) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final future = _doRefresh(performRefresh);
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
    return future;
  }

  Future<TokenRefreshResult> _doRefresh(
    Future<Response> Function(String refreshToken) performRefresh,
  ) async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      // Nothing to refresh with — the session is unusable.
      return const TokenRefreshResult.rejected();
    }

    try {
      final response = await performRefresh(refreshToken);

      // Parse the body first (mirror AuthService.login): a response carrying a
      // fresh access token is a success regardless of whether the caller set
      // an explicit statusCode (some servers/clients omit it). Only when the
      // body carries no token do we fall back to classifying by status code.
      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      // Accept both camelCase and snake_case payloads (the backend may
      // return either shape — mirror AuthService.login).
      final newAccess = (data['accessToken'] as String?) ??
          (data['access_token'] as String?);
      final newRefresh = (data['refreshToken'] as String?) ??
          (data['refresh_token'] as String?);

      if (newAccess != null) {
        await saveTokens(newAccess, newRefresh ?? refreshToken);
        return TokenRefreshResult.success(
          newAccess,
          newRefresh ?? refreshToken,
        );
      }

      // No access token in the body — classify by status code. A 200 without
      // an access token is a malformed server response — keep the existing
      // tokens rather than invalidating the session.
      if (response.statusCode == 200) {
        developer.log(
          'TokenRefresher: refresh returned 200 without an access token',
          name: 'TokenRefresher',
        );
        return const TokenRefreshResult.transientError();
      }

      return _classify(response.statusCode);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      developer.log(
        'TokenRefresher: refresh failed – type=${e.type} status=$status',
        name: 'TokenRefresher',
      );
      return _classify(status);
    } catch (e) {
      developer.log(
        'TokenRefresher: refresh failed – $e',
        name: 'TokenRefresher',
      );
      return const TokenRefreshResult.transientError();
    }
  }

  /// Only a definitive rejection of the refresh token (HTTP 400/401/403)
  /// invalidates the session; every other failure is treated as transient.
  TokenRefreshResult _classify(int? statusCode) {
    if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
      return const TokenRefreshResult.rejected();
    }
    return const TokenRefreshResult.transientError();
  }
}
