import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../../../core/sync/wifi_gate.dart';

/// Endpoint methods for the history module (blueprint §6.8).
///
/// All paths are relative to `/api/v1`. List endpoints gate on
/// `require_dispatcher`; exports gate on `can_export_data`.
class HistoryEndpoints {
  final ApiClient client;

  HistoryEndpoints(this.client);

  /// `GET /mobile/history/trips?status&client_id&start_date&end_date&page&page_size`.
  Future<Response> getTrips(
    TripHistoryFilter filter, {
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/history/trips',
        queryParameters: filter.toQuery(),
        cancelToken: cancelToken,
      );

  /// `GET /mobile/history/routes?page&page_size&start_date&end_date`.
  Future<Response> getRoutes(
    RouteHistoryFilter filter, {
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/history/routes',
        queryParameters: filter.toQuery(),
        cancelToken: cancelToken,
      );

  /// `GET /mobile/history/routes/{route_id}/thumbnail` — schematic polyline
  /// PNG (~320×180), `require_dispatcher`, 404 on missing/cross-company/no
  /// geometry rows.
  ///
  /// Returns a path relative to the API base URL (matching the convention
  /// that endpoints expose paths and the caller/Dio applies the base URL).
  /// Callers that need an absolute URL — e.g. `Image.network` — must prepend
  /// the API base URL themselves (the app's `AppConstants.baseUrl`, which is
  /// what `ApiClient` is configured with). Static because it is pure URL
  /// construction and the screen must be able to build it without touching
  /// the ApiClient/provider graph (e.g. in widget tests that stub the data
  /// provider directly).
  static String routeThumbnailUrl(String routeId) =>
      '/api/v1/mobile/history/routes/$routeId/thumbnail';

  /// `POST /mobile/history/trips/export` → 202 {job_id}.
  Future<Response> exportTrips(
    TripExportRequest request, {
    CancelToken? cancelToken,
  }) =>
      client.post(
        '/api/v1/mobile/history/trips/export',
        data: request.toJson(),
        cancelToken: cancelToken,
      );

  /// `GET /mobile/history/trips/export/{job_id}/status`.
  Future<Response> exportStatus(
    String jobId, {
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/history/trips/export/$jobId/status',
        cancelToken: cancelToken,
      );
}

/// Provides the singleton [HistoryEndpoints] wired to the shared client.
final historyEndpointsProvider = Provider<HistoryEndpoints>((ref) {
  return HistoryEndpoints(ref.watch(apiClientProvider));
});

// ── Filters ───────────────────────────────────────────────────────────────

/// Filter state for the trip-history list (§4.8).
class TripHistoryFilter {
  const TripHistoryFilter({
    this.status,
    this.clientId,
    this.startDate,
    this.endDate,
    this.page = 1,
    this.pageSize = 20,
  });

  final String? status;
  final String? clientId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int page;
  final int pageSize;

  /// A copy with a different page (infinite-scroll increments).
  TripHistoryFilter copyWith({
    String? status,
    String? clientId,
    DateTime? startDate,
    DateTime? endDate,
    int? page,
    int? pageSize,
  }) {
    return TripHistoryFilter(
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  Map<String, dynamic> toQuery() {
    return {
      if (status != null && status!.isNotEmpty) 'status': status,
      if (clientId != null && clientId!.isNotEmpty) 'client_id': clientId,
      if (startDate != null) 'start_date': _iso(startDate!),
      if (endDate != null) 'end_date': _iso(endDate!),
      'page': page,
      'page_size': pageSize,
    };
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is TripHistoryFilter &&
      other.status == status &&
      other.clientId == clientId &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(status, clientId, startDate, endDate, page, pageSize);
}

/// Filter state for the route-history list (§4.8).
class RouteHistoryFilter {
  const RouteHistoryFilter({
    this.startDate,
    this.endDate,
    this.page = 1,
    this.pageSize = 20,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final int page;
  final int pageSize;

  RouteHistoryFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? page,
    int? pageSize,
  }) {
    return RouteHistoryFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  Map<String, dynamic> toQuery() {
    return {
      if (startDate != null)
        'start_date':
            '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
      if (endDate != null)
        'end_date':
            '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
      'page': page,
      'page_size': pageSize,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is RouteHistoryFilter &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(startDate, endDate, page, pageSize);
}

// ── Models ────────────────────────────────────────────────────────────────

/// A trip-history row (`TripHistoryOut`).
class TripHistoryEntry {
  const TripHistoryEntry({
    required this.id,
    required this.clientName,
    required this.truckNumber,
    required this.driverName,
    required this.origin,
    required this.destination,
    required this.status,
    this.startDate,
    this.endDate,
    this.distanceKm,
    this.totalPriceEur,
    this.netProfit,
  });

  final int id;
  final String clientName;
  final String truckNumber;
  final String driverName;
  final String origin;
  final String destination;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? distanceKm;
  final double? totalPriceEur;
  final double? netProfit;

  factory TripHistoryEntry.fromJson(Map<String, dynamic> json) =>
      TripHistoryEntry(
        id: (json['id'] as num?)?.toInt() ?? 0,
        clientName: json['client_name']?.toString() ?? '',
        truckNumber: json['truck_number']?.toString() ?? '',
        driverName: json['driver_name']?.toString() ?? '',
        origin: json['origin']?.toString() ?? '',
        destination: json['destination']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        startDate: json['start_date'] != null
            ? DateTime.tryParse(json['start_date'].toString())
            : null,
        endDate: json['end_date'] != null
            ? DateTime.tryParse(json['end_date'].toString())
            : null,
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        totalPriceEur: (json['total_price_eur'] as num?)?.toDouble(),
        netProfit: (json['net_profit'] as num?)?.toDouble(),
      );
}

/// A route-history row (`RouteHistoryOut`).
class RouteHistoryEntry {
  const RouteHistoryEntry({
    required this.id,
    required this.name,
    required this.origin,
    required this.destination,
    this.totalDistanceKm,
    this.durationMin,
    this.createdAt,
  });

  final int id;
  final String name;
  final String origin;
  final String destination;
  final double? totalDistanceKm;
  final int? durationMin;
  final DateTime? createdAt;

  factory RouteHistoryEntry.fromJson(Map<String, dynamic> json) =>
      RouteHistoryEntry(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
        origin: json['origin']?.toString() ?? '',
        destination: json['destination']?.toString() ?? '',
        totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble(),
        durationMin: (json['duration_min'] as num?)?.toInt(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
      );
}

// ── Providers ─────────────────────────────────────────────────────────────

/// Fetches `GET /mobile/history/trips` (paginated).
final tripHistoryProvider = FutureProvider.autoDispose
    .family<PaginatedResponse<TripHistoryEntry>, TripHistoryFilter>(
        (ref, filter) async {
  final endpoints = ref.watch(historyEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final response =
      await endpoints.getTrips(filter, cancelToken: cancelToken);
  final data = response.data;
  if (data is! Map<String, dynamic>) {
    throw StateError('Unexpected trip history response: ${data.runtimeType}');
  }
  return PaginatedResponse.fromJson(data, TripHistoryEntry.fromJson);
});

/// Fetches `GET /mobile/history/routes` (paginated).
final routeHistoryProvider = FutureProvider.autoDispose
    .family<PaginatedResponse<RouteHistoryEntry>, RouteHistoryFilter>(
        (ref, filter) async {
  final endpoints = ref.watch(historyEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final response =
      await endpoints.getRoutes(filter, cancelToken: cancelToken);
  final data = response.data;
  if (data is! Map<String, dynamic>) {
    throw StateError('Unexpected route history response: ${data.runtimeType}');
  }
  return PaginatedResponse.fromJson(data, RouteHistoryEntry.fromJson);
});

// ── Export (async job + polling) ─────────────────────────────────────────

/// The immutable filter subset sent with an export job.
class TripExportRequest {
  const TripExportRequest({
    this.format = 'csv',
    this.status,
    this.clientId,
    this.startDate,
    this.endDate,
  });

  final String format;
  final String? status;
  final String? clientId;
  final DateTime? startDate;
  final DateTime? endDate;

  Map<String, dynamic> toJson() => {
        'format': format,
        'filters': {
          if (status != null && status!.isNotEmpty) 'status': status,
          if (clientId != null && clientId!.isNotEmpty) 'client_id': clientId,
          if (startDate != null)
            'start_date':
                '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
          if (endDate != null)
            'end_date':
                '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
        },
      };
}

/// Kicks off an async trip-history export: `POST /mobile/history/trips/export`
/// → `202 {job_id}`.
///
/// Phase 4B §4.10 Wi-Fi gate: blocked with [WifiGateBlocked] when "Wi-Fi only
/// for large syncs" is on and the device is on cellular — never queued.
final tripHistoryExportProvider = FutureProvider.autoDispose
    .family<String, TripExportRequest>((ref, request) async {
  if (ref.watch(wifiGateProvider).blocksLargeTransfer) {
    throw const WifiGateBlocked();
  }
  final endpoints = ref.watch(historyEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final response =
      await endpoints.exportTrips(request, cancelToken: cancelToken);
  final data = response.data;
  if (data is! Map<String, dynamic>) {
    throw StateError('Unexpected export response: ${data.runtimeType}');
  }
  final jobId = data['job_id']?.toString();
  if (jobId == null || jobId.isEmpty) {
    throw StateError('Export response missing job_id');
  }
  return jobId;
});

/// Status of an async export job.
enum ExportJobStatus { processing, success, error }

/// Parsed export-job status payload.
class ExportJobState {
  const ExportJobState({required this.status, this.downloadUrl});

  final ExportJobStatus status;
  final String? downloadUrl;

  bool get isTerminal => status != ExportJobStatus.processing;

  factory ExportJobState.fromJson(Map<String, dynamic> json) {
    final status = switch (json['status']?.toString()) {
      'success' => ExportJobStatus.success,
      'error' => ExportJobStatus.error,
      _ => ExportJobStatus.processing,
    };
    return ExportJobState(
      status: status,
      downloadUrl: json['download_url']?.toString(),
    );
  }
}

/// Polls `GET /mobile/history/trips/export/{job_id}/status` every 3 seconds
/// until a terminal state (success|error), then the stream closes.
final exportJobStatusProvider = StreamProvider.autoDispose
    .family<ExportJobState, String>((ref, jobId) {
  return Stream.periodic(const Duration(seconds: 3), (_) => 0)
      .asyncMap((_) async {
        final endpoints = ref.watch(historyEndpointsProvider);
        final response = await endpoints.exportStatus(jobId);
        final data = response.data;
        if (data is! Map<String, dynamic>) {
          return const ExportJobState(status: ExportJobStatus.processing);
        }
        return ExportJobState.fromJson(data);
      })
      .where((state) => true)
      .takeWhileInclusive((state) => state.status == ExportJobStatus.processing);
});

extension _TakeWhileInclusiveX on Stream<ExportJobState> {
  /// Emits items until [test] fails; the failing item is included, then the
  /// stream closes (terminal state is delivered once).
  Stream<ExportJobState> takeWhileInclusive(bool Function(ExportJobState) test) {
    return transform(
      StreamTransformer<ExportJobState, ExportJobState>.fromHandlers(
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
