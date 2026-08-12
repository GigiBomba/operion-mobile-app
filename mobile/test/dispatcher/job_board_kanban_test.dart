import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/auth/biometric_service.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/dispatcher_endpoints.dart';
import 'package:operion_mobile/core/storage/secure_token_store.dart';
import 'package:operion_mobile/features/dispatcher/home/dispatcher_providers.dart';
import 'package:operion_mobile/features/dispatcher/jobs/job_list_screen.dart';
import 'package:operion_mobile/features/dispatcher/jobs/job_providers.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockSecureTokenStore extends SecureTokenStore {
  @override
  Future<bool> hasTokens() async => false;
  @override
  Future<String?> getAccessToken() async => null;
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<void> saveTokens(String access, String refresh) async {}
  @override
  Future<void> clearTokens() async {}
}

class _MockBiometricService extends BiometricService {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<bool> authenticate({required String reason}) async => false;
}

ApiClient _stubApiClient() => ApiClient.create(
      baseUrl: '',
      apiKey: 'test-key',
      getAccessToken: () async => null,
    );

/// Records transport-status PATCHes.
class _RecordingDispatcherEndpoints extends DispatcherEndpoints {
  _RecordingDispatcherEndpoints() : super(_stubApiClient());

  final List<({String transportId, String status})> statusUpdates = [];

