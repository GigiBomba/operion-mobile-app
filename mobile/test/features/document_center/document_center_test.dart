import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/document_center/providers/document_center_providers.dart';
import 'package:operion_mobile/features/document_center/screens/document_center_screen.dart';

/// Fake OCR endpoints returning a `queued` acknowledgement.
class _FakeOcrEndpoints extends OcrEndpoints {
  _FakeOcrEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  bool throwError = false;
  int processCount = 0;

  @override
  Future<Response> processImage({
    required String imagePath,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    processCount++;
    if (throwError) {
      throw DioException(requestOptions: RequestOptions(path: '/api/v1/ocr/process'));
    }
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/ocr/process'),
      data: {
        'document_id': 'doc-ocr-1',
        'status': 'queued',
        'idempotency_key': idempotencyKey,
      },
      statusCode: 200,
    );
  }
}

Widget wrapDocumentCenter(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: DocumentCenterScreen(),
    ),
  );
}

ProviderContainer _containerWith(
  _FakeOcrEndpoints endpoints, {
  List<Map<String, dynamic>>? documents,
}) {
  return ProviderContainer(
    overrides: [
      ocrEndpointsProvider.overrideWithValue(endpoints),
      // Camera picker stub: returns a fake path without any platform channel.
      ocrImagePickProvider.overrideWithValue(() async => '/fake/capture.jpg'),
      // Documents tab fixture (empty by default — the existing placeholder
      // empty-state behaviour). The provider is a family keyed by
      // [DocumentListFilter]; the default (empty) filter is overridden.
      companyDocumentsProvider(const DocumentListFilter()).overrideWith(
          (ref) async =>
              documents?.map(CompanyDocument.fromJson).toList() ??
              <CompanyDocument>[]),
      documentCategoriesProvider
          .overrideWith((ref) async => <DocumentCategory>[]),
    ],
  );
}

