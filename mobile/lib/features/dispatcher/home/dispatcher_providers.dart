import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/endpoints/dispatcher_endpoints.dart';
import '../../../shared/models/fleet_position.dart';

/// Provides a singleton [DispatcherEndpoints] wired to the shared [ApiClient]
/// from the auth layer.
final dispatcherEndpointsProvider = Provider<DispatcherEndpoints>((ref) {
  return DispatcherEndpoints(ref.read(apiClientProvider));
});

/// A single monthly revenue point on the overview sparkline.
class RevenueTrendPoint {
  /// Month label as sent by the backend (e.g. `2026-02` or `Feb 2026`).
  final String month;

  /// Monthly revenue in the company's base currency.
  final double revenue;

  const RevenueTrendPoint({required this.month, required this.revenue});

  factory RevenueTrendPoint.fromJson(Map<String, dynamic> json) =>
      RevenueTrendPoint(
        month: json['month'] as String? ?? '',
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      );
}

/// One entry in the overview "recent activity" feed.
class RecentActivityItem {
  /// `trip` or `alert`.
  final String type;

  /// Entity id (trip id or alert id).
  final String? id;

  final String title;

  /// ISO-8601 timestamp; may be absent/`null` → rendered as empty.
  final DateTime? createdAt;

  const RecentActivityItem({
    required this.type,
    this.id,
    required this.title,
    this.createdAt,
  });

  bool get isAlert => type.toLowerCase() == 'alert';

  factory RecentActivityItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    return RecentActivityItem(
      type: json['type'] as String? ?? '',
      id: id is String || id is num ? '$id' : null,
      title: json['title'] as String? ?? '',
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// Parses the overview `revenue_trend` payload defensively.
///
/// Absent, null, or non-list payloads yield an empty list so the dashboard
/// never crashes on an older backend.
List<RevenueTrendPoint> parseRevenueTrend(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(RevenueTrendPoint.fromJson)
      .where((p) => p.month.isNotEmpty)
      .toList();
}

/// Parses the overview `recent_activity` payload defensively.
///
/// Absent, null, or non-list payloads yield an empty list.
List<RecentActivityItem> parseRecentActivity(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(RecentActivityItem.fromJson)
      .where((a) => a.title.isNotEmpty)
      .toList();
}

/// Fetches the dispatcher overview aggregate data from the API.
///
/// The returned map is expected to contain keys such as:
/// - `activeJobs` (int) — number of currently active jobs
/// - `activeDrivers` (int) — number of currently active drivers
/// - `openAlerts` (int) — number of open / unacknowledged alerts
/// - `vehiclesOnRoad` (int) — number of vehicles currently in transit
/// - `lastUpdated` (String) — ISO-8601 timestamp of the last refresh
/// - `revenue_trend` (List) — last-6-months `[{month, revenue}]` (§2)
/// - `recent_activity` (List) — `[{type, id, title, created_at}]` (§2)
///
/// Throws on network or server errors; the calling widget should handle
/// loading / error states.
final dispatcherOverviewProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final endpoints = ref.watch(dispatcherEndpointsProvider);
  final response = await endpoints.getOverview();
  final data = response.data;
  if (data is Map<String, dynamic>) return data;
  throw StateError('Unexpected response type: ${data.runtimeType}');
});

/// Fetches live fleet positions.
///
/// Each item is expected to contain keys such as:
/// - `vehicle_id` (String)
/// - `plate` (String)
/// - `driver_name` (String)
/// - `lat` / `lng` (double)
/// - `status` (String)
/// - `last_update` (String — ISO-8601)
final fleetPositionsProvider = FutureProvider<List<FleetPosition>>((ref) async {
  final endpoints = ref.watch(dispatcherEndpointsProvider);
  final response = await endpoints.getFleet();
  final data = response.data;
  if (data is List) {
    return data
        .map((e) => FleetPosition.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  return [];
});

/// Fetches all active jobs / transport orders.
final dispatcherJobsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final endpoints = ref.watch(dispatcherEndpointsProvider);
  final response = await endpoints.getJobs();
  final data = response.data;
  if (data is! List) return [];
  return data.cast<Map<String, dynamic>>();
});

/// Fetches all drivers.
final dispatcherDriversProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final endpoints = ref.watch(dispatcherEndpointsProvider);
  final response = await endpoints.getDrivers();
  final data = response.data;
  if (data is! List) return [];
  return data.cast<Map<String, dynamic>>();
});

/// Fetches all alerts / notifications.
final dispatcherAlertsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final endpoints = ref.watch(dispatcherEndpointsProvider);
  final response = await endpoints.getAlerts();
  final data = response.data;
  if (data is! List) return [];
  return data.cast<Map<String, dynamic>>();
});

/// Provides a single alert by its [alertId] from the cached alerts list.
///
/// Returns `null` while loading or when the alert is not found.
final dispatcherAlertDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, int>((ref, alertId) async {
  final alerts = await ref.watch(dispatcherAlertsProvider.future);
  return alerts.cast<Map<String, dynamic>?>().firstWhere(
        (alert) {
          final id = alert!['id'];
          if (id is int) return id == alertId;
          if (id is String) return int.tryParse(id) == alertId;
          return false;
        },
        orElse: () => null,
      );
});

/// Selected tab index for the dispatcher bottom navigation shell.
///
/// 0 = Overview, 1 = Fleet Tracker, 2 = AI Copilot, 3 = Records, 4 = More.
final dispatcherTabProvider = StateProvider<int>((ref) => 0);
