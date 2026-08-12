import 'package:dio/dio.dart';

import '../api_client.dart';

/// Endpoint methods for document uploads and retrieval.
class DocumentEndpoints {
  final ApiClient client;

  DocumentEndpoints(this.client);

  /// Upload a document.
  ///
  /// Multipart fields match the backend contract
  /// (`POST /api/v1/documents/upload` in `api/v1/documents.py`):
  /// `file`, `category`, `entity_type`, `entity_id`. [entityId] is optional —
  /// uploads without a resolvable entity omit the field (the backend default
  /// is `null`).
  ///
  /// [filePath] is the absolute path to the file on disk.
  Future<Response> uploadDocument({
    required String category,
    required String entityType,
    String? entityId,
    required String filePath,
  }) {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromFileSync(filePath),
      'category': category,
      'entity_type': entityType,
      if (entityId != null && entityId.isNotEmpty) 'entity_id': entityId,
    });
    return client.upload('/api/v1/documents/upload', formData);
  }

  /// List company documents filtered by entity.
  ///
  /// `GET /api/v1/documents/?entity_type=...&entity_id=...` returns the shared
  /// `{items: [DocumentResponse], ...}` envelope; the company scope is derived
  /// from the JWT server-side. [entityId] is included when provided (the
  /// backend currently filters on `entity_type`).
  Future<Response> listDocumentsForEntity({
    required String entityType,
    String? entityId,
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/documents/',
        queryParameters: {
          'entity_type': entityType,
          if (entityId != null && entityId.isNotEmpty) 'entity_id': entityId,
        },
        cancelToken: cancelToken,
      );

  /// List company documents with the §2 parity filters.
  ///
  /// `GET /api/v1/documents/` accepts `query` (server-side full-text search)
  /// and `category` (exact category filter); both are omitted when empty so
  /// an older backend keeps working.
  Future<Response> searchCompanyDocuments({
    String? query,
    String? category,
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/documents/',
        queryParameters: {
          if (query != null && query.isNotEmpty) 'query': query,
          if (category != null && category.isNotEmpty) 'category': category,
        },
        cancelToken: cancelToken,
      );

  /// List document categories with per-category counts.
  ///
  /// `GET /api/v1/documents/categories` → `[{category, count}, ...]`.
  Future<Response> listDocumentCategories({CancelToken? cancelToken}) =>
      client.get('/api/v1/documents/categories', cancelToken: cancelToken);

  /// Fetch a document's read payload (metadata + version history).
  ///
  /// `GET /api/v1/documents/{doc_id}/read` → `DocumentReadResult` whose
  /// `versions` list carries `{version_number, file_name?, created_at,
  /// uploaded_by}` per revision. No raw file/stream endpoint exists in the
  /// dispatcher contract — the mobile layer renders the version list without
  /// a preview (documented in the §2 report).
  Future<Response> readDocument(int docId, {CancelToken? cancelToken}) =>
      client.get('/api/v1/documents/$docId/read', cancelToken: cancelToken);
}
