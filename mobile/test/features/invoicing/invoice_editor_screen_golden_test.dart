import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/invoicing/models/invoice.dart';
import 'package:operion_mobile/features/invoicing/providers/invoicing_providers.dart';
import 'package:operion_mobile/features/invoicing/screens/invoice_editor_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

/// A finalized (mid-machine) invoice with line items — the editor seeds its
/// state from `invoiceDetailProvider` and recomputes totals via the P4 core.
Invoice _finalizedInvoice() => Invoice.fromJson({
      'id': 'inv-1',
      'invoice_number': 'INV-2026-0001',
      'client_id': 7,
      'client_name': 'Alpha Logistics',
      'trip_id': 42,
      'status': 'finalized',
      'issue_date': '2026-07-25',
      'due_date': '2026-08-31',
      'line_items': [
        {
          'description': 'Transport București–Cluj',
          'quantity': 3,
          'unit_price': 100.0,
          'vat_rate': 19.0,
        },
        {
          'description': 'Extra stop Cluj',
          'quantity': 1,
          'unit_price': 50.0,
          'vat_rate': 19.0,
        },
      ],
    });

List<Override> _overrides() => [
      isOfflineProvider.overrideWith((ref) => false),
      currentUserProvider.overrideWith((ref) => _adminUser),
      invoiceDetailProvider.overrideWith(
        (ref, id) async =>
            InvoiceDetailData(invoice: _finalizedInvoice(), fromCache: false),
      ),
    ];

Widget _app({required Brightness brightness}) {
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
      home: const InvoiceEditorScreen(invoiceId: 'inv-1'),
    ),
  );
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Brightness brightness,
  String file,
) async {
  // 460 wide (still phone layout, <600): the "Line items (N)" Row is 6px too
  // wide at 390 with the blocky Ahem test font (glyph width == fontSize). Real
  // Roboto is far narrower, so this is a test-harness accommodation, not a
  // production layout change.
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
  testWidgets('InvoiceEditorScreen golden (light)', (tester) async {
    await _pumpGolden(tester, Brightness.light, 'invoice_editor_light.png');
  });

  testWidgets('InvoiceEditorScreen golden (dark)', (tester) async {
    await _pumpGolden(tester, Brightness.dark, 'invoice_editor_dark.png');
  });
}
