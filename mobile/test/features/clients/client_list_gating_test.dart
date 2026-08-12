import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/clients/models/client.dart';
import 'package:operion_mobile/features/clients/providers/client_providers.dart';
import 'package:operion_mobile/features/clients/screens/client_list_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';

const _dispatcherUser = User(
  id: 'u1',
  email: 'disp@operion.ro',
  fullName: 'Disp',
  role: 'dispatcher',
  companyId: 'c1',
);

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

const List<Client> _clients = [
  Client(
    id: 'c1',
    companyId: 'c1',
    name: 'ACME Logistics',
    paymentTermsDays: 30,
    rating: 4.5,
  ),
  Client(
    id: 'c2',
    companyId: 'c1',
    name: 'Beta SRL',
    paymentTermsDays: 14,
    rating: 3.0,
  ),
];

Widget _wrap(User user, {bool empty = false}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      clientListProvider.overrideWith(
        (ref) async => ClientListData(
          clients: empty ? const [] : _clients,
          fromCache: false,
        ),
      ),
      clientCachedBannerProvider.overrideWith((ref) => false),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ClientListScreen(),
    ),
  );
}

void main() {
  group('ClientListScreen — RBAC gating (§8.2)', () {
    testWidgets('FAB is ABSENT for dispatcher (no can_create_client)',
        (tester) async {
      await tester.pumpWidget(_wrap(_dispatcherUser));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('FAB is present for admin (can_create_client)', (tester) async {
      await tester.pumpWidget(_wrap(_adminUser));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('empty state renders when there are no clients', (tester) async {
      await tester.pumpWidget(_wrap(_adminUser, empty: true));
      await tester.pumpAndSettle();

      expect(find.text('No clients yet'), findsOneWidget);
    });
  });
}
