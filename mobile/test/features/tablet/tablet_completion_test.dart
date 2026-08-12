import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/paginated.dart';
import 'package:operion_mobile/features/clients/models/client.dart';
import 'package:operion_mobile/features/clients/providers/client_providers.dart';
import 'package:operion_mobile/features/clients/screens/client_list_screen.dart';
import 'package:operion_mobile/features/fleet/models/truck.dart';
import 'package:operion_mobile/features/fleet/providers/fleet_providers.dart';
import 'package:operion_mobile/features/fleet/screens/fleet_list_screen.dart';
import 'package:operion_mobile/features/fleet/screens/truck_detail_screen.dart';
import 'package:operion_mobile/features/history/providers/history_providers.dart';
import 'package:operion_mobile/features/history/screens/route_history_screen.dart';
import 'package:operion_mobile/features/history/screens/trip_history_screen.dart';
import 'package:operion_mobile/features/invoicing/models/invoice.dart';
import 'package:operion_mobile/features/invoicing/providers/invoicing_providers.dart';
import 'package:operion_mobile/features/invoicing/screens/invoice_editor_screen.dart';
import 'package:operion_mobile/features/invoicing/screens/invoice_list_screen.dart';
import 'package:operion_mobile/features/settings/settings_screen.dart';
import 'package:operion_mobile/features/settings/widgets/settings_sections.dart';
import 'package:operion_mobile/features/team_management/models/team_member.dart';
import 'package:operion_mobile/features/team_management/providers/team_providers.dart';
import 'package:operion_mobile/features/team_management/screens/team_management_screen.dart';
import 'package:operion_mobile/features/teams/providers/teams_providers.dart';
import 'package:operion_mobile/features/teams/screens/teams_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';
import 'package:operion_mobile/shared/widgets/master_detail_layout.dart';

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

final List<Truck> _trucks = [
  Truck.fromJson({
    'id': 't1',
    'company_id': 'c1',
    'plate': 'B-100-ABC',
    'brand': 'Volvo',
    'model': 'FH16',
    'status': 'Active',
    'health_score': 90.0,
  }),
  Truck.fromJson({
    'id': 't2',
    'company_id': 'c1',
    'plate': 'B-200-DEF',
    'brand': 'MAN',
    'model': 'TGX',
    'status': 'In Service',
    'health_score': 60.0,
  }),
];

