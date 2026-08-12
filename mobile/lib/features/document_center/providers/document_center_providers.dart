import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints/document_endpoints.dart';
import '../models/ocr_upload_response.dart';

/// Endpoint methods for OCR automation (`POST /api/v1/ocr/process`).
///
/// The request is multipart with a REQUIRED `Idempotency-Key` header. The
/// response is `OcrUploadResponse` — status is always `queued`/`processing`,
/// never a synchronous extracted-fields result.
class OcrEndpoints {
  final ApiClient client;

  OcrEndpoints(this.client);

  /// Uploads [imagePath] to `POST /api/v1/ocr/process`.
  Future<Response> processImage({
    required String imagePath,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromFileSync(imagePath),
    });
    return client.dio.post(
      '/api/v1/ocr/process',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        headers: {'Idempotency-Key': idempotencyKey},
      ),
      cancelToken: cancelToken,
    );
  }
}

final ocrEndpointsProvider = Provider<OcrEndpoints>((ref) {
  return OcrEndpoints(ref.read(apiClientProvider));
});

/// Provides a singleton [DocumentEndpoints] wired to the shared [ApiClient].
final documentEndpointsProvider = Provider<DocumentEndpoints>((ref) {
  return DocumentEndpoints(ref.read(apiClientProvider));
});

/// A single company document (DocumentResponse — dispatcher/manager scope).
class CompanyDocument {
  final int id;
  final String title;
  final String category;
  final String fileName;
  final String uploadedBy;
  final DateTime? uploadedAt;
  final String mimeType;
  final int fileSize;

  const CompanyDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.fileName,
    required this.uploadedBy,
    this.uploadedAt,
    this.mimeType = '',
    this.fileSize = 0,
  });

  factory CompanyDocument.fromJson(Map<String, dynamic> json) =>
      CompanyDocument(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? '',
        fileName: json['file_name'] as String? ?? '',
        uploadedBy: json['uploaded_by'] as String? ?? '',
        uploadedAt: json['uploaded_at'] != null
            ? DateTime.tryParse(json['uploaded_at'] as String)
            : null,
        mimeType: json['mime_type'] as String? ?? '',
        fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      );
}

/// Filters for the Documents list (`query` FTS + `category` chip, §2 parity).
class DocumentListFilter {
  final String query;
  final String category;

  const DocumentListFilter({this.query = '', this.category = ''});

  bool get isDefault => query.isEmpty && category.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentListFilter &&
          query == other.query &&
          category == other.category;

  @override
  int get hashCode => Object.hash(query, category);

  @override
  String toString() => 'DocumentListFilter(query: $query, category: $category)';
}

/// A document category with its document count (`GET /documents/categories`).
class DocumentCategory {
  final String category;
  final int count;

  const DocumentCategory({required this.category, required this.count});

  factory DocumentCategory.fromJson(Map<String, dynamic> json) =>
      DocumentCategory(
        category: json['category'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

/// One revision of a document (`GET /documents/{id}/read` → `versions`).
///
/// Parsed defensively — `file_name` and `uploaded_by` may be absent per the
/// contract.
class DocumentVersion {
  final int versionNumber;
  final String fileName;
  final DateTime? createdAt;
  final String uploadedBy;

  const DocumentVersion({
    required this.versionNumber,
    this.fileName = '',
    this.createdAt,
    this.uploadedBy = '',
  });

  factory DocumentVersion.fromJson(Map<String, dynamic> json) {
    final versionNumber = json['version_number'];
    return DocumentVersion(
      versionNumber: versionNumber is num
          ? versionNumber.toInt()
          : int.tryParse('$versionNumber') ?? 0,
      fileName: json['file_name'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      uploadedBy: json['uploaded_by'] as String? ?? '',
    );
  }
}

/// Fetches company documents for the Documents tab, filtered by [filter].
///
/// `GET /api/v1/documents/` returns `PaginatedResponse[DocumentResponse]` —
/// a flat `{items: [...]}` list. The §2 parity contract adds the `query`
/// (server-side FTS) and `category` query params; both are omitted when
/// empty so an older backend keeps working.
///
/// Owns a [CancelToken] per in-flight request tied to the provider lifecycle
/// (§1.2): navigating away disposes the provider and cancels the call.
final companyDocumentsProvider =
    FutureProvider.family<List<CompanyDocument>, DocumentListFilter>(
        (ref, filter) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final endpoints = ref.watch(documentEndpointsProvider);
  final response = await endpoints.searchCompanyDocuments(
    query: filter.query,
    category: filter.category,
    cancelToken: cancelToken,
  );
  final data = response.data;
  if (data is! Map<String, dynamic> || data['items'] is! List) {
    throw StateError('Unexpected documents response: ${data.runtimeType}');
  }
  return (data['items'] as List)
      .whereType<Map<String, dynamic>>()
      .map(CompanyDocument.fromJson)
      .toList();
});

/// Fetches the document category chips (`GET /documents/categories`).
///
/// Parsed defensively: a non-list payload yields an empty list so the chips
/// row simply renders "All".
final documentCategoriesProvider = FutureProvider<List<DocumentCategory>>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final endpoints = ref.watch(documentEndpointsProvider);
  final response = await endpoints.listDocumentCategories(
    cancelToken: cancelToken,
  );
  final data = response.data;
  if (data is! List) return const [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(DocumentCategory.fromJson)
      .where((c) => c.category.isNotEmpty)
      .toList();
});

/// Request key for entity-scoped document listings (truck/transport tabs).
class EntityDocumentsRequest {
  final String entityType;
  final String entityId;

  const EntityDocumentsRequest({
    required this.entityType,
    required this.entityId,
  });

  @override
  bool operator ==(Object other) =>
      other is EntityDocumentsRequest &&
      other.entityType == entityType &&
      other.entityId == entityId;

  @override
  int get hashCode => Object.hash(entityType, entityId);

  @override
  String toString() => 'EntityDocumentsRequest($entityType/$entityId)';
}

/// Fetches documents linked to an entity: `GET /api/v1/documents/` with the
/// `entity_type` (+ `entity_id`) query filters.
///
/// Owns a [CancelToken] per in-flight request tied to the provider lifecycle
/// (§1.2). The backend returns the shared paginated envelope; items are parsed
/// into [CompanyDocument].
final entityDocumentsProvider = FutureProvider.autoDispose
    .family<List<CompanyDocument>, EntityDocumentsRequest>((ref, request) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final endpoints = ref.watch(documentEndpointsProvider);
  final response = await endpoints.listDocumentsForEntity(
    entityType: request.entityType,
    entityId: request.entityId,
    cancelToken: cancelToken,
  );
  final data = response.data;
  if (data is! Map<String, dynamic> || data['items'] is! List) {
    throw StateError('Unexpected documents response: ${data.runtimeType}');
  }
  return (data['items'] as List)
      .whereType<Map<String, dynamic>>()
      .map(CompanyDocument.fromJson)
      .toList();
});

/// Fetches the version history of [docId] (`GET /documents/{id}/read`).
///
/// Parsed defensively: absent/non-list `versions` yields an empty list.
///
/// No read/stream endpoint exists in the dispatcher contract, so this only
/// powers the metadata version list (no preview) — documented in §2.
final documentVersionsProvider =
    FutureProvider.family<List<DocumentVersion>, int>((ref, docId) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final endpoints = ref.watch(documentEndpointsProvider);
  final response = await endpoints.readDocument(docId, cancelToken: cancelToken);
  final data = response.data;
  if (data is! Map<String, dynamic>) return const [];
  final versions = data['versions'];
  if (versions is! List) return const [];
  return versions
      .whereType<Map<String, dynamic>>()
      .map(DocumentVersion.fromJson)
      .toList();
});

