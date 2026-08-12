import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/global_search/providers/global_search_providers.dart';

import 'test_support.dart';

/// Stub [SearchEndpoints] returning cross-entity sections for any 2+ char
/// query.
class _StubSearchEndpoints extends SearchEndpoints {
  _StubSearchEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_access_token',
        ));

  @override
  Future<Response> search(
    String query, {
    String? types,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'trips': {
          'items': [
            {'id': 't1', 'title': 'Transport T-101'},
          ],
          'total_count': 1,
        },
        'clients': {
          'items': [
            {'id': 'c1', 'name': 'ACME Logistics'},
          ],
          'total_count': 1,
        },
        'drivers': {
          'items': [
            {'id': 'd1', 'name': 'Ion Popescu'},
          ],
          'total_count': 1,
        },
        'trucks': {
          'items': [
            {'id': 'v1', 'plate': 'B-123-ABC'},
          ],
          'total_count': 1,
        },
        'documents': {
          'items': [
            {'id': 1, 'title': 'CMR — Transport T-101'},
          ],
          'total_count': 1,
        },
      },
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Global Search Flow', () {
    testWidgets(
      '1. Typing a query returns grouped results',
      (tester) async {
        final db = await initTestLocalDatabase();
        final overrides = managerOverrides(
          db: db,
          user: managerUser,
          extra: [
            searchEndpointsProvider.overrideWith((ref) => _StubSearchEndpoints()),
          ],
        );

        await pumpApp(tester, overrides: overrides);

        // Open Global Search from the Records app-bar action.
        await openRecordsTab(tester);
        await tester.tap(find.byTooltip('Global search'));
        await tester.pumpAndSettle();

        expect(find.text('Global Search'), findsOneWidget);

        // Enter a 2+ char query; the provider debounces 350ms before firing.
        await tester.enterText(find.byType(TextField).hitTestable(), 'ACME');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await tester.pumpAndSettle();

        // Result section headers render with their items.
        expect(find.text('Trips'), findsOneWidget);
        expect(find.text('Clients'), findsOneWidget);
        expect(find.text('Drivers'), findsOneWidget);
        expect(find.text('Trucks'), findsOneWidget);
        expect(find.text('ACME Logistics'), findsOneWidget);
        expect(find.text('Ion Popescu'), findsOneWidget);
        expect(find.text('B-123-ABC'), findsOneWidget);
      },
    );
  });
}
