import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/api_client.dart';
import '../models/freight_load.dart';/// Load-board filter state (origin, destination, date, cargo type).
///
/// Plain value type so it can be used as a `StateProvider` value and as the
/// family argument of [freightLoadsProvider].
class FreightLoadFilter {
  final String origin;
  final String destination;
  final DateTime? date;
  final String? cargoType;

  const FreightLoadFilter({
    this.origin = '',
    this.destination = '',
    this.date,
    this.cargoType,
  });

  bool get isActive =>
      origin.isNotEmpty ||
      destination.isNotEmpty ||
      date != null ||
      (cargoType != null && cargoType!.isNotEmpty);

  /// Query parameters for `GET /api/v1/freight/loads` (ISO date for `date`).
  Map<String, dynamic> toQueryParameters() => {
        if (origin.isNotEmpty) 'origin': origin,
        if (destination.isNotEmpty) 'destination': destination,
        if (date != null) 'date': _isoDate(date!),
        if (cargoType != null && cargoType!.isNotEmpty) 'cargo_type': cargoType,
      };

  static String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FreightLoadFilter &&
          origin == other.origin &&
          destination == other.destination &&
          date == other.date &&
          cargoType == other.cargoType;

  @override
  int get hashCode => Object.hash(origin, destination, date, cargoType);

  @override
  String toString() =>
      'FreightLoadFilter(origin: $origin, destination: $destination, '
      'date: $date, cargoType: $cargoType)';
}

/// The load-board filter state edited by the filter/search UI.
final freightExchangeFilterProvider =
    StateProvider<FreightLoadFilter>((ref) => const FreightLoadFilter());

/// Fetches the provider-agnostic load board.
///
/// `GET /api/v1/freight/loads` with optional `origin` / `destination` /
/// `date` / `cargo_type` query filters. The response is a list of
/// `{id, origin, destination, cargo_type, price, currency, pickup_date,
/// deadline_date, weight_kg, distance_km}` objects — no provider-specific
/// field names are referenced anywhere in the mobile layer.
///
/// Owns a [CancelToken] per in-flight request tied to the provider lifecycle
/// (§1.2): navigating away disposes the family instance and cancels the
/// call — a disposed provider has no listeners, so the cancellation never
/// surfaces as an error state.
final freightLoadsProvider =
    FutureProvider.family<List<FreightLoad>, FreightLoadFilter>(
        (ref, filter) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final client = ref.read(apiClientProvider);
  final response = await client.get(
    '/api/v1/freight/loads',
    queryParameters: filter.toQueryParameters(),
    cancelToken: cancelToken,
  );
  final data = response.data;
  if (data is List) {
    return data
        .whereType<Map<String, dynamic>>()
        .map(FreightLoad.fromJson)
        .toList();
  }
  throw StateError('Unexpected freight list response: ${data.runtimeType}');
});

/// Resolves the import endpoint target for a load.
///
/// The fixed contract is `POST /api/v1/freight/loads/{provider_id}/
/// {load_id}/import` while the provider-agnostic list only carries a single
/// `id`. Prefer an explicit `provider_id` from the payload, then a composite
/// `provider_id/load_id` id.
///
/// Returns `null` when the provider id cannot be resolved — the caller must
/// surface a localized error instead of guessing a provider (Gate 2 — M1:
/// never a silent `'current'` provider guess).
({String providerId, String loadId})? resolveImportTarget(FreightLoad load) {
  final parts = load.idParts;
  final providerId = parts.providerId;
  if (providerId == null || providerId.isEmpty) return null;
  return (providerId: providerId, loadId: parts.loadId);
}

/// Outcome of the Accept & Assign flow.
enum FreightAcceptStatus {
  idle,
  checking,
  accepted,
  taken,
  error,
}

/// State of the Accept & Assign flow.
class FreightAcceptState {
  final FreightAcceptStatus status;

  /// i18n key for the localized message shown for this outcome.
  final String? messageKey;

