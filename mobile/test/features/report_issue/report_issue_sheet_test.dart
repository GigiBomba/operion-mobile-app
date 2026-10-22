import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/document_endpoints.dart';
import 'package:operion_mobile/core/network/endpoints/issue_endpoints.dart';
import 'package:operion_mobile/core/providers/issue_providers.dart';
import 'package:operion_mobile/features/document_center/providers/document_center_providers.dart';
import 'package:operion_mobile/features/report_issue/data/report_conversation_store.dart';
import 'package:operion_mobile/features/report_issue/providers/report_issue_providers.dart';
import 'package:operion_mobile/features/report_issue/screens/report_issue_sheet.dart';
import 'package:operion_mobile/l10n/app_localizations.dart';
import 'package:operion_mobile/shared/models/user.dart';
import '../../support/test_helpers.dart';

const _user = User(
  id: 'u1',
  email: 'customer@operion.ro',
  fullName: 'Customer',
  role: 'admin',
  companyId: 'c1',
);

ApiClient _apiClient() => ApiClient.create(
  baseUrl: 'https://api.test.com',
  getAccessToken: () async => null,
);

/// In-memory endpoints so widget tests never touch Dio.
class _FakeIssueEndpoints extends IssueEndpoints {
  _FakeIssueEndpoints() : super(_apiClient());

  Map<String, dynamic> threadResponse = <String, dynamic>{
    'conversation_id': 'conv-1',
    'status': 'awaiting_reply',
    'requires_reply': true,
    'resolved': false,
    'entries': <Map<String, dynamic>>[],
  };
  Map<String, dynamic> submitResponse = <String, dynamic>{
    'conversation_id': 'conv-new',
    'reply': '',
    'requires_reply': false,
  };
  Map<String, dynamic> replyResponse = <String, dynamic>{
    'conversation_id': 'conv-1',
    'reply': 'We found the bug and deployed a fix.',
    'requires_reply': false,
  };
  Object? threadError;

  final List<Map<String, Object?>> submissions = [];
  final List<Map<String, Object?>> replies = [];

  @override
  Future<Response<dynamic>> submitIssue({
    String? conversationId,
    required String message,
    String channel = IssueEndpoints.inAppChannel,
    String environment = IssueEndpoints.mobileEnvironment,
  }) async {
    submissions.add({
      'conversationId': conversationId,
      'message': message,
      'channel': channel,
      'environment': environment,
    });
    return Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      data: submitResponse,
      statusCode: 200,
    );
  }

  @override
  Future<Response<dynamic>> getThread(String conversationId) async {
    if (threadError != null) throw threadError!;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      data: threadResponse,
      statusCode: 200,
    );
  }

  @override
  Future<Response<dynamic>> replyToThread(
    String conversationId,
    String message,
  ) async {
    replies.add({'conversationId': conversationId, 'message': message});
    // Mirror the backend: the reply is appended to the thread and the loop
    // reaches a terminal outcome, so a follow-up refresh returns the resolved
    // thread.
    final previous = (threadResponse['entries'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    threadResponse = <String, dynamic>{
      'conversation_id': conversationId,
      'status': 'resolved',
      'requires_reply': false,
      'resolved': true,
      'entries': <Map<String, dynamic>>[
        ...previous,
        <String, dynamic>{'role': 'customer', 'text': message},
        <String, dynamic>{'role': 'argo', 'text': replyResponse['reply']},
      ],
    };
    return Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      data: replyResponse,
      statusCode: 200,
    );
  }
}

class _FakeDocumentEndpoints extends DocumentEndpoints {
  _FakeDocumentEndpoints() : super(_apiClient());

  final List<Map<String, Object?>> uploads = [];

  @override
  Future<Response<dynamic>> uploadDocument({
    required String category,
    required String entityType,
    String? entityId,
    required String filePath,
  }) async {
    uploads.add({
      'category': category,
      'entityType': entityType,
      'entityId': entityId,
      'filePath': filePath,
    });
    return Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      data: <String, dynamic>{'id': 'doc-1'},
      statusCode: 200,
    );
  }
}

class _FakeScreenshotPicker extends ReportScreenshotPicker {
  @override
  Future<XFile?> pickFromGallery() async => XFile('report-shot.png');
}

