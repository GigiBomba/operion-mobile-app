// Maintenance schedule mutation offline rules (blueprint §7 / §13.5 gap
// coverage).
//
// Queueable: scheduleMaintenance — offline → enqueued via actionQueueProvider
// with the exact endpoint/method/data; online → direct endpoint call, queue
// untouched.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/features/maintenance/models/maintenance.dart';
import 'package:operion_mobile/features/maintenance/providers/maintenance_providers.dart';

import '../../support/fake_local_database.dart';

/// Endpoints stub that records createSchedule calls.
class _RecordingMaintenanceEndpoints extends MaintenanceEndpoints {
  _RecordingMaintenanceEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<Map<String, dynamic>> createCalls = [];

  @override
  Future<Response> createSchedule(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    createCalls.add(data);
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/maintenance/schedule'),
      data: {'id': 's-9', ...data},
      statusCode: 201,
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
  group('maintenanceMutationProvider — offline queueing (§7)', () {
    test('scheduleMaintenance offline enqueues the POST, endpoint not called',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingMaintenanceEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => true),
          actionQueueProvider.overrideWithValue(queue),
          maintenanceEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(maintenanceMutationProvider.notifier)
          .scheduleMaintenance(
            const MaintenanceScheduleDraft(
              truckId: 't-1',
              maintenanceType: 'Oil change',
              intervalKm: 15000,
            ),
          );

      expect(queue.enqueued, hasLength(1));
      expect(queue.enqueued.single.$1, '/api/v1/mobile/maintenance/schedule');
      expect(queue.enqueued.single.$2, 'POST');
      expect(queue.enqueued.single.$3, {
        'truck_id': 't-1',
        'maintenance_type': 'Oil change',
        'interval_km': 15000,
      });
      expect(endpoints.createCalls, isEmpty);
    });

    test('scheduleMaintenance online calls the endpoint DIRECTLY and does NOT '
        'enqueue', () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingMaintenanceEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => false),
          actionQueueProvider.overrideWithValue(queue),
          maintenanceEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(maintenanceMutationProvider.notifier)
          .scheduleMaintenance(
            const MaintenanceScheduleDraft(
              truckId: 't-1',
              maintenanceType: 'Oil change',
              intervalKm: 15000,
            ),
          );

      expect(endpoints.createCalls, hasLength(1));
      expect(endpoints.createCalls.single['truck_id'], 't-1');
      expect(endpoints.createCalls.single['interval_km'], 15000);
      expect(queue.enqueued, isEmpty);
    });
  });
}
