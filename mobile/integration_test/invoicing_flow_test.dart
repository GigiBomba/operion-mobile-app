import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/client_endpoints.dart';
import 'package:operion_mobile/features/clients/providers/client_providers.dart';
import 'package:operion_mobile/features/invoicing/providers/invoicing_providers.dart';

import 'test_support.dart';

/// Stub [ClientEndpoints] serving the client the invoice editor needs.
class _StubClientEndpoints extends ClientEndpoints {
  _StubClientEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_access_token',
        ));

  @override
  Future<Response> getClients({
    String? search,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: [
        {
          'id': 'c1',
          'company_id': '1',
          'name': 'ACME Logistics',
          'vat_number': 'RO12345678',
          'payment_terms_days': 30,
          'rating': 4.5,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
        },
      ],
    );
  }

  @override
  Future<Response> getClient(String id, {CancelToken? cancelToken}) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'id': 'c1',
        'company_id': '1',
        'name': 'ACME Logistics',
        'vat_number': 'RO12345678',
        'payment_terms_days': 30,
        'rating': 4.5,
        'is_active': true,
        'contacts': <Map<String, dynamic>>[],
      },
    );
  }
}

/// Stub [InvoicingEndpoints] serving a draft + paid invoice and echoing new
/// drafts back through `createInvoice`.
class _StubInvoicingEndpoints extends InvoicingEndpoints {
  _StubInvoicingEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_access_token',
        ));

  final List<Map<String, dynamic>> invoices = [
    {
      'id': 'inv-1001',
      'invoice_number': 'INV-1001',
      'client_id': 'c1',
      'client_name': 'ACME Logistics',
      'status': 'draft',
      'issue_date': DateTime.now().toIso8601String(),
      'due_date': DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String(),
      'subtotal_net': 1000.0,
      'total_vat': 190.0,
      'total_gross': 1190.0,
      'total_amount': 1190.0,
      'line_items': [
        {
          'description': 'Transport Cluj-Bucharest',
          'quantity': 1,
          'unit_price': 1000.0,
          'vat_rate': 19,
          'line_total': 1190.0,
        },
      ],
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'inv-1002',
      'invoice_number': 'INV-1002',
      'client_id': 'c1',
      'client_name': 'ACME Logistics',
      'status': 'paid',
      'issue_date': DateTime.now().toIso8601String(),
      'subtotal_net': 500.0,
      'total_vat': 95.0,
      'total_gross': 595.0,
      'total_amount': 595.0,
      'line_items': [
        {
          'description': 'Local delivery',
          'quantity': 1,
          'unit_price': 500.0,
          'vat_rate': 19,
          'line_total': 595.0,
        },
      ],
      'created_at': DateTime.now().toIso8601String(),
    },
  ];

  @override
  Future<Response> getInvoices(
    InvoiceListFilter filter, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: invoices,
    );
  }

  @override
  Future<Response> getInvoice(String id, {CancelToken? cancelToken}) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: invoices.firstWhere(
        (i) => i['id'] == id,
        orElse: () => invoices.first,
      ),
    );
  }

  @override
  Future<Response> createInvoice(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    final invoice = <String, dynamic>{
      'id': 'inv-1003',
      'invoice_number': 'INV-1003',
      'client_id': data['client_id'],
      'client_name': 'ACME Logistics',
      'status': 'draft',
      'issue_date': DateTime.now().toIso8601String(),
      'subtotal_net': 0,
      'total_vat': 0,
      'total_gross': 0,
      'total_amount': 0,
      'line_items': data['line_items'] ?? <Map<String, dynamic>>[],
      'created_at': DateTime.now().toIso8601String(),
    };
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: invoice,
    );
  }
}

Future<List<Override>> _overrides() async {
  final db = await initTestLocalDatabase();
  return managerOverrides(
    db: db,
    user: managerUser,
    extra: [
      clientEndpointsProvider.overrideWith((ref) => _StubClientEndpoints()),
      invoicingEndpointsProvider
          .overrideWith((ref) => _StubInvoicingEndpoints()),
    ],
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Invoicing Flow', () {
    testWidgets(
      '1. Create an invoice draft from the editor',
      (tester) async {
        await pumpApp(tester, overrides: await _overrides());

        await openMoreTab(tester);
        await tapByText(tester, 'Invoicing');

        // Stub invoices are listed.
        expect(find.text('INV-1001'), findsOneWidget);

        // Open the new-draft editor via the FAB.
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // Select a client through the client picker.
        await tapByText(tester, 'Select a client');
        await tapByText(tester, 'ACME Logistics');
        expect(find.text('Select a client'), findsNothing);

        // Add a line item.
        await tapByText(tester, 'Add line');
        expect(find.textContaining('Line items (1)'), findsOneWidget);

        // Save the draft.
        await tester.scrollUntilVisible(
          find.text('Save Draft'),
          200,
          scrollable: find.byType(Scrollable).hitTestable().first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save Draft'));
        await tester.pumpAndSettle();

        expect(
          find.text('Draft saved'),
          findsOneWidget,
          reason: 'Saving a valid draft should surface the success message.',
        );
      },
    );

    testWidgets(
      '2. Invoice detail shows totals and the status stepper',
      (tester) async {
        await pumpApp(tester, overrides: await _overrides());

        await openMoreTab(tester);
        await tapByText(tester, 'Invoicing');

        // The list rows show the invoice number and the gross total.
        expect(find.text('INV-1001'), findsOneWidget);
        expect(find.textContaining('Total: 1190.00'), findsOneWidget);

        // Open the draft invoice detail.
        await tapByText(tester, 'INV-1001');

        // The status stepper is rendered with the Draft step current.
        expect(find.text('Status'), findsOneWidget);
        expect(find.text('Draft'), findsWidgets);
        expect(find.text('Paid'), findsWidgets);
        expect(find.text('Invoice no.: INV-1001'), findsOneWidget);

        // The draft's primary action is Finalize (scrolled into view).
        await tester.scrollUntilVisible(
          find.text('Finalize'),
          200,
          scrollable: find.byType(Scrollable).hitTestable().first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Finalize'), findsOneWidget);
      },
    );
  });
}
