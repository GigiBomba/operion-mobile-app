import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/drivers_endpoints.dart';
import 'package:operion_mobile/features/teams/providers/teams_providers.dart';

import 'test_support.dart';

/// Stub [DriversEndpoints]. The Expiring filter is applied server-side via
/// `expiring_within_days`, so the stub returns a different roster for that
/// query — the same contract the real backend implements.
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
    if (expiringWithinDays != null) {
      return Response(
        requestOptions: RequestOptions(path: ''),
        data: [
          {
            'id': 'd2',
            'name': 'Vasile Ionescu',
            'email': 'vasile@operion.ro',
            'status': 'active',
            'license_expiry':
                DateTime.now().add(const Duration(days: 10)).toIso8601String(),
          },
        ],
      );
    }
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: [
        {
          'id': 'd1',
          'name': 'Ion Popescu',
          'email': 'ion@operion.ro',
          'status': 'active',
          'license_expiry':
              DateTime.now().add(const Duration(days: 200)).toIso8601String(),
        },
        {
          'id': 'd2',
          'name': 'Vasile Ionescu',
          'email': 'vasile@operion.ro',
          'status': 'active',
          'license_expiry':
              DateTime.now().add(const Duration(days: 10)).toIso8601String(),
        },
      ],
    );
  }

  @override
  Future<Response> getDriverDetail(String id, {CancelToken? cancelToken}) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'id': 1,
        'name': 'Ion Popescu',
        'phone': '+40721112233',
        'email': 'ion@operion.ro',
        'license_number': 'RO123456',
        'license_category': 'CE',
        'license_expiry':
            DateTime.now().add(const Duration(days: 200)).toIso8601String(),
        'medical_expiry':
            DateTime.now().add(const Duration(days: 90)).toIso8601String(),
        'adr_certificate_expiry':
            DateTime.now().add(const Duration(days: 400)).toIso8601String(),
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
      driversEndpointsProvider.overrideWith((ref) => _StubDriversEndpoints()),
    ],
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Drivers Flow', () {
    testWidgets(
      '1. Drivers list renders and the Expiring filter refetches the roster',
      (tester) async {
        await pumpApp(tester, overrides: await _overrides());

        await openRecordsTab(tester);
        await tapByText(tester, 'Drivers');

        // Both stub drivers are listed.
        expect(find.text('Ion Popescu'), findsOneWidget);
        expect(find.text('Vasile Ionescu'), findsOneWidget);

        // Filter chips include the Expiring filter.
        await tapByText(tester, 'Expiring');

        // The refetch hits the stub with expiring_within_days set, which now
        // only returns the expiring driver.
        expect(find.text('Vasile Ionescu'), findsOneWidget);
        expect(
          find.text('Ion Popescu'),
          findsNothing,
          reason: 'After the Expiring filter, non-expiring drivers are hidden.',
        );
      },
    );

    testWidgets(
      '2. Driver detail opens with the four tabs and license info',
      (tester) async {
        await pumpApp(tester, overrides: await _overrides());

        await openRecordsTab(tester);
        await tapByText(tester, 'Drivers');

        // Open the driver detail.
        await tapByText(tester, 'Ion Popescu');

        // Detail tabs render.
        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('Compliance'), findsOneWidget);
        expect(find.text('Tacho'), findsOneWidget);
        expect(find.text('Assignments'), findsOneWidget);

        // License data from the stub detail payload.
        expect(find.text('Ion Popescu'), findsWidgets);
        expect(find.text('CE'), findsWidgets);
      },
    );
  });
}
