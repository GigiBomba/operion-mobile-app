import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Minimal [HttpClientAdapter] that routes requests to test handlers and
/// records every request so tests can assert on headers / URLs / call counts.
class MockDioAdapter implements HttpClientAdapter {
  MockDioAdapter({this.onGet, this.onPost});

  /// Handler for `GET` requests. Returns a [ResponseBody] for [options].
  final ResponseBody Function(RequestOptions options)? onGet;

  /// Handler for `POST` requests.
  final ResponseBody Function(RequestOptions options)? onPost;

  /// Every request the adapter received, in order.
  final List<RequestOptions> requests = [];

  /// Count of `GET` requests.
  int get getRequestCount =>
      requests.where((r) => r.method == 'GET').length;

  /// Count of `POST` requests.
  int get postRequestCount =>
      requests.where((r) => r.method == 'POST').length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'GET' && onGet != null) return onGet!(options);
    if (options.method == 'POST' && onPost != null) return onPost!(options);
    return jsonResponse('[]');
  }

  @override
  void close({bool force = false}) {}
}

/// Builds a JSON [ResponseBody] with the given [statusCode].
ResponseBody jsonResponse(dynamic body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    body is String ? body : jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// Provider-agnostic load-board fixture matching the fixed contract fields.
///
/// `id` uses the composite `provider_id/load_id` shape so the accept flow can
/// build the import URL without any provider-specific model fields.
List<Map<String, dynamic>> freightLoadFixture() => [
      {
        'id': 'exch-a/load-1',
        'origin': 'Berlin',
        'destination': 'Bucharest',
        'cargo_type': 'general',
        'price': 1850.0,
        'currency': 'EUR',
        'pickup_date': '2026-08-01T08:00:00',
        'deadline_date': '2026-08-03T18:00:00',
        'weight_kg': 22000.0,
        'distance_km': '1800',
      },
      {
        'id': 'exch-a/load-2',
        'origin': 'Munich',
        'destination': 'Cluj',
        'cargo_type': 'reefer',
        'price': 2400.0,
        'currency': 'EUR',
        'pickup_date': '2026-08-02T06:00:00',
        'deadline_date': '2026-08-04T20:00:00',
        'weight_kg': 18000.0,
        'distance_km': '1400',
      },
    ];

/// Transport fixture for the Accept & Assign transport picker.
Map<String, dynamic> transportFixture() => {
      'id': 'tr-1',
      'companyId': 'c-1',
      'loadInfo': 'Truck A',
      'origin': 'Berlin',
      'destination': 'Bucharest',
      'waypoints': <String>[],
      'status': 'planned',
      'vehiclePlate': 'B-123-ABC',
    };
