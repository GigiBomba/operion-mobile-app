import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/fleet_endpoints.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/features/fleet/models/truck.dart';
import 'package:operion_mobile/features/fleet/providers/fleet_providers.dart';

import '../../support/fake_local_database.dart';

const _cachedTruck = {
  'id': 't-1',
  'company_id': 'c1',
  'plate': 'B-OLD',
  'brand': 'MAN',
  'model': 'TGX',
  'status': 'Active',
  'health_score': 85.0,
};

const _networkTruck = {
  'id': 't-2',
  'company_id': 'c1',
  'plate': 'B-NEW',
  'brand': 'Volvo',
  'model': 'FH16',
  'status': 'In Service',
  'health_score': 60.0,
};

/// Endpoints stub: fails the fleet list (simulates offline / server down).
class _ThrowingFleetEndpoints extends FleetEndpoints {
  _ThrowingFleetEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  @override
  Future<Response> getFleet({
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/api/v1/mobile/fleet'),
      type: DioExceptionType.connectionError,
    );
  }
}

/// Endpoints stub serving a paginated fleet response.
class _OkFleetEndpoints extends FleetEndpoints {
  _OkFleetEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  @override
  Future<Response> getFleet({
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/fleet'),
      data: {
        'items': [_networkTruck],
        'total': 1,
        'page': 1,
        'page_size': 20,
        'total_pages': 1,
      },
      statusCode: 200,
    );
  }
}

/// Endpoints stub that records updateTruck / addMaintenanceRecord calls.
class _RecordingFleetMutations extends FleetEndpoints {
  _RecordingFleetMutations()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<(String, Map<String, dynamic>)> updateCalls = [];
  final List<(String, Map<String, dynamic>)> maintenanceCalls = [];

  @override
  Future<Response> updateTruck(
    String id,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    updateCalls.add((id, data));
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/fleet/$id'),
      data: {'id': id, 'plate': data['plate']},
      statusCode: 200,
    );
  }

  @override
  Future<Response> addMaintenanceRecord(
    String id,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    maintenanceCalls.add((id, data));
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/fleet/$id/maintenance'),
      data: {'id': 'm-1'},
      statusCode: 201,
    );
  }
}

