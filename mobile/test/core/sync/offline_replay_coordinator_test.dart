import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operion_mobile/core/app/app_services.dart';
import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/auth/token_manager.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/core/sync/connectivity_monitor.dart';

import '../../support/fake_local_database.dart';

// =============================================================================
// Fakes
// =============================================================================

/// LocalDatabase fake whose namespaced IO stores raw values (the queue also
/// persists booleans like `_meta_is_replaying`, which the support fake's
/// map-only JSON encoder cannot handle).
class _FakeQueueDatabase extends FakeLocalDatabase {
  final _raw = <String, Map<String, dynamic>>{};

  @override
  Future<dynamic> read(String key, {String namespace = 'default'}) async {
    return _raw[namespace]?[key];
  }

  @override
  Future<void> write(
    String key,
    dynamic value, {
    String namespace = 'default',
  }) async {
    _raw.putIfAbsent(namespace, () => <String, dynamic>{})[key] = value;
  }

  @override
  Future<void> delete(String key, {String namespace = 'default'}) async {
    _raw[namespace]?.remove(key);
  }

  @override
  Future<List<String>> keysWithPrefix(
    String prefix, {
    String namespace = 'default',
  }) async {
    return _raw[namespace]?.keys.where((k) => k.startsWith(prefix)).toList() ??
        [];
  }

  @override
  Future<void> deleteAllWithPrefix(
    String prefix, {
    String namespace = 'default',
  }) async {
    _raw[namespace]?.removeWhere((k, _) => k.startsWith(prefix));
  }
}

/// Controllable [ConnectivityMonitor] fake (test driver for online/offline).
class _FakeConnectivityMonitor implements ConnectivityMonitor {
  _FakeConnectivityMonitor({bool online = true}) {
    _online = online;
  }

  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();
  final StreamController<ConnectivityResult?> _typeController =
      StreamController<ConnectivityResult?>.broadcast();

  late bool _online;
  ConnectivityResult? _type;

  @override
  bool get isOnline => _online;

  @override
  ConnectivityResult? get connectivityType => _type;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  Stream<ConnectivityResult?> get onTypeChanged => _typeController.stream;

  @override
  Future<void> initialize() async {}

  /// Flips the online state and notifies listeners.
  void setOnline(bool online) {
    if (online == _online) return;
    _online = online;
    _controller.add(online);
  }

  @override
  void dispose() {
    _controller.close();
    _typeController.close();
  }
}

/// [TokenManager] fake whose token presence is controllable per test.
class _FakeTokenManager implements TokenManager {
  _FakeTokenManager({this.accessToken = 'access-token'});

  String? accessToken;

  @override
  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveTokens(String access, String refresh) async {}

  @override
  Future<void> clearTokens() async => accessToken = null;

  @override
  Future<bool> tryRefresh() async => false;
}

/// Records every HTTP call made by the replay executor.
class _ApiCall {
  const _ApiCall(this.method, this.path, this.data);

  final String method;
  final String path;
  final dynamic data;
}

class _FakeApiClient implements ApiClient {
  final List<_ApiCall> calls = [];

