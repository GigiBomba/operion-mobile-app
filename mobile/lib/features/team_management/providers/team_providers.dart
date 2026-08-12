import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permission_guard.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_errors.dart';
import '../../../core/network/paginated.dart';
import '../../../core/security/biometric_gate.dart';
import '../../../core/sync/action_queue.dart';
import '../../invoicing/providers/invoicing_providers.dart'
    show BiometricRequired;
import '../models/team_member.dart';

/// Endpoint methods for team management (blueprint §4.9).
///
/// All paths are relative to `/api/v1` and every mutation gates on
/// `can_manage_users` (manager+).
class TeamEndpoints {
  final ApiClient client;

  TeamEndpoints(this.client);

  /// `GET /mobile/team?page&page_size&search` → PaginatedResponse[TeamMemberOut].
  Future<Response> getMembers({
    int page = 1,
    int pageSize = 100,
    String? search,
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/team',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (search != null && search.isNotEmpty) 'search': search,
        },
        cancelToken: cancelToken,
      );

  /// `POST /mobile/team/invite {email, role}` — role ∈ {dispatcher, manager}.
  Future<Response> invite(
    String email,
    String role, {
    CancelToken? cancelToken,
  }) =>
      client.post(
        '/api/v1/mobile/team/invite',
        data: {'email': email, 'role': role},
        cancelToken: cancelToken,
      );

  /// `PATCH /mobile/team/{user_id} {role?, is_active?}`.
  Future<Response> updateUser(
    String userId,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) =>
      client.patch('/api/v1/mobile/team/$userId',
          data: data, cancelToken: cancelToken);
}

/// Provides the singleton [TeamEndpoints] wired to the shared client.
final teamEndpointsProvider = Provider<TeamEndpoints>((ref) {
  return TeamEndpoints(ref.watch(apiClientProvider));
});

// ── List (dual-mode: network → cache, §5) ───────────────────────────────

/// True while the team list is showing cached (stale) data.
final teamCachedBannerProvider = StateProvider<bool>((ref) => false);

/// Result of a team-list fetch.
class TeamListData {
  final List<TeamMember> members;
  final bool fromCache;

  const TeamListData({required this.members, required this.fromCache});
}

/// The team user list shown by the Team Management screen.
///
/// Dual-mode (blueprint §5): network first, cache refresh on success, cache
/// fallback + banner on connection failure. 401/403 propagate (I1).
final teamMembersProvider = FutureProvider<TeamListData>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final endpoints = ref.watch(teamEndpointsProvider);
  try {
    final response = await endpoints.getMembers(cancelToken: cancelToken);
    final data = response.data;
    final members = data is Map<String, dynamic>
        ? PaginatedResponse.fromJson(data, TeamMember.fromJson).items
        : data is List
            ? data.whereType<Map<String, dynamic>>().map(TeamMember.fromJson).toList()
            : <TeamMember>[];
    await ref
        .read(localDatabaseProvider)
        .cacheTeamMembers(members.map((m) => m.toJson()).toList());
    ref.read(teamCachedBannerProvider.notifier).state = false;
    return TeamListData(members: members, fromCache: false);
  } catch (e) {
    if (isAuthRejection(e)) rethrow;
    final cached = await ref.read(localDatabaseProvider).getCachedTeamMembers();
    final members = cached.map(TeamMember.fromJson).toList();
    ref.read(teamCachedBannerProvider.notifier).state = members.isNotEmpty;
    return TeamListData(members: members, fromCache: true);
  }
});

// ── Mutations (all gated can_manage_users) ──────────────────────────────

/// Thrown when the current user lacks `can_manage_users` (client-side
/// defense-in-depth; the server enforces the same gate).
class TeamNotPermitted implements Exception {
  const TeamNotPermitted();
}

/// Thrown when a team mutation requires a live connection (never queued —
/// admin/security actions stay synchronous).
class TeamRequiresConnection implements Exception {
  const TeamRequiresConnection();
}

