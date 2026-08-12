import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/freight_exchange/models/freight_negotiation.dart';
import 'package:operion_mobile/features/freight_exchange/providers/freight_exchange_providers.dart';
import 'package:operion_mobile/features/freight_exchange/providers/freight_negotiation_providers.dart';
import 'package:operion_mobile/features/freight_exchange/screens/freight_load_detail_screen.dart';

// ── Fixtures ───────────────────────────────────────────────────────────────

Map<String, dynamic> negotiationJson({
  String id = 'n1',
  String direction = 'to',
  String status = 'offered',
  double amount = 1850.0,
  String? counterparty = 'Exchange A',
  String? parentId,
}) =>
    {
      'id': id,
      'provider_id': 'exch-a',
      'provider_load_id': 'load-1',
      'direction': direction,
      'status': status,
      'amount_eur': amount,
      'currency': 'EUR',
      'counterparty_name': counterparty,
      'parent_negotiation_id': parentId,
      'created_at': '2026-08-01T10:00:00Z',
    };

Map<String, dynamic> threadFixture({List<Map<String, dynamic>>? records}) =>
    {'thread': records ?? [negotiationJson()]};

// ── Endpoints stub ────────────────────────────────────────────────────────

class _StubFreightEndpoints extends FreightEndpoints {
  _StubFreightEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<String> getPaths = [];
  final List<({String action, double? amount, String? counterparty})> posts = [];

  Map<String, dynamic> threadResponse = threadFixture();
  bool throwGet = false;

  @override
  Future<Response> getNegotiationThread(
    String providerId,
    String loadId, {
    CancelToken? cancelToken,
  }) async {
    getPaths.add('/$providerId/$loadId');
    if (throwGet) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      );
    }
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: threadResponse,
      statusCode: 200,
    );
  }

  @override
  Future<Response> postNegotiationAction(
    String providerId,
    String loadId, {
    required String action,
    double? amountEur,
    String? counterpartyName,
    CancelToken? cancelToken,
  }) async {
    posts.add((action: action, amount: amountEur, counterparty: counterpartyName));
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'negotiation': negotiationJson(status: action)},
      statusCode: 200,
    );
  }
}

ProviderContainer _container({
  bool offline = false,
  _StubFreightEndpoints? endpoints,
}) {
  return ProviderContainer(
    overrides: [
      isOfflineProvider.overrideWith((ref) => offline),
      freightEndpointsProvider.overrideWithValue(endpoints ?? _StubFreightEndpoints()),
    ],
  );
}

// ── Model tests ───────────────────────────────────────────────────────────

