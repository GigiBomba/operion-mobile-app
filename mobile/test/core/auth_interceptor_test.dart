import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/network/auth_interceptor.dart';
import 'package:operion_mobile/core/network/token_refresher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Dio with [AuthInterceptor] and a capturing interceptor that resolves all
/// requests with 200. Used for onRequest (Authorization header) tests.
Dio _createResolvingDio({
  required AuthInterceptor authInterceptor,
  required _CapturingInterceptor capture,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test.com'));
  dio.interceptors.clear();
  dio.interceptors.add(authInterceptor);
  dio.interceptors.add(capture);
  dio.interceptors.add(_ResolvingInterceptor());
  return dio;
}

/// A mock interceptor that captures request options after the AuthInterceptor.
class _CapturingInterceptor extends Interceptor {
  final List<RequestOptions> capturedRequests = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    capturedRequests.add(options);
    handler.next(options);
  }
}

/// Resolves every request with 200.
class _ResolvingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.resolve(Response(
      requestOptions: options,
      data: {'status': 'ok'},
      statusCode: 200,
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('AuthInterceptor', () {
    String? currentAccessToken;
    String? currentRefreshToken;
    bool tokensCleared = false;
    bool forceLogoutCalled = false;

    late AuthInterceptor interceptor;
    late _CapturingInterceptor capture;

    setUp(() {
      currentAccessToken = null;
      currentRefreshToken = null;
      tokensCleared = false;
      forceLogoutCalled = false;

      interceptor = AuthInterceptor(
        getAccessToken: () async => currentAccessToken,
        getRefreshToken: () async => currentRefreshToken,
        saveTokens: (access, refresh) async {},
        clearTokens: () async {
          tokensCleared = true;
        },
        onForceLogout: () {
          forceLogoutCalled = true;
        },
      );

      capture = _CapturingInterceptor();
    });

    // ── onRequest – Authorization header ────────────────────────────────

    test('adds Authorization header to non-public endpoints', () async {
      currentAccessToken = 'valid_token';
      final dio = _createResolvingDio(
        authInterceptor: interceptor,
        capture: capture,
      );

      await dio.get('/api/v1/transports');

      expect(capture.capturedRequests, hasLength(1));
      final req = capture.capturedRequests.first;
      expect(req.headers['Authorization'], 'Bearer valid_token');
    });

    test('does NOT add Authorization to login endpoint', () async {
      currentAccessToken = 'valid_token';
      final dio = _createResolvingDio(
        authInterceptor: interceptor,
        capture: capture,
      );

      await dio.post('/api/v1/auth/token');

      expect(capture.capturedRequests, hasLength(1));
      final req = capture.capturedRequests.first;
      expect(req.headers['Authorization'], isNull);
    });

    test('does NOT add Authorization to refresh endpoint', () async {
      currentAccessToken = 'valid_token';
      final dio = _createResolvingDio(
        authInterceptor: interceptor,
        capture: capture,
      );

      await dio.post('/api/v1/auth/refresh');

      expect(capture.capturedRequests, hasLength(1));
      final req = capture.capturedRequests.first;
      expect(req.headers['Authorization'], isNull);
    });

    test('does NOT add Authorization when no token is available', () async {
      currentAccessToken = null;
      final dio = _createResolvingDio(
        authInterceptor: interceptor,
        capture: capture,
      );

      await dio.get('/api/v1/transports');

      expect(capture.capturedRequests, hasLength(1));
      final req = capture.capturedRequests.first;
      expect(req.headers['Authorization'], isNull);
    });

    test('does NOT add Authorization for empty token', () async {
      currentAccessToken = '';
      final dio = _createResolvingDio(
        authInterceptor: interceptor,
        capture: capture,
      );

      await dio.get('/api/v1/transports');

      expect(capture.capturedRequests, hasLength(1));
      final req = capture.capturedRequests.first;
      expect(req.headers['Authorization'], isNull);
    });

    test('handles full URL paths for public endpoint detection', () async {
      currentAccessToken = 'valid_token';
      final dio = _createResolvingDio(
        authInterceptor: interceptor,
        capture: capture,
      );

      await dio.post(
          'https://api.test.com/api/v1/auth/refresh');

      expect(capture.capturedRequests, hasLength(1));
      final req = capture.capturedRequests.first;
      expect(req.headers['Authorization'], isNull);
    });

    // ── onError – direct tests ─────────────────────────────────────────

    test(
        'handles non-401 errors without calling refresh or force logout',
        () async {
      final error = _dioError(
        path: '/api/v1/transports',
        statusCode: 500,
      );

      final handler = _TestErrorHandler();
      interceptor.onError(error, handler);
      await Future(() {});

      expect(tokensCleared, isFalse);
      expect(forceLogoutCalled, isFalse);
    });

    test('handles 403 errors without calling refresh or force logout',
        () async {
      final error = _dioError(
        path: '/api/v1/transports',
        statusCode: 403,
      );

      final handler = _TestErrorHandler();
      interceptor.onError(error, handler);
      await Future(() {});

      expect(tokensCleared, isFalse);
      expect(forceLogoutCalled, isFalse);
    });

    test('401 without refresh callbacks forwards error without forceLogout',
        () async {
      final minimalInterceptor = AuthInterceptor(
        getAccessToken: () async => 'token',
      );

      final error = _dioError(
        path: '/api/v1/transports',
        statusCode: 401,
      );

      final handler = _TestErrorHandler();
      minimalInterceptor.onError(error, handler);
      await Future(() {});

      // Without refresh callbacks, the error is just forwarded
      expect(forceLogoutCalled, isFalse);
    });

    test('401 with null refresh token triggers force logout', () async {
      currentRefreshToken = null;

      final error = _dioError(
        path: '/api/v1/transports',
        statusCode: 401,
      );

      final handler = _TestErrorHandler();
      interceptor.onError(error, handler);
      await Future(() {});
      await Future(() {});

      expect(forceLogoutCalled, isTrue);
      expect(tokensCleared, isTrue);
    });

    test('401 with empty refresh token triggers force logout', () async {
      currentRefreshToken = '';

      final error = _dioError(
        path: '/api/v1/transports',
        statusCode: 401,
      );

      final handler = _TestErrorHandler();
      interceptor.onError(error, handler);
      await Future(() {});
      await Future(() {});

      expect(forceLogoutCalled, isTrue);
      expect(tokensCleared, isTrue);
    });

    test('401 on refresh endpoint is not retried or force-logged', () async {
      // When the failing request itself IS the refresh endpoint,
      // the interceptor forwards the error without attempting another
      // refresh or triggering a force-logout.
      final error = _dioError(
        path: '/api/v1/auth/refresh',
        statusCode: 401,
      );

      final handler = _TestErrorHandler();
      interceptor.onError(error, handler);
      await Future(() {});
      await Future(() {});

      // The interceptor should NOT call force-logout; it just forwards.
      expect(forceLogoutCalled, isFalse);
      expect(tokensCleared, isFalse);
    });

    test('401 with valid refresh token but transient network error keeps tokens',
        () async {
      currentRefreshToken = 'valid_rt';

      final error = _dioError(
        path: '/api/v1/transports',
        statusCode: 401,
      );

      final handler = _RecordingErrorHandler();
      interceptor.onError(error, handler);

      // Allow async onError to complete (the refresh POST fails offline).
      for (int i = 0; i < 10; i++) {
        await Future(() {});
      }

      // A transient failure (no network in the test env) must NOT log the
      // user out or wipe the tokens — a driver in a dead zone stays signed in.
      expect(forceLogoutCalled, isFalse);
      expect(tokensCleared, isFalse);
      expect(handler.forwardedError, same(error));
    });

    test('401 on login endpoint is a plain auth failure (no refresh, no logout)',
        () async {
      currentRefreshToken = 'valid_rt';

      final error = _dioError(
        path: '/api/v1/auth/token',
        statusCode: 401,
      );

      final handler = _RecordingErrorHandler();
      interceptor.onError(error, handler);
      await Future(() {});
      await Future(() {});

      // A wrong-password 401 must never enter the refresh/force-logout
      // machinery (which could flash SessionExpiredScreen or loop the login).
      expect(forceLogoutCalled, isFalse);
      expect(tokensCleared, isFalse);
      expect(handler.forwardedError, same(error));
    });

    test('401 on forgot-password endpoint is forwarded without refresh',
        () async {
      currentRefreshToken = 'valid_rt';

      final error = _dioError(
        path: '/api/v1/auth/forgot-password',
        statusCode: 401,
      );

      final handler = _RecordingErrorHandler();
      interceptor.onError(error, handler);
      await Future(() {});
      await Future(() {});

      expect(forceLogoutCalled, isFalse);
      expect(tokensCleared, isFalse);
      expect(handler.forwardedError, same(error));
    });

    // ── Shared single-flight refresher ─────────────────────────────────

    test('concurrent refresh attempts share a single in-flight request',
        () async {
      var refreshCalls = 0;
      final refresher = TokenRefresher(
        getRefreshToken: () async => 'valid_rt',
        saveTokens: (access, refresh) async {},
      );

      Future<Response> slowRefresh(String refreshToken) async {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return Response(
          requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
          statusCode: 200,
          data: {'accessToken': 'at_new', 'refreshToken': 'rt_new'},
        );
      }

      final results = await Future.wait([
        refresher.refresh(slowRefresh),
        refresher.refresh(slowRefresh),
        refresher.refresh(slowRefresh),
      ]);

      // Only ONE network request must be issued for all three callers.
      expect(refreshCalls, 1);
      for (final result in results) {
        expect(result.outcome, TokenRefreshOutcome.success);
        expect(result.accessToken, 'at_new');
      }
    });

    test('refresh parses snake_case token fields (backend shape)', () async {
      final refresher = TokenRefresher(
        getRefreshToken: () async => 'valid_rt',
        saveTokens: (access, refresh) async {},
      );

      final result = await refresher.refresh(
        (refreshToken) async => Response(
          requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
          statusCode: 200,
          data: {'access_token': 'snake_at', 'refresh_token': 'snake_rt'},
        ),
      );

      expect(result.outcome, TokenRefreshOutcome.success);
      expect(result.accessToken, 'snake_at');
      expect(result.refreshToken, 'snake_rt');
    });

    test('refresh rejection (401) is classified as rejected, not transient',
        () async {
      final refresher = TokenRefresher(
        getRefreshToken: () async => 'valid_rt',
        saveTokens: (access, refresh) async {},
      );

      final result = await refresher.refresh(
        (refreshToken) async => throw DioException(
          requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
            statusCode: 401,
          ),
        ),
      );

      expect(result.outcome, TokenRefreshOutcome.rejected);
    });

    // ── Edge cases ────────────────────────────────────────────────────

    test('handle non-standard path format for public detection', () async {
      final i = AuthInterceptor(getAccessToken: () async => 'token');

      expect(
        () => i.onRequest(
          RequestOptions(path: '/api/v1/auth/token'),
          _MockRequestHandler(),
        ),
        returnsNormally,
      );
    });

    test('normalisePath handles bad URI gracefully', () async {
      final i = AuthInterceptor(getAccessToken: () async => 'token');

      expect(
        () => i.onRequest(
          RequestOptions(path: ':::invalid uri'),
          _MockRequestHandler(),
        ),
        returnsNormally,
      );
    });

    test('forceLogout handles null clearTokens and onForceLogout', () async {
      final i = AuthInterceptor(
        getAccessToken: () async => 'token',
        getRefreshToken: () async => 'rt',
        saveTokens: (a, r) async {},
      );

      final error = _dioError(
        path: '/api/v1/test',
        statusCode: 401,
      );

      final handler = _TestErrorHandler();
      i.onError(error, handler);
      await Future(() {});
      // No crash expected
    });

    test('VoidCallback typedef compiles', () {
      // Verify the typedef from auth_interceptor.dart is accessible
      expect(VoidCallback, isNotNull);
    });
  });
}

