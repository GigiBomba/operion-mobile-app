import 'package:dio/dio.dart';

import '../api_client.dart';

/// Endpoint methods for route planning / optimization API calls.
class RoutesEndpoints {
  final ApiClient client;

  RoutesEndpoints(this.client);

  /// POST /api/v1/routes/calculate — optimize a route through [payload]
  /// points (place name strings or `{lat, lng}` dicts) for a truck profile.
  ///
  /// An optional [cancelToken] ties the request to a provider/widget
  /// lifecycle — navigating away cancels the in-flight call (§1.2).
  Future<Response> calculateRoute(
    Map<String, dynamic> payload, {
    CancelToken? cancelToken,
  }) =>
      client.post(
        '/api/v1/routes/calculate',
        data: payload,
        cancelToken: cancelToken,
      );
}
