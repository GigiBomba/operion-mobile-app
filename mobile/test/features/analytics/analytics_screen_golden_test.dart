import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/analytics/models/date_range.dart';
import 'package:operion_mobile/features/analytics/providers/analytics_providers.dart';
import 'package:operion_mobile/features/analytics/screens/analytics_screen.dart';
import '../../helpers/golden_fonts.dart';

final _revenue = RevenueAnalytics(
  trend: const [
    ChartPoint(label: 'W1', value: 100),
    ChartPoint(label: 'W2', value: 150),
    ChartPoint(label: 'W3', value: 120),
  ],
  perClient: const [
    ChartPoint(label: 'ACME', value: 90),
    ChartPoint(label: 'Beta', value: 60),
  ],
  perRoute: const [ChartPoint(label: 'BucureÈ™tiâ€“Cluj', value: 250)],
);

const _fleet = FleetUtilizationAnalytics(
  statusSplit: {'active': 5, 'maintenance': 1, 'decommissioned': 1},
  trucks: [{'truck': 'B-100', 'trip_count': 12, 'total_km': 3200}],
);

const _drivers = [
  DriverPerformanceRow(
    driver: 'Ion Popescu',
    tripsCompleted: 10,
    onTimePct: 92.5,
    profitPerKm: 1.2,
    revenue: 8500,
  ),
];

const _aging = InvoiceAgingReport(
  current: 12000,
  bucket31_60: 3000,
  bucket61_90: 1000,
  overdue: 500,
  totalOutstanding: 16500,
);
List<Override> _overrides() => [
      isOfflineProvider.overrideWith((ref) => false),
      analyticsDateRangeProvider.overrideWith(
        (ref) => DateRange(
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 7, 31),
        ),
      ),
      analyticsRevenueProvider.overrideWith((ref, arg) async => _revenue),
      analyticsFleetUtilizationProvider
          .overrideWith((ref, arg) async => _fleet),
      analyticsDriverPerformanceProvider
          .overrideWith((ref, arg) async => _drivers),
      analyticsInvoiceAgingProvider.overrideWith((ref) async => _aging),
    ];

Widget _app({required Brightness brightness, required int tabIndex}) {
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
      home: DefaultTabController(
        initialIndex: tabIndex,
        length: 4,
        child: const AnalyticsScreen(),
      ),
    ),
  );
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Brightness brightness,
  int tabIndex,
  String file,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(brightness: brightness, tabIndex: tabIndex));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(Scaffold),
    matchesGoldenFile(file),
  );
}

void main() {
  setUpAll(loadGoldenFonts);
  testWidgets('analytics revenue tab golden (light)', (tester) async {
    await _pumpGolden(tester, Brightness.light, 0, goldenFile('analytics_revenue_light'));
  });

  testWidgets('analytics revenue tab golden (dark)', (tester) async {
    await _pumpGolden(tester, Brightness.dark, 0, goldenFile('analytics_revenue_dark'));
  });

  testWidgets('analytics fleet tab golden (light)', (tester) async {
    await _pumpGolden(tester, Brightness.light, 1, goldenFile('analytics_fleet_light'));
  });

  testWidgets('analytics fleet tab golden (dark)', (tester) async {
    await _pumpGolden(tester, Brightness.dark, 1, goldenFile('analytics_fleet_dark'));
  });

  testWidgets('analytics drivers tab golden (light)', (tester) async {
    await _pumpGolden(tester, Brightness.light, 2, goldenFile('analytics_drivers_light'));
  });

  testWidgets('analytics drivers tab golden (dark)', (tester) async {
    await _pumpGolden(tester, Brightness.dark, 2, goldenFile('analytics_drivers_dark'));
  });

  testWidgets('analytics aging tab golden (light)', (tester) async {
    await _pumpGolden(tester, Brightness.light, 3, goldenFile('analytics_aging_light'));
  });

  testWidgets('analytics aging tab golden (dark)', (tester) async {
    await _pumpGolden(tester, Brightness.dark, 3, goldenFile('analytics_aging_dark'));
  });
}