  const FreightAcceptState({
    this.status = FreightAcceptStatus.idle,
    this.messageKey,
  });
}

/// Accept & Assign notifier.
///
/// Per §1.6 the availability of the load is re-validated with a **live**
/// re-check immediately before the import call — the load-board cache is
/// never trusted. On conflict the flow surfaces a localized "this load was
/// just taken" state and the caller refreshes the list; there is no silent
/// retry or substitute.
class FreightExchangeAcceptNotifier extends StateNotifier<FreightAcceptState> {
  final ApiClient _client;

  /// One [CancelToken] per notifier lifecycle (§1.2).
  ///
  /// Both the live re-check and the import carry it; [dispose] cancels it so
  /// navigating away from the detail screen never leaves a stray request or
  /// surfaces a spurious error state.
  final CancelToken _cancelToken = CancelToken();

  FreightExchangeAcceptNotifier(this._client)
      : super(const FreightAcceptState());

  /// The notifier's in-flight [CancelToken] (test seam).
  @visibleForTesting
  CancelToken get cancelToken => _cancelToken;

  @override
  void dispose() {
    _cancelToken.cancel();
    super.dispose();
  }

  /// Live re-check: re-fetches the load board with the current [filter] and
  /// verifies [load] is still listed. Throws DioException on network errors.
  Future<bool> isStillAvailable(FreightLoad load, FreightLoadFilter filter) async {
    final response = await _client.get(
      '/api/v1/freight/loads',
      queryParameters: filter.toQueryParameters(),
      cancelToken: _cancelToken,
    );
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .any((json) => (json['id'] as String? ?? '') == load.id);
    }
    return false;
  }

  /// Runs the Accept & Assign flow:
  /// 1. Live re-check availability (§1.6).
  /// 2. If the load is gone → `taken` (localized message, caller refreshes).
  /// 3. Otherwise POST the import with an `Idempotency-Key` (§1.7).
  Future<void> accept({
    required FreightLoad load,
    required FreightLoadFilter filter,
    required String transportId,
  }) async {
    if (state.status == FreightAcceptStatus.checking) return;

    state = const FreightAcceptState(status: FreightAcceptStatus.checking);
    try {
      // §1.6 — never trust the value fetched earlier in the session.
      final available = await isStillAvailable(load, filter);
      if (!available) {
        state = const FreightAcceptState(
          status: FreightAcceptStatus.taken,
          messageKey: 'freightExchange_taken',
        );
        return;
      }

      final target = resolveImportTarget(load);
      if (target == null) {
        // Gate 2 — M1: an unresolvable provider id must never silently guess
        // `'current'`; surface a localized error instead.
        state = const FreightAcceptState(
          status: FreightAcceptStatus.error,
          messageKey: 'freightExchange_acceptError',
        );
        return;
      }

      await _client.postWithIdempotencyKey(
        '/api/v1/freight/loads/${target.providerId}/${target.loadId}/import',
        data: {'transport_id': transportId},
        cancelToken: _cancelToken,
      );
      state = const FreightAcceptState(status: FreightAcceptStatus.accepted);
    } on DioException catch (e) {
      // Cancelling the token on dispose must never surface as an error state.
      if (e.type == DioExceptionType.cancel) return;
      if (e.response?.statusCode == 409) {
        // Another session accepted it between the re-check and the import.
        state = const FreightAcceptState(
          status: FreightAcceptStatus.taken,
          messageKey: 'freightExchange_taken',
        );
      } else {
        state = const FreightAcceptState(
          status: FreightAcceptStatus.error,
          messageKey: 'freightExchange_acceptError',
        );
      }
    } catch (_) {
      state = const FreightAcceptState(
        status: FreightAcceptStatus.error,
        messageKey: 'freightExchange_acceptError',
      );
    }
  }

  void reset() => state = const FreightAcceptState();
}

final freightExchangeAcceptProvider =
    StateNotifierProvider<FreightExchangeAcceptNotifier, FreightAcceptState>(
        (ref) {
  return FreightExchangeAcceptNotifier(ref.read(apiClientProvider));
});

