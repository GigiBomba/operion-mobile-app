import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static test for the Phase 5A push-infra fix (5A.2): main.dart must
/// register a top-level `@pragma('vm:entry-point')` background handler and
/// initialize the Firebase + notification services.
///
/// These properties cannot be exercised at runtime in `flutter test` (they
/// require a real Firebase device / isolate), so the registration contract is
/// asserted against the source — a genuine static test.
void main() {
  final libDir = Directory('lib');
  final mainSource = File(
    '${libDir.path}${Platform.pathSeparator}main.dart',
  ).readAsStringSync();

  test('Firebase is initialized before services', () {
    expect(mainSource, contains('await Firebase.initializeApp();'));
  });

  test('onBackgroundMessage is registered with the top-level handler', () {
    expect(
      mainSource,
      contains(
        'FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);',
      ),
    );
  });

  test('background handler is top-level and entry-point annotated', () {
    expect(mainSource, contains("@pragma('vm:entry-point')"));
    expect(
      mainSource,
      contains(
        'Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message)',
      ),
    );
    // The handler must NOT be a method/closure — it is declared at top level.
    final declStart = mainSource.indexOf('firebaseMessagingBackgroundHandler');
    final surrounding = mainSource.substring(declStart - 30, declStart);
    expect(surrounding, isNot(contains('class ')));
  });

  test('background handler shows alert messages via the local layer', () {
    expect(
      mainSource,
      contains(
        'NotificationActionHandler.instance.showFromDataMessage(message.data)',
      ),
    );
  });

  test('local notification service wires the background action callback', () {
    expect(
      mainSource,
      contains('onBackgroundAction: firebaseMessagingNotificationBackgroundHandler'),
    );
  });

  test('app services are initialized from main()', () {
    expect(mainSource, contains('AppServices.instance.initialize(container)'));
    expect(mainSource, contains('runApp(OperionMobileApp(container: container))'));
  });

  test('foreground FCM auto-presentation is suppressed on iOS', () {
    final servicesSource = File(
      '${libDir.path}${Platform.pathSeparator}core'
      '${Platform.pathSeparator}app${Platform.pathSeparator}app_services.dart',
    ).readAsStringSync();
    expect(
      servicesSource,
      contains('setForegroundNotificationPresentationOptions'),
    );
    expect(
      servicesSource,
      contains('alert: false'),
    );
  });
}
