// Phase 4B Wi-Fi-only gate tests (§4.10).
//
// Covers: the WifiGate predicate, DeltaSyncService deferral (no network call),
// and the trip-history export block (no endpoint call).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/sync_endpoints.dart';
import 'package:operion_mobile/core/storage/local_db.dart';
import 'package:operion_mobile/core/sync/delta_sync_service.dart';
import 'package:operion_mobile/core/sync/connectivity_monitor.dart';
import 'package:operion_mobile/core/sync/wifi_gate.dart';
import 'package:operion_mobile/features/history/providers/history_providers.dart';
import 'package:operion_mobile/features/settings/providers/settings_providers.dart';

class _FakeSyncEndpoints implements SyncEndpoints {
  @override
  ApiClient get client => throw UnimplementedError();

  bool syncEntityCalled = false;

  @override
  Future<Response> syncEntity(String entityType, {String? cursor}) async {
    syncEntityCalled = true;
    return Response(
      data: {'records': <Map<String, dynamic>>[], 'cursor': null},
      requestOptions: RequestOptions(path: ''),
    );
  }

  @override
  Future<Response> syncEntityFull(String entityType) async {
    return Response(
      data: {'records': <Map<String, dynamic>>[], 'cursor': null},
      requestOptions: RequestOptions(path: ''),
    );
  }

  Future<Response> getDelta(String cursor) =>
      throw UnimplementedError('not used');
}

class _FakeLocalDatabase implements LocalDatabase {
  @override
  Future<void> initialize() async {}

  @override
  Future<dynamic> read(String key, {String namespace = 'default'}) async => null;

  @override
  Future<void> write(String key, dynamic value, {String namespace = 'default'}) async {}

  @override
  Future<void> delete(String key, {String namespace = 'default'}) async {}

  @override
  Future<List<String>> keysWithPrefix(String prefix,
      {String namespace = 'default'}) async =>
      const [];

  @override
  Future<void> deleteAllWithPrefix(String prefix,
      {String namespace = 'default'}) async {}

  @override
  Future<void> cacheData(
      String collection, String key, Map<String, dynamic> data) async {}

  @override
  Future<Map<String, dynamic>?> getCachedData(
      String collection, String key) async =>
      null;

  @override
  Future<void> cacheTransports(List<Map<String, dynamic>> transports) async {}

  @override
  Future<List<Map<String, dynamic>>> getCachedTransports() async => const [];

  @override
  Future<void> cacheFleet(List<Map<String, dynamic>> trucks) async {}

  @override
  Future<List<Map<String, dynamic>>> getCachedFleet() async => const [];

  @override
  Future<void> cacheDrivers(List<Map<String, dynamic>> drivers) async {}

  @override
  Future<List<Map<String, dynamic>>> getCachedDrivers() async => const [];

  @override
  Future<void> cacheClients(List<Map<String, dynamic>> clients) async {}

  @override
  Future<List<Map<String, dynamic>>> getCachedClients() async => const [];

  @override
  Future<void> cacheInvoices(List<Map<String, dynamic>> invoices) async {}

  @override
  Future<List<Map<String, dynamic>>> getCachedInvoices() async => const [];

  @override
  Future<void> cacheTeamMembers(List<Map<String, dynamic>> members) async {}

  @override
  Future<List<Map<String, dynamic>>> getCachedTeamMembers() async => const [];

  @override
  Future<void> clearCollection(String collection) async {}

  @override
  Future<void> close() async {}
}

class _RecordingHistoryEndpoints extends HistoryEndpoints {
  _RecordingHistoryEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => null,
        ));

  bool exportTripsCalled = false;

  @override
  Future<Response> exportTrips(
    TripExportRequest request, {
    CancelToken? cancelToken,
  }) async {
    exportTripsCalled = true;
    return Response(
      data: {'job_id': '1'},
      requestOptions: RequestOptions(path: ''),
    );
  }
}

