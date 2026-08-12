/// Sync entity vocabulary (blueprint §5 "Sync/queue extensions").
///
/// The blueprint says to "extend the existing enum", but no sync-entity enum
/// exists in this repo today — [`SyncCursor`] in
/// `shared/models/sync_cursor.dart` is a plain data class carrying a raw
/// `String entityType`. This file is therefore the canonical home for the
/// sync entity type vocabulary, and Phase 1+ may migrate
/// `SyncCursor.entityType` to be typed by [SyncEntityType].
enum SyncEntityType {
  /// Transport trips/transports.
  trips,

  /// Driver alerts/notifications.
  alerts,

  /// In-app messages.
  messages,

  /// Trucks/vehicles (blueprint §4.1).
  fleet,

  /// Drivers (blueprint §4.2).
  drivers,

  /// Clients/CRM (blueprint §4.3).
  clients,

  /// Invoices (blueprint §4.5).
  invoices,

  /// Maintenance records (blueprint §4.6).
  maintenance,
}