final List<Invoice> _invoices = [
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

Invoice _finalizedInvoice() => Invoice.fromJson({
      'id': '1',
      'invoice_number': 'INV-2026-0001',
      'client_id': 7,
      'client_name': 'Alpha Logistics',
      'status': 'finalized',
      'issue_date': '2026-07-25',
      'due_date': '2026-08-31',
      'line_items': [
        {
          'description': 'Transport București–Cluj',
          'quantity': 1,
          'unit_price': 100.0,
          'vat_rate': 19.0,
        },
      ],
    });

const _members = [
  TeamMember(
    id: 1,
    email: 'ana@operion.ro',
    displayName: 'Ana Admin',
    role: 'manager',
    isActive: true,
  ),
  TeamMember(
    id: 2,
    email: 'ion@operion.ro',
    displayName: 'Ion Driver',
    role: 'dispatcher',
    isActive: false,
  ),
];

final List<Map<String, dynamic>> _drivers = [
  {'id': 1, 'name': 'Ana Popescu', 'status': 'available', 'current_vehicle': 'TR-101'},
  {'id': 2, 'name': 'Ion Ionescu', 'status': 'driving', 'current_transport': 'T-77'},
];

List<Override> _fleetOverrides() => [
      currentUserProvider.overrideWith((ref) => _adminUser),
      isOfflineProvider.overrideWith((ref) => false),
      fleetListProvider.overrideWith(
        (ref) async => FleetListData(trucks: _trucks, fromCache: false),
      ),
      fleetCachedBannerProvider.overrideWith((ref) => false),
      truckDetailProvider.overrideWith(
        (ref, id) async => TruckDetailData(
          truck: _trucks.firstWhere((t) => t.id == id),
          fromCache: false,
        ),
      ),
      truckMaintenanceHistoryProvider.overrideWith((ref, id) async => []),
    ];

List<Override> _invoiceOverrides() => [
      currentUserProvider.overrideWith((ref) => _adminUser),
      isOfflineProvider.overrideWith((ref) => false),
      invoiceCachedBannerProvider.overrideWith((ref) => false),
      invoiceListProvider.overrideWith(
        (ref, filter) async =>
            InvoiceListData(invoices: _invoices, fromCache: false),
      ),
      invoiceDetailProvider.overrideWith(
        (ref, id) async =>
            InvoiceDetailData(invoice: _finalizedInvoice(), fromCache: false),
      ),
    ];

List<Override> _teamManagementOverrides() => [
      currentUserProvider.overrideWith((ref) => _adminUser),
      isOfflineProvider.overrideWith((ref) => false),
      teamCachedBannerProvider.overrideWith((ref) => false),
      teamMembersProvider.overrideWith(
        (ref) async => const TeamListData(members: _members, fromCache: false),
      ),
    ];

List<Override> _clientsOverrides() => [
      currentUserProvider.overrideWith((ref) => _adminUser),
      isOfflineProvider.overrideWith((ref) => false),
      clientCachedBannerProvider.overrideWith((ref) => false),
      clientListProvider.overrideWith(
        (ref) async => ClientListData(
          clients: [
            Client.fromJson({
              'id': 'c1',
              'name': 'Alpha Logistics',
              'rating': 4.5,
              'payment_terms_days': 30,
              'is_active': true,
            }),
            Client.fromJson({
              'id': 'c2',
              'name': 'Beta Trading',
              'rating': 3.0,
              'payment_terms_days': 45,
              'is_active': false,
            }),
          ],
          fromCache: false,
        ),
      ),
      clientDetailProvider.overrideWith(
        (ref, id) async => ClientDetailData(
          client: Client.fromJson({
            'id': id,
            'name': 'Alpha Logistics',
            'rating': 4.5,
            'payment_terms_days': 30,
            'is_active': true,
          }),
          fromCache: false,
        ),
      ),
    ];

List<Override> _teamsOverrides() => [
      currentUserProvider.overrideWith((ref) => _adminUser),
      teamsDriversProvider.overrideWith((ref) async => _drivers),
      teamsFilteredDriversProvider.overrideWith((ref) => _drivers),
    ];

List<Override> _tripHistoryOverrides() => [
      isOfflineProvider.overrideWith((ref) => false),
      tripHistoryProvider.overrideWith(
        (ref, filter) async => PaginatedResponse<TripHistoryEntry>(
          items: [
            TripHistoryEntry.fromJson({
              'id': 1,
              'client_name': 'ACME',
              'truck_number': 'B-100',
              'driver_name': 'Ion',
              'origin': 'București',
              'destination': 'Cluj',
              'status': 'Delivered',
              'start_date': '2026-07-01',
              'total_price_eur': 1200,
            }),
            TripHistoryEntry.fromJson({
              'id': 2,
              'client_name': 'Beta',
              'truck_number': 'B-200',
              'driver_name': 'Ana',
              'origin': 'Cluj',
              'destination': 'Sibiu',
              'status': 'In Transit',
              'start_date': '2026-07-02',
              'total_price_eur': 800,
            }),
          ],
          total: 2,
          page: 1,
          pageSize: 20,
          totalPages: 1,
        ),
      ),
    ];

List<Override> _routeHistoryOverrides() => [
      routeHistoryProvider.overrideWith(
        (ref, filter) async => PaginatedResponse<RouteHistoryEntry>(
          items: [
            RouteHistoryEntry.fromJson({
              'id': 1,
              'name': 'Ruta Vest',
              'origin': 'București',
              'destination': 'Timișoara',
              'total_distance_km': 428,
              'duration_min': 330,
              'created_at': '2026-07-31',
            }),
            RouteHistoryEntry.fromJson({
              'id': 2,
              'name': 'Ruta Est',
              'origin': 'Constanța',
              'destination': 'Iași',
              'total_distance_km': 512,
              'duration_min': 400,
              'created_at': '2026-07-29',
            }),
          ],
          total: 2,
          page: 1,
          pageSize: 20,
          totalPages: 1,
        ),
      ),
    ];

Widget _app(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

Future<void> _pumpAtWidth(
  WidgetTester tester,
  Widget child,
  List<Override> overrides,
  double width,
) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(child, overrides));
  await tester.pumpAndSettle();
}

