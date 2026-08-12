import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/driver_endpoints.dart';
import 'package:operion_mobile/features/driver/home/driver_providers.dart';
import 'package:operion_mobile/features/driver/profile/driver_profile_screen.dart';
import 'package:operion_mobile/features/driver/profile/driver_profile_providers.dart';
import 'package:operion_mobile/features/driver/tacho/providers/driver_tacho_providers.dart';
import 'package:operion_mobile/features/driver/tacho/screens/driver_tachograph_screen.dart';
import 'package:operion_mobile/features/teams/models/tacho.dart';
import 'package:operion_mobile/shared/models/user.dart';
import 'package:operion_mobile/shared/widgets/tacho_week_view.dart';

// ── Fixtures ───────────────────────────────────────────────────────────────

TachoWeek _week() => TachoWeek(
      weeklyDrivingMinutes: 2400,
      weeklyLimitMinutes: 3360,
      days: [
        TachoDay(
          date: DateTime(2026, 8, 10),
          drivingMinutes: 480,
          workingMinutes: 120,
          restMinutes: 240,
          availabilityMinutes: 600,
        ),
        TachoDay(
          date: DateTime(2026, 8, 11),
          drivingMinutes: 420,
          workingMinutes: 90,
          restMinutes: 300,
          availabilityMinutes: 630,
        ),
        TachoDay(
          date: DateTime(2026, 8, 12),
          drivingMinutes: 0,
          workingMinutes: 0,
          restMinutes: 720,
          availabilityMinutes: 720,
        ),
      ],
    );

Map<String, dynamic> _weekJson() => {
      'weekly_driving_minutes': 2400,
      'weekly_limit_minutes': 3360,
      'days': [
        {
          'date': '2026-08-10T00:00:00Z',
          'driving_minutes': 480,
          'working_minutes': 120,
          'rest_minutes': 240,
          'availability_minutes': 600,
        },
        {
          'date': '2026-08-11T00:00:00Z',
          'driving_minutes': 420,
          'working_minutes': 90,
          'rest_minutes': 300,
          'availability_minutes': 630,
        },
      ],
    };

class _StubDriverEndpoints extends DriverEndpoints {
  _StubDriverEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => null,
        ));

  int tachoCalls = 0;
  Object? error;

  @override
  Future<Response> getTacho({CancelToken? cancelToken}) async {
    tachoCalls++;
    if (error != null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/mobile/driver/tacho'),
        type: DioExceptionType.connectionError,
      );
    }
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/driver/tacho'),
      data: _weekJson(),
      statusCode: 200,
    );
  }
}

List<Override> _screenOverrides(TachoWeek week) => [
      driverTachoProvider.overrideWith((ref) async => week),
    ];

Widget _wrap(Widget child, {List<Override>? overrides}) {
  return ProviderScope(
    overrides: overrides ?? const [],
    child: MaterialApp(
      locale: const Locale('en'),
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

void main() {
  group('driverTachoProvider', () {
    test('fetches and parses the TachoTimelineOut shape', () async {
      final endpoints = _StubDriverEndpoints();
      final container = ProviderContainer(
        overrides: [
          driverEndpointsProvider.overrideWithValue(endpoints),
        ],
      );
      addTearDown(container.dispose);

      final week = await container.read(driverTachoProvider.future);
      expect(endpoints.tachoCalls, 1);
      expect(week.weeklyDrivingMinutes, 2400);
      expect(week.weeklyLimitMinutes, 3360);
      expect(week.days, hasLength(2));
      expect(week.days.first.drivingMinutes, 480);
    });

    test('surfaces the 404/network error as a provider error', () async {
      final endpoints = _StubDriverEndpoints()..error = 'boom';
      final container = ProviderContainer(
        overrides: [
          driverEndpointsProvider.overrideWithValue(endpoints),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(driverTachoProvider.future),
          throwsA(isA<DioException>()));
    });
  });

  group('DriverTachographScreen', () {
    testWidgets('renders the shared TachoWeekView + note on data',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const DriverTachographScreen(),
        overrides: _screenOverrides(_week()),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TachoWeekView), findsOneWidget);
      expect(find.byType(TachoDayBar), findsWidgets);
      expect(find.text('Tachograph'), findsOneWidget);
      expect(
        find.text('Data comes from tachograph imports performed by dispatchers'),
        findsOneWidget,
      );
      // Weekly gauge values from the shared widget.
      expect(find.text('2400'), findsOneWidget);
    });

    testWidgets('shows an error state with retry when the fetch fails',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const DriverTachographScreen(),
        overrides: [
          driverTachoProvider.overrideWith(
            (ref) async => throw Exception('no tacho row'),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TachoWeekView), findsNothing);
      expect(find.textContaining('no tacho row'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('empty week renders the shared empty state', (tester) async {
      await tester.pumpWidget(_wrap(
        const DriverTachographScreen(),
        overrides: _screenOverrides(
          const TachoWeek(weeklyDrivingMinutes: 0, weeklyLimitMinutes: 3360),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TachoWeekView), findsOneWidget);
      expect(find.text('No tacho data available'), findsOneWidget);
    });
  });

  group('Driver profile — Tachograph quick link', () {
    testWidgets('tapping the Tachograph link pushes DriverTachographScreen',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(
        const DriverProfileScreen(),
        overrides: [
          userProfileProvider.overrideWith(
            (ref) async => {
              'fullName': 'Mihai Popescu',
              'email': 'mihai@test.com',
              'phone': '+40-700-000-000',
              'role': 'driver',
              'driverProfile': {
                'licenseNumber': 'B12345678',
                'licenseCategory': 'C+E',
                'licenseExpiry': '2027-06-15',
              },
              'documents': <Map<String, dynamic>>[],
            },
          ),
          profileUpdatingProvider.overrideWith((ref) => false),
          profileEditingProvider.overrideWith((ref) => false),
          currentUserProvider.overrideWith(
            (ref) => const User(
              id: '1',
              email: 'mihai@test.com',
              fullName: 'Mihai Popescu',
              role: 'driver',
              companyId: '1',
            ),
          ),
          isOfflineProvider.overrideWith((ref) => false),
          // The pushed screen reads the tacho provider — stub it so no real
          // network call happens.
          driverTachoProvider.overrideWith((ref) async => _week()),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Tachograph'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Tachograph'));
      await tester.pumpAndSettle();

      expect(find.byType(DriverTachographScreen), findsOneWidget);
      expect(find.byType(TachoWeekView), findsOneWidget);
    });
  });
}
