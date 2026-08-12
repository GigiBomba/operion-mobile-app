import 'package:dio/dio.dart';

/// Whether [error] is an authentication / authorization rejection (HTTP 401
/// or 403).
///
/// Dual-mode providers (fleet/clients/drivers) use this to decide between the
/// cache-fallback path and propagating the error: an auth rejection must
/// surface (the auth interceptor forces logout) instead of silently rendering
/// a stale cached list — which would flash before the forced logout. Connection
/// failures (timeouts, socket errors, `connectionError`/`unknown` without a
/// status code) stay on the cache-fallback path.
bool isAuthRejection(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) return true;
  }
  return false;
}
