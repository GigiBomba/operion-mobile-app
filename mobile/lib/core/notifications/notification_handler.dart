import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/dispatcher/alerts/approval_detail_screen.dart';
import '../../features/dispatcher/home/dispatcher_providers.dart';
import '../auth/auth_providers.dart';
import '../i18n/app_localizations.dart';
import '../navigation/app_navigator.dart';
import '../widgets/widget_data_service.dart';
import 'local_notification_service.dart';
import 'notification_actions.dart';
import 'notification_router.dart';

// ── Parsed data-only alert push ─────────────────────────────────────────

/// Parsed representation of a data-only FCM message that should be displayed
/// as a rich local notification with inline actions.
///
/// Backend payload contract (type=alert | approval):
/// - `type`      → `'alert'` or `'approval'` (routes to alert detail)
/// - `alert_id`  → the alert id the inline actions operate on
/// - `title` / `message` → display text
/// - `message_id` → dedupe key (iOS 18 double-fire guard)
@immutable
class AlertPushData {
  const AlertPushData({
    required this.type,
    required this.alertId,
    required this.title,
    required this.body,
    required this.messageId,
  });

  final String type;
  final String alertId;
  final String title;
  final String body;
  final String messageId;

  bool get isAlertType => type == 'alert' || type == 'approval';

  /// Parses [data] defensively; returns `null` when the message is not an
  /// alert-type notification (and should therefore not be locally shown).
  static AlertPushData? tryParse(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    if (type != 'alert' && type != 'approval') return null;
    final alertId = (data['alert_id'] ?? '').toString();
    if (alertId.isEmpty) return null;
    final messageId =
        (data['message_id'] ?? data['messageId'] ?? alertId).toString();
    return AlertPushData(
      type: type,
      alertId: alertId,
      title: (data['title'] ?? 'Operion Alert').toString(),
      body: (data['message'] ?? data['body'] ?? '').toString(),
      messageId: messageId,
    );
  }
}

// ── iOS 18 / duplicate-delivery dedupe ──────────────────────────────────

/// Persists the ids of locally-shown alert notifications so a duplicated
/// delivery (e.g. the iOS 18 notification double-fire) is shown only once.
///
/// The set is bounded (last [maxEntries] ids) so it cannot grow unbounded.
class NotificationDedupeStore {
  NotificationDedupeStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  static const String storageKey = 'shown_notification_message_ids';
  static const int maxEntries = 100;

  final Future<SharedPreferences> Function() _prefs;

  /// Returns `false` (and records the id) when [messageId] was already shown.
  Future<bool> tryClaim(String messageId) async {
    final prefs = await _prefs();
    final ids = prefs.getStringList(storageKey) ?? const [];
    if (ids.contains(messageId)) return false;
    final updated = [...ids, messageId];
    // Bound the set — drop the oldest half when full.
    if (updated.length > maxEntries) {
      updated.removeRange(0, updated.length - maxEntries);
    }
    await prefs.setStringList(storageKey, updated);
    return true;
  }

  /// Marks [messageId] as shown (no-op when already present).
  Future<void> markShown(String messageId) async {
    final prefs = await _prefs();
    final ids = prefs.getStringList(storageKey) ?? const [];
    if (ids.contains(messageId)) return;
    final updated = [...ids, messageId];
    if (updated.length > maxEntries) {
      updated.removeRange(0, updated.length - maxEntries);
    }
    await prefs.setStringList(storageKey, updated);
  }
}

// ── Action handler ──────────────────────────────────────────────────────

/// Coordinates rich alert notifications end-to-end.
///
/// - Foreground / background FCM data messages → local show with inline
///   actions (deduped by [NotificationDedupeStore]).
/// - Tapped notification / inline action (`Approve` / `Snooze` / `View`) →
///   intent persisted via [NotificationActionStore], then executed through
///   the SAME authenticated flow used by the in-app screens
///   (`dispatcherEndpointsProvider.approveAction` / `rejectAction`).
/// - Headless / terminated state: the action intent is persisted (the
///   background isolate has NO access to the encrypted token store), and
///   executed via [executePendingActions] on the next authenticated launch.
class NotificationActionHandler {
  NotificationActionHandler({
    LocalNotificationService? localNotifications,
    NotificationActionStore? actionStore,
    NotificationDedupeStore? dedupeStore,
  })  : localNotifications =
            localNotifications ?? LocalNotificationService.instance,
        actionStore = actionStore ?? NotificationActionStore(),
        dedupeStore = dedupeStore ?? NotificationDedupeStore();

