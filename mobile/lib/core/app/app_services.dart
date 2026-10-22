import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../auth/auth_providers.dart';
import '../auth/user_role.dart';
import '../network/api_client.dart';
import '../network/endpoints/device_endpoints.dart';
import '../notifications/device_registration.dart';
import '../notifications/local_notification_service.dart';
import '../notifications/notification_handler.dart';
import '../notifications/notification_providers.dart';
import '../notifications/notification_router.dart';
import '../notifications/push_service.dart';
import '../notifications/support_thread_router.dart';
import '../quick_actions/quick_actions_service.dart';
import '../sync/action_queue.dart';
import '../sync/connectivity_monitor.dart';
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
/// 7. runs the 15-minute widget refresh timer while the app is alive,
/// 8. bootstraps [LocalDatabase] (offline cache + action-queue persistence)
///    and starts the [OfflineReplayCoordinator] that drains the queue when
///    connectivity returns / the session is restored.
class AppServices {
  AppServices._();

  /// Process-wide coordinator instance.
  static final AppServices instance = AppServices._();

  ProviderContainer? _container;
  PushService? _pushService;
  Timer? _widgetRefreshTimer;
  ProviderSubscription<AuthState>? _authSubscription;
  StreamSubscription<PushNotification>? _pushSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  OfflineReplayCoordinator? _replayCoordinator;
  bool _initialized = false;

  /// The last FCM token successfully registered with the backend. Guards
  /// against re-registering the same token on every auth transition.
  String? _lastRegisteredToken;

  /// Max in-session registration attempts before giving up until the next
  /// token refresh / launch.
  static const int _maxRegistrationAttempts = 3;

  /// Base backoff delay between registration retries (doubles per attempt).
  static const Duration _registrationRetryBaseDelay = Duration(seconds: 2);

  bool get isInitialized => _initialized;

  /// The initialized [PushService] (test seam).
  @visibleForTesting
  PushService? get pushService => _pushService;

  /// The initialized offline-replay coordinator (test seam).
  @visibleForTesting
  OfflineReplayCoordinator? get replayCoordinator => _replayCoordinator;

  /// Initializes all services. Safe to call once (idempotent guard).
  Future<void> initialize(ProviderContainer container) async {
    if (_initialized) return;
    _container = container;
    _initialized = true;

    // ── 0. LocalDatabase bootstrap ────────────────────────────────────
    // The offline cache (fleet/clients/teams/invoicing) and the offline
    // action queue both persist through LocalDatabase. It MUST be
    // initialised before any provider reads/writes the cache, otherwise every
    // operation throws StateError('LocalDatabase not initialised').
    try {
      await container.read(localDatabaseProvider).initialize();
    } catch (e) {
      developer.log('AppServices: LocalDatabase init failed → $e',
          name: 'AppServices');
    }

    // ── 0b. Widget App Group (iOS: WidgetKit shares data through it) ──
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

    // Reflect the current token in the provider immediately.
    container.read(deviceTokenProvider.notifier).state = push.token;

    // ── 3. Foreground messages → local show + widget refresh ─────────
    _pushSubscription = push.onNotification.listen((notification) {
      final c = _container;
      if (c == null) return;
      NotificationActionHandler.instance
          .onForegroundMessage(notification.data, c);
    });

    // ── 3a. Support-reply tap deep links (blueprint 41.3e) ───────────
    // FCM notification-type deliveries (and cold starts) route straight to
    // the report thread. Data-only alerts keep using the local-notification
    // tap path in `NotificationActionHandler`.
    await _wirePushTaps();

    // ── 3b. Token refresh → re-register the device (Bug 2) ───────────
    // FCM rotates the token periodically; the backend keeps the stale token
    // and pushes silently stop unless we re-register. The provider is always
    // updated; re-registration only happens for an authenticated session.
    _tokenRefreshSubscription = push.onTokenRefresh.listen((newToken) {
      final c = _container;
      if (c == null) return;
      c.read(deviceTokenProvider.notifier).state = newToken;
      final authenticated = c.read(authStateProvider) ==
              AuthState.authenticated &&
          c.read(currentUserProvider) != null;
      if (!authenticated) return;
      unawaited(_registerDevice(push));
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
        // Re-register the device token on every authenticated session —
        // covers a token refresh that happened before login (Bug 2). The
        // `_lastRegisteredToken` guard makes this a no-op when unchanged.
        final pushService = _pushService;
        if (pushService != null) unawaited(_registerDevice(pushService));
      },
    );

    // ── 6. Quick actions ─────────────────────────────────────────────
    await QuickActionService.instance.initialize(container);

    // ── 7. 15-minute widget refresh while the app is alive ───────────
    _startWidgetRefreshTimer(container);

    // ── 8. Offline action queue replay coordinator ───────────────────
    // Loads persisted offline actions, replays them whenever connectivity
    // returns, and drains the queue once the session is restored.
    try {
      _replayCoordinator = OfflineReplayCoordinator(container);
      await _replayCoordinator!.initialize();
    } catch (e) {
      developer.log('AppServices: replay coordinator init failed → $e',
          name: 'AppServices');
    }
  }

