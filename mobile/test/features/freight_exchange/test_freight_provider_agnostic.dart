import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/freight_exchange/models/freight_load.dart';
import 'package:operion_mobile/features/freight_exchange/screens/freight_exchange_screen.dart';

import 'helpers.dart';

/// The fixed provider-agnostic contract field names (blueprint §6.3).
const _contractFieldNames = [
  'id',
  'origin',
  'destination',
  'cargo_type',
  'price',
  'currency',
  'pickup_date',
  'deadline_date',
  'weight_kg',
  'distance_km',
];

/// Provider-specific identifiers that must never appear in the mobile layer.
const _forbiddenIdentifiers = ['timocom', 'trans_eu', 'trans.eu', 'teleroute', 'wtransnet'];

void main() {
  group('Freight Exchange — provider-agnostic discipline', () {
    test('model contains no provider-specific field names or identifiers',
        () {
      const modelPath = 'lib/features/freight_exchange/models/freight_load.dart';
      final source = File(modelPath).readAsStringSync();
      final lower = source.toLowerCase();

      for (final identifier in _forbiddenIdentifiers) {
        expect(
          lower.contains(identifier),
          isFalse,
          reason: 'mobile model must not reference "$identifier" '
              '(provider-agnostic discipline, blueprint §6.3)',
        );
      }
    });

    test('model parses every fixed-contract field name', () {
      const modelPath = 'lib/features/freight_exchange/models/freight_load.dart';
      final source = File(modelPath).readAsStringSync();

      for (final key in _contractFieldNames) {
        expect(
          source,
          contains("'$key'"),
          reason: 'model must expose the fixed-contract field "$key"',
        );
      }
    });

    test('provider file targets only the provider-agnostic endpoints', () {
      const providerPath =
          'lib/features/freight_exchange/providers/freight_exchange_providers.dart';
      final source = File(providerPath).readAsStringSync();

      expect(source, contains("'/api/v1/freight/loads'"));
      // The import path is built from the provider-agnostic load id — the
      // endpoint template only appears inside the resolveImportTarget helper.
      expect(source, contains("'/api/v1/freight/loads/"));
      expect(source, contains("/import'"));
    });

    test('FreightLoad round-trips the provider-agnostic fixture', () {
      final load = FreightLoad.fromJson(freightLoadFixture()[0]);

      expect(load.id, 'exch-a/load-1');
      expect(load.origin, 'Berlin');
      expect(load.destination, 'Bucharest');
      expect(load.cargoType, 'general');
      expect(load.price, 1850.0);
      expect(load.currency, 'EUR');
      expect(load.weightKg, 22000.0);
      expect(load.distanceKm, '1800');
      expect(load.pickupDate, isNotNull);
      expect(load.deadlineDate, isNotNull);
    });

    testWidgets('load board renders identically from a provider-agnostic fixture',
        (tester) async {
      final adapter = MockDioAdapter(
        onGet: (options) => jsonResponse(freightLoadFixture()),
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

      expect(find.text('Berlin → Bucharest'), findsOneWidget);
      expect(find.text('Munich → Cluj'), findsOneWidget);
    });
  });
}
