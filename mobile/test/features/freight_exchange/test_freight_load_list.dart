import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/freight_exchange/screens/freight_exchange_screen.dart';

import 'helpers.dart';

/// Renders [FreightExchangeScreen] with an [ApiClient] backed by
/// [MockDioAdapter] so the load board is driven by the fixture.
Widget wrapFreightExchange(MockDioAdapter adapter) {
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
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: FreightExchangeScreen(),
    ),
  );
}

void main() {
  group('FreightExchangeScreen — load list from fixture', () {
    testWidgets('renders load cards from the fixture', (tester) async {
      final adapter = MockDioAdapter(
        onGet: (options) => jsonResponse(freightLoadFixture()),
      );
      await tester.pumpWidget(wrapFreightExchange(adapter));
      await tester.pumpAndSettle();

      // Both fixture loads render their route line.
      expect(find.text('Berlin → Bucharest'), findsOneWidget);
      expect(find.text('Munich → Cluj'), findsOneWidget);

      // Price renders with currency.
      expect(find.text('1850.00 EUR'), findsOneWidget);
      expect(find.text('2400.00 EUR'), findsOneWidget);

      // Cargo type + distance rows render.
      expect(find.text('general'), findsOneWidget);
      expect(find.text('reefer'), findsOneWidget);
    });

    testWidgets('GET /api/v1/freight/loads is called without a filter',
        (tester) async {
      final adapter = MockDioAdapter(
        onGet: (options) => jsonResponse(freightLoadFixture()),
      );
      await tester.pumpWidget(wrapFreightExchange(adapter));
      await tester.pumpAndSettle();

      expect(adapter.getRequestCount, 1);
      final request = adapter.requests.first;
      expect(request.path, '/api/v1/freight/loads');
    });

    testWidgets('shows empty state when the fixture list is empty',
        (tester) async {
      final adapter = MockDioAdapter(onGet: (options) => jsonResponse([]));
      await tester.pumpWidget(wrapFreightExchange(adapter));
      await tester.pumpAndSettle();

      expect(find.text('No loads found'), findsOneWidget);
    });

    testWidgets('shows shimmer while loading then swaps to data',
        (tester) async {
      final adapter = MockDioAdapter(
        onGet: (options) => jsonResponse(freightLoadFixture()),
      );
      await tester.pumpWidget(wrapFreightExchange(adapter));

      // Loading phase — shimmer present.
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('Berlin → Bucharest'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Berlin → Bucharest'), findsOneWidget);
    });
  });
}
