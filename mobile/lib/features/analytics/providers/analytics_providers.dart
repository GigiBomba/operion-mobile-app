import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_errors.dart';
import '../models/date_range.dart';

/// Endpoint methods for the analytics module (blueprint §6.4).
///
/// All paths are relative to `/api/v1`; every endpoint gates on
/// `can_view_analytics` server-side (dispatcher → 403).
class AnalyticsEndpoints {
  final ApiClient client;

  AnalyticsEndpoints(this.client);

  /// `GET /mobile/analytics/revenue?start_date&end_date&group_by`.
  Future<Response> getRevenue(
    DateRange range, {
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/analytics/revenue',
        queryParameters: {
          'start_date': range.startIso,
          'end_date': range.endIso,
          'group_by': 'period',
        },
        cancelToken: cancelToken,
      );

  /// `GET /mobile/analytics/fleet-utilization?start_date&end_date`.
  Future<Response> getFleetUtilization(
    DateRange range, {
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/analytics/fleet-utilization',
        queryParameters: {
          'start_date': range.startIso,
          'end_date': range.endIso,
        },
        cancelToken: cancelToken,
      );

  /// `GET /mobile/analytics/driver-performance?start_date&end_date`.
  Future<Response> getDriverPerformance(
    DateRange range, {
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/analytics/driver-performance',
        queryParameters: {
          'start_date': range.startIso,
          'end_date': range.endIso,
        },
        cancelToken: cancelToken,
      );

  /// `GET /mobile/analytics/invoice-aging`.
  Future<Response> getInvoiceAging({CancelToken? cancelToken}) =>
      client.get('/api/v1/mobile/analytics/invoice-aging',
          cancelToken: cancelToken);

  /// `GET /mobile/analytics/export?report&start_date&end_date`.
  ///
  /// [report] is one of the backend report names: `revenue`, `fleet`,
  /// `drivers` or `invoice_aging` — matched to the currently active tab.
  Future<Response> export(
    DateRange range, {
    required String report,
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/analytics/export',
        queryParameters: {
          'report': report,
          'start_date': range.startIso,
          'end_date': range.endIso,
        },
        cancelToken: cancelToken,
      );
}

/// Provides the singleton [AnalyticsEndpoints] wired to the shared client.
final analyticsEndpointsProvider = Provider<AnalyticsEndpoints>((ref) {
  return AnalyticsEndpoints(ref.watch(apiClientProvider));
});

/// Shared date-range selection for all analytics tabs (§4.4).
///
/// Defaults to the last 30 days; the segmented selector overwrites it.
final analyticsDateRangeProvider =
    StateProvider<DateRange>((ref) => DateRange.last30Days());

// ── Revenue ──────────────────────────────────────────────────────────────

/// Revenue analytics payload: trend line + per-client/per-route bars.
class RevenueAnalytics {
  const RevenueAnalytics({
    required this.trend,
    required this.perClient,
    required this.perRoute,
  });

  /// `[{label, value}]` time-series trend points.
  final List<ChartPoint> trend;

  /// `[{label, value}]` revenue by client.
  final List<ChartPoint> perClient;

  /// `[{label, value}]` revenue by route.
  final List<ChartPoint> perRoute;

  bool get hasData =>
      trend.isNotEmpty || perClient.isNotEmpty || perRoute.isNotEmpty;

  factory RevenueAnalytics.fromJson(Map<String, dynamic> json) {
    return RevenueAnalytics(
      trend: _points(json['trend']),
      perClient: _points(json['per_client']),
      perRoute: _points(json['per_route']),
    );
  }
}

/// A single named/value chart datum (`{label, value}`).
class ChartPoint {
  const ChartPoint({required this.label, required this.value});

  final String label;
  final double value;

  factory ChartPoint.fromJson(Map<String, dynamic> json) => ChartPoint(
        label: json['label']?.toString() ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0,
      );
}
/// Fetches `GET /mobile/analytics/revenue?start_date&end_date&group_by`.
///
/// [clientId] is optional and currently unused by the contract (kept for
/// §4.4 parity).
final analyticsRevenueProvider = FutureProvider.autoDispose
    .family<RevenueAnalytics, ({DateRange range, String? clientId})>(
        (ref, args) async {
  final endpoints = ref.watch(analyticsEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  try {
    final response = await endpoints.getRevenue(args.range, cancelToken: cancelToken);
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected revenue response: ${data.runtimeType}');
    }
    return RevenueAnalytics.fromJson(data);
  } catch (e) {
    // 401/403 must propagate (force-logout); connection errors surface as
    // the tab error state (analytics has no local cache).
    if (isAuthRejection(e)) rethrow;
    rethrow;
  }
});

// ── Fleet utilization ────────────────────────────────────────────────────

/// Fleet utilization payload: status split + per-truck rows.
class FleetUtilizationAnalytics {
  const FleetUtilizationAnalytics({required this.statusSplit, required this.trucks});

  /// `{active, maintenance, decommissioned}` counts.
  final Map<String, int> statusSplit;

  /// `[{truck, trip_count, total_km}]`.
  final List<Map<String, dynamic>> trucks;

  bool get hasData => statusSplit.isNotEmpty || trucks.isNotEmpty;

  factory FleetUtilizationAnalytics.fromJson(Map<String, dynamic> json) {
    final rawSplit = json['status_split'];
    return FleetUtilizationAnalytics(
      statusSplit: rawSplit is Map<String, dynamic>
          ? rawSplit.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0))
          : const {},
      trucks: json['trucks'] is List
          ? (json['trucks'] as List)
              .whereType<Map<String, dynamic>>()
              .toList()
          : const [],
    );
  }
}

/// Fetches `GET /mobile/analytics/fleet-utilization?start_date&end_date`.
final analyticsFleetUtilizationProvider = FutureProvider.autoDispose
    .family<FleetUtilizationAnalytics, DateRange>((ref, range) async {
  final endpoints = ref.watch(analyticsEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final response = await endpoints.getFleetUtilization(range, cancelToken: cancelToken);
  final data = response.data;
  if (data is! Map<String, dynamic>) {
    throw StateError('Unexpected fleet utilization response: ${data.runtimeType}');
  }
  return FleetUtilizationAnalytics.fromJson(data);
});

// ── Driver performance ───────────────────────────────────────────────────

/// A single driver-performance row.
class DriverPerformanceRow {
  const DriverPerformanceRow({
    required this.driver,
    required this.tripsCompleted,
    required this.onTimePct,
    required this.profitPerKm,
    required this.revenue,
  });

  final String driver;
  final int tripsCompleted;
  final double onTimePct;
  final double profitPerKm;
  final double revenue;

  factory DriverPerformanceRow.fromJson(Map<String, dynamic> json) =>
      DriverPerformanceRow(
        driver: json['driver']?.toString() ?? '',
        tripsCompleted: (json['trips_completed'] as num?)?.toInt() ?? 0,
        onTimePct: (json['on_time_pct'] as num?)?.toDouble() ?? 0,
        profitPerKm: (json['profit_per_km'] as num?)?.toDouble() ?? 0,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      );
}

/// Fetches `GET /mobile/analytics/driver-performance?start_date&end_date`.
///
/// Returns `{rows: [...]}` — no driver-rating field exists in the real
/// backend, so the table shows trips/OTD%/profit-per-km/revenue only (§4.4
/// "REAL WINS" deviation).
final analyticsDriverPerformanceProvider = FutureProvider.autoDispose
    .family<List<DriverPerformanceRow>, DateRange>((ref, range) async {
  final endpoints = ref.watch(analyticsEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final response = await endpoints.getDriverPerformance(range, cancelToken: cancelToken);
  final data = response.data;
  final rawRows = data is Map<String, dynamic> ? data['rows'] : data;
  if (rawRows is! List) return const <DriverPerformanceRow>[];
  return rawRows
      .whereType<Map<String, dynamic>>()
      .map(DriverPerformanceRow.fromJson)
      .toList();
});

// ── Invoice aging ────────────────────────────────────────────────────────

/// Invoice aging buckets from the real backend (§6.4).
class InvoiceAgingReport {
  const InvoiceAgingReport({
    required this.current,
    required this.bucket31_60,
    required this.bucket61_90,
    required this.overdue,
    required this.totalOutstanding,
  });

  final double current;
  final double bucket31_60;
  final double bucket61_90;
  final double overdue;
  final double totalOutstanding;

  bool get hasData =>
      current > 0 || bucket31_60 > 0 || bucket61_90 > 0 || overdue > 0;

  factory InvoiceAgingReport.fromJson(Map<String, dynamic> json) =>
      InvoiceAgingReport(
        current: (json['current'] as num?)?.toDouble() ?? 0,
        bucket31_60: (json['bucket_31_60'] as num?)?.toDouble() ?? 0,
        bucket61_90: (json['bucket_61_90'] as num?)?.toDouble() ?? 0,
        overdue: (json['overdue'] as num?)?.toDouble() ?? 0,
        totalOutstanding: (json['total_outstanding'] as num?)?.toDouble() ?? 0,
      );
}

/// Fetches `GET /mobile/analytics/invoice-aging` (no date params — aging is
/// a snapshot, §6.4).
final analyticsInvoiceAgingProvider =
    FutureProvider.autoDispose<InvoiceAgingReport>((ref) async {
  final endpoints = ref.watch(analyticsEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final response = await endpoints.getInvoiceAging(cancelToken: cancelToken);
  final data = response.data;
  if (data is! Map<String, dynamic>) {
    throw StateError('Unexpected invoice aging response: ${data.runtimeType}');
  }
  return InvoiceAgingReport.fromJson(data);
});

// ── Export ───────────────────────────────────────────────────────────────

/// Result of an analytics export request.
class AnalyticsExportResult {
  const AnalyticsExportResult({required this.downloadUrl, this.expiresAt});

  final String downloadUrl;
  final DateTime? expiresAt;

  factory AnalyticsExportResult.fromJson(Map<String, dynamic> json) =>
      AnalyticsExportResult(
        downloadUrl: json['download_url']?.toString() ?? '',
        expiresAt: json['expires_at'] != null
            ? DateTime.tryParse(json['expires_at'].toString())
            : null,
      );
}

/// Triggers `GET /mobile/analytics/export?report&start_date&end_date`.
///
/// Synchronous generation returns a signed 10-minute download URL; the caller
/// opens the OS share sheet with that URL (§4.4). Never queued offline.
/// [report] matches the currently active analytics tab.
final analyticsExportProvider = FutureProvider.autoDispose
    .family<AnalyticsExportResult, ({DateRange range, String report})>(
        (ref, args) async {
  final endpoints = ref.watch(analyticsEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final response =
      await endpoints.export(args.range, report: args.report, cancelToken: cancelToken);
  final data = response.data;
  if (data is! Map<String, dynamic>) {
    throw StateError('Unexpected analytics export response: ${data.runtimeType}');
  }
  return AnalyticsExportResult.fromJson(data);
});

// ── Helpers ──────────────────────────────────────────────────────────────

List<ChartPoint> _points(dynamic raw) {
  if (raw is! List) return const <ChartPoint>[];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(ChartPoint.fromJson)
      .toList();
}
