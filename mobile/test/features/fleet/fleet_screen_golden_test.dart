import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/fleet/models/truck.dart';
import 'package:operion_mobile/features/fleet/providers/fleet_providers.dart';
import 'package:operion_mobile/features/fleet/screens/fleet_list_screen.dart';
import 'package:operion_mobile/features/fleet/screens/truck_detail_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';

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
    'vin': 'VIN123',
    'year': 2021,
    'status': 'Active',
    'health_score': 92.0,
  }),
  Truck.fromJson({
    'id': 't2',
    'company_id': 'c1',
    'plate': 'B-200-DEF',
    'brand': 'MAN',
    'model': 'TGX',
    'status': 'In Service',
    'health_score': 64.0,
  }),
  Truck.fromJson({
    'id': 't3',
    'company_id': 'c1',
    'plate': 'B-300-GHI',
    'brand': 'Scania',
    'model': 'R500',
    'status': 'Inactive',
    'health_score': 35.0,
  }),
];

List<Override> _overrides() => [
      currentUserProvider.overrideWith((ref) => _adminUser),
      fleetListProvider.overrideWith(
        (ref) async => FleetListData(trucks: _trucks, fromCache: false),
      ),
      fleetCachedBannerProvider.overrideWith((ref) => false),
      truckDetailProvider.overrideWith(
        (ref, id) async => TruckDetailData(truck: _trucks.first, fromCache: false),
      ),
      truckMaintenanceHistoryProvider.overrideWith(
        (ref, id) async => [
          TruckMaintenanceRecord.fromJson({
            'id': 1,
            'truck_id': 't1',
            'date': '2026-07-15',
            'category': 'oil_change',
            'cost': 350,
            'vendor': 'AutoService',
          }),
        ],
      ),
    ];

Widget _app(Widget child, {Brightness brightness = Brightness.light}) {
  return ProviderScope(
    overrides: _overrides(),
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Widget child,
  String file, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(child, brightness: brightness));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(Scaffold),
    matchesGoldenFile(file),
  );
}

void main() {
  testWidgets('FleetListScreen golden (light)', (tester) async {
    await _pumpGolden(tester, const FleetListScreen(), 'fleet_list_light.png');
  });

  testWidgets('FleetListScreen golden (dark)', (tester) async {
    await _pumpGolden(
      tester,
      const FleetListScreen(),
      'fleet_list_dark.png',
      brightness: Brightness.dark,
    );
  });

  testWidgets('TruckDetailScreen golden (light)', (tester) async {
    await _pumpGolden(
      tester,
      const TruckDetailScreen(truckId: 't1'),
      'truck_detail_light.png',
    );
  });

  testWidgets('TruckDetailScreen golden (dark)', (tester) async {
    await _pumpGolden(
      tester,
      const TruckDetailScreen(truckId: 't1'),
      'truck_detail_dark.png',
      brightness: Brightness.dark,
    );
  });
}