// ═════════════════════════════════════════════════════════════════════════════
// §2 Feature-parity — saved searches / advanced search / evaluate
// ═════════════════════════════════════════════════════════════════════════════

/// A saved search (GET /api/v1/freight/searches).
class SavedFreightSearch {
  final String id;
  final String label;

  /// `LoadSearchFilters` dict echoed by the backend.
  final Map<String, dynamic> filters;

  final DateTime? createdAt;
  final DateTime? lastRefreshedAt;

  const SavedFreightSearch({
    required this.id,
    required this.label,
    this.filters = const {},
    this.createdAt,
    this.lastRefreshedAt,
  });

  factory SavedFreightSearch.fromJson(Map<String, dynamic> json) {
    final rawId = json['saved_search_id'] ?? json['id'];
    return SavedFreightSearch(
      id: rawId is String || rawId is num ? '$rawId' : '',
      label: json['label'] as String? ?? '',
      filters: (json['filters'] is Map<String, dynamic>)
          ? json['filters'] as Map<String, dynamic>
          : const {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      lastRefreshedAt: json['last_refreshed_at'] != null
          ? DateTime.tryParse(json['last_refreshed_at'] as String)
          : null,
    );
  }
}

/// Endpoint methods for the freight-exchange module.
class FreightEndpoints {
  final ApiClient client;

  FreightEndpoints(this.client);

  /// `DELETE /freight/searches/{search_id}` — deletes a saved search
  /// (company + user scoped, 200 / 404).
  Future<Response> deleteSearch(String searchId) =>
      client.delete('/api/v1/freight/searches/$searchId');

  /// `GET /freight/loads/{provider_id}/{load_id}/negotiation` — the current
  /// negotiation thread for a load (`{thread: [...]}`, 200). Requires
  /// dispatcher scope on the backend.
  Future<Response> getNegotiationThread(
    String providerId,
    String loadId, {
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/freight/loads/$providerId/$loadId/negotiation',
        cancelToken: cancelToken,
      );

  /// `POST /freight/loads/{provider_id}/{load_id}/negotiation` with body
  /// `{action: 'accept'|'reject'|'counter', amount_eur?, counterparty_name?}`
  /// → 200 `{negotiation: record}` | 422 | 403. Requires dispatcher scope.
  Future<Response> postNegotiationAction(
    String providerId,
    String loadId, {
    required String action,
    double? amountEur,
    String? counterpartyName,
    CancelToken? cancelToken,
  }) =>
      client.post(
        '/api/v1/freight/loads/$providerId/$loadId/negotiation',
        data: {
          'action': action,
          'amount_eur': ?amountEur,
          if (counterpartyName != null && counterpartyName.isNotEmpty)
            'counterparty_name': counterpartyName,
        },
        cancelToken: cancelToken,
      );
}

/// Provides the singleton [FreightEndpoints] wired to the shared client.
final freightEndpointsProvider = Provider<FreightEndpoints>((ref) {
  return FreightEndpoints(ref.read(apiClientProvider));
});

/// Delete state: `busy` while a delete is in flight, `error` non-null on a
/// non-2xx/network failure.
class DeleteSavedSearchState {
  final bool busy;
  final String? error;

  const DeleteSavedSearchState({this.busy = false, this.error});

