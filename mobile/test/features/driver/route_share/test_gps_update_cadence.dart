import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/features/driver/models/route_share_geometry.dart';
import 'package:operion_mobile/features/driver/route_share/logic/gps_logic.dart';

// Blueprint §11 / §7.2.3 test requirement: the 5s / 20m GPS update cadence
// (whichever fires first) and the off-route / remaining-route pure logic.
void main() {
  group('shouldEmitGpsUpdate — §7.2.3 cadence (5s / 20m, whichever first)', () {
    test('stationary: the 5s timer fires at exactly 5s, not before', () {
      expect(
        shouldEmitGpsUpdate(
          elapsed: const Duration(seconds: 5),
          displacementMeters: 0,
        ),
        isTrue,
        reason: '5s elapsed, zero displacement → timer threshold reached',
      );
      expect(
        shouldEmitGpsUpdate(
          elapsed: const Duration(milliseconds: 4900),
          displacementMeters: 0,
        ),
        isFalse,
        reason: '4.9s elapsed, zero displacement → neither threshold reached',
      );
    });

    test('fast-moving: the 20m threshold fires before the 5s timer', () {
      expect(
        shouldEmitGpsUpdate(
          elapsed: const Duration(seconds: 2),
          displacementMeters: 20,
        ),
        isTrue,
        reason: '20m displacement at t=2s → distance threshold reached first',
      );
      expect(
        shouldEmitGpsUpdate(
          elapsed: const Duration(seconds: 2),
          displacementMeters: 19.9,
        ),
        isFalse,
        reason: '19.9m at t=2s → neither threshold reached',
      );
    });

    test('both conditions satisfied at once emits', () {
      expect(
        shouldEmitGpsUpdate(
          elapsed: const Duration(seconds: 6),
          displacementMeters: 30,
        ),
        isTrue,
      );
    });

    test('exact thresholds use >= semantics (5s / 20m boundaries)', () {
      expect(
        shouldEmitGpsUpdate(
          elapsed: const Duration(seconds: 5),
          displacementMeters: 20,
        ),
        isTrue,
      );
    });

    test('zero values do not emit', () {
      expect(
        shouldEmitGpsUpdate(elapsed: Duration.zero, displacementMeters: 0),
        isFalse,
      );
    });
  });

  group('distanceToRouteMeters / isOffRoute — straight 2-point route', () {
    // Straight east-west line at lat 44.0 from lng 26.0 to 26.02.
    const points = [
      RoutePoint(lat: 44.0, lng: 26.0),
      RoutePoint(lat: 44.0, lng: 26.02),
    ];

    test('a point on the route is 0m away', () {
      expect(distanceToRouteMeters(44.0, 26.0, points), closeTo(0, 1));
      expect(distanceToRouteMeters(44.0, 26.01, points), closeTo(0, 1));
    });

    test('60m off the route exceeds the 50m threshold → off route', () {
      // 60m north of the segment midpoint (1° lat ≈ 111320m).
      const offLat = 44.0 + 60 / 111320.0;
      expect(distanceToRouteMeters(offLat, 26.01, points), closeTo(60, 2));
      expect(isOffRoute(offLat, 26.01, points), isTrue);
    });

    test('30m off the route is within tolerance → not off route', () {
      const offLat = 44.0 + 30 / 111320.0;
      expect(distanceToRouteMeters(offLat, 26.01, points), closeTo(30, 2));
      expect(isOffRoute(offLat, 26.01, points), isFalse);
    });

    test('an empty route is never off route', () {
      expect(distanceToRouteMeters(44.0, 26.0, const []), double.infinity);
      expect(isOffRoute(44.0, 26.0, const []), isFalse);
    });
  });

  group('nearestPointIndex / remainingRouteFrom', () {
    const points = [
      RoutePoint(lat: 44.0, lng: 26.00),
      RoutePoint(lat: 44.0, lng: 26.01),
      RoutePoint(lat: 44.0, lng: 26.02),
      RoutePoint(lat: 44.0, lng: 26.03),
    ];

    test('remaining sublist starts at the nearest point', () {
      final remaining = remainingRouteFrom(44.0, 26.015, points);
      expect(remaining.length, 3);
      expect(remaining.first, points[1]);
      expect(remaining.last, points.last);
    });

    test('nearest index is 0 at the route start and last at the end', () {
      expect(nearestPointIndex(44.0, 26.0, points), 0);
      expect(nearestPointIndex(44.0, 26.03, points), points.length - 1);
    });

    test('empty route yields an empty remaining list', () {
      expect(remainingRouteFrom(44.0, 26.0, const []), isEmpty);
    });
  });

  group('remainingDistanceMeters / remainingDurationSeconds — local recompute', () {
    const points = [
      RoutePoint(lat: 44.0, lng: 26.00),
      RoutePoint(lat: 44.0, lng: 26.01),
      RoutePoint(lat: 44.0, lng: 26.02),
    ];

    test('remaining distance from the start equals the full route length', () {
      // Two ~800m segments at lat 44.0 (1° lng ≈ 80077m).
      expect(remainingDistanceMeters(44.0, 26.0, points), closeTo(1601.5, 10));
    });

    test('remaining distance halves at the midpoint', () {
      expect(remainingDistanceMeters(44.0, 26.01, points), closeTo(800.8, 10));
    });

    test('duration scales proportionally with the remaining distance', () {
      final duration = remainingDurationSeconds(
        44.0,
        26.01,
        points,
        totalDistanceMeters: 1601.5,
        totalDurationSeconds: 600,
      );
      expect(duration, closeTo(300, 10));
    });

    test('degenerate totals fall back to the full duration', () {
      expect(
        remainingDurationSeconds(
          44.0,
          26.01,
          points,
          totalDistanceMeters: 0,
          totalDurationSeconds: 600,
        ),
        600,
      );
      expect(
        remainingDurationSeconds(
          44.0,
          26.01,
          const [],
          totalDistanceMeters: 100,
          totalDurationSeconds: 600,
        ),
        600,
      );
    });
  });

  group('nextInstructionIndexFor — instruction banner advance', () {
    const points = [
      RoutePoint(lat: 44.0, lng: 26.00),
      RoutePoint(lat: 44.0, lng: 26.01),
      RoutePoint(lat: 44.0, lng: 26.02),
      RoutePoint(lat: 44.0, lng: 26.03),
    ];
    const instructions = [
      RouteInstruction(textKey: 'Turn left', distanceMeters: 500, pointIndex: 1),
      RouteInstruction(textKey: 'Turn right', distanceMeters: 300, pointIndex: 3),
    ];

    test('the first instruction still ahead is selected', () {
      // Near point index 1 → instruction at pointIndex 1 is "reached", so the
      // next ahead one (pointIndex 3) wins.
      expect(nextInstructionIndexFor(44.0, 26.015, instructions, points), 1);
      // At the route start → first instruction wins.
      expect(nextInstructionIndexFor(44.0, 26.0, instructions, points), 0);
    });

    test('returns 0 once every instruction is passed', () {
      expect(nextInstructionIndexFor(44.0, 26.04, instructions, points), 0);
    });

    test('returns 0 for empty instructions or empty points', () {
      expect(nextInstructionIndexFor(44.0, 26.01, const [], points), 0);
      expect(nextInstructionIndexFor(44.0, 26.01, instructions, const []), 0);
    });
  });
}
