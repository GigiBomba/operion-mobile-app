import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/history/providers/history_providers.dart';
import 'package:operion_mobile/features/history/screens/trip_history_screen.dart';
import 'package:operion_mobile/shared/widgets/empty_state.dart';

import '../../support/test_helpers.dart';

/// Endpoints stub that records export calls and serves paginated trips.
class _Stub extends HistoryEndpoints {
  _Stub()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  int exportCalls = 0;
  bool offline = false;

  @override
  Future<Response> getTrips(
    TripHistoryFilter filter, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'items': [
          {
            'id': 1,
            'client_name': 'ACME',
            'truck_number': 'B-100',
            'driver_name': 'Ion',
            'origin': 'București',
            'destination': 'Cluj',
            'status': 'Delivered',
            'start_date': '2026-07-01',
            'total_price_eur': 1200,
          },
        ],
        'total': 21,
        'page': filter.page,
        'page_size': 20,
        'total_pages': 2,
      },
      statusCode: 200,
    );
  }

  @override
  Future<Response> exportTrips(
    TripExportRequest request, {
    CancelToken? cancelToken,
  }) async {
    exportCalls++;
    if (offline) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      );
    }
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'job_id': 'job-1'},
      statusCode: 202,
    );
  }

  @override
  Future<Response> exportStatus(
    String jobId, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'status': 'success', 'download_url': 'https://cdn/export.csv'},
      statusCode: 200,
    );
  }
}

Widget _app(HistoryEndpoints endpoints, {bool offline = false}) {
  return ProviderScope(
    overrides: [
      isOfflineProvider.overrideWith((ref) => offline),
      historyEndpointsProvider.overrideWithValue(endpoints),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripHistoryScreen(),
    ),
  );
}

void main() {
  testWidgets('renders trip rows with client/route/status', (tester) async {
      usePhoneSurface(tester);
    await tester.pumpWidget(_app(_Stub()));
    await tester.pumpAndSettle();

    expect(find.text('ACME'), findsOneWidget);
    expect(find.text('București → Cluj'), findsOneWidget);
    expect(find.text('Delivered'), findsWidgets);
  });

  testWidgets('export offline shows inline message + no API call',
      (tester) async {
      usePhoneSurface(tester);
    final stub = _Stub();
    await tester.pumpWidget(_app(stub, offline: true));
    await tester.pumpAndSettle();

    expect(
      find.text('Export requires an internet connection'),
      findsWidgets,
    );
    // Tap the (disabled) export area — nothing should hit the network.
    await tester.tap(find.byIcon(Icons.download_outlined), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(stub.exportCalls, 0);
  });

  testWidgets('export online calls POST and shows started snackbar',
      (tester) async {
      usePhoneSurface(tester);
    final stub = _Stub();
    await tester.pumpWidget(_app(stub));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pumpAndSettle();

    expect(stub.exportCalls, 1);
    expect(find.textContaining('Export started'), findsOneWidget);
  });

  testWidgets('empty trips renders EmptyState', (tester) async {
      usePhoneSurface(tester);
    final stub = _EmptyStub();
    await tester.pumpWidget(_app(stub));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No trips in this period'), findsOneWidget);
  });

  testWidgets('filter chips change status and reload', (tester) async {
      usePhoneSurface(tester);
    final stub = _Stub();
    await tester.pumpWidget(_app(stub));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delivered').first);
    await tester.pumpAndSettle();

    // Status chip selected; list still renders.
    expect(find.text('ACME'), findsOneWidget);
  });
}

class _EmptyStub extends HistoryEndpoints {
  _EmptyStub()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  @override
  Future<Response> getTrips(
    TripHistoryFilter filter, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'items': <dynamic>[],
        'total': 0,
        'page': 1,
        'page_size': 20,
        'total_pages': 0,
      },
      statusCode: 200,
    );
  }
}
