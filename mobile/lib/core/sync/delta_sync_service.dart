import 'dart:developer' as developer;

import '../storage/local_db.dart';
import '../network/endpoints/sync_endpoints.dart';

// ── Data models ───────────────────────────────────────────────────────

/// Outcome of a single delta-sync cycle.
class SyncResult {
  /// Whether the sync completed without errors.
  final bool success;

  /// Number of records that were synced.
  final int recordsSynced;

  /// Error message if [success] is `false`.
  final String? error;

  /// When the sync finished.
  final DateTime timestamp;

  /// True when the sync was skipped by the Phase 4B Wi-Fi-only gate
  /// (§4.10 Data Usage): the user enabled "Wi-Fi only for large syncs" and
  /// the device is on cellular. The caller should surface the inline
  /// message and retry later — no cursor was consumed.
  final bool deferred;

  SyncResult({
    required this.success,
    required this.recordsSynced,
    this.error,
    DateTime? timestamp,
    this.deferred = false,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'SyncResult(success: $success, records: $recordsSynced, error: $error)';
}

// ── Delta sync service ────────────────────────────────────────────────

/// Performs delta (incremental) synchronisation with the backend.
///
/// For a given [entityType] (e.g. `transport`, `message`) the service:
/// 1. Reads the last-known sync cursor from [LocalDatabase].
/// 2. Fetches only records that changed **after** that cursor.
/// 3. Persists the new cursor returned by the server.
///
/// This minimises bandwidth and speeds up subsequent syncs.
class DeltaSyncService {
  final SyncEndpoints _endpoints;
  final LocalDatabase _db;

  /// Optional Phase 4B Wi-Fi-only gate check (§4.10).
  ///
  /// When non-null and returning `true`, [sync] is deferred before any
  /// network fetch (the cursor is NOT consumed). Wired to
  /// [WifiGate.blocksLargeTransfer] by the production provider.
  final bool Function()? isLargeTransferBlocked;

  /// Namespace used inside [LocalDatabase] for sync cursors.
  static const String _cursorNamespace = 'sync_cursors';

  DeltaSyncService(this._endpoints, this._db, {this.isLargeTransferBlocked});

  // ── Public API ─────────────────────────────────────────────────────

  /// Performs a delta sync for [entityType].
  ///
  /// Sends a GET request with the last-known cursor and processes the
  /// returned records. Returns a [SyncResult] describing the outcome.
  Future<SyncResult> sync({required String entityType}) async {
    // Phase 4B Wi-Fi-only gate (§4.10): defer large syncs on cellular before
    // ANY network fetch — the cursor is untouched so nothing is lost.
    if (isLargeTransferBlocked?.call() ?? false) {
      developer.log(
        'DeltaSync.sync($entityType): deferred (Wi-Fi-only large syncs)',
        name: 'DeltaSync',
      );
      return SyncResult(
        success: false,
        recordsSynced: 0,
        error: 'deferred_wifi_only',
        deferred: true,
      );
    }

    try {
      final cursor = await getLastCursor(entityType);

      final response = await _endpoints.syncEntity(
        entityType,
        cursor: cursor,
      );

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        return SyncResult(
          success: false,
          recordsSynced: 0,
          error: 'Unexpected response format for $entityType sync',
        );
      }

      final records = body['records'];
      final newCursor = body['cursor'] as String?;
      final recordCount = records is List ? records.length : 0;

      // Cache the fetched records locally
      if (records is List) {
        for (final record in records) {
          if (record is Map<String, dynamic>) {
            final recordId = (record['id'] ?? record['_id']).toString();
            await _db.cacheData(entityType, recordId, record);
          }
        }
      }

      developer.log(
        'DeltaSync: $entityType synced $recordCount record(s) '
        '${cursor != null ? "(cursor: ${cursor.length > 8 ? cursor.substring(0, 8) : cursor}…)" : "(initial)"} '
        '→ new cursor: ${newCursor != null ? "${newCursor.length > 8 ? newCursor.substring(0, 8) : newCursor}…" : "none"}',
        name: 'DeltaSync',
      );

      if (newCursor != null) {
        await updateCursor(entityType, newCursor);
      }

      return SyncResult(success: true, recordsSynced: recordCount);
    } catch (e) {
      developer.log(
        'DeltaSync.sync($entityType): $e',
        name: 'DeltaSync',
      );
      return SyncResult(
        success: false,
        recordsSynced: 0,
        error: e.toString(),
      );
    }
  }

  /// Performs a full (bulk) sync for [entityType], ignoring any existing
  /// cursor.
  ///
  /// After a successful full sync the cursor is reset so subsequent delta
  /// syncs only fetch newer changes.
  Future<SyncResult> fullSync({required String entityType}) async {
    try {
      final response = await _endpoints.syncEntityFull(entityType);

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        return SyncResult(
          success: false,
          recordsSynced: 0,
          error: 'Unexpected response format for $entityType full sync',
        );
      }

      final records = body['records'];
      final cursor = body['cursor'] as String?;
      final recordCount = records is List ? records.length : 0;

      // Cache the fetched records locally
      if (records is List) {
        for (final record in records) {
          if (record is Map<String, dynamic>) {
            final recordId = (record['id'] ?? record['_id']).toString();
            await _db.cacheData(entityType, recordId, record);
          }
        }
      }

      developer.log(
        'DeltaSync: full sync of $entityType returned $recordCount record(s)',
        name: 'DeltaSync',
      );

      if (cursor != null) {
        await updateCursor(entityType, cursor);
      }

      return SyncResult(success: true, recordsSynced: recordCount);
    } catch (e) {
      developer.log(
        'DeltaSync.fullSync($entityType): $e',
        name: 'DeltaSync',
      );
      return SyncResult(
        success: false,
        recordsSynced: 0,
        error: e.toString(),
      );
    }
  }

  // ── Phase 1B convenience wrappers (§4.1–4.3) ────────────────────────

  /// Delta-syncs the `fleet` entity (§4.1).
  Future<SyncResult> syncFleet() => sync(entityType: 'fleet');

  /// Delta-syncs the `drivers` entity (§4.2).
  Future<SyncResult> syncDrivers() => sync(entityType: 'drivers');

  /// Delta-syncs the `clients` entity (§4.3).
  Future<SyncResult> syncClients() => sync(entityType: 'clients');

  // ── Cursor persistence ────────────────────────────────────────────────

  /// Retrieves the last-known sync cursor for [entityType].
  ///
  /// Returns `null` when no prior sync has been performed.
  Future<String?> getLastCursor(String entityType) async {
    try {
      final raw = await _db.read(entityType, namespace: _cursorNamespace);
      return raw as String?;
    } catch (e) {
      developer.log(
        'DeltaSync.getLastCursor($entityType): $e',
        name: 'DeltaSync',
      );
      return null;
    }
  }

  /// Persists the [cursor] returned by the server for [entityType].
  Future<void> updateCursor(String entityType, String cursor) async {
    try {
      await _db.write(entityType, cursor, namespace: _cursorNamespace);
    } catch (e) {
      developer.log(
        'DeltaSync.updateCursor($entityType): $e',
        name: 'DeltaSync',
      );
      rethrow;
    }
  }
}
