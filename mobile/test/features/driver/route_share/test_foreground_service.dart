import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/features/driver/route_share/logic/gps_logic.dart';
import 'package:operion_mobile/features/driver/route_share/services/foreground_navigation_service.dart';

// Blueprint §11 / §7.2.3 test requirement: the Android foreground-service
// notification content builder is pure and unit-testable, and the service
// controller's state machine (idle → running → stopping) is exercised WITHOUT
// the platform plugin via an injected fake adapter.

/// Fake adapter recording calls. [stopGate]/[startGate] let a test hold a
/// platform call in flight so the controller's transient states are
/// observable; [failStart] simulates the plugin refusing to start.
class _RecordingAdapter implements ForegroundServiceAdapter {
  int initializeCount = 0;
  int startCount = 0;
  int updateCount = 0;
  int stopCount = 0;
  String? lastChannelName;
  NavigationNotificationContent? lastContent;
  bool failStart = false;
  Completer<void>? stopGate;
  Completer<void>? startGate;

  @override
  Future<void> initialize({required String channelName}) async {
    initializeCount++;
    lastChannelName = channelName;
  }

  @override
  Future<void> start({required NavigationNotificationContent content}) async {
    if (failStart) throw StateError('plugin refused to start');
    startCount++;
    lastContent = content;
    await startGate?.future;
  }

  @override
  Future<void> update({required NavigationNotificationContent content}) async {
    updateCount++;
    lastContent = content;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    await stopGate?.future;
  }
}

