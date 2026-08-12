import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/sync/connectivity_monitor.dart';
import 'package:operion_mobile/features/history/providers/history_providers.dart';
import 'package:operion_mobile/features/settings/providers/settings_providers.dart';

/// Endpoints stub serving a paginated trips response.
class _HistoryStub extends HistoryEndpoints {
  _HistoryStub()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<Map<String, dynamic>?> queries = [];
  final List<String> paths = [];

  @override
  Future<Response> getTrips(
    TripHistoryFilter filter, {
    CancelToken? cancelToken,
  }) async {
    paths.add('/api/v1/mobile/history/trips');
    queries.add(filter.toQuery());
    return Response(
      requestOptions: RequestOptions(path: paths.last),
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
            'end_date': '2026-07-02',
            'distance_km': 450,
            'total_price_eur': 1200,
            'net_profit': 300,
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
  Future<Response> getRoutes(
    RouteHistoryFilter filter, {
    CancelToken? cancelToken,
  }) async {
    paths.add('/api/v1/mobile/history/routes');
    queries.add(filter.toQuery());
    return Response(
      requestOptions: RequestOptions(path: paths.last),
      data: {
        'items': [
          {
            'id': 1,
            'name': 'București–Cluj',
            'origin': 'București',
            'destination': 'Cluj',
            'total_distance_km': 450,
            'duration_min': 320,
            'created_at': '2026-07-01T08:00:00Z',
          },
        ],
        'total': 1,
        'page': filter.page,
        'page_size': 20,
        'total_pages': 1,
      },
      statusCode: 200,
    );
  }

  @override
  Future<Response> exportTrips(
    TripExportRequest request, {
    CancelToken? cancelToken,
  }) async {
    paths.add('/api/v1/mobile/history/trips/export');
    return Response(
      requestOptions: RequestOptions(path: paths.last),
      data: {'job_id': 'job-123'},
      statusCode: 202,
    );
  }

  @override
  Future<Response> exportStatus(
    String jobId, {
    CancelToken? cancelToken,
  }) async {
    paths.add('/api/v1/mobile/history/trips/export/$jobId/status');
    return Response(
      requestOptions: RequestOptions(path: paths.last),
      data: {'status': 'processing'},
      statusCode: 200,
    );
  }
}

void main() {
  test('tripHistoryProvider parses pagination envelope and sends filters',
      () async {
    final stub = _HistoryStub();
    final container = ProviderContainer(
      overrides: [historyEndpointsProvider.overrideWithValue(stub)],
    );
    addTearDown(container.dispose);

    final filter = TripHistoryFilter(
      status: 'Delivered',
      clientId: 'c1',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 31),
      page: 1,
    );
    final page = await container.read(tripHistoryProvider(filter).future);

    expect(stub.paths.single, '/api/v1/mobile/history/trips');
    expect(stub.queries.single!['status'], 'Delivered');
    expect(stub.queries.single!['client_id'], 'c1');
    expect(stub.queries.single!['start_date'], '2026-07-01');
    expect(stub.queries.single!['end_date'], '2026-07-31');
    expect(stub.queries.single!['page'], 1);
    expect(stub.queries.single!['page_size'], 20);
    expect(page.items.single.clientName, 'ACME');
    expect(page.total, 21);
    expect(page.totalPages, 2);
  });

  test('filter copyWith increments page for infinite scroll', () {
    const base = TripHistoryFilter(page: 1);
    final next = base.copyWith(page: 2);
    expect(next.page, 2);
    expect(next.status, base.status);
  });

  test('routeHistoryProvider parses rows', () async {
    final stub = _HistoryStub();
    final container = ProviderContainer(
      overrides: [historyEndpointsProvider.overrideWithValue(stub)],
    );
    addTearDown(container.dispose);

    final page = await container.read(
      routeHistoryProvider(const RouteHistoryFilter()).future,
    );
    expect(stub.paths.single, '/api/v1/mobile/history/routes');
    expect(page.items.single.name, 'București–Cluj');
    expect(page.items.single.totalDistanceKm, 450);
    expect(page.items.single.durationMin, 320);
  });

  test('routeThumbnailUrl builds the thumbnail path per route id', () {
    expect(
      HistoryEndpoints.routeThumbnailUrl('42'),
      '/api/v1/mobile/history/routes/42/thumbnail',
    );
    expect(
      HistoryEndpoints.routeThumbnailUrl('7'),
      '/api/v1/mobile/history/routes/7/thumbnail',
    );
  });

  test('tripHistoryExportProvider returns job_id', () async {
    final stub = _HistoryStub();
    final container = ProviderContainer(
      overrides: [
        historyEndpointsProvider.overrideWithValue(stub),
        // The Phase 4B Wi-Fi gate reads these; override so the pure-Dart test
        // never instantiates the platform ConnectivityMonitor.
        isOfflineProvider.overrideWith((ref) => false),
        isOnWifiProvider.overrideWith((ref) => Stream.value(true)),
        dataUsageProvider.overrideWith((ref) => DataUsageNotifier(ref)),
      ],
    );
    addTearDown(container.dispose);

    final jobId = await container.read(
      tripHistoryExportProvider(
        const TripExportRequest(format: 'csv', status: 'Delivered'),
      ).future,
    );
    expect(jobId, 'job-123');
  });

  test('exportJobStatusProvider polls every 3s and terminates on success',
      () {
    final progressingStub = _ProgressingExportStub();
    final container = ProviderContainer(
      overrides: [historyEndpointsProvider.overrideWithValue(progressingStub)],
    );
    addTearDown(container.dispose);

    fakeAsync((async) {
      final states = <ExportJobState>[];
      final sub = container.listen(exportJobStatusProvider('job-123'), (_, next) {
        final v = next.valueOrNull;
        if (v != null) states.add(v);
      });

      // First tick: processing (stub call 1).
      async.elapse(const Duration(seconds: 3));
      expect(states, isNotEmpty);
      expect(states.last.status, ExportJobStatus.processing);
      expect(progressingStub.calls, 1);

      // Second tick: success → stream closes.
      async.elapse(const Duration(seconds: 3));
      expect(progressingStub.calls, 2);
      expect(states.last.status, ExportJobStatus.success);
      expect(states.last.downloadUrl, 'https://cdn/export.csv');

      // No further ticks after terminal.
      async.elapse(const Duration(seconds: 9));
      expect(progressingStub.calls, 2);

      sub.close();
    });
  });
}

/// Stub that flips processing → success across polls.
class _ProgressingExportStub extends HistoryEndpoints {
  _ProgressingExportStub()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  int calls = 0;

  @override
  Future<Response> exportStatus(
    String jobId, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: calls >= 2
          ? {'status': 'success', 'download_url': 'https://cdn/export.csv'}
          : {'status': 'processing'},
      statusCode: 200,
    );
  }
}
