// Team Management screen goldens (light + dark).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/features/team_management/models/team_member.dart';
import 'package:operion_mobile/features/team_management/providers/team_providers.dart';
import 'package:operion_mobile/features/team_management/screens/team_management_screen.dart';
import 'package:operion_mobile/l10n/app_localizations.dart';
import 'package:operion_mobile/shared/models/user.dart';

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

List<Override> _overrides() => [
      isOfflineProvider.overrideWith((ref) => false),
      currentUserProvider.overrideWith((ref) => _adminUser),
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
            TeamMember(
              id: 2,
              email: 'ion@operion.ro',
              displayName: 'Ion Driver',
              role: 'dispatcher',
              isActive: true,
            ),
            TeamMember(
              id: 3,
              email: 'gheorghe@operion.ro',
              displayName: 'Gheorghe Sofer',
              role: 'driver',
              isActive: false,
            ),
          ],
          fromCache: false,
        ),
      ),
    ];

Widget _app(Brightness brightness) {
  return ProviderScope(
    overrides: _overrides(),
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TeamManagementScreen(),
    ),
  );
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Brightness brightness,
  String file,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(brightness));
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(Scaffold),
    matchesGoldenFile(file),
  );
}

void main() {
  testWidgets('team management screen golden (light)', (tester) async {
    await _pumpGolden(tester, Brightness.light, 'team_management_screen_light.png');
  });

  testWidgets('team management screen golden (dark)', (tester) async {
    await _pumpGolden(tester, Brightness.dark, 'team_management_screen_dark.png');
  });
}