  /// Process-wide handler instance (used by background isolates).
  static final NotificationActionHandler instance =
      NotificationActionHandler();

  final LocalNotificationService localNotifications;
  final NotificationActionStore actionStore;
  final NotificationDedupeStore dedupeStore;

  /// Displays an alert-type FCM data message as a rich local notification.
  ///
  /// Safe to call from the background isolate — it only touches the local
  /// notification plugin + [SharedPreferences] (never the encrypted token
  /// store). [loc] provides localized action labels on the main isolate;
  /// when `null` (headless background isolate) English defaults are used.
  /// Returns `false` when the message is not alert-type or was already shown
  /// (dedupe).
  Future<bool> showFromDataMessage(
    Map<String, dynamic> data, {
    AppLocalizations? loc,
  }) async {
    final alert = AlertPushData.tryParse(data);
    if (alert == null) return false;
    try {
      if (!await dedupeStore.tryClaim(alert.messageId)) {
        developer.log(
          'Notifications: duplicate delivery skipped (${alert.messageId})',
          name: 'Notifications',
        );
        return false;
      }
      await localNotifications.showAlertNotification(
        id: LocalNotificationService.notificationIdFor(alert.messageId),
        title: alert.title,
        body: alert.body,
        alertId: alert.alertId,
        approveLabel: loc?.notification_approve ?? 'Approve',
        snoozeLabel: loc?.notification_snooze ?? 'Snooze',
        viewLabel: loc?.notification_view ?? 'View',
      );
      developer.log(
        'Notifications: showed alert ${alert.alertId} (${alert.messageId})',
        name: 'Notifications',
      );
      return true;
    } catch (e) {
      developer.log('Notifications: local show failed → $e',
          name: 'Notifications');
      return false;
    }
  }

  /// Main-isolate entry for a foreground FCM message: shows the local
  /// notification (deduped) and triggers the push-refreshed widget update.
  Future<void> onForegroundMessage(
    Map<String, dynamic> data,
    ProviderContainer container,
  ) async {
    final loc = AppLocalizations(container.read(localeProvider));
    final shown = await showFromDataMessage(data, loc: loc);
    if (shown) {
      unawaited(WidgetDataService.onPushMessage(container, data));
    }
  }

  /// MAIN isolate: user tapped a notification or one of its actions.
  ///
  /// Persists the intent first (so a crash/termination never loses it), then
  /// executes immediately when the session is authenticated.
  Future<void> handleResponse(
    NotificationResponse response,
    ProviderContainer container,
  ) async {
    final alertId = _alertIdFromResponse(response);
    if (alertId == null) return;

    final type = NotificationActionType.fromId(response.actionId);
    final intent = NotificationActionIntent(
      type: type,
      alertId: alertId,
      createdAt: DateTime.now(),
    );
    await actionStore.append(intent);
    await executePendingActions(container);
  }

  /// BACKGROUND isolate: user tapped an action while the app is not running.
  ///
  /// The headless isolate cannot authenticate (no access to the encrypted
  /// token store) — persist the intent only. It is executed by
  /// [executePendingActions] on the next authenticated launch (documented OS
  /// limitation). Best-effort: storage failures are logged, never thrown.
  Future<void> handleBackgroundResponse(NotificationResponse response) async {
    final alertId = _alertIdFromResponse(response);
    if (alertId == null) return;
    final type = NotificationActionType.fromId(response.actionId);
    try {
      await actionStore.append(
        NotificationActionIntent(
          type: type,
          alertId: alertId,
          createdAt: DateTime.now(),
        ),
      );
      developer.log(
        'Notifications: persisted ${type.id} intent for alert $alertId',
        name: 'Notifications',
      );
    } catch (e) {
      developer.log('Notifications: background intent persist failed → $e',
          name: 'Notifications');
    }
  }

