import 'package:dio/dio.dart';

import '../api_client.dart';

/// Endpoint methods for the fleet (trucks) module (blueprint §4.1).
///
/// All paths are relative to `/api/v1`. List endpoints follow the shared
/// `{items, total, page, page_size, total_pages}` envelope contract and take
/// `page`/`page_size` parameters.
class FleetEndpoints {
  final ApiClient client;

  FleetEndpoints(this.client);

  /// `GET /mobile/fleet?search&status&page&page_size`
  Future<Response> getFleet({
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/fleet',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (status != null && status.isNotEmpty) 'status': status,
          'page': page,
          'page_size': pageSize,
        },
        cancelToken: cancelToken,
      );

  /// `GET /mobile/fleet/{id}` → TruckOut.
  Future<Response> getTruck(String id, {CancelToken? cancelToken}) =>
      client.get('/api/v1/mobile/fleet/$id', cancelToken: cancelToken);

  /// `POST /mobile/fleet` (create truck) → TruckOut.
  Future<Response> createTruck(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) =>
      client.post('/api/v1/mobile/fleet', data: data, cancelToken: cancelToken);

  /// `PATCH /mobile/fleet/{id}` (update truck).
  Future<Response> updateTruck(
    String id,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) =>
      client.patch('/api/v1/mobile/fleet/$id',
          data: data, cancelToken: cancelToken);

  /// `GET /mobile/fleet/{id}/maintenance` → `{items: [...]}` history.
  Future<Response> getMaintenanceHistory(
    String id, {
    CancelToken? cancelToken,
  }) =>
      client.get('/api/v1/mobile/fleet/$id/maintenance',
          cancelToken: cancelToken);

  /// `POST /mobile/fleet/{id}/maintenance` (record work).
  Future<Response> addMaintenanceRecord(
    String id,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) =>
      client.post('/api/v1/mobile/fleet/$id/maintenance',
          data: data, cancelToken: cancelToken);
}
