import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/routes_endpoints.dart';
import 'package:operion_mobile/features/route_planner/providers/route_planner_providers.dart';

/// Backend-shaped fixture for `POST /api/v1/routes/calculate`.
///
/// Mirrors `RouteCalculateRequest` (points as place-name strings + truck
/// profile) and the `RouteResponse` payload returned by RouteService
/// (`distance_km`, `duration_min`, `geometry` as [lat, lng] pairs,
/// `instructions` with `text` / `distance_meters` / `point_index`).
const Map<String, dynamic> _cannedRouteResponse = {
  'status': 'ok',
  'route': {
    'distance_km': 124.5,
    'duration_min': 96.0,
    'geometry': [
      [44.4268, 26.1025],
      [45.0, 26.5],
      [46.7712, 23.6236],
    ],
    'instructions': [
      {'text': 'Turn right', 'distance_meters': 120, 'point_index': 0},
      {'text': 'Keep straight', 'distance_meters': 250, 'point_index': 1},
    ],
  },
};

/// Stub that resolves route calculation calls without touching the network
/// (same pattern as the trip-overview tests).
class _StubRoutesEndpoints extends RoutesEndpoints {
  _StubRoutesEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => null,
        ));

  Map<String, dynamic>? lastPayload;

  @override
  Future<Response> calculateRoute(
    Map<String, dynamic> payload, {
    CancelToken? cancelToken,
  }) async {
    lastPayload = payload;
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: _cannedRouteResponse,
    );
  }
}

void main() {
  group('buildRouteRequest (contract parity with RouteCalculateRequest)', () {
    test('matches the backend request fixture exactly', () {
      final points = ['Bucharest', 'Ploiești', 'Cluj-Napoca'];
      expect(buildRouteRequest(points), {
        'points': ['Bucharest', 'Ploiești', 'Cluj-Napoca'],
        'profile': 'truck',
      });
    });

    test('sends place-name strings unchanged and keeps the truck profile', () {
      final request = buildRouteRequest(['București', 'Sibiu']);
      expect(request['points'], isA<List<String>>());
      expect(request['points'], ['București', 'Sibiu']);
      expect(request['profile'], 'truck');
    });
  });

  group('routeCalculateProvider (parity with the backend response)', () {
    test('posts the exact request body', () async {
      final stub = _StubRoutesEndpoints();
      final container = ProviderContainer(overrides: [
        routesEndpointsProvider.overrideWithValue(stub),
      ]);
      addTearDown(container.dispose);

      final points = ['Bucharest', 'Cluj-Napoca'];
      await container
          .read(routeCalculateProvider(RouteRequestConfig(points: points)).future);

      expect(stub.lastPayload, {
        'points': ['Bucharest', 'Cluj-Napoca'],
        'profile': 'truck',
      });
    });

    test('sends profile and excluded_countries when configured', () async {
      final stub = _StubRoutesEndpoints();
      final container = ProviderContainer(overrides: [
        routesEndpointsProvider.overrideWithValue(stub),
      ]);
      addTearDown(container.dispose);

      await container.read(
        routeCalculateProvider(
          const RouteRequestConfig(
            points: ['Bucharest', 'Budapest'],
            profile: 'car',
            excludedCountries: ['HU', 'BG'],
          ),
        ).future,
      );

      expect(stub.lastPayload, {
        'points': ['Bucharest', 'Budapest'],
        'profile': 'car',
        'excluded_countries': ['HU', 'BG'],
      });
    });

    test('parses distance, duration, geometry and instructions', () async {
      final container = ProviderContainer(overrides: [
        routesEndpointsProvider.overrideWithValue(_StubRoutesEndpoints()),
      ]);
      addTearDown(container.dispose);

      final result = await container
          .read(routeCalculateProvider(const RouteRequestConfig(points: ['A', 'B'])).future);

      // distance_km = 124.5 → 124500 meters.
      expect(result.distanceMeters, closeTo(124500.0, 0.001));
      // duration_min = 96 → 5760 seconds.
      expect(result.durationSeconds, 5760);

      // geometry = [[lat, lng], ...] pairs.
      expect(result.geometry, hasLength(3));
      expect(result.geometry.first.latitude, closeTo(44.4268, 0.0001));
      expect(result.geometry.first.longitude, closeTo(26.1025, 0.0001));
      expect(result.geometry.last.latitude, closeTo(46.7712, 0.0001));
      expect(result.geometry.last.longitude, closeTo(23.6236, 0.0001));

      // instructions parsed into local step objects.
      expect(result.instructions, hasLength(2));
      expect(result.instructions.first.text, 'Turn right');
      expect(result.instructions.first.distanceMeters, closeTo(120.0, 0.001));
      expect(result.instructions.first.pointIndex, 0);
    });

    test('surfaces malformed responses as provider errors', () async {
      final container = ProviderContainer(overrides: [
        routesEndpointsProvider.overrideWith(
          (ref) => _MalformedRoutesEndpoints(),
        ),
      ]);
      addTearDown(container.dispose);

      await expectLater(
        container.read(routeCalculateProvider(const RouteRequestConfig(points: ['A', 'B'])).future),
        throwsStateError,
      );
    });
  });
}

class _MalformedRoutesEndpoints extends RoutesEndpoints {
  _MalformedRoutesEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => null,
        ));

  @override
  Future<Response> calculateRoute(
    Map<String, dynamic> payload, {
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: <String, dynamic>{'status': 'ok', 'route': 'not-a-map'},
    );
  }
}
