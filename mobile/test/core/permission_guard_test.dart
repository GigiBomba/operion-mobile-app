// Incremental RBAC gate test (§13.4) for Phase 1B.
//
// Walks `test/test_vectors/permission_matrix.json` (backend-generated) and
// asserts that `buildIfPermitted` renders the gated widget for every role
// where the matrix says the permission is allowed, and ABSENT for roles where
// it is denied. This covers this phase's gated actions: fleet FAB/edit/
// decommission, driver edit, client FAB/edit/merge.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/auth/permission_guard.dart';
import 'package:operion_mobile/core/auth/user_role.dart';
import 'package:operion_mobile/shared/models/user.dart';

const _fixturePath = 'test/test_vectors/permission_matrix.json';

const _gatedKey = ValueKey<String>('gated-content');

/// Renders [buildIfPermitted] for the given permission.
class _GateHarness extends ConsumerWidget {
  const _GateHarness({required this.permission});

  final Permission permission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return buildIfPermitted(
      ref,
      permission,
      () => const SizedBox(key: _gatedKey, width: 1, height: 1),
    );
  }
}

void main() {
  final fixture = jsonDecode(
    File(_fixturePath).readAsStringSync(),
  ) as List<dynamic>;

  // Role → allowed permission set, resolved through userRoleFromString so
  // legacy role aliases ('fleet_manager', 'owner') collapse to the canonical
  // enum values.
  final allowedByRole = <UserRole, Set<String>>{
    for (final role in UserRole.values) role: <String>{},
  };
  for (final raw in fixture) {
    final entry = raw as Map<String, dynamic>;
    final role = userRoleFromString(entry['role'] as String);
    if (entry['expected_allowed'] as bool == true) {
      allowedByRole[role]!.add(entry['permission'] as String);
    }
  }

  Widget buildRole(UserRole role, Permission permission) {
    return ProviderScope(
      overrides: [
        currentUserProvider.overrideWith(
          (ref) => User(
            id: 'u',
            email: 'u@operion.ro',
            fullName: 'U',
            role: role.name,
            companyId: 'c1',
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(body: _GateHarness(permission: permission)),
      ),
    );
  }

  for (final role in UserRole.values) {
    testWidgets(
      '${role.name}: every gate renders iff the matrix allows it '
      '(${allowedByRole[role]!.length} allowed)', (tester) async {
      for (final permission in Permissions.all) {
        final allowed = allowedByRole[role]!.contains(permission);

        await tester.pumpWidget(buildRole(role, permission));
        await tester.pump();

        expect(
          find.byKey(_gatedKey),
          allowed ? findsOneWidget : findsNothing,
          reason: '${role.name} / $permission — matrix allowed=$allowed',
        );
      }
    });
  }

  group('Phase 1B gates sanity', () {
    test('merge is admin-only (REAL matrix beats §8.3)', () {
      expect(
        allowedByRole[UserRole.admin],
        contains(Permissions.mergeClients),
      );
      for (final role in [
        UserRole.driver,
        UserRole.dispatcher,
        UserRole.manager,
      ]) {
        expect(
          allowedByRole[role],
          isNot(contains(Permissions.mergeClients)),
          reason: 'can_merge_clients must be admin-only (real matrix)',
        );
      }
    });

    test('fleet create/edit denied for driver & dispatcher, allowed manager+; '
        'delete is admin-only (real matrix)', () {
      for (final permission in [
        Permissions.createVehicle,
        Permissions.updateVehicle,
      ]) {
        expect(allowedByRole[UserRole.driver], isNot(contains(permission)));
        expect(allowedByRole[UserRole.dispatcher], isNot(contains(permission)));
        expect(allowedByRole[UserRole.manager], contains(permission));
        expect(allowedByRole[UserRole.admin], contains(permission));
      }
      // can_delete_vehicle: admin only.
      expect(
        allowedByRole[UserRole.driver],
        isNot(contains(Permissions.deleteVehicle)),
      );
      expect(
        allowedByRole[UserRole.dispatcher],
        isNot(contains(Permissions.deleteVehicle)),
      );
      expect(
        allowedByRole[UserRole.manager],
        isNot(contains(Permissions.deleteVehicle)),
      );
      expect(allowedByRole[UserRole.admin], contains(Permissions.deleteVehicle));
    });

    test('client create/edit denied for driver & dispatcher, allowed manager+',
        () {
      for (final permission in [
        Permissions.createClient,
        Permissions.updateClient,
      ]) {
        expect(allowedByRole[UserRole.driver], isNot(contains(permission)));
        expect(allowedByRole[UserRole.dispatcher], isNot(contains(permission)));
        expect(allowedByRole[UserRole.manager], contains(permission));
        expect(allowedByRole[UserRole.admin], contains(permission));
      }
    });

    test('driver edit denied for driver & dispatcher, allowed manager+', () {
      expect(allowedByRole[UserRole.driver], isNot(contains(Permissions.updateDriver)));
      expect(allowedByRole[UserRole.dispatcher], isNot(contains(Permissions.updateDriver)));
      expect(allowedByRole[UserRole.manager], contains(Permissions.updateDriver));
      expect(allowedByRole[UserRole.admin], contains(Permissions.updateDriver));
    });
  });
}
