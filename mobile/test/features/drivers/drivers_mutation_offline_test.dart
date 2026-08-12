// Driver mutation offline rules (blueprint §7 / §13.5 gap coverage).
//
// Queueable: createDriver / updateDriver — offline → enqueued via
// actionQueueProvider with the exact endpoint/method/data; online → direct
// endpoint call, queue untouched.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/drivers_endpoints.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/features/teams/providers/teams_providers.dart';
import 'package:operion_mobile/shared/models/driver.dart';

import '../../support/fake_local_database.dart';

/// Endpoints stub that records createDriver / updateDriver calls.
class _RecordingDriversMutationEndpoints extends DriversEndpoints {
  _RecordingDriversMutationEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<Map<String, dynamic>> createCalls = [];
  final List<(String, Map<String, dynamic>)> updateCalls = [];

  @override
  Future<Response> createDriver(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    createCalls.add(data);
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/drivers'),
      data: {'id': 'd-9', 'name': data['name']},
      statusCode: 201,
    );
  }

  @override
  Future<Response> updateDriver(
    String id,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    updateCalls.add((id, data));
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/drivers/$id'),
      data: {'id': id, 'name': data['name']},
      statusCode: 200,
    );
  }
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

void main() {
  group('driverMutationProvider — offline queueing (§7)', () {
    test('createDriver offline enqueues POST /api/v1/mobile/drivers, endpoint '
        'not called', () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingDriversMutationEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => true),
          actionQueueProvider.overrideWithValue(queue),
          driversEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(driverMutationProvider.notifier).createDriver(
            const DriverDraft(name: 'Ion'),
          );

      expect(queue.enqueued, hasLength(1));
      expect(queue.enqueued.single.$1, '/api/v1/mobile/drivers');
      expect(queue.enqueued.single.$2, 'POST');
      expect(queue.enqueued.single.$3, {'name': 'Ion'});
      expect(endpoints.createCalls, isEmpty);
    });

    test('createDriver online calls the endpoint DIRECTLY and does NOT enqueue',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingDriversMutationEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => false),
          actionQueueProvider.overrideWithValue(queue),
          driversEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(driverMutationProvider.notifier).createDriver(
            const DriverDraft(name: 'Ion'),
          );

      expect(endpoints.createCalls, hasLength(1));
      expect(endpoints.createCalls.single, {'name': 'Ion'});
      expect(queue.enqueued, isEmpty);
    });

    test('updateDriver offline enqueues the PATCH, endpoint not called',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingDriversMutationEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => true),
          actionQueueProvider.overrideWithValue(queue),
          driversEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(driverMutationProvider.notifier).updateDriver(
            'd-1',
            const DriverDraft(name: 'Ion', phone: '0722'),
          );

      expect(queue.enqueued, hasLength(1));
      expect(queue.enqueued.single.$1, '/api/v1/mobile/drivers/d-1');
      expect(queue.enqueued.single.$2, 'PATCH');
      expect(queue.enqueued.single.$3, {'name': 'Ion', 'phone': '0722'});
      expect(endpoints.updateCalls, isEmpty);
    });

    test('updateDriver online calls the endpoint DIRECTLY and does NOT enqueue',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingDriversMutationEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => false),
          actionQueueProvider.overrideWithValue(queue),
          driversEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(driverMutationProvider.notifier).updateDriver(
            'd-1',
            const DriverDraft(name: 'Ion', phone: '0722'),
          );

      expect(endpoints.updateCalls, hasLength(1));
      expect(endpoints.updateCalls.single.$1, 'd-1');
      expect(endpoints.updateCalls.single.$2, {'name': 'Ion', 'phone': '0722'});
      expect(queue.enqueued, isEmpty);
    });
  });
}
