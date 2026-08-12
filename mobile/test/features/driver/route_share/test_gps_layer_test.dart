import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/driver/models/route_share_geometry.dart';
import 'package:operion_mobile/features/driver/route_share/logic/gps_logic.dart';
import 'package:operion_mobile/features/driver/route_share/providers/gps_providers.dart';
import 'package:operion_mobile/features/driver/route_share/providers/route_share_providers.dart';
import 'package:operion_mobile/features/driver/route_share/screens/route_share_nav_screen.dart';
import 'package:operion_mobile/features/driver/route_share/services/foreground_navigation_service.dart';

// Screen-level GPS wiring tests: current-position marker, traveled/remaining
// polyline split, instruction-banner advance, the §7.2.2 off-route re-fetch
// trigger (50m deviation persisted 10s → geometry re-fetch, suppressed while
// offline), and the §7.2.3 foreground-service lifecycle wiring (start when
// background tracking is permitted, cadence-gated notification updates, stop
// on dispose / permission regression / foreground-only never starts).

class _FakeGpsService implements GpsService {
  // ignore: prefer_initializing_formals
  _FakeGpsService({required GpsPermission permission}) : _permission = permission;

  GpsPermission _permission;
  final StreamController<GpsFix?> _controller =
      StreamController<GpsFix?>.broadcast();

  @override
  Stream<GpsFix?> get positionStream => _controller.stream;

  @override
  Future<GpsPermission> get permission async => _permission;

  void emit(GpsFix? fix) => _controller.add(fix);

  void updatePermission(GpsPermission permission) => _permission = permission;

  void dispose() => _controller.close();
}

/// Fake foreground-service adapter recording the platform calls made by the
/// screen's controller wiring.
class _FakeForegroundAdapter implements ForegroundServiceAdapter {
  int initializeCount = 0;
  int startCount = 0;
  int updateCount = 0;
  int stopCount = 0;
  String? lastChannelName;
  NavigationNotificationContent? lastContent;

  @override
  Future<void> initialize({required String channelName}) async {
    initializeCount++;
    lastChannelName = channelName;
  }

  @override
  Future<void> start({required NavigationNotificationContent content}) async {
    startCount++;
    lastContent = content;
  }

