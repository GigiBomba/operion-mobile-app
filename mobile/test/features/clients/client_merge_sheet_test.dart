import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/client_endpoints.dart';
import 'package:operion_mobile/core/security/biometric_gate.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/features/clients/models/client.dart';
import 'package:operion_mobile/features/clients/providers/client_providers.dart';
import 'package:operion_mobile/features/clients/widgets/client_merge_sheet.dart';
import 'package:operion_mobile/shared/widgets/app_button.dart';

import '../../support/fake_local_database.dart';

final List<Client> _clients = [
  const Client(
    id: 't1',
    companyId: 'c1',
    name: 'ACME Logistics',
    paymentTermsDays: 30,
    rating: 4.5,
  ),
  const Client(
    id: 's1',
    companyId: 'c1',
    name: 'Beta SRL',
    paymentTermsDays: 14,
    rating: 3.0,
  ),
];

/// Endpoints stub that records merge calls.
class _RecordingMergeEndpoints extends ClientEndpoints {
  _RecordingMergeEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<(String, List<String>)> mergeCalls = [];

  @override
  Future<Response> mergeClients({
    required String targetId,
    required List<String> sourceIds,
    CancelToken? cancelToken,
  }) async {
    mergeCalls.add((targetId, sourceIds));
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/clients/merge'),
      data: {
        'merged_trip_count': 1,
        'merged_invoice_count': 1,
        'merged_contact_count': 1,
      },
      statusCode: 200,
    );
  }
}

/// Minimal recording ActionQueue (to prove merge never enqueues).
class _RecordingActionQueue implements ActionQueue {
  final List<String> enqueued = [];

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
    enqueued.add(endpoint);
    return 'id';
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

Widget _wrap({
  required bool isOffline,
  required _RecordingMergeEndpoints endpoints,
  required _RecordingActionQueue queue,
}) {
  return ProviderScope(
    overrides: [
      isOfflineProvider.overrideWith((ref) => isOffline),
      clientEndpointsProvider.overrideWithValue(endpoints),
      actionQueueProvider.overrideWithValue(queue),
      localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
      biometricGateProvider.overrideWithValue(
        BiometricGate(authenticate: (_) async => true),
      ),
      clientDetailProvider.overrideWith(
        (ref, id) async => ClientDetailData(
          client: _clients.firstWhere((c) => c.id == id,
              orElse: () => _clients.first),
          fromCache: false,
        ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ClientMergeSheet(clients: _clients, initialTargetId: 't1'),
      ),
    ),
  );
}

AppButton _mergeButton(WidgetTester tester) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, 'Merge'));

void main() {
  group('ClientMergeSheet — typed-confirmation gate', () {
    testWidgets('merge is DISABLED until the exact target name is typed',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          isOffline: false,
          endpoints: _RecordingMergeEndpoints(),
          queue: _RecordingActionQueue(),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no confirmation text → disabled.
      expect(_mergeButton(tester).onPressed, isNull);

      // Select a source client.
      await tester.tap(find.text('Beta SRL'));
      await tester.pumpAndSettle();
      expect(_mergeButton(tester).onPressed, isNull);

      // Wrong name → still disabled.
      await tester.enterText(find.byType(TextField).last, 'WRONG');
      await tester.pumpAndSettle();
      expect(_mergeButton(tester).onPressed, isNull);

      // Exact target name → enabled.
      await tester.enterText(find.byType(TextField).last, 'ACME Logistics');
      await tester.pumpAndSettle();
      expect(_mergeButton(tester).onPressed, isNotNull);
    });
  });

  group('ClientMergeSheet — offline block (§7)', () {
    testWidgets('offline shows inline message, disables Merge, NEVER enqueues',
        (tester) async {
      final endpoints = _RecordingMergeEndpoints();
      final queue = _RecordingActionQueue();
      await tester.pumpWidget(
        _wrap(isOffline: true, endpoints: endpoints, queue: queue),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Merging requires an internet connection'),
        findsOneWidget,
      );
      expect(_mergeButton(tester).onPressed, isNull);

      // Even with correct confirmation, offline keeps it disabled.
      await tester.tap(find.text('Beta SRL'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'ACME Logistics');
      await tester.pumpAndSettle();
      expect(_mergeButton(tester).onPressed, isNull);

      // PROOF: no queue call was ever made.
      expect(queue.enqueued, isEmpty);
      expect(endpoints.mergeCalls, isEmpty);
    });
  });

  group('ClientMergeSheet — online direct call', () {
    testWidgets('online + typed confirmation calls the endpoint directly',
        (tester) async {
      final endpoints = _RecordingMergeEndpoints();
      final queue = _RecordingActionQueue();
      await tester.pumpWidget(
        _wrap(isOffline: false, endpoints: endpoints, queue: queue),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Beta SRL'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'ACME Logistics');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Merge'));
      await tester.pumpAndSettle();

      expect(endpoints.mergeCalls, hasLength(1));
      expect(endpoints.mergeCalls.single.$1, 't1');
      expect(endpoints.mergeCalls.single.$2, ['s1']);
      // Still never queued even online.
      expect(queue.enqueued, isEmpty);
    });
  });
}
