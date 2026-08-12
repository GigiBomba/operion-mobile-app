import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/sync/wifi_gate.dart';
import 'package:operion_mobile/features/tachograph/models/tacho_compliance.dart';
import 'package:operion_mobile/features/tachograph/providers/tacho_providers.dart';

class _TachoStub extends TachoEndpoints {
  _TachoStub()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  String? lastDriverId;
  String? lastFilePath;
  ProgressCallback? lastOnSendProgress;
  bool importCalled = false;
  bool statusCalled = false;
  int statusCalls = 0;
  Map<String, dynamic>? statusResponse;

  @override
  Future<Response> import({
    required String driverId,
    required String filePath,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    importCalled = true;
    lastDriverId = driverId;
    lastFilePath = filePath;
    lastOnSendProgress = onSendProgress;
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'job_id': 42},
      statusCode: 202,
    );
  }

  @override
  Future<Response> importStatus(String jobId, {CancelToken? cancelToken}) async {
    statusCalled = true;
    statusCalls++;
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: statusResponse ?? {'status': 'processing'},
      statusCode: 200,
    );
  }
}

ProviderContainer _container(_TachoStub stub) {
  final container = ProviderContainer(
    overrides: [
      isOfflineProvider.overrideWith((ref) => false),
      tachoEndpointsProvider.overrideWithValue(stub),
      wifiGateProvider.overrideWithValue(
        const WifiGate(wifiOnlyLargeSyncs: false, onWifi: true, online: true),
      ),
    ],
  );
  return container;
}

void main() {
  group('tachoImportProvider', () {
    test('uploads with progress and transitions to processing with job_id',
        () async {
      final stub = _TachoStub();
      final container = _container(stub);
      addTearDown(container.dispose);

      final notifier = container.read(tachoImportProvider.notifier);
      expect(container.read(tachoImportProvider).phase, TachoImportPhase.idle);

      final future = notifier.import(driverId: '7', filePath: '/tmp/card.ddd');
      // The upload phase fires synchronously before the first await.
      expect(container.read(tachoImportProvider).phase, TachoImportPhase.uploading);

      // Simulate backend progress: 50 of 100 bytes.
      stub.lastOnSendProgress!(50, 100);
      expect(container.read(tachoImportProvider).progress, closeTo(0.5, 0.001));

      await future;
      final state = container.read(tachoImportProvider);
      expect(state.phase, TachoImportPhase.processing);
      expect(state.jobId, '42');
      expect(state.progress, 1);
      expect(stub.lastDriverId, '7');
      expect(stub.lastFilePath, '/tmp/card.ddd');
      expect(stub.importCalled, isTrue);
    });

    test('offline import throws TachoUploadRequiresConnection and never calls '
        'the network', () async {
      final stub = _TachoStub();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => true),
          tachoEndpointsProvider.overrideWithValue(stub),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(tachoImportProvider.notifier)
            .import(driverId: '7', filePath: '/tmp/card.ddd'),
        throwsA(isA<TachoUploadRequiresConnection>()),
      );
      expect(stub.importCalled, isFalse);
    });

    test('onJobSuccess stores the compliance result', () async {
      final stub = _TachoStub();
      final container = _container(stub);
      addTearDown(container.dispose);

      final notifier = container.read(tachoImportProvider.notifier);
      notifier.onJobSuccess(_result());
      final state = container.read(tachoImportProvider);
      expect(state.phase, TachoImportPhase.success);
      expect(state.result!.weeklyDrivingMinutes, 3456);
      expect(state.result!.violations.single, 'Weekly driving limit exceeded');
    });
  });

  group('tachoImportJobStatusProvider', () {
    test('polls every 3s and terminates on success', () {
      final stub = _TachoStub()
        ..statusResponse = {
          'status': 'processing',
        };
      final container = ProviderContainer(
        overrides: [tachoEndpointsProvider.overrideWithValue(stub)],
      );
      addTearDown(container.dispose);

      fakeAsync((async) {
        final states = <TachoImportJobState>[];
        final sub = container.listen(
          tachoImportJobStatusProvider('42'),
          (_, next) {
            final v = next.valueOrNull;
            if (v != null) states.add(v);
          },
        );

        // First tick: processing.
        async.elapse(const Duration(seconds: 3));
        expect(states, isNotEmpty);
        expect(states.last.status, TachoImportStatus.processing);
        expect(stub.statusCalls, 1);

        // Second tick: success → stream closes.
        stub.statusResponse = {
          'status': 'success',
          'result': {
            'days': [
              {
                'date': '2026-07-31',
                'driving_minutes': 570,
                'working_minutes': 660,
                'rest_minutes': 480,
                'availability_minutes': 300,
              },
            ],
            'weekly_driving_minutes': 3456,
            'weekly_limit_minutes': 3360,
            'violations': ['Weekly driving limit exceeded'],
          },
        };
        async.elapse(const Duration(seconds: 3));
        expect(stub.statusCalls, 2);
        expect(states.last.status, TachoImportStatus.success);
        expect(states.last.result!.weeklyDrivingMinutes, 3456);
        expect(states.last.result!.violations.single,
            'Weekly driving limit exceeded');

        // No further ticks after terminal.
        async.elapse(const Duration(seconds: 9));
        expect(stub.statusCalls, 2);

        sub.close();
      });
    });

    test('terminates on error carrying the backend message', () {
      final stub = _TachoStub()
        ..statusResponse = {
          'status': 'error',
          'error': 'Parser binary not installed',
        };
      final container = ProviderContainer(
        overrides: [tachoEndpointsProvider.overrideWithValue(stub)],
      );
      addTearDown(container.dispose);

      fakeAsync((async) {
        TachoImportJobState? last;
        final sub = container.listen(
          tachoImportJobStatusProvider('42'),
          (_, next) => last = next.valueOrNull,
        );
        async.elapse(const Duration(seconds: 3));
        expect(last?.status, TachoImportStatus.error);
        expect(last?.error, 'Parser binary not installed');
        sub.close();
      });
    });
  });

  group('TachoComplianceResult', () {
    test('parses the backend result shape', () {
      final result = TachoComplianceResult.fromJson({
        'days': [
          {
            'date': '2026-07-31',
            'driving_minutes': 570,
            'working_minutes': 660,
            'rest_minutes': 480,
            'availability_minutes': 300,
          },
        ],
        'weekly_driving_minutes': 3456,
        'weekly_limit_minutes': 3360,
        'violations': ['Weekly driving limit exceeded'],
      });
      expect(result.days.single.date, '2026-07-31');
      expect(result.days.single.drivingMinutes, 570);
      expect(result.weeklyDrivingMinutes, 3456);
      expect(result.weeklyLimitMinutes, 3360);
      expect(result.violations.single, 'Weekly driving limit exceeded');
    });
  });
}

TachoComplianceResult _result() => const TachoComplianceResult(
      days: [],
      weeklyDrivingMinutes: 3456,
      weeklyLimitMinutes: 3360,
      violations: ['Weekly driving limit exceeded'],
    );
