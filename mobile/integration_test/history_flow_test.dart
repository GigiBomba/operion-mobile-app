import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/history/providers/history_providers.dart';

import 'test_support.dart';

/// Stub [HistoryEndpoints]. The trip list honours the status filter exactly
/// like the real backend, so the status-chip journey is observable.
class _StubHistoryEndpoints extends HistoryEndpoints {
  _StubHistoryEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_access_token',
        ));

  @override
  Future<Response> getTrips(
    TripHistoryFilter filter, {
    CancelToken? cancelToken,
  }) async {
    final delivered = <Map<String, dynamic>>[
      {
        'id': 2,
        'client_name': 'Nord Cargo',
        'truck_number': 'B-456-DEF',
        'driver_name': 'Vasile Ionescu',
        'origin': 'Constanta',
        'destination': 'Bucharest',
        'status': 'Delivered',
        'distance_km': 220,
        'total_price_eur': 800,
        'net_profit': 300,
      },
    ];
    final items = filter.status == 'Delivered'
        ? delivered
        : <Map<String, dynamic>>[
            {
              'id': 1,
              'client_name': 'ACME Logistics',
              'truck_number': 'B-123-ABC',
              'driver_name': 'Ion Popescu',
              'origin': 'Cluj-Napoca',
              'destination': 'Bucharest',
              'status': 'In Transit',
              'distance_km': 450,
              'total_price_eur': 1200,
              'net_profit': 500,
            },
            ...delivered,
          ];
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'items': items,
        'total': items.length,
        'page': filter.page,
        'page_size': filter.pageSize,
        'total_pages': 1,
      },
    );
  }

  @override
  Future<Response> getRoutes(
    RouteHistoryFilter filter, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'items': [
          {
            'id': 1,
            'name': 'Route Cluj-Bucharest',
            'origin': 'Cluj-Napoca',
            'destination': 'Bucharest',
            'total_distance_km': 450,
            'duration_min': 300,
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'id': 2,
            'name': 'Route Constanta-Bucharest',
            'origin': 'Constanta',
            'destination': 'Bucharest',
            'total_distance_km': 220,
            'duration_min': 180,
            'created_at': DateTime.now().toIso8601String(),
          },
        ],
        'total': 2,
        'page': 1,
        'page_size': 20,
        'total_pages': 1,
      },
    );
  }
}

Future<List<Override>> _overrides() async {
  final db = await initTestLocalDatabase();
  return managerOverrides(
    db: db,
    user: managerUser,
    extra: [
      historyEndpointsProvider.overrideWith((ref) => _StubHistoryEndpoints()),
    ],
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('History Flow', () {
    testWidgets(
      '1. Trip history renders and the status filter refetches the list',
      (tester) async {
        await pumpApp(tester, overrides: await _overrides());

        await openRecordsTab(tester);
        await tapByText(tester, 'Trip History');

        // Both stub trips render with origin → destination.
        expect(find.text('ACME Logistics'), findsOneWidget);
        expect(find.text('Cluj-Napoca → Bucharest'), findsOneWidget);

        // Apply the Delivered status filter.
        await tapByText(tester, 'Delivered');

        expect(
          find.text('Constanta → Bucharest'),
          findsOneWidget,
          reason: 'After the Delivered filter the delivered trip remains.',
        );
        expect(
          find.text('Cluj-Napoca → Bucharest'),
          findsNothing,
          reason: 'In-Transit trips are filtered out by the status chip.',
        );
      },
    );

    testWidgets(
      '2. Route history renders the saved routes',
      (tester) async {
        await pumpApp(tester, overrides: await _overrides());

        await openRecordsTab(tester);
        await tapByText(tester, 'Route History');

        expect(find.text('Route Cluj-Bucharest'), findsOneWidget);
        expect(find.text('Route Constanta-Bucharest'), findsOneWidget);
        expect(find.text('Cluj-Napoca → Bucharest'), findsWidgets);
      },
    );
  });
}
