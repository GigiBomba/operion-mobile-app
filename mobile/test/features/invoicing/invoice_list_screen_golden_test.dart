import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/invoicing/models/invoice.dart';
import 'package:operion_mobile/features/invoicing/providers/invoicing_providers.dart';
import 'package:operion_mobile/features/invoicing/screens/invoice_list_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';
import '../../helpers/golden_fonts.dart';

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

final _invoices = [
  Invoice.fromJson({
    'id': 1,
    'invoice_number': 'INV-2026-0001',
    'client_id': 7,
    'client_name': 'Alpha Logistics',
    'status': 'draft',
    'due_date': '2026-08-31',
    'subtotal_net': 300.0,
    'total_vat': 57.0,
    'total_gross': 357.0,
  }),
  Invoice.fromJson({
    'id': 2,
    'invoice_number': 'INV-2026-0002',
    'client_id': 8,
    'client_name': 'Beta Trading',
    'status': 'finalized',
    'due_date': '2026-08-15',
    'subtotal_net': 400.0,
    'total_vat': 76.0,
    'total_gross': 476.0,
  }),
  Invoice.fromJson({
    'id': 3,
    'invoice_number': 'INV-2026-0003',
    'client_id': 9,
    'client_name': 'Gamma Distribution',
    'status': 'paid',
    'due_date': '2026-07-20',
    'subtotal_net': 1250.0,
    'total_vat': 237.5,
    'total_gross': 1487.5,
  }),
];

List<Override> _overrides() => [
      isOfflineProvider.overrideWith((ref) => false),
      currentUserProvider.overrideWith((ref) => _adminUser),
      invoiceCachedBannerProvider.overrideWith((ref) => false),
      invoiceListProvider.overrideWith(
        (ref, filter) async =>
            InvoiceListData(invoices: _invoices, fromCache: false),
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
      home: const InvoiceListScreen(),
    ),
  );
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Brightness brightness,
  String file,
) async {
  // 460 wide (still phone layout, <600): the Total/Due row uses two un-flexed
  // Texts inside a Spacer row, which overflows at 390 with the blocky Ahem
  // test font (glyph width == fontSize). Real Roboto is far narrower, so this
  // is a test-harness accommodation, not a production layout change.
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
  setUpAll(loadGoldenFonts);
  testWidgets('InvoiceListScreen golden (light)', (tester) async {
    await _pumpGolden(tester, Brightness.light, 'invoice_list_light.png');
  });

  testWidgets('InvoiceListScreen golden (dark)', (tester) async {
    await _pumpGolden(tester, Brightness.dark, 'invoice_list_dark.png');
  });
}