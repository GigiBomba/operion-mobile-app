import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/clients/screens/client_detail_screen.dart';
import 'package:operion_mobile/features/fleet/screens/truck_detail_screen.dart';
import 'package:operion_mobile/features/global_search/providers/global_search_providers.dart';
import 'package:operion_mobile/features/global_search/screens/global_search_screen.dart';
import 'package:operion_mobile/shared/widgets/empty_state.dart';

class _Stub extends SearchEndpoints {
  _Stub()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  int calls = 0;

  @override
  Future<Response> search(
    String query, {
    String? types,
    CancelToken? cancelToken,
  }) async {
    calls++;
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'trips': {
          'items': List.generate(5, (i) => {'id': i, 'name': 'Trip $i'}),
          'total_count': 12,
        },
        'clients': {
          'items': [
            {'id': 'c1', 'name': 'ACME'},
          ],
          'total_count': 3,
        },
        'drivers': {
          'items': [
            {'id': 'd1', 'name': 'Ion'},
          ],
          'total_count': 1,
        },
        'trucks': {
          'items': [
            {'id': 't1', 'name': 'B-100'},
          ],
          'total_count': 1,
        },
        'documents': {'items': [], 'total_count': 0},
      },
      statusCode: 200,
    );
  }
}

class _EmptyStub extends SearchEndpoints {
  _EmptyStub()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  @override
  Future<Response> search(
    String query, {
    String? types,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'trips': {'items': [], 'total_count': 0},
        'clients': {'items': [], 'total_count': 0},
        'drivers': {'items': [], 'total_count': 0},
        'trucks': {'items': [], 'total_count': 0},
        'documents': {'items': [], 'total_count': 0},
      },
      statusCode: 200,
    );
  }
}

Widget _app(SearchEndpoints endpoints) {
  return ProviderScope(
    overrides: [searchEndpointsProvider.overrideWithValue(endpoints)],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: GlobalSearchScreen(),
    ),
  );
}

void main() {
  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    // Advance past the 350ms debounce.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('shows min-2-chars hint before query', (tester) async {
    await tester.pumpWidget(_app(_Stub()));
    await tester.pumpAndSettle();

    expect(find.text('Type at least 2 characters'), findsOneWidget);
  });

  testWidgets('renders per-type sections capped at 5 with N more',
      (tester) async {
    await tester.pumpWidget(_app(_Stub()));
    await tester.pumpAndSettle();

    await type(tester, 'ac');
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('7 more'), findsOneWidget); // 12 total, 5 shown.
    expect(find.text('Clients'), findsOneWidget);
    expect(find.text('2 more'), findsOneWidget); // 3 total, 1 shown.
  });

  testWidgets('empty result renders EmptyState', (tester) async {
    await tester.pumpWidget(_app(_EmptyStub()));
    await tester.pumpAndSettle();

    await type(tester, 'zz');
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No results found'), findsOneWidget);
  });

  testWidgets('tapping a client navigates to ClientDetailScreen',
      (tester) async {
    await tester.pumpWidget(_app(_Stub()));
    await tester.pumpAndSettle();

    await type(tester, 'acm');
    await tester.tap(find.text('ACME'));
    await tester.pumpAndSettle();

    expect(find.byType(ClientDetailScreen), findsOneWidget);
  });

  testWidgets('tapping a truck navigates to TruckDetailScreen',
      (tester) async {
    await tester.pumpWidget(_app(_Stub()));
    await tester.pumpAndSettle();

    await type(tester, 'tru');
    final truckFinder = find.text('B-100');
    await tester.scrollUntilVisible(truckFinder, 200,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(truckFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.ancestor(
        of: truckFinder, matching: find.byType(Card)).first,
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(TruckDetailScreen), findsOneWidget);
  });
}
