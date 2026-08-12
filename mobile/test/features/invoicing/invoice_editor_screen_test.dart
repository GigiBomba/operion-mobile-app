import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/security/biometric_gate.dart';
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

class _NoopInvoicingEndpoints extends InvoicingEndpoints {
  _NoopInvoicingEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<String> transitionActions = [];

  @override
  Future<Response> transition(
    String id,
    String action, {
    CancelToken? cancelToken,
  }) async {
    transitionActions.add(action);
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'id': id,
        'invoice_number': 'INV-1',
        'client_id': 'c1',
        'status': 'paid',
      },
      statusCode: 200,
    );
  }
}

Widget _app(Widget child) {
  return ProviderScope(
    overrides: [
      isOfflineProvider.overrideWith((ref) => false),
      currentUserProvider.overrideWith((ref) => _adminUser),
      invoicingEndpointsProvider.overrideWithValue(_NoopInvoicingEndpoints()),
      biometricGateProvider
          .overrideWithValue(BiometricGate(authenticate: (_) async => true)),
    ],
    child: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
}

Future<void> _addLine(WidgetTester tester) async {
  await tester.tap(find.text('Add line'));
  await tester.pumpAndSettle();
}

Future<void> _editLine(WidgetTester tester,
    {required int index,
    required String description,
    required String quantity,
    required String unitPrice,
    required String vatRate,
    String discountPct = '0',
    String discountAmount = '0'}) async {
  await tester.tap(find.byIcon(LucideIcons.pencil).at(index));
  await tester.pumpAndSettle();

  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), description);
  await tester.enterText(fields.at(1), quantity);
  await tester.enterText(fields.at(2), unitPrice);
  await tester.enterText(fields.at(3), discountPct);
  await tester.enterText(fields.at(4), discountAmount);
  await tester.enterText(fields.at(5), vatRate);

  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('add line + live totals footer (recompute → P4 core)',
      (tester) async {
    await tester.pumpWidget(_app(InvoiceEditorScreen.newInvoice()));
    await tester.pumpAndSettle();

    await _addLine(tester);
    expect(find.byType(ListTile), findsOneWidget);

    await _editLine(
      tester,
      index: 0,
      description: 'Transport',
      quantity: '3',
      unitPrice: '100',
      vatRate: '19',
    );

    // Live totals: subtotal 300.00, VAT 57.00, total 357.00.
    expect(find.text('300.00'), findsWidgets);
    expect(find.text('57.00'), findsWidgets);
    expect(find.text('357.00'), findsWidgets);

    // Second line changes the totals.
    await _addLine(tester);
    await _editLine(
      tester,
      index: 1,
      description: 'Warehouse',
      quantity: '1',
      unitPrice: '50',
      discountPct: '10',
      vatRate: '19',
    );

    expect(find.text('345.00'), findsWidgets); // subtotal 300+45
    expect(find.text('65.55'), findsWidgets); // VAT 57+8.55
    expect(find.text('410.55'), findsWidgets); // total 357+53.55
  });

  testWidgets('delete a line removes it and zeroes the totals', (tester) async {
    await tester.pumpWidget(_app(InvoiceEditorScreen.newInvoice()));
    await tester.pumpAndSettle();

    await _addLine(tester);
    await _editLine(
      tester,
      index: 0,
      description: 'Transport',
      quantity: '3',
      unitPrice: '100',
      vatRate: '19',
    );
    expect(find.byType(ListTile), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('0.00'), findsWidgets);
  });

  testWidgets('two line items render in order and reorder by drag',
      (tester) async {
    await tester.pumpWidget(_app(InvoiceEditorScreen.newInvoice()));
    await tester.pumpAndSettle();

    await _addLine(tester);
    await _editLine(
      tester,
      index: 0,
      description: 'First',
      quantity: '1',
      unitPrice: '10',
      vatRate: '0',
    );
    await _addLine(tester);
    await _editLine(
      tester,
      index: 1,
      description: 'Second',
      quantity: '1',
      unitPrice: '20',
      vatRate: '0',
    );

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));

    // Drag the second line above the first (long-press + drag up).
    final second = find.byKey(const ValueKey('invoice_line_1'));
    await tester.longPress(second);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.drag(second, const Offset(0, -120));
    await tester.pumpAndSettle();

    // Order now: Second first, First second.
    final positions = tester
        .getTopLeft(find.byKey(const ValueKey('invoice_line_0')))
        .dy;
    final positions2 = tester
        .getTopLeft(find.byKey(const ValueKey('invoice_line_1')))
        .dy;
    expect(positions2, greaterThan(positions),
        reason: 'After the drag, line 1 must sit above line 0');
  });

  testWidgets('primary action label follows the invoice state', (tester) async {
    final loc = AppLocalizations(const Locale('en'));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isOfflineProvider.overrideWith((ref) => false),
        currentUserProvider.overrideWith((ref) => _adminUser),
        invoicingEndpointsProvider.overrideWithValue(_NoopInvoicingEndpoints()),
        biometricGateProvider
            .overrideWithValue(BiometricGate(authenticate: (_) async => true)),
        invoiceDetailProvider.overrideWith((ref, id) async {
          return InvoiceDetailData(
            invoice: Invoice.fromJson({
              'id': id,
              'invoice_number': 'INV-2026-0001',
              'client_id': 'c1',
              'client_name': 'Client A',
              'status': 'finalized',
            }),
            fromCache: false,
          );
        }),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvoiceEditorScreen(invoiceId: 'inv-1'),
      ),
    ));
    await tester.pumpAndSettle();

    // finalized → Generate e-Factura XML.
    await tester.scrollUntilVisible(
      find.text(loc.invoicing_generateXml),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(loc.invoicing_generateXml), findsOneWidget);
  });

  testWidgets('xml_generated primary action is Mark Paid (Gate-31, no Submit)',
      (tester) async {
    final loc = AppLocalizations(const Locale('en'));
    final endpoints = _NoopInvoicingEndpoints();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isOfflineProvider.overrideWith((ref) => false),
        currentUserProvider.overrideWith((ref) => _adminUser),
        invoicingEndpointsProvider.overrideWithValue(endpoints),
        biometricGateProvider
            .overrideWithValue(BiometricGate(authenticate: (_) async => true)),
        invoiceDetailProvider.overrideWith((ref, id) async {
          return InvoiceDetailData(
            invoice: Invoice.fromJson({
              'id': id,
              'invoice_number': 'INV-2026-0001',
              'client_id': 'c1',
              'client_name': 'Client A',
              'status': 'xml_generated',
            }),
            fromCache: false,
          );
        }),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvoiceEditorScreen(invoiceId: 'inv-1'),
      ),
    ));
    await tester.pumpAndSettle();

    // xml_generated → "Mark Paid" is the primary action (the former ANAF
    // Submit step is gone). "Submit" must NOT appear anywhere.
    await tester.scrollUntilVisible(
      find.text(loc.invoicing_markPaid),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(loc.invoicing_markPaid), findsOneWidget);
    expect(find.text('Submit'), findsNothing);

    // Tapping the primary action fires mark_paid (not submit).
    await tester.tap(find.text(loc.invoicing_markPaid));
    await tester.pumpAndSettle();
    expect(endpoints.transitionActions, ['mark_paid']);
  });
}
