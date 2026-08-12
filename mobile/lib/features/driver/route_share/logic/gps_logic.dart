import 'dart:math' as math;

import '../../models/route_share_geometry.dart';

// ---------------------------------------------------------------------------
// GPS turn-by-turn pure logic (blueprint §7.2.2 / §7.2.3).
//
// All functions are pure and platform-free so they can be unit-tested
// without mocking platform channels. The only dependency is the route-share
// model (RoutePoint / RouteInstruction).
// ---------------------------------------------------------------------------

/// Earth radius used by the equirectangular approximation, in meters.
const double _earthRadiusMeters = 6371000.0;

/// Approximate meters per degree of latitude (WGS84 ellipsoid, ~1:1,000,000
/// accuracy — ample for the sub-50-metre checks this module feeds).
const double _metersPerDegreeLat = 111320.0;

/// The 5-second / 20-meter GPS update cadence decision (blueprint §7.2.3):
/// an update is emitted when [elapsed] reaches [interval] OR the displacement
/// reaches [thresholdMeters] — whichever comes first. A fixed timer alone
/// wastes battery while stationary at a loading dock; a pure distance filter
/// alone produces no update while queued in traffic. Both conditions are
/// evaluated on every raw platform fix and the first to be satisfied wins.
bool shouldEmitGpsUpdate({
  required Duration elapsed,
  required double displacementMeters,
  Duration interval = const Duration(seconds: 5),
  double thresholdMeters = 20,
}) {
  return elapsed >= interval || displacementMeters >= thresholdMeters;
}

double _toRadians(double degrees) => degrees * math.pi / 180.0;

/// Distance in meters between two coordinates using the equirectangular
/// approximation:
///
///   distance = R · √( Δlat² + (Δlng · cos φm)² )
///
/// where R = 6,371,000 m and φm is the mean latitude. This is a small-angle
/// approximation whose relative error stays below ~0.5% for distances up to a
/// few hundred kilometres — well within tolerance for the sub-50-metre
/// off-route checks and cadence displacement it feeds.
double distanceMetersBetween(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  final meanLat = _toRadians((lat1 + lat2) / 2.0);
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1) * math.cos(meanLat);
  return _earthRadiusMeters * math.sqrt(dLat * dLat + dLng * dLng);
}

/// Minimum distance in meters from the point (lat, lng) to the polyline
/// defined by [points], measured against each consecutive segment (not just
/// the nearest vertex — the driver may be closest to the middle of a long
/// segment). Returns [double.infinity] for an empty route.
double distanceToRouteMeters(double lat, double lng, List<RoutePoint> points) {
  if (points.isEmpty) return double.infinity;
  if (points.length == 1) {
    return distanceMetersBetween(lat, lng, points.first.lat, points.first.lng);
  }
  var minDistance = double.infinity;
  for (var i = 0; i < points.length - 1; i++) {
    final distance =
        _distanceToSegmentMeters(lat, lng, points[i], points[i + 1]);
    if (distance < minDistance) minDistance = distance;
  }
  return minDistance;
}

/// Distance in meters from the point (lat, lng) to the segment [a]–[b].
///
/// The segment is projected onto a local planar frame using the equirectangular
/// scale factors (meters per degree at the query point's latitude), then the
/// point-to-segment distance is computed in that frame and the projection
/// point is clamped to the segment.
double _distanceToSegmentMeters(double lat, double lng, RoutePoint a, RoutePoint b) {
  final cosLat = math.cos(_toRadians(lat));

  final ax = (a.lng - lng) * _metersPerDegreeLat * cosLat;
  final ay = (a.lat - lat) * _metersPerDegreeLat;
  final bx = (b.lng - lng) * _metersPerDegreeLat * cosLat;
  final by = (b.lat - lat) * _metersPerDegreeLat;

  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) {
    return math.sqrt(ax * ax + ay * ay);
  }

  // Project the origin (the query point) onto the segment, clamped to it.
  var t = -(ax * dx + ay * dy) / lengthSquared;
  t = t.clamp(0.0, 1.0);
  final closestX = ax + t * dx;
  final closestY = ay + t * dy;
  return math.sqrt(closestX * closestX + closestY * closestY);
}

/// True when the point deviates more than [thresholdMeters] from the nearest
/// route point/segment (blueprint decision: 50 meters). An empty route is
/// never "off route" — there is no route to deviate from.
bool isOffRoute(
  double lat,
  double lng,
  List<RoutePoint> points, {
  double thresholdMeters = 50,
}) {
  if (points.isEmpty) return false;
  return distanceToRouteMeters(lat, lng, points) > thresholdMeters;
}

/// Index of the point in [points] nearest to (lat, lng).
int nearestPointIndex(double lat, double lng, List<RoutePoint> points) {
  var bestIndex = 0;
  var bestDistance = double.infinity;
  for (var i = 0; i < points.length; i++) {
    final distance = distanceMetersBetween(lat, lng, points[i].lat, points[i].lng);
    if (distance < bestDistance) {
      bestDistance = distance;
      bestIndex = i;
    }
  }
  return bestIndex;
}

