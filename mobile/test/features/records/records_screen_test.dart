import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/global_search/screens/global_search_screen.dart';
import 'package:operion_mobile/features/history/screens/route_history_screen.dart';
import 'package:operion_mobile/features/history/screens/trip_history_screen.dart';
import 'package:operion_mobile/features/records/records_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

Widget _app({required User user}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      isOfflineProvider.overrideWith((ref) => false),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: RecordsScreen(),
    ),
  );
}

void main() {
  Future<void> pumpPhone(WidgetTester tester, User user) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(user: user));
    await tester.pumpAndSettle();
  }

  testWidgets('records grid shows the two new history tiles', (tester) async {
    await pumpPhone(tester, _adminUser);

    expect(find.text('Trip History'), findsOneWidget);
    expect(find.text('Route History'), findsOneWidget);
    expect(find.text('Fleet'), findsOneWidget);
  });

  testWidgets('tapping Trip History pushes TripHistoryScreen', (tester) async {
    await pumpPhone(tester, _adminUser);

    await tester.tap(find.text('Trip History'));
    await tester.pumpAndSettle();
    expect(find.byType(TripHistoryScreen), findsOneWidget);
  });

  testWidgets('tapping Route History pushes RouteHistoryScreen', (tester) async {
    await pumpPhone(tester, _adminUser);

    await tester.tap(find.text('Route History'));
    await tester.pumpAndSettle();
    expect(find.byType(RouteHistoryScreen), findsOneWidget);
  });

  testWidgets('search action opens GlobalSearchScreen', (tester) async {
    await pumpPhone(tester, _adminUser);

    await tester.tap(find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.search),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSearchScreen), findsOneWidget);
  });
}
