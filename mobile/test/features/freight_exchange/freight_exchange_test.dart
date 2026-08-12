import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/freight_exchange/providers/freight_exchange_providers.dart';
import 'package:operion_mobile/features/freight_exchange/screens/freight_exchange_screen.dart';

import 'helpers.dart';

/// Wraps [FreightExchangeScreen] in a container with a mocked load-board API.
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
  // ==========================================================================
  // Initial state
  // ==========================================================================
  group('FreightExchangeScreen — initial state', () {
    testWidgets('renders app bar with title', (tester) async {
      final adapter = MockDioAdapter(onGet: (options) => jsonResponse([]));
      await tester.pumpWidget(wrapFreightExchange(adapter));
      await tester.pumpAndSettle();

      expect(find.text('Freight Exchange'), findsOneWidget);
    });

    testWidgets('renders origin, destination and cargo type filter fields',
        (tester) async {
      final adapter = MockDioAdapter(onGet: (options) => jsonResponse([]));
      await tester.pumpWidget(wrapFreightExchange(adapter));
      await tester.pumpAndSettle();

      // Three AppTextField filters (each renders a TextFormField).
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('Origin'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
      expect(find.text('Cargo type'), findsOneWidget);
      expect(find.byIcon(LucideIcons.search), findsWidgets);
    });

    testWidgets('shows apply and clear filter buttons', (tester) async {
      final adapter = MockDioAdapter(onGet: (options) => jsonResponse([]));
      await tester.pumpWidget(wrapFreightExchange(adapter));
      await tester.pumpAndSettle();

      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });
  });

  // ==========================================================================
  // Empty state
  // ==========================================================================
  group('FreightExchangeScreen — empty state', () {
    testWidgets('shows empty state with title and subtitle', (tester) async {
      final adapter = MockDioAdapter(onGet: (options) => jsonResponse([]));
      await tester.pumpWidget(wrapFreightExchange(adapter));
      await tester.pumpAndSettle();

      expect(find.text('No loads found'), findsOneWidget);
      expect(
        find.text('Try adjusting your filters or pull to refresh.'),
        findsOneWidget,
      );
    });
  });

  // ==========================================================================
  // User interactions
  // ==========================================================================
  group('FreightExchangeScreen — user interactions', () {
    testWidgets('applying filters re-fetches the board with query parameters',
        (tester) async {
      final adapter = MockDioAdapter(onGet: (options) => jsonResponse([]));
      await tester.pumpWidget(wrapFreightExchange(adapter));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Berlin');
      await tester.enterText(fields.at(1), 'Bucharest');
      await tester.enterText(fields.at(2), 'general');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Re-fetch with the applied filter params.
      expect(adapter.getRequestCount, 2);
      final last = adapter.requests.last;
      expect(last.queryParameters['origin'], 'Berlin');
      expect(last.queryParameters['destination'], 'Bucharest');
      expect(last.queryParameters['cargo_type'], 'general');
    });

    testWidgets('clearing filters resets the filter state to unfiltered',
        (tester) async {
      final adapter = MockDioAdapter(onGet: (options) => jsonResponse([]));
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

      await tester.enterText(find.byType(TextFormField).at(0), 'Berlin');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Filter state now carries the origin.
      expect(container.read(freightExchangeFilterProvider).origin, 'Berlin');

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      // Filter state is back to an empty, unfiltered board.
      expect(container.read(freightExchangeFilterProvider),
          const FreightLoadFilter());
    });
  });
}
