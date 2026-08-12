import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/freight_exchange/models/freight_load.dart';
import 'package:operion_mobile/features/freight_exchange/providers/freight_exchange_providers.dart';
import 'package:operion_mobile/features/freight_exchange/screens/freight_exchange_screen.dart';
import 'package:operion_mobile/features/freight_exchange/screens/freight_load_detail_screen.dart';

import 'helpers.dart';

/// A single load in the `LoadSearchResult.model_dump()` shape returned by
/// POST /freight/search and /freight/searches/{id}/refresh.
Map<String, dynamic> searchResultJson({
  String resultId = 'exch-a/load-1',
  String origin = 'Berlin',
  String destination = 'Bucharest',
}) =>
    {
      'result_id': resultId,
      'provider_id': 'exch-a',
      'provider_load_id': 'load-1',
      'origin': origin,
      'destination': destination,
      'pickup_window': ['2026-08-01T08:00:00', '2026-08-02T08:00:00'],
      'delivery_window': ['2026-08-03T08:00:00', '2026-08-04T18:00:00'],
      'price': {'amount': 1850.0, 'currency': 'EUR'},
      'distance_km': 1800.0,
      'trailer_type': 'general',
      'adr': false,
      'weight_kg': 22000.0,
    };

/// A `LoadEvaluation.model_dump()`-shaped fixture.
Map<String, dynamic> evaluationJson() => {
      'provider_id': 'exch-a',
      'provider_load_id': 'load-1',
      'estimated_revenue': {'amount': 1850.0, 'currency': 'EUR'},
      'fuel_cost': {'amount': 420.0, 'currency': 'EUR'},
      'toll_cost': {'amount': 180.0, 'currency': 'EUR'},
      'driver_salary': {'amount': 300.0, 'currency': 'EUR'},
      'deadhead_distance_km': 80.0,
      'expected_profit': {'amount': 950.0, 'currency': 'EUR'},
      'profit_margin_pct': 51.4,
      'estimated_duration_hours': 28.5,
      'risk_score': 0.42,
      'vehicle_compatibility': [
        {'vehicle_id': 1, 'compatible': true, 'reasons': <String>[]},
      ],
      'driver_compatibility': <dynamic>[],
      'evaluated_at': '2026-07-19T10:00:00',
    };

Widget _wrapWithAdapter(MockDioAdapter adapter, {Widget? home}) {
  final client = ApiClient.create(
    baseUrl: 'https://test.com',
    getAccessToken: () async => null,
  );
  client.dio.httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(client)],
  );
  addTearDown(container.dispose);

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home ?? const FreightExchangeScreen(),
    ),
  );
}