// §12 biometric rejection for deactivate reuses the invoicing
// [BiometricRequired] (imported above) — one canonical exception, not a
// per-feature duplicate.

/// Team mutation state.
class TeamMutationState {
  final bool busy;
  final String? error;

  const TeamMutationState({this.busy = false, this.error});

  TeamMutationState copyWith({bool? busy, String? error}) {
    return TeamMutationState(busy: busy ?? this.busy, error: error ?? this.error);
  }
}

final teamMutationProvider =
    StateNotifierProvider<TeamMutationNotifier, TeamMutationState>((ref) {
  return TeamMutationNotifier(ref);
});

class TeamMutationNotifier extends StateNotifier<TeamMutationState> {
  TeamMutationNotifier(this._ref) : super(const TeamMutationState());

  final Ref _ref;

  bool get _canManageUsers =>
      _ref.read(permissionProvider).can(Permissions.canManageUsers);

  /// Invites a new member. [role] must be `dispatcher` or `manager` (the
  /// server rejects `admin`; the dropdown restricts the same way).
  Future<void> invite({required String email, required String role}) async {
    if (!_canManageUsers) {
      state = state.copyWith(error: 'not_permitted');
      throw const TeamNotPermitted();
    }
    if (_ref.read(isOfflineProvider)) {
      state = state.copyWith(error: 'requires_connection');
      throw const TeamRequiresConnection();
    }
    state = state.copyWith(busy: true, error: null);
    try {
      await _ref.read(teamEndpointsProvider).invite(email, role);
      _onSuccess();
    } catch (e, s) {
      state = state.copyWith(busy: false, error: '$e');
      Error.throwWithStackTrace(e, s);
    }
  }

  /// Changes a member's role (server constrains to `{dispatcher, manager}`).
  Future<void> updateRole({required String userId, required String role}) async {
    if (!_canManageUsers) {
      state = state.copyWith(error: 'not_permitted');
      throw const TeamNotPermitted();
    }
    if (_ref.read(isOfflineProvider)) {
      state = state.copyWith(error: 'requires_connection');
      throw const TeamRequiresConnection();
    }
    state = state.copyWith(busy: true, error: null);
    try {
      await _ref.read(teamEndpointsProvider).updateUser(userId, {'role': role});
      _onSuccess();
    } catch (e, s) {
      state = state.copyWith(busy: false, error: '$e');
      Error.throwWithStackTrace(e, s);
    }
  }

  /// Deactivates a member — the server revokes their sessions in the same
  /// transaction (mobile_devices + refresh tokens).
  ///
  /// §12 biometric step-up: prompts BEFORE any network call — a failed
  /// confirmation throws [BiometricRequired] and the endpoint is never
  /// reached (test-proven, mirrors the invoicing finance pattern).
  Future<void> deactivate({required String userId, String? biometricReason}) async {
    if (!_canManageUsers) {
      state = state.copyWith(error: 'not_permitted');
      throw const TeamNotPermitted();
    }
    if (_ref.read(isOfflineProvider)) {
      state = state.copyWith(error: 'requires_connection');
      throw const TeamRequiresConnection();
    }
    final ok = await _ref
        .read(biometricGateProvider)
        .requireBiometricConfirmation(
          reason: biometricReason ?? BiometricGate.defaultReason,
        );
    if (!ok) {
      state = state.copyWith(error: 'biometric_required');
      throw const BiometricRequired();
    }
    state = state.copyWith(busy: true, error: null);
    try {
      await _ref.read(teamEndpointsProvider).updateUser(userId, {'is_active': false});
      _onSuccess();
    } catch (e, s) {
      state = state.copyWith(busy: false, error: '$e');
      Error.throwWithStackTrace(e, s);
    }
  }

  void _onSuccess() {
    state = state.copyWith(busy: false, error: null);
    _ref.invalidate(teamMembersProvider);
  }
}
