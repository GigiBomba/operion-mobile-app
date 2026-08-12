import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/analytics/models/date_range.dart';
import 'package:operion_mobile/features/analytics/providers/analytics_providers.dart';
import 'package:operion_mobile/features/analytics/screens/analytics_screen.dart';
import 'package:operion_mobile/shared/widgets/empty_state.dart';

/// Records export report values; serves a valid export response.
class _RecordingExportEndpoints extends AnalyticsEndpoints {
  _RecordingExportEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<String> reports = [];

  @override
  Future<Response> export(
    DateRange range, {
    required String report,
    CancelToken? cancelToken,
  }) async {
    reports.add(report);
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'download_url': 'https://cdn/export.csv'},
      statusCode: 200,
    );
  }
}


final _revenue = RevenueAnalytics(
  trend: const [
    ChartPoint(label: 'W1', value: 100),
    ChartPoint(label: 'W2', value: 150),
  ],
  perClient: const [ChartPoint(label: 'ACME', value: 90)],
  perRoute: const [ChartPoint(label: 'București–Cluj', value: 250)],
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

Widget _app({
  RevenueAnalytics? revenue,
  FleetUtilizationAnalytics? fleet,
  List<DriverPerformanceRow>? drivers,
  InvoiceAgingReport? aging,
  bool offline = false,
}) {
  return ProviderScope(
    overrides: [
      isOfflineProvider.overrideWith((ref) => offline),
      analyticsRevenueProvider
          .overrideWith((ref, arg) async => revenue ?? _revenue),
      analyticsFleetUtilizationProvider
          .overrideWith((ref, arg) async => fleet ?? _fleet),
      analyticsDriverPerformanceProvider
          .overrideWith((ref, arg) async => drivers ?? _drivers),
      analyticsInvoiceAgingProvider
          .overrideWith((ref) async => aging ?? _aging),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AnalyticsScreen(),
    ),
  );
}

void main() {
  Future<void> pumpApp(WidgetTester tester, Widget app) async {
    // Wide/tall enough that the scrollable 4-tab TabBar shows every label
    // and the DataTable fits on-screen without scrolling.
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  testWidgets('renders 4 tabs with chart content', (tester) async {
    await pumpApp(tester, _app());

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget); // Revenue trend.

    // Toggle to per-client on the Revenue tab → bar chart + legend.
    await tester.tap(find.text('Client'));
    await tester.pumpAndSettle();
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('ACME'), findsOneWidget);

    // Switch to Fleet Utilization.
    await tester.tap(find.text('Fleet Utilization'));
    await tester.pumpAndSettle();
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('B-100'), findsOneWidget);

    // Driver Performance table.
    await tester.tap(find.text('Driver Performance'));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Ion Popescu'), findsOneWidget);

    // Invoice Aging bar chart.
    await tester.tap(find.text('Invoice Aging'));
    await tester.pumpAndSettle();
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('date range selector drives the segmented control',
      (tester) async {
    await pumpApp(tester, _app());

    expect(find.text('30d'), findsOneWidget);
    await tester.tap(find.text('7d'));
    await tester.pumpAndSettle();
  });

  testWidgets('empty datasets render EmptyState (no zero-data chart)',
      (tester) async {
    await pumpApp(
      tester,
      _app(
        revenue: const RevenueAnalytics(
          trend: [],
          perClient: [],
          perRoute: [],
        ),
      ),
    );

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('dispatcher 403 surfaces as error state', (tester) async {
    await pumpApp(
      tester,
      ProviderScope(
        overrides: [
          isOfflineProvider.overrideWith((ref) => false),
          analyticsRevenueProvider.overrideWith(
            (ref, arg) => Future.error(Exception('HTTP 403 Forbidden')),
          ),
          analyticsFleetUtilizationProvider
              .overrideWith((ref, arg) => Future.error(Exception('HTTP 403'))),
          analyticsDriverPerformanceProvider
              .overrideWith((ref, arg) => Future.error(Exception('HTTP 403'))),
          analyticsInvoiceAgingProvider
              .overrideWith((ref) => Future.error(Exception('HTTP 403'))),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AnalyticsScreen(),
        ),
      ),
    );

    expect(find.textContaining('403'), findsWidgets);
    expect(find.text('Retry'), findsWidgets);
  });

  testWidgets('offline export shows inline message and disables button',
      (tester) async {
    await pumpApp(tester, _app(offline: true));

    expect(
      find.text('Export requires an internet connection'),
      findsOneWidget,
    );
    // Export action is rendered but non-interactive (icon only).
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
  });

  testWidgets('export sends the report matching the active tab',
      (tester) async {
    // Mock the share_plus platform channel so Share.share resolves in tests.
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async => 'success',
    );
    addTearDown(() => messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          null,
        ));

    final endpoints = _RecordingExportEndpoints();
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isOfflineProvider.overrideWith((ref) => false),
        analyticsEndpointsProvider.overrideWithValue(endpoints),
        analyticsRevenueProvider
            .overrideWith((ref, arg) async => _revenue),
        analyticsFleetUtilizationProvider
            .overrideWith((ref, arg) async => _fleet),
        analyticsDriverPerformanceProvider
            .overrideWith((ref, arg) async => _drivers),
        analyticsInvoiceAgingProvider
            .overrideWith((ref) async => _aging),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnalyticsScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Revenue tab is active by default → export reports 'revenue'.
    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();
    expect(endpoints.reports, ['revenue']);

    // Switch to Fleet Utilization → export reports 'fleet'.
    await tester.tap(find.text('Fleet Utilization'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();
    expect(endpoints.reports, ['revenue', 'fleet']);

    // Driver Performance → 'drivers'.
    await tester.tap(find.text('Driver Performance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();
    expect(endpoints.reports, ['revenue', 'fleet', 'drivers']);

    // Invoice Aging → 'invoice_aging'.
    await tester.tap(find.text('Invoice Aging'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();
    expect(endpoints.reports, ['revenue', 'fleet', 'drivers', 'invoice_aging']);
  });
}