void main() {
  group('FreightExchange — §2 saved searches', () {
    testWidgets('saved searches sheet lists backend searches and runs one',
        (tester) async {
      final adapter = MockDioAdapter(
        onGet: (options) {
          if (options.path.contains('/freight/searches')) {
            return jsonResponse({
              'searches': [
                {
                  'saved_search_id': 's1',
                  'label': 'Berlin → Bucharest',
                  'filters': {
                    'origin': {'location': 'Berlin', 'radius_km': 50},
                    'destination': {'location': 'Bucharest', 'radius_km': 30},
                    'pickup_date_from': '2026-07-01',
                    'pickup_date_to': '2026-07-31',
                  },
                  'created_at': '2026-07-01T08:00:00',
                  'last_refreshed_at': null,
                },
              ],
            });
          }
          return jsonResponse([]);
        },
        onPost: (options) {
          // Refresh re-runs and returns fresh results.
          if (options.path.contains('/searches/s1/refresh')) {
            return jsonResponse({
              'results': [searchResultJson()],
              'providers_queried': 1,
            });
          }
          return jsonResponse([]);
        },
      );

      await tester.pumpWidget(_wrapWithAdapter(adapter));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Saved searches'));
      await tester.pumpAndSettle();

      expect(find.text('Berlin → Bucharest'), findsOneWidget);

      // Run the saved search → refresh endpoint fires and results display.
      await tester.tap(find.text('Run'));
      await tester.pumpAndSettle();

      final refreshCalls = adapter.requests
          .where((r) => r.path.contains('/searches/s1/refresh'))
          .toList();
      expect(refreshCalls, hasLength(1));
      expect(refreshCalls.first.method, 'POST');
      expect(find.text('Berlin → Bucharest'), findsOneWidget);
    });

    testWidgets('saving the current search posts label + filters',
        (tester) async {
      final adapter = MockDioAdapter(
        onGet: (options) {
          if (options.path.contains('/freight/searches')) {
            return jsonResponse({'searches': <dynamic>[]});
          }
          return jsonResponse([]);
        },
        onPost: (options) {
          if (options.path.contains('/freight/searches')) {
            return jsonResponse({
              'saved_search_id': 'new-1',
              'label': 'My search',
            });
          }
          return jsonResponse([]);
        },
      );

      await tester.pumpWidget(_wrapWithAdapter(adapter));
      await tester.pumpAndSettle();

      // Set a simple filter first so the save payload carries it.
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Berlin');
      await tester.enterText(fields.at(1), 'Bucharest');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Saved searches'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save current search'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'My search');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saveCall = adapter.requests.firstWhere(
        (r) => r.method == 'POST' && r.path.contains('/freight/searches'),
      );
      final body = saveCall.data as Map<String, dynamic>;
      expect(body['label'], 'My search');
      final filters = body['filters'] as Map<String, dynamic>;
      expect(
        (filters['origin'] as Map)['location'],
        'Berlin',
      );
    });

    testWidgets('saved searches sheet shows an empty state', (tester) async {
      final adapter = MockDioAdapter(
        onGet: (options) {
          if (options.path.contains('/freight/searches')) {
            return jsonResponse({'searches': <dynamic>[]});
          }
          return jsonResponse([]);
        },
      );

      await tester.pumpWidget(_wrapWithAdapter(adapter));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Saved searches'));
      await tester.pumpAndSettle();

      expect(find.text('No saved searches yet'), findsOneWidget);
    });
  });

  group('FreightExchange — §2 advanced search', () {
    testWidgets('more filters posts the SearchRequest body and shows results',
        (tester) async {
      final adapter = MockDioAdapter(
        onGet: (options) => jsonResponse([]),
        onPost: (options) {
          if (options.path.contains('/freight/search')) {
            return jsonResponse({
              'results': [searchResultJson(resultId: 'exch-a/adv-1')],
              'providers_queried': 1,
              'provider_statuses': <dynamic>[],
            });
          }
          return jsonResponse([]);
        },
      );

      await tester.pumpWidget(_wrapWithAdapter(adapter));
      await tester.pumpAndSettle();

      await tester.tap(find.text('More filters'));
      await tester.pumpAndSettle();

      // Fill the bounded form: origin + destination + weight min/max + prices.
      // Scope to the sheet — the main filter bar's fields are still in the
      // tree behind the modal.
      final sheetFields = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(sheetFields.at(0), 'Berlin');
      await tester.enterText(sheetFields.at(1), 'Bucharest');
      await tester.enterText(sheetFields.at(2), '15000');
      await tester.enterText(sheetFields.at(3), '25000');
      await tester.enterText(sheetFields.at(4), '1000');
      await tester.enterText(sheetFields.at(5), '3000');
      // Both the main filter bar and the sheet have an "Apply" button — the
      // sheet's is the last one in the tree.
      await tester.tap(find.text('Apply').last);
      await tester.pumpAndSettle();

      final searchCall = adapter.requests.firstWhere(
        (r) => r.method == 'POST' && r.path.contains('/freight/search'),
      );
      final body = searchCall.data as Map<String, dynamic>;
      expect(body['origin_location'], 'Berlin');
      expect(body['destination_location'], 'Bucharest');
      expect(body['weight_kg_min'], 15000);
      expect(body['weight_kg_max'], 25000);
      expect(body['price_min'], 1000);
      expect(body['price_max'], 3000);

      // The advanced result is shown in the board.
      expect(find.text('Berlin → Bucharest'), findsOneWidget);
    });
  });

  group('FreightLoadDetailScreen — §2 evaluate', () {
    testWidgets('evaluate renders the profitability/risk card', (tester) async {
      final adapter = MockDioAdapter(
        onGet: (options) {
          if (options.path.contains('/loads/exch-a/load-1/evaluate')) {
            return jsonResponse(evaluationJson());
          }
          return jsonResponse([]);
        },
        onPost: (options) => jsonResponse([]),
      );

      final load = const FreightLoad(
        id: 'exch-a/load-1',
        origin: 'Berlin',
        destination: 'Bucharest',
        cargoType: 'general',
        price: 1850,
        currency: 'EUR',
      );

      await tester.pumpWidget(
        _wrapWithAdapter(
          adapter,
          home: FreightLoadDetailScreen(
            load: load,
            filter: const FreightLoadFilter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Evaluate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evaluate'));
      await tester.pumpAndSettle();

      // Key LoadEvaluation fields are rendered (the load's price row shares
      // the "1850.00 EUR" text with the estimated-revenue row).
      expect(find.text('Load evaluation'), findsOneWidget);
      expect(find.textContaining('1850.00 EUR'), findsWidgets);
      expect(find.textContaining('950.00 EUR'), findsOneWidget);
      expect(find.text('Risk'), findsOneWidget);
      expect(find.text('Medium · 42'), findsOneWidget);
      expect(find.text('Vehicle compatible'), findsOneWidget);
    });

    testWidgets('evaluate shows an error card when the provider is missing',
        (tester) async {
      final adapter = MockDioAdapter(
        onGet: (options) => jsonResponse([]),
        onPost: (options) => jsonResponse([]),
      );

      // No resolvable provider → unresolvable import target.
      final load = const FreightLoad(
        id: 'bare-id',
        origin: 'Berlin',
        destination: 'Bucharest',
      );

      await tester.pumpWidget(
        _wrapWithAdapter(
          adapter,
          home: FreightLoadDetailScreen(
            load: load,
            filter: const FreightLoadFilter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Evaluate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evaluate'));
      await tester.pumpAndSettle();

      expect(find.text('Evaluation failed'), findsOneWidget);
    });
  });
}
