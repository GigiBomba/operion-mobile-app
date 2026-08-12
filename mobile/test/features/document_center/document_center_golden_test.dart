import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/document_center/providers/document_center_providers.dart';
import 'package:operion_mobile/features/document_center/screens/document_center_screen.dart';

List<Override> _overrides() => [
      companyDocumentsProvider(const DocumentListFilter()).overrideWith(
        (ref) async => [
          CompanyDocument.fromJson(const {
            'id': 1,
            'title': 'CMR 42',
            'category': 'cmr',
            'file_name': 'cmr-42.pdf',
            'uploaded_by': 'Admin',
            'uploaded_at': '2026-07-01T10:00:00',
          }),
          CompanyDocument.fromJson(const {
            'id': 2,
            'title': 'Invoice 2026-07',
            'category': 'invoice',
            'file_name': 'invoice-2026-07.pdf',
            'uploaded_by': 'Admin',
            'uploaded_at': '2026-07-02T11:00:00',
          }),
          CompanyDocument.fromJson(const {
            'id': 3,
            'title': 'ADR Certificate',
            'category': 'adr',
            'file_name': 'adr-certificate.pdf',
            'uploaded_by': 'Dispatch',
            'uploaded_at': '2026-06-15T09:00:00',
          }),
        ],
      ),
      documentCategoriesProvider.overrideWith((ref) async => [
            const DocumentCategory(category: 'cmr', count: 1),
            const DocumentCategory(category: 'invoice', count: 1),
            const DocumentCategory(category: 'adr', count: 1),
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
      home: const DocumentCenterScreen(),
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
  await expectLater(find.byType(Scaffold), matchesGoldenFile(file));
}

void main() {
  testWidgets('DocumentCenterScreen golden (light) — §2 search/categories',
      (tester) async {
    await _pumpGolden(tester, Brightness.light, 'document_center_light.png');
  });

  testWidgets('DocumentCenterScreen golden (dark) — §2 search/categories',
      (tester) async {
    await _pumpGolden(tester, Brightness.dark, 'document_center_dark.png');
  });
}
