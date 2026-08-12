import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/client_endpoints.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/features/clients/providers/client_providers.dart';

import 'test_support.dart';

/// Stub [ClientEndpoints] used both by the UI and by the replay executor.
class _StubClientEndpoints extends ClientEndpoints {
  _StubClientEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_access_token',
        ));

  final List<Map<String, dynamic>> clients = [
    {
      'id': 'c1',
      'company_id': '1',
      'name': 'ACME Logistics',
      'vat_number': 'RO12345678',
      'payment_terms_days': 30,
      'rating': 4.5,
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    },
  ];

  final List<String> createdNames = [];

  @override
  Future<Response> getClients({
    String? search,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: clients,
    );
  }

  @override
  Future<Response> createClient(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    final name = data['name'] as String? ?? '';
    createdNames.add(name);
    final client = <String, dynamic>{
      'id': 'c${clients.length + 1}',
      'company_id': '1',
      'name': name,
      'payment_terms_days': data['payment_terms_days'] ?? 0,
      'rating': 0,
      'is_active': data['is_active'] ?? true,
      'created_at': DateTime.now().toIso8601String(),
    };
    clients.add(client);
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: client,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Flow', () {
    testWidgets(
      '1. Airplane mode: creating a client enqueues a queued action',
      (tester) async {
        final db = await initTestLocalDatabase();
        final offline = OfflineFlag()..offline = true;
        final clientEndpoints = _StubClientEndpoints();
        final overrides = managerOverrides(
          db: db,
          user: managerUser,
          offline: offline,
          extra: [
            clientEndpointsProvider.overrideWithValue(clientEndpoints),
          ],
        );

        final container = ProviderContainer(overrides: overrides);
        addTearDown(container.dispose);
        await pumpApp(tester, overrides: overrides, container: container);

        // The offline banner is visible while airplane mode is on.
        expect(find.text('You are offline'), findsOneWidget);

        // Open Clients and create one.
        await openRecordsTab(tester);
        await tapByText(tester, 'Clients');
        expect(find.text('ACME Logistics'), findsOneWidget);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).hitTestable().first,
          'Offline SRL',
        );
        await tapByText(tester, 'Save');

        // The create-client mutation is queueable offline: it never touched
        // the network and the action sits in the queue.
        final queue = container.read(actionQueueProvider);
        expect(
          queue.pendingCount,
          1,
          reason: 'The offline create-client action should be queued.',
        );
        expect(queue.pendingCount, 1);
        expect(clientEndpoints.createdNames, isEmpty);
      },
    );

    testWidgets(
      '2. Reconnecting replays the queued action through the endpoint',
      (tester) async {
        final db = await initTestLocalDatabase();
        final offline = OfflineFlag()..offline = true;
        final clientEndpoints = _StubClientEndpoints();
        final overrides = managerOverrides(
          db: db,
          user: managerUser,
          offline: offline,
          extra: [
            clientEndpointsProvider.overrideWithValue(clientEndpoints),
          ],
        );

        final container = ProviderContainer(overrides: overrides);
        addTearDown(container.dispose);
        await pumpApp(tester, overrides: overrides, container: container);

        // Queue a create-client action while offline.
        await openRecordsTab(tester);
        await tapByText(tester, 'Clients');
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).hitTestable().first,
          'Replay SA',
        );
        await tapByText(tester, 'Save');

        final queue = container.read(actionQueueProvider);
        expect(queue.pendingCount, 1);

        // Reconnect: flip the flag and replay the queue through the client
        // endpoint (the app's queueable-mutation dispatch path).
        offline.offline = false;
        container.invalidate(isOfflineProvider);
        await tester.pumpAndSettle();
        expect(find.text('You are offline'), findsNothing);

        await container.read(actionQueueProvider).replayAll(
              (action) async {
                await clientEndpoints.createClient(action.data ?? const {});
              },
            );

        expect(
          queue.pendingCount,
          0,
          reason: 'After a successful replay the queue drains.',
        );
        expect(
          clientEndpoints.createdNames,
          contains('Replay SA'),
          reason: 'The replayed action should hit the create-client endpoint.',
        );
      },
    );
  });
}
