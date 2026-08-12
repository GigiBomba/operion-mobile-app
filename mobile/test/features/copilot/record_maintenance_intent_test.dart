import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/copilot_endpoints.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/features/copilot/models/copilot_models.dart';
import 'package:operion_mobile/features/copilot/providers/copilot_providers.dart';
import 'package:operion_mobile/features/copilot/screens/copilot_screen.dart';
import 'package:operion_mobile/features/fleet/models/truck.dart';
import 'package:operion_mobile/features/fleet/providers/fleet_providers.dart';
import 'package:operion_mobile/shared/models/user.dart';

import '../../support/fake_local_database.dart';

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

const _dispatcherUser = User(
  id: 'u1',
  email: 'disp@operion.ro',
  fullName: 'Disp',
  role: 'dispatcher',
  companyId: 'c1',
);

/// Endpoints stub whose `chat` returns a configured response and whose
/// `confirmPlan`/`cancelPlan` calls are recorded.
class _FakeCopilotEndpoints extends CopilotEndpoints {
  _FakeCopilotEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  CopilotResponse Function()? onChat;
  int confirmPlanCalls = 0;
  int cancelPlanCalls = 0;

  @override
  Future<CopilotResponse> chat({
    required String utterance,
    String? conversationId,
    String language = 'en',
    CancelToken? cancelToken,
  }) async {
    return onChat?.call() ??
        const CopilotResponse(conversationId: 'conv-test');
  }

  @override
  Future<Map<String, dynamic>> confirmPlan(
    String planId,
    CancelToken? cancelToken, {
    String? confirmationPhrase,
  }) async {
    confirmPlanCalls++;
    return {'status': 'completed'};
  }

  @override
  Future<Map<String, dynamic>> cancelPlan(String planId) async {
    cancelPlanCalls++;
    return {'status': 'cancelled'};
  }
}

/// Records enqueue() calls so tests can assert the offline mutation path.
class _RecordingActionQueue implements ActionQueue {
  final List<(String, String, Map<String, dynamic>)> enqueued = [];

  @override
  int get pendingCount => enqueued.length;

  @override
  int get staleCount => 0;

  @override
  Stream<ActionQueueState> get state => const Stream.empty();

  @override
  Future<String> enqueue(
    String endpoint,
    String method, {
    Map<String, dynamic>? data,
  }) async {
    enqueued.add((endpoint, method, data ?? const {}));
    return 'fake-id';
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dequeue(String id) async {}

  @override
  Future<int> replayAll(
    Future<dynamic> Function(QueuedAction action) executor,
  ) async =>
      0;

  @override
  Future<void> clear() async {}

  @override
  Future<void> clearStale() async {}

  @override
  void dispose() {}
}

/// The backend `record_maintenance` step fixture (contract from MINI-LANE).
CopilotExecutionStep _maintenanceStep({
  Map<String, dynamic>? parameters,
}) {
  return CopilotExecutionStep(
    stepId: 's-maint',
    toolName: 'record_maintenance',
    confirmationLevel: 2,
    status: 'pending',
    parameters: parameters ??
        {
          'truck_id': 1,
          'plate_number': 'B-100-ABC',
          'category': 'oil_change',
          'cost': 350.0,
          'notes': 'Service anual',
          'date': '2026-07-31',
        },
  );
}

CopilotExecutionPlan _planWithSteps(List<CopilotExecutionStep> steps) {
  return CopilotExecutionPlan(
    planId: 'plan-maint',
    conversationId: 'conv-maint',
    intent: const CopilotIntent(
      name: 'record_maintenance',
      rawUtterance: 'record maintenance on B-100-ABC oil change 350',
    ),
    requiresConfirmation: true,
    steps: steps,
  );
}

void main() {
  group('MaintenancePrefill.fromStepParameters', () {
    test('maps full backend params onto the sheet pre-fill', () {
      final prefill = MaintenancePrefill.fromStepParameters({
        'truck_id': 1,
        'plate_number': 'B-100-ABC',
        'category': 'tires',
        'cost': 420.5,
        'notes': 'Set nou',
        'date': '2026-07-31',
      });

      expect(prefill.plateNumber, 'B-100-ABC');
      expect(prefill.category, MaintenanceCategory.tires);
      expect(prefill.cost, 420.5);
      expect(prefill.notes, 'Set nou');
      expect(prefill.date, DateTime(2026, 7, 31));
    });

    test('unknown category/cost degrade safely (sheet stays valid)', () {
      final prefill = MaintenancePrefill.fromStepParameters({
        'truck_id': 1,
        'plate_number': 'B-100-ABC',
        'category': 'unsupported_things',
        'cost': 'not-a-number',
      });

      // fromApiString falls back to `other`; the bad cost stays null.
      expect(prefill.category, MaintenanceCategory.other);
      expect(prefill.cost, isNull);
    });

    test('date string maps to a DateTime', () {
      final prefill =
          MaintenancePrefill.fromStepParameters({'date': '2026-07-31'});
      expect(prefill.date, DateTime(2026, 7, 31));
    });
  });

  group('CopilotStateNotifier — record_maintenance interception', () {
    late _FakeCopilotEndpoints fakeEndpoints;
    late ProviderContainer container;
    late FakeLocalDatabase db;

    ProviderContainer buildContainer(User user, {bool offline = false}) {
      db = FakeLocalDatabase()
        ..seedCollection('fleet', [
          {'id': 't1', 'plate': 'B-100-ABC'},
          {'id': 't2', 'plate': 'B-200-DEF'},
        ]);
      return ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => user),
          isOfflineProvider.overrideWith((ref) => offline),
          localDatabaseProvider.overrideWithValue(db),
          copilotEndpointsProvider.overrideWithValue(fakeEndpoints),
        ],
      );
    }

