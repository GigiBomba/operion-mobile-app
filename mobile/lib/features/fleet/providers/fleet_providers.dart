import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/dio_errors.dart';
import '../../../core/network/endpoints/fleet_endpoints.dart';
import '../../../core/network/paginated.dart';
import '../../../core/sync/action_queue.dart';
import '../models/truck.dart';

/// Provides the singleton [FleetEndpoints] wired to the shared [ApiClient].
final fleetEndpointsProvider = Provider<FleetEndpoints>((ref) {
  return FleetEndpoints(ref.read(apiClientProvider));
});

/// True while the fleet list/detail is showing cached (stale) data after a
/// network failure — drives the non-blocking "showing cached data" banner.
final fleetCachedBannerProvider = StateProvider<bool>((ref) => false);

/// Debounced server-side search query for the fleet list.
final fleetSearchProvider = StateProvider<String>((ref) => '');

/// Result of a fleet list fetch.
class FleetListData {
  final List<Truck> trucks;
  final bool fromCache;

  const FleetListData({required this.trucks, required this.fromCache});
}

/// Result of a truck detail fetch.
class TruckDetailData {
  final Truck truck;
  final bool fromCache;

  const TruckDetailData({required this.truck, required this.fromCache});
}

/// Dual-mode fleet list (blueprint §5).
///
/// Tries the network first; on ANY failure it falls back to the LocalDatabase
/// fleet cache and flags [fleetCachedBannerProvider] so the UI can show a
/// non-blocking "cached data" banner. On success the network result replaces
/// the cache and the banner is cleared.
final fleetListProvider =
    FutureProvider.autoDispose<FleetListData>((ref) async {
  final endpoints = ref.watch(fleetEndpointsProvider);
  final search = ref.watch(fleetSearchProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  try {
    final response = await endpoints.getFleet(
      search: search.isEmpty ? null : search,
      cancelToken: cancelToken,
    );
    final data = response.data;
    final trucks = data is Map<String, dynamic>
        ? PaginatedResponse.fromJson(data, Truck.fromJson).items
        : data is List
            ? data.whereType<Map<String, dynamic>>().map(Truck.fromJson).toList()
            : <Truck>[];
    // Refresh the offline cache with the fresh network payload.
    final db = ref.read(localDatabaseProvider);
    await db.cacheFleet(trucks.map((t) => t.toJson()).toList());
    ref.read(fleetCachedBannerProvider.notifier).state = false;
    return FleetListData(trucks: trucks, fromCache: false);
  } catch (e) {
    // Auth rejections (401/403) must surface (force-logout path), not fall
    // back to a stale cache flash (I1). Connection failures stay cached.
    if (isAuthRejection(e)) rethrow;
    final db = ref.read(localDatabaseProvider);
    final cached = await db.getCachedFleet();
    final trucks = cached.map(Truck.fromJson).toList();
    ref.read(fleetCachedBannerProvider.notifier).state = trucks.isNotEmpty;
    return FleetListData(trucks: trucks, fromCache: true);
  }
});

/// Dual-mode truck detail (`GET /mobile/fleet/{id}`), caching to the same
/// `fleet` collection. Rethrows when neither network nor cache can satisfy it.
final truckDetailProvider = FutureProvider.autoDispose
    .family<TruckDetailData, String>((ref, truckId) async {
  final endpoints = ref.watch(fleetEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  try {
    final response = await endpoints.getTruck(truckId, cancelToken: cancelToken);
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected truck detail response: ${data.runtimeType}');
    }
    final truck = Truck.fromJson(data);
    await ref
        .read(localDatabaseProvider)
        .cacheData('fleet', truckId, truck.toJson());
    ref.read(fleetCachedBannerProvider.notifier).state = false;
    return TruckDetailData(truck: truck, fromCache: false);
  } catch (e) {
    // 401/403 must propagate to the force-logout path (I1), not the cache.
    if (isAuthRejection(e)) rethrow;
    final cached = await ref.read(localDatabaseProvider).getCachedData('fleet', truckId);
    if (cached == null) rethrow;
    return TruckDetailData(truck: Truck.fromJson(cached), fromCache: true);
  }
});

/// Maintenance history for a truck (`GET /mobile/fleet/{id}/maintenance`).
final truckMaintenanceHistoryProvider = FutureProvider.autoDispose
    .family<List<TruckMaintenanceRecord>, String>((ref, truckId) async {
  final endpoints = ref.watch(fleetEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final response = await endpoints.getMaintenanceHistory(truckId, cancelToken: cancelToken);
  final data = response.data;
  if (data is Map<String, dynamic>) {
    final items = data['items'];
    if (items is List) {
      return items
          .whereType<Map<String, dynamic>>()
          .map(TruckMaintenanceRecord.fromJson)
          .toList();
    }
  }
  if (data is List) {
    return data.whereType<Map<String, dynamic>>().map(TruckMaintenanceRecord.fromJson).toList();
  }
  return <TruckMaintenanceRecord>[];
});

// ── Mutations (offline → queue per §7) ────────────────────────────────

/// Fleet mutation state: `AsyncValue<void>` where errors surface the failing
/// call. Offline mutations are queued via [actionQueueProvider] (blueprint §7)
/// and succeed locally (no error) so the UI can move on.
final fleetMutationProvider =
    StateNotifierProvider<FleetMutationNotifier, AsyncValue<void>>((ref) {
  return FleetMutationNotifier(ref);
});

/// THE single mutation entry point for recording maintenance work.
///
/// Every call site — the manual record-work sheet (Phase 3 / Truck Detail
/// quick-action, Phase 1), the maintenance screen (Phase 4), and the Copilot
/// `record_maintenance` intent (Phase 5) — must resolve through this
/// top-level function so there is exactly ONE code path for the mutation
/// (blueprint §9 item 4). Top-level function references are identical in
/// Dart, which is what the intent-proof test asserts with `identical`.
Future<void> submitRecordMaintenance(
  WidgetRef ref,
  String truckId,
  MaintenanceRecordDraft draft,
) {
  return ref
      .read(fleetMutationProvider.notifier)
      .recordMaintenance(truckId, draft);
}

class FleetMutationNotifier extends StateNotifier<AsyncValue<void>> {
  FleetMutationNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  bool get _isOffline => _ref.read(isOfflineProvider);

  Future<void> createTruck(TruckDraft draft) async {
    if (_isOffline) {
      await _enqueue('/api/v1/mobile/fleet', 'POST', draft.toJson());
      return;
    }
    state = const AsyncLoading();
    try {
      await _ref.read(fleetEndpointsProvider).createTruck(draft.toJson());
      state = const AsyncData(null);
      _ref.invalidate(fleetListProvider);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> updateTruck(String truckId, TruckUpdateDraft draft) async {
    if (_isOffline) {
      await _enqueue('/api/v1/mobile/fleet/$truckId', 'PATCH', draft.toJson());
      return;
    }
    state = const AsyncLoading();
    try {
      await _ref.read(fleetEndpointsProvider).updateTruck(truckId, draft.toJson());
      state = const AsyncData(null);
      _ref.invalidate(fleetListProvider);
      _ref.invalidate(truckDetailProvider(truckId));
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  /// Irreversible (blueprint §4.1): PATCHes the truck to `Inactive`.
  Future<void> decommissionTruck(String truckId) async {
    if (_isOffline) {
      await _enqueue('/api/v1/mobile/fleet/$truckId', 'PATCH', {'status': 'Inactive'});
      return;
    }
    state = const AsyncLoading();
    try {
      await _ref
          .read(fleetEndpointsProvider)
          .updateTruck(truckId, {'status': 'Inactive'});
      state = const AsyncData(null);
      _ref.invalidate(fleetListProvider);
      _ref.invalidate(truckDetailProvider(truckId));
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> recordMaintenance(String truckId, MaintenanceRecordDraft draft) async {
    if (_isOffline) {
      await _enqueue(
        '/api/v1/mobile/fleet/$truckId/maintenance',
        'POST',
        draft.toJson(),
      );
      return;
    }
    state = const AsyncLoading();
    try {
      await _ref
          .read(fleetEndpointsProvider)
          .addMaintenanceRecord(truckId, draft.toJson());
      state = const AsyncData(null);
      _ref.invalidate(truckMaintenanceHistoryProvider(truckId));
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> _enqueue(
    String endpoint,
    String method,
    Map<String, dynamic> data,
  ) async {
    await _ref.read(actionQueueProvider).enqueue(endpoint, method, data: data);
  }
}
