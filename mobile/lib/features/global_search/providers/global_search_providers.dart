import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/api_client.dart';

/// Endpoint methods for the global-search module (blueprint §6.11).
///
/// Path is relative to `/api/v1`; gates on `require_dispatcher`.
class SearchEndpoints {
  final ApiClient client;

  SearchEndpoints(this.client);

  /// `GET /mobile/search?q&types`.
  Future<Response> search(
    String query, {
    String? types,
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/search',
        queryParameters: {
          'q': query,
          if (types != null && types.isNotEmpty) 'types': types,
        },
        cancelToken: cancelToken,
      );
}

/// Provides the singleton [SearchEndpoints] wired to the shared client.
final searchEndpointsProvider = Provider<SearchEndpoints>((ref) {
  return SearchEndpoints(ref.watch(apiClientProvider));
});

/// The live search query (debounced upstream).
final globalSearchQueryProvider = StateProvider<String>((ref) => '');

/// One result type section.
class SearchSection {
  const SearchSection({required this.items, required this.totalCount});

  /// Capped at 5 items by the backend.
  final List<Map<String, dynamic>> items;

  /// The true total across all matches (may exceed `items.length`).
  final int totalCount;

  int get remaining => (totalCount - items.length).clamp(0, totalCount);

  factory SearchSection.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return const SearchSection(items: [], totalCount: 0);
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    return SearchSection(
      items: items,
      totalCount: (json['total_count'] as num?)?.toInt() ?? items.length,
    );
  }
}

/// Parsed global-search response.
class GlobalSearchResults {
  const GlobalSearchResults({
    required this.trips,
    required this.clients,
    required this.drivers,
    required this.trucks,
    required this.documents,
  });

  final SearchSection trips;
  final SearchSection clients;
  final SearchSection drivers;
  final SearchSection trucks;
  final SearchSection documents;

  bool get isEmpty =>
      trips.items.isEmpty &&
      clients.items.isEmpty &&
      drivers.items.isEmpty &&
      trucks.items.isEmpty &&
      documents.items.isEmpty;

  factory GlobalSearchResults.fromJson(Map<String, dynamic> json) =>
      GlobalSearchResults(
        trips: SearchSection.fromJson(json['trips']),
        clients: SearchSection.fromJson(json['clients']),
        drivers: SearchSection.fromJson(json['drivers']),
        trucks: SearchSection.fromJson(json['trucks']),
        documents: SearchSection.fromJson(json['documents']),
      );
}

/// Debounced global-search provider.
///
/// - 1-char queries return an EMPTY result without touching the network.
/// - 2+ char queries fire after a 350ms debounce window.
/// - The Timer is cancelled on provider dispose (§5 debounce pattern).
final globalSearchResultsProvider = FutureProvider.autoDispose
    .family<GlobalSearchResults, String>((ref, query) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) {
    return const GlobalSearchResults(
      trips: SearchSection(items: [], totalCount: 0),
      clients: SearchSection(items: [], totalCount: 0),
      drivers: SearchSection(items: [], totalCount: 0),
      trucks: SearchSection(items: [], totalCount: 0),
      documents: SearchSection(items: [], totalCount: 0),
    );
  }

  // Debounce: wait 350ms; cancel on dispose.
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final completer = Completer<void>();
  final timer = Timer(const Duration(milliseconds: 350), () {
    completer.complete();
  });
  ref.onDispose(() {
    timer.cancel();
    if (!completer.isCompleted) completer.complete();
  });
  await completer.future;

  final endpoints = ref.watch(searchEndpointsProvider);
  final response = await endpoints.search(
    trimmed,
    types: 'trips,clients,drivers,trucks,documents',
    cancelToken: cancelToken,
  );
  final data = response.data;
  if (data is! Map<String, dynamic>) {
    throw StateError('Unexpected search response: ${data.runtimeType}');
  }
  return GlobalSearchResults.fromJson(data);
});
