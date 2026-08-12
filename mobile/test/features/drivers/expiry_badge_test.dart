import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/teams/widgets/expiry_badge.dart';

Widget _wrap(DateTime? expiry, {DateTime? now}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ExpiryBadge(expiry: expiry, now: now),
    ),
  );
}

void main() {
  final now = DateTime(2026, 7, 31, 12);

  group('ExpiryBadge thresholds (real 30-day window)', () {
    testWidgets('past expiry → red EXPIRED', (tester) async {
      await tester.pumpWidget(_wrap(now.subtract(const Duration(days: 1)), now: now));
      await tester.pumpAndSettle();
      expect(find.text('EXPIRED'), findsOneWidget);
    });

    testWidgets('within 30 days → amber N d', (tester) async {
      await tester.pumpWidget(_wrap(now.add(const Duration(days: 10)), now: now));
      await tester.pumpAndSettle();
      expect(find.text('10 d'), findsOneWidget);
    });

    testWidgets('exactly 30 days → amber 30 d', (tester) async {
      await tester.pumpWidget(_wrap(now.add(const Duration(days: 30)), now: now));
      await tester.pumpAndSettle();
      expect(find.text('30 d'), findsOneWidget);
    });

    testWidgets('beyond 30 days → green formatted date', (tester) async {
      await tester.pumpWidget(_wrap(now.add(const Duration(days: 400)), now: now));
      await tester.pumpAndSettle();
      expect(find.text('04/09/2027'), findsOneWidget);
    });

    testWidgets('null expiry renders nothing', (tester) async {
      await tester.pumpWidget(_wrap(null, now: now));
      await tester.pumpAndSettle();
      expect(find.byType(ExpiryBadge), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ExpiryBadge),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });
  });
}