Widget _app({
  required IssueEndpoints endpoints,
  DocumentEndpoints? documents,
  ReportScreenshotPicker? picker,
  Widget? home,
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => _user),
      issueEndpointsProvider.overrideWithValue(endpoints),
      if (documents != null)
        documentEndpointsProvider.overrideWithValue(documents),
      if (picker != null)
        reportScreenshotPickerProvider.overrideWithValue(picker),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home:
          home ??
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showReportIssueSheet(context),
                  child: const Text('open-report-sheet'),
                ),
              ),
            ),
          ),
    ),
  );
}

void main() {
  final loc = AppLocalizations(const Locale('en'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Compose mode', () {
    testWidgets('submit is disabled below 10 characters', (tester) async {
      usePhoneSurface(tester);
      final endpoints = _FakeIssueEndpoints();
      await tester.pumpWidget(_app(endpoints: endpoints));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open-report-sheet'));
      await tester.pumpAndSettle();

      expect(find.text(loc.reportIssue_title), findsOneWidget);
      expect(find.text(loc.reportIssue_composeIntro), findsOneWidget);

      final submitFinder = find.widgetWithText(ElevatedButton, 'Submit');
      expect(tester.widget<ElevatedButton>(submitFinder).onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'Too short');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submitFinder).onPressed, isNull);
      expect(find.text(loc.reportIssue_minChars), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).first,
        'Invoices crash on save',
      );
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submitFinder).onPressed, isNotNull);
    });

    testWidgets('submits the message with channel/environment and shows ack', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final endpoints = _FakeIssueEndpoints();
      await tester.pumpWidget(_app(endpoints: endpoints));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open-report-sheet'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'Invoices crash when I press save',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(endpoints.submissions, hasLength(1));
      expect(
        endpoints.submissions.single['message'],
        equals('Invoices crash when I press save'),
      );
      expect(endpoints.submissions.single['channel'], equals('in_app'));
      expect(endpoints.submissions.single['environment'], equals('mobile'));
      expect(endpoints.submissions.single['conversationId'], isNull);

      // Confirmation state replaces the form.
      expect(find.text(loc.reportIssue_ack), findsOneWidget);
      expect(find.text(loc.reportIssue_done), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Submit'), findsNothing);

      // Blueprint 41.3d: the sheet closes by itself after the ack.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text(loc.reportIssue_title), findsNothing);
    });

    testWidgets('attaches a screenshot and references the document id', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final endpoints = _FakeIssueEndpoints();
      final documents = _FakeDocumentEndpoints();
      await tester.pumpWidget(
        _app(
          endpoints: endpoints,
          documents: documents,
          picker: _FakeScreenshotPicker(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open-report-sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(loc.reportIssue_attachScreenshot));
      await tester.pumpAndSettle();
      expect(find.text('report-shot.png'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).first,
        'The dashboard renders blank after login',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(documents.uploads, hasLength(1));
      expect(documents.uploads.single['category'], equals('other'));
      expect(documents.uploads.single['entityType'], equals('support_report'));
      expect(
        endpoints.submissions.single['message'],
        contains('Screenshot attached (document doc-1).'),
      );
    });
  });

  group('Thread mode', () {
    _FakeIssueEndpoints threadEndpoints({
      required String status,
      required bool requiresReply,
      required bool resolved,
    }) {
      final endpoints = _FakeIssueEndpoints();
      endpoints.threadResponse = <String, dynamic>{
        'conversation_id': 'conv-1',
        'status': status,
        'requires_reply': requiresReply,
        'resolved': resolved,
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
      };
      return endpoints;
    }

    testWidgets('renders status, original report and ARGO reply', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final endpoints = threadEndpoints(
        status: 'awaiting_reply',
        requiresReply: true,
        resolved: false,
      );
      await tester.pumpWidget(
        _app(
          endpoints: endpoints,
          home: const Scaffold(
            body: ReportIssueSheet(conversationId: 'conv-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(loc.reportIssue_threadTitle), findsOneWidget);
      expect(find.text(loc.reportIssue_statusLogged), findsOneWidget);
      expect(find.text(loc.reportIssue_originalReport), findsOneWidget);
      expect(find.text('Invoices crash when I press save'), findsOneWidget);
      expect(find.text(loc.reportIssue_argoSupport), findsOneWidget);
      expect(find.text('Which screen were you on?'), findsOneWidget);
      // The reply composer is visible only while ARGO awaits an answer.
      expect(find.text(loc.reportIssue_replyHint), findsOneWidget);
      expect(find.text(loc.reportIssue_newIssue), findsNothing);
    });

    testWidgets(
      'resolved thread hides the reply input and offers a new report',
      (tester) async {
        usePhoneSurface(tester);
        final endpoints = threadEndpoints(
          status: 'resolved',
          requiresReply: false,
          resolved: true,
        );
        await tester.pumpWidget(
          _app(
            endpoints: endpoints,
            home: const Scaffold(
              body: ReportIssueSheet(conversationId: 'conv-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(loc.reportIssue_statusFixed), findsOneWidget);
        expect(find.text(loc.reportIssue_resolvedNote), findsOneWidget);
        expect(find.text(loc.reportIssue_replyHint), findsNothing);
        expect(find.byTooltip(loc.reportIssue_replySend), findsNothing);

        final newIssue = find.widgetWithText(
          ElevatedButton,
          loc.reportIssue_newIssue,
        );
        expect(newIssue, findsOneWidget);

        await tester.tap(newIssue);
        await tester.pumpAndSettle();
        expect(find.text(loc.reportIssue_composeIntro), findsOneWidget);
        expect(find.text(loc.reportIssue_title), findsOneWidget);
      },
    );

    testWidgets('waiting thread (no pending question) hides the reply input', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final endpoints = threadEndpoints(
        status: 'being_investigated',
        requiresReply: false,
        resolved: false,
      );
      await tester.pumpWidget(
        _app(
          endpoints: endpoints,
          home: const Scaffold(
            body: ReportIssueSheet(conversationId: 'conv-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(loc.reportIssue_statusBeingInvestigated),
        findsOneWidget,
      );
      expect(find.text(loc.reportIssue_waiting), findsOneWidget);
      expect(find.text(loc.reportIssue_replyHint), findsNothing);
    });

    testWidgets('sends a reply and appends the terminal ARGO answer', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final endpoints = threadEndpoints(
        status: 'awaiting_reply',
        requiresReply: true,
        resolved: false,
      );
      await tester.pumpWidget(
        _app(
          endpoints: endpoints,
          home: const Scaffold(
            body: ReportIssueSheet(conversationId: 'conv-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'The invoices list screen',
      );
      await tester.tap(find.byTooltip(loc.reportIssue_replySend));
      await tester.pumpAndSettle();

      expect(endpoints.replies, hasLength(1));
      expect(endpoints.replies.single['conversationId'], equals('conv-1'));
      expect(
        endpoints.replies.single['message'],
        equals('The invoices list screen'),
      );
      expect(find.text('The invoices list screen'), findsOneWidget);
      expect(find.text('We found the bug and deployed a fix.'), findsOneWidget);
      expect(find.text(loc.reportIssue_replyHint), findsNothing);
      expect(find.text(loc.reportIssue_newIssue), findsOneWidget);
    });

    testWidgets('thread load failure shows an inline error with retry', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final endpoints = _FakeIssueEndpoints()
        ..threadError = DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: ''),
            statusCode: 500,
          ),
        );
      await tester.pumpWidget(
        _app(
          endpoints: endpoints,
          home: const Scaffold(
            body: ReportIssueSheet(conversationId: 'conv-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(loc.reportIssue_threadError), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, loc.general_retry),
        findsOneWidget,
      );
    });
  });

  group('ReportConversationStore', () {
    test('scopes the conversation id by company and user', () async {
      final store = ReportConversationStore();
      await store.write(
        companyId: 'c1',
        userId: 'u1',
        conversationId: 'conv-1',
      );

      expect(await store.read(companyId: 'c1', userId: 'u1'), equals('conv-1'));
      expect(await store.read(companyId: 'c1', userId: 'u2'), isNull);
      expect(await store.read(companyId: 'c2', userId: 'u1'), isNull);

      await store.clear(companyId: 'c1', userId: 'u1');
      expect(await store.read(companyId: 'c1', userId: 'u1'), isNull);
    });
  });
}
