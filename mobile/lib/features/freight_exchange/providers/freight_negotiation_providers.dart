import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../models/freight_negotiation.dart';
import 'freight_exchange_providers.dart';

/// Fetches the negotiation thread for a load.
///
/// `GET /freight/loads/{provider_id}/{load_id}/negotiation` → 200
/// `{thread: [...]}`. Owns a [CancelToken] per in-flight request tied to the
/// provider lifecycle (§1.2) — navigating away disposes the family instance
/// and cancels the call, so a disposed provider's cancellation never surfaces
/// as an error state.
final freightNegotiationProvider =
    FutureProvider.family<FreightNegotiationThread,
        ({String providerId, String loadId})>((ref, target) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final response = await ref.read(freightEndpointsProvider).getNegotiationThread(
        target.providerId,
        target.loadId,
        cancelToken: cancelToken,
      );
  final data = response.data;
  if (data is Map<String, dynamic>) {
    return FreightNegotiationThread.fromJson(data);
  }
  throw StateError('Unexpected negotiation response: ${data.runtimeType}');
});

/// State of a negotiation action (accept / reject / counter).
class FreightNegotiationActionState {
  final bool busy;

  /// Localization key of the failure message; null when idle/successful.
  final String? errorKey;

  const FreightNegotiationActionState({this.busy = false, this.errorKey});

  FreightNegotiationActionState copyWith({bool? busy, String? errorKey}) {
    return FreightNegotiationActionState(
      busy: busy ?? this.busy,
      errorKey: errorKey ?? this.errorKey,
    );
  }
}

/// Runs negotiation actions (accept / reject / counter).
///
/// Rules:
/// - **Live connection only**: negotiation is a live action — offline the
///   action is BLOCKED with the localized 'requires connection' message and is
///   NEVER queued (mirrors the finance §7 rule for live actions).
/// - On success the thread provider is invalidated so the sheet re-fetches the
///   updated thread (the 200 `{negotiation: record}` may also be returned but
///   the invalidation is the source of truth for the thread rendering).
/// - One [CancelToken] per notifier lifecycle (§1.2): [dispose] cancels it so
///   navigating away never leaves a stray request or surfaces a spurious
///   error state.
class FreightNegotiationNotifier
    extends StateNotifier<FreightNegotiationActionState> {
  FreightNegotiationNotifier(this._ref) : super(const FreightNegotiationActionState());

  final Ref _ref;

  /// One [CancelToken] per notifier lifecycle (§1.2).
  final CancelToken _cancelToken = CancelToken();

  /// The notifier's in-flight [CancelToken] (test seam).
  @visibleForTesting
  CancelToken get cancelToken => _cancelToken;

  bool get _isOffline => _ref.read(isOfflineProvider);

  @override
  void dispose() {
    _cancelToken.cancel();
    super.dispose();
  }

  /// Accepts the current offer/counter.
  Future<bool> accept({
    required String providerId,
    required String loadId,
  }) =>
      _run(providerId, loadId, action: 'accept');

  /// Rejects the current offer/counter.
  Future<bool> reject({
    required String providerId,
    required String loadId,
  }) =>
      _run(providerId, loadId, action: 'reject');

  /// Sends a counter offer of [amountEur].
  Future<bool> counter({
    required String providerId,
    required String loadId,
    required double amountEur,
  }) =>
      _run(providerId, loadId, action: 'counter', amountEur: amountEur);

  /// Shared runner: validates offline, calls the endpoint, invalidates the
  /// thread on success, and always settles the busy/error state.
  Future<bool> _run(
    String providerId,
    String loadId, {
    required String action,
    double? amountEur,
  }) async {
    if (state.busy) return false;
    if (_isOffline) {
      // Live action — never queued (§7-style rule for live connections).
      state = const FreightNegotiationActionState(
        errorKey: 'freightNegotiation_offline',
      );
      return false;
    }
    state = const FreightNegotiationActionState(busy: true);
    try {
      await _ref
          .read(freightEndpointsProvider)
          .postNegotiationAction(
            providerId,
            loadId,
            action: action,
            amountEur: amountEur,
            cancelToken: _cancelToken,
          );
      _ref.invalidate(
        freightNegotiationProvider((providerId: providerId, loadId: loadId)),
      );
      state = const FreightNegotiationActionState();
      return true;
    } on DioException catch (e) {
      // Cancelling the token on dispose must never surface as an error state.
      if (e.type == DioExceptionType.cancel) return false;
      state = const FreightNegotiationActionState(
        errorKey: 'freightNegotiation_error',
      );
      return false;
    } catch (_) {
      state = const FreightNegotiationActionState(
        errorKey: 'freightNegotiation_error',
      );
      return false;
    }
  }
}

/// Provides the negotiation action notifier wired to the shared client.
final freightNegotiationActionProvider =
    StateNotifierProvider<FreightNegotiationNotifier, FreightNegotiationActionState>(
        (ref) {
  return FreightNegotiationNotifier(ref);
});