void main() {
  group('WifiGate', () {
    test('blocks when wifiOnly ON + online + NOT on wifi', () {
      const gate = WifiGate(wifiOnlyLargeSyncs: true, onWifi: false, online: true);
      expect(gate.blocksLargeTransfer, isTrue);
    });

    test('does not block when wifiOnly ON but on wifi', () {
      const gate = WifiGate(wifiOnlyLargeSyncs: true, onWifi: true, online: true);
      expect(gate.blocksLargeTransfer, isFalse);
    });

    test('does not block when wifiOnly OFF even on cellular', () {
      const gate = WifiGate(wifiOnlyLargeSyncs: false, onWifi: false, online: true);
      expect(gate.blocksLargeTransfer, isFalse);
    });

    test('does not block when offline (its own gate handles that)', () {
      const gate = WifiGate(wifiOnlyLargeSyncs: true, onWifi: false, online: false);
      expect(gate.blocksLargeTransfer, isFalse);
    });
  });

  group('DeltaSyncService WiFi gate', () {
    test('sync() defers WITHOUT any network call when the gate blocks', () async {
      final endpoints = _FakeSyncEndpoints();
      final service = DeltaSyncService(
        endpoints,
        _FakeLocalDatabase(),
        isLargeTransferBlocked: () => true,
      );

      final result = await service.sync(entityType: 'fleet');

      expect(result.deferred, isTrue);
      expect(result.success, isFalse);
      expect(endpoints.syncEntityCalled, isFalse,
          reason: 'The Wi-Fi gate must skip the fetch entirely');
    });

    test('sync() proceeds when the gate does not block', () async {
      final endpoints = _FakeSyncEndpoints();
      final service = DeltaSyncService(
        endpoints,
        _FakeLocalDatabase(),
        isLargeTransferBlocked: () => false,
      );

      final result = await service.sync(entityType: 'fleet');

      expect(result.deferred, isFalse);
      expect(result.success, isTrue);
      expect(endpoints.syncEntityCalled, isTrue);
    });
  });

  group('wifiGateProvider', () {
    test('reflects wifiOnly + cellular → blocksLargeTransfer true', () async {
      final container = ProviderContainer(overrides: [
        isOfflineProvider.overrideWith((ref) => false),
        isOnWifiProvider.overrideWith((ref) => Stream.value(false)),
        dataUsageProvider.overrideWith((ref) => DataUsageNotifier(ref)),
      ]);
      addTearDown(container.dispose);
      container.read(dataUsageProvider.notifier).state =
          const DataUsagePreferences(wifiOnlyLargeSyncs: true);
      // Let the stream provider emit its (cellular) value.
      await container.read(isOnWifiProvider.future);

      expect(container.read(wifiGateProvider).blocksLargeTransfer, isTrue);
    });
  });

  group('tripHistoryExportProvider WiFi gate', () {
    test('throws WifiGateBlocked and never calls the endpoint', () async {
      final endpoints = _RecordingHistoryEndpoints();
      final container = ProviderContainer(overrides: [
        isOfflineProvider.overrideWith((ref) => false),
        isOnWifiProvider.overrideWith((ref) => Stream.value(false)),
        dataUsageProvider.overrideWith((ref) => DataUsageNotifier(ref)),
        historyEndpointsProvider.overrideWithValue(endpoints),
      ]);
      addTearDown(container.dispose);
      container.read(dataUsageProvider.notifier).state =
          const DataUsagePreferences(wifiOnlyLargeSyncs: true);
      await container.read(isOnWifiProvider.future);

      await expectLater(
        container
            .read(tripHistoryExportProvider(const TripExportRequest()).future),
        throwsA(isA<WifiGateBlocked>()),
      );
      expect(endpoints.exportTripsCalled, isFalse);
    });

    test('kicks off the export when the gate does not block', () async {
      final endpoints = _RecordingHistoryEndpoints();
      final container = ProviderContainer(overrides: [
        isOfflineProvider.overrideWith((ref) => false),
        isOnWifiProvider.overrideWith((ref) => Stream.value(true)),
        dataUsageProvider.overrideWith((ref) => DataUsageNotifier(ref)),
        historyEndpointsProvider.overrideWithValue(endpoints),
      ]);
      addTearDown(container.dispose);
      container.read(dataUsageProvider.notifier).state =
          const DataUsagePreferences(wifiOnlyLargeSyncs: true);

      final jobId = await container
          .read(tripHistoryExportProvider(const TripExportRequest()).future);
      expect(jobId, '1');
      expect(endpoints.exportTripsCalled, isTrue);
    });
  });
}
