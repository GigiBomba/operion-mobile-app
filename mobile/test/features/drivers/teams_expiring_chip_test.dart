import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/drivers_endpoints.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/features/teams/providers/teams_providers.dart';

import '../../support/fake_local_database.dart';

/// Records the expiring_within_days param seen by the NEW /mobile/drivers
/// endpoint and serves a paginated envelope.
class _RecordingDriversEndpoints extends DriversEndpoints {
  _RecordingDriversEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  int? lastExpiringWithinDays;
  String? lastStatus;
  bool throwError = false;
  List<Map<String, dynamic>> items = [
    {'id': '1', 'name': 'Ana Popescu', 'status': 'available'},
  ];

  @override
  Future<Response> getDrivers({
    String? search,
    String? status,
    int? expiringWithinDays,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    lastExpiringWithinDays = expiringWithinDays;
    lastStatus = status;
    if (throwError) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/mobile/drivers'),
        type: DioExceptionType.connectionError,
      );
    }
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/drivers'),
      data: {
        'items': items,
        'total': items.length,
        'page': page,
        'page_size': pageSize,
        'total_pages': 1,
      },
      statusCode: 200,
    );
  }
}

void main() {
  test('kExpiringLicensesDefaultDays is the real backend constant (30)', () {
    // Mirrors driver_repository.get_expiring_licenses default in the backend.
    expect(kExpiringLicensesDefaultDays, 30);
  });

  group('teamsDriversProvider — Expiring filter (§4.2)', () {
    test('passes expiring_within_days=30 when the Expiring chip is selected',
        () async {
      final endpoints = _RecordingDriversEndpoints();
      final container = ProviderContainer(
        overrides: [
          driversEndpointsProvider.overrideWithValue(endpoints),
          teamsFilterProvider.overrideWith((ref) => DriverFilter.expiring),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
        ],
      );
      addTearDown(container.dispose);

      final drivers = await container.read(teamsDriversProvider.future);

      expect(endpoints.lastExpiringWithinDays, 30);
      expect(drivers, hasLength(1));
    });

    test('passes no expiring_within_days for a status filter', () async {
      final endpoints = _RecordingDriversEndpoints();
      final container = ProviderContainer(
        overrides: [
          driversEndpointsProvider.overrideWithValue(endpoints),
          teamsFilterProvider.overrideWith((ref) => DriverFilter.available),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(teamsDriversProvider.future);

      expect(endpoints.lastExpiringWithinDays, isNull);
      expect(endpoints.lastStatus, 'available');
    });

    test('filterDriversByStatus passes the Expiring list through unchanged', () {
      final drivers = <Map<String, dynamic>>[
        {'id': '1', 'name': 'A', 'status': 'driving'},
      ];
      expect(filterDriversByStatus(drivers, DriverFilter.expiring), hasLength(1));
      expect(filterDriversByStatus(drivers, DriverFilter.all), hasLength(1));
    });
  });

  group('teamsDriversProvider — dual mode (blueprint §5)', () {
    test('network failure → cached data + banner state (fromCache)', () async {
      final db = FakeLocalDatabase()
        ..seedCollection('drivers', [
          {'id': '7', 'name': 'Cached Driver', 'status': 'available'},
        ]);
      final endpoints = _RecordingDriversEndpoints()..throwError = true;
      final container = ProviderContainer(
        overrides: [
          driversEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final drivers = await container.read(teamsDriversProvider.future);

      expect(container.read(driversCachedBannerProvider), isTrue);
      expect(drivers, hasLength(1));
      expect(drivers.single['name'], 'Cached Driver');
    });

    test('network success → fresh payload, cache refreshed, no banner',
        () async {
      final db = FakeLocalDatabase()
        ..seedCollection('drivers', [
          {'id': '7', 'name': 'Stale Driver', 'status': 'available'},
        ]);
      final endpoints = _RecordingDriversEndpoints()
        ..items = [
          {'id': '2', 'name': 'Fresh Driver', 'status': 'driving'},
        ];
      final container = ProviderContainer(
        overrides: [
          driversEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final drivers = await container.read(teamsDriversProvider.future);

      expect(container.read(driversCachedBannerProvider), isFalse);
      expect(drivers.single['name'], 'Fresh Driver');
      // The fresh payload replaced the cache.
      expect(db.getCachedDrivers(), completion(hasLength(1)));
    });

    test('401 rejection propagates (I1) instead of falling back to cache',
        () async {
      final db = FakeLocalDatabase()
        ..seedCollection('drivers', [
          {'id': '7', 'name': 'Cached Driver', 'status': 'available'},
        ]);
      final endpoints = _AuthRejectionDriversEndpoints();
      final container = ProviderContainer(
        overrides: [
          driversEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(teamsDriversProvider.future),
        throwsA(isA<DioException>()),
      );
      expect(container.read(driversCachedBannerProvider), isFalse);
    });
  });
}

/// Serves HTTP 401 on the drivers list (auth rejection — must NOT cache-fall).
class _AuthRejectionDriversEndpoints extends DriversEndpoints {
  _AuthRejectionDriversEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
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
    throw DioException(
      requestOptions: RequestOptions(path: '/api/v1/mobile/drivers'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/v1/mobile/drivers'),
        statusCode: 401,
      ),
      type: DioExceptionType.badResponse,
    );
  }
}