void main() {
  group('FreightNegotiation model', () {
    test('fromJson parses every field', () {
      final record = FreightNegotiation.fromJson(negotiationJson());
      expect(record.id, 'n1');
      expect(record.providerId, 'exch-a');
      expect(record.providerLoadId, 'load-1');
      expect(record.direction, FreightNegotiationDirection.to);
      expect(record.status, FreightNegotiationStatus.offered);
      expect(record.amountEur, 1850.0);
      expect(record.currency, 'EUR');
      expect(record.counterpartyName, 'Exchange A');
      expect(record.parentNegotiationId, isNull);
      expect(record.createdAt, isNotNull);
    });

    test('thread parses the array + latest/isSettled helpers', () {
      final thread = FreightNegotiationThread.fromJson(threadFixture());
      expect(thread.isEmpty, isFalse);
      expect(thread.latest!.id, 'n1');
      expect(thread.isSettled, isFalse);

      final settled = FreightNegotiationThread.fromJson(threadFixture(
        records: [negotiationJson(status: 'accepted')],
      ));
      expect(settled.isSettled, isTrue);
    });

    test('fromApiString maps backend inbound/outbound + legacy to/from', () {
      expect(FreightNegotiationDirection.fromApiString('outbound'),
          FreightNegotiationDirection.from);
      expect(FreightNegotiationDirection.fromApiString('inbound'),
          FreightNegotiationDirection.to);
      expect(FreightNegotiationDirection.fromApiString('from'),
          FreightNegotiationDirection.from);
      expect(FreightNegotiationDirection.fromApiString('to'),
          FreightNegotiationDirection.to);
    });

    test('fromApiString tolerates unknown status/direction', () {
      expect(FreightNegotiationStatus.fromApiString('bogus'),
          FreightNegotiationStatus.offered);
      expect(FreightNegotiationDirection.fromApiString('bogus'),
          FreightNegotiationDirection.to);
    });
  });

  // ── Thread provider ─────────────────────────────────────────────────────
  group('freightNegotiationProvider', () {
    test('fetches the thread for the target', () async {
      final endpoints = _StubFreightEndpoints();
      final container = _container(endpoints: endpoints);
      addTearDown(container.dispose);

      final thread = await container
          .read(freightNegotiationProvider(
              (providerId: 'exch-a', loadId: 'load-1')).future);

      expect(endpoints.getPaths, ['/exch-a/load-1']);
      expect(thread.items.single.amountEur, 1850.0);
    });

    test('surfaces an error when the fetch fails', () async {
      final endpoints = _StubFreightEndpoints()..throwGet = true;
      final container = _container(endpoints: endpoints);
      addTearDown(container.dispose);

      expect(
        container
            .read(freightNegotiationProvider(
                (providerId: 'exch-a', loadId: 'load-1')).future),
        throwsA(isA<DioException>()),
      );
    });
  });

  // ── Notifier actions ────────────────────────────────────────────────────
  group('FreightNegotiationNotifier', () {
    test('accept/reject/counter post the right action and invalidate',
        () async {
      final endpoints = _StubFreightEndpoints();
      final container = _container(endpoints: endpoints);
      addTearDown(container.dispose);

      // Prime the thread (1 GET).
      await container
          .read(freightNegotiationProvider(
              (providerId: 'exch-a', loadId: 'load-1')).future);
      expect(endpoints.getPaths, hasLength(1));

      final notifier = container.read(freightNegotiationActionProvider.notifier);
      expect(
        await notifier.accept(providerId: 'exch-a', loadId: 'load-1'),
        isTrue,
      );
      expect(
        await notifier.reject(providerId: 'exch-a', loadId: 'load-1'),
        isTrue,
      );
      expect(
        await notifier.counter(
            providerId: 'exch-a', loadId: 'load-1', amountEur: 1900.0),
        isTrue,
      );

      expect(endpoints.posts.map((p) => p.action), ['accept', 'reject', 'counter']);
      expect(endpoints.posts.last.amount, 1900.0);

      // Each successful action invalidated the thread → re-fetch on next read.
      await container
          .read(freightNegotiationProvider(
              (providerId: 'exch-a', loadId: 'load-1')).future);
      expect(endpoints.getPaths, hasLength(2));
      expect(container.read(freightNegotiationActionProvider).busy, isFalse);
    });

    test('offline → blocked with the offline error, endpoint never called',
        () async {
      final endpoints = _StubFreightEndpoints();
      final container = _container(offline: true, endpoints: endpoints);
      addTearDown(container.dispose);

      final notifier = container.read(freightNegotiationActionProvider.notifier);
      expect(
        await notifier.accept(providerId: 'exch-a', loadId: 'load-1'),
        isFalse,
      );
      expect(endpoints.posts, isEmpty);
      expect(container.read(freightNegotiationActionProvider).errorKey,
          'freightNegotiation_offline');
    });

    test('busy guard: concurrent actions collapse to one call', () async {
      final endpoints = _StubFreightEndpoints();
      final container = _container(endpoints: endpoints);
      addTearDown(container.dispose);

      final notifier = container.read(freightNegotiationActionProvider.notifier);
      // First accept is awaited so busy is already true for the second call.
      final first = notifier.accept(providerId: 'exch-a', loadId: 'load-1');
      final second = notifier.reject(providerId: 'exch-a', loadId: 'load-1');
      await Future.wait([first, second]);

      expect(endpoints.posts, hasLength(1));
    });
  });

  // ── Sheet widget ────────────────────────────────────────────────────────
  group('FreightNegotiationSheet', () {
    Widget wrap(
      WidgetTester tester, {
      required _StubFreightEndpoints endpoints,
      bool offline = false,
    }) {
      return ProviderScope(
        overrides: [
          isOfflineProvider.overrideWith((ref) => offline),
          freightEndpointsProvider.overrideWithValue(endpoints),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FreightNegotiationSheet(
              target: (providerId: 'exch-a', loadId: 'load-1'),
              currency: 'EUR',
            ),
          ),
        ),
      );
    }

    testWidgets('renders the thread records with status + amount',
        (tester) async {
      final endpoints = _StubFreightEndpoints();
      await tester.pumpWidget(wrap(tester, endpoints: endpoints));
      await tester.pumpAndSettle();

      expect(find.text('Negotiation'), findsOneWidget);
      expect(find.text('Offered'), findsWidgets);
      expect(find.text('1850.00 EUR'), findsWidgets);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Counter'), findsOneWidget);
    });

    testWidgets('backend inbound/outbound directions render "You" on '
        'outbound rows', (tester) async {
      final endpoints = _StubFreightEndpoints()
        ..threadResponse = threadFixture(records: [
          negotiationJson(id: 'n1', direction: 'inbound', amount: 1850.0),
          negotiationJson(
            id: 'n2',
            direction: 'outbound',
            amount: 1900.0,
            counterparty: null,
          ),
        ]);
      await tester.pumpWidget(wrap(tester, endpoints: endpoints));
      await tester.pumpAndSettle();

      // The inbound row is attributed to the counterparty; the outbound
      // (company) row renders the localized "You" author label. (The author
      // line is `'<author> · <relative time>'`, so match by substring.)
      expect(find.text('1850.00 EUR'), findsOneWidget);
      expect(find.text('1900.00 EUR'), findsOneWidget);
      expect(find.textContaining('Exchange A'), findsOneWidget);
      expect(find.textContaining('You'), findsOneWidget);
    });

    testWidgets('counter flow: expands amount field and posts counter',
        (tester) async {
      final endpoints = _StubFreightEndpoints();
      await tester.pumpWidget(wrap(tester, endpoints: endpoints));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Counter'));
      await tester.pumpAndSettle();
      expect(find.text('Counter amount (EUR)'), findsOneWidget);

      await tester.enterText(
          find.byType(TextField), '1900');
      await tester.tap(find.text('Send counter'));
      await tester.pumpAndSettle();

      expect(endpoints.posts.single.action, 'counter');
      expect(endpoints.posts.single.amount, 1900.0);
      expect(find.text('Counter amount (EUR)'), findsNothing,
          reason: 'counter field collapses after a successful send');
    });

    testWidgets('offline: inline message shown and actions disabled',
        (tester) async {
      final endpoints = _StubFreightEndpoints();
      await tester.pumpWidget(
          wrap(tester, endpoints: endpoints, offline: true));
      await tester.pumpAndSettle();

      expect(
        find.text('Negotiation requires an internet connection'),
        findsOneWidget,
      );

      final elevated = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(elevated.onPressed, isNull, reason: 'Accept disabled offline');
    });

    testWidgets('empty thread composes the base offer from the evaluation',
        (tester) async {
      final endpoints = _StubFreightEndpoints()
        ..threadResponse = threadFixture(records: []);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          isOfflineProvider.overrideWith((ref) => false),
          freightEndpointsProvider.overrideWithValue(endpoints),
          freightLoadEvaluationProvider.overrideWith(
            (ref, target) async => const FreightLoadEvaluation(
              estimatedRevenue: 1850.0,
              expectedProfit: 350.0,
              currency: 'EUR',
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FreightNegotiationSheet(
              target: (providerId: 'exch-a', loadId: 'load-1'),
              currency: 'EUR',
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Base offer card from the evaluation provider.
      expect(find.text('Base offer'), findsOneWidget);
      expect(find.text('1850.00 EUR'), findsOneWidget);
      expect(find.text('350.00 EUR'), findsOneWidget);
    });
  });
}