void main() {
  // ==========================================================================
  // Initial state — tab bar rendering
  // ==========================================================================
  group('DocumentCenterScreen — initial state', () {
    testWidgets('renders app bar with title', (tester) async {
      final container = _containerWith(_FakeOcrEndpoints());
      addTearDown(container.dispose);
      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      expect(find.text('Document Center'), findsOneWidget);
    });

    testWidgets('renders two tabs: Documents and Automation', (tester) async {
      final container = _containerWith(_FakeOcrEndpoints());
      addTearDown(container.dispose);
      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      // Tab labels appear — both Documents tab label and the empty-state title
      // use the same key so findsAtLeast is safe
      expect(find.text('Documents'), findsAtLeastNWidgets(1));
      expect(find.text('Automation'), findsOneWidget);
    });

    testWidgets('shows folder open icon on Documents tab', (tester) async {
      final container = _containerWith(_FakeOcrEndpoints());
      addTearDown(container.dispose);
      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.folderOpen), findsOneWidget);
    });

    testWidgets('shows camera icon on Automation tab', (tester) async {
      final container = _containerWith(_FakeOcrEndpoints());
      addTearDown(container.dispose);
      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.camera), findsOneWidget);
    });
  });

  // ==========================================================================
  // Documents tab (default, first tab)
  // ==========================================================================
  group('DocumentCenterScreen — Documents tab', () {
    testWidgets('shows file text icon in documents tab', (tester) async {
      final container = _containerWith(_FakeOcrEndpoints());
      addTearDown(container.dispose);
      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      // fileText icon appears as the empty-state icon when no documents
      expect(find.byIcon(LucideIcons.fileText), findsOneWidget);
    });

    testWidgets('renders company documents with pull-to-refresh',
        (tester) async {
      final container = _containerWith(
        _FakeOcrEndpoints(),
        documents: [
          {
            'id': 1,
            'title': 'CMR 42',
            'category': 'cmr',
            'file_name': 'cmr-42.pdf',
            'file_size': 1024,
            'mime_type': 'application/pdf',
            'uploaded_by': 'Admin',
            'uploaded_at': '2026-07-01T10:00:00',
          },
          {
            'id': 2,
            'title': 'Invoice 2026-07',
            'category': 'invoice',
            'file_name': 'invoice-2026-07.pdf',
            'file_size': 2048,
            'mime_type': 'application/pdf',
            'uploaded_by': 'Admin',
            'uploaded_at': '2026-07-02T11:00:00',
          },
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      // Both documents render; the tab is pull-to-refreshable.
      expect(find.text('cmr-42.pdf'), findsOneWidget);
      expect(find.text('invoice-2026-07.pdf'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('refresh re-invokes the documents provider', (tester) async {
      var fetchCount = 0;
      final container = ProviderContainer(
        overrides: [
          ocrEndpointsProvider.overrideWithValue(_FakeOcrEndpoints()),
          ocrImagePickProvider.overrideWithValue(() async => '/fake.jpg'),
          companyDocumentsProvider(const DocumentListFilter())
              .overrideWith((ref) async {
            fetchCount++;
            return <CompanyDocument>[];
          }),
          documentCategoriesProvider
              .overrideWith((ref) async => <DocumentCategory>[]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();
      expect(fetchCount, 1);

      await tester.fling(
        find.byKey(const ValueKey('documents_list_empty')),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();
      expect(fetchCount, greaterThanOrEqualTo(2));
    });
  });

  // ==========================================================================
  // Automation tab
  // ==========================================================================
  group('DocumentCenterScreen — Automation tab', () {
    testWidgets('switching to Automation tab shows OCR content',
        (tester) async {
      final container = _containerWith(_FakeOcrEndpoints());
      addTearDown(container.dispose);
      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Automation'));
      await tester.pumpAndSettle();

      expect(find.text('OCR Document Capture'), findsOneWidget);
      expect(
        find.text('Capture a document photo to automatically extract fields.'),
        findsOneWidget,
      );
    });

    testWidgets('shows Capture Photo button on Automation tab',
        (tester) async {
      final container = _containerWith(_FakeOcrEndpoints());
      addTearDown(container.dispose);
      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Automation'));
      await tester.pumpAndSettle();

      expect(find.text('Capture Photo'), findsOneWidget);
    });

    testWidgets('capturing a photo posts to the OCR endpoint and shows the '
        'confirmed processing state', (tester) async {
      final endpoints = _FakeOcrEndpoints();
      final container = _containerWith(endpoints);
      addTearDown(container.dispose);

      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Automation'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Capture Photo'));
      await tester.pumpAndSettle();

      // The upload hit the mocked OCR endpoint exactly once.
      expect(endpoints.processCount, 1);
      // "Upload confirmed, processing..." — the flow stops here, no results.
      expect(find.text('Upload confirmed, processing...'), findsOneWidget);
      expect(
        find.text('The document is processed in the cloud. '
            'Results will appear under Local Download.'),
        findsOneWidget,
      );
    });

    testWidgets('failed upload shows the localized error state',
        (tester) async {
      final endpoints = _FakeOcrEndpoints()..throwError = true;
      final container = _containerWith(endpoints);
      addTearDown(container.dispose);

      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Automation'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Capture Photo'));
      await tester.pumpAndSettle();

      expect(find.text('Upload failed. Please try again.'), findsOneWidget);
    });
  });

  // ==========================================================================
  // Tab switching
  // ==========================================================================
  group('DocumentCenterScreen — tab switching', () {
    testWidgets('switching back to Documents tab shows file icon',
        (tester) async {
      final container = _containerWith(_FakeOcrEndpoints());
      addTearDown(container.dispose);
      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      // Go to Automation
      await tester.tap(find.text('Automation'));
      await tester.pumpAndSettle();

      // Switch back to Documents
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.fileText), findsOneWidget);
    });
  });

  // ==========================================================================
  // §2 Feature-parity — search, category chips, version browsing
  // ==========================================================================
  group('DocumentCenterScreen — §2 parity (search + categories + versions)',
      () {
    testWidgets('renders the document search field', (tester) async {
      final container = _containerWith(_FakeOcrEndpoints());
      addTearDown(container.dispose);
      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      expect(find.text('Search documents...'), findsOneWidget);
    });

    testWidgets('typing searches with a debounce and forwards the query param',
        (tester) async {
      final capturedFilters = <DocumentListFilter>[];
      final container = ProviderContainer(
        overrides: [
          ocrEndpointsProvider.overrideWithValue(_FakeOcrEndpoints()),
          ocrImagePickProvider.overrideWithValue(() async => '/fake.jpg'),
          companyDocumentsProvider.overrideWith((ref, filter) async {
            capturedFilters.add(filter);
            return <CompanyDocument>[];
          }),
          documentCategoriesProvider
              .overrideWith((ref) async => <DocumentCategory>[]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'CMR invoice');
      await tester.pump(const Duration(milliseconds: 100));
      // Before the 400ms debounce elapses no re-fetch has happened with query.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(
        capturedFilters.any((f) => f.query == 'CMR invoice'),
        isTrue,
      );
    });

    testWidgets('renders category chips from the API with All first',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          ocrEndpointsProvider.overrideWithValue(_FakeOcrEndpoints()),
          ocrImagePickProvider.overrideWithValue(() async => '/fake.jpg'),
          companyDocumentsProvider(const DocumentListFilter())
              .overrideWith((ref) async => <CompanyDocument>[]),
          documentCategoriesProvider.overrideWith((ref) async => [
                const DocumentCategory(category: 'invoice', count: 2),
                const DocumentCategory(category: 'cmr', count: 1),
              ]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('invoice (2)'), findsOneWidget);
      expect(find.text('cmr (1)'), findsOneWidget);
    });

    testWidgets('tapping a category chip filters the list', (tester) async {
      final capturedFilters = <DocumentListFilter>[];
      final container = ProviderContainer(
        overrides: [
          ocrEndpointsProvider.overrideWithValue(_FakeOcrEndpoints()),
          ocrImagePickProvider.overrideWithValue(() async => '/fake.jpg'),
          companyDocumentsProvider.overrideWith((ref, filter) async {
            capturedFilters.add(filter);
            return <CompanyDocument>[];
          }),
          documentCategoriesProvider.overrideWith((ref) async => [
                const DocumentCategory(category: 'invoice', count: 2),
              ]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('invoice (2)'));
      await tester.pumpAndSettle();

      expect(
        capturedFilters.any((f) => f.category == 'invoice'),
        isTrue,
      );
    });

    testWidgets('tapping a document opens the version-history sheet',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          ocrEndpointsProvider.overrideWithValue(_FakeOcrEndpoints()),
          ocrImagePickProvider.overrideWithValue(() async => '/fake.jpg'),
          companyDocumentsProvider(const DocumentListFilter())
              .overrideWith((ref) async => [
                    CompanyDocument.fromJson(const {
                      'id': 1,
                      'title': 'CMR 42',
                      'category': 'cmr',
                      'file_name': 'cmr-42.pdf',
                      'uploaded_by': 'Admin',
                      'uploaded_at': '2026-07-01T10:00:00',
                    }),
                  ]),
          documentCategoriesProvider
              .overrideWith((ref) async => <DocumentCategory>[]),
          documentVersionsProvider(1).overrideWith((ref) async => [
                const DocumentVersion(
                  versionNumber: 1,
                  fileName: 'cmr-42-v1.pdf',
                  uploadedBy: 'Admin',
                  createdAt: null,
                ),
                const DocumentVersion(
                  versionNumber: 2,
                  fileName: 'cmr-42-v2.pdf',
                  uploadedBy: 'Dispatch',
                  createdAt: null,
                ),
              ]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('cmr-42.pdf'));
      await tester.pumpAndSettle();

      // Version sheet lists both revisions with their metadata.
      expect(find.text('Versions'), findsOneWidget);
      expect(find.textContaining('cmr-42-v1.pdf'), findsOneWidget);
      expect(find.textContaining('cmr-42-v2.pdf'), findsOneWidget);
      expect(find.text('Uploaded by: Admin'), findsOneWidget);
    });

    testWidgets('version sheet shows an empty state when no versions exist',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          ocrEndpointsProvider.overrideWithValue(_FakeOcrEndpoints()),
          ocrImagePickProvider.overrideWithValue(() async => '/fake.jpg'),
          companyDocumentsProvider(const DocumentListFilter())
              .overrideWith((ref) async => [
                    CompanyDocument.fromJson(const {
                      'id': 1,
                      'title': 'CMR 42',
                      'category': 'cmr',
                      'file_name': 'cmr-42.pdf',
                      'uploaded_by': 'Admin',
                      'uploaded_at': '2026-07-01T10:00:00',
                    }),
                  ]),
          documentCategoriesProvider
              .overrideWith((ref) async => <DocumentCategory>[]),
          documentVersionsProvider(1)
              .overrideWith((ref) async => <DocumentVersion>[]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(wrapDocumentCenter(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('cmr-42.pdf'));
      await tester.pumpAndSettle();

      expect(find.text('No versions'), findsOneWidget);
    });
  });
}
