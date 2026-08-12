import 'package:dio/dio.dart';

import '../api_client.dart';

/// Endpoint methods for the drivers module (blueprint §4.2).
///
/// List endpoints follow the shared `{items, total, page, page_size,
/// total_pages}` envelope and accept `page`/`page_size`, `search`, `status`
/// and `expiring_within_days` (30-day license-expiry window, mirroring the
/// backend driver repository default).
class DriversEndpoints {
  final ApiClient client;

  DriversEndpoints(this.client);

  /// `GET /mobile/drivers?search&status&expiring_within_days&page&page_size`.
  Future<Response> getDrivers({
    String? search,
    String? status,
    int? expiringWithinDays,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/drivers',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (status != null && status.isNotEmpty) 'status': status,
          'expiring_within_days': ?expiringWithinDays,
          'page': page,
          'page_size': pageSize,
        },
        cancelToken: cancelToken,
      );

  /// `GET /mobile/drivers/{id}` → full DriverOut (incl. `adr_certificate_expiry`,
  /// `current_truck_id`, `status`).
  Future<Response> getDriverDetail(String id, {CancelToken? cancelToken}) =>
      client.get('/api/v1/mobile/drivers/$id', cancelToken: cancelToken);

  /// `POST /mobile/drivers` (create driver) → DriverOut.
  Future<Response> createDriver(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) =>
      client.post('/api/v1/mobile/drivers',
          data: data, cancelToken: cancelToken);

  /// `PATCH /mobile/drivers/{id}` (update driver).
  Future<Response> updateDriver(
    String id,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) =>
      client.patch('/api/v1/mobile/drivers/$id',
          data: data, cancelToken: cancelToken);

  /// `GET /mobile/drivers/{id}/tacho?start_date&end_date` → TachoWeek.
  Future<Response> getTacho(
    String id, {
    String? startDate,
    String? endDate,
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/drivers/$id/tacho',
        queryParameters: {
          'start_date': ?startDate,
          'end_date': ?endDate,
        },
        cancelToken: cancelToken,
      );
}