  DeleteSavedSearchState copyWith({bool? busy, String? error, bool clearError = false}) {
    return DeleteSavedSearchState(
      busy: busy ?? this.busy,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Deletes a saved search via `DELETE /api/v1/freight/searches/{search_id}`
/// and invalidates [savedFreightSearchesProvider] on success.
final deleteSavedSearchProvider = StateNotifierProvider<
    DeleteSavedSearchNotifier,
    DeleteSavedSearchState>((ref) {
  return DeleteSavedSearchNotifier(ref);
});

class DeleteSavedSearchNotifier extends StateNotifier<DeleteSavedSearchState> {
  DeleteSavedSearchNotifier(this._ref) : super(const DeleteSavedSearchState());

  final Ref _ref;

  /// Deletes [searchId]. Returns `true` on success (list invalidated).
  Future<bool> delete(String searchId) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await _ref.read(freightEndpointsProvider).deleteSearch(searchId);
      _ref.invalidate(savedFreightSearchesProvider);
      state = const DeleteSavedSearchState();
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: '$e');
      return false;
    }
  }
}

/// Fetches the saved searches for the company (GET /freight/searches).
///
/// The delete affordance ships with the mobile lane (B14) and calls the
/// backend `DELETE /freight/searches/{search_id}` added by the parallel
/// backend lane.
final savedFreightSearchesProvider =
    FutureProvider<List<SavedFreightSearch>>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final client = ref.read(apiClientProvider);
  final response = await client.get(
    '/api/v1/freight/searches',
    cancelToken: cancelToken,
  );
  final data = response.data;
  if (data is! Map<String, dynamic> || data['searches'] is! List) {
    return const [];
  }
  return (data['searches'] as List)
      .whereType<Map<String, dynamic>>()
      .map(SavedFreightSearch.fromJson)
      .where((s) => s.id.isNotEmpty)
      .toList();
});

/// Phases of the save-search flow.
enum FreightSearchSaveStatus { idle, saving, saved, error }

class FreightSearchSaveState {
  final FreightSearchSaveStatus status;
  final String? errorKey;

  const FreightSearchSaveState({this.status = FreightSearchSaveStatus.idle, this.errorKey});
}

/// Saves the current filter state as a search (POST /freight/searches).
class FreightSearchSaveNotifier extends StateNotifier<FreightSearchSaveState> {
  final ApiClient _client;

  FreightSearchSaveNotifier(this._client) : super(const FreightSearchSaveState());

  Future<bool> save({
    required String label,
    required Map<String, dynamic> filters,
  }) async {
    state = const FreightSearchSaveState(status: FreightSearchSaveStatus.saving);
    try {
      await _client.post(
        '/api/v1/freight/searches',
        data: {'label': label, 'filters': filters},
      );
      state = const FreightSearchSaveState(status: FreightSearchSaveStatus.saved);
      return true;
    } catch (_) {
      state = const FreightSearchSaveState(
        status: FreightSearchSaveStatus.error,
        errorKey: 'freightExchange_saveSearchError',
      );
      return false;
    }
  }

  void reset() => state = const FreightSearchSaveState();
}

final freightSearchSaveProvider =
    StateNotifierProvider<FreightSearchSaveNotifier, FreightSearchSaveState>(
        (ref) {
  return FreightSearchSaveNotifier(ref.read(apiClientProvider));
});

/// Re-runs a saved search (POST /freight/searches/{id}/refresh) and parses
/// the `results` (LoadSearchResult shape) into provider-agnostic loads.
final refreshSavedSearchProvider =
    FutureProvider.family<List<FreightLoad>, String>((ref, searchId) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final client = ref.read(apiClientProvider);
  final response = await client.post(
    '/api/v1/freight/searches/$searchId/refresh',
    cancelToken: cancelToken,
  );
  final data = response.data;
  if (data is! Map<String, dynamic>) return const [];
  return _parseSearchResults(data['results']);
});

/// Advanced-search filters (POST /freight/search — `SearchRequest`).
///
/// Bounded to the most useful fields per §2: origin/destination locations,
/// pickup date range, weight min/max, trailer type, price min/max. The
/// backend requires origin/destination/pickup range; the form defaults the
/// pickup window to a rolling 7-day range so the request is always valid.
class AdvancedSearchFilters {
  final String originLocation;
  final String destinationLocation;
  final DateTime? pickupDateFrom;
  final DateTime? pickupDateTo;
  final double? weightKgMin;
  final double? weightKgMax;
  final String? trailerType;
  final double? priceMin;
  final double? priceMax;