  /// Wires FCM notification taps (background -> foreground, and cold start)
  /// to the report thread. No-op when Firebase is not initialized (tests).
  Future<void> _wirePushTaps() async {
    final container = _container;
    if (container == null) return;
    try {
      if (Firebase.apps.isEmpty) return;
      _openedAppSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handlePushTap(message.data, container);
      });
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handlePushTap(initial.data, container);
    } catch (e) {
      developer.log('AppServices: push tap wiring failed → $e',
          name: 'AppServices');
    }
  }

  void _handlePushTap(Map<String, dynamic> data, ProviderContainer container) {
    if (NotificationRouter.resolveRoute(data) !=
        NotificationRoute.supportThread) {
      return;
    }
    final conversationId =
        NotificationRouter.resolveParams(data)?['conversationId'];
    if (conversationId == null || conversationId.isEmpty) return;
    unawaited(openSupportThread(container, conversationId));
  }

  Future<void> _registerDevice(PushService push) async {
    final container = _container;
    if (container == null) return;
    final current = push.token;
    // Already registered this exact token — nothing to do (avoids duplicate
    // POSTs on every auth transition).
    if (current != null &&
        current.isNotEmpty &&
        current == _lastRegisteredToken) {
      return;
    }

    final endpoints = DeviceEndpoints(container.read(apiClientProvider));
    final registration = DeviceRegistration(endpoints, push);

    // In-session retry with backoff: a transient failure (dead zone, 5xx)
    // must not wait for the next launch to re-register.
    for (var attempt = 1; attempt <= _maxRegistrationAttempts; attempt++) {
      try {
        final ok = await registration.register();
        if (ok) {
          // Read AFTER success — register() may have populated the token via
          // getToken() when it was still null.
          _lastRegisteredToken = push.token;
          return;
        }
      } catch (e) {
        developer.log(
          'AppServices: device registration attempt '
          '$attempt/$_maxRegistrationAttempts failed → $e',
          name: 'AppServices',
        );
      }
      if (attempt == _maxRegistrationAttempts) return;
      await Future<void>.delayed(_registrationRetryBaseDelay * attempt);
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
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _openedAppSubscription?.cancel();
    _openedAppSubscription = null;
    _replayCoordinator?.dispose();
    _replayCoordinator = null;
    QuickActionService.instance.dispose();
    _initialized = false;
  }
}

