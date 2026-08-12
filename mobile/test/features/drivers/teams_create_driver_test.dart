import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/drivers_endpoints.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/features/teams/providers/teams_providers.dart';
import 'package:operion_mobile/features/teams/screens/teams_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';

import '../../support/fake_local_database.dart';
import '../../support/test_helpers.dart';

const _dispatcherUser = User(
  id: 'u1',
  email: 'disp@operion.ro',
  fullName: 'Disp',
  role: 'dispatcher',
  companyId: 'c1',
);

const _managerUser = User(
  id: 'u3',
  email: 'manager@operion.ro',
  fullName: 'Manager',
  role: 'manager',
  companyId: 'c1',
);

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

/// Records createDriver calls and serves an empty drivers list.
class _RecordingDriversEndpoints extends DriversEndpoints {
  _RecordingDriversEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<Map<String, dynamic>> createCalls = [];

  @override
  Future<Response> getDrivers({
    String? search,
    String? status,
    int? expiringWithinDays,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/drivers'),
      data: {
        'items': <dynamic>[],
        'total': 0,
        'page': page,
        'page_size': pageSize,
        'total_pages': 0,
      },
      statusCode: 200,
    );
  }

  @override
  Future<Response> createDriver(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    createCalls.add(data);
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/drivers'),
      data: {'id': 'new-1', 'name': data['name']},
      statusCode: 201,
    );
  }
}

Widget _wrap(User user, _RecordingDriversEndpoints endpoints) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      isOfflineProvider.overrideWith((ref) => false),
      driversEndpointsProvider.overrideWithValue(endpoints),
      localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: TeamsScreen(),
    ),
  );
}

void main() {
  group('TeamsScreen — Add-driver FAB gating (§8.2)', () {
    testWidgets('FAB is ABSENT for dispatcher (no can_create_driver)',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_wrap(_dispatcherUser, _RecordingDriversEndpoints()));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('FAB is present for manager and admin', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_wrap(_managerUser, _RecordingDriversEndpoints()));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('TeamsScreen — create-driver flow', () {
    testWidgets('tapping the FAB opens CREATE mode and submits the mutation',
        (tester) async {
      usePhoneSurface(tester);
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final endpoints = _RecordingDriversEndpoints();
      await tester.pumpWidget(_wrap(_adminUser, endpoints));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // The edit sheet opens in CREATE mode: name field is empty.
      final nameField = find.byType(TextField).first;
      expect(nameField, findsOneWidget);
      expect(
        tester.widget<TextField>(nameField).controller?.text,
        isEmpty,
        reason: 'create mode starts with empty fields',
      );

      await tester.enterText(nameField, 'New Driver');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The mutation hit the NEW /mobile/drivers endpoint with the draft.
      expect(endpoints.createCalls, hasLength(1));
      expect(endpoints.createCalls.single['name'], 'New Driver');
    });
  });
}
