import 'dart:io' show Platform;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/gps_logic.dart';

// ---------------------------------------------------------------------------
// Foreground navigation service (blueprint §7.2.3 — the Android foreground
// service with persistent notification that keeps backgrounded/screen-locked
// turn-by-turn navigation alive and shows the next instruction + remaining
// distance, mirroring Google Maps' own notification).
//
// [ForegroundNavigationController] is a pure, platform-free state machine
// (idle → running → stopping). Every platform interaction happens through the
// narrow [ForegroundServiceAdapter] seam, so the controller logic is
// unit-testable WITHOUT the plugin (tests inject a fake adapter).
// ---------------------------------------------------------------------------

/// Lifecycle state of the foreground navigation service.
enum ForegroundServiceState { idle, running, stopping }

/// Narrow platform seam for the persistent-notification foreground service.
abstract class ForegroundServiceAdapter {
  /// One-time setup (notification channel on Android, plugin options).
  Future<void> initialize({required String channelName});

  /// Starts the foreground service with the given notification content.
  Future<void> start({required NavigationNotificationContent content});

  /// Refreshes the notification content as the driver moves.
  Future<void> update({required NavigationNotificationContent content});

  /// Tears the service down.
  Future<void> stop();
}

/// Real adapter backed by the `flutter_foreground_task` plugin.
///
/// Android-only by design: iOS background location is handled natively by
/// geolocator's "Always" authorization plus `UIBackgroundModes.location` —
/// the plugin's iOS background task is intentionally not used for turn-by-turn.
/// On non-Android platforms every method is a no-op (the controller still
/// tracks state, but nothing touches the plugin).
class FlutterForegroundTaskAdapter implements ForegroundServiceAdapter {
  const FlutterForegroundTaskAdapter();

  static const int _serviceId = 256;

  @override
  Future<void> initialize({required String channelName}) async {
    if (!Platform.isAndroid) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'operion_navigation',
        channelName: channelName,
        channelDescription: channelName,
        onlyAlertOnce: true,
        showWhen: false,
        showBadge: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
        stopWithTask: true,
      ),
    );
  }

  @override
  Future<void> start({required NavigationNotificationContent content}) async {
    if (!Platform.isAndroid) return;
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: content.title,
      notificationText: content.body,
    );
    if (result is ServiceRequestFailure) {
      throw result.error;
    }
  }

  @override
  Future<void> update({required NavigationNotificationContent content}) async {
    if (!Platform.isAndroid) return;
    final result = await FlutterForegroundTask.updateService(
      notificationTitle: content.title,
      notificationText: content.body,
    );
    if (result is ServiceRequestFailure) {
      throw result.error;
    }
  }

  @override
  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.stopService();
  }
}

/// Testable controller wrapping the plugin behind [ForegroundServiceAdapter].
///
/// State machine: idle → running → stopping → idle.
/// * `start` while not idle is a no-op that reports `false` (guards duplicate
///   starts, including concurrent in-flight ones — the state flips before the
///   first await).
/// * `update` only reaches the platform while running and skips content
///   identical to the last pushed one (the 5s/20m cadence already gates the
///   call site, so this is a second, cheaper dedup).
/// * `stop` is safe from any state; a stop-when-idle is a no-op.
/// * A failed `start` returns to idle so the UI can retry — graceful
///   degradation, foreground tracking is never affected.
class ForegroundNavigationController {
  ForegroundNavigationController({
    ForegroundServiceAdapter? adapter,
    this.titleTemplate = '{instruction}',
    this.bodyTemplate = '{distance} · {eta} remaining',
  }) : _adapter = adapter ?? const FlutterForegroundTaskAdapter();

  final ForegroundServiceAdapter _adapter;

  /// Localized notification title template (`{instruction}` placeholder).
  final String titleTemplate;

  /// Localized notification body template (`{distance}` + `{eta}`).
  final String bodyTemplate;

  ForegroundServiceState _state = ForegroundServiceState.idle;
  NavigationNotificationContent? _lastContent;

  /// Current lifecycle state (idle → running → stopping).
  ForegroundServiceState get state => _state;

  /// Whether the service is currently up (started and not stopping).
  bool get isRunning => _state == ForegroundServiceState.running;

  /// Starts the foreground service with the persistent notification content
  /// composed from the current guidance. Returns `false` when a service is
  /// already running/stopping or the platform refused to start it.
  Future<bool> start({
    required String instructionText,
    required String distanceLabel,
    required String etaLabel,
    required String channelName,
  }) async {
    if (_state != ForegroundServiceState.idle) return false;
    _state = ForegroundServiceState.running;
    final content = buildNavigationNotificationContent(
      instructionText: instructionText,
      distanceLabel: distanceLabel,
      etaLabel: etaLabel,
      titleTemplate: titleTemplate,
      bodyTemplate: bodyTemplate,
    );
    try {
      await _adapter.initialize(channelName: channelName);
      await _adapter.start(content: content);
      _lastContent = content;
      return true;
    } catch (_) {
      // The platform refused to start the service (e.g. notification
      // permission missing, service already running externally, Android 14
      // runtime requirement not met). Return to idle so a later retry can
      // succeed; foreground tracking is unaffected.
      _state = ForegroundServiceState.idle;
      _lastContent = null;
      return false;
    }
  }

  /// Refreshes the notification (instruction/distance/ETA change as the
  /// driver moves). No-op while idle or when the content did not change.
  Future<void> update({
    required String instructionText,
    required String distanceLabel,
    required String etaLabel,
  }) async {
    if (_state != ForegroundServiceState.running) return;
    final content = buildNavigationNotificationContent(
      instructionText: instructionText,
      distanceLabel: distanceLabel,
      etaLabel: etaLabel,
      titleTemplate: titleTemplate,
      bodyTemplate: bodyTemplate,
    );
    if (content == _lastContent) return;
    try {
      await _adapter.update(content: content);
      _lastContent = content;
    } catch (_) {
      // A failed notification refresh is non-fatal: keep the service running
      // and retry on the next cadence-emitted fix.
    }
  }

  /// Tears the service down. Safe to call from any state; no-op when idle.
  Future<void> stop() async {
    if (_state == ForegroundServiceState.idle) return;
    _state = ForegroundServiceState.stopping;
    try {
      await _adapter.stop();
    } finally {
      _state = ForegroundServiceState.idle;
      _lastContent = null;
    }
  }
}

/// Injectable foreground-service adapter (override in tests with a fake).
final foregroundServiceAdapterProvider =
    Provider<ForegroundServiceAdapter>((ref) => const FlutterForegroundTaskAdapter());
