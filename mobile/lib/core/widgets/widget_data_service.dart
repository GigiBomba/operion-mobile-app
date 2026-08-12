import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/user_role.dart';
import '../../features/dispatcher/home/dispatcher_providers.dart';
import '../../features/driver/trip_overview/providers/trip_overview_providers.dart';

/// Signature for `HomeWidget.saveWidgetData` (test seam).
typedef SaveWidgetData =
    Future<bool?> Function(String key, Object? value);

/// Signature for `HomeWidget.updateWidget` (test seam).
typedef UpdateWidget = Future<bool?> Function({
  String? name,
  String? androidName,
  String? iOSName,
  String? qualifiedAndroidName,
});

/// Default implementation backed by the real `home_widget` plugin.
Future<bool?> _defaultSaveWidgetData(String key, Object? value) =>
    HomeWidget.saveWidgetData<Object>(key, value);

Future<bool?> _defaultUpdateWidget({
  String? name,
  String? androidName,
  String? iOSName,
  String? qualifiedAndroidName,
}) =>
    HomeWidget.updateWidget(
      name: name,
      androidName: androidName,
      iOSName: iOSName,
      qualifiedAndroidName: qualifiedAndroidName,
    );

/// The KPI values pushed to the dispatcher / manager "Today's KPIs" widget.
@immutable
class DispatcherWidgetData {
  const DispatcherWidgetData({
    required this.activeJobs,
    required this.openAlerts,
    this.revenueToDate,
    this.lastUpdated,
  });

  final int activeJobs;
  final int openAlerts;

  /// Revenue-to-date for the current month; nullable because the overview
  /// payload only recently gained `revenue_to_date` and older backends / the
  /// defensive parser may not provide it.
  final double? revenueToDate;
  final DateTime? lastUpdated;