  /// Drains the persisted intent queue through the authenticated flow.
  ///
  /// Executes every intent whose [NotificationActionType] can be fulfilled
  /// from the main isolate, removing it on success. Intents stay queued when
  /// the user is not authenticated — they are retried on the next launch
  /// (terminated-state limitation).
  Future<void> executePendingActions(ProviderContainer container) async {
    final pending = await actionStore.loadPending();
    if (pending.isEmpty) return;

    final authenticated = container.read(authStateProvider) ==
            AuthState.authenticated &&
        container.read(currentUserProvider) != null;

    if (!authenticated) return;

    final executed = <NotificationActionIntent>[];
    for (final intent in pending) {
      try {
        switch (intent.type) {
          case NotificationActionType.approve:
            // Same mutation the in-app ApprovalDetailScreen uses.
            final endpoints = container.read(dispatcherEndpointsProvider);
            await endpoints.approveAction(intent.alertId);
            // Job/alert event → refresh the home-screen widget (trigger c).
            unawaited(WidgetDataService().refreshOverview(container));
            executed.add(intent);
          case NotificationActionType.snooze:
            await localNotifications.scheduleSnoozeReShow(
              id: LocalNotificationService.notificationIdFor(intent.alertId),
              title: intent.title ?? 'Operion Alert',
              body: intent.body ?? '',
              alertId: intent.alertId,
            );
            executed.add(intent);
          case NotificationActionType.view:
          case NotificationActionType.tap:
            // showsUserInterface:true — navigate to the alert detail.
            _navigateToAlertDetail(container, intent.alertId);
            executed.add(intent);
        }
      } catch (e) {
        // Network/auth failures keep the intent queued for the next launch.
        developer.log(
          'Notifications: action ${intent.type.id} failed → $e',
          name: 'Notifications',
        );
      }
    }
    if (executed.isNotEmpty) {
      final remaining = pending.where((i) => !executed.contains(i)).toList();
      await actionStore.replaceAll(remaining);
    }
  }

  /// Keeps the tap → router behaviour: alert/approval payloads open the
  /// [ApprovalDetailScreen] (the same screen the notification router maps
  /// `alert`/`approval` types to).
  void _navigateToAlertDetail(ProviderContainer container, String alertId) {
    final route = NotificationRouter.resolveRoute({'type': 'alert'});
    if (route != NotificationRoute.alertDetail) return;
    final alertIdInt = int.tryParse(alertId);
    if (alertIdInt == null) {
      developer.log('Notifications: non-numeric alert_id $alertId',
          name: 'Notifications');
      return;
    }
    pushOnRootNavigator(ApprovalDetailScreen(alertId: alertIdInt));
  }

  String? _alertIdFromResponse(NotificationResponse response) {
    // Prefer the JSON payload attached at show time; fall back to the
    // platform-provided `data` map (used on some platforms).
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map && decoded['alert_id'] != null) {
          return decoded['alert_id'].toString();
        }
      } catch (_) {
        // Not JSON — fall through.
      }
    }
    final data = response.data;
    if (data['alert_id'] != null) return data['alert_id'].toString();
    if (data['alertId'] != null) return data['alertId'].toString();
    return null;
  }
}

/// Top-level entry point for inline notification actions tapped while the
/// app is NOT running (Android 12+ trampoline → headless background isolate).
///
/// Registered via `onDidReceiveBackgroundNotificationResponse` in
/// [LocalNotificationService.initialize]. The headless isolate has no access
/// to the encrypted token store, so the intent is only persisted here and
/// executed through the authenticated flow on the next launch.
@pragma('vm:entry-point')
Future<void> firebaseMessagingNotificationBackgroundHandler(
  NotificationResponse response,
) async {
  await NotificationActionHandler.instance.handleBackgroundResponse(response);
}
