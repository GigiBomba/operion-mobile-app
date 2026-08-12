import 'package:dio/dio.dart';

import '../api_client.dart';

/// Endpoint methods for driver-related API calls.
class DriverEndpoints {
  final ApiClient client;

  DriverEndpoints(this.client);

  /// Fetch the driver's current day summary.
  Future<Response> getMyDay() => client.get('/api/v1/mobile/driver/my-day');

  /// Fetch the list of transports assigned to the driver.
  Future<Response> getTransports() => client.get('/api/v1/mobile/driver/transports');

  /// Fetch a single transport by [id].
  Future<Response> getTransport(String id) =>
      client.get('/api/v1/mobile/driver/transports/$id');

  /// Update the [status] of a transport identified by [transportId].
  Future<Response> updateStatus(String transportId, String status) =>
      client.patch('/api/v1/mobile/transports/$transportId/status',
          data: {'status': status});

  /// Fetch the vehicle currently assigned to the driver.
  Future<Response> getVehicle() => client.get('/api/v1/mobile/driver/vehicle');

  /// Fetch all messages for the driver.
  Future<Response> getMessages() => client.get('/api/v1/mobile/messages');

  /// Send a message to [receiverId] with the given [text].
  Future<Response> sendMessage(String receiverId, String text) =>
      client.post('/api/v1/mobile/messages',
          data: {'receiver_id': receiverId, 'text': text});

  /// GET /api/v1/mobile/driver/trip-overview — current assigned trip overview.
  ///
  /// An optional [cancelToken] ties the request to a provider/widget
  /// lifecycle — navigating away cancels the in-flight call (§1.2).
  Future<Response> getTripOverview({CancelToken? cancelToken}) =>
      client.get(
        '/api/v1/mobile/driver/trip-overview',
        cancelToken: cancelToken,
      );

  /// GET /api/v1/mobile/driver/route-share — route share geometry for navigation.
  ///
  /// An optional [cancelToken] ties the request to a provider/widget
  /// lifecycle — navigating away cancels the in-flight call (§1.2).
  Future<Response> getRouteShare({CancelToken? cancelToken}) =>
      client.get(
        '/api/v1/mobile/driver/route-share',
        cancelToken: cancelToken,
      );

  /// GET /api/v1/mobile/driver/tacho — the current driver's tacho timeline
  /// (TachoTimelineOut: `{days: [...], weekly_driving_minutes,
  /// weekly_limit_minutes: 3360}`). 404 when the driver has no tacho row yet.
  ///
  /// An optional [cancelToken] ties the request to a provider/widget
  /// lifecycle — navigating away cancels the in-flight call (§1.2).
  Future<Response> getTacho({CancelToken? cancelToken}) =>
      client.get(
        '/api/v1/mobile/driver/tacho',
        cancelToken: cancelToken,
      );
}