  /// Parses a dispatcher overview response map defensively (accepts both
  /// camelCase and snake_case keys; missing/odd types degrade to 0).
  factory DispatcherWidgetData.fromOverviewMap(Map<String, dynamic> json) {
    int readInt(String key) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    double? readNullableDouble(List<String> keys) {
      for (final key in keys) {
        final v = json[key];
        if (v is num) return v.toDouble();
        if (v is String) {
          final parsed = double.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    final lastUpdatedStr = (json['lastUpdated'] ?? json['last_updated']) as String?;

    return DispatcherWidgetData(
      activeJobs: readInt('activeJobs') +
          readInt('active_jobs') +
          readInt('active_jobs_count'),
      openAlerts: readInt('openAlerts') + readInt('open_alerts'),
      revenueToDate: readNullableDouble(
        const ['revenue_to_date', 'revenueToDate', 'revenueToDateEur'],
      ),
      lastUpdated: lastUpdatedStr != null
          ? DateTime.tryParse(lastUpdatedStr)
          : null,
    );
  }

  Map<String, String> toWidgetData() => {
    'active_jobs': '$activeJobs',
    'open_alerts': '$openAlerts',
    if (revenueToDate != null)
      'revenue_to_date': _formatRevenue(revenueToDate!),
    'last_updated': lastUpdated?.toIso8601String() ?? '',
  };

  static String _formatRevenue(double value) {
    return value.toStringAsFixed(2);
  }
}

/// The values pushed to the driver "Next stop / active trip" widget.
@immutable
class DriverWidgetData {
  const DriverWidgetData({this.nextStop, this.activeTrip, this.lastUpdated});

  final String? nextStop;
  final String? activeTrip;
  final DateTime? lastUpdated;

  Map<String, String> toWidgetData() => {
    'next_stop': nextStop ?? '',
    'active_trip': activeTrip ?? '',
    'last_updated': lastUpdated?.toIso8601String() ?? '',
  };
}

/// Pushes today's KPI data to the native home-screen widgets.
///
/// Refresh triggers (blueprint §9.1):
/// (a) a 15-minute `Timer.periodic` in the main isolate while the app is
///     alive (wired in `core/app/app_services.dart`);
/// (b) push-triggered refresh when an alert FCM message arrives while the
///     app is alive ([NotificationActionHandler.onForegroundMessage]);
/// (c) after job/alert events (the approval screen refreshes the widget
///     after an approve/reject).
///
/// Terminated-state limitation: a background isolate has NO access to the
/// encrypted token store, so the widget can only be refreshed while the app
/// is alive — after force-stop the widget shows the last-known data until
/// the next app run (documented).
class WidgetDataService {
  WidgetDataService({
    SaveWidgetData? saveWidgetData,
    UpdateWidget? updateWidget,
  })  : _saveWidgetData = saveWidgetData ?? _defaultSaveWidgetData,
        _updateWidget = updateWidget ?? _defaultUpdateWidget;

  static const String dispatcherWidgetName = 'OperionWidget';
  static const String driverWidgetName = 'OperionDriverWidget';

  /// iOS App Group shared with the WidgetKit extensions — must match the
  /// native entitlements (`ios/Runner/Runner.entitlements`).
  static const String appGroupId = 'group.com.operion.operionMobile';

  final SaveWidgetData _saveWidgetData;
  final UpdateWidget _updateWidget;

  /// Pushes [data] to the dispatcher KPI widget.
  Future<void> pushDispatcherData(DispatcherWidgetData data) async {
    await _pushAll(data.toWidgetData(), dispatcherWidgetName);
  }

  /// Pushes [data] to the driver next-stop widget.
  Future<void> pushDriverData(DriverWidgetData data) async {
    await _pushAll(data.toWidgetData(), driverWidgetName);
  }

  /// Fetches the dispatcher overview and pushes it to the KPI widget.
  ///
  /// Best-effort: network failures and unparsable payloads are logged, never
  /// thrown. Parses `activeJobs` / `openAlerts` / `revenue_to_date`
  /// defensively (missing `revenue_to_date` → widget shows "—").
  Future<void> refreshOverview(ProviderContainer container) async {
    try {
      final overview = await container.read(dispatcherOverviewProvider.future);
      final data = DispatcherWidgetData.fromOverviewMap(overview);
      await pushDispatcherData(data);
      developer.log(
        'Widgets: dispatcher KPI widget refreshed '
        '(jobs ${data.activeJobs}, alerts ${data.openAlerts})',
        name: 'Widgets',
      );
    } catch (e) {
      developer.log('Widgets: overview refresh failed → $e', name: 'Widgets');
    }
  }

  /// Fetches the driver trip overview and pushes it to the next-stop widget.
  Future<void> refreshDriverTrip(ProviderContainer container) async {
    try {
      final overview = await container.read(tripOverviewProvider.future);
      await pushDriverData(
        DriverWidgetData(
          nextStop: overview.destination ?? overview.origin,
          activeTrip: overview.loadInfo,
          lastUpdated: DateTime.now(),
        ),
      );
      developer.log(
        'Widgets: driver widget refreshed (next stop '
        '${overview.destination ?? "—"})',
        name: 'Widgets',
      );
    } catch (e) {
      developer.log('Widgets: driver refresh failed → $e', name: 'Widgets');
    }
  }

  /// Role-aware push-triggered refresh (called when an alert push arrives).
  static Future<void> onPushMessage(
    ProviderContainer container,
    Map<String, dynamic> _,
  ) async {
    final role = container.read(currentUserRoleProvider);
    final isDriver = role?.shellVariant == AppShellVariant.driverShell;
    final service = WidgetDataService();
    if (isDriver) {
      await service.refreshDriverTrip(container);
    } else {
      await service.refreshOverview(container);
    }
  }

  Future<void> _pushAll(
    Map<String, String> data,
    String widgetName,
  ) async {
    for (final entry in data.entries) {
      await _saveWidgetData(entry.key, entry.value);
    }
    await _updateWidget(
      androidName: widgetName,
      iOSName: widgetName,
    );
  }
}
