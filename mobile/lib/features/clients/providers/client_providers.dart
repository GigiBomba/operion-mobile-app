import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/dio_errors.dart';
import '../../../core/network/endpoints/client_endpoints.dart';
import '../../../core/network/paginated.dart';
import '../../../core/security/biometric_gate.dart';
import '../../../core/sync/action_queue.dart';
import '../../invoicing/providers/invoicing_providers.dart'
    show BiometricRequired;
import '../models/client.dart';

/// Provides the singleton [ClientEndpoints] wired to the shared [ApiClient].
final clientEndpointsProvider = Provider<ClientEndpoints>((ref) {
  return ClientEndpoints(ref.read(apiClientProvider));
});

/// True while the client list/detail is showing cached (stale) data.
final clientCachedBannerProvider = StateProvider<bool>((ref) => false);

/// Debounced server-side search query for the client list.
final clientSearchProvider = StateProvider<String>((ref) => '');

/// Result of a client list fetch.
class ClientListData {
  final List<Client> clients;
  final bool fromCache;

  const ClientListData({required this.clients, required this.fromCache});
}

/// Result of a client detail fetch.
class ClientDetailData {
  final Client client;
  final bool fromCache;

  const ClientDetailData({required this.client, required this.fromCache});
}

/// Dual-mode client list (blueprint §5).
///
/// Network first; on failure falls back to the LocalDatabase clients cache and
/// flags [clientCachedBannerProvider]. On success the cache is refreshed.
final clientListProvider = FutureProvider.autoDispose<ClientListData>((ref) async {
  final endpoints = ref.watch(clientEndpointsProvider);
  final search = ref.watch(clientSearchProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  try {
    final response = await endpoints.getClients(
      search: search.isEmpty ? null : search,
      cancelToken: cancelToken,
    );
    final data = response.data;
    final clients = data is Map<String, dynamic>
        ? PaginatedResponse.fromJson(data, Client.fromJson).items
        : data is List
            ? data.whereType<Map<String, dynamic>>().map(Client.fromJson).toList()
            : <Client>[];
    final db = ref.read(localDatabaseProvider);
    await db.cacheClients(clients.map((c) => c.toJson()).toList());
    ref.read(clientCachedBannerProvider.notifier).state = false;
    return ClientListData(clients: clients, fromCache: false);
  } catch (e) {
    // Auth rejections (401/403) must surface (force-logout path), not fall
    // back to a stale cache flash (I1). Connection failures stay cached.
    if (isAuthRejection(e)) rethrow;
    final db = ref.read(localDatabaseProvider);
    final cached = await db.getCachedClients();
    final clients = cached.map(Client.fromJson).toList();
    ref.read(clientCachedBannerProvider.notifier).state = clients.isNotEmpty;
    return ClientListData(clients: clients, fromCache: true);
  }
});

/// Dual-mode client detail (`GET /mobile/clients/{id}`), caching to the same
/// `clients` collection. Rethrows when neither network nor cache can satisfy.
final clientDetailProvider = FutureProvider.autoDispose
    .family<ClientDetailData, String>((ref, clientId) async {
  final endpoints = ref.watch(clientEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  try {
    final response = await endpoints.getClient(clientId, cancelToken: cancelToken);
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected client detail response: ${data.runtimeType}');
    }
    final client = Client.fromJson(data);
    await ref
        .read(localDatabaseProvider)
        .cacheData('clients', clientId, client.toJson());
    ref.read(clientCachedBannerProvider.notifier).state = false;
    return ClientDetailData(client: client, fromCache: false);
  } catch (e) {
    // 401/403 must propagate to the force-logout path (I1), not the cache.
    if (isAuthRejection(e)) rethrow;
    final cached = await ref.read(localDatabaseProvider).getCachedData('clients', clientId);
    if (cached == null) rethrow;
    return ClientDetailData(client: Client.fromJson(cached), fromCache: true);
  }
});

/// Thrown by [ClientMutationNotifier.mergeClients] when offline.
///
/// Merges are NEVER queued (blueprint §7): unlike the other CRUD mutations,
/// an offline merge would silently drop the source-into-target mapping, so it
/// requires a live connection and surfaces this typed error instead.
class MergeRequiresConnection implements Exception {
  const MergeRequiresConnection();
}

// §12 biometric rejection for mergeClients reuses the invoicing
// [BiometricRequired] (imported above) — one canonical exception, not a
// per-feature duplicate.

// ── Mutations (offline → queue per §7, EXCEPT merge) ──────────────────

/// Client mutation state. createClient/updateClient/addContact queue offline;
/// mergeClients never queues and requires connectivity.
final clientMutationProvider =
    StateNotifierProvider<ClientMutationNotifier, AsyncValue<void>>((ref) {
  return ClientMutationNotifier(ref);
});

class ClientMutationNotifier extends StateNotifier<AsyncValue<void>> {
  ClientMutationNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  bool get _isOffline => _ref.read(isOfflineProvider);

  Future<void> createClient(ClientDraft draft) async {
    if (_isOffline) {
      await _enqueue('/api/v1/mobile/clients', 'POST', draft.toJson());
      return;
    }
    state = const AsyncLoading();
    try {
      await _ref.read(clientEndpointsProvider).createClient(draft.toJson());
      state = const AsyncData(null);
      _ref.invalidate(clientListProvider);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> updateClient(String clientId, ClientDraft draft) async {
    if (_isOffline) {
      await _enqueue('/api/v1/mobile/clients/$clientId', 'PATCH', draft.toJson());
      return;
    }
    state = const AsyncLoading();
    try {
      await _ref.read(clientEndpointsProvider).updateClient(clientId, draft.toJson());
      state = const AsyncData(null);
      _ref.invalidate(clientListProvider);
      _ref.invalidate(clientDetailProvider(clientId));
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> addContact(String clientId, ClientContactDraft draft) async {
    if (_isOffline) {
      await _enqueue(
        '/api/v1/mobile/clients/$clientId/contacts',
        'POST',
        draft.toJson(),
      );
      return;
    }
    state = const AsyncLoading();
    try {
      await _ref.read(clientEndpointsProvider).addContact(clientId, draft.toJson());
      state = const AsyncData(null);
      _ref.invalidate(clientDetailProvider(clientId));
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  /// Merges [sourceIds] into [targetId] — DIRECT call only.
  ///
  /// NEVER queued: throws [MergeRequiresConnection] when offline so the UI can
  /// show the inline "requires an internet connection" message (blueprint §7).
  ///
  /// §12 biometric step-up: prompts BEFORE any network call — a failed
  /// confirmation throws [BiometricRequired] and the merge endpoint is never
  /// reached (test-proven, mirrors the invoicing finance pattern).
  Future<ClientMergeResult> mergeClients({
    required String targetId,
    required List<String> sourceIds,
    String? biometricReason,
  }) async {
    if (_isOffline) {
      state = const AsyncError(
        MergeRequiresConnection(),
        StackTrace.empty,
      );
      throw const MergeRequiresConnection();
    }
    final ok = await _ref
        .read(biometricGateProvider)
        .requireBiometricConfirmation(
          reason: biometricReason ?? BiometricGate.defaultReason,
        );
    if (!ok) {
      state = const AsyncError(BiometricRequired(), StackTrace.empty);
      throw const BiometricRequired();
    }
    state = const AsyncLoading();
    try {
      final response = await _ref.read(clientEndpointsProvider).mergeClients(
            targetId: targetId,
            sourceIds: sourceIds,
          );
      final data = response.data;
      final result = data is Map<String, dynamic>
          ? ClientMergeResult.fromJson(data)
          : const ClientMergeResult();
      state = const AsyncData(null);
      _ref.invalidate(clientListProvider);
      _ref.invalidate(clientDetailProvider(targetId));
      return result;
    } catch (e, s) {
      state = AsyncError(e, s);
      rethrow;
    }
  }

  Future<void> _enqueue(
    String endpoint,
    String method,
    Map<String, dynamic> data,
  ) async {
    await _ref.read(actionQueueProvider).enqueue(endpoint, method, data: data);
  }
}