  const AdvancedSearchFilters({
    this.originLocation = '',
    this.destinationLocation = '',
    this.pickupDateFrom,
    this.pickupDateTo,
    this.weightKgMin,
    this.weightKgMax,
    this.trailerType,
    this.priceMin,
    this.priceMax,
  });

  /// Request body for `POST /api/v1/freight/search`.
  Map<String, dynamic> toRequestBody() {
    final now = DateTime.now();
    return {
      'origin_location': originLocation,
      'destination_location': destinationLocation,
      'pickup_date_from': _isoDate(pickupDateFrom ?? now),
      'pickup_date_to': _isoDate(pickupDateTo ?? now.add(const Duration(days: 7))),
      if (weightKgMin != null) 'weight_kg_min': weightKgMin,
      if (weightKgMax != null) 'weight_kg_max': weightKgMax,
      if (trailerType != null && trailerType!.isNotEmpty) 'trailer_type': [trailerType],
      if (priceMin != null) 'price_min': priceMin,
      if (priceMax != null) 'price_max': priceMax,
    };
  }

  static String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// Advanced multi-filter search (POST /freight/search).
///
/// The results list replaces the load board until the user clears it.
final advancedSearchProvider =
    FutureProvider.family<List<FreightLoad>, AdvancedSearchFilters>(
        (ref, filters) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final client = ref.read(apiClientProvider);
  final response = await client.post(
    '/api/v1/freight/search',
    data: filters.toRequestBody(),
    cancelToken: cancelToken,
  );
  final data = response.data;
  if (data is! Map<String, dynamic>) return const [];
  return _parseSearchResults(data['results']);
});

/// Parses `LoadSearchResult` payloads (from /search and /searches/{id}/refresh)
/// into provider-agnostic [FreightLoad]s.
///
/// The list endpoint already maps to `FreightLoadListItem`, but the search /
/// refresh endpoints return the raw `LoadSearchResult.model_dump()` shape —
/// `price` is `{amount, currency}`, windows are `[from, to]` ISO lists, and
/// `distance_km` is a float. Parsed defensively throughout.
List<FreightLoad> _parseSearchResults(dynamic raw) {
  if (raw is! List) return const [];
  final loads = <FreightLoad>[];
  for (final entry in raw) {
    if (entry is! Map<String, dynamic>) continue;
    final resultId = entry['result_id'] as String? ?? '';
    final providerId = entry['provider_id'] as String? ?? '';
    final providerLoadId = entry['provider_load_id'] as String? ?? '';

    final priceRaw = entry['price'];
    double? price;
    String? currency;
    if (priceRaw is Map<String, dynamic>) {
      price = (priceRaw['amount'] as num?)?.toDouble();
      currency = priceRaw['currency'] as String?;
    } else if (priceRaw is num) {
      price = priceRaw.toDouble();
    }

    final pickupWindow = entry['pickup_window'];
    final deliveryWindow = entry['delivery_window'];
    DateTime? pickupDate;
    DateTime? deadlineDate;
    if (pickupWindow is List && pickupWindow.isNotEmpty && pickupWindow.first is String) {
      pickupDate = DateTime.tryParse(pickupWindow.first as String);
    }
    if (deliveryWindow is List &&
        deliveryWindow.length > 1 &&
        deliveryWindow[1] is String) {
      deadlineDate = DateTime.tryParse(deliveryWindow[1] as String);
    }

    final distanceKm = entry['distance_km'];
    loads.add(FreightLoad(
      id: resultId.isNotEmpty
          ? resultId
          : (providerId.isNotEmpty && providerLoadId.isNotEmpty
              ? '$providerId/$providerLoadId'
              : providerLoadId),
      origin: entry['origin'] as String? ?? '',
      destination: entry['destination'] as String? ?? '',
      cargoType: entry['trailer_type'] as String?,
      price: price,
      currency: currency,
      pickupDate: pickupDate,
      deadlineDate: deadlineDate,
      weightKg: (entry['weight_kg'] as num?)?.toDouble(),
      distanceKm: distanceKm is num ? distanceKm.toStringAsFixed(1) : distanceKm as String?,
      providerId: providerId.isNotEmpty ? providerId : null,
    ));
  }
  return loads;
}

