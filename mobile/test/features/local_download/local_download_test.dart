import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/local_download/models/download_manifest.dart';
import 'package:operion_mobile/features/local_download/providers/local_download_providers.dart';
import 'package:operion_mobile/features/local_download/screens/local_download_screen.dart';

List<Map<String, dynamic>> manifestFixture() => [
      {
        'record_id': 'r1',
        'filename': 'invoice-2026-08.pdf',
        'size_bytes': 2048,
        'download_url': '/api/v1/mobile/company/export/download/token-1',
        'url_expires_at': '2026-08-31T00:00:00Z',
      },
      {
        'record_id': 'r2',
        'filename': 'cmr-2026-07.pdf',
        'size_bytes': 1024,
        'download_url': '/api/v1/mobile/company/export/download/token-2',
        'url_expires_at': '2026-08-31T00:00:00Z',
      },
    ];

/// Fake endpoints: serves a manifest and "downloads" by writing a local file.
class _FakeLocalDownloadEndpoints extends LocalDownloadEndpoints {
  _FakeLocalDownloadEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  List<Map<String, dynamic>>? manifest;
  final List<String> downloadedUrls = [];

  @override
  Future<Response> fetchManifest({
    required DownloadCategory category,
    DateTime? dateFrom,
    DateTime? dateTo,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(
        path: '/api/v1/mobile/company/export/manifest',
      ),
      data: manifest ?? manifestFixture(),
      statusCode: 200,
    );
  }

  @override
  Future<Response> downloadFile(
    String downloadUrl,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    downloadedUrls.add(downloadUrl);
    // Real file IO is not performed here — widget tests run in a FakeAsync
    // zone where dart:io futures would never complete. The notifier only
    // needs the progress signal + successful completion.
    onReceiveProgress?.call(3, 3);
    return Response(
      requestOptions: RequestOptions(path: downloadUrl),
      statusCode: 200,
    );
  }
}

Widget wrapLocalDownload(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: LocalDownloadScreen(),
    ),
  );
}

/// Pumps the screen on a tall viewport so every category card, the date
/// fields and the download button are laid out (the screen is a lazy
/// [ListView]).
Future<void> pumpLocalDownload(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapLocalDownload(container));
  await tester.pumpAndSettle();
}

