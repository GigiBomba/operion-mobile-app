import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../../../core/sync/action_queue.dart';
import '../models/maintenance.dart';

/// Endpoint methods for the maintenance module (blueprint §4.6/§6.5).
class MaintenanceEndpoints {
  final ApiClient client;

  MaintenanceEndpoints(this.client);

  /// `GET /mobile/maintenance/schedule?overdue_only&page&page_size`.
  Future<Response> getSchedule(
    MaintenanceScheduleFilter filter, {
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/maintenance/schedule',
        queryParameters: filter.toQuery(),
        cancelToken: cancelToken,
      );

  /// `POST /mobile/maintenance/schedule` (create a schedule).
  Future<Response> createSchedule(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) =>
      client.post('/api/v1/mobile/maintenance/schedule',
          data: data, cancelToken: cancelToken);

  /// `GET /mobile/maintenance/cost-trend?start_date&end_date`.
  Future<Response> getCostTrend(
    CostTrendRange range, {
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/maintenance/cost-trend',
        queryParameters: range.toQuery(),
        cancelToken: cancelToken,
      );
}

/// Provides the singleton [MaintenanceEndpoints] wired to the shared client.
final maintenanceEndpointsProvider = Provider<MaintenanceEndpoints>((ref) {
  return MaintenanceEndpoints(ref.watch(apiClientProvider));
});

// ── Schedule filter & providers ────────────────────────────────────────

/// Filter state for the maintenance schedule list.
class MaintenanceScheduleFilter {
  final bool overdueOnly;
  final int page;
  final int pageSize;

  const MaintenanceScheduleFilter({
    this.overdueOnly = false,
    this.page = 1,
    this.pageSize = 20,
  });

  MaintenanceScheduleFilter copyWith({
    bool? overdueOnly,
    int? page,
    int? pageSize,
  }) {
    return MaintenanceScheduleFilter(
      overdueOnly: overdueOnly ?? this.overdueOnly,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  Map<String, dynamic> toQuery() => {
        if (overdueOnly) 'overdue_only': 'true',
        'page': page,
        'page_size': pageSize,
      };

  @override
  bool operator ==(Object other) =>
      other is MaintenanceScheduleFilter &&
      other.overdueOnly == overdueOnly &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(overdueOnly, page, pageSize);
}

/// The current schedule filter (drives the family key).
final maintenanceScheduleFilterProvider =
    StateProvider<MaintenanceScheduleFilter>(
  (ref) => const MaintenanceScheduleFilter(),
);

/// Fetches `GET /mobile/maintenance/schedule`.
final maintenanceScheduleProvider = FutureProvider.autoDispose
    .family<PaginatedResponse<MaintenanceScheduleItem>, MaintenanceScheduleFilter>(
        (ref, filter) async {
  final endpoints = ref.watch(maintenanceEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final response =
      await endpoints.getSchedule(filter, cancelToken: cancelToken);
  final data = response.data;
  if (data is! Map<String, dynamic>) {
    throw StateError('Unexpected maintenance schedule response: ${data.runtimeType}');
  }
  return PaginatedResponse.fromJson(data, MaintenanceScheduleItem.fromJson);
});

// ── Cost-trend range & provider ────────────────────────────────────────

/// Date range for the cost-trend query.
class CostTrendRange {
  final DateTime? startDate;
  final DateTime? endDate;

  const CostTrendRange({this.startDate, this.endDate});

  Map<String, dynamic> toQuery() => {
        if (startDate != null) 'start_date': _iso(startDate!),
        if (endDate != null) 'end_date': _iso(endDate!),
      };

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is CostTrendRange &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(startDate, endDate);
}

/// The current cost-trend range (defaults to the last 12 months).
final maintenanceCostTrendRangeProvider =
    StateProvider<CostTrendRange>((ref) {
  final now = DateTime.now();
  return CostTrendRange(
    startDate: DateTime(now.year - 1, now.month, now.day),
    endDate: now,
  );
});

/// Fetches `GET /mobile/maintenance/cost-trend`.
final maintenanceCostTrendProvider = FutureProvider.autoDispose
    .family<CostTrendData, CostTrendRange>((ref, range) async {
  final endpoints = ref.watch(maintenanceEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final response = await endpoints.getCostTrend(range, cancelToken: cancelToken);
  final data = response.data;
  if (data is! Map<String, dynamic>) {
    throw StateError('Unexpected cost-trend response: ${data.runtimeType}');
  }
  return CostTrendData.fromJson(data);
});

// ── Schedule mutation (offline → queue per §7) ─────────────────────────

/// Maintenance mutation state. `scheduleMaintenance` is queueable offline
/// (blueprint §7) — unlike the finance transitions that never queue.
final maintenanceMutationProvider =
    StateNotifierProvider<MaintenanceMutationNotifier, AsyncValue<void>>((ref) {
  return MaintenanceMutationNotifier(ref);
});

class MaintenanceMutationNotifier extends StateNotifier<AsyncValue<void>> {
  MaintenanceMutationNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  bool get _isOffline => _ref.read(isOfflineProvider);

  Future<void> scheduleMaintenance(MaintenanceScheduleDraft draft) async {
    if (_isOffline) {
      await _ref
          .read(actionQueueProvider)
          .enqueue('/api/v1/mobile/maintenance/schedule', 'POST',
              data: draft.toJson());
      return;
    }
    state = const AsyncLoading();
    try {
      await _ref
          .read(maintenanceEndpointsProvider)
          .createSchedule(draft.toJson());
      state = const AsyncData(null);
      _ref.invalidate(
          maintenanceScheduleProvider(_ref.read(maintenanceScheduleFilterProvider)));
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
}
