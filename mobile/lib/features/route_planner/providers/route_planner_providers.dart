import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/endpoints/routes_endpoints.dart';

/// Singleton [RoutesEndpoints] wired to the shared [ApiClient] from the
/// auth layer.
final routesEndpointsProvider = Provider<RoutesEndpoints>((ref) {
  return RoutesEndpoints(ref.read(apiClientProvider));
});

/// Routing profiles the mobile route planner offers, verified against the
/// backend's profile handling.
///
/// The backend `RouteCalculateRequest` accepts any `profile` string and
/// forwards it to GraphHopper; the constraint engine's `validate_profile`
/// whitelist is `{truck, truck_fast, truck_safe, truck_cheap, truck_short,
/// car, bike, foot}` and `Config.GRAPHHOPPER_PROFILES` maps the truck
/// strategy presets. The mobile selector deliberately offers the core trio
/// (truck / car / foot) to stay bounded; `truck_fast`, `truck_safe`,
/// `truck_cheap`, `truck_short` and `bike` also pass backend validation but
/// are omitted from the UI.
class RouteProfile {
  final String id;
  final String labelKey;

  const RouteProfile({required this.id, required this.labelKey});

  static const truck = RouteProfile(id: 'truck', labelKey: 'routePlanner_profileTruck');
  static const car = RouteProfile(id: 'car', labelKey: 'routePlanner_profileCar');
  static const foot = RouteProfile(id: 'foot', labelKey: 'routePlanner_profilePedestrian');

  static const List<RouteProfile> values = [truck, car, foot];
}

/// The full set of countries offered in the "countries to avoid" selector.
///
/// Fixed EU-27 list (the backend `avoid_countries` handler consumes ISO
/// alpha-2 codes).
const List<String> kAvoidableCountries = [
  'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR',
  'DE', 'GR', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL',
  'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE',
];

/// Inputs for a `POST /api/v1/routes/calculate` call.
///
/// Value type so it can be the family argument of [routeCalculateProvider] —
/// changing any input (points, profile, exclusions) re-fetches.
class RouteRequestConfig {
  final List<String> points;
  final String profile;
  final List<String> excludedCountries;

  const RouteRequestConfig({
    required this.points,
    this.profile = 'truck',
    this.excludedCountries = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteRequestConfig &&
          _listEquals(points, other.points) &&
          profile == other.profile &&
          _listEquals(excludedCountries, other.excludedCountries);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(points), profile, Object.hashAll(excludedCountries));

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Builds the request body for `POST /api/v1/routes/calculate`.
///
/// Matches the backend `RouteCalculateRequest` schema: every point is sent
/// as a place-name string. The §2 parity contract adds
/// `excluded_countries: Optional[List[str]]` — sent only when non-empty so
/// older backends (without the field) keep working.
Map<String, dynamic> buildRouteRequest(
  List<String> addressPoints, {
  String profile = 'truck',
  List<String> excludedCountries = const [],
}) =>
    {
      'points': addressPoints,
      'profile': profile,
      if (excludedCountries.isNotEmpty)
        'excluded_countries': excludedCountries,
    };

/// A single turn-by-turn instruction along a calculated route.
class RouteStepInstruction {
  final String text;
  final double distanceMeters;
  final int pointIndex;

  const RouteStepInstruction({
    required this.text,
    required this.distanceMeters,
    required this.pointIndex,
  });

  factory RouteStepInstruction.fromJson(Map<String, dynamic> json) =>
      RouteStepInstruction(
        text: json['text'] as String? ?? '',
        distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0,
        pointIndex: json['point_index'] as int? ?? 0,
      );
}

/// Parsed result of a `POST /api/v1/routes/calculate` call.
class RouteOptimizationResult {
  /// Total route distance in meters (converted from backend `distance_km`).
  final double distanceMeters;

  /// Total route duration in seconds (converted from backend `duration_min`).
  final int durationSeconds;

  /// Ordered geometry points (origin → destination).
  final List<LatLng> geometry;

  /// Turn-by-turn instructions (empty when the backend omits them).
  final List<RouteStepInstruction> instructions;

  const RouteOptimizationResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.geometry,
    this.instructions = const [],
  });

  factory RouteOptimizationResult.fromJson(Map<String, dynamic> json) {
    final distanceKm = (json['distance_km'] as num?)?.toDouble() ?? 0;
    final durationMin = (json['duration_min'] as num?)?.toDouble() ?? 0;
    final geometry = (json['geometry'] as List<dynamic>?)
            ?.map(_latLngFromJson)
            .whereType<LatLng>()
            .toList() ??
        const [];
    final instructions = (json['instructions'] as List<dynamic>?)
            ?.map((e) => RouteStepInstruction.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    return RouteOptimizationResult(
      distanceMeters: distanceKm * 1000,
      durationSeconds: (durationMin * 60).round(),
      geometry: geometry,
      instructions: instructions,
    );
  }
}

/// Parses a `[lat, lng]` pair (as returned by the backend geometry) into a
/// [LatLng], or `null` when the shape is unexpected.
LatLng? _latLngFromJson(dynamic entry) {
  if (entry is List && entry.length >= 2) {
    return LatLng(
      (entry[0] as num).toDouble(),
      (entry[1] as num).toDouble(),
    );
  }
  return null;
}

/// Calculates an optimized route for the given [config] (origin + waypoints +
/// destination points, routing profile, excluded countries).
///
/// Owns a [CancelToken] per in-flight request tied to the provider lifecycle
/// (§1.2): closing the result sheet or navigating away disposes the family
/// instance and cancels the call — a disposed provider has no listeners, so
/// the cancellation never surfaces as an error state.
///
/// Throws on network/server errors or unexpected payload shapes; callers
/// surface the resulting error state and can retry by invalidating this
/// provider.
final routeCalculateProvider = FutureProvider.family<RouteOptimizationResult,
    RouteRequestConfig>((ref, config) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final endpoints = ref.watch(routesEndpointsProvider);
  final response = await endpoints.calculateRoute(
    buildRouteRequest(
      config.points,
      profile: config.profile,
      excludedCountries: config.excludedCountries,
    ),
    cancelToken: cancelToken,
  );
  final data = response.data;
  if (data is! Map<String, dynamic>) {
    throw StateError('Unexpected response type: ${data.runtimeType}');
  }
  final route = data['route'];
  if (route is! Map<String, dynamic>) {
    throw StateError('Missing route payload in response');
  }
  return RouteOptimizationResult.fromJson(route);
});