ProviderContainer _containerWith(
  _FakeLocalDownloadEndpoints endpoints,
  Directory tempDir,
) {
  return ProviderContainer(
    overrides: [
      localDownloadEndpointsProvider.overrideWithValue(endpoints),
      localDownloadProvider.overrideWith(
        (ref) => LocalDownloadNotifier(
          endpoints,
          directoryProvider: () async => tempDir,
        ),
      ),
    ],
  );
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('local_download_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ==========================================================================
  // Initial state
  // ==========================================================================
  group('LocalDownloadScreen — initial state', () {
    testWidgets('renders app bar with title', (tester) async {
      final container = _containerWith(_FakeLocalDownloadEndpoints(), tempDir);
      addTearDown(container.dispose);
      await pumpLocalDownload(tester, container);

      expect(find.text('Local Download'), findsOneWidget);
    });

    testWidgets('shows select category prompt', (tester) async {
      final container = _containerWith(_FakeLocalDownloadEndpoints(), tempDir);
      addTearDown(container.dispose);
      await pumpLocalDownload(tester, container);

      expect(find.text('Select Category'), findsOneWidget);
    });

    testWidgets('renders all five category cards', (tester) async {
      final container = _containerWith(_FakeLocalDownloadEndpoints(), tempDir);
      addTearDown(container.dispose);
      await pumpLocalDownload(tester, container);

      expect(find.text('Documents'), findsAtLeastNWidgets(1));
      expect(find.text('Invoices'), findsOneWidget);
      expect(find.text('Receipts'), findsOneWidget);
      expect(find.text('OCR Results'), findsOneWidget);
      expect(find.text('Trip History'), findsOneWidget);
    });

    testWidgets('download button is not shown when no category selected',
        (tester) async {
      final container = _containerWith(_FakeLocalDownloadEndpoints(), tempDir);
      addTearDown(container.dispose);
      await pumpLocalDownload(tester, container);

      expect(find.text('Download'), findsNothing);
    });
  });

  // ==========================================================================
  // Category selection
  // ==========================================================================
  group('LocalDownloadScreen — category selection', () {
    testWidgets('selecting a category shows Lucide check icon',
        (tester) async {
      final container = _containerWith(_FakeLocalDownloadEndpoints(), tempDir);
      addTearDown(container.dispose);
      await pumpLocalDownload(tester, container);

      await tester.tap(find.text('Invoices'));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.check), findsOneWidget);
    });

    testWidgets('selecting a category shows the download button',
        (tester) async {
      final container = _containerWith(_FakeLocalDownloadEndpoints(), tempDir);
      addTearDown(container.dispose);
      await pumpLocalDownload(tester, container);

      await tester.tap(find.text('Receipts'));
      await tester.pumpAndSettle();

      expect(find.text('Download'), findsOneWidget);
    });
  });

  // ==========================================================================
  // Date-range filter
  // ==========================================================================
  group('LocalDownloadScreen — date range filter', () {
    testWidgets('date From/To fields appear once a category is selected',
        (tester) async {
      final container = _containerWith(_FakeLocalDownloadEndpoints(), tempDir);
      addTearDown(container.dispose);
      await pumpLocalDownload(tester, container);

      expect(find.text('From'), findsNothing);

      await tester.tap(find.text('Trip History'));
      await tester.pumpAndSettle();

      expect(find.text('From'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);
    });

    testWidgets('picking a From date replaces the placeholder', (tester) async {
      final container = _containerWith(_FakeLocalDownloadEndpoints(), tempDir);
      addTearDown(container.dispose);
      await pumpLocalDownload(tester, container);

      await tester.tap(find.text('Invoices'));
      await tester.pumpAndSettle();

      // Two placeholder dashes (From + To).
      expect(find.text('—'), findsNWidgets(2));

      await tester.tap(find.text('From'));
      await tester.pumpAndSettle();

      // The date picker dialog is open.
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Accept the initial date.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // From now shows a concrete date; To still shows its placeholder.
      expect(find.text('—'), findsOneWidget);
    });
  });

  // ==========================================================================
  // Download flow
  // ==========================================================================
  group('LocalDownloadScreen — download flow', () {
    testWidgets('download renders the manifest file list with per-file progress',
        (tester) async {
      final endpoints = _FakeLocalDownloadEndpoints();
      final container = _containerWith(endpoints, tempDir);
      addTearDown(container.dispose);

      await pumpLocalDownload(tester, container);

      await tester.tap(find.text('Invoices'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();

      // Manifest entries render.
      expect(find.text('invoice-2026-08.pdf'), findsOneWidget);
      expect(find.text('cmr-2026-07.pdf'), findsOneWidget);

      // Downloads run asynchronously after the manifest resolves — pump
      // until both files have been fetched.
      for (var i = 0; i < 100 && endpoints.downloadedUrls.length < 2; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      expect(endpoints.downloadedUrls.length, 2);
      expect(find.text('Saved to device'), findsNWidgets(2));

      // The notifier marked both files completed.
      final files = container.read(localDownloadProvider).files.values.toList();
      expect(files.length, 2);
      expect(files.every((f) => f.completed), isTrue);
      expect(files.every((f) => f.error == null), isTrue);
    });

    testWidgets('empty manifest shows the localized empty state',
        (tester) async {
      final endpoints = _FakeLocalDownloadEndpoints()..manifest = [];
      final container = _containerWith(endpoints, tempDir);
      addTearDown(container.dispose);

      await pumpLocalDownload(tester, container);

      await tester.tap(find.text('Receipts'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();

      expect(find.text('No files to download'), findsOneWidget);
      expect(endpoints.downloadedUrls, isEmpty);
    });
  });
}
