import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/records/records_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

void main() {
  Future<void> pumpTablet(WidgetTester tester, Brightness brightness) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => _adminUser),
        isOfflineProvider.overrideWith((ref) => false),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RecordsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile(
        brightness == Brightness.light
            ? 'records_tablet_light.png'
            : 'records_tablet_dark.png',
      ),
    );
  }

  testWidgets('Records tablet layout golden (light)', (tester) async {
    await pumpTablet(tester, Brightness.light);
  });

  testWidgets('Records tablet layout golden (dark)', (tester) async {
    await pumpTablet(tester, Brightness.dark);
  });
}
