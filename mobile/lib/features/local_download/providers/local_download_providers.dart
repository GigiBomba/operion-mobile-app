import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/api_client.dart';
import '../models/download_manifest.dart';

/// Selected category + optional date range for a manifest request.
class DownloadRequestFilter {
  final DownloadCategory category;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const DownloadRequestFilter({
    required this.category,
    this.dateFrom,
    this.dateTo,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadRequestFilter &&
          category == other.category &&
          dateFrom == other.dateFrom &&
          dateTo == other.dateTo;

  @override
  int get hashCode => Object.hash(category, dateFrom, dateTo);

  @override
  String toString() =>
      'DownloadRequestFilter(category: ${category.apiValue}, '
      'from: $dateFrom, to: $dateTo)';
}

/// Endpoint methods for Local Download.
class LocalDownloadEndpoints {
  final ApiClient client;

  LocalDownloadEndpoints(this.client);

  /// `POST /api/v1/mobile/company/export/manifest` — returns a list of
  /// signed, short-lived download entries.
  Future<Response> fetchManifest({
    required DownloadCategory category,
    DateTime? dateFrom,
    DateTime? dateTo,
    CancelToken? cancelToken,
  }) {
    return client.post(
      '/api/v1/mobile/company/export/manifest',
      data: {
        'category': category.apiValue,
        if (dateFrom != null) 'date_from': _isoDate(dateFrom),
        if (dateTo != null) 'date_to': _isoDate(dateTo),
      },
      cancelToken: cancelToken,
    );
  }

  /// Downloads [downloadUrl] to [savePath] reporting progress via
  /// [onReceiveProgress]. The URL is a short-lived signed URL resolved
  /// against the configured base URL by Dio.
  Future<Response> downloadFile(
    String downloadUrl,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) {
    return client.dio.download(
      downloadUrl,
      savePath,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    );
  }

  static String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

final localDownloadEndpointsProvider = Provider<LocalDownloadEndpoints>((ref) {
  return LocalDownloadEndpoints(ref.read(apiClientProvider));
});

/// The category + date-range selected in the UI.
final localDownloadFilterProvider =
    StateProvider<DownloadRequestFilter?>((ref) => null);

/// Fetches the download manifest for [filter].
///
/// `POST /api/v1/mobile/company/export/manifest` with `{category,
/// date_from?, date_to?}`. The response is a list of
/// `DownloadManifestEntry` objects (signed, short-lived URLs).
///
/// Owns a [CancelToken] per in-flight request tied to the provider lifecycle
/// (§1.2): navigating away disposes the family instance and cancels the
/// call — a disposed provider has no listeners, so the cancellation never
/// surfaces as an error state.
final downloadManifestProvider = FutureProvider.family<
    List<DownloadManifestEntry>,
    DownloadRequestFilter>((ref, filter) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final endpoints = ref.watch(localDownloadEndpointsProvider);
  final response = await endpoints.fetchManifest(
    category: filter.category,
    dateFrom: filter.dateFrom,
    dateTo: filter.dateTo,
    cancelToken: cancelToken,
  );
  final data = response.data;
  if (data is List) {
    return data
        .whereType<Map<String, dynamic>>()
        .map(DownloadManifestEntry.fromJson)
        .toList();
  }
  throw StateError('Unexpected manifest response: ${data.runtimeType}');
});

/// Per-file download progress.
class DownloadFileStatus {
  final String recordId;
  final String filename;
  final double progress; // 0.0 .. 1.0
  final bool completed;
  final String? error;

  const DownloadFileStatus({
    required this.recordId,
    required this.filename,
    this.progress = 0,
    this.completed = false,
    this.error,
  });

  DownloadFileStatus copyWith({
    double? progress,
    bool? completed,
    String? error,
  }) {
    return DownloadFileStatus(
      recordId: recordId,
      filename: filename,
      progress: progress ?? this.progress,
      completed: completed ?? this.completed,
      error: error ?? this.error,
    );
  }
}

/// State of the per-file Local Download flow.
class LocalDownloadState {
  final bool isDownloading;

  /// Per-file status keyed by record id.
  final Map<String, DownloadFileStatus> files;

  const LocalDownloadState({
    this.isDownloading = false,
    this.files = const {},
  });
}

/// Pull-on-demand download notifier.
///
/// This feature is intentionally pull-on-demand only: nothing in here (or
/// anywhere in `lib/features/local_download/`) registers background work or
/// schedules anything to run without an explicit user action.
class LocalDownloadNotifier extends StateNotifier<LocalDownloadState> {
  final LocalDownloadEndpoints _endpoints;

  /// Overridable documents-directory resolver (test injection).
  final Future<Directory> Function() _directoryProvider;

  /// One [CancelToken] per notifier lifecycle (§1.2).
  ///
  /// Every per-file download carries it; [dispose] cancels it so navigating
  /// away mid-download never leaves a stray transfer or surfaces a spurious
  /// per-file error state.
  final CancelToken _cancelToken = CancelToken();

  LocalDownloadNotifier(
    this._endpoints, {
    Future<Directory> Function()? directoryProvider,
  })  : _directoryProvider =
            directoryProvider ?? _defaultDocumentsDirectory,
        super(const LocalDownloadState());

  /// The notifier's in-flight [CancelToken] (test seam).
  @visibleForTesting
  CancelToken get cancelToken => _cancelToken;

  @override
  void dispose() {
    _cancelToken.cancel();
    super.dispose();
  }

  static Future<Directory> _defaultDocumentsDirectory() async {
    return getApplicationDocumentsDirectory();
  }

  /// Downloads every [entry] to the documents directory with per-file
  /// progress updates.
  Future<void> startDownloads(List<DownloadManifestEntry> entries) async {
    if (state.isDownloading) return;
    state = LocalDownloadState(
      isDownloading: true,
      files: {
        for (final entry in entries)
          entry.recordId: DownloadFileStatus(
            recordId: entry.recordId,
            filename: entry.filename,
          ),
      },
    );

    // The documents directory is guaranteed to exist in production
    // (path_provider) and is test-injectable via [_directoryProvider].
    final dir = await _directoryProvider();

    for (final entry in entries) {
      final savePath = '${dir.path}${Platform.pathSeparator}${entry.filename}';
      try {
        await _endpoints.downloadFile(
          entry.downloadUrl,
          savePath,
          onReceiveProgress: (received, total) {
            final ratio = total > 0 ? received / total : 0.0;
            _updateFile(
              entry.recordId,
              (status) => status.copyWith(progress: ratio.clamp(0.0, 1.0)),
            );
          },
          cancelToken: _cancelToken,
        );
        _updateFile(
          entry.recordId,
          (status) => status.copyWith(progress: 1.0, completed: true),
        );
      } on DioException catch (e) {
        // Cancelling the token on dispose must never surface as an error.
        if (e.type == DioExceptionType.cancel) break;
        _updateFile(
          entry.recordId,
          (status) => status.copyWith(error: e.message),
        );
      } catch (_) {
        _updateFile(
          entry.recordId,
          (status) => status.copyWith(
            error: 'Unexpected download error.',
          ),
        );
      }
    }

    state = LocalDownloadState(isDownloading: false, files: state.files);
  }

  void _updateFile(
    String recordId,
    DownloadFileStatus Function(DownloadFileStatus) transform,
  ) {
    final current = state.files[recordId];
    if (current == null) return;
    state = LocalDownloadState(
      isDownloading: state.isDownloading,
      files: {
        ...state.files,
        recordId: transform(current),
      },
    );
  }

  void reset() => state = const LocalDownloadState();
}

final localDownloadProvider =
    StateNotifierProvider<LocalDownloadNotifier, LocalDownloadState>((ref) {
  return LocalDownloadNotifier(ref.read(localDownloadEndpointsProvider));
});
