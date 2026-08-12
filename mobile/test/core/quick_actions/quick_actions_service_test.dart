import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_actions/quick_actions.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/quick_actions/quick_actions_service.dart';
import 'package:operion_mobile/features/dispatcher/alerts/alert_inbox_screen.dart';
import 'package:operion_mobile/features/dispatcher/jobs/job_list_screen.dart';
import 'package:operion_mobile/features/document_center/screens/document_center_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';

/// Fake [QuickActionsBridge] that captures the registered handler and the
/// shortcut items so tests can trigger shortcut taps without the OS.
class _FakeQuickActionsBridge implements QuickActionsBridge {
  QuickActionHandler? handler;
  List<ShortcutItem>? items;

  @override
  Future<void> initialize(QuickActionHandler handler) async {
    this.handler = handler;
  }

  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) async {
    this.items = items;
  }
}

const _user = User(
  id: '1',
  email: 'dispatcher@operion.ro',
  fullName: 'Test Dispatcher',
  role: 'dispatcher',
  companyId: '1',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuickActionService — deep-link routing (5A.2)', () {
    late _FakeQuickActionsBridge bridge;
    late List<Widget> pushed;
    late ProviderContainer container;

    setUp(() {
      bridge = _FakeQuickActionsBridge();
      pushed = [];
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    Future<QuickActionService> buildAuthenticated() async {
      container.read(authStateProvider.notifier).setAuthenticated();
      container.read(currentUserProvider.notifier).state = _user;
      final service = QuickActionService(
        bridge: bridge,
        pusher: (page) {
          pushed.add(page);
          return true;
        },
      );
      await service.initialize(container);
      return service;
    }

    test('registers exactly three shortcuts', () async {
      await buildAuthenticated();
      expect(bridge.items, hasLength(3));
      final types = bridge.items!.map((e) => e.type).toSet();
      expect(types, {
        QuickActionService.approvePending,
        QuickActionService.alertCheck,
        QuickActionService.scanDocument,
      });
    });

    test('approve_pending routes to JobListScreen with the pending filter',
        () async {
      await buildAuthenticated();
      bridge.handler!(QuickActionService.approvePending);

      expect(pushed, hasLength(1));
      final screen = pushed.single;
      expect(screen, isA<JobListScreen>());
      expect((screen as JobListScreen).initialFilter, JobFilter.pending);
    });

    test('alert_check routes to AlertInboxScreen', () async {
      await buildAuthenticated();
      bridge.handler!(QuickActionService.alertCheck);

      expect(pushed, hasLength(1));
      expect(pushed.single, isA<AlertInboxScreen>());
    });

    test('scan_document deep-links past the list into the camera tab',
        () async {
      await buildAuthenticated();
      bridge.handler!(QuickActionService.scanDocument);

      expect(pushed, hasLength(1));
      final screen = pushed.single;
      expect(screen, isA<DocumentCenterScreen>());
      expect((screen as DocumentCenterScreen).initialTab, 1);
    });

    test('unknown shortcut is ignored', () async {
      await buildAuthenticated();
      bridge.handler!('some_unknown_shortcut');
      expect(pushed, isEmpty);
    });
  });

  group('QuickActionService — auth gate (5A.2)', () {
    test(
        'shortcut tapped while UNAUTHENTICATED is deferred and routed once '
        'the session is restored', () async {
      final bridge = _FakeQuickActionsBridge();
      final pushed = <Widget>[];
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = QuickActionService(
        bridge: bridge,
        pusher: (page) {
          pushed.add(page);
          return true;
        },
      );
      await service.initialize(container);

      // No session — tap defers.
      bridge.handler!(QuickActionService.alertCheck);
      await Future<void>.delayed(Duration.zero);
      expect(pushed, isEmpty);

      // Session restored → deferred shortcut is routed automatically.
      // (Set the user BEFORE auth flips, matching ModeRouter._restoreSession.)
      container.read(currentUserProvider.notifier).state = _user;
      container.read(authStateProvider.notifier).setAuthenticated();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(pushed, hasLength(1));
      expect(pushed.single, isA<AlertInboxScreen>());
    });

    test('shortcut tapped with a session is routed immediately', () async {
      final bridge = _FakeQuickActionsBridge();
      final pushed = <Widget>[];
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authStateProvider.notifier).setAuthenticated();
      container.read(currentUserProvider.notifier).state = _user;

      final service = QuickActionService(
        bridge: bridge,
        pusher: (page) {
          pushed.add(page);
          return true;
        },
      );
      await service.initialize(container);

      bridge.handler!(QuickActionService.approvePending);
      await Future<void>.delayed(Duration.zero);

      expect(pushed, hasLength(1));
      expect(pushed.single, isA<JobListScreen>());
    });
  });
}
