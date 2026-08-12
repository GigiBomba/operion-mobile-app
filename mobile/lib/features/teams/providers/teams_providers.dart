import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/dio_errors.dart';
import '../../../core/network/endpoints/drivers_endpoints.dart';
import '../../../core/network/paginated.dart';
import '../../../core/sync/action_queue.dart';
import '../../../shared/models/driver.dart';
import '../models/tacho.dart';

/// Backend constant for the license-expiry "expiring soon" window.
///
/// Mirrors `driver_repository.get_expiring_licenses` default of 30 days in the
/// backend repo (`Calculator logistica`). Used by the Expiring filter chip and
/// the [ExpiryBadge] thresholds — do NOT hardcode 30 elsewhere.
const int kExpiringLicensesDefaultDays = 30;

/// Driver status filter options (blueprint §4.2).
enum DriverFilter { all, available, driving, off, expiring }

/// Current filter selection for the Teams driver list.
final teamsFilterProvider =
    StateProvider<DriverFilter>((ref) => DriverFilter.all);

/// Maps a [DriverFilter] to the backend driver status value.
///
/// `DriverFilter.all` and `DriverFilter.expiring` map to the empty string:
/// "all" is not a concrete backend status and "expiring" is a server-side
/// date window (`expiring_within_days=30`), not a status value.
String filterToStatus(DriverFilter filter) {
  switch (filter) {
    case DriverFilter.available:
      return 'available';
    case DriverFilter.driving:
      return 'driving';
    case DriverFilter.off:
      return 'off';
    case DriverFilter.all:
    case DriverFilter.expiring:
      return '';
  }
}

/// Pure filtering logic for the Teams driver list.
///
/// When a specific status [filter] is selected, drivers with an empty or
/// absent `status` are excluded. [DriverFilter.all] and
/// [DriverFilter.expiring] return the list unchanged (the Expiring window is
/// applied server-side via `expiring_within_days`).
List<Map<String, dynamic>> filterDriversByStatus(
  List<Map<String, dynamic>> drivers,
  DriverFilter filter,
) {
  if (filter == DriverFilter.all || filter == DriverFilter.expiring) {
    return drivers;
  }
  final status = filterToStatus(filter);
  return drivers
      .where((d) => (d['status'] as String? ?? '') == status)
      .toList();
}

/// True while the drivers list/detail is showing cached (stale) data after a
/// network failure — drives the non-blocking "showing cached data" banner.
final driversCachedBannerProvider = StateProvider<bool>((ref) => false);

/// The driver list shown by the Teams screen.
///
/// Dual-mode (blueprint §5): fetches `GET /api/v1/mobile/drivers` (paginated
/// envelope) with `page`/`page_size`, `search`, `status` and
/// `expiring_within_days` (server-side license-expiry window, active when the
/// [teamsFilterProvider] is `expiring`). On success the payload refreshes the
/// LocalDatabase drivers cache and clears the banner; on a connection failure
/// it falls back to [LocalDatabase.getCachedDrivers] and flags
/// [driversCachedBannerProvider]. 401/403 rejections propagate (I1). Owns a
/// [CancelToken] per in-flight request tied to the provider lifecycle (§1.2).
final teamsDriversProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final filter = ref.watch(teamsFilterProvider);
  final endpoints = ref.watch(driversEndpointsProvider);
  final status = filterToStatus(filter);
  final expiringWithinDays =
      filter == DriverFilter.expiring ? kExpiringLicensesDefaultDays : null;
  try {
    final response = await endpoints.getDrivers(
      status: status.isEmpty ? null : status,
      expiringWithinDays: expiringWithinDays,
      page: 1,
      pageSize: 20,
      cancelToken: cancelToken,
    );
    final data = response.data;
    final drivers = data is Map<String, dynamic>
        ? PaginatedResponse.fromJson(data, (m) => m).items
        : data is List
            ? data.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
    // Refresh the offline cache with the fresh network payload.
    await ref.read(localDatabaseProvider).cacheDrivers(drivers);
    ref.read(driversCachedBannerProvider.notifier).state = false;
    return drivers;
  } catch (e) {
    // Auth rejections (401/403) must surface (force-logout path), not fall
    // back to a stale cache flash (I1). Connection failures stay cached.
    if (isAuthRejection(e)) rethrow;
    final cached = await ref.read(localDatabaseProvider).getCachedDrivers();
    ref.read(driversCachedBannerProvider.notifier).state = cached.isNotEmpty;
    return cached;
  }
});

/// The driver list shown by the Teams screen, filtered by [teamsFilterProvider].
///
/// Keeps filtering out of `build()` — the screen only renders this list.
final teamsFilteredDriversProvider =
    Provider<List<Map<String, dynamic>>>((ref) {
  final drivers = ref.watch(teamsDriversProvider).value ?? const [];
  return filterDriversByStatus(drivers, ref.watch(teamsFilterProvider));
});

// ── Driver detail (license info) ───────────────────────────────────────────

/// Expiry status of a driver's license or medical certificate.
///
/// Pure classification helper — the date comparison lives here, never in a
/// `build()` method (§1.1). [now] is injectable so tests can pin the clock.
enum LicenseExpiryStatus { valid, expiringSoon, expired }

/// Classifies [expiry] against [now]:
/// - `null` → [LicenseExpiryStatus.valid] (no data, nothing to flag);
/// - more than 30 days out → valid;
/// - within the next 30 days → expiring soon;
/// - in the past → expired.
LicenseExpiryStatus licenseExpiryStatusFor(
  DateTime? expiry, {
  DateTime? now,
}) {
  if (expiry == null) return LicenseExpiryStatus.valid;
  final reference = now ?? DateTime.now();
  final cutoff =
      reference.add(const Duration(days: kExpiringLicensesDefaultDays));
  if (expiry.isBefore(reference)) return LicenseExpiryStatus.expired;
  if (expiry.isBefore(cutoff)) return LicenseExpiryStatus.expiringSoon;
  return LicenseExpiryStatus.valid;
}

