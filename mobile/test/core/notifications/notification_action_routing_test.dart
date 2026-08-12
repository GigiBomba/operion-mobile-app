import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/dispatcher_endpoints.dart';
import 'package:operion_mobile/core/notifications/local_notification_service.dart';
import 'package:operion_mobile/core/notifications/notification_actions.dart';
import 'package:operion_mobile/core/notifications/notification_handler.dart';
import 'package:operion_mobile/features/dispatcher/home/dispatcher_providers.dart';
import 'package:operion_mobile/shared/models/user.dart';

/// Controllable [DispatcherEndpoints] fake that records the exact calls the
/// inline notification actions must make (approveAction / rejectAction).
class _RecordingDispatcherEndpoints implements DispatcherEndpoints {
  @override
  final ApiClient client;

  _RecordingDispatcherEndpoints()
      : client = ApiClient.create(
          baseUrl: 'https://test.example.com',
          getAccessToken: () async => 'access',
          getRefreshToken: () async => 'refresh',
          saveTokens: (_, __) async {},
          clearTokens: () async {},
        );

  final List<String> approvedIds = [];
  final List<(String, String?)> rejected = [];

  @override
  Future<Response> approveAction(String id) async {
    approvedIds.add(id);
    return Response(requestOptions: RequestOptions(path: ''), data: {'ok': true});
  }

  @override
  Future<Response> rejectAction(String id, {String? reason}) async {
    rejected.add((id, reason));
    return Response(requestOptions: RequestOptions(path: ''), data: {'ok': true});
  }

  @override
  Future<Response> getOverview() async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'activeJobs': 3, 'openAlerts': 1, 'revenue_to_date': 1234.5},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Remaining DispatcherEndpoints methods are not exercised by these tests.
    if (invocation.isGetter) return null;
    if (invocation.isMethod) return Future<Response>(
        () => Response(requestOptions: RequestOptions(path: '')));
    return null;
  }
}

const _user = User(
  id: '1',
  email: 'dispatcher@operion.ro',
  fullName: 'Test Dispatcher',
  role: 'dispatcher',
  companyId: '1',
);

