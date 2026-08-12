import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/global_search/providers/global_search_providers.dart';
import 'package:operion_mobile/features/global_search/screens/global_search_screen.dart';

/// Dark-mode golden gap-fill (blueprint §9 item 7): GlobalSearchScreen
/// previously had NO golden. Fixed per-type results with "N more" totals,
/// explicit Brightness, provider mocks — per the repo convention.
const _results = GlobalSearchResults(
  trips: SearchSection(items: [
    {'id': 1, 'name': 'Trip #1042 — București → Cluj'},
    {'id': 2, 'name': 'Trip #1015 — Brașov → Iași'},
  ], totalCount: 7),
  clients: SearchSection(items: [
    {'id': 'c1', 'name': 'ACME Logistics'},
    {'id': 'c2', 'name': 'Beta Trading'},
  ], totalCount: 5),
  drivers: SearchSection(items: [
    {'id': 'd1', 'name': 'Ion Popescu'},
  ], totalCount: 3),
  trucks: SearchSection(items: [
    {'id': 't1', 'name': 'B-100-ABC'},
    {'id': 't2', 'name': 'B-200-DEF'},
    {'id': 't3', 'name': 'B-300-GHI'},
  ], totalCount: 9),
  documents: SearchSection(items: [
    {'id': 11, 'title': 'CMR #8821.pdf'},
  ], totalCount: 2),
);

Widget _app({Brightness brightness = Brightness.light}) {
  return ProviderScope(
    overrides: [
      globalSearchQueryProvider.overrideWith((ref) => 'volvo'),
      globalSearchResultsProvider.overrideWith((ref, q) async => _results),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const GlobalSearchScreen(),
    ),
  );
}

void main() {
  testWidgets('GlobalSearchScreen golden (light)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('global_search_light.png'),
    );
  });

  testWidgets('GlobalSearchScreen golden (dark)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(brightness: Brightness.dark));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('global_search_dark.png'),
    );
  });
}