  @override
  Dio get dio => throw UnimplementedError('dio not used in tests');

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    calls.add(_ApiCall('GET', path, null));
    return Response<T>(requestOptions: RequestOptions(path: path));
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) async {
    calls.add(_ApiCall('POST', path, data));
    return Response<T>(requestOptions: RequestOptions(path: path));
  }

  @override
  Future<Response<T>> postWithIdempotencyKey<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    calls.add(_ApiCall('POST', path, data));
    return Response<T>(requestOptions: RequestOptions(path: path));
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) async {
    calls.add(_ApiCall('PUT', path, data));
    return Response<T>(requestOptions: RequestOptions(path: path));
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    CancelToken? cancelToken,
  }) async {
    calls.add(_ApiCall('PATCH', path, data));
    return Response<T>(requestOptions: RequestOptions(path: path));
  }

  @override
  Future<Response<T>> delete<T>(String path, {CancelToken? cancelToken}) async {
    calls.add(_ApiCall('DELETE', path, null));
    return Response<T>(requestOptions: RequestOptions(path: path));
  }

  @override
  Future<Response<T>> upload<T>(
    String path,
    FormData formData, {
    CancelToken? cancelToken,
  }) async {
    calls.add(_ApiCall('UPLOAD', path, null));
    return Response<T>(requestOptions: RequestOptions(path: path));
  }
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('OfflineReplayCoordinator', () {
    test('replays queued actions when connectivity returns', () async {
      final fakeDb = _FakeQueueDatabase();
      final queue = ActionQueue(fakeDb, backoffBase: Duration.zero);
      final monitor = _FakeConnectivityMonitor(online: false);
      final tokens = _FakeTokenManager(accessToken: 'access-token');
      final api = _FakeApiClient();

      final container = ProviderContainer(overrides: [
        actionQueueProvider.overrideWithValue(queue),
        connectivityProvider.overrideWithValue(monitor),
        tokenManagerProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWithValue(api),
      ]);
      addTearDown(container.dispose);

      final coordinator = OfflineReplayCoordinator(container);
      addTearDown(coordinator.dispose);
      await coordinator.initialize();

      // Offline mutation queued while the device is offline.
      await queue.enqueue('/api/v1/mobile/drivers', 'POST',
          data: {'name': 'Driver A'});
      expect(queue.pendingCount, 1);
      expect(api.calls, isEmpty);

      // Connectivity returns → the coordinator drains the queue.
      monitor.setOnline(true);
      await pumpEventQueue(times: 50);

      expect(api.calls, hasLength(1));
      expect(api.calls.single.method, 'POST');
      expect(api.calls.single.path, '/api/v1/mobile/drivers');
      expect(api.calls.single.data, {'name': 'Driver A'});
      expect(queue.pendingCount, 0);
    });

    test('drains the queue at startup when already authenticated and online',
        () async {
      final fakeDb = _FakeQueueDatabase();
      final queue = ActionQueue(fakeDb, backoffBase: Duration.zero);
      final monitor = _FakeConnectivityMonitor(online: true);
      final tokens = _FakeTokenManager(accessToken: 'access-token');
      final api = _FakeApiClient();

      final container = ProviderContainer(overrides: [
        actionQueueProvider.overrideWithValue(queue),
        connectivityProvider.overrideWithValue(monitor),
        tokenManagerProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWithValue(api),
      ]);
      addTearDown(container.dispose);

      // Persisted offline action from a previous session.
      await queue.enqueue('/api/v1/mobile/fleet/truck-1', 'PATCH',
          data: {'status': 'Inactive'});

      final coordinator = OfflineReplayCoordinator(container);
      addTearDown(coordinator.dispose);
      await coordinator.initialize();
      await pumpEventQueue(times: 50);

      expect(api.calls, hasLength(1));
      expect(api.calls.single.method, 'PATCH');
      expect(api.calls.single.path, '/api/v1/mobile/fleet/truck-1');
      expect(queue.pendingCount, 0);
    });

    test('does not replay before the session is authenticated', () async {
      final fakeDb = _FakeQueueDatabase();
      final queue = ActionQueue(fakeDb, backoffBase: Duration.zero);
      final monitor = _FakeConnectivityMonitor(online: true);
      final tokens = _FakeTokenManager(accessToken: null);
      final api = _FakeApiClient();

      final container = ProviderContainer(overrides: [
        actionQueueProvider.overrideWithValue(queue),
        connectivityProvider.overrideWithValue(monitor),
        tokenManagerProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWithValue(api),
      ]);
      addTearDown(container.dispose);

      final coordinator = OfflineReplayCoordinator(container);
      addTearDown(coordinator.dispose);
      // Online + no token → the startup replay must be skipped.
      await coordinator.initialize();
      await queue.enqueue('/api/v1/mobile/clients', 'POST',
          data: {'name': 'ACME'});
      await pumpEventQueue(times: 50);

      expect(api.calls, isEmpty, reason: 'no replay without tokens');
      expect(queue.pendingCount, 1);

      // Session restored → the queue drains.
      tokens.accessToken = 'access-token';
      container.read(authStateProvider.notifier).setAuthenticated();
      await pumpEventQueue(times: 50);

      expect(api.calls, hasLength(1));
      expect(api.calls.single.path, '/api/v1/mobile/clients');
      expect(queue.pendingCount, 0);
    });

    test('skips document-upload actions (not replayable as JSON)', () async {
      final fakeDb = _FakeQueueDatabase();
      final queue = ActionQueue(fakeDb, backoffBase: Duration.zero);
      final monitor = _FakeConnectivityMonitor(online: false);
      final tokens = _FakeTokenManager(accessToken: 'access-token');
      final api = _FakeApiClient();

      final container = ProviderContainer(overrides: [
        actionQueueProvider.overrideWithValue(queue),
        connectivityProvider.overrideWithValue(monitor),
        tokenManagerProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWithValue(api),
      ]);
      addTearDown(container.dispose);

      final coordinator = OfflineReplayCoordinator(container);
      addTearDown(coordinator.dispose);
      await coordinator.initialize();

      await queue.enqueue('/api/v1/documents/upload', 'POST',
          data: {'file_path': '/tmp/doc.jpg'});

      monitor.setOnline(true);
      await pumpEventQueue(times: 50);

      expect(api.calls, isEmpty,
          reason: 'document uploads are never replayed as JSON');
      expect(queue.pendingCount, 0,
          reason: 'skipped action is dequeued (permanent failure)');
    });
  });

  group('ActionQueue replay robustness', () {
    test('replayAll runs an extra cycle when a replay is requested mid-run',
        () async {
      final fakeDb = _FakeQueueDatabase();
      final queue = ActionQueue(fakeDb, backoffBase: Duration.zero);
      await queue.initialize();
      await queue.enqueue('/first', 'GET');

      final gate = Completer<void>();
      final replayed = <String>[];
      final firstFuture = queue.replayAll((action) async {
        replayed.add(action.endpoint);
        if (action.endpoint == '/first') await gate.future;
      });

      await Future<void>.delayed(Duration.zero);

      // Enqueue + request another replay while the first is still running.
      await queue.enqueue('/second', 'POST');
      final secondCount = await queue.replayAll((action) async {
        replayed.add(action.endpoint);
      });
      expect(secondCount, 0, reason: 'mid-run request is queued, not dropped');

      gate.complete();
      await firstFuture;

      expect(replayed, ['/first', '/second'],
          reason: 'action enqueued during replay is drained by an extra cycle');
      expect(queue.pendingCount, 0);
    });

    test('drops an action permanently after maxRetryCount failures', () async {
      final fakeDb = _FakeQueueDatabase();
      final queue =
          ActionQueue(fakeDb, maxRetryCount: 2, backoffBase: Duration.zero);
      await queue.initialize();
      await queue.enqueue('/flaky', 'PATCH');

      ActionQueueState? emitted;
      final sub = queue.state.listen((s) {
        emitted = emitted != null && s.lastError == null ? emitted : s;
      });

      await queue.replayAll((action) async => throw Exception('boom'));
      expect(queue.pendingCount, 1, reason: 'first failure is retried');

      await queue.replayAll((action) async => throw Exception('boom'));
      expect(queue.pendingCount, 0, reason: 'dropped after max retries');
      await Future<void>.delayed(Duration.zero);
      expect(emitted?.lastError, contains('permanently failed'));
      await sub.cancel();
    });
  });
}