    setUp(() {
      fakeEndpoints = _FakeCopilotEndpoints();
      container = buildContainer(_adminUser);
      addTearDown(container.dispose);
    });

    test('intercepts a record_maintenance plan into maintenance capture',
        () async {
      fakeEndpoints.onChat = () => CopilotResponse(
            conversationId: 'conv-1',
            plan: _planWithSteps([_maintenanceStep()]),
          );

      final notifier = container.read(copilotStateProvider.notifier);
      await notifier
          .sendMessage('record maintenance on B-100-ABC oil change 350');

      final state = notifier.state;
      expect(state, isA<CopilotAwaitingMaintenanceCapture>());
      final capture = state as CopilotAwaitingMaintenanceCapture;
      expect(capture.plan.planId, 'plan-maint');
      // truck_id from the plan wins; plate resolution is a fallback.
      expect(capture.truckId, '1');
      expect(capture.prefill.category, MaintenanceCategory.oilChange);
      expect(capture.prefill.cost, 350.0);
      expect(capture.prefill.plateNumber, 'B-100-ABC');
      // confirmPlan was NOT used — the mobile owns execution.
      expect(fakeEndpoints.confirmPlanCalls, 0);
    });

    test('resolves truck by plate from the fleet cache when truck_id absent',
        () async {
      fakeEndpoints.onChat = () => CopilotResponse(
            conversationId: 'conv-2',
            plan: _planWithSteps([
              _maintenanceStep(parameters: {
                'plate_number': 'B-100-ABC',
                'category': 'brakes',
                'cost': 99.0,
              }),
            ]),
          );

      final notifier = container.read(copilotStateProvider.notifier);
      await notifier.sendMessage('brakes on B-100-ABC');

      final capture = notifier.state as CopilotAwaitingMaintenanceCapture;
      expect(capture.truckId, 't1');
    });

    test('SAME-FUNCTION-REFERENCE proof: intent submit == manual form entry',
        () async {
      fakeEndpoints.onChat = () => CopilotResponse(
            conversationId: 'conv-3',
            plan: _planWithSteps([_maintenanceStep()]),
          );

      final notifier = container.read(copilotStateProvider.notifier);
      await notifier.sendMessage('record maintenance on B-100-ABC');

      final capture = notifier.state as CopilotAwaitingMaintenanceCapture;
      // The capture's submit closure IS the same top-level function the manual
      // form (truck_detail / maintenance_screen) calls. Top-level function
      // references are identical in Dart — this is the literal shared
      // reference, not a lookalike copy.
      expect(capture.submit, same(submitRecordMaintenance));
    });

