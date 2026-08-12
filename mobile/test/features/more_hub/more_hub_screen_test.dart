import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/driver_endpoints.dart';
import 'package:operion_mobile/features/driver/home/driver_providers.dart';
import 'package:operion_mobile/features/driver/messages/message_list_screen.dart';
import 'package:operion_mobile/features/more_hub/screens/more_hub_screen.dart';
import 'package:operion_mobile/l10n/app_localizations.dart';
import 'package:operion_mobile/shared/models/user.dart';
import 'package:operion_mobile/shared/widgets/app_card.dart';

const _adminUser = User(
  id: 'u2',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

/// Stub that resolves driver endpoint calls without touching the network.
class _StubDriverEndpoints extends DriverEndpoints {
  _StubDriverEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => null,
        ));

  @override
  Future<Response> getMessages() async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: <dynamic>[],
    );
  }
}

/// Records route pushes so tests can assert navigation targets.
class _PushingObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }
}

Widget createTestApp({
  Locale locale = const Locale('en'),
  List<NavigatorObserver>? observers,
  List<Override>? overrides,
}) {
  return ProviderScope(
    overrides: [
      isOfflineProvider.overrideWith((ref) => false),
      currentUserProvider.overrideWith((ref) => _adminUser),
      ...?overrides,
    ],
    child: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: observers ?? const [],
        home: const MoreHubScreen(),
      ),
    ),
  );
}

void main() {
  group('MoreHubScreen', () {
    for (final locale in [const Locale('en'), const Locale('ro')]) {
      testWidgets(
        'renders 14 tiles in _tiles order with non-empty labels '
        '(${locale.languageCode})',
        (tester) async {
          await tester.pumpWidget(createTestApp(locale: locale));
          await tester.pumpAndSettle();

          // Verify the grid exists.
          expect(find.byType(GridView), findsOneWidget);

          // Exactly 14 AppCard tiles are rendered (Team Management +
          // Tachograph added in Phase 4B — blueprint §2 rows 13/19/20).
          final cards = find.descendant(
            of: find.byType(GridView),
            matching: find.byType(AppCard),
          );
          expect(cards, findsNWidgets(14));

          // Verify the tiles render in the exact order of `_tiles`.
          final loc = AppLocalizations(locale);
          final expectedLabels = [
            loc.nav_messages,
            loc.nav_analytics,
            loc.nav_jobs,
            loc.nav_alerts,
            loc.nav_profitCalculator,
            loc.nav_routePlanner,
            loc.nav_freightExchange,
            loc.nav_documentCenter,
            loc.nav_localDownload,
            loc.nav_invoicing,
            loc.nav_maintenance,
            loc.nav_teamsManagement,
            loc.nav_tachograph,
            loc.nav_settings,
          ];

          final actualLabels = <String>[];
          for (final cardWidget in tester.widgetList<AppCard>(cards)) {
            final textFinder = find.descendant(
              of: find.byWidget(cardWidget),
              matching: find.byType(Text),
            );
            expect(textFinder, findsOneWidget,
                reason: 'Every tile must render exactly one label Text');
            actualLabels.add(tester.widget<Text>(textFinder).data!);
          }

          expect(actualLabels, expectedLabels,
              reason: 'Tiles must render in the exact order of `_tiles`');

          for (final label in actualLabels) {
            expect(label.trim(), isNotEmpty,
                reason: 'Every tile label must be resolved and non-empty');
          }
        },
      );
    }

    testWidgets('tapping the first tile (nav_messages) pushes MessageListScreen',
        (tester) async {
      final observer = _PushingObserver();
      await tester.pumpWidget(createTestApp(
        observers: [observer],
        overrides: [
          driverEndpointsProvider.overrideWithValue(_StubDriverEndpoints()),
        ],
      ));
      await tester.pumpAndSettle();

      // The first tile in `_tiles` is nav_messages.
      expect(find.text('Messages'), findsOneWidget);

      // Ignore the initial `/` route push recorded by the observer.
      observer.pushedRoutes.clear();
      await tester.tap(find.text('Messages'));

      // Drive the navigation push manually (no pumpAndSettle: the pushed
      // screen renders a shimmer loader while its provider resolves).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(observer.pushedRoutes, hasLength(1),
          reason: 'Tapping the first tile must push exactly one route');
      expect(find.byType(MessageListScreen), findsOneWidget,
          reason: 'nav_messages must navigate to MessageListScreen');
    });

    testWidgets(
        'dispatcher sees no Invoicing/Maintenance/Team Management tiles '
        '(gated absent, not disabled)', (tester) async {
      const dispatcher = User(
        id: 'u1',
        email: 'dispatcher@operion.ro',
        fullName: 'Dispatcher',
        role: 'dispatcher',
        companyId: 'c1',
      );
      await tester.pumpWidget(createTestApp(
        overrides: [
          currentUserProvider.overrideWith((ref) => dispatcher),
        ],
      ));
      await tester.pumpAndSettle();

      final cards = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(AppCard),
      );
      // 10 un-gated tiles remain: 14 total − analytics (can_view_analytics) −
      // invoicing (can_create_invoice) − maintenance (can_schedule_maintenance)
      // − team management (can_manage_users), all four denied to dispatcher per
      // the real permission matrix. Tachograph (can_upload_document) IS shown.
      expect(cards, findsNWidgets(10));

      final loc = AppLocalizations(const Locale('en'));
      expect(find.text(loc.nav_invoicing), findsNothing,
          reason: 'Invoicing tile must be absent for dispatcher (§8.2)');
      expect(find.text(loc.nav_maintenance), findsNothing,
          reason: 'Maintenance tile must be absent for dispatcher (§8.2)');
      expect(find.text(loc.nav_teamsManagement), findsNothing,
          reason: 'Team Management tile must be absent for dispatcher (§8.2)');
      expect(find.text(loc.nav_tachograph), findsOneWidget,
          reason: 'Tachograph tile is gated can_upload_document (dispatcher has it)');
    });

    testWidgets('admin sees the Invoicing, Maintenance, Team Management and '
        'Tachograph tiles', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final loc = AppLocalizations(const Locale('en'));
      expect(find.text(loc.nav_invoicing), findsOneWidget);
      expect(find.text(loc.nav_maintenance), findsOneWidget);
      expect(find.text(loc.nav_teamsManagement), findsOneWidget);
      expect(find.text(loc.nav_tachograph), findsOneWidget);
    });
  });
}
