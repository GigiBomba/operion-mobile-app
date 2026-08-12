import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/analytics/models/date_range.dart';
import 'package:operion_mobile/features/analytics/providers/analytics_providers.dart';

/// Endpoints stub that throws (offline / server down).
class _ThrowingAnalyticsEndpoints extends AnalyticsEndpoints {
  _ThrowingAnalyticsEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  @override
  Future<Response> getRevenue(DateRange range, {CancelToken? cancelToken}) {
    throw DioException(
      requestOptions: RequestOptions(path: '/api/v1/mobile/analytics/revenue'),
      type: DioExceptionType.connectionError,
    );
  }
}

/// Endpoints stub that records paths + query params and serves canned data.
class _RecordingAnalyticsEndpoints extends AnalyticsEndpoints {
  _RecordingAnalyticsEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<String> paths = [];
  final List<Map<String, dynamic>?> queries = [];

  Map<String, dynamic>? get lastQuery =>
      queries.isEmpty ? null : queries.last;

  @override
  Future<Response> getRevenue(DateRange range, {CancelToken? cancelToken}) async {
    paths.add('/api/v1/mobile/analytics/revenue');
    queries.add({
      'start_date': range.startIso,
      'end_date': range.endIso,
      'group_by': 'period',
    });
    return Response(
      requestOptions: RequestOptions(path: paths.last),
      data: {
        'trend': [
          {'label': 'W1', 'value': 100},
          {'label': 'W2', 'value': 150},
        ],
        'per_client': [
          {'label': 'ACME', 'value': 90},
        ],
        'per_route': [
          {'label': 'București–Cluj', 'value': 250},
        ],
      },
      statusCode: 200,
    );
  }

  @override
  Future<Response> getFleetUtilization(
    DateRange range, {
    CancelToken? cancelToken,
  }) async {
    paths.add('/api/v1/mobile/analytics/fleet-utilization');
    queries.add({'start_date': range.startIso, 'end_date': range.endIso});
    return Response(
      requestOptions: RequestOptions(path: paths.last),
      data: {
        'status_split': {'active': 5, 'maintenance': 1, 'decommissioned': 1},
        'trucks': [
          {'truck': 'B-100', 'trip_count': 12, 'total_km': 3200},
        ],
      },
      statusCode: 200,
    );
  }

  @override
  Future<Response> getDriverPerformance(
    DateRange range, {
    CancelToken? cancelToken,
  }) async {
    paths.add('/api/v1/mobile/analytics/driver-performance');
    queries.add({'start_date': range.startIso, 'end_date': range.endIso});
    return Response(
      requestOptions: RequestOptions(path: paths.last),
      data: {
        'rows': [
          {
            'driver': 'Ion',
            'trips_completed': 10,
            'on_time_pct': 92.5,
            'profit_per_km': 1.2,
            'revenue': 8500,
          },
        ],
      },
      statusCode: 200,
    );
  }

  @override
  Future<Response> getInvoiceAging({CancelToken? cancelToken}) async {
    paths.add('/api/v1/mobile/analytics/invoice-aging');
    queries.add(const {});
    return Response(
      requestOptions: RequestOptions(path: paths.last),
      data: {
        'current': 12000,
        'bucket_31_60': 3000,
        'bucket_61_90': 1000,
        'overdue': 500,
        'total_outstanding': 16500,
      },
      statusCode: 200,
    );
  }

  @override
  Future<Response> export(
    DateRange range, {
    required String report,
    CancelToken? cancelToken,
  }) async {
    paths.add('/api/v1/mobile/analytics/export');
    queries.add({
      'report': report,
      'start_date': range.startIso,
      'end_date': range.endIso,
    });
    return Response(
      requestOptions: RequestOptions(path: paths.last),
      data: {
        'download_url': 'https://cdn/export.csv',
        'expires_at': '2026-08-02T10:00:00Z',
      },
      statusCode: 200,
    );
  }
}

/// Endpoints stub serving empty payloads (new company).
class _EmptyAnalyticsEndpoints extends AnalyticsEndpoints {
  _EmptyAnalyticsEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  @override
  Future<Response> getRevenue(DateRange range, {CancelToken? cancelToken}) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: <String, dynamic>{},
      statusCode: 200,
    );
  }
}

