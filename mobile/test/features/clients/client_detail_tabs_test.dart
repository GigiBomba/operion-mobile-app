// ---------------------------------------------------------------------------
// client_detail_tabs_test.dart — B1
//
// Verifies the client-detail Invoices/Trips tabs are wired to real providers
// (not the Phase-1 count+placeholder stubs):
//   1. Invoices tab shows a shimmer while the invoice list is loading.
//   2. Invoices tab shows the empty-state when the client has no invoices.
//   3. Trips tab shows the empty-state when the client has no trips.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/paginated.dart';
import 'package:operion_mobile/features/clients/models/client.dart';
import 'package:operion_mobile/features/clients/providers/client_providers.dart';
import 'package:operion_mobile/features/clients/screens/client_detail_screen.dart';
import 'package:operion_mobile/features/history/providers/history_providers.dart';
import 'package:operion_mobile/features/invoicing/providers/invoicing_providers.dart';
import 'package:operion_mobile/shared/widgets/shimmer_loader.dart';

const _clientId = 'c1';

Client _client() => Client.fromJson({
      'id': _clientId,
      'company_id': 'co1',
      'name': 'Acme Logistics',
      'vat_number': 'RO123',
      'address': 'Str. X 1',
      'payment_terms_days': 30,
      'rating': 4.5,
      'is_active': true,
      'contacts': <dynamic>[],
      'recent_trip_count': 0,
      'recent_invoice_count': 0,
    });

Widget _wrap({
  Future<InvoiceListData> Function(Ref, InvoiceListFilter)? invoices,
  Future<PaginatedResponse<TripHistoryEntry>> Function(
      Ref, TripHistoryFilter)? trips,
}) {
  return ProviderScope(
    overrides: [
      clientDetailProvider(_clientId).overrideWith(
        (ref) async => ClientDetailData(client: _client(), fromCache: false),
      ),
      if (invoices != null)
        invoiceListProvider.overrideWith(invoices),
      if (trips != null)
        tripHistoryProvider.overrideWith(trips),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ClientDetailScreen(clientId: _clientId),
    ),
  );
}

void main() {
  group('ClientDetailScreen — Invoices tab (B1)', () {
    testWidgets('shows shimmer while the invoice list is loading',
        (tester) async {
      // Keep the invoice list pending forever → the tab renders its shimmer.
      final pending = Completer<InvoiceListData>();
      await tester.pumpWidget(_wrap(
        invoices: (ref, filter) => pending.future,
        trips: (ref, filter) async => const PaginatedResponse<TripHistoryEntry>(
          items: <TripHistoryEntry>[],
          total: 0,
          page: 1,
          pageSize: 20,
          totalPages: 0,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Invoices'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ShimmerCard), findsWidgets);
    });

    testWidgets('shows empty-state when the client has no invoices',
        (tester) async {
      await tester.pumpWidget(_wrap(
        invoices: (ref, filter) async =>
            const InvoiceListData(invoices: [], fromCache: false),
        trips: (ref, filter) async => const PaginatedResponse<TripHistoryEntry>(
          items: <TripHistoryEntry>[],
          total: 0,
          page: 1,
          pageSize: 20,
          totalPages: 0,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Invoices'));
      await tester.pumpAndSettle();

      expect(find.text('No invoices yet'), findsOneWidget);
    });
  });

  group('ClientDetailScreen — Trips tab (B1)', () {
    testWidgets('shows empty-state when the client has no trips',
        (tester) async {
      await tester.pumpWidget(_wrap(
        invoices: (ref, filter) async =>
            const InvoiceListData(invoices: [], fromCache: false),
        trips: (ref, filter) async => const PaginatedResponse<TripHistoryEntry>(
          items: <TripHistoryEntry>[],
          total: 0,
          page: 1,
          pageSize: 20,
          totalPages: 0,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trips'));
      await tester.pumpAndSettle();

      expect(find.text('No trips yet'), findsOneWidget);
    });
  });
}
