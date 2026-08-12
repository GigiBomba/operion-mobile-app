import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/invoicing/models/invoice.dart';
import 'package:operion_mobile/features/invoicing/widgets/status_stepper.dart';

void main() {
  group('InvoiceStatus — REAL backend strings', () {
    test('fromApiString parses every current status', () {
      const expectations = {
        'draft': InvoiceStatus.draft,
        'finalized': InvoiceStatus.finalized,
        'xml_generated': InvoiceStatus.xmlGenerated,
        'paid': InvoiceStatus.paid,
        'cancelled': InvoiceStatus.cancelled,
      };
      expectations.forEach((raw, expected) {
        expect(InvoiceStatus.fromApiString(raw), expected,
            reason: '$raw must map to $expected');
      });
    });

    test('fromApiString parses legacy submission strings defensively '
        '(historical cached rows)', () {
      // Gate-31: the backend removed the submission states — these strings
      // only survive in old local-cache rows and must keep parsing to the
      // closest current status instead of falling back to draft.
      expect(InvoiceStatus.fromApiString('submitted_externally'),
          InvoiceStatus.xmlGenerated);
      expect(InvoiceStatus.fromApiString('queued'), InvoiceStatus.xmlGenerated);
      expect(InvoiceStatus.fromApiString('submitting'),
          InvoiceStatus.xmlGenerated);
      expect(InvoiceStatus.fromApiString('accepted'),
          InvoiceStatus.xmlGenerated);
      expect(InvoiceStatus.fromApiString('rejected'),
          InvoiceStatus.cancelled);
      expect(InvoiceStatus.fromApiString('manual_review'),
          InvoiceStatus.xmlGenerated);
    });

    test('fromApiString falls back to draft for unknown values', () {
      expect(InvoiceStatus.fromApiString('unknown'), InvoiceStatus.draft);
      expect(InvoiceStatus.fromApiString(null), InvoiceStatus.draft);
    });

    test('apiValue round-trips', () {
      for (final s in InvoiceStatus.values) {
        expect(InvoiceStatus.fromApiString(s.apiValue), s);
      }
    });

    test('kStepperStatuses is the 4-step Gate-31 machine', () {
      expect(kStepperStatuses, [
        InvoiceStatus.draft,
        InvoiceStatus.finalized,
        InvoiceStatus.xmlGenerated,
        InvoiceStatus.paid,
      ]);
    });
  });

  group('Invoice.fromJson', () {
    test('parses the InvoiceOut shape', () {
      final invoice = Invoice.fromJson(const {
        'id': 42,
        'invoice_number': 'INV-2026-0001',
        'client_id': 7,
        'client_name': 'Client A',
        'trip_id': 99,
        'status': 'xml_generated',
        'issue_date': '2026-08-01',
        'due_date': '2026-08-31',
        'subtotal_net': 300.0,
        'total_vat': 57.0,
        'total_gross': 357.0,
        'total_amount': 357.0,
        'line_items': [
          {
            'description': 'Transport',
            'quantity': 3,
            'unit_price': 100.0,
            'discount_percent': 0.0,
            'discount_amount': 0.0,
            'vat_rate': 19.0,
            'taxable_amount': 300.0,
            'vat_amount': 57.0,
            'line_total': 357.0,
          },
        ],
        'created_at': '2026-08-01T10:00:00Z',
        'updated_at': '2026-08-01T10:00:00Z',
      });

      expect(invoice.id, '42');
      expect(invoice.invoiceNumber, 'INV-2026-0001');
      expect(invoice.clientId, '7');
      expect(invoice.clientName, 'Client A');
      expect(invoice.tripId, 99);
      expect(invoice.status, InvoiceStatus.xmlGenerated);
      expect(invoice.totalGross, 357.0);
      expect(invoice.lineItems, hasLength(1));
      expect(invoice.lineItems.single.quantity, 3.0);
      expect(invoice.lineItems.single.lineTotal, 357.0);
    });
  });

  group('InvoiceDraft / CmrFormDraft serialization', () {
    test('InvoiceDraft.toJson maps to the create payload', () {
      // ignore: prefer_const_declarations
      final draft = InvoiceDraft(
        clientId: 'c1',
        tripId: 10,
        issueDate: DateTime(2026, 8, 1),
        dueDate: DateTime(2026, 8, 31),
        lineItems: const [
          InvoiceLineItem(description: 'A', quantity: 2, unitPrice: 50),
        ],
      );
      final json = draft.toJson();
      expect(json['client_id'], 'c1');
      expect(json['trip_id'], 10);
      expect(json['issue_date'], '2026-08-01');
      expect(json['due_date'], '2026-08-31');
      expect(json['line_items'], hasLength(1));
    });

    test('CmrFormDraft.toJson includes the signature base64', () {
      const draft = CmrFormDraft(
        senderName: 'Sender',
        copies: 3,
        includeStamps: true,
        signaturePngBase64: 'aGVsbG8=',
      );
      final json = draft.toJson();
      expect(json['sender_name'], 'Sender');
      expect(json['copies'], 3);
      expect(json['include_stamps'], true);
      expect(json['signature_png_base64'], 'aGVsbG8=');
      expect(json.containsKey('remarks'), isFalse);
    });
  });

  group('InvoiceStatusStepper â€” labels per status', () {
    Widget app(InvoiceStatus status) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                InvoiceStatusStepper(status: status),
                const InvoiceStatusStepperLabels(),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('draft shows all four step labels', (tester) async {
      await tester.pumpWidget(app(InvoiceStatus.draft));
      await tester.pumpAndSettle();
      final loc = AppLocalizations(const Locale('en'));
      expect(find.text(loc.invoicing_stepDraft), findsWidgets);
      expect(find.text(loc.invoicing_stepFinalized), findsWidgets);
      expect(find.text(loc.invoicing_stepXml), findsWidgets);
      expect(find.text(loc.invoicing_stepPaid), findsWidgets);
    });

    testWidgets('paid highlights the final step', (tester) async {
      await tester.pumpWidget(app(InvoiceStatus.paid));
      await tester.pumpAndSettle();
      expect(find.text(AppLocalizations(const Locale('en')).invoicing_stepPaid),
          findsWidgets);
    });

    testWidgets('cancelled renders the terminal cancelled bar', (tester) async {
      await tester.pumpWidget(app(InvoiceStatus.cancelled));
      await tester.pumpAndSettle();
      final loc = AppLocalizations(const Locale('en'));
      expect(find.text(loc.invoicing_stepCancelled), findsWidgets);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    test('stepIndexFor maps the 4-step stepper subset', () {
      expect(InvoiceStatusStepper.stepIndexFor(InvoiceStatus.draft), 0);
      expect(InvoiceStatusStepper.stepIndexFor(InvoiceStatus.finalized), 1);
      expect(InvoiceStatusStepper.stepIndexFor(InvoiceStatus.xmlGenerated), 2);
      expect(InvoiceStatusStepper.stepIndexFor(InvoiceStatus.paid), 3);
      expect(InvoiceStatusStepper.stepIndexFor(InvoiceStatus.cancelled), isNull);
    });
  });
}