/// Picks an image from the camera; overridable in tests.
///
/// Returns the picked file path or `null` when the user cancels.
final ocrImagePickProvider = Provider<Future<String?> Function()>((ref) {
  return _pickCameraImage;
});

Future<String?> _pickCameraImage() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 2048,
    maxHeight: 2048,
  );
  return file?.path;
}

/// Phases of the camera → OCR upload flow.
enum OcrUploadPhase { idle, uploading, confirmed, error }

/// Upload flow state. Holds only the acknowledgement from the backend —
/// never extracted fields (those stay cloud-side until Local Download).
class OcrUploadState {
  final OcrUploadPhase phase;

  /// `document_id` echoed by the backend.
  final String? documentId;

  /// The parsed `OcrUploadResponse` (status `queued`/`processing` only).
  final OcrUploadResponse? response;

  const OcrUploadState({
    this.phase = OcrUploadPhase.idle,
    this.documentId,
    this.response,
  });
}

/// Camera-capture OCR upload notifier.
///
/// Flow (§6.4):
/// 1. Generate an `Idempotency-Key` (UUID) for this upload action.
/// 2. `POST /api/v1/ocr/process` with the image + key → `OcrUploadResponse`.
/// 3. Surface "upload confirmed, processing" — NO polling loop, NO local
///    storage of OCR results.
class OcrUploadNotifier extends StateNotifier<OcrUploadState> {
  final OcrEndpoints _endpoints;

  /// One [CancelToken] per notifier lifecycle (§1.2).
  ///
  /// The upload carries it; [dispose] cancels it so navigating away from the
  /// Automation tab never leaves a stray upload or surfaces a spurious error
  /// state.
  final CancelToken _cancelToken = CancelToken();

  OcrUploadNotifier(this._endpoints) : super(const OcrUploadState());

  /// The notifier's in-flight [CancelToken] (test seam).
  @visibleForTesting
  CancelToken get cancelToken => _cancelToken;

  @override
  void dispose() {
    _cancelToken.cancel();
    super.dispose();
  }

  Future<void> upload({required String imagePath}) async {
    if (state.phase == OcrUploadPhase.uploading) return;
    state = const OcrUploadState(phase: OcrUploadPhase.uploading);
    try {
      final idempotencyKey = generateIdempotencyKey();
      final response = await _endpoints.processImage(
        imagePath: imagePath,
        idempotencyKey: idempotencyKey,
        cancelToken: _cancelToken,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw StateError('Unexpected OCR response: ${data.runtimeType}');
      }
      final parsed = OcrUploadResponse.fromJson(data);
      // Status is always queued/processing — never extracted fields.
      state = OcrUploadState(
        phase: OcrUploadPhase.confirmed,
        documentId: parsed.documentId,
        response: parsed,
      );
    } on DioException catch (e) {
      // Cancelling the token on dispose must never surface as an error state.
      if (e.type == DioExceptionType.cancel) return;
      state = const OcrUploadState(phase: OcrUploadPhase.error);
    } catch (_) {
      state = const OcrUploadState(phase: OcrUploadPhase.error);
    }
  }

  void reset() => state = const OcrUploadState();
}

final ocrUploadProvider =
    StateNotifierProvider<OcrUploadNotifier, OcrUploadState>((ref) {
  return OcrUploadNotifier(ref.read(ocrEndpointsProvider));
});
