import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'auth_interceptor.dart';

const Uuid _uuid = Uuid();

/// Generates a unique idempotency key (UUID v4) for write requests.
///
/// Sent as the `Idempotency-Key` header; the backend's
/// `IdempotencyMiddleware` caches the response for 24h and replays it when
/// the same key is submitted again, preventing duplicate processing.
String generateIdempotencyKey() => _uuid.v4();

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
  static ApiClient create({
    required String baseUrl,
    required Future<String?> Function() getAccessToken,
    Future<String?> Function()? getRefreshToken,
    Future<void> Function(String access, String refresh)? saveTokens,
    Future<void> Function()? clearTokens,
    VoidCallback? onForceLogout,
    String? apiKey,
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
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[Dio] $obj'),
    ));

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
