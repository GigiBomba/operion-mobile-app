import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/paginated.dart';
import 'package:operion_mobile/features/maintenance/models/maintenance.dart';
import 'package:operion_mobile/features/maintenance/providers/maintenance_providers.dart';
import 'package:operion_mobile/features/maintenance/screens/maintenance_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

/// Mixed overdue/non-overdue schedules (the screen re-sorts overdue-first, so
/// the provider order deliberately interleaves them).
final _schedules = [
  MaintenanceScheduleItem.fromJson({
    'id': 's3',
    'truck_id': 't3',
    'truck_plate': 'B-300-GHI',
    'maintenance_type': 'Inspection ITP',
    'interval_km': 40000,
    'overdue': false,
    'next_due': '2026-09-10',
  }),
  MaintenanceScheduleItem.fromJson({
    'id': 's1',
    'truck_id': 't1',
    'truck_plate': 'B-100-ABC',
    'maintenance_type': 'Oil change',
    'interval_km': 15000,
    'last_done_km': 115000,
    'overdue': true,
    'next_due': '2026-07-20',
  }),
  MaintenanceScheduleItem.fromJson({
    'id': 's2',
    'truck_id': 't2',
    'truck_plate': 'B-200-DEF',
    'maintenance_type': 'Brake service',
    'interval_months': 6,
    'overdue': false,
    'next_due': '2026-08-05',
  }),
];

const _trend = CostTrendData(
  monthly: [
    CostTrendPoint(month: '2026-05', total: 850.0),
    CostTrendPoint(month: '2026-06', total: 1200.0),
    CostTrendPoint(month: '2026-07', total: 640.0),
  ],
  byType: [
    CostByType(type: 'oil_change', total: 1350.0),
    CostByType(type: 'tires', total: 900.0),
    CostByType(type: 'brakes', total: 440.0),
  ],
);

List<Override> _overrides() => [
      isOfflineProvider.overrideWith((ref) => false),
      currentUserProvider.overrideWith((ref) => _adminUser),
      maintenanceCostTrendRangeProvider.overrideWith(
        (ref) => const CostTrendRange(
          startDate: null,
          endDate: null,
        ),
      ),
      maintenanceScheduleProvider.overrideWith(
        (ref, filter) async => PaginatedResponse<MaintenanceScheduleItem>(
          items: _schedules,
          total: _schedules.length,
          page: 1,
          pageSize: 20,
          totalPages: 1,
        ),
      ),
      maintenanceCostTrendProvider.overrideWith(
        (ref, range) async => _trend,
      ),
    ];

Widget _app({required Brightness brightness}) {
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
      home: const MaintenanceScreen(),
    ),
  );
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Brightness brightness,
  String file,
) async {
  // Taller than the phone default (390x844) so the cost-trend charts AND the
  // mixed overdue/non-overdue schedule list are both visible in the capture.
  tester.view.physicalSize = const Size(390, 1150);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(brightness: brightness));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(Scaffold),
    matchesGoldenFile(file),
  );
}

void main() {
  testWidgets('MaintenanceScreen golden (light)', (tester) async {
    await _pumpGolden(tester, Brightness.light, 'maintenance_light.png');
  });

  testWidgets('MaintenanceScreen golden (dark)', (tester) async {
    await _pumpGolden(tester, Brightness.dark, 'maintenance_dark.png');
  });
}