  @override
  Future<Response> updateTransportStatus(
      String transportId, String status) async {
    statusUpdates.add((transportId: transportId, status: status));
    return Response(requestOptions: RequestOptions(path: ''), data: {});
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Map<String, dynamic> _job({
  required int id,
  required String loadInfo,
  required String status,
  String plate = 'B-01-ABC',
  String? startDate,
  String? endDate,
}) =>
    {
      'id': id,
      'load_info': loadInfo,
      'origin': 'Bucharest',
      'destination': 'Constanta',
      'driver_name': 'Driver $id',
      'vehicle_plate': plate,
      'status': status,
      'last_updated': '2026-07-19T10:00:00',
      'start_date': ?startDate,
      'end_date': ?endDate,
    };

/// One job per column: planned / loading / in_transit / delivered.
List<Map<String, dynamic>> _kanbanJobs() => [
      _job(id: 1, loadInfo: 'Steel beams', status: 'planned'),
      _job(id: 2, loadInfo: 'Electronics', status: 'loading'),
      _job(id: 3, loadInfo: 'Furniture', status: 'in_transit'),
      _job(id: 4, loadInfo: 'Machinery', status: 'delivered'),
    ];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final List<Override> _baseOverrides = [
  secureTokenStoreProvider.overrideWithValue(_MockSecureTokenStore()),
  biometricServiceProvider.overrideWithValue(_MockBiometricService()),
  apiClientProvider.overrideWithValue(_stubApiClient()),
];

Widget _wrap({
  required List<Map<String, dynamic>> jobs,
  required List<String>? capturedStatuses,
  required _RecordingDispatcherEndpoints endpoints,
}) {
  return ProviderScope(
    overrides: [
      ..._baseOverrides,
      dispatcherEndpointsProvider.overrideWithValue(endpoints),
      dispatcherJobsProvider.overrideWith((ref) async => jobs),
      dispatcherJobsWithStatusesProvider.overrideWith((ref, statuses) async {
        capturedStatuses?.addAll(statuses);
        return jobs;
      }),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: JobListScreen(),
    ),
  );
}

Future<void> _switchToView(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// Simulates a long-press drag from [from] to [to] (LongPressDraggable).
Future<void> _longPressDrag(
  WidgetTester tester,
  Finder from,
  Finder to,
) async {
  final gesture = await tester.startGesture(tester.getCenter(from));
  // Long-press to arm the draggable.
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  // A small move starts the drag session.
  await gesture.moveBy(const Offset(20, 0));
  await tester.pump();
  // Move over the drop target, then release.
  await gesture.moveTo(tester.getCenter(to));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kanban view groups jobs into the four canonical columns',
      (tester) async {
    // ignore: deprecated_member_use
    tester.view.physicalSize = const Size(1600, 1000);
    // ignore: deprecated_member_use
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      // ignore: deprecated_member_use
      tester.view.resetPhysicalSize();
      // ignore: deprecated_member_use
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(
      jobs: _kanbanJobs(),
      capturedStatuses: null,
      endpoints: _RecordingDispatcherEndpoints(),
    ));
    await tester.pumpAndSettle();

    await _switchToView(tester, 'Kanban');

    // Column headers.
    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('In Transit'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);

    // Each job appears exactly once and its card is present.
    expect(find.text('Steel beams'), findsOneWidget);
    expect(find.text('Electronics'), findsOneWidget);
    expect(find.text('Furniture'), findsOneWidget);
    expect(find.text('Machinery'), findsOneWidget);
  });

  testWidgets('kanban view refetches with the statuses parameter',
      (tester) async {
    // ignore: deprecated_member_use
    tester.view.physicalSize = const Size(1600, 1000);
    // ignore: deprecated_member_use
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      // ignore: deprecated_member_use
      tester.view.resetPhysicalSize();
      // ignore: deprecated_member_use
      tester.view.resetDevicePixelRatio();
    });

    final captured = <String>[];
    await tester.pumpWidget(_wrap(
      jobs: _kanbanJobs(),
      capturedStatuses: captured,
      endpoints: _RecordingDispatcherEndpoints(),
    ));
    await tester.pumpAndSettle();

    await _switchToView(tester, 'Kanban');

    // The statuses param must include Delivered (replaces default exclusion).
    expect(captured, isNotEmpty);
    expect(captured, contains('Delivered'));
    expect(captured, contains('Planned'));
    expect(captured, contains('Loading'));
    expect(captured, contains('In Transit'));
  });

  testWidgets('drag-drop commits the PATCH only after the undo window, '
      'and Undo cancels it', (tester) async {
    // ignore: deprecated_member_use
    tester.view.physicalSize = const Size(1600, 1000);
    // ignore: deprecated_member_use
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      // ignore: deprecated_member_use
      tester.view.resetPhysicalSize();
      // ignore: deprecated_member_use
      tester.view.resetDevicePixelRatio();
    });

    final endpoints = _RecordingDispatcherEndpoints();
    await tester.pumpWidget(_wrap(
      jobs: _kanbanJobs(),
      capturedStatuses: null,
      endpoints: endpoints,
    ));
    await tester.pumpAndSettle();

    await _switchToView(tester, 'Kanban');

    // Drag "Steel beams" (Planned) onto the Delivered column's drop zone.
    await _longPressDrag(
      tester,
      find.text('Steel beams'),
      find.byKey(const ValueKey('kanban_drop_Delivered')),
    );

    // Confirmation snackbar with Undo is shown.
    expect(find.text('Undo'), findsOneWidget);
    expect(find.textContaining('Job moved'), findsOneWidget);

    // Inside the window: no API call yet.
    await tester.pump(const Duration(seconds: 2));
    expect(endpoints.statusUpdates, isEmpty);

    // Window elapses → PATCH fired with the target column status.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(endpoints.statusUpdates, hasLength(1));
    expect(endpoints.statusUpdates.first.status, 'Delivered');
    expect(endpoints.statusUpdates.first.transportId, '1');
  });

  testWidgets('undo restores the card and prevents the PATCH',
      (tester) async {
    // ignore: deprecated_member_use
    tester.view.physicalSize = const Size(1600, 1000);
    // ignore: deprecated_member_use
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      // ignore: deprecated_member_use
      tester.view.resetPhysicalSize();
      // ignore: deprecated_member_use
      tester.view.resetDevicePixelRatio();
    });

    final endpoints = _RecordingDispatcherEndpoints();
    await tester.pumpWidget(_wrap(
      jobs: _kanbanJobs(),
      capturedStatuses: null,
      endpoints: endpoints,
    ));
    await tester.pumpAndSettle();

    await _switchToView(tester, 'Kanban');

    await _longPressDrag(
      tester,
      find.text('Electronics'),
      find.byKey(const ValueKey('kanban_drop_Delivered')),
    );

    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    // No API call even after the full window.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(endpoints.statusUpdates, isEmpty);
  });

  testWidgets('timeline renders per-truck rows with date blocks',
      (tester) async {
    // ignore: deprecated_member_use
    tester.view.physicalSize = const Size(1200, 1200);
    // ignore: deprecated_member_use
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      // ignore: deprecated_member_use
      tester.view.resetPhysicalSize();
      // ignore: deprecated_member_use
      tester.view.resetDevicePixelRatio();
    });

    final jobs = [
      _job(
        id: 1,
        loadInfo: 'Steel beams',
        status: 'in_transit',
        plate: 'B-01-ABC',
        startDate: '2026-07-10T06:00:00',
        endDate: '2026-07-12T18:00:00',
      ),
      _job(
        id: 2,
        loadInfo: 'Electronics',
        status: 'loading',
        plate: 'B-01-ABC',
        startDate: '2026-07-13T06:00:00',
        endDate: '2026-07-14T18:00:00',
      ),
      // No dates → zero-width marker, still shown.
      _job(id: 3, loadInfo: 'No-dates job', status: 'planned', plate: 'B-01-ABC'),
      // No plate → unassigned row.
      _job(
        id: 4,
        loadInfo: 'Unassigned job',
        status: 'planned',
        plate: '',
        startDate: '2026-07-10T06:00:00',
        endDate: '2026-07-11T06:00:00',
      ),
    ];

    await tester.pumpWidget(_wrap(
      jobs: jobs,
      capturedStatuses: null,
      endpoints: _RecordingDispatcherEndpoints(),
    ));
    await tester.pumpAndSettle();

    await _switchToView(tester, 'Timeline');

    // Truck plate rows + unassigned fallback row.
    expect(find.text('B-01-ABC'), findsOneWidget);
    expect(find.text('Unassigned'), findsOneWidget);

    // Dated and undated jobs are all present in the timeline.
    expect(find.text('Steel beams'), findsOneWidget);
    expect(find.text('Electronics'), findsOneWidget);
    expect(find.text('Unassigned job'), findsOneWidget);
    // Undated jobs render as zero-width markers whose load info lives in the
    // marker tooltip (documented behaviour).
    expect(find.byTooltip('No-dates job'), findsOneWidget);
  });
}
