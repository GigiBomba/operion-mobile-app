import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/analytics/models/date_range.dart';
import 'package:operion_mobile/features/analytics/providers/analytics_providers.dart';
import 'package:operion_mobile/features/analytics/widgets/date_range_selector.dart';

import 'test_support.dart';

/// Stub [AnalyticsEndpoints] that serves a small revenue trend.
class _StubAnalyticsEndpoints extends AnalyticsEndpoints {
  _StubAnalyticsEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_access_token',
        ));

  @override
  Future<Response> getRevenue(
    DateRange range, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'trend': [
          {'label': 'W1', 'value': 100},
          {'label': 'W2', 'value': 150},
          {'label': 'W3', 'value': 120},
        ],
        'per_client': [
          {'label': 'ACME Logistics', 'value': 90},
        ],
        'per_route': [
          {'label': 'Bucharest-Cluj', 'value': 250},
        ],
      },
    );
  }

  @override
  Future<Response> getFleetUtilization(
    DateRange range, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'status_split': {'active': 5, 'maintenance': 1, 'decommissioned': 0},
        'trucks': <Map<String, dynamic>>[],
      },
    );
  }

  @override
  Future<Response> getDriverPerformance(
    DateRange range, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'rows': <Map<String, dynamic>>[]},
    );
  }

  @override
  Future<Response> getInvoiceAging({CancelToken? cancelToken}) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'current': 1000,
        'bucket_31_60': 0,
        'bucket_61_90': 0,
        'overdue': 0,
        'total_outstanding': 1000,
      },
    );
  }

  @override
  Future<Response> export(
    DateRange range, {
    required String report,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'download_url': 'https://cdn.example/export.csv'},
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Analytics Flow', () {
    testWidgets(
      '1. Revenue tab renders the trend chart and the date-range selector '
      'interacts without breaking the chart',
      (tester) async {
        final db = await initTestLocalDatabase();
        final overrides = managerOverrides(
          db: db,
          user: managerUser,
          extra: [
            analyticsEndpointsProvider
                .overrideWith((ref) => _StubAnalyticsEndpoints()),
          ],
        );

        await pumpApp(tester, overrides: overrides);

        // More tab → Analytics tile.
        await openMoreTab(tester);
        await tapByText(tester, 'Analytics');

        // The Revenue tab is the first tab: the trend LineChart renders from
        // the stub payload.
        expect(
          find.byType(LineChart),
          findsOneWidget,
          reason: 'Revenue tab should render the trend LineChart.',
        );

        // The shared date-range selector offers the 7d preset.
        expect(
          find.byType(DateRangeSelector),
          findsOneWidget,
          reason: 'The analytics screen should show the date-range selector.',
        );
        expect(find.text('7d'), findsOneWidget);

        // Interact: switch to the 7-day preset → the provider is rewritten
        // and the chart re-renders (stub is range-agnostic).
        await tester.tap(find.text('7d'));
        await tester.pumpAndSettle();

        expect(
          find.byType(LineChart),
          findsOneWidget,
          reason: 'After changing the date range the revenue chart remains.',
        );
      },
    );
  });
}
