import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../../../core/sync/wifi_gate.dart';
import '../../teams/providers/teams_providers.dart';
import '../models/tacho_compliance.dart';

/// Endpoint methods for the tachograph module (blueprint §4.7).
///
/// Paths are relative to `/api/v1`. The import is multipart and returns a
/// `202 {job_id}`; the status endpoint is polled until a terminal state.
class TachoEndpoints {
  final ApiClient client;

  TachoEndpoints(this.client);

  /// `POST /mobile/tacho/import` (multipart `driver_id` + `.ddd`/`.esm`).
  Future<Response> import({
    required String driverId,
    required String filePath,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) {
    final formData = FormData.fromMap({
      'driver_id': driverId,
      'file': MultipartFile.fromFileSync(filePath),
    });
    return client.dio.post(
      '/api/v1/mobile/tacho/import',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
  }

  /// `GET /mobile/tacho/import/{job_id}/status`.
  Future<Response> importStatus(String jobId, {CancelToken? cancelToken}) =>
      client.get(
        '/api/v1/mobile/tacho/import/$jobId/status',
        cancelToken: cancelToken,
      );
}

/// Provides the singleton [TachoEndpoints] wired to the shared client.
final tachoEndpointsProvider = Provider<TachoEndpoints>((ref) {
  return TachoEndpoints(ref.watch(apiClientProvider));
});

/// Picks a `.ddd`/`.esm` file; overridable in tests.
final tachoFilePickerProvider = Provider<Future<FilePickerResult?> Function()>(
  (ref) => _pickTachoFile,
);

Future<FilePickerResult?> _pickTachoFile() async {
  return FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['ddd', 'esm'],
  );
}

/// The driver list shown by the tachograph driver picker (bottom sheet).
///
/// Reuses `GET /mobile/drivers` via [driversEndpointsProvider] — the same
/// endpoint the Teams screen uses.
final tachoDriversProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final endpoints = ref.watch(driversEndpointsProvider);
  final response = await endpoints.getDrivers(
    page: 1,
    pageSize: 100,
    cancelToken: cancelToken,
  );
  final data = response.data;
  if (data is! Map<String, dynamic>) return const <Map<String, dynamic>>[];
  return PaginatedResponse.fromJson(data, (m) => m).items;
});

// ── Import flow (StateNotifier, §4.7) ──────────────────────────────────

/// Phases of the `.ddd`/`.esm` import flow.
enum TachoImportPhase {
  /// No import has been started.
  idle,

  /// The file is being uploaded (progress is reported).
  uploading,

  /// The upload succeeded; the backend is processing the card.
  processing,

  /// The backend returned a compliance result.
  success,

  /// The upload or job failed (see [TachoImportState.error]).
  error,
}

/// Import-flow state.
class TachoImportState {
  const TachoImportState({
    this.phase = TachoImportPhase.idle,
    this.progress = 0,
    this.jobId,
    this.result,
    this.error,
    this.wifiBlocked = false,
  });

  final TachoImportPhase phase;

  /// Upload progress, 0..1 (only meaningful while [phase] is `uploading`).
  final double progress;

  /// The async import job id returned by the backend (202 response).
  final String? jobId;

  /// Parsed compliance result (only after a terminal success).
  final TachoComplianceResult? result;

  /// Error message / reason for the `error` phase.
  final String? error;

  /// Phase 4B §4.10: the upload was blocked by the Wi-Fi-only gate.
  final bool wifiBlocked;

  bool get isBusy =>
      phase == TachoImportPhase.uploading || phase == TachoImportPhase.processing;

  TachoImportState copyWith({
    TachoImportPhase? phase,
    double? progress,
    String? jobId,
    TachoComplianceResult? result,
    String? error,
    bool? wifiBlocked,
  }) {
    return TachoImportState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      jobId: jobId ?? this.jobId,
      result: result ?? this.result,
      error: error ?? this.error,
      wifiBlocked: wifiBlocked ?? this.wifiBlocked,
    );
  }
}

/// Upload + job-state notifier.
///
/// Offline: the upload throws a [TachoUploadRequiresConnection] which the
/// screen surfaces inline. Wi-Fi-only (Phase 4B §4.10): blocked with the
/// [TachoImportState.wifiBlocked] flag — no network call is made.
class TachoImportNotifier extends StateNotifier<TachoImportState> {
  TachoImportNotifier(this._ref) : super(const TachoImportState());

  final Ref _ref;

