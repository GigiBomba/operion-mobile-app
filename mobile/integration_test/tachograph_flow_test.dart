import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/drivers_endpoints.dart';
import 'package:operion_mobile/features/teams/providers/teams_providers.dart';

import 'test_support.dart';

/// Stub [DriversEndpoints] serving the tachograph driver picker (reuses the
/// same endpoint the Teams screen uses).
class _StubDriversEndpoints extends DriversEndpoints {
  _StubDriversEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_access_token',
        ));

  @override
  Future<Response> getDrivers({
    String? search,
    String? status,
    int? expiringWithinDays,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'items': [
          {
            'id': 'd1',
            'name': 'Ion Popescu',
            'email': 'ion@operion.ro',
            'status': 'active',
          },
          {
            'id': 'd2',
            'name': 'Vasile Ionescu',
            'email': 'vasile@operion.ro',
            'status': 'active',
          },
        ],
        'total': 2,
        'page': 1,
        'page_size': 100,
        'total_pages': 1,
      },
    );
  }

  @override
  Future<Response> getDriverDetail(String id, {CancelToken? cancelToken}) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: <String, dynamic>{'id': 1, 'name': 'Ion Popescu'},
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Tachograph Flow', () {
    testWidgets(
      '1. Import screen renders and the driver picker selects a driver',
      (tester) async {
        final db = await initTestLocalDatabase();
        final overrides = managerOverrides(
          db: db,
          user: managerUser,
          extra: [
            driversEndpointsProvider
                .overrideWith((ref) => _StubDriversEndpoints()),
          ],
        );

        await pumpApp(tester, overrides: overrides);

        // More tab → Tachograph tile.
        await openMoreTab(tester);
        await tapByText(tester, 'Tachograph');

        // Import screen renders with the driver selector and import button.
        expect(find.text('Choose a driver'), findsOneWidget);
        expect(find.text('Import .ddd file'), findsOneWidget);

        // Open the driver picker bottom sheet.
        await tapByText(tester, 'Select a driver');

        // Both stub drivers are offered.
        expect(find.text('Ion Popescu'), findsOneWidget);
        expect(find.text('Vasile Ionescu'), findsOneWidget);

        // Selecting a driver closes the sheet and shows the name inline.
        await tapByText(tester, 'Ion Popescu');
        expect(find.text('Select a driver'), findsNothing);
        expect(find.text('Ion Popescu'), findsOneWidget);
      },
    );
  });
}