/// Coordinates draining the offline [ActionQueue] when connectivity returns.
///
/// Wired from [AppServices.initialize]. Responsibilities:
/// 1. loads persisted actions via [ActionQueue.initialize],
/// 2. listens for connectivity events and replays whenever the device is
///    online,
/// 3. runs an initial replay as soon as the session is authenticated
///    (startup drain; a no-op until tokens exist),
/// 4. maps each [QueuedAction] (endpoint + method + payload) onto the shared
///    [ApiClient] by HTTP method,
/// 5. skips action types whose queued payload cannot faithfully reproduce the
///    online request (e.g. document uploads — queued with a local `file_path`
///    but uploaded as multipart FormData online) via a permanent failure that
///    surfaces through [ActionQueueState.lastError] instead of retrying
///    forever.
class OfflineReplayCoordinator {
  OfflineReplayCoordinator(this._container);

  final ProviderContainer _container;

  StreamSubscription<bool>? _connectivitySubscription;
  ProviderSubscription<AuthState>? _authSubscription;
  ActionQueue? _queue;
  bool _disposed = false;

  /// Loads persisted actions and starts listening for connectivity + auth.
  Future<void> initialize() async {
    final queue = _container.read(actionQueueProvider);
    _queue = queue;
    await queue.initialize();

    final monitor = _container.read(connectivityProvider);
    _connectivitySubscription = monitor.onConnectivityChanged.listen((online) {
      if (online) unawaited(_replayIfReady());
    });

    // Startup drain: replay as soon as the session is restored.
    // `fireImmediately` covers the case where the session was already
    // authenticated before the coordinator started.
    _authSubscription = _container.listen<AuthState>(
      authStateProvider,
      (_, next) {
        if (next == AuthState.authenticated) unawaited(_replayIfReady());
      },
      fireImmediately: true,
    );

    // If the platform already reports online, kick a replay too (a no-op
    // until auth is ready thanks to the token guard).
    if (monitor.isOnline) {
      unawaited(_replayIfReady());
    }
  }

  /// Replays the queue when authenticated. Safe to call concurrently —
  /// [ActionQueue.replayAll] is re-entrant-safe (a request arriving while one
  /// replay is running schedules another cycle).
  Future<void> _replayIfReady() async {
    if (_disposed) return;
    final queue = _queue;
    if (queue == null) return;

    // Guard: never replay before the user is authenticated (no tokens).
    final tokenManager = _container.read(tokenManagerProvider);
    final accessToken = await tokenManager.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) return;

    final api = _container.read(apiClientProvider);
    await queue.replayAll((action) => _execute(api, action));
  }

  /// Maps a [QueuedAction] onto the shared [ApiClient] by HTTP method.
  ///
  /// Action types whose queued payload cannot faithfully reproduce the online
  /// request (document uploads — multipart FormData vs a local `file_path`)
  /// are skipped with a permanent failure so they surface via
  /// [ActionQueueState.lastError] instead of being replayed as garbage.
  Future<void> _execute(ApiClient api, QueuedAction action) async {
    // Document uploads are enqueued with a local `file_path` (see
    // document_upload_screen). The online path uploads multipart FormData,
    // which a JSON replay cannot reconstruct — skip rather than POST garbage.
    if (action.endpoint == '/api/v1/documents/upload') {
      throw ReplayPermanentFailure(
        'Document upload ${action.id} cannot be replayed automatically — '
        'please upload it manually.',
      );
    }

    switch (action.method.toUpperCase()) {
      case 'POST':
        await api.post<dynamic>(action.endpoint, data: action.data);
        return;
      case 'PUT':
        await api.put<dynamic>(action.endpoint, data: action.data);
        return;
      case 'PATCH':
        await api.patch<dynamic>(action.endpoint, data: action.data);
        return;
      case 'DELETE':
        await api.delete<dynamic>(action.endpoint);
        return;
      case 'GET':
        await api.get<dynamic>(action.endpoint);
        return;
      default:
        throw ReplayPermanentFailure(
          'Unsupported replay method ${action.method} for ${action.endpoint}',
        );
    }
  }

  /// Stops listening and releases subscriptions.
  void dispose() {
    _disposed = true;
    _connectivitySubscription?.cancel();
    _authSubscription?.close();
    _connectivitySubscription = null;
    _authSubscription = null;
  }
}
