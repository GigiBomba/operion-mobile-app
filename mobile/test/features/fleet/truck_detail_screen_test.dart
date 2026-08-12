import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/document_center/providers/document_center_providers.dart';
import 'package:operion_mobile/features/fleet/models/truck.dart';
import 'package:operion_mobile/features/fleet/providers/fleet_providers.dart';
import 'package:operion_mobile/features/fleet/screens/truck_detail_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

const _dispatcherUser = User(
  id: 'u1',
  email: 'disp@operion.ro',
  fullName: 'Disp',
  role: 'dispatcher',
  companyId: 'c1',
);

final Truck _truck = Truck.fromJson({
  'id': 't1',
  'company_id': 'c1',
  'plate': 'B-100-ABC',
  'brand': 'Volvo',
  'model': 'FH16',
  'vin': 'VIN123',
  'year': 2021,
  'status': 'Active',
  'health_score': 90.0,
  'current_driver_id': 'd7',
});

Widget _wrap({required User user}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      truckDetailProvider.overrideWith(
        (ref, id) async => TruckDetailData(truck: _truck, fromCache: false),
      ),
      truckMaintenanceHistoryProvider.overrideWith(
        (ref, id) async => [
          TruckMaintenanceRecord.fromJson({
            'id': 1,
            'truck_id': 't1',
            'date': '2026-07-15',
            'category': 'oil_change',
            'cost': 350,
            'vendor': 'AutoService',
          }),
        ],
      ),
      entityDocumentsProvider.overrideWith(
        (ref, request) async => [
          CompanyDocument.fromJson({
            'id': 1,
            'title': 'cmr',
            'category': 'cmr',
            'file_name': 'cmr_transport_1.pdf',
            'uploaded_by': 'admin',
            'uploaded_at': '2026-07-15T10:00:00',
          }),
        ],
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: TruckDetailScreen(truckId: 't1'),
    ),
  );
}

void main() {
  group('TruckDetailScreen — 4 tabs', () {
    testWidgets('renders the four tabs (Overview/Maintenance/Documents/Assignments)',
        (tester) async {
      await tester.pumpWidget(_wrap(user: _adminUser));
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Assignments'), findsOneWidget);
    });

    testWidgets('overview shows plate, VIN, year, health and current driver',
        (tester) async {
      await tester.pumpWidget(_wrap(user: _adminUser));
      await tester.pumpAndSettle();

      expect(find.text('Volvo FH16'), findsOneWidget);
      expect(find.text('B-100-ABC'), findsOneWidget);
      expect(find.text('VIN123'), findsOneWidget);
      expect(find.text('2021'), findsOneWidget);
      expect(find.text('d7'), findsOneWidget);
    });

    testWidgets('maintenance tab lists records', (tester) async {
      await tester.pumpWidget(_wrap(user: _adminUser));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Maintenance'));
      await tester.pumpAndSettle();

      expect(find.text('oil_change'), findsOneWidget);
      expect(find.textContaining('AutoService'), findsOneWidget);
      expect(find.text('350.00 RON'), findsOneWidget);
    });

    testWidgets('documents tab lists entity-scoped documents', (tester) async {
      await tester.pumpWidget(_wrap(user: _adminUser));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();

      expect(find.text('cmr_transport_1.pdf'), findsOneWidget);
      expect(find.text('cmr'), findsOneWidget);
    });

    testWidgets('documents tab shows empty state when no documents',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => _adminUser),
          truckDetailProvider.overrideWith(
            (ref, id) async => TruckDetailData(truck: _truck, fromCache: false),
          ),
          truckMaintenanceHistoryProvider.overrideWith(
            (ref, id) async => <TruckMaintenanceRecord>[],
          ),
          entityDocumentsProvider.overrideWith(
            (ref, request) async => <CompanyDocument>[],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: TruckDetailScreen(truckId: 't1'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();

      expect(find.text('No documents'), findsOneWidget);
    });
  });

  group('TruckDetailScreen — RBAC gating (§8.2)', () {
    testWidgets('decommission popup is ABSENT for dispatcher', (tester) async {
      await tester.pumpWidget(_wrap(user: _dispatcherUser));
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('decommission popup present for admin (can_delete_vehicle)',
        (tester) async {
      await tester.pumpWidget(_wrap(user: _adminUser));
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });
  });
}
