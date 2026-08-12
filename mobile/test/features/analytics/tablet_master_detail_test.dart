import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/analytics/screens/analytics_screen.dart';
import 'package:operion_mobile/features/clients/screens/client_list_screen.dart';
import 'package:operion_mobile/features/fleet/screens/fleet_list_screen.dart';
import 'package:operion_mobile/features/more_hub/screens/more_hub_screen.dart';
import 'package:operion_mobile/features/records/records_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';
import 'package:operion_mobile/shared/widgets/master_detail_layout.dart';

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

const _dispatcherUser = User(
  id: 'u1',
  email: 'disp@operion.ro',
  fullName: 'Disp',
  role: 'dispatcher',
  companyId: 'c1',
);

Widget _wrap(Widget child, {required User user}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      isOfflineProvider.overrideWith((ref) => false),
    ],
    child: MaterialApp(
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

Future<void> _pumpAtWidth(WidgetTester tester, Widget child, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(child);
  await tester.pumpAndSettle();
}

void main() {
  group('Tablet master-detail (§9)', () {
    testWidgets('Records at 800dp renders Row + list pane + detail pane',
        (tester) async {
      await _pumpAtWidth(tester, _wrap(const RecordsScreen(), user: _adminUser), 800);

      expect(find.byType(MasterDetailLayout), findsOneWidget);
      expect(find.byType(Row), findsWidgets);
      // List pane shows the grid; detail pane shows the first tile screen.
      expect(find.text('Fleet'), findsWidgets);
      expect(find.byType(FleetListScreen), findsOneWidget);
    });

    testWidgets('Records at 800dp selection swaps detail pane', (tester) async {
      await _pumpAtWidth(tester, _wrap(const RecordsScreen(), user: _adminUser), 800);

      // Tap the Clients tile in the list pane → detail pane shows clients.
      await tester.tap(find.text('Clients'));
      await tester.pumpAndSettle();
      expect(find.byType(ClientListScreen), findsOneWidget);
    });

    testWidgets('MoreHub at 800dp renders master-detail with Analytics',
        (tester) async {
      await _pumpAtWidth(tester, _wrap(const MoreHubScreen(), user: _adminUser), 800);

      expect(find.byType(MasterDetailLayout), findsOneWidget);

      // Selecting Analytics swaps the detail pane to the analytics screen.
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();
      expect(find.byType(AnalyticsScreen), findsOneWidget);
    });

    testWidgets('phone width keeps push-navigation (no master-detail)',
        (tester) async {
      await _pumpAtWidth(tester, _wrap(const RecordsScreen(), user: _adminUser), 390);

      expect(find.byType(MasterDetailLayout), findsNothing);
    });
  });

  group('Analytics tile gating (§8.2)', () {
    testWidgets('analytics tile ABSENT for dispatcher (no can_view_analytics)',
        (tester) async {
      await _pumpAtWidth(
          tester, _wrap(const MoreHubScreen(), user: _dispatcherUser), 390);

      expect(find.text('Analytics'), findsNothing);
      // Other tiles still render.
      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets('analytics tile PRESENT for admin', (tester) async {
      await _pumpAtWidth(
          tester, _wrap(const MoreHubScreen(), user: _adminUser), 390);

      expect(find.text('Analytics'), findsOneWidget);
    });
  });
}
