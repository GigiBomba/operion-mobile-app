import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/issue_endpoints.dart';
import 'package:operion_mobile/core/providers/issue_providers.dart';
import 'package:operion_mobile/features/more_hub/screens/more_hub_screen.dart';
import 'package:operion_mobile/features/report_issue/data/report_conversation_store.dart';
import 'package:operion_mobile/features/report_issue/providers/report_issue_providers.dart';
import 'package:operion_mobile/features/report_issue/screens/report_issue_sheet.dart';
import 'package:operion_mobile/l10n/app_localizations.dart';
import 'package:operion_mobile/shared/models/user.dart';
import 'package:operion_mobile/shared/widgets/app_card.dart';

import '../../support/test_helpers.dart';

const _adminUser = User(
  id: 'u1',
  email: 'admin@operion.ro',
  fullName: 'Admin',
  role: 'admin',
  companyId: 'c1',
);

const _badgeKey = Key('moreTileBadgeDot');

/// Serves a thread whose ARGO question still awaits an answer.
class _PendingThreadEndpoints extends IssueEndpoints {
  _PendingThreadEndpoints()
    : super(
        ApiClient.create(
          baseUrl: 'https://api.test.com',
          getAccessToken: () async => null,
        ),
      );

  @override
  Future<Response<dynamic>> getThread(String conversationId) async {
    return Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      statusCode: 200,
      data: <String, dynamic>{
        'conversation_id': conversationId,
        'status': 'awaiting_reply',
        'requires_reply': true,
        'resolved': false,
        'entries': <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'customer',
            'text': 'Invoices crash when I press save',
          },
          <String, dynamic>{
            'role': 'argo',
            'text': 'Which screen were you on?',
          },
        ],
      },
    );
  }
}

Widget _moreHub({bool? badge, List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      isOfflineProvider.overrideWith((ref) => false),
      currentUserProvider.overrideWith((ref) => _adminUser),
      if (badge != null) reportIssueBadgeProvider.overrideWithValue(badge),
      ...overrides,
    ],
    child: const MediaQuery(
      data: MediaQueryData(size: Size(390, 844)),
      child: MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: MoreHubScreen(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('More tab Report an Issue entry', () {
    testWidgets('renders the tile with a badge dot when a reply is pending', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_moreHub(badge: true));
      await tester.pumpAndSettle();

      final loc = AppLocalizations(const Locale('en'));
      expect(find.text(loc.nav_reportIssue), findsOneWidget);
      expect(find.byKey(_badgeKey), findsOneWidget);
      expect(find.byTooltip(loc.reportIssue_badgeTooltip), findsOneWidget);
    });

    testWidgets('renders no badge dot when no reply is pending', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_moreHub(badge: false));
      await tester.pumpAndSettle();

      expect(find.byKey(_badgeKey), findsNothing);
    });

    testWidgets('badge is driven by the loaded thread requires_reply flag', (
      tester,
    ) async {
      usePhoneSurface(tester);
      SharedPreferences.setMockInitialValues(<String, Object>{
        ReportConversationStore.storageKeyFor(companyId: 'c1', userId: 'u1'):
            'conv-1',
      });

      await tester.pumpWidget(
        _moreHub(
          overrides: [
            issueEndpointsProvider.overrideWithValue(_PendingThreadEndpoints()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_badgeKey), findsOneWidget);
    });

    testWidgets('tapping the tile opens the Report an Issue bottom sheet', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_moreHub(badge: false));
      await tester.pumpAndSettle();

      final loc = AppLocalizations(const Locale('en'));
      await tester.ensureVisible(find.text(loc.nav_reportIssue));
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.nav_reportIssue));
      await tester.pumpAndSettle();

      expect(find.byType(ReportIssueSheet), findsOneWidget);
      expect(find.text(loc.reportIssue_composeIntro), findsOneWidget);
      // The sheet is a route above the More tab, not a full-screen push that
      // replaces it.
      expect(find.byType(MoreHubScreen), findsOneWidget);
      expect(find.byType(AppCard), findsWidgets);
    });
  });
}
