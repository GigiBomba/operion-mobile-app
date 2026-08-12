import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/global_search/providers/global_search_providers.dart';

void main() {
  test('1-char query returns empty result WITHOUT network', () {
    fakeAsync((async) {
      final stub = _RecordingSearchEndpoints();
      final container = ProviderContainer(
        overrides: [searchEndpointsProvider.overrideWithValue(stub)],
      );
      addTearDown(container.dispose);

      GlobalSearchResults? result;
      container.listen(globalSearchResultsProvider('a'), (_, next) {
        result = next.valueOrNull;
      });
      // Advance past the debounce window.
      async.elapse(const Duration(milliseconds: 400));
      expect(result, isNotNull);
      expect(result!.isEmpty, isTrue);
      expect(stub.calls, 0, reason: '1-char query must not hit the network');
    });
  });

  test('2-char query fires after 350ms debounce', () {
    fakeAsync((async) {
      final stub = _RecordingSearchEndpoints();
      final container = ProviderContainer(
        overrides: [searchEndpointsProvider.overrideWithValue(stub)],
      );
      addTearDown(container.dispose);

      GlobalSearchResults? result;
      container.listen(globalSearchResultsProvider('ac'), (_, next) {
        result = next.valueOrNull;
      });

      // Before the debounce window elapses: no network call.
      async.elapse(const Duration(milliseconds: 200));
      expect(stub.calls, 0);

      // After 350ms: fired.
      async.elapse(const Duration(milliseconds: 200));
      expect(stub.calls, 1);
      expect(result, isNotNull);
      expect(stub.lastQuery, 'ac');
    });
  });

  test('results parse per-type sections with total_count', () async {
    final stub = _RecordingSearchEndpoints();
    final container = ProviderContainer(
      overrides: [searchEndpointsProvider.overrideWithValue(stub)],
    );
    addTearDown(container.dispose);

    final results = await container.read(globalSearchResultsProvider('acm').future);
    expect(results.clients.items, hasLength(1));
    expect(results.clients.totalCount, 3);
    expect(results.clients.remaining, 2);
    expect(results.trips.items, hasLength(5));
    expect(results.trips.totalCount, 12);
    expect(results.trips.remaining, 7);
    expect(results.isEmpty, isFalse);
  });
}

class _RecordingSearchEndpoints extends SearchEndpoints {
  _RecordingSearchEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  int calls = 0;
  String? lastQuery;

  @override
  Future<Response> search(
    String query, {
    String? types,
    CancelToken? cancelToken,
  }) async {
    calls++;
    lastQuery = query;
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'trips': {
          'items': List.generate(5, (i) => {'id': i, 'name': 'Trip $i'}),
          'total_count': 12,
        },
        'clients': {
          'items': [
            {'id': 1, 'name': 'ACME'},
          ],
          'total_count': 3,
        },
        'drivers': {'items': [], 'total_count': 0},
        'trucks': {'items': [], 'total_count': 0},
        'documents': {'items': [], 'total_count': 0},
      },
      statusCode: 200,
    );
  }
}