/// The unvisited sublist of [points] starting at the point nearest to
/// (lat, lng). The traveled segment is `points[0..nearestIndex]`, so the UI
/// can render the traveled portion dimmed and the remainder bright/thick.
List<RoutePoint> remainingRouteFrom(
  double lat,
  double lng,
  List<RoutePoint> points,
) {
  if (points.isEmpty) return const [];
  return points.sublist(nearestPointIndex(lat, lng, points));
}

/// Distance in meters remaining along the polyline from (lat, lng): the leg
/// from the position to the nearest route point plus every subsequent segment.
/// This is the locally-recomputed value the bottom sheet displays instead of
/// re-fetching geometry per tick (blueprint §7.2.2).
double remainingDistanceMeters(double lat, double lng, List<RoutePoint> points) {
  if (points.isEmpty) return 0;
  final startIndex = nearestPointIndex(lat, lng, points);
  var total =
      distanceMetersBetween(lat, lng, points[startIndex].lat, points[startIndex].lng);
  for (var i = startIndex; i < points.length - 1; i++) {
    total += distanceMetersBetween(
      points[i].lat,
      points[i].lng,
      points[i + 1].lat,
      points[i + 1].lng,
    );
  }
  return total;
}

/// Local estimate of remaining travel time in seconds: the total duration
/// scaled by the remaining fraction of the total distance (blueprint §7.2.2 —
/// recompute locally from GPS + already-downloaded geometry, never re-fetch
/// per tick). Degenerate inputs (empty route / zero total distance) fall back
/// to the full [totalDurationSeconds].
int remainingDurationSeconds(
  double lat,
  double lng,
  List<RoutePoint> points, {
  required double totalDistanceMeters,
  required int totalDurationSeconds,
}) {
  if (points.isEmpty || totalDistanceMeters <= 0) return totalDurationSeconds;
  final remaining = remainingDistanceMeters(lat, lng, points);
  return (totalDurationSeconds * remaining / totalDistanceMeters).round();
}

/// Index into [instructions] of the first instruction whose `pointIndex` is
/// strictly ahead of the point nearest to (lat, lng). Returns 0 when the
/// inputs are empty or every instruction has already been passed (the banner
/// falls back to the first instruction, mirroring the no-fix state).
int nextInstructionIndexFor(
  double lat,
  double lng,
  List<RouteInstruction> instructions,
  List<RoutePoint> points,
) {
  if (instructions.isEmpty || points.isEmpty) return 0;
  final nearestIndex = nearestPointIndex(lat, lng, points);
  for (var i = 0; i < instructions.length; i++) {
    if (instructions[i].pointIndex > nearestIndex) return i;
  }
  return 0;
}

// ---------------------------------------------------------------------------
// Shared distance/duration formatting (used by the screen's bottom bar,
// instruction banner, and the foreground-service notification).
// ---------------------------------------------------------------------------

/// Formats seconds as `Xh Ym`, or `Ym` under an hour (matches the pre-existing
/// route-share screen convention).
String formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

/// Formats meters as `X.X km` at/above 1 km, otherwise `N m` (matches the
/// pre-existing route-share screen convention).
String formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.toInt()} m';
}

// ---------------------------------------------------------------------------
// Persistent foreground-service notification content (blueprint §7.2.3: the
// Android foreground-service notification shows the next instruction plus the
// remaining distance/ETA, mirroring Google Maps' own notification).
// ---------------------------------------------------------------------------

/// Content shown by the persistent foreground-service notification.
class NavigationNotificationContent {
  final String title;
  final String body;

  const NavigationNotificationContent({required this.title, required this.body});

  @override
  bool operator ==(Object other) =>
      other is NavigationNotificationContent &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(title, body);
}

/// Composes the persistent-notification title/body from the next-instruction
/// text and the already-formatted remaining distance / ETA labels (produced
/// by [remainingDistanceMeters] / [remainingDurationSeconds] plus the shared
/// km/m and h/min formatting).
///
/// The templates are caller-supplied localized strings using the placeholders
/// `{instruction}`, `{distance}` and `{eta}` (defaults are plain English so
/// the function is usable and testable standalone). Empty values substitute
/// to an empty string — never a leftover placeholder or a throw.
NavigationNotificationContent buildNavigationNotificationContent({
  required String instructionText,
  required String distanceLabel,
  required String etaLabel,
  String titleTemplate = '{instruction}',
  String bodyTemplate = '{distance} · {eta} remaining',
}) {
  return NavigationNotificationContent(
    title: titleTemplate.replaceAll('{instruction}', instructionText),
    body: bodyTemplate
        .replaceAll('{distance}', distanceLabel)
        .replaceAll('{eta}', etaLabel),
  );
}
