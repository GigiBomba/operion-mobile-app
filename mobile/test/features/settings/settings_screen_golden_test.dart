// Settings screen goldens (light + dark) â€” manager view with all 7 sections.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/features/settings/providers/settings_endpoints.dart';
import 'package:operion_mobile/features/settings/settings_screen.dart';
import 'package:operion_mobile/l10n/app_localizations.dart';
import 'package:operion_mobile/shared/models/user.dart';
import '../../helpers/golden_fonts.dart';

const _managerUser = User(
  id: 'm1',
  email: 'manager@operion.ro',
  fullName: 'Manager',
  role: 'manager',
  companyId: 'c1',
);

const _companySettings = CompanySettings(
  legalName: 'Operion SRL',
  vatNumber: 'RO123456',
  address: 'Str. Exemplu 1',
  invoiceFooter: 'Multumim!',
  smtpServer: 'smtp.operion.ro',
  smtpPort: '587',
  smtpUser: 'noreply@operion.ro',
  smtpPasswordIsSet: true,
  trackingProvider: 'wialon',
  trackingApiKeyIsSet: true,
);

List<Override> _overrides() => [
      isOfflineProvider.overrideWith((ref) => false),
      currentUserProvider.overrideWith((ref) => _managerUser),
      companySettingsProvider.overrideWith((ref) async => _companySettings),
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
      home: const SettingsScreen(),
    ),
  );
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Brightness brightness,
  String file,
) async {
  SharedPreferences.setMockInitialValues({});
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
  setUpAll(loadGoldenFonts);
  testWidgets('settings screen golden (light)', (tester) async {
    await _pumpGolden(tester, Brightness.light, 'settings_screen_light.png');
  });

  testWidgets('settings screen golden (dark)', (tester) async {
    await _pumpGolden(tester, Brightness.dark, 'settings_screen_dark.png');
  });
}