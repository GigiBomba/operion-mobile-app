import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/paginated.dart';
import 'package:operion_mobile/core/theme/app_colors.dart';
import 'package:operion_mobile/features/fleet/models/truck.dart';
import 'package:operion_mobile/features/fleet/providers/fleet_providers.dart';
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

const _managerUser = User(
  id: 'u3',
  email: 'manager@operion.ro',
  fullName: 'Manager',
  role: 'manager',
  companyId: 'c1',
);

const _dispatcherUser = User(
  id: 'u1',
  email: 'dispatcher@operion.ro',
  fullName: 'Dispatcher',
  role: 'dispatcher',
  companyId: 'c1',
);

/// Mixed overdue/non-overdue schedules (interleaved on purpose — the screen
/// must re-sort overdue-first).
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
  ],
);

List<Override> _overrides({User? user}) => [
      isOfflineProvider.overrideWith((ref) => false),
      currentUserProvider.overrideWith((ref) => user ?? _adminUser),
      maintenanceCostTrendRangeProvider.overrideWith(
        (ref) => const CostTrendRange(startDate: null, endDate: null),
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
      maintenanceCostTrendProvider.overrideWith((ref, range) async => _trend),
    ];

/// Spy notifier: records the Phase-1 path the screen must reuse
/// (`fleetMutationProvider.recordMaintenance`) without re-testing its
/// implementation.
class _SpyFleetMutation extends FleetMutationNotifier {
  // The super constructor takes the library-private `this._ref`, so a
  // `super.ref` parameter is impossible from this library — keep the explicit
  // forwarding.
  // ignore: use_super_parameters
  _SpyFleetMutation(Ref ref) : super(ref);

  final recordedMaintenance = <(String, MaintenanceRecordDraft)>[];

  @override
  Future<void> recordMaintenance(
    String truckId,
    MaintenanceRecordDraft draft,
  ) async {
    recordedMaintenance.add((truckId, draft));
  }
}

Widget _app({User? user, List<Override>? extraOverrides}) {
  return ProviderScope(
    overrides: [..._overrides(user: user), ...?extraOverrides],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MaintenanceScreen(),
    ),
  );
}

void main() {
  /// The cost-trend charts occupy the top of the screen, so the schedule list
  /// is below the fold at 390x844. Every schedule assertion scrolls the single
  /// body [ListView] until the schedule row is in view first.
  Future<void> scrollToSchedules(WidgetTester tester) async {
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('B-300-GHI'),
      200,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('schedule list renders truck plates, types and overdue pill',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await scrollToSchedules(tester);

    final loc = AppLocalizations(const Locale('en'));
    expect(find.text('B-100-ABC'), findsOneWidget);
    expect(find.text('Oil change'), findsOneWidget);
    expect(find.text('B-200-DEF'), findsOneWidget);
    expect(find.text('Brake service'), findsOneWidget);
    expect(find.text('B-300-GHI'), findsOneWidget);
    expect(find.text(loc.maintenance_overdue), findsOneWidget,
        reason: 'Exactly one schedule is overdue → one OVERDUE pill');
  });

  testWidgets('overdue schedules are listed first', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await scrollToSchedules(tester);

    // The provider delivers s3 first, but the screen must sort the overdue
    // item (B-100-ABC) above the non-overdue ones.
    final overdueY = tester.getTopLeft(find.text('B-100-ABC')).dy;
    final soonY = tester.getTopLeft(find.text('B-200-DEF')).dy;
    final laterY = tester.getTopLeft(find.text('B-300-GHI')).dy;

    expect(overdueY, lessThan(soonY),
        reason: 'Overdue schedule must sort before non-overdue');
    expect(overdueY, lessThan(laterY),
        reason: 'Overdue schedule must sort first regardless of provider order');
  });

  testWidgets('overdue card carries the red left-border accent',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await scrollToSchedules(tester);

    // The 4px accent bar is a Container filled with AppColors.error, only
    // rendered on the overdue card.
    Finder accentIn(Widget card) => find.descendant(
          of: find.byWidget(card),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.color == AppColors.error,
          ),
        );

    final overdueCard =
        find.ancestor(of: find.text('B-100-ABC'), matching: find.byType(IntrinsicHeight));
    final nonOverdueCard =
        find.ancestor(of: find.text('B-200-DEF'), matching: find.byType(IntrinsicHeight));

    expect(overdueCard, findsOneWidget);
    expect(nonOverdueCard, findsOneWidget);
    expect(accentIn(tester.widget(overdueCard)), findsOneWidget,
        reason: 'Overdue card must show the red left-border accent');
    expect(accentIn(tester.widget(nonOverdueCard)), findsNothing,
        reason: 'Non-overdue card must NOT show the red accent');
  });

  testWidgets('cost-trend section renders the LineChart and PieChart',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget,
        reason: 'Monthly cost trend must render a LineChart');
    expect(find.byType(PieChart), findsOneWidget,
        reason: 'By-type split must render a PieChart');
  });

  testWidgets('record-work action calls fleetMutationProvider.recordMaintenance',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        ..._overrides(),
        fleetMutationProvider.overrideWith((ref) => _SpyFleetMutation(ref)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MaintenanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final loc = AppLocalizations(const Locale('en'));
    // Bring the schedule cards into view, then tap the first card's
    // (overdue-first → truck t1) Record work button.
    await tester.scrollUntilVisible(
      find.text('B-100-ABC'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, loc.fleet_recordWork).first);
    await tester.pumpAndSettle();
    expect(find.text(loc.fleet_recordWork), findsWidgets,
        reason: 'Record-work bottom sheet opened');

    // Cost is required (>0); vendor/notes optional.
    await tester.enterText(find.byType(TextField).at(0), '250');
    await tester.tap(find.text(loc.general_save));
    await tester.pumpAndSettle();

    final notifier =
        container.read(fleetMutationProvider.notifier) as _SpyFleetMutation;
    expect(notifier.recordedMaintenance, hasLength(1),
        reason: 'Saving the sheet must call fleetMutationProvider.recordMaintenance');
    final (truckId, draft) = notifier.recordedMaintenance.single;
    expect(truckId, 't1');
    expect(draft.cost, 250.0);
    expect(draft.category, MaintenanceCategory.other);
  });

  testWidgets('add-schedule FAB absent for dispatcher (§8.2)', (tester) async {
    await tester.pumpWidget(_app(user: _dispatcherUser));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing,
        reason: 'Dispatcher lacks can_schedule_maintenance → FAB must be absent');
  });

  testWidgets('add-schedule FAB present for manager', (tester) async {
    await tester.pumpWidget(_app(user: _managerUser));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget,
        reason: 'Manager holds can_schedule_maintenance per the permission matrix');
  });
}
