import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'auth_interceptor.dart';

const Uuid _uuid = Uuid();

/// Generates a unique idempotency key (UUID v4) for write requests.
///
/// Sent as the `Idempotency-Key` header; the backend's
/// `IdempotencyMiddleware` caches the response for 24h and replays it when
/// the same key is submitted again, preventing duplicate processing.
String generateIdempotencyKey() => _uuid.v4();

/// [LogInterceptor] that redacts credentials before anything is printed.
///
/// Debug/profile builds log request/response bodies for diagnostics, but the
/// login payload carries the plaintext password and every request carries the
/// `X-API-Key` header — neither may ever reach the console. This interceptor
/// strips sensitive headers and masks password-like body fields on a COPY of
/// the request/response before delegating to the stock [LogInterceptor].
class RedactingLogInterceptor extends LogInterceptor {
  RedactingLogInterceptor()
      : super(requestBody: true, responseBody: true);

  /// Header names whose values are never logged.
  static const Set<String> _sensitiveHeaders = {
    'Authorization',
    'X-API-Key',
    'Proxy-Authorization',
    'Cookie',
    'Set-Cookie',
  };

  /// Body keys (case-insensitive) whose values are masked.
  static final RegExp _sensitiveBodyKey = RegExp(
    r'password|passwd|pwd|secret|refresh_token|access_token',
    caseSensitive: false,
  );

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final redacted = options.copyWith(
      headers: redactHeaders(options.headers),
      data: redactBody(options.data),
    );
    super.onRequest(redacted, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final redacted = Response(
      data: redactBody(response.data),
      requestOptions: response.requestOptions.copyWith(
        headers: redactHeaders(response.requestOptions.headers),
        data: redactBody(response.requestOptions.data),
      ),
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      isRedirect: response.isRedirect,
      redirects: response.redirects,
      extra: response.extra,
      headers: response.headers,
    );
    super.onResponse(redacted, handler);
  }

  /// Redacts sensitive header values (Authorization, X-API-Key, cookies).
  @visibleForTesting
  static Map<String, dynamic> redactHeaders(Map<String, dynamic> headers) {
    final redacted = Map<String, dynamic>.from(headers);
    for (final key in redacted.keys.toList()) {
      if (_sensitiveHeaders.contains(key)) {
        redacted[key] = '[REDACTED]';
      }
    }
    return redacted;
  }

  /// Masks sensitive values in a JSON-encodable body (Map/List/primitive).
  @visibleForTesting
  static dynamic redactBody(dynamic data) {
    if (data is Map) {
      final redacted = <String, dynamic>{};
      data.forEach((key, value) {
        final k = key.toString();
        redacted[k] =
            _sensitiveBodyKey.hasMatch(k) ? '[REDACTED]' : redactBody(value);
      });
      return redacted;
    }
    if (data is List) {
      return data.map(redactBody).toList();
    }
    return data;
  }
}

/// Singleton Dio-based HTTP client for the Operion Mobile app.
///
/// Create an instance via [ApiClient.create] which wires up:
/// - Base URL and sensible timeouts
/// - JSON content-type header
/// - A [LogInterceptor] for debug logging
/// - The [AuthInterceptor] for automatic token management
///
/// Convenience methods ([get], [post], [put], [patch], [delete], [upload])
/// delegate directly to the underlying [Dio] instance.
class ApiClient {
  final Dio dio;

  ApiClient._(this.dio);

  /// Creates a fully-configured [ApiClient].
  ///
  /// [baseUrl] is the root URL of the Operion API.
  /// [getAccessToken] is invoked by the auth interceptor before every
  /// non-public request to obtain the current Bearer token.
  ///
  /// [enableLogging] controls the debug [LogInterceptor]. It defaults to
  /// `!kReleaseMode` so release builds NEVER log request/response bodies
  /// (login posts the plaintext password and every request carries the
  /// `X-API-Key` header). Tests can pass `false` to assert the release
  /// behaviour.
  static ApiClient create({
    required String baseUrl,
    required Future<String?> Function() getAccessToken,
    Future<String?> Function()? getRefreshToken,
    Future<void> Function(String access, String refresh)? saveTokens,
    Future<void> Function()? clearTokens,
    VoidCallback? onForceLogout,
    String? apiKey,
    bool enableLogging = !kReleaseMode,
  }) {
    final headers = <String, dynamic>{'Content-Type': 'application/json'};
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['X-API-Key'] = apiKey;
    }

    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: headers,
    ));

    // ── Logging interceptor ─────────────────────
    // NEVER installed in release builds: request/response bodies contain
    // credentials (login password), PII and business payloads, and the
    // X-API-Key header. Debug/profile builds use the redacting interceptor
    // so sensitive headers and password-like fields are masked.
    if (enableLogging) {
      dio.interceptors.add(RedactingLogInterceptor());
    }

    // ── Auth interceptor ────────────────────────
    dio.interceptors.add(AuthInterceptor(
      getAccessToken: getAccessToken,
      getRefreshToken: getRefreshToken,
      saveTokens: saveTokens,
      clearTokens: clearTokens,
      onForceLogout: onForceLogout,
    ));

    return ApiClient._(dio);
  }

  // ── Convenience methods ───────────────────────

  /// Sends a GET request to the given [path].
  ///
  /// An optional [cancelToken] lets the caller tie the request to a widget or
  /// provider lifecycle — navigating away cancels the in-flight call (§1.2).
  /// [options] (e.g. `ResponseType.bytes` for binary downloads) is forwarded
  /// to Dio.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) =>
      dio.get<T>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
      );

  /// Sends a POST request to the given [path] with optional [data].
  ///
  /// An optional [cancelToken] lets the caller tie the request to a widget or
  /// provider lifecycle — navigating away cancels the in-flight call (§1.2).
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) =>
      dio.post<T>(path, data: data, cancelToken: cancelToken);

  /// Sends a POST request with a freshly generated `Idempotency-Key` header.
  ///
  /// Backward-compatible with [post]; the only difference is the extra
  /// header that lets the backend deduplicate retries of the same request.
  Future<Response<T>> postWithIdempotencyKey<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) =>
      dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(headers: {'Idempotency-Key': generateIdempotencyKey()}),
      );

  /// Sends a PUT request to the given [path] with optional [data].
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) =>
      dio.put<T>(path, data: data, cancelToken: cancelToken);

  /// Sends a PATCH request to the given [path] with optional [data].
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) =>
      dio.patch<T>(path, data: data, cancelToken: cancelToken);

  /// Sends a DELETE request to the given [path].
  Future<Response<T>> delete<T>(String path, {CancelToken? cancelToken}) =>
      dio.delete<T>(path, cancelToken: cancelToken);

  /// Uploads a [FormData] payload (e.g. file uploads) to [path].
  Future<Response<T>> upload<T>(
    String path,
    FormData formData, {
    CancelToken? cancelToken,
  }) =>
      dio.post<T>(
        path,
        data: formData,
        cancelToken: cancelToken,
        options: Options(contentType: 'multipart/form-data'),
      );
}
