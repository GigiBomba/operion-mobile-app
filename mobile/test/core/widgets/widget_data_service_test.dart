import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/dispatcher_endpoints.dart';
import 'package:operion_mobile/core/widgets/widget_data_service.dart';
import 'package:operion_mobile/features/dispatcher/home/dispatcher_providers.dart';

class _RecordingWidgetSink {
  final Map<String, Object?> saved = {};
  final List<String> updates = [];

  Future<bool?> save(String key, Object? value) async {
    saved[key] = value;
    return true;
  }

  Future<bool?> update({
    String? name,
    String? androidName,
    String? iOSName,
    String? qualifiedAndroidName,
  }) async {
    updates.add(androidName ?? iOSName ?? '');
    return true;
  }
}

void main() {
  group('DispatcherWidgetData.fromOverviewMap — defensive parsing (5A.1)', () {
    test('parses camelCase KPI keys', () {
      final data = DispatcherWidgetData.fromOverviewMap({
        'activeJobs': 4,
        'openAlerts': 2,
        'revenue_to_date': 1234.56,
      });
      expect(data.activeJobs, 4);
      expect(data.openAlerts, 2);
      expect(data.revenueToDate, 1234.56);
    });

    test('parses snake_case KPI keys', () {
      final data = DispatcherWidgetData.fromOverviewMap({
        'active_jobs': 5,
        'open_alerts': 1,
        'revenue_to_date': '999.5',
      });
      expect(data.activeJobs, 5);
      expect(data.openAlerts, 1);
      expect(data.revenueToDate, 999.5);
    });

    test('missing revenue_to_date is tolerated (nullable)', () {
      final data = DispatcherWidgetData.fromOverviewMap({
        'activeJobs': 3,
        'openAlerts': 0,
      });
      expect(data.revenueToDate, isNull);
      expect(data.toWidgetData(), isNot(contains('revenue_to_date')));
    });

    test('missing/odd types degrade to zero without throwing', () {
      final data = DispatcherWidgetData.fromOverviewMap({
        'activeJobs': 'not-a-number',
        'openAlerts': null,
      });
      expect(data.activeJobs, 0);
      expect(data.openAlerts, 0);
    });

    test('string numeric values parse to ints', () {
      final data = DispatcherWidgetData.fromOverviewMap({
        'activeJobs': '7',
        'openAlerts': '3',
      });
      expect(data.activeJobs, 7);
      expect(data.openAlerts, 3);
    });
  });

  group('WidgetDataService — data push (5A.1)', () {
    test('pushDispatcherData writes every key and calls updateWidget', () async {
      final sink = _RecordingWidgetSink();
      final service = WidgetDataService(
        saveWidgetData: sink.save,
        updateWidget: sink.update,
      );

      await service.pushDispatcherData(
        const DispatcherWidgetData(
          activeJobs: 3,
          openAlerts: 1,
          revenueToDate: 2500.75,
        ),
      );

      expect(sink.saved['active_jobs'], '3');
      expect(sink.saved['open_alerts'], '1');
      expect(sink.saved['revenue_to_date'], '2500.75');
      expect(sink.updates, contains(WidgetDataService.dispatcherWidgetName));
    });

    test('pushDriverData writes next-stop keys for the driver widget', () async {
      final sink = _RecordingWidgetSink();
      final service = WidgetDataService(
        saveWidgetData: sink.save,
        updateWidget: sink.update,
      );

      await service.pushDriverData(
        const DriverWidgetData(nextStop: 'Cluj-Napoca', activeTrip: 'TRIP-42'),
      );

      expect(sink.saved['next_stop'], 'Cluj-Napoca');
      expect(sink.saved['active_trip'], 'TRIP-42');
      expect(sink.updates, contains(WidgetDataService.driverWidgetName));
    });

    test('refreshOverview is best-effort (never throws on failure)', () async {
      final container = ProviderContainer(
        overrides: [
          dispatcherEndpointsProvider.overrideWith((ref) {
            return _ThrowingDispatcherEndpoints();
          }),
        ],
      );
      addTearDown(container.dispose);

      final sink = _RecordingWidgetSink();
      final service = WidgetDataService(
        saveWidgetData: sink.save,
        updateWidget: sink.update,
      );

      await service.refreshOverview(container);
      // Network failure → no data pushed, no exception surfaced.
      expect(sink.saved, isEmpty);
    });
  });

  group('WidgetDataService — provider-driven refresh (5A.1)', () {
    test('refreshOverview pushes KPIs from the overview provider', () async {
      final container = ProviderContainer(
        overrides: [
          dispatcherEndpointsProvider.overrideWith(
            (ref) => _FixedDispatcherEndpoints(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sink = _RecordingWidgetSink();
      final service = WidgetDataService(
        saveWidgetData: sink.save,
        updateWidget: sink.update,
      );

      await service.refreshOverview(container);

      expect(sink.saved['active_jobs'], '3');
      expect(sink.saved['open_alerts'], '2');
      expect(sink.saved['revenue_to_date'], '1200.00');
      expect(sink.updates, isNotEmpty);
    });
  });
}

/// Endpoints whose overview call fails (network error).
class _ThrowingDispatcherEndpoints implements DispatcherEndpoints {
  @override
  ApiClient get client => _client;

  static final _client = ApiClient.create(
    baseUrl: 'https://test.example.com',
    getAccessToken: () async => null,
    getRefreshToken: () async => null,
    saveTokens: (_, _) async {},
    clearTokens: () async {},
  );

  @override
  Future<Response> getOverview() {
    return Future.error(Exception('network unavailable'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) return null;
    if (invocation.isMethod) {
      return Future.error(Exception('network unavailable'));
    }
    return null;
  }
}

/// Endpoints returning a fixed overview payload.
class _FixedDispatcherEndpoints implements DispatcherEndpoints {
  @override
  ApiClient get client => _ThrowingDispatcherEndpoints().client;

  @override
  Future<Response> getOverview() async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'activeJobs': 3, 'openAlerts': 2, 'revenue_to_date': 1200},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) return null;
    if (invocation.isMethod) {
      return Future.value(
        Response(requestOptions: RequestOptions(path: ''), data: {}),
      );
    }
    return null;
  }
}