void main() {
  group('buildNavigationNotificationContent — §7.2.3 notification content', () {
    test('default template: title = instruction, body = distance · eta',
        () {
      final content = buildNavigationNotificationContent(
        instructionText: 'Turn left',
        distanceLabel: '350 m',
        etaLabel: '5 min',
      );
      expect(content.title, 'Turn left');
      expect(content.body, '350 m · 5 min remaining');
    });

    test('custom (localized) templates fill every placeholder', () {
      final content = buildNavigationNotificationContent(
        instructionText: 'Viraj la stânga',
        distanceLabel: '12.4 km',
        etaLabel: '25 min',
        titleTemplate: 'Navigare: {instruction}',
        bodyTemplate: '{distance} · {eta} rămase',
      );
      expect(content.title, 'Navigare: Viraj la stânga');
      expect(content.body, '12.4 km · 25 min rămase');
    });

    test('empty instruction/distance/eta → no leftover placeholders, no throw',
        () {
      final content = buildNavigationNotificationContent(
        instructionText: '',
        distanceLabel: '',
        etaLabel: '',
      );
      expect(content.title.contains('{instruction}'), isFalse);
      expect(content.body.contains('{distance}'), isFalse);
      expect(content.body.contains('{eta}'), isFalse);
    });

    test('template without a matching placeholder passes through unchanged',
        () {
      final content = buildNavigationNotificationContent(
        instructionText: 'Go',
        distanceLabel: '1 km',
        etaLabel: '2 min',
        titleTemplate: 'Operion',
        bodyTemplate: '{distance} — {eta}',
      );
      expect(content.title, 'Operion');
      expect(content.body, '1 km — 2 min');
    });

    test('km labels and multi-hour ETA labels are passed through verbatim', () {
      final content = buildNavigationNotificationContent(
        instructionText: 'Continue straight',
        distanceLabel: '412.0 km',
        etaLabel: '5h 10m',
      );
      expect(content.title, 'Continue straight');
      expect(content.body, '412.0 km · 5h 10m remaining');
    });
  });

  group('ForegroundNavigationController — state machine (idle → running → stopping)',
      () {
    late _RecordingAdapter adapter;
    late ForegroundNavigationController controller;

    setUp(() {
      adapter = _RecordingAdapter();
      controller = ForegroundNavigationController(adapter: adapter);
    });

    const startArgs = (
      instructionText: 'Turn left',
      distanceLabel: '350 m',
      etaLabel: '5 min',
      channelName: 'Navigation',
    );

    test('start: idle → running, initializes + starts with composed content',
        () async {
      final started = await controller.start(
        instructionText: startArgs.instructionText,
        distanceLabel: startArgs.distanceLabel,
        etaLabel: startArgs.etaLabel,
        channelName: startArgs.channelName,
      );
      expect(started, isTrue);
      expect(controller.state, ForegroundServiceState.running);
      expect(adapter.initializeCount, 1);
      expect(adapter.startCount, 1);
      expect(adapter.lastChannelName, 'Navigation');
      expect(adapter.lastContent?.title, 'Turn left');
      expect(adapter.lastContent?.body, '350 m · 5 min remaining');
    });

    test('duplicate start is a no-op: returns false, one platform start', () async {
      final first = await controller.start(
        instructionText: startArgs.instructionText,
        distanceLabel: startArgs.distanceLabel,
        etaLabel: startArgs.etaLabel,
        channelName: startArgs.channelName,
      );
      final second = await controller.start(
        instructionText: startArgs.instructionText,
        distanceLabel: startArgs.distanceLabel,
        etaLabel: startArgs.etaLabel,
        channelName: startArgs.channelName,
      );
      expect(first, isTrue);
      expect(second, isFalse);
      expect(controller.state, ForegroundServiceState.running);
      expect(adapter.startCount, 1);
      expect(adapter.initializeCount, 1);
    });

    test('concurrent start while the first is still in flight is rejected',
        () async {
      adapter.startGate = Completer<void>();
      final first = controller.start(
        instructionText: startArgs.instructionText,
        distanceLabel: startArgs.distanceLabel,
        etaLabel: startArgs.etaLabel,
        channelName: startArgs.channelName,
      );
      final second = await controller.start(
        instructionText: startArgs.instructionText,
        distanceLabel: startArgs.distanceLabel,
        etaLabel: startArgs.etaLabel,
        channelName: startArgs.channelName,
      );
      expect(second, isFalse);
      expect(controller.state, ForegroundServiceState.running);
      adapter.startGate!.complete();
      await first;
      expect(adapter.startCount, 1);
    });

    test('failed start returns false and resets to idle (retryable)', () async {
      adapter.failStart = true;
      final started = await controller.start(
        instructionText: startArgs.instructionText,
        distanceLabel: startArgs.distanceLabel,
        etaLabel: startArgs.etaLabel,
        channelName: startArgs.channelName,
      );
      expect(started, isFalse);
      expect(controller.state, ForegroundServiceState.idle);
      expect(adapter.startCount, 0);

      adapter.failStart = false;
      final retried = await controller.start(
        instructionText: startArgs.instructionText,
        distanceLabel: startArgs.distanceLabel,
        etaLabel: startArgs.etaLabel,
        channelName: startArgs.channelName,
      );
      expect(retried, isTrue);
      expect(controller.state, ForegroundServiceState.running);
      expect(adapter.startCount, 1);
    });

    test('update refreshes the notification; identical content is skipped',
        () async {
      await controller.start(
        instructionText: startArgs.instructionText,
        distanceLabel: startArgs.distanceLabel,
        etaLabel: startArgs.etaLabel,
        channelName: startArgs.channelName,
      );
      final updatesBefore = adapter.updateCount;

      // Same instruction/distance/ETA as the initial content → no platform call.
      await controller.update(
        instructionText: startArgs.instructionText,
        distanceLabel: startArgs.distanceLabel,
        etaLabel: startArgs.etaLabel,
      );
      expect(adapter.updateCount, updatesBefore);

      // Changed instruction/distance → platform update with new content.
      await controller.update(
        instructionText: 'Turn right',
        distanceLabel: '120 m',
        etaLabel: '2 min',
      );
      expect(adapter.updateCount, updatesBefore + 1);
      expect(adapter.lastContent?.title, 'Turn right');
      expect(adapter.lastContent?.body, '120 m · 2 min remaining');
    });

    test('update while idle is a no-op (no platform call)', () async {
      await controller.update(
        instructionText: startArgs.instructionText,
        distanceLabel: startArgs.distanceLabel,
        etaLabel: startArgs.etaLabel,
      );
      expect(controller.state, ForegroundServiceState.idle);
      expect(adapter.updateCount, 0);
      expect(adapter.startCount, 0);
    });

    test('stop tears the service down and returns to idle; repeat stop is safe',
        () async {
      await controller.start(
        instructionText: startArgs.instructionText,
        distanceLabel: startArgs.distanceLabel,
        etaLabel: startArgs.etaLabel,
        channelName: startArgs.channelName,
      );
      await controller.stop();
      expect(controller.state, ForegroundServiceState.idle);
      expect(adapter.stopCount, 1);

      await controller.stop();
      expect(adapter.stopCount, 1);
      expect(controller.state, ForegroundServiceState.idle);
    });

    test('stop while idle is a no-op (no platform call)', () async {
      await controller.stop();
      expect(controller.state, ForegroundServiceState.idle);
      expect(adapter.stopCount, 0);
    });

    test('stop observes the transient "stopping" state while teardown is in flight',
        () async {
      await controller.start(
        instructionText: startArgs.instructionText,
        distanceLabel: startArgs.distanceLabel,
        etaLabel: startArgs.etaLabel,
        channelName: startArgs.channelName,
      );
      adapter.stopGate = Completer<void>();
      final stopFuture = controller.stop();
      expect(controller.state, ForegroundServiceState.stopping);
      adapter.stopGate!.complete();
      await stopFuture;
      expect(controller.state, ForegroundServiceState.idle);
    });

    test('update while stopping is a no-op (never reaches the platform)',
        () async {
      await controller.start(
        instructionText: startArgs.instructionText,
        distanceLabel: startArgs.distanceLabel,
        etaLabel: startArgs.etaLabel,
        channelName: startArgs.channelName,
      );
      adapter.stopGate = Completer<void>();
      final stopFuture = controller.stop();
      expect(controller.state, ForegroundServiceState.stopping);

      await controller.update(
        instructionText: 'Turn right',
        distanceLabel: '120 m',
        etaLabel: '2 min',
      );
      expect(adapter.updateCount, 0);

      adapter.stopGate!.complete();
      await stopFuture;
    });
  });
}
