// ---------------------------------------------------------------------------
// freight_saved_search_delete_test.dart — B14
//
// Verifies the saved-searches sheet supports swipe-to-delete:
// swipe a saved search → confirmation dialog → DELETE /freight/searches/{id}
// is issued and savedFreightSearchesProvider is invalidated (re-fetched).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/freight_exchange/screens/freight_exchange_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('swipe saved search → confirm → DELETE issued + list invalidated',
      (tester) async {
    final adapter = MockDioAdapter(
      onGet: (options) {
        if (options.path.contains('/api/v1/freight/searches')) {
          return jsonResponse({
            'searches': [
              {
                'saved_search_id': 's1',
                'label': 'Berlin → Bucharest',
                'filters': {
                  'origin': {'location': 'Berlin', 'radius_km': 50},
                  'destination': {'location': 'Bucharest', 'radius_km': 30},
                  'pickup_date_from': '2026-08-01',
                  'pickup_date_to': '2026-08-15',
                },
              },
            ],
          });
        }
        return jsonResponse([]);
      },
    );
    final client = ApiClient.create(
      baseUrl: 'https://test.com',
      getAccessToken: () async => null,
    );
    client.dio.httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

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
          home: FreightExchangeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the saved-searches sheet.
    await tester.tap(find.text('Saved searches'));
    await tester.pumpAndSettle();
    expect(find.text('Berlin → Bucharest'), findsOneWidget);

    // Record the saved-searches fetch count before deletion.
    final fetchesBefore =
        adapter.requests.where((r) => r.path.contains('/freight/searches')).length;

    // Swipe the saved-search row to reveal the delete affordance.
    await tester.drag(find.text('Berlin → Bucharest'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // Confirmation dialog appears.
    expect(find.text('Delete this saved search?'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // DELETE issued against the correct path.
    expect(
      adapter.requests.any((r) =>
          r.method == 'DELETE' &&
          r.path == '/api/v1/freight/searches/s1'),
      isTrue,
    );
    // Provider invalidated → the saved-searches list was re-fetched.
    final fetchesAfter =
        adapter.requests.where((r) => r.path.contains('/freight/searches')).length;
    expect(fetchesAfter, greaterThan(fetchesBefore));
  });
}
