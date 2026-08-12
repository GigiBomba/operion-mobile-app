import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/driver/models/route_share_geometry.dart';
import 'package:operion_mobile/features/driver/route_share/providers/gps_providers.dart';
import 'package:operion_mobile/features/driver/route_share/providers/route_share_providers.dart';
import 'package:operion_mobile/features/driver/route_share/screens/route_share_nav_screen.dart';

// Blueprint §11 / §7.2.3 test requirement: a denied background/"Always"
// permission must degrade to foreground-only tracking with a persistent
// banner — never a crash or a silent stop. A granted permission shows no
// fallback banner.

/// Fake GPS service with a deterministic permission state and an injectable
/// position stream (mirrors the provider-override pattern used by the
/// trip-overview screen tests).
class _FakeGpsService implements GpsService {
  // ignore: prefer_initializing_formals
  _FakeGpsService({required GpsPermission permission}) : _permission = permission;

  final GpsPermission _permission;
  final StreamController<GpsFix?> _controller =
      StreamController<GpsFix?>.broadcast();

  @override
  Stream<GpsFix?> get positionStream => _controller.stream;

  @override
  Future<GpsPermission> get permission async => _permission;

  void emit(GpsFix? fix) => _controller.add(fix);

  void dispose() => _controller.close();
}

RouteShareGeometry _geometry() => RouteShareGeometry(
      transportId: 't-001',
      points: const [
        RoutePoint(lat: 44.42, lng: 26.10),
        RoutePoint(lat: 44.42, lng: 26.11),
        RoutePoint(lat: 44.42, lng: 26.12),
      ],
      instructions: const [
        RouteInstruction(textKey: 'Turn left', distanceMeters: 500, pointIndex: 0),
        RouteInstruction(textKey: 'Turn right', distanceMeters: 300, pointIndex: 1),
      ],
      totalDistanceMeters: 12450.0,
      totalDurationSeconds: 840,
      generatedAt: DateTime.now(),
      ttlSeconds: 300,
    );

Widget _wrap({required GpsService gpsService}) {
  return ProviderScope(
    overrides: [
      routeShareGeometryProvider.overrideWith((ref) async => _geometry()),
      gpsServiceProvider.overrideWithValue(gpsService),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: RouteShareNavScreen(),
    ),
  );
}

/// The FlutterMap tile layer performs real HTTP loads in the test environment,
/// which surface as unhandled FlutterErrors. Suppress exactly those, matching
/// the existing route-share screen test pattern.
void _ignoreTileErrors() {
  final originalHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!details.exceptionAsString().contains('tile.openstreetmap')) {
      originalHandler?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = originalHandler);
}

/// Pumps enough frames for the async permission FutureProvider to resolve.
Future<void> _pumpUntilPermissionResolved(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

/// Pumps enough frames for a stream-emitted fix to reach the widget's
/// `ref.listen` cadence callback and repaint the marker.
Future<void> _pumpAfterEmit(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}

void main() {
  group('RouteShareNavScreen — background permission fallback (§7.2.3)', () {
    testWidgets(
        'background denied → persistent banner + foreground tracking still works',
        (tester) async {
      _ignoreTileErrors();
      final gps = _FakeGpsService(
        permission: const GpsPermission(
          foregroundAllowed: true,
          backgroundAllowed: false,
        ),
      );
      addTearDown(gps.dispose);

      await tester.pumpWidget(_wrap(gpsService: gps));
      await _pumpUntilPermissionResolved(tester);

      // Persistent, non-blocking banner explaining the fallback.
      expect(
        find.text('Navigation will pause when app is backgrounded'),
        findsOneWidget,
      );

      // Foreground tracking still works: a fix renders the position marker.
      gps.emit(const GpsFix(lat: 44.42, lng: 26.11));
      await _pumpAfterEmit(tester);
      expect(find.byIcon(Icons.navigation), findsOneWidget);
    });

    testWidgets('background granted → full tracking, no fallback banner',
        (tester) async {
      _ignoreTileErrors();
      final gps = _FakeGpsService(
        permission: const GpsPermission(
          foregroundAllowed: true,
          backgroundAllowed: true,
        ),
      );
      addTearDown(gps.dispose);

      await tester.pumpWidget(_wrap(gpsService: gps));
      await _pumpUntilPermissionResolved(tester);

      expect(
        find.text('Navigation will pause when app is backgrounded'),
        findsNothing,
      );

      // Tracking works as usual.
      gps.emit(const GpsFix(lat: 44.42, lng: 26.11));
      await _pumpAfterEmit(tester);
      expect(find.byIcon(Icons.navigation), findsOneWidget);
    });

    testWidgets('location fully denied → permission-denied banner, no crash',
        (tester) async {
      _ignoreTileErrors();
      final gps = _FakeGpsService(
        permission: const GpsPermission(
          foregroundAllowed: false,
          backgroundAllowed: false,
        ),
      );
      addTearDown(gps.dispose);

      await tester.pumpWidget(_wrap(gpsService: gps));
      await _pumpUntilPermissionResolved(tester);

      // Explains that position updates are unavailable — no crash, no
      // silent stop; the static route geometry still renders.
      expect(
        find.text('Location access is denied. Position updates are unavailable.'),
        findsOneWidget,
      );
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