/// Immutable, parsed result of `GET /api/v1/mobile/drivers/{id}` (DriverOut).
///
/// Phase 1B extension: adds `adr_certificate_expiry` and `current_truck_id`
/// (both also parsed from camelCase keys for legacy payloads).
class DriverDetail {
  final int id;
  final String name;
  final String phone;
  final String email;
  final String licenseNumber;
  final String licenseCategory;
  final DateTime? licenseExpiry;
  final DateTime? medicalExpiry;
  final DateTime? adrCertificateExpiry;
  final String? currentTruckId;

  const DriverDetail({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.licenseNumber = '',
    this.licenseCategory = '',
    this.licenseExpiry,
    this.medicalExpiry,
    this.adrCertificateExpiry,
    this.currentTruckId,
  });

  factory DriverDetail.fromJson(Map<String, dynamic> json) => DriverDetail(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        licenseNumber: json['license_number'] as String? ?? '',
        licenseCategory: json['license_category'] as String? ?? '',
        licenseExpiry: json['license_expiry'] != null
            ? DateTime.tryParse(json['license_expiry'] as String)
            : null,
        medicalExpiry: json['medical_expiry'] != null
            ? DateTime.tryParse(json['medical_expiry'] as String)
            : null,
        adrCertificateExpiry: json['adr_certificate_expiry'] != null
            ? DateTime.tryParse(json['adr_certificate_expiry'] as String)
            : null,
        currentTruckId: json['current_truck_id']?.toString(),
      );
}

/// Result of a driver detail fetch.
class DriverDetailData {
  final DriverDetail driver;
  final bool fromCache;

  const DriverDetailData({required this.driver, required this.fromCache});
}

/// Fetches the company-scoped driver detail (`GET /api/v1/mobile/drivers/{id}` —
/// the full DriverOut shape incl. `adr_certificate_expiry` and
/// `current_truck_id`).
///
/// Dual-mode (blueprint §5): caches the detail in the `drivers` collection by
/// id on success (following the truckDetailProvider precedent); on a
/// connection failure reads the cached entry and flags
/// [driversCachedBannerProvider]. 401/403 propagate (I1). Rethrows when
/// neither network nor cache can satisfy it. Owns a [CancelToken] per
/// in-flight request (§1.2).
final driverDetailProvider = FutureProvider.autoDispose
    .family<DriverDetailData, String>((ref, driverId) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final endpoints = ref.watch(driversEndpointsProvider);
  try {
    final response =
        await endpoints.getDriverDetail(driverId, cancelToken: cancelToken);
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected driver detail response: ${data.runtimeType}');
    }
    final detail = DriverDetail.fromJson(data);
    await ref
        .read(localDatabaseProvider)
        .cacheData('drivers', driverId, data);
    ref.read(driversCachedBannerProvider.notifier).state = false;
    return DriverDetailData(driver: detail, fromCache: false);
  } catch (e) {
    // 401/403 must propagate to the force-logout path (I1), not the cache.
    if (isAuthRejection(e)) rethrow;
    final cached =
        await ref.read(localDatabaseProvider).getCachedData('drivers', driverId);
    if (cached == null) rethrow;
    return DriverDetailData(
      driver: DriverDetail.fromJson(cached),
      fromCache: true,
    );
  }
});

// ── Tacho timeline (blueprint §4.2) ───────────────────────────────────────

/// Provides the singleton [DriversEndpoints] wired to the shared [ApiClient].
final driversEndpointsProvider = Provider<DriversEndpoints>((ref) {
  return DriversEndpoints(ref.read(apiClientProvider));
});

/// Fetches a driver's tacho week (`GET /mobile/drivers/{id}/tacho`).
///
/// Returns the 7-day timeline plus weekly aggregates. Owns a [CancelToken]
/// per in-flight request (§1.2).
final driverTachoProvider = FutureProvider.autoDispose
    .family<TachoWeek, String>((ref, driverId) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final endpoints = ref.watch(driversEndpointsProvider);
  final response = await endpoints.getTacho(driverId, cancelToken: cancelToken);
  final data = response.data;
  if (data is! Map<String, dynamic>) {
    throw StateError('Unexpected tacho response: ${data.runtimeType}');
  }
  return TachoWeek.fromJson(data);
});

// ── Driver mutations (offline → queue per §7) ─────────────────────────────

/// Driver mutation state.
final driverMutationProvider =
    StateNotifierProvider<DriverMutationNotifier, AsyncValue<void>>((ref) {
  return DriverMutationNotifier(ref);
});

class DriverMutationNotifier extends StateNotifier<AsyncValue<void>> {
  DriverMutationNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  bool get _isOffline => _ref.read(isOfflineProvider);

  Future<void> createDriver(DriverDraft draft) async {
    if (_isOffline) {
      await _enqueue('/api/v1/mobile/drivers', 'POST', draft.toJson());
      return;
    }
    state = const AsyncLoading();
    try {
      await _ref.read(driversEndpointsProvider).createDriver(draft.toJson());
      state = const AsyncData(null);
      _ref.invalidate(teamsDriversProvider);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> updateDriver(String driverId, DriverDraft draft) async {
    if (_isOffline) {
      await _enqueue('/api/v1/mobile/drivers/$driverId', 'PATCH', draft.toJson());
      return;
    }
    state = const AsyncLoading();
    try {
      await _ref.read(driversEndpointsProvider).updateDriver(driverId, draft.toJson());
      state = const AsyncData(null);
      _ref.invalidate(teamsDriversProvider);
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
