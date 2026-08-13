// Tachograph screen goldens (light + dark).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/sync/wifi_gate.dart';
import 'package:operion_mobile/features/tachograph/models/tacho_compliance.dart';
import 'package:operion_mobile/features/tachograph/providers/tacho_providers.dart';
import 'package:operion_mobile/features/tachograph/screens/tachograph_screen.dart';
import 'package:operion_mobile/l10n/app_localizations.dart';
import '../../helpers/golden_fonts.dart';

const _result = TachoComplianceResult(
  days: [
    TachoDay(
      date: '2026-07-25',
      drivingMinutes: 570,
      workingMinutes: 660,
      restMinutes: 480,
      availabilityMinutes: 300,
    ),
    TachoDay(
      date: '2026-07-26',
      drivingMinutes: 480,
      workingMinutes: 600,
      restMinutes: 540,
      availabilityMinutes: 360,
    ),
  ],
  weeklyDrivingMinutes: 3456,
  weeklyLimitMinutes: 3360,
  violations: [
    'Weekly driving limit exceeded: 3456 minutes vs 3360 limit',
    'Daily driving limit exceeded on 2026-07-25',
  ],
);

List<Override> _overrides() => [
      isOfflineProvider.overrideWith((ref) => false),
      wifiGateProvider.overrideWithValue(
        const WifiGate(wifiOnlyLargeSyncs: false, onWifi: true, online: true),
      ),
      tachoDriversProvider.overrideWith((ref) async => [
            {'id': 7, 'name': 'Ion Popescu', 'email': 'ion@operion.ro'},
          ]),
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
      home: const TachographScreen(),
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

  // Drive the notifier into the success/compliance state deterministically.
  final container = ProviderScope.containerOf(
    tester.element(find.byType(TachographScreen)),
  );
  container.read(tachoImportProvider.notifier).onJobSuccess(_result);
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(Scaffold),
    matchesGoldenFile(file),
  );
}

void main() {
  setUpAll(loadGoldenFonts);
  testWidgets('tachograph screen golden (light)', (tester) async {
    await _pumpGolden(tester, Brightness.light, 'tachograph_screen_light.png');
  });

  testWidgets('tachograph screen golden (dark)', (tester) async {
    await _pumpGolden(tester, Brightness.dark, 'tachograph_screen_dark.png');
  });
}