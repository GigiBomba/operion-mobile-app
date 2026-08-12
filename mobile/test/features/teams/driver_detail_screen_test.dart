import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/drivers_endpoints.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/features/teams/providers/teams_providers.dart';
import 'package:operion_mobile/features/teams/screens/driver_detail_screen.dart';
import 'package:operion_mobile/shared/widgets/shimmer_loader.dart';
import 'package:operion_mobile/shared/widgets/status_badge.dart';

import '../../support/fake_local_database.dart';

/// DriverOut-shaped summary as pushed from the Teams list (new /mobile/drivers).
const Map<String, dynamic> _driverSummary = {
  'id': '1',
  'name': 'Ana Popescu',
  'status': 'available',
  'current_transport': null,
  'current_vehicle': 'TR-101',
};

/// DriverOut-shaped detail fixture (backend `GET /api/v1/mobile/drivers/{id}`).
Map<String, dynamic> _detailFixture({
  required String licenseExpiry,
  required String medicalExpiry,
}) =>
    {
      // Numeric id: DriverDetail.fromJson casts json['id'] as num?.
      'id': 1,
      'company_id': 'c1',
      'name': 'Ana Popescu',
      'phone': '+40 700 000 000',
      'email': 'ana@example.com',
      'status': 'available',
      'license_number': 'RO-123456',
      'license_category': 'CE',
      'license_expiry': licenseExpiry,
      'medical_expiry': medicalExpiry,
      'adr_certificate_expiry':
          DateTime.now().add(const Duration(days: 400)).toIso8601String(),
      'current_truck_id': 'TR-101',
      'is_active': true,
      'created_at': '2020-01-01T00:00:00',
      'updated_at': '2020-01-01T00:00:00',
    };

String _iso(DateTime value) => value.toIso8601String();

/// Endpoints stub serving a fixed DriverOut fixture on the NEW /mobile/drivers
/// endpoint (mirrors the trip_overview_screen_test stub pattern).
class _StubDriversEndpoints extends DriversEndpoints {
  _StubDriversEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  Map<String, dynamic>? detailJson;
  bool throwError = false;
  int detailCallCount = 0;

  @override
  Future<Response> getDriverDetail(
    String id, {
    CancelToken? cancelToken,
  }) async {
    detailCallCount++;
    if (throwError) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/mobile/drivers/$id'),
        type: DioExceptionType.connectionTimeout,
      );
    }
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/drivers/$id'),
      data: detailJson ?? _detailFixture(
        licenseExpiry: _iso(DateTime.now().add(const Duration(days: 400))),
        medicalExpiry: _iso(DateTime.now().add(const Duration(days: 400))),
      ),
      statusCode: 200,
    );
  }
}

Widget _wrap(_StubDriversEndpoints endpoints, {Map<String, dynamic>? driver}) {
  return ProviderScope(
    overrides: [
      driversEndpointsProvider.overrideWithValue(endpoints),
      // Dual-mode detail caches by id → use the in-memory fake.
      localDatabaseProvider.overrideWithValue(FakeLocalDatabase()),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: DriverDetailScreen(driver: driver ?? _driverSummary),
    ),
  );
}

