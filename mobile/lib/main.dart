import 'dart:async' show runZonedGuarded, unawaited;
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/app/app_services.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/notification_handler.dart';

/// True when running under `flutter test` (unit + integration): the test
/// binding has no Firebase platform implementation and the native SDK must
/// not be initialised there. Production/device runs are unaffected.
final bool _isTestRun = Platform.environment['FLUTTER_TEST'] == 'true';

/// Sentry DSN supplied at build time via
/// `--dart-define=SENTRY_DSN=https://...@ingest.sentry.io/...`.
///
/// When empty — the default for local dev, tests, and CI — the crash SDK is
/// NOT initialized and every `Sentry.*` call below is a guarded no-op.
const String _sentryDsn =
    String.fromEnvironment('SENTRY_DSN', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase (Phase 5A push-infra gap FIX) ─────────────────────────
  // Previously main.dart had NO Firebase init and NO onBackgroundMessage
  // registration — the push layer could never receive background /
  // terminated messages. Both are wired here.
  //
  // Skipped under `flutter test` (FLUTTER_TEST=true): the test binding has
  // no Firebase platform implementation, so `Firebase.initializeApp()` would
  // throw there. Production behavior is unchanged — this runs on every real
  // launch.
  if (!_isTestRun) {
    await Firebase.initializeApp();

    // Registers the top-level background-message handler. Must be a top-level
    // function (not a closure) for the background isolate to invoke it.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // ── Crash reporting (blueprint §8.4) ──────────────────────────────
  // Initialized before any error handler is installed so the SDK is ready
  // when the first unhandled error fires. Skipped entirely when no DSN is
  // configured: tests/CI run without a DSN and must never touch the network.
  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init((options) {
      options.dsn = _sentryDsn;
      options.tracesSampleRate = 0.0;
    });
  }

  // ── Global error handlers ─────────────────────────────────────────
  // Every unhandled error — Flutter framework, async, and plain Dart —
  // gets dumped to the debug console with full stack trace, and forwarded
  // to Sentry when the SDK is enabled.

  FlutterError.onError = (details) {
    developer.log(
      '[FLUTTER ERROR] ${details.exception}\n${details.stack}',
      name: 'FlutterError',
    );
    if (Sentry.isEnabled) {
      unawaited(
        Sentry.captureException(
          details.exception,
          stackTrace: details.stack,
        ),
      );
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log(
      '[UNHANDLED ERROR] $error\n$stack',
      name: 'PlatformDispatcher',
    );
    if (Sentry.isEnabled) {
      unawaited(Sentry.captureException(error, stackTrace: stack));
    }
    return true; // Don't kill the app
  };

  // ── Phase 5A OS-integration services ──────────────────────────────
  // One shared ProviderContainer is handed to both the OS services and the
  // widget tree so push/quick-action/widget callbacks can read providers
  // without a BuildContext.
  final container = ProviderContainer();
  await AppServices.instance.initialize(container);

  runZonedGuarded(() {
    runApp(OperionMobileApp(container: container));
  }, (error, stack) {
    developer.log(
      '[ZONED GUARD] $error\n$stack',
      name: 'ZoneGuard',
    );
    if (Sentry.isEnabled) {
      unawaited(Sentry.captureException(error, stackTrace: stack));
    }
  });
}

/// Background / terminated-state FCM message handler (data-only payloads).
///
/// Runs in a headless isolate with NO access to the encrypted token store.
/// Alert-type messages are displayed as rich local notifications with inline
/// actions (approve/snooze/view); everything else is ignored. Actions tapped
/// here are persisted and executed on the next authenticated launch.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  try {
    // The local-notification plugin runs in this isolate too; initialize it
    // (idempotent per isolate) before showing.
    await LocalNotificationService.instance.initialize(
      onAction: (_) {},
      onBackgroundAction: firebaseMessagingNotificationBackgroundHandler,
    );
    await NotificationActionHandler.instance.showFromDataMessage(message.data);
  } catch (e) {
    developer.log(
      'PushService: background message handler failed → $e',
      name: 'PushService',
    );
  }
}
