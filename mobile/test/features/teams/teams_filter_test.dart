import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/features/teams/providers/teams_providers.dart';
import 'package:operion_mobile/features/teams/screens/teams_screen.dart';
import 'package:operion_mobile/l10n/app_localizations.dart';
import 'package:operion_mobile/shared/widgets/app_card.dart';

import '../../support/test_helpers.dart';

/// Backend-shaped fixture (DispatcherDriverResponse): `id` int, `name`,
/// `status`, `current_transport`, `current_vehicle` — no `fullName`, no `phone`.
final List<Map<String, dynamic>> _drivers = [
  {
    'id': 1,
    'name': 'Ana Popescu',
    'status': 'available',
    'current_transport': null,
    'current_vehicle': 'TR-101',
  },
  {
    'id': 2,
    'name': 'Ion Ionescu',
    'status': 'driving',
    'current_transport': 'T-77',
    'current_vehicle': 'TR-202',
  },
  {
    'id': 3,
    'name': 'Maria Dobre',
    'status': 'off',
    'current_transport': null,
    'current_vehicle': null,
  },
  {
    'id': 4,
    'name': 'Vlad Georgescu',
    'status': 'available',
    'current_transport': 'T-12',
    'current_vehicle': 'TR-303',
  },
  {
    'id': 5,
    'name': 'Fara Status', // missing `status` key entirely
  },
];

Widget _wrap({List<Override>? overrides}) {
  return ProviderScope(
    overrides: [
      teamsDriversProvider.overrideWith((ref) async => _drivers),
      ...?overrides,
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: TeamsScreen(),
    ),
  );
}

void main() {
  group('filterDriversByStatus', () {
    test('DriverFilter enum has the 5 expected values', () {
      expect(DriverFilter.values, hasLength(5));
      expect(DriverFilter.values, containsAll([
        DriverFilter.all,
        DriverFilter.available,
        DriverFilter.driving,
        DriverFilter.off,
        DriverFilter.expiring,
      ]));
    });

    test('All returns every driver including missing-status entries', () {
      final result = filterDriversByStatus(_drivers, DriverFilter.all);
      expect(result, hasLength(5));
    });

    test('Expiring passes the list through unchanged (server-side window)', () {
      final result = filterDriversByStatus(_drivers, DriverFilter.expiring);
      expect(result, hasLength(5));
    });

    test('Available narrows to available drivers only', () {
      final result = filterDriversByStatus(_drivers, DriverFilter.available);
      expect(result.map((d) => d['name']).toSet(),
          {'Ana Popescu', 'Vlad Georgescu'});
    });

    test('Driving narrows to driving drivers only', () {
      final result = filterDriversByStatus(_drivers, DriverFilter.driving);
      expect(result.map((d) => d['name']).toList(), ['Ion Ionescu']);
    });

    test('Off narrows to off drivers only', () {
      final result = filterDriversByStatus(_drivers, DriverFilter.off);
      expect(result.map((d) => d['name']).toList(), ['Maria Dobre']);
    });

    test('missing-status driver is excluded by any specific filter', () {
      for (final filter in [
        DriverFilter.available,
        DriverFilter.driving,
        DriverFilter.off,
      ]) {
        final result = filterDriversByStatus(_drivers, filter);
        expect(result.any((d) => d['name'] == 'Fara Status'), isFalse,
            reason: 'driver without status must not match $filter');
      }
    });
  });

  group('teamsFilteredDriversProvider', () {
    ProviderContainer container({DriverFilter initial = DriverFilter.all}) {
      final c = ProviderContainer(overrides: [
        teamsDriversProvider.overrideWith((ref) async => _drivers),
        teamsFilterProvider.overrideWith((ref) => initial),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('defaults to the full driver list', () async {
      final c = container();
      await c.read(teamsDriversProvider.future);
      expect(c.read(teamsFilteredDriversProvider), hasLength(5));
    });

    test('follows the selected filter for every chip value', () async {
      final c = container();
      await c.read(teamsDriversProvider.future);

      c.read(teamsFilterProvider.notifier).state = DriverFilter.available;
      expect(c.read(teamsFilteredDriversProvider).map((d) => d['name']).toSet(),
          {'Ana Popescu', 'Vlad Georgescu'});

      c.read(teamsFilterProvider.notifier).state = DriverFilter.driving;
      expect(c.read(teamsFilteredDriversProvider).map((d) => d['name']).toList(),
          ['Ion Ionescu']);

      c.read(teamsFilterProvider.notifier).state = DriverFilter.off;
      expect(c.read(teamsFilteredDriversProvider).map((d) => d['name']).toList(),
          ['Maria Dobre']);

      c.read(teamsFilterProvider.notifier).state = DriverFilter.all;
      expect(c.read(teamsFilteredDriversProvider), hasLength(5));
    });
  });

  group('TeamsScreen chips', () {
    testWidgets('each chip narrows the list and All restores it',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // All chips + one card per driver (5 drivers).
      expect(find.byType(AppCard), findsNWidgets(5));

      await tester.tap(find.text('Available'));
      await tester.pumpAndSettle();
      expect(find.byType(AppCard), findsNWidgets(2));
      expect(find.text('Ana Popescu'), findsOneWidget);
      expect(find.text('Vlad Georgescu'), findsOneWidget);
      expect(find.text('Ion Ionescu'), findsNothing);

      await tester.ensureVisible(find.text('Driving'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Driving'));
      await tester.pumpAndSettle();
      expect(find.byType(AppCard), findsNWidgets(1));
      expect(find.text('Ion Ionescu'), findsOneWidget);

      await tester.ensureVisible(find.text('Off'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();
      expect(find.byType(AppCard), findsNWidgets(1));
      expect(find.text('Maria Dobre'), findsOneWidget);

      await tester.ensureVisible(find.text('All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.byType(AppCard), findsNWidgets(5));
    });
  });

  group('TeamsScreen — pull-to-refresh', () {
    testWidgets('RefreshIndicator re-fetches the driver list', (tester) async {
      usePhoneSurface(tester);
      var fetchCount = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teamsDriversProvider.overrideWith((ref) async {
              fetchCount++;
              return _drivers;
            }),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [AppLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
            home: TeamsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(fetchCount, 1);

      // Simulate the pull gesture on the driver list.
      await tester.fling(
        find.byType(ListView),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      // The refresh re-invoked the provider.
      expect(fetchCount, greaterThanOrEqualTo(2));
    });
  });
}