  @override
  Future<void> update({required NavigationNotificationContent content}) async {
    updateCount++;
    lastContent = content;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

/// 4-point east-west route at lat 44.42 with an instruction at index 0 and a
/// later one at index 2 (so the banner can visibly advance past the first).
RouteShareGeometry _geometry() => RouteShareGeometry(
      transportId: 't-001',
      points: const [
        RoutePoint(lat: 44.42, lng: 26.10),
        RoutePoint(lat: 44.42, lng: 26.11),
        RoutePoint(lat: 44.42, lng: 26.12),
        RoutePoint(lat: 44.42, lng: 26.13),
      ],
      instructions: const [
        RouteInstruction(textKey: 'Start', distanceMeters: 500, pointIndex: 0),
        RouteInstruction(textKey: 'Turn right', distanceMeters: 300, pointIndex: 2),
      ],
      totalDistanceMeters: 2400.0,
      totalDurationSeconds: 840,
      generatedAt: DateTime.now(),
      ttlSeconds: 300,
    );

/// 60m north of the route line at lng 26.11 (past the 50m threshold).
const _offRouteFix = GpsFix(
  lat: 44.42 + 60 / 111320.0,
  lng: 26.11,
);

Widget _wrap({
  required GpsService gpsService,
  required Future<RouteShareGeometry> Function() geometryLoader,
  bool isOffline = false,
  ForegroundServiceAdapter? foregroundAdapter,
}) {
  return ProviderScope(
    overrides: [
      routeShareGeometryProvider.overrideWith((ref) => geometryLoader()),
      gpsServiceProvider.overrideWithValue(gpsService),
      isOfflineProvider.overrideWith((ref) => isOffline),
      if (foregroundAdapter != null)
        foregroundServiceAdapterProvider.overrideWithValue(foregroundAdapter),
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

void _ignoreTileErrors() {
  final originalHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!details.exceptionAsString().contains('tile.openstreetmap')) {
      originalHandler?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = originalHandler);
}

/// Pumps enough frames for a stream-emitted fix to reach the widget's
/// `ref.listen` cadence callback and repaint the marker/polyline.
Future<void> _pumpAfterEmit(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}

void main() {
  group('RouteShareNavScreen — GPS layer wiring (§7.2.2 / §7.2.3)', () {
    testWidgets('a fix renders the current-position marker on the map',
        (tester) async {
      _ignoreTileErrors();
      final gps = _FakeGpsService(
        permission: const GpsPermission(
          foregroundAllowed: true,
          backgroundAllowed: true,
        ),
      );
      addTearDown(gps.dispose);

      await tester.pumpWidget(_wrap(
        gpsService: gps,
        geometryLoader: () async => _geometry(),
      ));
      await tester.pump();
      await tester.pump();

      // No fix yet → no position marker.
      expect(find.byIcon(Icons.navigation), findsNothing);

      gps.emit(const GpsFix(lat: 44.42, lng: 26.10));
      await _pumpAfterEmit(tester);

      expect(find.byIcon(Icons.navigation), findsOneWidget);
    });

    testWidgets('cadence: a fix below 5s/20m is dropped; a 20m move is shown',
        (tester) async {
      _ignoreTileErrors();
      final gps = _FakeGpsService(
        permission: const GpsPermission(
          foregroundAllowed: true,
          backgroundAllowed: true,
        ),
      );
      addTearDown(gps.dispose);

      await tester.pumpWidget(_wrap(
        gpsService: gps,
        geometryLoader: () async => _geometry(),
      ));
      await tester.pump();
      await tester.pump();

      MarkerLayer layer() => tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      Marker positionMarker() => layer().markers.last;

      // First fix always emits.
      gps.emit(const GpsFix(lat: 44.42, lng: 26.11));
      await _pumpAfterEmit(tester);
      expect(positionMarker().point.longitude, closeTo(26.11, 1e-9));

      // Second fix: <5s elapsed, ~4m displacement → dropped by the cadence.
      gps.emit(const GpsFix(lat: 44.42, lng: 26.11005));
      await _pumpAfterEmit(tester);
      expect(positionMarker().point.longitude, closeTo(26.11, 1e-9));

      // Third fix: >20m from the emitted position → shown immediately.
      gps.emit(const GpsFix(lat: 44.42, lng: 26.112));
      await _pumpAfterEmit(tester);
      expect(positionMarker().point.longitude, closeTo(26.112, 1e-9));
    });

    testWidgets('polyline splits into traveled (thin/dim) + remaining (thick)',
        (tester) async {
      _ignoreTileErrors();
      final gps = _FakeGpsService(
        permission: const GpsPermission(
          foregroundAllowed: true,
          backgroundAllowed: true,
        ),
      );
      addTearDown(gps.dispose);

      await tester.pumpWidget(_wrap(
        gpsService: gps,
        geometryLoader: () async => _geometry(),
      ));
      await tester.pump();
      await tester.pump();

      PolylineLayer layer() =>
          tester.widget<PolylineLayer>(find.byType(PolylineLayer));

      // No fix → single (full-route) polyline.
      expect(layer().polylines.length, 1);

      gps.emit(const GpsFix(lat: 44.42, lng: 26.11));
      await _pumpAfterEmit(tester);

      // Fix → traveled + remaining. Traveled is thinner than remaining.
      expect(layer().polylines.length, 2);
      expect(layer().polylines[0].points.length, 2); // up to and incl. nearest
      expect(layer().polylines[1].points.length, 3); // nearest to end
      expect(
        layer().polylines[0].strokeWidth,
        lessThan(layer().polylines[1].strokeWidth),
      );
    });

    testWidgets('instruction banner advances to the next maneuver with a fix',
        (tester) async {
      _ignoreTileErrors();
      final gps = _FakeGpsService(
        permission: const GpsPermission(
          foregroundAllowed: true,
          backgroundAllowed: true,
        ),
      );
      addTearDown(gps.dispose);

      await tester.pumpWidget(_wrap(
        gpsService: gps,
        geometryLoader: () async => _geometry(),
      ));
      await tester.pump();
      await tester.pump();

      // No fix → first instruction.
      expect(find.text('Start'), findsOneWidget);

      // Fix at point index 1 → past "Start" (pointIndex 0), "Turn right"
      // (pointIndex 2) is the next ahead instruction.
      gps.emit(const GpsFix(lat: 44.42, lng: 26.11));
      await _pumpAfterEmit(tester);
      expect(find.text('Turn right'), findsOneWidget);
    });

    testWidgets(
        'off-route: banner shown and geometry re-fetched after 10s persisted',
        (tester) async {
      _ignoreTileErrors();
      final gps = _FakeGpsService(
        permission: const GpsPermission(
          foregroundAllowed: true,
          backgroundAllowed: true,
        ),
      );
      addTearDown(gps.dispose);

      var fetchCount = 0;
      await tester.pumpWidget(_wrap(
        gpsService: gps,
        geometryLoader: () async {
          fetchCount++;
          return _geometry();
        },
      ));
      await tester.pump();
      await tester.pump();
      expect(fetchCount, 1);

      // 60m off route → banner appears and the 10s window starts.
      gps.emit(_offRouteFix);
      await _pumpAfterEmit(tester);
      expect(find.text('You appear to be off route'), findsOneWidget);

      // Not yet 10s of sustained deviation → no re-fetch.
      await tester.pump(const Duration(seconds: 9));
      expect(fetchCount, 1);

      // Persisted past 10s → geometry re-fetch triggered.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(fetchCount, 2);
    });

    testWidgets('offline: off-route banner stays but re-fetch is suppressed',
        (tester) async {
      _ignoreTileErrors();
      final gps = _FakeGpsService(
        permission: const GpsPermission(
          foregroundAllowed: true,
          backgroundAllowed: true,
        ),
      );
      addTearDown(gps.dispose);

      var fetchCount = 0;
      await tester.pumpWidget(_wrap(
        gpsService: gps,
        geometryLoader: () async {
          fetchCount++;
          return _geometry();
        },
        isOffline: true,
      ));
      await tester.pump();
      await tester.pump();
      expect(fetchCount, 1);

      gps.emit(_offRouteFix);
      await _pumpAfterEmit(tester);
      expect(find.text('You appear to be off route'), findsOneWidget);

      // 11s pass — the persistence window elapses, but offline suppresses the
      // re-fetch (§7.2.2: keep rendering the last-fetched geometry).
      await tester.pump(const Duration(seconds: 11));
      await tester.pump();
      expect(fetchCount, 1);
    });
  });

  group('RouteShareNavScreen — foreground service wiring (§7.2.3)', () {
    testWidgets(
        'background+foreground granted → service starts with initial content '
        'and updates only when guidance changes', (tester) async {
      _ignoreTileErrors();
      final gps = _FakeGpsService(
        permission: const GpsPermission(
          foregroundAllowed: true,
          backgroundAllowed: true,
        ),
      );
      final adapter = _FakeForegroundAdapter();
      addTearDown(gps.dispose);

      await tester.pumpWidget(_wrap(
        gpsService: gps,
        geometryLoader: () async => _geometry(),
        foregroundAdapter: adapter,
      ));
      await tester.pump();
      await tester.pump();
      await _pumpAfterEmit(tester);

      // Initial content uses the no-fix fallback: first instruction + totals.
      expect(adapter.startCount, 1);
      expect(adapter.initializeCount, 1);
      expect(adapter.lastChannelName, 'Operion Navigation');
      expect(adapter.lastContent?.title, 'Start');
      expect(adapter.lastContent?.body, contains('2.4 km'));

      // A fix that leaves instruction/distance/ETA unchanged is deduped by
      // the controller (no per-fix notification storm).
      final updatesBefore = adapter.updateCount;

      // First emitted fix (start point): the "next instruction strictly
      // ahead" logic advances the banner to "Turn right" → update once.
      gps.emit(const GpsFix(lat: 44.42, lng: 26.10));
      await _pumpAfterEmit(tester);
      expect(adapter.updateCount, updatesBefore + 1);
      expect(adapter.lastContent?.title, 'Turn right');

      // Re-emitting the same position is dropped by the 5s/20m cadence → no
      // further update.
      gps.emit(const GpsFix(lat: 44.42, lng: 26.10));
      await _pumpAfterEmit(tester);
      expect(adapter.updateCount, updatesBefore + 1);
    });

    testWidgets('foreground-only (background denied) → service never starts',
        (tester) async {
      _ignoreTileErrors();
      final gps = _FakeGpsService(
        permission: const GpsPermission(
          foregroundAllowed: true,
          backgroundAllowed: false,
        ),
      );
      final adapter = _FakeForegroundAdapter();
      addTearDown(gps.dispose);

      await tester.pumpWidget(_wrap(
        gpsService: gps,
        geometryLoader: () async => _geometry(),
        foregroundAdapter: adapter,
      ));
      await tester.pump();
      await tester.pump();
      await _pumpAfterEmit(tester);

      // The existing foreground-only banner is shown and the service never
      // touched the platform.
      expect(find.text('Navigation will pause when app is backgrounded'),
          findsOneWidget);
      expect(adapter.startCount, 0);
      expect(adapter.initializeCount, 0);
      expect(adapter.stopCount, 0);
    });

    testWidgets('location fully denied → service never starts, no crash',
        (tester) async {
      _ignoreTileErrors();
      final gps = _FakeGpsService(
        permission: const GpsPermission(
          foregroundAllowed: false,
          backgroundAllowed: false,
        ),
      );
      final adapter = _FakeForegroundAdapter();
      addTearDown(gps.dispose);

      await tester.pumpWidget(_wrap(
        gpsService: gps,
        geometryLoader: () async => _geometry(),
        foregroundAdapter: adapter,
      ));
      await tester.pump();
      await tester.pump();
      await _pumpAfterEmit(tester);

      expect(adapter.startCount, 0);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('dispose stops the running service', (tester) async {
      _ignoreTileErrors();
      final gps = _FakeGpsService(
        permission: const GpsPermission(
          foregroundAllowed: true,
          backgroundAllowed: true,
        ),
      );
      final adapter = _FakeForegroundAdapter();
      addTearDown(gps.dispose);

      await tester.pumpWidget(_wrap(
        gpsService: gps,
        geometryLoader: () async => _geometry(),
        foregroundAdapter: adapter,
      ));
      await tester.pump();
      await tester.pump();
      await _pumpAfterEmit(tester);
      expect(adapter.startCount, 1);
      expect(adapter.stopCount, 0);

      // Leaving the map view tears the service down.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      expect(adapter.stopCount, 1);
    });

    testWidgets('permission regression mid-route stops the service',
        (tester) async {
      _ignoreTileErrors();
      final gps = _FakeGpsService(
        permission: const GpsPermission(
          foregroundAllowed: true,
          backgroundAllowed: true,
        ),
      );
      final adapter = _FakeForegroundAdapter();
      addTearDown(gps.dispose);

      await tester.pumpWidget(_wrap(
        gpsService: gps,
        geometryLoader: () async => _geometry(),
        foregroundAdapter: adapter,
      ));
      await tester.pump();
      await tester.pump();
      await _pumpAfterEmit(tester);
      expect(adapter.startCount, 1);

      // Simulate the user revoking background access mid-route: the provider
      // re-resolves and the screen tears the service down.
      gps.updatePermission(const GpsPermission(
        foregroundAllowed: true,
        backgroundAllowed: false,
      ));
      ProviderScope.containerOf(
        tester.element(find.byType(RouteShareNavScreen)),
      ).invalidate(gpsPermissionProvider);
      await _pumpAfterEmit(tester);

      expect(adapter.stopCount, 1);
    });
  });
}