void main() {
  ProviderContainer makeContainer(AnalyticsEndpoints endpoints) {
    final container = ProviderContainer(
      overrides: [analyticsEndpointsProvider.overrideWithValue(endpoints)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('revenue provider sends date params and parses payload', () async {
    final endpoints = _RecordingAnalyticsEndpoints();
    final container = makeContainer(endpoints);
    final range = DateRange(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 31),
    );
    final data = await container.read(
      analyticsRevenueProvider((range: range, clientId: null)).future,
    );

    expect(endpoints.paths.first, '/api/v1/mobile/analytics/revenue');
    expect(endpoints.lastQuery!['start_date'], '2026-07-01');
    expect(endpoints.lastQuery!['end_date'], '2026-07-31');
    expect(endpoints.lastQuery!['group_by'], 'period');
    expect(data.trend, hasLength(2));
    expect(data.perClient.single.label, 'ACME');
    expect(data.perRoute.single.value, 250);
    expect(data.hasData, isTrue);
  });

  test('fleet utilization parses status split + truck rows', () async {
    final endpoints = _RecordingAnalyticsEndpoints();
    final container = makeContainer(endpoints);
    final data = await container.read(
      analyticsFleetUtilizationProvider(DateRange.last30Days()).future,
    );

    expect(data.statusSplit['active'], 5);
    expect(data.trucks.single['truck'], 'B-100');
    expect(data.hasData, isTrue);
  });

  test('driver performance parses rows with no rating field', () async {
    final endpoints = _RecordingAnalyticsEndpoints();
    final container = makeContainer(endpoints);
    final rows = await container.read(
      analyticsDriverPerformanceProvider(DateRange.last30Days()).future,
    );

    expect(rows, hasLength(1));
    expect(rows.single.driver, 'Ion');
    expect(rows.single.tripsCompleted, 10);
    expect(rows.single.onTimePct, 92.5);
  });

  test('invoice aging parses the four buckets + total', () async {
    final endpoints = _RecordingAnalyticsEndpoints();
    final container = makeContainer(endpoints);
    final report = await container.read(analyticsInvoiceAgingProvider.future);

    expect(report.current, 12000);
    expect(report.bucket31_60, 3000);
    expect(report.bucket61_90, 1000);
    expect(report.overdue, 500);
    expect(report.totalOutstanding, 16500);
    expect(report.hasData, isTrue);
  });

  test('export contract sends report + download_url', () async {
    final endpoints = _RecordingAnalyticsEndpoints();
    final container = makeContainer(endpoints);

    // Revenue tab export.
    final result = await container.read(
      analyticsExportProvider(
        (range: DateRange.last30Days(), report: 'revenue'),
      ).future,
    );
    expect(endpoints.lastQuery!['report'], 'revenue');
    expect(result.downloadUrl, 'https://cdn/export.csv');
    expect(result.expiresAt, isNotNull);
  });

  test('export provider passes each report through', () async {
    final endpoints = _RecordingAnalyticsEndpoints();
    final container = makeContainer(endpoints);

    for (final report in ['fleet', 'drivers', 'invoice_aging']) {
      await container.read(
        analyticsExportProvider(
          (range: DateRange.last30Days(), report: report),
        ).future,
      );
      expect(endpoints.lastQuery!['report'], report,
          reason: 'report=$report must be forwarded to the endpoint');
    }
  });

  test('network failure surfaces as error (no cache fallback)', () async {
    final container = makeContainer(_ThrowingAnalyticsEndpoints());
    await expectLater(
      container.read(
        analyticsRevenueProvider(
          (range: DateRange.last30Days(), clientId: null),
        ).future,
      ),
      throwsA(isA<DioException>()),
    );
  });

  test('empty datasets parse to empty structures with hasData=false', () async {
    final container = makeContainer(_EmptyAnalyticsEndpoints());
    final data = await container.read(
      analyticsRevenueProvider(
        (range: DateRange.last30Days(), clientId: null),
      ).future,
    );
    expect(data.hasData, isFalse);
    expect(data.trend, isEmpty);
  });
}