void main() {
  group('Tablet ≥600dp completion (§9 item 5)', () {
    testWidgets('Fleet at 800dp: master-detail + selection swaps truck detail',
        (tester) async {
      await _pumpAtWidth(tester, const FleetListScreen(), _fleetOverrides(), 800);

      expect(find.byType(MasterDetailLayout), findsOneWidget);
      expect(find.byType(TruckDetailScreen), findsOneWidget);

      // Default selection = first truck.
      var detail = tester.widget<TruckDetailScreen>(find.byType(TruckDetailScreen));
      expect(detail.truckId, 't1');

      // Selecting the second row swaps the detail pane.
      await tester.tap(find.text('B-200-DEF'));
      await tester.pumpAndSettle();
      detail = tester.widget<TruckDetailScreen>(find.byType(TruckDetailScreen));
      expect(detail.truckId, 't2');
    });

    testWidgets('Fleet at 390dp: phone push navigation (no master-detail)',
        (tester) async {
      await _pumpAtWidth(tester, const FleetListScreen(), _fleetOverrides(), 390);

      expect(find.byType(MasterDetailLayout), findsNothing);
      expect(find.byType(TruckDetailScreen), findsNothing);
    });

    testWidgets('Invoicing at 800dp: master-detail + selection swaps editor',
        (tester) async {
      await _pumpAtWidth(
          tester, const InvoiceListScreen(), _invoiceOverrides(), 800);

      expect(find.byType(MasterDetailLayout), findsOneWidget);
      expect(find.byType(InvoiceEditorScreen), findsOneWidget);

      await tester.tap(find.text('INV-2026-0002'));
      await tester.pumpAndSettle();
      final editor = tester.widget<InvoiceEditorScreen>(
          find.byType(InvoiceEditorScreen));
      expect(editor.invoiceId, '2');
    });

    testWidgets('Invoicing at 390dp: phone push navigation (no master-detail)',
        (tester) async {
      await _pumpAtWidth(
          tester, const InvoiceListScreen(), _invoiceOverrides(), 390);

      expect(find.byType(MasterDetailLayout), findsNothing);
      expect(find.byType(InvoiceEditorScreen), findsNothing);
    });

    testWidgets('Team Management at 800dp: master-detail + selection swaps',
        (tester) async {
      await _pumpAtWidth(
          tester, const TeamManagementScreen(), _teamManagementOverrides(), 800);

      expect(find.byType(MasterDetailLayout), findsOneWidget);
      // Default detail pane = first member (Ana Admin appears in list + detail).
      expect(find.text('Ana Admin'), findsNWidgets(2));
      expect(find.text('Ion Driver'), findsOneWidget);

      // Selecting the second member swaps the detail pane.
      await tester.tap(find.text('Ion Driver'));
      await tester.pumpAndSettle();
      expect(find.text('Ion Driver'), findsNWidgets(2));
      expect(find.text('Ana Admin'), findsOneWidget);
    });

    testWidgets('Team Management at 390dp: no master-detail', (tester) async {
      await _pumpAtWidth(
          tester, const TeamManagementScreen(), _teamManagementOverrides(), 390);

      expect(find.byType(MasterDetailLayout), findsNothing);
    });

    testWidgets('Clients at 800dp: master-detail present', (tester) async {
      await _pumpAtWidth(
          tester, const ClientListScreen(), _clientsOverrides(), 800);

      expect(find.byType(MasterDetailLayout), findsOneWidget);
      await tester.tap(find.text('Beta Trading'));
      await tester.pumpAndSettle();
      expect(find.text('Beta Trading'), findsWidgets);
    });

    testWidgets('Teams at 800dp: master-detail + selection swaps driver detail',
        (tester) async {
      await _pumpAtWidth(tester, const TeamsScreen(), _teamsOverrides(), 800);

      expect(find.byType(MasterDetailLayout), findsOneWidget);
      expect(find.byType(TruckDetailScreen), findsNothing);

      await tester.tap(find.text('Ion Ionescu'));
      await tester.pumpAndSettle();
      expect(find.byType(MasterDetailLayout), findsOneWidget);
    });

    testWidgets('Trip History at 800dp: master-detail present', (tester) async {
      await _pumpAtWidth(
          tester, const TripHistoryScreen(), _tripHistoryOverrides(), 800);

      expect(find.byType(MasterDetailLayout), findsOneWidget);
      // Detail pane defaults to the first trip (trip details header).
      expect(find.text('Trip details'), findsOneWidget);
    });

    testWidgets('Route History at 800dp: master-detail present', (tester) async {
      await _pumpAtWidth(
          tester, const RouteHistoryScreen(), _routeHistoryOverrides(), 800);

      expect(find.byType(MasterDetailLayout), findsOneWidget);
      expect(find.text('Route details'), findsOneWidget);
    });

    testWidgets('Settings at 800dp: master-detail section nav', (tester) async {
      await _pumpAtWidth(
          tester,
          const SettingsScreen(),
          [
            currentUserProvider.overrideWith((ref) => _adminUser),
            isOfflineProvider.overrideWith((ref) => false),
          ],
          800);

      expect(find.byType(MasterDetailLayout), findsOneWidget);
      // Selecting a section swaps the detail pane.
      await tester.tap(find.text('Notification Preferences'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationPreferencesSection), findsOneWidget);
    });
  });
}
