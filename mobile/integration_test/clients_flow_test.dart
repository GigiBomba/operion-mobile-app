import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/client_endpoints.dart';
import 'package:operion_mobile/features/clients/providers/client_providers.dart';

import 'test_support.dart';

/// Stub [ClientEndpoints] with an in-memory client list that `createClient`
/// mutates. `getClient` returns a detail payload including contacts.
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
      'address': 'Str. Fabricii 12, Cluj-Napoca',
      'payment_terms_days': 30,
      'rating': 4.5,
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    },
  ];

  int _nextId = 2;

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
  Future<Response> getClient(String id, {CancelToken? cancelToken}) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'id': 'c1',
        'company_id': '1',
        'name': 'ACME Logistics',
        'vat_number': 'RO12345678',
        'address': 'Str. Fabricii 12, Cluj-Napoca',
        'payment_terms_days': 30,
        'rating': 4.5,
        'is_active': true,
        'contacts': [
          {
            'id': 'ct1',
            'name': 'Ana Marin',
            'role': 'Dispatcher',
            'phone': '+40741112233',
            'email': 'ana@acme.ro',
          },
        ],
        'recent_trip_count': 12,
        'recent_invoice_count': 4,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  Future<Response> createClient(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    final id = 'c${_nextId++}';
    final client = <String, dynamic>{
      'id': id,
      'company_id': '1',
      'name': data['name'],
      'vat_number': data['vat_number'],
      'address': data['address'],
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

Future<List<Override>> _overrides() async {
  final db = await initTestLocalDatabase();
  return managerOverrides(
    db: db,
    user: managerUser,
    extra: [
      clientEndpointsProvider.overrideWith((ref) => _StubClientEndpoints()),
    ],
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Clients Flow', () {
    testWidgets(
      '1. Create client via the FAB and see it appear in the list',
      (tester) async {
        await pumpApp(tester, overrides: await _overrides());

        await openRecordsTab(tester);
        await tapByText(tester, 'Clients');

        // The stub client is listed.
        expect(find.text('ACME Logistics'), findsOneWidget);

        // Open the create sheet via the FAB and fill in the name.
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).hitTestable().first,
          'Nord Cargo SA',
        );
        await tapByText(tester, 'Save');

        expect(
          find.text('Nord Cargo SA'),
          findsOneWidget,
          reason: 'The newly created client should appear in the client list.',
        );
      },
    );

    testWidgets(
      '2. Client detail renders and the Contacts tab lists contacts',
      (tester) async {
        await pumpApp(tester, overrides: await _overrides());

        await openRecordsTab(tester);
        await tapByText(tester, 'Clients');

        // Open the stub client detail.
        await tapByText(tester, 'ACME Logistics');

        // Detail tabs render (Details / Contacts / Invoices / Trips).
        expect(find.text('Details'), findsOneWidget);
        expect(find.text('Contacts'), findsOneWidget);

        // The Contacts tab shows the stub contact.
        await tapByText(tester, 'Contacts');
        expect(
          find.text('Ana Marin'),
          findsOneWidget,
          reason: 'The contact list should render the stub contact.',
        );
      },
    );
  });
}
