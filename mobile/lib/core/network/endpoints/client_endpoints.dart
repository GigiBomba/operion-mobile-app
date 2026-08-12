import 'package:dio/dio.dart';

import '../api_client.dart';

/// Endpoint methods for the clients (CRM) module (blueprint §4.3).
///
/// List endpoints follow the shared `{items, total, page, page_size,
/// total_pages}` envelope and accept `page`/`page_size` and `search`.
class ClientEndpoints {
  final ApiClient client;

  ClientEndpoints(this.client);

  /// `GET /mobile/clients?search&page&page_size`.
  Future<Response> getClients({
    String? search,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/clients',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          'page': page,
          'page_size': pageSize,
        },
        cancelToken: cancelToken,
      );

  /// `GET /mobile/clients/{id}` → ClientOut + `contacts`,
  /// `recent_trip_count`, `recent_invoice_count`.
  Future<Response> getClient(String id, {CancelToken? cancelToken}) =>
      client.get('/api/v1/mobile/clients/$id', cancelToken: cancelToken);

  /// `POST /mobile/clients` (create client).
  Future<Response> createClient(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) =>
      client.post('/api/v1/mobile/clients',
          data: data, cancelToken: cancelToken);

  /// `PATCH /mobile/clients/{id}` (update client).
  Future<Response> updateClient(
    String id,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) =>
      client.patch('/api/v1/mobile/clients/$id',
          data: data, cancelToken: cancelToken);

  /// `POST /mobile/clients/{id}/contacts` (add a contact).
  Future<Response> addContact(
    String id,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) =>
      client.post('/api/v1/mobile/clients/$id/contacts',
          data: data, cancelToken: cancelToken);

  /// `POST /mobile/clients/merge` → `{merged_trip_count,
  /// merged_invoice_count, merged_contact_count}`.
  Future<Response> mergeClients({
    required String targetId,
    required List<String> sourceIds,
    CancelToken? cancelToken,
  }) =>
      client.post(
        '/api/v1/mobile/clients/merge',
        data: {'target_id': targetId, 'source_ids': sourceIds},
        cancelToken: cancelToken,
      );
}