  /// One [CancelToken] per notifier lifecycle (§1.2).
  final CancelToken _cancelToken = CancelToken();

  @override
  void dispose() {
    _cancelToken.cancel();
    super.dispose();
  }

  /// Uploads [filePath] for [driverId] and transitions to `processing`.
  ///
  /// The Phase 4B Wi-Fi-only gate is checked BEFORE any network call.
  Future<void> import({
    required String driverId,
    required String filePath,
  }) async {
    if (state.isBusy) return;

    if (_ref.read(isOfflineProvider)) {
      state = const TachoImportState(phase: TachoImportPhase.error)
          .copyWith(error: 'requires_connection');
      throw const TachoUploadRequiresConnection();
    }

    // Phase 4B §4.10: block large uploads on cellular when the user opted in.
    if (_ref.read(wifiGateProvider).blocksLargeTransfer) {
      state = const TachoImportState(
        phase: TachoImportPhase.error,
        wifiBlocked: true,
      );
      throw const TachoUploadWifiBlocked();
    }

    state = const TachoImportState(phase: TachoImportPhase.uploading);
    try {
      final response = await _ref.read(tachoEndpointsProvider).import(
            driverId: driverId,
            filePath: filePath,
            onSendProgress: (sent, total) {
              if (total > 0) {
                state = state.copyWith(
                  progress: (sent / total).clamp(0.0, 1.0),
                );
              }
            },
            cancelToken: _cancelToken,
          );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw StateError('Unexpected tacho import response: ${data.runtimeType}');
      }
      final jobId = data['job_id']?.toString();
      if (jobId == null || jobId.isEmpty) {
        throw StateError('Tacho import response missing job_id');
      }
      state = TachoImportState(
        phase: TachoImportPhase.processing,
        progress: 1,
        jobId: jobId,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      state = TachoImportState(phase: TachoImportPhase.error, error: '$e');
    } catch (_) {
      state = const TachoImportState(
        phase: TachoImportPhase.error,
        error: 'import_failed',
      );
    }
  }

  /// Called when the status poll reports a terminal success.
  void onJobSuccess(TachoComplianceResult result) {
    state = TachoImportState(
      phase: TachoImportPhase.success,
      progress: 1,
      result: result,
    );
  }

  /// Called when the status poll reports a terminal error.
  void onJobError(String message) {
    state = TachoImportState(phase: TachoImportPhase.error, error: message);
  }

  void reset() => state = const TachoImportState();
}

/// Thrown when an import requires a live connection but the device is offline.
class TachoUploadRequiresConnection implements Exception {
  const TachoUploadRequiresConnection();
}

/// Thrown when the Phase 4B Wi-Fi-only gate blocks the upload.
class TachoUploadWifiBlocked implements Exception {
  const TachoUploadWifiBlocked();
}

final tachoImportProvider =
    StateNotifierProvider<TachoImportNotifier, TachoImportState>((ref) {
  return TachoImportNotifier(ref);
});

// ── Job status polling (§4.7, 3s until terminal) ──────────────────────

/// Polls `GET /mobile/tacho/import/{job_id}/status` every 3 seconds until a
/// terminal state, then closes the stream (history-export precedent).
final tachoImportJobStatusProvider = StreamProvider.autoDispose
    .family<TachoImportJobState, String>((ref, jobId) {
  return Stream.periodic(const Duration(seconds: 3), (_) => 0)
      .asyncMap((_) async {
        final endpoints = ref.watch(tachoEndpointsProvider);
        final response = await endpoints.importStatus(jobId);
        final data = response.data;
        if (data is! Map<String, dynamic>) {
          return const TachoImportJobState(status: TachoImportStatus.processing);
        }
        return TachoImportJobState.fromJson(data);
      })
      .where((state) => true)
      .takeWhileInclusive((state) => state.status == TachoImportStatus.processing);
});

extension _TachoTakeWhileInclusiveX on Stream<TachoImportJobState> {
  /// Emits items until [test] fails; the failing item is included, then the
  /// stream closes (terminal state is delivered once).
  Stream<TachoImportJobState> takeWhileInclusive(
      bool Function(TachoImportJobState) test) {
    return transform(
      StreamTransformer<TachoImportJobState, TachoImportJobState>.fromHandlers(
        handleData: (data, sink) {
          sink.add(data);
          if (!test(data)) {
            sink.close();
          }
        },
        handleDone: (sink) => sink.close(),
      ),
    );
  }
}
