import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../network/api_client.dart';
import '../network/endpoints/sync_endpoints.dart';
import 'action_queue.dart';
import 'delta_sync_service.dart';
import 'wifi_gate.dart';

// ── Sync service ─────────────────────────────────────────────────────

/// Provides the singleton [SyncEndpoints] wired to the shared [ApiClient].
final syncEndpointsProvider = Provider<SyncEndpoints>((ref) {
  return SyncEndpoints(ref.watch(apiClientProvider));
});

/// Production [DeltaSyncService] with the Phase 4B Wi-Fi-only gate wired in
/// (§4.10): when the user enables "Wi-Fi only for large syncs" and the device
/// is on cellular, [DeltaSyncService.sync] defers before any network fetch.
final deltaSyncServiceProvider = Provider<DeltaSyncService>((ref) {
  return DeltaSyncService(
    ref.read(syncEndpointsProvider),
    ref.read(localDatabaseProvider),
    isLargeTransferBlocked: () => ref.read(wifiGateProvider).blocksLargeTransfer,
  );
});

// ── Sync status ───────────────────────────────────────────────────────

/// Describes the current state of a sync cycle.
enum SyncStatus {
  /// No sync is in progress and the last sync was successful (or never run).
  idle,

  /// A sync is currently running.
  syncing,

  /// The last sync completed with errors.
  error,

  /// The last sync completed successfully.
  success,
}

// ── Providers ─────────────────────────────────────────────────────────

/// Writing a non-null [DateTime] to this provider triggers a sync for a
/// specific entity type (the caller is responsible for listening and acting).
///
/// Usage:
/// ```dart
/// ref.read(syncTriggerProvider.notifier).state = DateTime.now();
/// ```
final syncTriggerProvider = StateProvider<DateTime?>((ref) => null);

/// Global sync status used by the UI to show spinners / banners.
final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

/// The last error message from a failed sync, if any.
final syncErrorMessageProvider = StateProvider<String?>((ref) => null);

/// The number of records synced during the last successful (or partially
/// successful) sync cycle.
final syncRecordsCountProvider = StateProvider<int>((ref) => 0);

/// Writable provider for the sync cursor map.
///
/// Maps entity type (e.g. `'transport'`, `'message'`) to the last-known
/// cursor string. Driving this from a provider makes it easy to reactively
/// rebuild widgets that depend on sync state.
final syncCursorsProvider =
    StateProvider<Map<String, String>>((ref) => const {});