    test('completeMaintenanceCapture cancels the pending plan and completes',
        () async {
      fakeEndpoints.onChat = () => CopilotResponse(
            conversationId: 'conv-4',
            plan: _planWithSteps([_maintenanceStep()]),
          );
      container.dispose();
      container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => _adminUser),
          isOfflineProvider.overrideWith((ref) => false),
          localDatabaseProvider.overrideWithValue(db),
          copilotEndpointsProvider.overrideWithValue(fakeEndpoints),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(copilotStateProvider.notifier);
      await notifier.sendMessage('record maintenance on B-100-ABC');
      expect(notifier.state, isA<CopilotAwaitingMaintenanceCapture>());

      await notifier.completeMaintenanceCapture();

      // The pending server plan was cancelled, never confirmed.
      expect(fakeEndpoints.cancelPlanCalls, 1);
      expect(fakeEndpoints.confirmPlanCalls, 0);
      expect(notifier.state, isA<CopilotCompleted>());
    });

    test('non-maintenance plans keep the standard confirmation flow', () async {
      fakeEndpoints.onChat = () => CopilotResponse(
            conversationId: 'conv-5',
            plan: _planWithSteps([
              const CopilotExecutionStep(
                stepId: 's1',
                toolName: 'vehicle.search',
                confirmationLevel: 2,
                status: 'pending',
              ),
            ]),
          );

      final notifier = container.read(copilotStateProvider.notifier);
      await notifier.sendMessage('find trucks');

      expect(notifier.state, isA<CopilotAwaitingConfirmation>());
    });

    test('record_maintenance WITHOUT can_schedule_maintenance is NOT intercepted',
        () async {
      // dispatcher has no can_schedule_maintenance (real matrix).
      container.dispose();
      container = buildContainer(_dispatcherUser);
      addTearDown(container.dispose);

      fakeEndpoints.onChat = () => CopilotResponse(
            conversationId: 'conv-6',
            plan: _planWithSteps([_maintenanceStep()]),
          );

      final notifier = container.read(copilotStateProvider.notifier);
      await notifier.sendMessage('record maintenance on B-100-ABC');

      expect(notifier.state, isA<CopilotAwaitingConfirmation>());
    });

    test('incomplete params (no truck, no cost) still capture with partial prefill',
        () async {
      fakeEndpoints.onChat = () => CopilotResponse(
            conversationId: 'conv-7',
            plan: _planWithSteps([
              _maintenanceStep(parameters: {
                'category': 'other',
              }),
            ]),
          );

      final notifier = container.read(copilotStateProvider.notifier);
      await notifier.sendMessage('record maintenance');

      final capture = notifier.state as CopilotAwaitingMaintenanceCapture;
      expect(capture.truckId, isNull); // sheet opens empty → UI picks truck
      expect(capture.prefill.category, MaintenanceCategory.other);
      expect(capture.prefill.cost, isNull);
    });
  });

  group('CopilotScreen — maintenance capture UI', () {
    testWidgets(
        'confirm opens the PRE-FILLED sheet and submits via the shared path',
        (tester) async {
      final fakeEndpoints = _FakeCopilotEndpoints();
      final queue = _RecordingActionQueue();
      final db = FakeLocalDatabase()
        ..seedCollection('fleet', [
          {'id': 't1', 'plate': 'B-100-ABC'},
        ]);
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => _adminUser),
          isOfflineProvider.overrideWith((ref) => true),
          localDatabaseProvider.overrideWithValue(db),
          actionQueueProvider.overrideWithValue(queue),
          copilotEndpointsProvider.overrideWithValue(fakeEndpoints),
          fleetListProvider.overrideWith((ref) async =>
              const FleetListData(trucks: [], fromCache: false)),
        ],
      );
      addTearDown(container.dispose);

      // Drive the real notifier into the maintenance-capture state.
      fakeEndpoints.onChat = () => CopilotResponse(
            conversationId: 'conv-ui',
            plan: _planWithSteps([_maintenanceStep()]),
          );
      final notifier = container.read(copilotStateProvider.notifier);
      await notifier.sendMessage('record maintenance on B-100-ABC');
      expect(notifier.state, isA<CopilotAwaitingMaintenanceCapture>());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: CopilotScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bar is visible with the prefill summary (plate · category · cost · notes).
      expect(find.text('Record maintenance'), findsOneWidget);
      expect(find.text('B-100-ABC · oil_change · 350.00 · Service anual'),
          findsOneWidget);

      // Confirm → the pre-filled sheet opens (cost pre-filled).
      await tester.tap(find.text('Pre-fill & confirm'));
      await tester.pumpAndSettle();
      expect(find.text('350'), findsOneWidget);

      // One-tap save → the shared mutation path enqueues the mapped draft.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(queue.enqueued, hasLength(1));
      // truck_id (1) from the plan wins over the plate-resolved id.
      expect(queue.enqueued.single.$1, '/api/v1/mobile/fleet/1/maintenance');
      expect(queue.enqueued.single.$3['category'], 'oil_change');
      expect(queue.enqueued.single.$3['cost'], 350.0);
    });
  });
}
