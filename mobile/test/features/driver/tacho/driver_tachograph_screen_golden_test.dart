import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/driver/tacho/providers/driver_tacho_providers.dart';
import 'package:operion_mobile/features/driver/tacho/screens/driver_tachograph_screen.dart';
import 'package:operion_mobile/features/teams/models/tacho.dart';

TachoWeek _week() => TachoWeek(
      weeklyDrivingMinutes: 2400,
      weeklyLimitMinutes: 3360,
      days: [
        TachoDay(
          date: DateTime(2026, 8, 10),
          drivingMinutes: 480,
          workingMinutes: 120,
          restMinutes: 240,
          availabilityMinutes: 600,
        ),
        TachoDay(
          date: DateTime(2026, 8, 11),
          drivingMinutes: 420,
          workingMinutes: 90,
          restMinutes: 300,
          availabilityMinutes: 630,
        ),
        TachoDay(
          date: DateTime(2026, 8, 12),
          drivingMinutes: 300,
          workingMinutes: 60,
          restMinutes: 480,
          availabilityMinutes: 600,
        ),
        TachoDay(
          date: DateTime(2026, 8, 13),
          drivingMinutes: 0,
          workingMinutes: 0,
          restMinutes: 720,
          availabilityMinutes: 720,
        ),
      ],
    );

Widget _app({required Brightness brightness}) {
  return ProviderScope(
    overrides: [
      driverTachoProvider.overrideWith((ref) async => _week()),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const DriverTachographScreen(),
    ),
  );
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Brightness brightness,
  String file,
) async {
  tester.view.physicalSize = const Size(460, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(brightness: brightness));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(Scaffold),
    matchesGoldenFile(file),
  );
}

void main() {
  testWidgets('DriverTachographScreen golden (light)', (tester) async {
    await _pumpGolden(tester, Brightness.light, 'driver_tachograph_light.png');
  });

  testWidgets('DriverTachographScreen golden (dark)', (tester) async {
    await _pumpGolden(tester, Brightness.dark, 'driver_tachograph_dark.png');
  });
}
