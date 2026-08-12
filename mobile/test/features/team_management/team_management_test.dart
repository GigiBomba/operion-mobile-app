// Team Management tests (blueprint §4.9).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/security/biometric_gate.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/features/team_management/models/team_member.dart';
import 'package:operion_mobile/features/team_management/providers/team_providers.dart';
import 'package:operion_mobile/features/invoicing/providers/invoicing_providers.dart'
    show BiometricRequired;
import 'package:operion_mobile/features/team_management/screens/team_management_screen.dart';
import 'package:operion_mobile/features/team_management/widgets/role_badge.dart';
import 'package:operion_mobile/l10n/app_localizations.dart';
import 'package:operion_mobile/shared/models/user.dart';

import '../../support/test_helpers.dart';

const _managerUser = User(
  id: 'm1',
  email: 'manager@operion.ro',
  fullName: 'Manager',
  role: 'manager',
  companyId: 'c1',
);

const _dispatcherUser = User(
  id: 'u1',
  email: 'dispatcher@operion.ro',
  fullName: 'Dispatcher',
  role: 'dispatcher',
  companyId: 'c1',
);

const _members = [
  TeamMember(
    id: 1,
    email: 'ana@operion.ro',
    displayName: 'Ana Admin',
    role: 'manager',
    isActive: true,
  ),
  TeamMember(
    id: 2,
    email: 'ion@operion.ro',
    displayName: 'Ion Driver',
    role: 'dispatcher',
    isActive: false,
  ),
];

class _RecordingTeamEndpoints extends TeamEndpoints {
  _RecordingTeamEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<String> invitedEmails = [];
  final List<String> invitedRoles = [];
  final List<(String, Map<String, dynamic>)> updates = [];

  @override
  Future<Response> invite(String email, String role, {CancelToken? cancelToken}) async {
    invitedEmails.add(email);
    invitedRoles.add(role);
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'id': 3},
      statusCode: 201,
    );
  }

  @override
  Future<Response> updateUser(
    String userId,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    updates.add((userId, data));
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'id': 1},
      statusCode: 200,
    );
  }
}

/// Minimal recording ActionQueue (to prove team mutations never enqueue).
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
    return 'fake-id';
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

List<Override> _overrides(
  _RecordingTeamEndpoints endpoints, {
  User user = _managerUser,
}) {
  return [
    isOfflineProvider.overrideWith((ref) => false),
    currentUserProvider.overrideWith((ref) => user),
    teamEndpointsProvider.overrideWithValue(endpoints),
    teamMembersProvider.overrideWith(
      (ref) async => const TeamListData(members: _members, fromCache: false),
    ),
    biometricGateProvider.overrideWithValue(
      BiometricGate(authenticate: (_) async => true),
    ),
  ];
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
      home: TeamManagementScreen(),
    ),
  );
}

