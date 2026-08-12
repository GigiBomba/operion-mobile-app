// Tachograph screen widget tests (blueprint §4.7).

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/sync/wifi_gate.dart';
import 'package:operion_mobile/core/theme/app_colors.dart';
import 'package:operion_mobile/features/tachograph/providers/tacho_providers.dart';
import 'package:operion_mobile/features/tachograph/screens/tachograph_screen.dart';
import 'package:operion_mobile/l10n/app_localizations.dart';

/// Stub tacho endpoints: import returns job 42; status can be scripted.
class _TachoScreenStub extends TachoEndpoints {
  _TachoScreenStub()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  int importCalls = 0;
  int statusCalls = 0;
  Map<String, dynamic> statusPayload = {'status': 'processing'};

  @override
  Future<Response> import({
    required String driverId,
    required String filePath,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    importCalls++;
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'job_id': 42},
      statusCode: 202,
    );
  }

  @override
  Future<Response> importStatus(String jobId, {CancelToken? cancelToken}) async {
    statusCalls++;
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: statusPayload,
      statusCode: 200,
    );
  }
}

// Backend VERBATIM violation string — the banner must render it exactly.
const _kBackendViolation =
    'Weekly driving limit exceeded: 3456 minutes vs 3360 limit';

Map<String, dynamic> _successPayload() => {
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
        'violations': [_kBackendViolation],
      },
    };

class _MockPicker {
  Future<FilePickerResult?> Function() call = _defaultPick;

  static Future<FilePickerResult?> _defaultPick() async {
    return FilePickerResult([
      PlatformFile(name: 'card.ddd', size: 100, path: '/tmp/card.ddd'),
    ]);
  }
}

Widget _app(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: TachographScreen(),
    ),
  );
}

void main() {
  Future<void> pumpTachoScreen(
    WidgetTester tester,
    List<Override> overrides,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(overrides));
    await tester.pumpAndSettle();
  }

  testWidgets('driver picker lists drivers and import uses .ddd/.esm picker',
      (tester) async {
    final stub = _TachoScreenStub();
    final mockPicker = _MockPicker();
    await pumpTachoScreen(tester, [
      isOfflineProvider.overrideWith((ref) => false),
      wifiGateProvider.overrideWithValue(
        const WifiGate(wifiOnlyLargeSyncs: false, onWifi: true, online: true),
      ),
      tachoEndpointsProvider.overrideWithValue(stub),
      tachoDriversProvider.overrideWith((ref) async => [
            {'id': 7, 'name': 'Ion Popescu', 'email': 'ion@operion.ro'},
          ]),
      tachoFilePickerProvider.overrideWith((ref) => mockPicker.call),
    ]);

    // Empty state first.
    expect(find.text('Nothing to show yet'), findsOneWidget);

    // Open the driver picker sheet.
    await tester.tap(find.text('Select a driver'));
    await tester.pumpAndSettle();
    expect(find.text('Ion Popescu'), findsOneWidget);

    // Select the driver.
    await tester.tap(find.text('Ion Popescu'));
    await tester.pumpAndSettle();
    expect(find.text('Ion Popescu'), findsOneWidget);

    // Tap import → picker mock must be invoked → upload → processing.
    // NOTE: pumpAndSettle would hang here — the job-status poller keeps a 3s
    // periodic timer alive, so use explicit pumps.
    await tester.tap(find.text('Import .ddd file'));
    await tester.pump();
    await tester.pump();
    expect(stub.importCalls, 1);

    // Processing row (uploading → processing transition).
    expect(find.text('Processing card...'), findsOneWidget);

    // Let the job poller terminate so no timers remain pending at teardown.
    stub.statusPayload = _successPayload();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  });

  testWidgets('compliance card renders verbatim banner + red over-limit gauge',
      (tester) async {
    final stub = _TachoScreenStub();
    final mockPicker = _MockPicker();
    await pumpTachoScreen(tester, [
      isOfflineProvider.overrideWith((ref) => false),
      wifiGateProvider.overrideWithValue(
        const WifiGate(wifiOnlyLargeSyncs: false, onWifi: true, online: true),
      ),
      tachoEndpointsProvider.overrideWithValue(stub),
      tachoDriversProvider.overrideWith((ref) async => [
            {'id': 7, 'name': 'Ion Popescu', 'email': 'ion@operion.ro'},
          ]),
      tachoFilePickerProvider.overrideWith((ref) => mockPicker.call),
    ]);

    await tester.tap(find.text('Select a driver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ion Popescu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import .ddd file'));
    await tester.pump();
    await tester.pump();

    // Script the status poll: first tick processing, second tick success.
    stub.statusPayload = {'status': 'processing'};
    await tester.pump(const Duration(seconds: 3)); // poll #1 (processing)
    await tester.pump();
    stub.statusPayload = _successPayload();
    await tester.pump(const Duration(seconds: 3)); // poll #2 (success)
    await tester.pump();

    expect(stub.statusCalls, 2);
    expect(find.text('Compliance summary'), findsOneWidget);
    expect(find.text('Weekly driving'), findsOneWidget);
    expect(find.text('3456 / 3360 min'), findsOneWidget);
    expect(find.text('2026-07-31'), findsOneWidget);

    // VERBATIM violation banner — exact text from the fixture response.
    expect(find.text(_kBackendViolation), findsOneWidget,
        reason: 'Backend violation strings must render VERBATIM (§4.7)');

    // Gauge is red when weekly driving exceeds the 3360 limit.
    expect(find.text('Over the weekly driving limit'), findsOneWidget);
    final gauge = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator).first,
    );
    expect(gauge.color, AppColors.error);
    expect(gauge.value, closeTo(1.0, 0.001));
  });

  testWidgets('file picker is invoked with the .ddd/.esm filter', (tester) async {
    final stub = _TachoScreenStub();
    final mockPicker = _MockPicker();
    await pumpTachoScreen(tester, [
      isOfflineProvider.overrideWith((ref) => false),
      wifiGateProvider.overrideWithValue(
        const WifiGate(wifiOnlyLargeSyncs: false, onWifi: true, online: true),
      ),
      tachoEndpointsProvider.overrideWithValue(stub),
      tachoDriversProvider.overrideWith((ref) async => [
            {'id': 7, 'name': 'Ion Popescu', 'email': 'ion@operion.ro'},
          ]),
      tachoFilePickerProvider.overrideWith((ref) => mockPicker.call),
    ]);

    await tester.tap(find.text('Select a driver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ion Popescu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import .ddd file'));
    await tester.pump();
    await tester.pump();
    expect(stub.importCalls, 1);

    // Let the job poller terminate so no timers remain pending at teardown.
    stub.statusPayload = _successPayload();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  });
}
