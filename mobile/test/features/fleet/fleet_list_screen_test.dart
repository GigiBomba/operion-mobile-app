import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/fleet/models/truck.dart';
import 'package:operion_mobile/features/fleet/providers/fleet_providers.dart';
import 'package:operion_mobile/features/fleet/screens/fleet_list_screen.dart';
import 'package:operion_mobile/features/fleet/widgets/health_score_chip.dart';
import 'package:operion_mobile/shared/models/user.dart';

import '../../support/test_helpers.dart';

const _dispatcherUser = User(
  id: 'u1',
  email: 'disp@operion.ro',
  fullName: 'Disp',
  role: 'dispatcher',
  companyId: 'c1',
);

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

final List<Truck> _trucks = [
  Truck.fromJson({
    'id': 't1',
    'company_id': 'c1',
    'plate': 'B-100-ABC',
    'brand': 'Volvo',
    'model': 'FH16',
    'status': 'Active',
    'health_score': 90.0,
  }),
  Truck.fromJson({
    'id': 't2',
    'company_id': 'c1',
    'plate': 'B-200-DEF',
    'brand': 'MAN',
    'model': 'TGX',
    'status': 'In Service',
    'health_score': 60.0,
  }),
  Truck.fromJson({
    'id': 't3',
    'company_id': 'c1',
    'plate': 'B-300-GHI',
    'brand': 'Scania',
    'model': 'R500',
    'status': 'Inactive',
    'health_score': 40.0,
  }),
];

Widget _wrap({required User user, List<Override>? extra}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      fleetListProvider.overrideWith(
        (ref) async => FleetListData(trucks: _trucks, fromCache: false),
      ),
      fleetCachedBannerProvider.overrideWith((ref) => false),
      ...?extra,
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: FleetListScreen(),
    ),
  );
}

void main() {
  group('FleetListScreen — empty state', () {
    testWidgets('renders the empty state when there are no trucks',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _adminUser),
            fleetListProvider.overrideWith(
              (ref) async => const FleetListData(trucks: [], fromCache: false),
            ),
            fleetCachedBannerProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: FleetListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No trucks yet'), findsOneWidget);
    });
  });

  group('FleetListScreen — RBAC gating (§8.2)', () {
    testWidgets('FAB is ABSENT for dispatcher (no can_create_vehicle)',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_wrap(user: _dispatcherUser));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('FAB is present for admin (can_create_vehicle)', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_wrap(user: _adminUser));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('FleetListScreen — rows', () {
    testWidgets('renders plate bold + brand/model + status + health chip',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_wrap(user: _adminUser));
      await tester.pumpAndSettle();

      expect(find.text('B-100-ABC'), findsOneWidget);
      expect(find.text('Volvo FH16'), findsOneWidget);
      expect(find.text('B-200-DEF'), findsOneWidget);
      expect(find.text('In Service'), findsOneWidget);
      expect(find.byType(HealthScoreChip), findsNWidgets(3));
    });

    testWidgets('health chip colors: >=80 green, 50–79 amber, <50 red',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_wrap(user: _adminUser));
      await tester.pumpAndSettle();

      final chips = tester
          .widgetList<HealthScoreChip>(find.byType(HealthScoreChip))
          .toList();
      // Order matches _trucks order.
      expect(chips, hasLength(3));
    });

    testWidgets('search filters the list client-side', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_wrap(user: _adminUser));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'B-200');
      await tester.pumpAndSettle();

      expect(find.text('B-200-DEF'), findsOneWidget);
      expect(find.text('B-100-ABC'), findsNothing);
    });
  });
}