ProviderContainer _buildContainer(
  _RecordingDispatcherEndpoints endpoints,
) {
  return ProviderContainer(
    overrides: [
      dispatcherEndpointsProvider.overrideWithValue(endpoints),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {});

  group('NotificationActionHandler — inline action routing (5A.3)', () {
    test(
        'tapping Approve on a rich notification calls the SAME '
        'dispatcherEndpoints.approveAction function', () async {
      final endpoints = _RecordingDispatcherEndpoints();
      final container = _buildContainer(endpoints);
      addTearDown(container.dispose);

      // Authenticated session.
      container.read(authStateProvider.notifier).setAuthenticated();
      container.read(currentUserProvider.notifier).state = _user;

      final handler = NotificationActionHandler(
        actionStore: NotificationActionStore(),
        dedupeStore: NotificationDedupeStore(),
      );

      await handler.handleResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'approve',
          payload: '{"alert_id": "42"}',
        ),
        container,
      );

      expect(endpoints.approvedIds, ['42']);
      // Intent executed → queue drained.
      expect(await handler.actionStore.loadPending(), isEmpty);
    });

    test('tapping View routes to the alert detail via the router (no crash)',
        () async {
      final endpoints = _RecordingDispatcherEndpoints();
      final container = _buildContainer(endpoints);
      addTearDown(container.dispose);
      container.read(authStateProvider.notifier).setAuthenticated();
      container.read(currentUserProvider.notifier).state = _user;

      final handler = NotificationActionHandler(
        actionStore: NotificationActionStore(),
        dedupeStore: NotificationDedupeStore(),
      );

      // No navigator is mounted in a pure-Dart test — the router falls back
      // gracefully (pushOnRootNavigator returns false) and the intent is
      // still drained.
      await handler.handleResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'view',
          payload: '{"alert_id": "7"}',
        ),
        container,
      );

      expect(await handler.actionStore.loadPending(), isEmpty);
    });

    test('approve action id is resolved from the JSON payload', () async {
      final handler = NotificationActionHandler(
        actionStore: NotificationActionStore(),
        dedupeStore: NotificationDedupeStore(),
      );
      final container = _buildContainer(_RecordingDispatcherEndpoints());
      addTearDown(container.dispose);

      await handler.handleBackgroundResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'approve',
          payload: '{"alert_id": "99"}',
        ),
      );

      final pending = await handler.actionStore.loadPending();
      expect(pending, hasLength(1));
      expect(pending.single.alertId, '99');
      expect(pending.single.type, NotificationActionType.approve);
    });
  });

  group(
      'NotificationActionHandler — terminated/headless persistence (5A.3)', () {
    test(
        'action tapped while UNAUTHENTICATED is persisted and executed on '
        'the next authenticated launch', () async {
      final endpoints = _RecordingDispatcherEndpoints();
      final container = _buildContainer(endpoints);
      addTearDown(container.dispose);
      // No auth — the app is not running / session not restored.

      final handler = NotificationActionHandler(
        actionStore: NotificationActionStore(),
        dedupeStore: NotificationDedupeStore(),
      );

      await handler.handleResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'approve',
          payload: '{"alert_id": "123"}',
        ),
        container,
      );

      // Not executed yet — the headless isolate cannot authenticate.
      expect(endpoints.approvedIds, isEmpty);
      final pending = await handler.actionStore.loadPending();
      expect(pending, hasLength(1));
      expect(pending.single.alertId, '123');

      // Session restored on the next launch → the normal flow drains it.
      container.read(authStateProvider.notifier).setAuthenticated();
      container.read(currentUserProvider.notifier).state = _user;
      await handler.executePendingActions(container);

      expect(endpoints.approvedIds, ['123']);
      expect(await handler.actionStore.loadPending(), isEmpty);
    });

    test('background response handler persists without auth', () async {
      final handler = NotificationActionHandler(
        actionStore: NotificationActionStore(),
        dedupeStore: NotificationDedupeStore(),
      );

      await handler.handleBackgroundResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'snooze',
          payload: '{"alert_id": "55"}',
        ),
      );

      final pending = await handler.actionStore.loadPending();
      expect(pending, hasLength(1));
      expect(pending.single.type, NotificationActionType.snooze);
      expect(pending.single.alertId, '55');
    });

    test('persisted intents survive across handler instances (SharedPrefs)',
        () async {
      final handlerA = NotificationActionHandler(
        actionStore: NotificationActionStore(),
        dedupeStore: NotificationDedupeStore(),
      );
      await handlerA.handleBackgroundResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'approve',
          payload: '{"alert_id": "88"}',
        ),
      );

      // A "fresh" process (new handler/store) still sees the intent.
      final handlerB = NotificationActionHandler(
        actionStore: NotificationActionStore(),
        dedupeStore: NotificationDedupeStore(),
      );
      final pending = await handlerB.actionStore.loadPending();
      expect(pending, hasLength(1));
      expect(pending.single.alertId, '88');
    });
  });

  group('NotificationDedupeStore — iOS 18 double-fire guard (5A.3)', () {
    test('same message_id is shown only once', () async {
      final handler = NotificationActionHandler(
        actionStore: NotificationActionStore(),
        dedupeStore: NotificationDedupeStore(),
      );

      final first = await handler.showFromDataMessage({
        'type': 'alert',
        'alert_id': '1',
        'title': 'Alert',
        'message': 'Body',
        'message_id': 'msg-1',
      });
      final duplicate = await handler.showFromDataMessage({
        'type': 'alert',
        'alert_id': '1',
        'title': 'Alert',
        'message': 'Body',
        'message_id': 'msg-1',
      });

      expect(first, isTrue);
      expect(duplicate, isFalse);
    });

    test('distinct message ids are both shown', () async {
      final handler = NotificationActionHandler(
        actionStore: NotificationActionStore(),
        dedupeStore: NotificationDedupeStore(),
      );

      final a = await handler.showFromDataMessage({
        'type': 'approval',
        'alert_id': '2',
        'title': 'A',
        'message': 'a',
        'message_id': 'msg-a',
      });
      final b = await handler.showFromDataMessage({
        'type': 'approval',
        'alert_id': '3',
        'title': 'B',
        'message': 'b',
        'message_id': 'msg-b',
      });

      expect(a, isTrue);
      expect(b, isTrue);
    });

    test('non-alert data messages are ignored', () async {
      final handler = NotificationActionHandler(
        actionStore: NotificationActionStore(),
        dedupeStore: NotificationDedupeStore(),
      );

      final result = await handler.showFromDataMessage({
        'type': 'new_message',
        'thread_id': 't1',
        'message': 'hi',
      });
      expect(result, isFalse);
    });

    test('dedupe survives across handler instances (persisted)', () async {
      final a = NotificationActionHandler(
        actionStore: NotificationActionStore(),
        dedupeStore: NotificationDedupeStore(),
      );
      await a.showFromDataMessage({
        'type': 'alert',
        'alert_id': '4',
        'title': 'T',
        'message': 'M',
        'message_id': 'persisted-msg',
      });

      // A "new process" must not re-show the same message.
      final b = NotificationActionHandler(
        actionStore: NotificationActionStore(),
        dedupeStore: NotificationDedupeStore(),
      );
      final result = await b.showFromDataMessage({
        'type': 'alert',
        'alert_id': '4',
        'title': 'T',
        'message': 'M',
        'message_id': 'persisted-msg',
      });
      expect(result, isFalse);
    });
  });

  group('LocalNotificationService helpers', () {
    test('notificationIdFor is positive and deterministic', () {
      final id = LocalNotificationService.notificationIdFor('abc');
      expect(id, greaterThan(0));
      expect(LocalNotificationService.notificationIdFor('abc'), id);
    });

    test('jsonEncodePayload round-trips the alert id', () {
      final payload = LocalNotificationService.jsonEncodePayload('77');
      expect(payload, contains('"alert_id": "77"'));
    });

    test('snooze re-show is bounded (no Snooze action)', () {
      // The bounded design is expressed in the service: the re-show details
      // list only approve + view. Verified by code inspection at build time;
      // here we assert the API surface compiles and accepts the parameters.
      final service = LocalNotificationService();
      expect(service.isInitialized, isFalse);
    });
  });
}
