import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/invoicing/models/invoice.dart';
import 'package:operion_mobile/features/invoicing/providers/invoicing_providers.dart';
import 'package:operion_mobile/features/invoicing/screens/invoice_list_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';

import '../../support/test_helpers.dart';

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

const _dispatcherUser = User(
  id: 'u1',
  email: 'dispatcher@operion.ro',
  fullName: 'Dispatcher',
  role: 'dispatcher',
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
    'status': 'paid',
    'due_date': '2026-07-15',
    'subtotal_net': 100.0,
    'total_vat': 19.0,
    'total_gross': 119.0,
  }),
];

List<Override> _overrides({User? user}) => [
      isOfflineProvider.overrideWith((ref) => false),
      currentUserProvider.overrideWith((ref) => user ?? _adminUser),
      invoiceCachedBannerProvider.overrideWith((ref) => false),
      invoiceListProvider.overrideWith(
        (ref, filter) async =>
            InvoiceListData(invoices: _invoices, fromCache: false),
      ),
    ];

Widget _app({User? user}) {
  return ProviderScope(
    overrides: _overrides(user: user),
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: InvoiceListScreen(),
    ),
  );
}

void main() {
  testWidgets('renders invoice rows with number, client, total and due date',
      (tester) async {
      usePhoneSurface(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('INV-2026-0001'), findsOneWidget);
    expect(find.text('Alpha Logistics'), findsOneWidget);
    expect(find.textContaining('357.00'), findsOneWidget); // total
    expect(find.textContaining('2026-08-31'), findsOneWidget); // due
    expect(find.text('INV-2026-0002'), findsOneWidget);
    expect(find.text('Beta Trading'), findsOneWidget);
  });

  testWidgets('status chips render and filter the family key', (tester) async {
      usePhoneSurface(tester);
    final container = ProviderContainer(overrides: _overrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [AppLocalizations.delegate],
          home: InvoiceListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final loc = AppLocalizations(const Locale('en'));
    // All stepper-subset chips render. At phone width the chips row scrolls
    // horizontally and builds lazily, so scroll to the trailing chips.
    expect(find.widgetWithText(ChoiceChip, loc.invoicing_statusAll), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, loc.invoicing_statusDraft),
        findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, loc.invoicing_statusPaid),
        findsOneWidget);

    // Tapping the Paid chip updates the filter provider.
    final paidChip = find.widgetWithText(ChoiceChip, loc.invoicing_statusPaid);
    await tester.ensureVisible(paidChip);
    await tester.pumpAndSettle();
    await tester.tap(paidChip);
    await tester.pump();
    expect(container.read(invoiceListFilterProvider).status, 'paid');
  });

  testWidgets('search filters rows instantly (client-side)', (tester) async {
      usePhoneSurface(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'beta');
    await tester.pumpAndSettle();

    expect(find.text('INV-2026-0002'), findsOneWidget);
    expect(find.text('INV-2026-0001'), findsNothing);
  });

  testWidgets('empty list shows the empty state', (tester) async {
      usePhoneSurface(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isOfflineProvider.overrideWith((ref) => false),
        currentUserProvider.overrideWith((ref) => _adminUser),
        invoiceCachedBannerProvider.overrideWith((ref) => false),
        invoiceListProvider.overrideWith(
          (ref, filter) async =>
              const InvoiceListData(invoices: [], fromCache: false),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [AppLocalizations.delegate],
        home: InvoiceListScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    final loc = AppLocalizations(const Locale('en'));
    expect(find.text(loc.invoicing_emptyTitle), findsOneWidget);
  });

  testWidgets('create FAB gated by can_create_invoice (admin present)',
      (tester) async {
      usePhoneSurface(tester);
    await tester.pumpWidget(_app(user: _adminUser));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('create FAB ABSENT for dispatcher (§8.2)', (tester) async {
      usePhoneSurface(tester);
    await tester.pumpWidget(_app(user: _dispatcherUser));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing,
        reason: 'Dispatcher cannot create invoices → FAB must be absent');
  });
}
