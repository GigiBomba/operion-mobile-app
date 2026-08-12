// Tachograph upload Wi-Fi-only gate test (Phase 4B §4.10).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/sync/connectivity_monitor.dart';
import 'package:operion_mobile/features/settings/providers/settings_providers.dart';
import 'package:operion_mobile/features/tachograph/providers/tacho_providers.dart';

class _TachoStub extends TachoEndpoints {
  _TachoStub()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  bool importCalled = false;

  @override
  Future<Response> import({
    required String driverId,
    required String filePath,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    importCalled = true;
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'job_id': 42},
      statusCode: 202,
    );
  }
}

void main() {
  test('wifiOnly + cellular → upload blocked, no API call', () async {
    final stub = _TachoStub();
    final container = ProviderContainer(
      overrides: [
        isOfflineProvider.overrideWith((ref) => false),
        isOnWifiProvider.overrideWith((ref) => Stream.value(false)),
        dataUsageProvider.overrideWith((ref) => DataUsageNotifier(ref)),
        tachoEndpointsProvider.overrideWithValue(stub),
      ],
    );
    addTearDown(container.dispose);
    container.read(dataUsageProvider.notifier).state =
        const DataUsagePreferences(wifiOnlyLargeSyncs: true);
    // Let the stream provider emit its (cellular) value.
    await container.read(isOnWifiProvider.future);

    await expectLater(
      container
          .read(tachoImportProvider.notifier)
          .import(driverId: '7', filePath: '/tmp/card.ddd'),
      throwsA(isA<TachoUploadWifiBlocked>()),
    );

    final state = container.read(tachoImportProvider);
    expect(state.wifiBlocked, isTrue);
    expect(state.phase, TachoImportPhase.error);
    expect(stub.importCalled, isFalse,
        reason: 'The Wi-Fi gate must prevent any upload network call');
  });

  test('wifiOnly ON but on Wi-Fi → upload proceeds', () async {
    final stub = _TachoStub();
    final container = ProviderContainer(
      overrides: [
        isOfflineProvider.overrideWith((ref) => false),
        isOnWifiProvider.overrideWith((ref) => Stream.value(true)),
        dataUsageProvider.overrideWith((ref) => DataUsageNotifier(ref)),
        tachoEndpointsProvider.overrideWithValue(stub),
      ],
    );
    addTearDown(container.dispose);
    container.read(dataUsageProvider.notifier).state =
        const DataUsagePreferences(wifiOnlyLargeSyncs: true);

    await container
        .read(tachoImportProvider.notifier)
        .import(driverId: '7', filePath: '/tmp/card.ddd');
    expect(stub.importCalled, isTrue);
    expect(container.read(tachoImportProvider).phase, TachoImportPhase.processing);
  });

  test('wifiOnly OFF on cellular → upload proceeds', () async {
    final stub = _TachoStub();
    final container = ProviderContainer(
      overrides: [
        isOfflineProvider.overrideWith((ref) => false),
        isOnWifiProvider.overrideWith((ref) => Stream.value(false)),
        dataUsageProvider.overrideWith((ref) => DataUsageNotifier(ref)),
        tachoEndpointsProvider.overrideWithValue(stub),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(tachoImportProvider.notifier)
        .import(driverId: '7', filePath: '/tmp/card.ddd');
    expect(stub.importCalled, isTrue);
  });
}