void main() {
  group('licenseExpiryStatusFor', () {
    final now = DateTime(2026, 7, 31);

    test('null expiry is never flagged', () {
      expect(licenseExpiryStatusFor(null, now: now),
          LicenseExpiryStatus.valid);
    });

    test('far-future expiry is valid', () {
      expect(
        licenseExpiryStatusFor(
            now.add(const Duration(days: 400)), now: now),
        LicenseExpiryStatus.valid,
      );
    });

    test('expiry within 30 days is expiring soon', () {
      expect(
        licenseExpiryStatusFor(now.add(const Duration(days: 15)), now: now),
        LicenseExpiryStatus.expiringSoon,
      );
      expect(
        licenseExpiryStatusFor(now.add(const Duration(days: 29)), now: now),
        LicenseExpiryStatus.expiringSoon,
      );
      // Exactly at the 30-day cutoff (and beyond) is still valid.
      expect(
        licenseExpiryStatusFor(now.add(const Duration(days: 30)), now: now),
        LicenseExpiryStatus.valid,
      );
    });

    test('past expiry is expired', () {
      expect(
        licenseExpiryStatusFor(now.subtract(const Duration(days: 1)), now: now),
        LicenseExpiryStatus.expired,
      );
    });
  });

  group('DriverDetailScreen — data', () {
    testWidgets('renders license fields and a valid expiry badge',
        (tester) async {
      final endpoints = _StubDriversEndpoints()
        ..detailJson = _detailFixture(
          licenseExpiry: _iso(DateTime.now().add(const Duration(days: 400))),
          medicalExpiry: _iso(DateTime.now().add(const Duration(days: 400))),
        );
      await tester.pumpWidget(_wrap(endpoints));
      await tester.pumpAndSettle();

      // Identity + license info.
      expect(find.text('Ana Popescu'), findsWidgets);
      expect(find.text('License Number'), findsOneWidget);
      expect(find.text('RO-123456'), findsOneWidget);
      expect(find.text('License Category'), findsOneWidget);
      expect(find.text('CE'), findsOneWidget);
      expect(find.text('License Expiry'), findsOneWidget);
      expect(find.text('Medical Expiry'), findsOneWidget);

      // Status badge from the summary (available) + expiry badge (Valid).
      expect(find.byType(StatusBadge), findsWidgets);
      expect(find.text('Valid'), findsWidgets);

      // Assigned vehicle from the summary.
      expect(find.text('Assigned Vehicle'), findsOneWidget);
      expect(find.text('TR-101'), findsOneWidget);
      // Transport not assigned for this driver.
      expect(find.text('Not assigned'), findsWidgets);
    });

    testWidgets('renders the expired expiry treatment for an expired license',
        (tester) async {
      final endpoints = _StubDriversEndpoints()
        ..detailJson = _detailFixture(
          licenseExpiry: _iso(DateTime.now().subtract(const Duration(days: 30))),
          medicalExpiry: _iso(DateTime.now().add(const Duration(days: 400))),
        );
      await tester.pumpWidget(_wrap(endpoints));
      await tester.pumpAndSettle();

      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Valid'), findsOneWidget);
    });

    testWidgets('renders the expiring-soon treatment within the 30-day window',
        (tester) async {
      final endpoints = _StubDriversEndpoints()
        ..detailJson = _detailFixture(
          licenseExpiry: _iso(DateTime.now().add(const Duration(days: 15))),
          medicalExpiry: _iso(DateTime.now().add(const Duration(days: 400))),
        );
      await tester.pumpWidget(_wrap(endpoints));
      await tester.pumpAndSettle();

      expect(find.text('Expiring soon'), findsOneWidget);
    });
  });

  group('DriverDetailScreen — §1.2 states', () {
    testWidgets('shows shimmer while the detail fetch is in flight',
        (tester) async {
      final endpoints = _StubDriversEndpoints();
      await tester.pumpWidget(_wrap(endpoints));
      await tester.pump();
      expect(find.byType(ShimmerLoader), findsWidgets);
      await tester.pumpAndSettle();
    });

    testWidgets('shows the localized error state with a retry action',
        (tester) async {
      final endpoints = _StubDriversEndpoints()..throwError = true;
      await tester.pumpWidget(_wrap(endpoints));
      await tester.pumpAndSettle();

      expect(find.text('Could not load driver details.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Retry re-fetches and recovers.
      endpoints
        ..throwError = false
        ..detailJson = _detailFixture(
          licenseExpiry: _iso(DateTime.now().add(const Duration(days: 400))),
          medicalExpiry: _iso(DateTime.now().add(const Duration(days: 400))),
        );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('RO-123456'), findsOneWidget);
    });

    testWidgets('empty state when the detail payload has no license data',
        (tester) async {
      final endpoints = _StubDriversEndpoints()
        ..detailJson = {
          'id': 1,
          'name': 'Ana Popescu',
          'phone': '',
          'email': '',
          'license_number': '',
          'license_category': '',
          'license_expiry': null,
          'medical_expiry': null,
          'is_active': true,
        };
      await tester.pumpWidget(_wrap(endpoints));
      await tester.pumpAndSettle();

      expect(find.text('No driver information available'), findsOneWidget);
    });
  });
}
