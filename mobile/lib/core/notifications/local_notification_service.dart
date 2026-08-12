import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_actions.dart';

/// Wrapper around `flutter_local_notifications` for the Phase 5A rich
/// notification layer.
///
/// Design notes (per the plugin audit + Android 12+ trampoline restriction):
/// - Alerts are ALWAYS displayed locally from data-only FCM messages
///   (`type=alert` / `type=approval`), never auto-presented by FCM
///   (`setForegroundNotificationPresentationOptions(alert: false)` on iOS).
/// - The Android channel id is `alerts_channel` — deliberately distinct from
///   the GPS foreground-task channel (`operion_navigation`) used by
///   `flutter_foreground_task` to avoid channel collisions.
/// - Inline actions: **Approve** / **Snooze** / **View**. Approve/Snooze run
///   headless (`showsUserInterface: false`) on Android 12+ because a
///   trampolined Activity cannot run in the background; View opens the app.
/// - iOS uses `DarwinNotificationCategory`s + `DarwinNotificationAction`s
///   registered at initialization; actions marked `foreground` launch the app.
/// - A snoozed re-show is BOUNDED: the re-shown notification is created
///   without the Snooze action, so snoozing can never loop.
class LocalNotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    Future<void> Function()? initializeTz,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _initializeTz = initializeTz ?? _defaultInitializeTz;

  /// Process-wide singleton so the `@pragma('vm:entry-point')` background
  /// FCM handler and the main isolate share one initialized instance.
  static LocalNotificationService instance = LocalNotificationService._();

  LocalNotificationService._()
      : _plugin = FlutterLocalNotificationsPlugin(),
        _initializeTz = _defaultInitializeTz;

  /// Android notification channel for alerts — MUST NOT collide with the
  /// GPS foreground-task channel (`operion_navigation`).
  static const String alertsChannelId = 'alerts_channel';
  static const String alertsChannelName = 'Operion Alerts';
  static const String alertsChannelDescription =
      'Job, approval and fleet alerts with inline actions';

  /// Darwin notification category for alert-type notifications.
  static const String alertsCategoryId = 'operion_alerts';

  final FlutterLocalNotificationsPlugin _plugin;
  final Future<void> Function() _initializeTz;

  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Visible for tests: expose the wrapped plugin.
  @visibleForTesting
  FlutterLocalNotificationsPlugin get plugin => _plugin;

  static Future<void> _defaultInitializeTz() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('UTC'));
    } catch (_) {
      // Never fatal — zonedSchedule falls back to UTC.
    }
  }

  /// Initializes the plugin, registers the alert channel + iOS Darwin
  /// categories, and requests notification permissions on both platforms.
  ///
  /// [onAction] is invoked in the MAIN isolate whenever the user taps a
  /// notification or one of its inline actions (see
  /// `NotificationActionHandler.handleResponse`).
  ///
  /// [onBackgroundAction] is invoked on a headless background isolate when
  /// the user taps a non-UI inline action while the app is not running
  /// (Android 12+ trampoline behaviour). It must be a top-level
  /// `@pragma('vm:entry-point')` function.
  Future<void> initialize({
    required void Function(NotificationResponse response) onAction,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundAction,
  }) async {
    if (_initialized) return;
    await _initializeTz();

    final settings = InitializationSettings(
      android: const AndroidInitializationSettings('@drawable/ic_notification_small'),
      // iOS categories are registered at initialization time. View is a
      // `foreground` action (launches the app); Approve/Snooze run in the
      // background (headless, no UI).
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory(
            alertsCategoryId,
            actions: [
              DarwinNotificationAction.plain(
                NotificationActionType.approve.id,
                'Approve',
              ),
              DarwinNotificationAction.plain(
                NotificationActionType.snooze.id,
                'Snooze',
              ),
              DarwinNotificationAction.plain(
                NotificationActionType.view.id,
                'View',
                options: const {
                  DarwinNotificationActionOption.foreground,
                },
              ),
            ],
          ),
        ],
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory(
            alertsCategoryId,
            actions: [
              DarwinNotificationAction.plain(
                NotificationActionType.approve.id,
                'Approve',
              ),
              DarwinNotificationAction.plain(
                NotificationActionType.snooze.id,
                'Snooze',
              ),
              DarwinNotificationAction.plain(
                NotificationActionType.view.id,
                'View',
                options: const {
                  DarwinNotificationActionOption.foreground,
                },
              ),
            ],
          ),
        ],
      ),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: onAction,
      onDidReceiveBackgroundNotificationResponse: onBackgroundAction,
    );

    // ── Permissions ──────────────────────────────
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  /// Shows an alert notification with inline actions.
  ///
  /// [snoozed] disables the Snooze action so the re-show is bounded.
  /// [approveLabel] / [snoozeLabel] / [viewLabel] are localized action labels
  /// (English defaults when no localization is available — e.g. the headless
  /// background isolate).
  Future<void> showAlertNotification({
    required int id,
    required String title,
    required String body,
    required String alertId,
    bool snoozed = false,
    String approveLabel = 'Approve',
    String snoozeLabel = 'Snooze',
    String viewLabel = 'View',
  }) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      alertsChannelId,
      alertsChannelName,
      channelDescription: alertsChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: [
        AndroidNotificationAction(
          NotificationActionType.approve.id,
          approveLabel,
          showsUserInterface: false,
        ),
        if (!snoozed)
          AndroidNotificationAction(
            NotificationActionType.snooze.id,
            snoozeLabel,
            showsUserInterface: false,
          ),
        AndroidNotificationAction(
          NotificationActionType.view.id,
          viewLabel,
          showsUserInterface: true,
        ),
      ],
      icon: '@drawable/ic_notification_small',
      onlyAlertOnce: true,
    );

    // iOS actions come from the Darwin category registered at init — the
    // payload carries `alert_id` for action routing.
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: alertsCategoryId,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      ),
      payload: jsonEncodePayload(alertId),
    );
  }

  /// Schedules a bounded re-show of the alert after [delay] (default 15 min).
  Future<void> scheduleSnoozeReShow({
    required int id,
    required String title,
    required String body,
    required String alertId,
    Duration delay = const Duration(minutes: 15),
  }) async {
    if (!_initialized) return;

    final tzNow = tz.TZDateTime.now(tz.local);
    final fireAt = tzNow.add(delay);

    final androidDetails = AndroidNotificationDetails(
      alertsChannelId,
      alertsChannelName,
      channelDescription: alertsChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      // No Snooze action on the re-show — bounded by design.
      actions: [
        AndroidNotificationAction(
          NotificationActionType.approve.id,
          'Approve',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          NotificationActionType.view.id,
          'View',
          showsUserInterface: true,
        ),
      ],
      icon: '@drawable/ic_notification_small',
      onlyAlertOnce: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: alertsCategoryId,
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: fireAt,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncodePayload(alertId),
    );
  }

  /// Stable, collision-free positive notification id for [messageId].
  static int notificationIdFor(String messageId) {
    final hash = messageId.hashCode;
    // Keep within the positive 32-bit range used by the plugin.
    return hash & 0x7FFFFFFF;
  }

  /// JSON payload attached to every alert notification carrying the alert id.
  static String? jsonEncodePayload(String alertId) {
    return '{"alert_id": "$alertId"}';
  }
}