// ── Helpers ─────────────────────────────────────────────────────────────────

DioException _dioError({
  required String path,
  required int statusCode,
}) {
  return DioException(
    requestOptions: RequestOptions(path: path),
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: RequestOptions(path: path),
      statusCode: statusCode,
      data: {},
    ),
  );
}

class _MockRequestHandler extends RequestInterceptorHandler {
  @override
  void next(RequestOptions options) {}

  @override
  void resolve(Response<dynamic> response, [bool? callFollowingResponse]) {}

  @override
  void reject(DioException error, [bool? callFollowingError]) {}
}

class _TestErrorHandler extends ErrorInterceptorHandler {
  @override
  void next(DioException err) {}

  @override
  void resolve(Response<dynamic> response, [bool? callFollowingResponse]) {}

  @override
  void reject(DioException error, [bool? callFollowingError]) {}
}

/// Records what the interceptor did with the error so tests can assert that
/// the original error was forwarded (and nothing was force-logged).
class _RecordingErrorHandler extends ErrorInterceptorHandler {
  DioException? forwardedError;
  Response<dynamic>? resolvedResponse;

  @override
  void next(DioException err) {
    forwardedError = err;
  }

  @override
  void resolve(Response<dynamic> response, [bool? callFollowingResponse]) {
    resolvedResponse = response;
  }

  @override
  void reject(DioException error, [bool? callFollowingError]) {}
}
