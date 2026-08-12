import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../auth/auth_providers.dart';
import '../auth/user_role.dart';
import '../network/endpoints/device_endpoints.dart';
import '../notifications/device_registration.dart';
import '../notifications/local_notification_service.dart';
import '../notifications/notification_handler.dart';
import '../notifications/push_service.dart';
import '../quick_actions/quick_actions_service.dart';
import '../widgets/widget_data_service.dart';

/// Coordinates every Phase 5A OS-integration service from the main isolate.
///
/// Wired once from `main()` (after `Firebase.initializeApp()` and before
/// `runApp`), this:
/// 1. initializes [LocalNotificationService] (alert channel + Darwin
///    categories + the main-isolate action callback),
/// 2. initializes [PushService] and fixes the pre-existing push gap
///    (`onBackgroundMessage` registration + foreground presentation
///    suppression live in `main.dart`),
/// 3. forwards foreground FCM messages to the local-notification layer and
///    the push-triggered widget refresh,
/// 4. registers the device token with the backend,
/// 5. drains persisted notification-action intents once the session is
///    restored (terminated-state execution),
/// 6. registers quick actions (with auth-gated deep links),
/// 7. runs the 15-minute widget refresh timer while the app is alive.
class AppServices {
  AppServices._();

  /// Process-wide coordinator instance.
  static final AppServices instance = AppServices._();

  ProviderContainer? _container;
  PushService? _pushService;
  Timer? _widgetRefreshTimer;
  ProviderSubscription<AuthState>? _authSubscription;
  StreamSubscription<PushNotification>? _pushSubscription;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// The initialized [PushService] (test seam).
  @visibleForTesting
  PushService? get pushService => _pushService;

  /// Initializes all services. Safe to call once (idempotent guard).
  Future<void> initialize(ProviderContainer container) async {
    if (_initialized) return;
    _container = container;
    _initialized = true;

    // ── 0. Widget App Group (iOS: WidgetKit shares data through it) ───
    // Must match the native entitlements (`group.com.operion.operionMobile`).
    try {
      await HomeWidget.setAppGroupId(WidgetDataService.appGroupId);
    } catch (e) {
      developer.log('AppServices: setAppGroupId failed → $e',
          name: 'AppServices');
    }

    // ── 1. Rich local notifications (alert channel + Darwin actions) ──
    await LocalNotificationService.instance.initialize(
      onAction: (response) {
        final c = _container;
        if (c == null) return;
        NotificationActionHandler.instance.handleResponse(response, c);
      },
      onBackgroundAction: firebaseMessagingNotificationBackgroundHandler,
    );

    // ── 2. Push service (pre-existing infra, now actually wired) ──────
    final push = PushService();
    _pushService = push;
    await push.initialize();
    await push.requestPermission();
    // iOS: never let FCM auto-present alert-type messages — the local
    // notification layer owns display (so inline actions are attached).
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: true,
        );

    // ── 3. Foreground messages → local show + widget refresh ─────────
    _pushSubscription = push.onNotification.listen((notification) {
      final c = _container;
      if (c == null) return;
      NotificationActionHandler.instance
          .onForegroundMessage(notification.data, c);
    });

    // ── 4. Device-token registration ─────────────────────────────────
    unawaited(_registerDevice(push));

    // ── 5. Terminated-state action execution on session restore ──────
    _authSubscription = container.listen<AuthState>(
      authStateProvider,
      (_, next) {
        if (next != AuthState.authenticated) return;
        final c = _container;
        if (c == null) return;
        unawaited(
          NotificationActionHandler.instance.executePendingActions(c),
        );
      },
    );

    // ── 6. Quick actions ─────────────────────────────────────────────
    await QuickActionService.instance.initialize(container);

    // ── 7. 15-minute widget refresh while the app is alive ───────────
    _startWidgetRefreshTimer(container);
  }

  Future<void> _registerDevice(PushService push) async {
    final container = _container;
    if (container == null) return;
    try {
      final endpoints = DeviceEndpoints(container.read(apiClientProvider));
      await DeviceRegistration(endpoints, push).register();
    } catch (e) {
      developer.log('AppServices: device registration failed → $e',
          name: 'AppServices');
    }
  }

  void _startWidgetRefreshTimer(ProviderContainer container) {
    _widgetRefreshTimer?.cancel();
    final service = WidgetDataService();
    _widgetRefreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      final role = container.read(currentUserRoleProvider);
      final isDriver = role?.shellVariant == AppShellVariant.driverShell;
      unawaited(
        isDriver
            ? service.refreshDriverTrip(container)
            : service.refreshOverview(container),
      );
    });
  }

  /// Tears down timers and subscriptions (tests / hot restart).
  void dispose() {
    _widgetRefreshTimer?.cancel();
    _widgetRefreshTimer = null;
    _authSubscription?.close();
    _pushSubscription?.cancel();
    QuickActionService.instance.dispose();
    _initialized = false;
  }
}
