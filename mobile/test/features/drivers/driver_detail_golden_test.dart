import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/teams/models/tacho.dart';
import 'package:operion_mobile/features/teams/providers/teams_providers.dart';
import 'package:operion_mobile/features/teams/screens/driver_detail_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';
import '../../helpers/golden_fonts.dart';

/// Fixed reference date for the detail fixture so the golden's date text is
/// deterministic (regenerate when the fixtures age past this window).
final _goldenNow = DateTime(2026, 7, 31, 12);

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

const Map<String, dynamic> _driverSummary = {
  'id': 1,
  'name': 'Ana Popescu',
  'status': 'available',
  'current_transport': null,
  'current_vehicle': 'TR-101',
};

final DriverDetail _detail = DriverDetail(
  id: 1,
  name: 'Ana Popescu',
  phone: '+40 700 000 000',
  email: 'ana@example.com',
  licenseNumber: 'RO-123456',
  licenseCategory: 'CE',
  licenseExpiry: _goldenNow.add(const Duration(days: 400)),
  medicalExpiry: _goldenNow.add(const Duration(days: 10)),
  adrCertificateExpiry: _goldenNow.add(const Duration(days: 60)),
  currentTruckId: 'TR-101',
);

final TachoWeek _tachoWeek = TachoWeek(
  days: [
    for (var i = 0; i < 7; i++)
      TachoDay(
        date: DateTime(2026, 7, 20 + i),
        drivingMinutes: 420,
        workingMinutes: 120,
        restMinutes: 480,
        availabilityMinutes: 420,
      ),
  ],
  weeklyDrivingMinutes: 2940,
  weeklyLimitMinutes: 3360,
);

List<Override> _overrides() => [
      currentUserProvider.overrideWith((ref) => _adminUser),
      driverDetailProvider.overrideWith(
        (ref, id) async => DriverDetailData(driver: _detail, fromCache: false),
      ),
      driverTachoProvider.overrideWith((ref, id) async => _tachoWeek),
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
      home: const DriverDetailScreen(driver: _driverSummary),
    ),
  );
}

Future<void> _pumpGolden(
  WidgetTester tester,
  String file, {
  Brightness brightness = Brightness.light,
}) async {
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
  testWidgets('DriverDetailScreen golden (light)', (tester) async {
    await _pumpGolden(tester, 'driver_detail_light.png');
  });

  testWidgets('DriverDetailScreen golden (dark)', (tester) async {
    await _pumpGolden(
      tester,
      'driver_detail_dark.png',
      brightness: Brightness.dark,
    );
  });
}