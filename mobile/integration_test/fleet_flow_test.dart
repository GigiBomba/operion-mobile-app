import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/fleet_endpoints.dart';
import 'package:operion_mobile/features/fleet/providers/fleet_providers.dart';

import 'test_support.dart';

/// Stub [FleetEndpoints] with an in-memory truck list that `createTruck`
/// mutates, so the create → list-refresh journey is observable.
class _StubFleetEndpoints extends FleetEndpoints {
  _StubFleetEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_access_token',
        ));

  final List<Map<String, dynamic>> trucks = [
    {
      'id': 'v1',
      'company_id': '1',
      'plate': 'B-123-ABC',
      'brand': 'Volvo',
      'model': 'FH16',
      'vin': 'YV2R4',
      'year': 2021,
      'status': 'Active',
      'health_score': 92.0,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'v2',
      'company_id': '1',
      'plate': 'B-456-DEF',
      'brand': 'MAN',
      'model': 'TGX',
      'vin': 'WMAA6',
      'year': 2020,
      'status': 'In Service',
      'health_score': 64.0,
      'created_at': DateTime.now().toIso8601String(),
    },
  ];

  int _nextId = 3;

  @override
  Future<Response> getFleet({
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: trucks,
    );
  }

  @override
  Future<Response> getTruck(String id, {CancelToken? cancelToken}) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: trucks.firstWhere(
        (t) => t['id'] == id,
        orElse: () => trucks.first,
      ),
    );
  }

  @override
  Future<Response> createTruck(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    final id = 'v${_nextId++}';
    final truck = <String, dynamic>{
      'id': id,
      'company_id': '1',
      'plate': data['plate'],
      'brand': data['brand'],
      'model': data['model'],
      'vin': data['vin'],
      'year': data['year'],
      'status': 'Active',
      'health_score': 100.0,
      'created_at': DateTime.now().toIso8601String(),
    };
    trucks.add(truck);
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: truck,
    );
  }

  @override
  Future<Response> getMaintenanceHistory(
    String id, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'items': <Map<String, dynamic>>[]},
    );
  }
}

Future<List<Override>> _overrides() async {
  final db = await initTestLocalDatabase();
  return managerOverrides(
    db: db,
    user: managerUser,
    extra: [
      fleetEndpointsProvider.overrideWith((ref) => _StubFleetEndpoints()),
    ],
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Fleet Flow', () {
    testWidgets(
      '1. Create truck via the FAB and see it appear in the fleet list',
      (tester) async {
        await pumpApp(tester, overrides: await _overrides());

        // Records tab → Fleet tile.
        await openRecordsTab(tester);
        await tapByText(tester, 'Fleet');

        // Stub trucks are listed.
        expect(find.text('B-123-ABC'), findsOneWidget);

        // Open the create sheet via the FAB.
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // The bottom sheet exposes Plate / Brand / Model fields.
        expect(find.text('Truck details'), findsOneWidget);
        final fields = find.byType(TextField).hitTestable();
        await tester.enterText(fields.at(0), 'B-999-ZZZ');
        await tester.enterText(fields.at(1), 'Scania');
        await tester.enterText(fields.at(2), 'R500');

        await tapByText(tester, 'Save');

        // After the create mutation the list refreshes and the new plate is
        // shown.
        expect(
          find.text('B-999-ZZZ'),
          findsOneWidget,
          reason: 'The newly created truck should appear in the fleet list.',
        );
        expect(find.text('Scania R500'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Truck detail renders the four tabs and the truck fields',
      (tester) async {
        await pumpApp(tester, overrides: await _overrides());

        await openRecordsTab(tester);
        await tapByText(tester, 'Fleet');

        // Open the detail of the first stub truck.
        await tapByText(tester, 'B-123-ABC');

        // Detail tabs render.
        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('Maintenance'), findsOneWidget);
        expect(find.text('Documents'), findsOneWidget);
        expect(find.text('Assignments'), findsOneWidget);

        // Truck identity fields from the stub payload.
        expect(find.text('B-123-ABC'), findsWidgets);
        expect(find.text('Volvo FH16'), findsWidgets);
      },
    );
  });
}
