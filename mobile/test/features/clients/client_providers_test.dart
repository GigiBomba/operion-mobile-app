import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/client_endpoints.dart';
import 'package:operion_mobile/core/security/biometric_gate.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/features/clients/models/client.dart';
import 'package:operion_mobile/features/clients/providers/client_providers.dart';
import 'package:operion_mobile/features/invoicing/providers/invoicing_providers.dart'
    show BiometricRequired;

import '../../support/fake_local_database.dart';

const _cachedClient = {
  'id': 'c-1',
  'company_id': 'c1',
  'name': 'Cached Client',
  'payment_terms_days': 30,
  'rating': 4.0,
  'is_active': true,
};

/// Endpoints stub that fails the client list (offline / server down).
class _ThrowingClientEndpoints extends ClientEndpoints {
  _ThrowingClientEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  @override
  Future<Response> getClients({
    String? search,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/api/v1/mobile/clients'),
      type: DioExceptionType.connectionError,
    );
  }
}

/// Endpoints stub that records createClient calls.
class _RecordingCreateEndpoints extends ClientEndpoints {
  _RecordingCreateEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<Map<String, dynamic>> createCalls = [];

  @override
  Future<Response> createClient(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    createCalls.add(data);
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/clients'),
      data: {'id': 'c-9', 'name': data['name']},
      statusCode: 201,
    );
  }
}

/// Endpoints stub that records merge calls and returns counts.
class _RecordingMergeEndpoints extends ClientEndpoints {
  _RecordingMergeEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<(String, List<String>)> mergeCalls = [];

  @override
  Future<Response> mergeClients({
    required String targetId,
    required List<String> sourceIds,
    CancelToken? cancelToken,
  }) async {
    mergeCalls.add((targetId, sourceIds));
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/clients/merge'),
      data: {
        'merged_trip_count': 3,
        'merged_invoice_count': 2,
        'merged_contact_count': 1,
      },
      statusCode: 200,
    );
  }
}

/// Endpoints stub that records updateClient calls.
class _RecordingUpdateEndpoints extends ClientEndpoints {
  _RecordingUpdateEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<(String, Map<String, dynamic>)> updateCalls = [];

  @override
  Future<Response> updateClient(
    String clientId,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    updateCalls.add((clientId, data));
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/clients/$clientId'),
      data: {'id': clientId, 'name': data['name']},
      statusCode: 200,
    );
  }
}