void main() {
  group('fleetListProvider — dual mode (blueprint §5)', () {
    test('network failure → cached data + banner state (fromCache)', () async {
      final db = FakeLocalDatabase()
        ..seedCollection('fleet', [_cachedTruck]);
      final container = ProviderContainer(
        overrides: [
          fleetEndpointsProvider.overrideWithValue(_ThrowingFleetEndpoints()),
          localDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final data = await container.read(fleetListProvider.future);

      expect(data.fromCache, isTrue);
      expect(container.read(fleetCachedBannerProvider), isTrue);
      expect(data.trucks, hasLength(1));
      expect(data.trucks.single.plate, 'B-OLD');
    });

    test('network failure + empty cache → empty list, no banner', () async {
      final db = FakeLocalDatabase();
      final container = ProviderContainer(
        overrides: [
          fleetEndpointsProvider.overrideWithValue(_ThrowingFleetEndpoints()),
          localDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final data = await container.read(fleetListProvider.future);

      expect(data.fromCache, isTrue);
      expect(data.trucks, isEmpty);
      expect(container.read(fleetCachedBannerProvider), isFalse);
    });

    test('network success → fresh data, cache refreshed, no banner', () async {
      final db = FakeLocalDatabase();
      final container = ProviderContainer(
        overrides: [
          fleetEndpointsProvider.overrideWithValue(_OkFleetEndpoints()),
          localDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final data = await container.read(fleetListProvider.future);

      expect(data.fromCache, isFalse);
      expect(data.trucks.single.plate, 'B-NEW');
      expect(container.read(fleetCachedBannerProvider), isFalse);
      // The fresh payload replaced the cache.
      expect(db.getCachedFleet(), completion(hasLength(1)));
    });
  });

  group('fleetMutationProvider — offline queueing (§7)', () {
    test('createTruck offline enqueues via actionQueueProvider', () async {
      final queue = _RecordingActionQueue();
      final container = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
          isOfflineProvider.overrideWith((ref) => true),
          actionQueueProvider.overrideWithValue(queue),
        ],
      );
      addTearDown(container.dispose);

      await container.read(fleetMutationProvider.notifier).createTruck(
            const TruckDraft(plate: 'B-X', brand: 'MAN', model: 'TGX'),
          );

      expect(queue.enqueued, hasLength(1));
      expect(queue.enqueued.single.$1, '/api/v1/mobile/fleet');
      expect(queue.enqueued.single.$2, 'POST');
      expect(queue.enqueued.single.$3['plate'], 'B-X');
    });

    test('decommissionTruck offline enqueues a PATCH to Inactive', () async {
      final queue = _RecordingActionQueue();
      final container = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
          isOfflineProvider.overrideWith((ref) => true),
          actionQueueProvider.overrideWithValue(queue),
        ],
      );
      addTearDown(container.dispose);

      await container.read(fleetMutationProvider.notifier).decommissionTruck('t-1');

      expect(queue.enqueued, hasLength(1));
      expect(queue.enqueued.single.$1, '/api/v1/mobile/fleet/t-1');
      expect(queue.enqueued.single.$2, 'PATCH');
      expect(queue.enqueued.single.$3['status'], 'Inactive');
    });

    test('updateTruck offline enqueues the PATCH, endpoint not called',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingFleetMutations();
      final container = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
          isOfflineProvider.overrideWith((ref) => true),
          actionQueueProvider.overrideWithValue(queue),
          fleetEndpointsProvider.overrideWithValue(endpoints),
        ],
      );
      addTearDown(container.dispose);

      await container.read(fleetMutationProvider.notifier).updateTruck(
            't-1',
            const TruckUpdateDraft(plate: 'B-X'),
          );

      expect(queue.enqueued, hasLength(1));
      expect(queue.enqueued.single.$1, '/api/v1/mobile/fleet/t-1');
      expect(queue.enqueued.single.$2, 'PATCH');
      expect(queue.enqueued.single.$3['plate'], 'B-X');
      expect(endpoints.updateCalls, isEmpty);
    });

    test('updateTruck online calls the endpoint DIRECTLY and does NOT enqueue',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingFleetMutations();
      final container = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
          isOfflineProvider.overrideWith((ref) => false),
          actionQueueProvider.overrideWithValue(queue),
          fleetEndpointsProvider.overrideWithValue(endpoints),
        ],
      );
      addTearDown(container.dispose);

      await container.read(fleetMutationProvider.notifier).updateTruck(
            't-1',
            const TruckUpdateDraft(plate: 'B-X'),
          );

      expect(endpoints.updateCalls, hasLength(1));
      expect(endpoints.updateCalls.single.$1, 't-1');
      expect(endpoints.updateCalls.single.$2['plate'], 'B-X');
      expect(queue.enqueued, isEmpty);
    });

    test('recordMaintenance offline enqueues the POST, endpoint not called',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingFleetMutations();
      final container = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
          isOfflineProvider.overrideWith((ref) => true),
          actionQueueProvider.overrideWithValue(queue),
          fleetEndpointsProvider.overrideWithValue(endpoints),
        ],
      );
      addTearDown(container.dispose);

      await container.read(fleetMutationProvider.notifier).recordMaintenance(
            't-1',
            MaintenanceRecordDraft(
              date: DateTime(2026, 8, 1),
              category: MaintenanceCategory.oilChange,
              cost: 250,
            ),
          );

      expect(queue.enqueued, hasLength(1));
      expect(queue.enqueued.single.$1, '/api/v1/mobile/fleet/t-1/maintenance');
      expect(queue.enqueued.single.$2, 'POST');
      expect(queue.enqueued.single.$3['category'], 'oil_change');
      expect(queue.enqueued.single.$3['cost'], 250);
      expect(endpoints.maintenanceCalls, isEmpty);
    });

    test('recordMaintenance online calls the endpoint DIRECTLY and does NOT '
        'enqueue', () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingFleetMutations();
      final container = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
          isOfflineProvider.overrideWith((ref) => false),
          actionQueueProvider.overrideWithValue(queue),
          fleetEndpointsProvider.overrideWithValue(endpoints),
        ],
      );
      addTearDown(container.dispose);

      await container.read(fleetMutationProvider.notifier).recordMaintenance(
            't-1',
            MaintenanceRecordDraft(
              date: DateTime(2026, 8, 1),
              category: MaintenanceCategory.oilChange,
              cost: 250,
            ),
          );

      expect(endpoints.maintenanceCalls, hasLength(1));
      expect(endpoints.maintenanceCalls.single.$1, 't-1');
      expect(endpoints.maintenanceCalls.single.$2['category'], 'oil_change');
      expect(queue.enqueued, isEmpty);
    });
  });
}

/// Minimal ActionQueue stand-in that records enqueue calls.
class _RecordingActionQueue implements ActionQueue {
  final List<(String, String, Map<String, dynamic>)> enqueued = [];

  @override
  int get pendingCount => enqueued.length;

  @override
  int get staleCount => 0;

  @override
  Stream<ActionQueueState> get state => const Stream.empty();

  @override
  Future<String> enqueue(
    String endpoint,
    String method, {
    Map<String, dynamic>? data,
  }) async {
    enqueued.add((endpoint, method, data ?? const {}));
    return 'fake-id';
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dequeue(String id) async {}

  @override
  Future<int> replayAll(
    Future<dynamic> Function(QueuedAction action) executor,
  ) async =>
      0;

  @override
  Future<void> clear() async {}

  @override
  Future<void> clearStale() async {}

  @override
  void dispose() {}
}
