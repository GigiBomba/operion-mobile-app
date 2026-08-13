import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/clients/models/client.dart';
import 'package:operion_mobile/features/clients/providers/client_providers.dart';
import 'package:operion_mobile/features/clients/screens/client_detail_screen.dart';
import 'package:operion_mobile/features/clients/screens/client_list_screen.dart';
import 'package:operion_mobile/shared/models/user.dart';
import '../../helpers/golden_fonts.dart';

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

final Client _client = Client.fromJson({
  'id': 'c1',
  'company_id': 'c1',
  'name': 'ACME Logistics',
  'vat_number': 'RO12345',
  'address': 'Bucuresti, Str. Exemplu 10',
  'payment_terms_days': 30,
  'rating': 4.5,
  'is_active': true,
  'contacts': [
    {'id': 1, 'name': 'Ion Popescu', 'role': 'manager', 'phone': '0700', 'email': 'ion@acme.ro'},
  ],
  'recent_trip_count': 12,
  'recent_invoice_count': 5,
});

List<Override> _overrides() => [
      currentUserProvider.overrideWith((ref) => _adminUser),
      clientListProvider.overrideWith(
        (ref) async => ClientListData(clients: [_client], fromCache: false),
      ),
      clientCachedBannerProvider.overrideWith((ref) => false),
      clientDetailProvider.overrideWith(
        (ref, id) async => ClientDetailData(client: _client, fromCache: false),
      ),
    ];

Widget _app(Widget child, {Brightness brightness = Brightness.light}) {
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
      home: child,
    ),
  );
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Widget child,
  String file, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(child, brightness: brightness));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(Scaffold),
    matchesGoldenFile(file),
  );
}

void main() {
  setUpAll(loadGoldenFonts);
  testWidgets('ClientListScreen golden (light)', (tester) async {
    await _pumpGolden(tester, const ClientListScreen(), goldenFile('client_list_light'));
  });

  testWidgets('ClientListScreen golden (dark)', (tester) async {
    await _pumpGolden(
      tester,
      const ClientListScreen(),
      goldenFile('client_list_dark'),
      brightness: Brightness.dark,
    );
  });

  testWidgets('ClientDetailScreen golden (light)', (tester) async {
    await _pumpGolden(
      tester,
      const ClientDetailScreen(clientId: 'c1'),
      goldenFile('client_detail_light'),
    );
  });

  testWidgets('ClientDetailScreen golden (dark)', (tester) async {
    await _pumpGolden(
      tester,
      const ClientDetailScreen(clientId: 'c1'),
      goldenFile('client_detail_dark'),
      brightness: Brightness.dark,
    );
  });
}