/// Minimal recording ActionQueue.
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
    return 'id';
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
  group('clientListProvider — dual mode (blueprint §5)', () {
    test('network failure → cached data + banner state', () async {
      final db = FakeLocalDatabase()
        ..seedCollection('clients', [_cachedClient]);
      final container = ProviderContainer(
        overrides: [
          clientEndpointsProvider.overrideWithValue(_ThrowingClientEndpoints()),
          localDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final data = await container.read(clientListProvider.future);

      expect(data.fromCache, isTrue);
      expect(container.read(clientCachedBannerProvider), isTrue);
      expect(data.clients.single.name, 'Cached Client');
    });
  });

  group('mergeClients — NEVER queued (§7)', () {
    test('offline merge throws MergeRequiresConnection and NEVER enqueues',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingMergeEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => true),
          actionQueueProvider.overrideWithValue(queue),
          clientEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(clientMutationProvider.notifier);

      await expectLater(
        notifier.mergeClients(targetId: 't1', sourceIds: ['s1', 's2']),
        throwsA(isA<MergeRequiresConnection>()),
      );

      // PROOF: the action queue never received a mergeClients call.
      expect(queue.enqueued, isEmpty,
          reason: 'mergeClients must never be queued (blueprint §7)');
      // And the endpoint was not called either (blocked before the wire).
      expect(endpoints.mergeCalls, isEmpty);
    });

    test('online merge calls the endpoint DIRECTLY and returns counts',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingMergeEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => false),
          actionQueueProvider.overrideWithValue(queue),
          clientEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
          biometricGateProvider.overrideWithValue(
            BiometricGate(authenticate: (_) async => true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(clientMutationProvider.notifier);
      final result = await notifier.mergeClients(
        targetId: 't1',
        sourceIds: ['s1', 's2'],
      );

      expect(endpoints.mergeCalls, hasLength(1));
      expect(endpoints.mergeCalls.single.$1, 't1');
      expect(endpoints.mergeCalls.single.$2, ['s1', 's2']);
      expect(result.mergedTripCount, 3);
      expect(queue.enqueued, isEmpty);
    });
  });

  group('mergeClients — §12 biometric step-up', () {
    test('biometric FAILURE → BiometricRequired, endpoint NOT called',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingMergeEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => false),
          actionQueueProvider.overrideWithValue(queue),
          clientEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
          biometricGateProvider.overrideWithValue(
            BiometricGate(authenticate: (_) async => false),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(clientMutationProvider.notifier);

      await expectLater(
        notifier.mergeClients(targetId: 't1', sourceIds: ['s1']),
        throwsA(isA<BiometricRequired>()),
      );
      expect(endpoints.mergeCalls, isEmpty,
          reason: 'API must be unreachable without a successful biometric check');
      expect(queue.enqueued, isEmpty);
    });

    test('biometric SUCCESS → proceeds and calls the endpoint DIRECTLY',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingMergeEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => false),
          actionQueueProvider.overrideWithValue(queue),
          clientEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
          biometricGateProvider.overrideWithValue(
            BiometricGate(authenticate: (_) async => true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(clientMutationProvider.notifier);
      final result = await notifier.mergeClients(
        targetId: 't1',
        sourceIds: ['s1'],
      );

      expect(endpoints.mergeCalls, hasLength(1));
      expect(endpoints.mergeCalls.single.$1, 't1');
      expect(result.mergedTripCount, 3);
      expect(queue.enqueued, isEmpty);
    });
  });

  group('updateClient — offline queueing (§7)', () {
    test('offline updateClient enqueues the PATCH, endpoint not called',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingUpdateEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => true),
          actionQueueProvider.overrideWithValue(queue),
          clientEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(clientMutationProvider.notifier)
          .updateClient('c-1', const ClientDraft(name: 'Acme'));

      expect(queue.enqueued, hasLength(1));
      expect(queue.enqueued.single.$1, '/api/v1/mobile/clients/c-1');
      expect(queue.enqueued.single.$2, 'PATCH');
      expect(queue.enqueued.single.$3['name'], 'Acme');
      expect(endpoints.updateCalls, isEmpty);
    });

    test('online updateClient calls the endpoint DIRECTLY and does NOT enqueue',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingUpdateEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => false),
          actionQueueProvider.overrideWithValue(queue),
          clientEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(clientMutationProvider.notifier)
          .updateClient('c-1', const ClientDraft(name: 'Acme'));

      expect(endpoints.updateCalls, hasLength(1));
      expect(endpoints.updateCalls.single.$1, 'c-1');
      expect(endpoints.updateCalls.single.$2['name'], 'Acme');
      expect(queue.enqueued, isEmpty);
    });
  });

  group('addContact — offline queueing (§7)', () {
    test('offline addContact enqueues instead of calling the endpoint',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingMergeEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => true),
          actionQueueProvider.overrideWithValue(queue),
          clientEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(clientMutationProvider.notifier)
          .addContact('c-1', const ClientContactDraft(name: 'Ion'));

      expect(queue.enqueued, hasLength(1));
      expect(queue.enqueued.single.$1, '/api/v1/mobile/clients/c-1/contacts');
      expect(queue.enqueued.single.$2, 'POST');
    });
  });

  group('createClient — offline queueing (§7)', () {
    test('offline createClient enqueues the draft instead of calling the endpoint',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingCreateEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => true),
          actionQueueProvider.overrideWithValue(queue),
          clientEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(clientMutationProvider.notifier)
          .createClient(const ClientDraft(name: 'Acme', vatNumber: 'RO1234'));

      expect(queue.enqueued, hasLength(1));
      expect(queue.enqueued.single.$1, '/api/v1/mobile/clients');
      expect(queue.enqueued.single.$2, 'POST');
      // The draft payload is queued verbatim for replay.
      expect(queue.enqueued.single.$3, {
        'name': 'Acme',
        'vat_number': 'RO1234',
        'payment_terms_days': 0,
        'is_active': true,
      });
      // Offline: the endpoint is never reached.
      expect(endpoints.createCalls, isEmpty);
    });

    test('online createClient calls the endpoint DIRECTLY and does NOT enqueue',
        () async {
      final queue = _RecordingActionQueue();
      final endpoints = _RecordingCreateEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => false),
          actionQueueProvider.overrideWithValue(queue),
          clientEndpointsProvider.overrideWithValue(endpoints),
          localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(clientMutationProvider.notifier)
          .createClient(const ClientDraft(name: 'Acme', vatNumber: 'RO1234'));

      expect(endpoints.createCalls, hasLength(1));
      expect(endpoints.createCalls.single, {
        'name': 'Acme',
        'vat_number': 'RO1234',
        'payment_terms_days': 0,
        'is_active': true,
      });
      expect(queue.enqueued, isEmpty);
    });
  });
}
