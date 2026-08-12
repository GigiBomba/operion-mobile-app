import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/teams/models/tacho.dart';
import 'package:operion_mobile/features/teams/providers/teams_providers.dart';
import 'package:operion_mobile/features/teams/screens/driver_detail_screen.dart';
import 'package:operion_mobile/features/teams/widgets/expiry_badge.dart';
import 'package:operion_mobile/shared/models/user.dart';

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

final DateTime _now = DateTime.now();

final DriverDetail _detail = DriverDetail(
  id: 1,
  name: 'Ana Popescu',
  phone: '+40 700 000 000',
  email: 'ana@example.com',
  licenseNumber: 'RO-123456',
  licenseCategory: 'CE',
  licenseExpiry: _now.add(const Duration(days: 400)),
  medicalExpiry: _now.add(const Duration(days: 10, hours: 1)),
  adrCertificateExpiry: _now.subtract(const Duration(days: 2)),
  currentTruckId: 'TR-101',
);

final TachoWeek _tachoWeek = TachoWeek(
  days: [
    for (var i = 0; i < 7; i++)
      TachoDay(
        date: DateTime(2026, 7, 20 + i),
        drivingMinutes: 480 - i * 20,
        workingMinutes: 120,
        restMinutes: 480,
        availabilityMinutes: 360,
      ),
  ],
  weeklyDrivingMinutes: 3400,
  weeklyLimitMinutes: 3360,
);

Widget _wrap() {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => _adminUser),
      driverDetailProvider.overrideWith(
        (ref, id) async => DriverDetailData(driver: _detail, fromCache: false),
      ),
      driverTachoProvider.overrideWith((ref, id) async => _tachoWeek),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: DriverDetailScreen(driver: _driverSummary),
    ),
  );
}

void main() {
  group('DriverDetailScreen — 4 tabs (blueprint §4.2)', () {
    testWidgets('renders Overview / Compliance / Tacho / Assignments tabs',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Compliance'), findsOneWidget);
      expect(find.text('Tacho'), findsOneWidget);
      expect(find.text('Assignments'), findsOneWidget);
    });

    testWidgets('compliance tab shows three ExpiryBadge rows + Renew',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Compliance'));
      await tester.pumpAndSettle();

      expect(find.byType(ExpiryBadge), findsNWidgets(3));
      expect(find.text('EXPIRED'), findsOneWidget); // ADR is past due
      expect(find.text('10 d'), findsOneWidget); // medical within 30 days
      expect(find.text('Renew'), findsNWidgets(3));
    });

    testWidgets('tacho tab renders 7-day bars + weekly gauge, red when over limit',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tacho'));
      await tester.pumpAndSettle();

      // 7 daily bars.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text('Over the weekly driving limit'),
        findsOneWidget,
      );
      expect(find.text('Weekly limit: 3360'), findsOneWidget);
      // 7 day cards; each shows the driving minutes twice (header + legend).
      expect(
        find.textContaining('Driving 480m'),
        findsNWidgets(2),
      );
    });

    testWidgets('assignments tab shows the current truck read-only',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assignments'));
      await tester.pumpAndSettle();

      expect(find.text('TR-101'), findsOneWidget);
    });
  });
}