void main() {
  testWidgets('renders members with RoleBadge + active/inactive status',
      (tester) async {
      usePhoneSurface(tester);
    final endpoints = _RecordingTeamEndpoints();
    await tester.pumpWidget(_app(_overrides(endpoints)));
    await tester.pumpAndSettle();

    expect(find.text('Ana Admin'), findsOneWidget);
    expect(find.text('Ion Driver'), findsOneWidget);
    expect(find.byType(RoleBadge), findsNWidgets(2));
    // Active + inactive statuses.
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
  });

  testWidgets('invite sheet role dropdown lacks the admin option', (tester) async {
      usePhoneSurface(tester);
    final endpoints = _RecordingTeamEndpoints();
    await tester.pumpWidget(_app(_overrides(endpoints)));
    await tester.pumpAndSettle();

    // Open the invite sheet via the FAB.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Invite a member'), findsOneWidget);

    // Open the role dropdown (the form field, not the RoleBadge text).
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    // dispatcher + manager are offered; admin is NOT.
    expect(find.text('dispatcher'), findsWidgets);
    expect(find.text('manager'), findsWidgets);
    expect(find.text('admin'), findsNothing,
        reason: 'The invite dropdown must never offer admin (§4.9)');
  });

  testWidgets('invite submits email + role via the mutation provider',
      (tester) async {
      usePhoneSurface(tester);
    final endpoints = _RecordingTeamEndpoints();
    await tester.pumpWidget(_app(_overrides(endpoints)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'new@operion.ro');
    await tester.tap(find.text('Invite').last);
    await tester.pumpAndSettle();

    expect(endpoints.invitedEmails.single, 'new@operion.ro');
    expect(endpoints.invitedRoles.single, 'dispatcher');
  });

  testWidgets('deactivate shows the §4.9 explicit wording and only calls the '
      'mutation after confirm', (tester) async {
      usePhoneSurface(tester);
    final endpoints = _RecordingTeamEndpoints();
    await tester.pumpWidget(_app(_overrides(endpoints)));
    await tester.pumpAndSettle();

    // Open the first row's popup menu.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();

    // §4.9 EXPLICIT revocation wording, with the member's display name.
    expect(find.text('Deactivate user'), findsOneWidget);
    expect(
      find.text("This will immediately revoke Ana Admin's mobile sessions "
          'and log them out of all devices'),
      findsOneWidget,
    );
    expect(endpoints.updates, isEmpty,
        reason: 'No mutation before the user confirms');

    // Cancel → no call.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(endpoints.updates, isEmpty);

    // Confirm → mutation fires with is_active=false.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate').last);
    await tester.pumpAndSettle();

    expect(endpoints.updates, hasLength(1));
    expect(endpoints.updates.single.$1, '1');
    expect(endpoints.updates.single.$2['is_active'], isFalse);
  });

  test('dispatcher cannot run team mutations (client-side gate)', () async {
    final endpoints = _RecordingTeamEndpoints();
    final container = ProviderContainer(
      overrides: [
        isOfflineProvider.overrideWith((ref) => false),
        currentUserProvider.overrideWith((ref) => _dispatcherUser),
        teamEndpointsProvider.overrideWithValue(endpoints),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(teamMutationProvider.notifier).invite(
            email: 'x@operion.ro',
            role: 'dispatcher',
          ),
      throwsA(isA<TeamNotPermitted>()),
    );
    expect(endpoints.invitedEmails, isEmpty);
  });

  group('deactivate — §12 biometric step-up', () {
    test('biometric FAILURE → BiometricRequired, endpoint NOT called',
        () async {
      final endpoints = _RecordingTeamEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => false),
          currentUserProvider.overrideWith((ref) => _managerUser),
          teamEndpointsProvider.overrideWithValue(endpoints),
          biometricGateProvider.overrideWithValue(
            BiometricGate(authenticate: (_) async => false),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(teamMutationProvider.notifier).deactivate(userId: '1'),
        throwsA(isA<BiometricRequired>()),
      );
      expect(endpoints.updates, isEmpty,
          reason: 'API must be unreachable without a successful biometric check');
    });

    test('biometric SUCCESS → proceeds and calls the endpoint DIRECTLY',
        () async {
      final endpoints = _RecordingTeamEndpoints();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => false),
          currentUserProvider.overrideWith((ref) => _managerUser),
          teamEndpointsProvider.overrideWithValue(endpoints),
          biometricGateProvider.overrideWithValue(
            BiometricGate(authenticate: (_) async => true),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(teamMutationProvider.notifier)
          .deactivate(userId: '1');

      expect(endpoints.updates, hasLength(1));
      expect(endpoints.updates.single.$1, '1');
      expect(endpoints.updates.single.$2['is_active'], isFalse);
    });
  });

  group('team mutations — §7 blocked offline (never queued)', () {
    test('invite / role change / deactivate offline → TeamRequiresConnection, '
        'queue empty, endpoint never called', () async {
      final endpoints = _RecordingTeamEndpoints();
      final queue = _RecordingActionQueue();
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => true),
          currentUserProvider.overrideWith((ref) => _managerUser),
          teamEndpointsProvider.overrideWithValue(endpoints),
          actionQueueProvider.overrideWithValue(queue),
          biometricGateProvider.overrideWithValue(
            BiometricGate(authenticate: (_) async => true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(teamMutationProvider.notifier);

      await expectLater(
        notifier.invite(email: 'x@operion.ro', role: 'dispatcher'),
        throwsA(isA<TeamRequiresConnection>()),
      );
      await expectLater(
        notifier.updateRole(userId: '1', role: 'manager'),
        throwsA(isA<TeamRequiresConnection>()),
      );
      await expectLater(
        notifier.deactivate(userId: '1'),
        throwsA(isA<TeamRequiresConnection>()),
      );

      expect(queue.enqueued, isEmpty,
          reason: 'team mutations must never be queued offline (§7)');
      expect(endpoints.invitedEmails, isEmpty);
      expect(endpoints.updates, isEmpty);
    });
  });
}
