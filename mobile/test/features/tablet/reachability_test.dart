import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/fleet/models/truck.dart';
import 'package:operion_mobile/features/fleet/providers/fleet_providers.dart';
import 'package:operion_mobile/features/fleet/screens/truck_detail_screen.dart';
import 'package:operion_mobile/features/team_management/models/team_member.dart';
import 'package:operion_mobile/features/team_management/providers/team_providers.dart';
import 'package:operion_mobile/features/team_management/screens/team_management_screen.dart';
import 'package:operion_mobile/features/teams/models/tacho.dart';
import 'package:operion_mobile/features/teams/providers/teams_providers.dart';
import 'package:operion_mobile/features/teams/screens/driver_detail_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';

import '../../support/test_helpers.dart';

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

const _driverSummary = {
  'id': 1,
  'name': 'Ana Popescu',
  'status': 'available',
  'current_vehicle': 'TR-101',
};

final _truck = Truck.fromJson({
  'id': 't1',
  'company_id': 'c1',
  'plate': 'B-100-ABC',
  'brand': 'Volvo',
  'model': 'FH16',
  'status': 'Active',
  'health_score': 90.0,
});

final DriverDetail _detail = DriverDetail(
  id: 1,
  name: 'Ana Popescu',
  phone: '+40 700 000 000',
  email: 'ana@example.com',
  licenseNumber: 'RO-123456',
  licenseCategory: 'CE',
  licenseExpiry: DateTime(2027, 7, 31),
  medicalExpiry: DateTime(2027, 7, 31),
  adrCertificateExpiry: DateTime(2027, 7, 31),
  currentTruckId: 'TR-101',
);

Widget _app(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  // Reachability audit (blueprint §9 item 6): the PRIMARY action must sit in
  // the bottom two-thirds (FAB / bottom button), not the AppBar top.
  group('One-handed reachability audit (§9 item 6)', () {
    testWidgets('truck_detail: Edit is FAB-only, Decommission stays in overflow',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _app(
          const TruckDetailScreen(truckId: 't1'),
          [
            currentUserProvider.overrideWith((ref) => _adminUser),
            truckDetailProvider.overrideWith(
              (ref, id) async =>
                  TruckDetailData(truck: _truck, fromCache: false),
            ),
            truckMaintenanceHistoryProvider.overrideWith((ref, id) async => []),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Primary Edit action lives on the FAB (bottom two-thirds).
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.child, isA<Icon>());
      expect((fab.child! as Icon).icon, Icons.edit_outlined);
      // No edit IconButton in the AppBar anymore.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.edit_outlined),
        ),
        findsNothing,
      );
      // Destructive Decommission stays in the AppBar overflow menu.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
        findsOneWidget,
      );
    });

    testWidgets('driver_detail: Edit is FAB-only (no AppBar icon)',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _app(
          const DriverDetailScreen(driver: _driverSummary),
          [
            currentUserProvider.overrideWith((ref) => _adminUser),
            driverDetailProvider.overrideWith(
              (ref, id) async =>
                  DriverDetailData(driver: _detail, fromCache: false),
            ),
            driverTachoProvider.overrideWith(
              (ref, id) async => const TachoWeek(
                days: [],
                weeklyDrivingMinutes: 0,
                weeklyLimitMinutes: 3360,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect((fab.child! as Icon).icon, Icons.edit_outlined);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.edit_outlined),
        ),
        findsNothing,
      );
    });

    testWidgets('team_management: invite is FAB-only and gated', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _app(
          const TeamManagementScreen(),
          [
            currentUserProvider.overrideWith((ref) => _adminUser),
            teamCachedBannerProvider.overrideWith((ref) => false),
            teamMembersProvider.overrideWith(
              (ref) async => const TeamListData(
                members: [
                  TeamMember(
                    id: 1,
                    email: 'ana@operion.ro',
                    displayName: 'Ana Admin',
                    role: 'manager',
                    isActive: true,
                  ),
                ],
                fromCache: false,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The invite FAB is present (admin has can_manage_users).
      expect(find.byType(FloatingActionButton), findsOneWidget);
      // The redundant AppBar invite icon is GONE (FAB-only).
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(LucideIcons.userPlus),
        ),
        findsNothing,
      );
      expect(find.byIcon(LucideIcons.userPlus), findsOneWidget);
    });

    testWidgets('team_management: invite FAB is ABSENT for dispatcher',
        (tester) async {
      usePhoneSurface(tester);
      const dispatcher = User(
        id: 'u1',
        email: 'disp@operion.ro',
        fullName: 'Disp',
        role: 'dispatcher',
        companyId: 'c1',
      );
      await tester.pumpWidget(
        _app(
          const TeamManagementScreen(),
          [
            currentUserProvider.overrideWith((ref) => dispatcher),
            teamCachedBannerProvider.overrideWith((ref) => false),
            teamMembersProvider.overrideWith(
              (ref) async => const TeamListData(
                members: [
                  TeamMember(
                    id: 1,
                    email: 'ana@operion.ro',
                    displayName: 'Ana Admin',
                    role: 'manager',
                    isActive: true,
                  ),
                ],
                fromCache: false,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // No invite affordance at all for dispatcher (§8.2).
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(LucideIcons.userPlus), findsNothing);
    });
  });
}
