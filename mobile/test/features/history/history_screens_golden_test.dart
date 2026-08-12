import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/history/providers/history_providers.dart';
import 'package:operion_mobile/features/history/screens/route_history_screen.dart';
import 'package:operion_mobile/features/history/screens/trip_history_screen.dart';

/// Dark-mode golden gap-fill (blueprint §9 item 7): TripHistoryScreen and
/// RouteHistoryScreen previously had NO goldens. Fixed-date fixtures with
/// mixed data, explicit Brightness, provider mocks — per the repo convention.
class _Stub extends HistoryEndpoints {
  _Stub()
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
        'items': [
          {
            'id': 1,
            'client_name': 'ACME Logistics',
            'truck_number': 'B-100-ABC',
            'driver_name': 'Ion Popescu',
            'origin': 'București',
            'destination': 'Cluj-Napoca',
            'status': 'Delivered',
            'start_date': '2026-07-31',
            'total_price_eur': 1250,
            'net_profit': 380.5,
            'distance_km': 450,
          },
          {
            'id': 2,
            'client_name': 'Beta Trading',
            'truck_number': 'B-200-DEF',
            'driver_name': 'Ana Dobre',
            'origin': 'Timișoara',
            'destination': 'Constanța',
            'status': 'In Transit',
            'start_date': '2026-07-30',
            'end_date': '2026-07-31',
            'total_price_eur': 890,
            'net_profit': 120,
            'distance_km': 610,
          },
          {
            'id': 3,
            'client_name': 'Gamma Foods',
            'truck_number': 'B-300-GHI',
            'driver_name': 'Vlad Marin',
            'origin': 'Brașov',
            'destination': 'Iași',
            'status': 'Cancelled',
            'start_date': '2026-07-28',
            'total_price_eur': 540,
          },
        ],
        'total': 3,
        'page': 1,
        'page_size': 20,
        'total_pages': 1,
      },
      statusCode: 200,
    );
  }

  @override
  Future<Response> getRoutes(
    RouteHistoryFilter filter, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'items': [
          {
            'id': 1,
            'name': 'Ruta Vest — București → Timișoara',
            'origin': 'București',
            'destination': 'Timișoara',
            'total_distance_km': 428,
            'duration_min': 330,
            'created_at': '2026-07-31',
          },
          {
            'id': 2,
            'name': 'Ruta Est — Constanța → Iași',
            'origin': 'Constanța',
            'destination': 'Iași',
            'total_distance_km': 512,
            'duration_min': 400,
            'created_at': '2026-07-29',
          },
          {
            'id': 3,
            'name': 'Ruta Nord — Cluj → Satu Mare',
            'origin': 'Cluj-Napoca',
            'destination': 'Satu Mare',
            'total_distance_km': 190,
            'duration_min': 150,
            'created_at': '2026-07-25',
          },
        ],
        'total': 3,
        'page': 1,
        'page_size': 20,
        'total_pages': 1,
      },
      statusCode: 200,
    );
  }
}

List<Override> _overrides() => [
      isOfflineProvider.overrideWith((ref) => false),
      historyEndpointsProvider.overrideWithValue(_Stub()),
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
  testWidgets('TripHistoryScreen golden (light)', (tester) async {
    await _pumpGolden(
      tester,
      const TripHistoryScreen(),
      'trip_history_light.png',
    );
  });

  testWidgets('TripHistoryScreen golden (dark)', (tester) async {
    await _pumpGolden(
      tester,
      const TripHistoryScreen(),
      'trip_history_dark.png',
      brightness: Brightness.dark,
    );
  });

  testWidgets('RouteHistoryScreen golden (light)', (tester) async {
    await _pumpGolden(
      tester,
      const RouteHistoryScreen(),
      'route_history_light.png',
    );
  });

  testWidgets('RouteHistoryScreen golden (dark)', (tester) async {
    await _pumpGolden(
      tester,
      const RouteHistoryScreen(),
      'route_history_dark.png',
      brightness: Brightness.dark,
    );
  });
}
