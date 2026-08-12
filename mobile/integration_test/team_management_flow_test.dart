import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/team_management/providers/team_providers.dart';

import 'test_support.dart';

/// Stub [TeamEndpoints] with an in-memory member list that `invite` extends,
/// so the invite → list-update journey is observable.
class _StubTeamEndpoints extends TeamEndpoints {
  _StubTeamEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_access_token',
        ));

  final List<Map<String, dynamic>> members = [
    {
      'id': 1,
      'email': 'dispatcher@operion.ro',
      'display_name': 'Maria Dispatcher',
      'role': 'dispatcher',
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 2,
      'email': 'manager@operion.ro',
      'display_name': 'Test Manager',
      'role': 'manager',
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    },
  ];

  @override
  Future<Response> getMembers({
    int page = 1,
    int pageSize = 100,
    String? search,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'items': members,
        'total': members.length,
        'page': page,
        'page_size': pageSize,
        'total_pages': 1,
      },
    );
  }

  @override
  Future<Response> invite(
    String email,
    String role, {
    CancelToken? cancelToken,
  }) async {
    final id = members.length + 1;
    members.add({
      'id': id,
      'email': email,
      'display_name': email.split('@').first,
      'role': role,
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    });
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: members.last,
    );
  }
}

Future<List<Override>> _overrides() async {
  final db = await initTestLocalDatabase();
  return managerOverrides(
    db: db,
    user: managerUser,
    extra: [
      teamEndpointsProvider.overrideWith((ref) => _StubTeamEndpoints()),
    ],
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Team Management Flow', () {
    testWidgets(
      '1. Invite a member and see the list update',
      (tester) async {
        await pumpApp(tester, overrides: await _overrides());

        await openMoreTab(tester);
        await tapByText(tester, 'Team Management');

        // Existing members render.
        expect(find.text('Maria Dispatcher'), findsOneWidget);

        // Open the invite sheet via the FAB and fill in the email.
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(find.text('Invite a member'), findsOneWidget);
        await tester.enterText(
          find.byType(TextField).hitTestable().first,
          'new@operion.ro',
        );
        await tapByText(tester, 'Invite');

        // Success SnackBar appears.
        expect(find.text('Invitation sent'), findsOneWidget);

        // The invalidated list now includes the invited member.
        expect(
          find.text('new@operion.ro'),
          findsOneWidget,
          reason: 'After the invite the member list refreshes with the new '
              'user.',
        );
      },
    );
  });
}
