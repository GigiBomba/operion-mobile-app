import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/maintenance/providers/maintenance_providers.dart';

import 'test_support.dart';

/// Stub [MaintenanceEndpoints] serving a schedule list with one overdue entry
/// and a small cost trend.
class _StubMaintenanceEndpoints extends MaintenanceEndpoints {
  _StubMaintenanceEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_access_token',
        ));

  @override
  Future<Response> getSchedule(
    MaintenanceScheduleFilter filter, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'items': [
          {
            'id': 'ms1',
            'truck_id': 'v1',
            'truck_plate': 'B-123-ABC',
            'maintenance_type': 'oil_change',
            'interval_km': 30000,
            'interval_months': 12,
            'last_done_km': 45000,
            'last_done_date':
                DateTime.now().subtract(const Duration(days: 400)).toIso8601String(),
            'overdue': true,
            'next_due':
                DateTime.now().subtract(const Duration(days: 20)).toIso8601String(),
          },
          {
            'id': 'ms2',
            'truck_id': 'v2',
            'truck_plate': 'B-456-DEF',
            'maintenance_type': 'tires',
            'interval_km': 60000,
            'interval_months': 24,
            'last_done_km': 10000,
            'last_done_date': DateTime.now().toIso8601String(),
            'overdue': false,
            'next_due': DateTime.now()
                .add(const Duration(days: 90))
                .toIso8601String(),
          },
        ],
        'total': 2,
        'page': 1,
        'page_size': 20,
        'total_pages': 1,
      },
    );
  }

  @override
  Future<Response> getCostTrend(
    CostTrendRange range, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'monthly': [
          {'month': '2026-01', 'total': 500.0},
          {'month': '2026-02', 'total': 720.0},
        ],
        'by_type': [
          {'type': 'oil_change', 'total': 400.0},
          {'type': 'tires', 'total': 820.0},
        ],
      },
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Maintenance Flow', () {
    testWidgets(
      '1. Schedule list renders and flags the overdue entry',
      (tester) async {
        final db = await initTestLocalDatabase();
        final overrides = managerOverrides(
          db: db,
          user: managerUser,
          extra: [
            maintenanceEndpointsProvider
                .overrideWith((ref) => _StubMaintenanceEndpoints()),
          ],
        );

        await pumpApp(tester, overrides: overrides);

        // More tab → Maintenance tile.
        await openMoreTab(tester);
        await tapByText(tester, 'Maintenance');

        // Schedules section renders with the two stub trucks.
        expect(find.text('Schedules'), findsOneWidget);
        expect(find.text('B-123-ABC'), findsOneWidget);
        expect(find.text('B-456-DEF'), findsOneWidget);

        // The overdue entry shows the OVERDUE flag.
        expect(
          find.text('OVERDUE'),
          findsOneWidget,
          reason: 'The overdue schedule entry should be flagged.',
        );

        // The overdue-only filter chip is available.
        expect(find.text('Overdue only'), findsOneWidget);
      },
    );
  });
}
