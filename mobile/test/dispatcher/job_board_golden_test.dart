import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
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
import '../helpers/golden_fonts.dart';

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

class _StubDispatcherEndpoints extends DispatcherEndpoints {
  _StubDispatcherEndpoints() : super(_stubApiClient());

  @override
  Future<Response> updateTransportStatus(
      String transportId, String status) async {
    return Response(requestOptions: RequestOptions(path: ''), data: {});
  }
}

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

List<Map<String, dynamic>> _kanbanJobs() => [
      _job(id: 1, loadInfo: 'Steel beams to Constanta', status: 'planned'),
      _job(id: 2, loadInfo: 'Electronics to Cluj', status: 'loading'),
      _job(id: 3, loadInfo: 'Furniture to Iasi', status: 'in_transit'),
      _job(id: 4, loadInfo: 'Machinery to Arad', status: 'delivered'),
    ];

List<Map<String, dynamic>> _timelineJobs() => [
      _job(
        id: 1,
        loadInfo: 'Steel beams to Constanta',
        status: 'in_transit',
        startDate: '2026-07-10T06:00:00',
        endDate: '2026-07-12T18:00:00',
      ),
      _job(
        id: 2,
        loadInfo: 'Electronics to Cluj',
        status: 'loading',
        plate: 'B-02-XYZ',
        startDate: '2026-07-11T06:00:00',
        endDate: '2026-07-13T18:00:00',
      ),
      _job(id: 3, loadInfo: 'No-dates job', status: 'planned'),
    ];

List<Override> _overrides(List<Map<String, dynamic>> jobs) => [
      secureTokenStoreProvider.overrideWithValue(_MockSecureTokenStore()),
      biometricServiceProvider.overrideWithValue(_MockBiometricService()),
      apiClientProvider.overrideWithValue(_stubApiClient()),
      dispatcherEndpointsProvider.overrideWithValue(_StubDispatcherEndpoints()),
      dispatcherJobsProvider.overrideWith((ref) async => jobs),
      dispatcherJobsWithStatusesProvider.overrideWith((ref, statuses) async => jobs),
    ];

Widget _app(Brightness brightness, List<Map<String, dynamic>> jobs) {
  return ProviderScope(
    overrides: _overrides(jobs),
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const JobListScreen(),
    ),
  );
}

Future<void> _pumpGolden(
  WidgetTester tester,
  List<Map<String, dynamic>> jobs,
  String viewLabel,
  Brightness brightness,
  String file,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(brightness, jobs));
  await tester.pumpAndSettle();
  await tester.tap(find.text(viewLabel).last);
  await tester.pumpAndSettle();
  await expectLater(find.byType(Scaffold), matchesGoldenFile(file));
}

void main() {
  setUpAll(loadGoldenFonts);
  testWidgets('JobListScreen kanban golden (light)', (tester) async {
    await _pumpGolden(
      tester,
      _kanbanJobs(),
      'Kanban',
      Brightness.light,
      goldenFile('job_list_kanban_light'),
    );
  });

  testWidgets('JobListScreen kanban golden (dark)', (tester) async {
    await _pumpGolden(
      tester,
      _kanbanJobs(),
      'Kanban',
      Brightness.dark,
      goldenFile('job_list_kanban_dark'),
    );
  });

  testWidgets('JobListScreen timeline golden (light)', (tester) async {
    await _pumpGolden(
      tester,
      _timelineJobs(),
      'Timeline',
      Brightness.light,
      goldenFile('job_list_timeline_light'),
    );
  });

  testWidgets('JobListScreen timeline golden (dark)', (tester) async {
    await _pumpGolden(
      tester,
      _timelineJobs(),
      'Timeline',
      Brightness.dark,
      goldenFile('job_list_timeline_dark'),
    );
  });
}