/// A vehicle compatibility result inside a load evaluation.
class EvaluationVehicleCompatibility {
  final int vehicleId;
  final bool compatible;
  final List<String> reasons;

  const EvaluationVehicleCompatibility({
    required this.vehicleId,
    required this.compatible,
    this.reasons = const [],
  });

  factory EvaluationVehicleCompatibility.fromJson(Map<String, dynamic> json) =>
      EvaluationVehicleCompatibility(
        vehicleId: (json['vehicle_id'] as num?)?.toInt() ?? 0,
        compatible: json['compatible'] as bool? ?? false,
        reasons: (json['reasons'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
      );
}

/// Parsed `GET /freight/loads/{provider_id}/{load_id}/evaluate` payload.
///
/// Mirrors the backend `LoadEvaluation` schema (all money fields are
/// `{amount, currency}`). Every field is parsed defensively.
class FreightLoadEvaluation {
  final double? estimatedRevenue;
  final double? fuelCost;
  final double? tollCost;
  final double? driverSalary;
  final double? deadheadDistanceKm;
  final double? expectedProfit;
  final double? profitMarginPct;
  final double? estimatedDurationHours;

  /// 0.0–1.0, higher = riskier.
  final double? riskScore;

  final String? currency;
  final DateTime? evaluatedAt;
  final List<EvaluationVehicleCompatibility> vehicleCompatibility;

  const FreightLoadEvaluation({
    this.estimatedRevenue,
    this.fuelCost,
    this.tollCost,
    this.driverSalary,
    this.deadheadDistanceKm,
    this.expectedProfit,
    this.profitMarginPct,
    this.estimatedDurationHours,
    this.riskScore,
    this.currency,
    this.evaluatedAt,
    this.vehicleCompatibility = const [],
  });

  factory FreightLoadEvaluation.fromJson(Map<String, dynamic> json) {
    final currency = _moneyCurrency(json['estimated_revenue']);
    return FreightLoadEvaluation(
      estimatedRevenue: _moneyAmount(json['estimated_revenue']),
      fuelCost: _moneyAmount(json['fuel_cost']),
      tollCost: _moneyAmount(json['toll_cost']),
      driverSalary: _moneyAmount(json['driver_salary']),
      deadheadDistanceKm: (json['deadhead_distance_km'] as num?)?.toDouble(),
      expectedProfit: _moneyAmount(json['expected_profit']),
      profitMarginPct: (json['profit_margin_pct'] as num?)?.toDouble(),
      estimatedDurationHours: (json['estimated_duration_hours'] as num?)?.toDouble(),
      riskScore: (json['risk_score'] as num?)?.toDouble(),
      currency: currency,
      evaluatedAt: json['evaluated_at'] != null
          ? DateTime.tryParse(json['evaluated_at'] as String)
          : null,
      vehicleCompatibility: (json['vehicle_compatibility'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(EvaluationVehicleCompatibility.fromJson)
              .toList() ??
          const [],
    );
  }

  static double? _moneyAmount(dynamic raw) {
    if (raw is Map<String, dynamic>) return (raw['amount'] as num?)?.toDouble();
    if (raw is num) return raw.toDouble();
    return null;
  }

  static String? _moneyCurrency(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw['currency'] as String?;
    return null;
  }
}

/// Fetches the profitability/risk evaluation of a load.
final freightLoadEvaluationProvider = FutureProvider.family<
    FreightLoadEvaluation,
    ({String providerId, String loadId})>((ref, target) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final client = ref.read(apiClientProvider);
  final response = await client.get(
    '/api/v1/freight/loads/${target.providerId}/${target.loadId}/evaluate',
    cancelToken: cancelToken,
  );
  final data = response.data;
  if (data is! Map<String, dynamic>) {
    throw StateError('Unexpected evaluation response: ${data.runtimeType}');
  }
  return FreightLoadEvaluation.fromJson(data);
});
