// ---------------------------------------------------------------------------
// document_list_screen_test.dart — B4
//
// Verifies the driver Documents screen now fetches real transport-scoped
// documents (instead of the old hardcoded `_mockDocuments`):
//   1. shows a shimmer while the entity documents provider is loading.
//   2. renders items returned by the provider.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/document_center/providers/document_center_providers.dart';
import 'package:operion_mobile/features/driver/documents/document_list_screen.dart';
import 'package:operion_mobile/shared/widgets/shimmer_loader.dart';

List<CompanyDocument> _docs() => [
      CompanyDocument.fromJson({
        'id': 1,
        'title': 'cmr',
        'category': 'cmr',
        'file_name': 'cmr_transport_1.pdf',
        'uploaded_by': 'driver',
        'uploaded_at': '2026-07-15T10:00:00',
      }),
      CompanyDocument.fromJson({
        'id': 2,
        'title': 'pod',
        'category': 'pod',
        'file_name': 'pod_signature.jpg',
        'uploaded_by': 'driver',
        'uploaded_at': '2026-07-16T09:00:00',
      }),
    ];

Widget _wrap({
  Future<List<CompanyDocument>> Function(Ref, EntityDocumentsRequest)?
      documents,
}) {
  return ProviderScope(
    overrides: [
      if (documents != null)
        entityDocumentsProvider.overrideWith(documents),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: DocumentListScreen(transportId: 't1'),
    ),
  );
}

void main() {
  group('DocumentListScreen (B4)', () {
    testWidgets('shows shimmer while documents are loading', (tester) async {
      final pending = Completer<List<CompanyDocument>>();
      await tester.pumpWidget(_wrap(
        documents: (ref, request) => pending.future,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ShimmerCard), findsWidgets);
    });

    testWidgets('renders items returned by the provider', (tester) async {
      await tester.pumpWidget(_wrap(
        documents: (ref, request) async => _docs(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('cmr_transport_1.pdf'), findsOneWidget);
      expect(find.text('pod_signature.jpg'), findsOneWidget);
    });
  });
}
