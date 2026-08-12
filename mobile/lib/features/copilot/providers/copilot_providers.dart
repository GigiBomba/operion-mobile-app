import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permission_guard.dart';
import '../../../core/network/endpoints/copilot_endpoints.dart';
import '../../../core/sync/action_queue.dart';
import '../../fleet/models/truck.dart';
import '../../fleet/providers/fleet_providers.dart';
import '../models/copilot_models.dart';

// ── Foundation providers ─────────────────────────────────────────────────

final copilotEndpointsProvider = Provider<CopilotEndpoints>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CopilotEndpoints(apiClient);
});

// ── State providers ──────────────────────────────────────────────────────

/// The possible states of the Co-Pilot mobile interface (§32.1).
///
/// Mirrors the backend's own state machine (§7) — the mobile app is a
/// renderer of server-authoritative state, not an independent source of truth.
sealed class CopilotMobileState {
  const CopilotMobileState();
}

class CopilotIdle extends CopilotMobileState {
  const CopilotIdle();
}

class CopilotListening extends CopilotMobileState {
  const CopilotListening();
}

class CopilotProcessing extends CopilotMobileState {
  const CopilotProcessing();
}

class CopilotAwaitingClarification extends CopilotMobileState {
  final String questionKey;
  final Map<String, dynamic> params;
  const CopilotAwaitingClarification({
    required this.questionKey,
    this.params = const {},
  });
}

class CopilotAwaitingConfirmation extends CopilotMobileState {
  final CopilotExecutionPlan plan;
  const CopilotAwaitingConfirmation({required this.plan});
}

/// Record-maintenance quick-capture (blueprint §9 item 4).
///
/// Replaces [CopilotAwaitingConfirmation] when the execution plan contains a
/// `record_maintenance` step AND the current user holds
/// `can_schedule_maintenance`. The mobile app OWNS execution for this step:
/// the plan is never confirmed through the backend `confirmPlan` path. Instead
/// the UI pre-fills the record-work sheet and submits through the SAME
/// `fleetMutationProvider.recordMaintenance` reference used by the manual
/// form ([submitRecordMaintenance]) — see [submit] (identity proof target).
class CopilotAwaitingMaintenanceCapture extends CopilotMobileState {
  final CopilotExecutionPlan plan;

  /// The mapped sheet pre-fill (category/cost/notes/date + plate hint).
  final MaintenancePrefill prefill;

  /// Resolved target truck id: from `truck_id`, or a fleet-cache plate match.
  /// `null` when the truck cannot be resolved → the UI must pick one.
  final String? truckId;

  /// The EXACT mutation entry point shared with the manual maintenance form —
  /// the top-level [submitRecordMaintenance] function (blueprint §9 item 4).
  /// Top-level function references are identical in Dart, so the intent-proof
  /// test asserts `identical(capture.submit, submitRecordMaintenance)`.
  final Future<void> Function(
    WidgetRef ref,
    String truckId,
    MaintenanceRecordDraft draft,
  ) submit;

  const CopilotAwaitingMaintenanceCapture({
    required this.plan,
    required this.prefill,
    required this.truckId,
    required this.submit,
  });
}

class CopilotExecuting extends CopilotMobileState {
  final List<CopilotExecutionStep> timeline;
  const CopilotExecuting({this.timeline = const []});
}

class CopilotCompleted extends CopilotMobileState {
  final String? summaryKey;
  final Map<String, dynamic> params;
  const CopilotCompleted({this.summaryKey, this.params = const {}});
}

class CopilotError extends CopilotMobileState {
  final String messageKey;
  const CopilotError({required this.messageKey});
}

/// StateNotifier managing the Co-Pilot conversation lifecycle.
///
/// Rules (§32.1):
/// 1. Only renders states the backend actually produced
/// 2. No locally-invented states for Level 1+ (optimistic UI OK for Level 0)
/// 3. Timeline updates rebuild only the changed step widget, not the whole screen
class CopilotStateNotifier extends StateNotifier<CopilotMobileState> {
  final CopilotEndpoints _endpoints;

  /// Optional [Ref] enabling the `record_maintenance` quick-capture
  /// interception (permission check + truck resolution + the shared submit
  /// closure). Tests that only exercise plain confirmation flows may omit it.
  final Ref? _ref;

  /// One [CancelToken] per notifier lifecycle (§1.2).
  ///
  /// Every in-flight Copilot request carries this token; [dispose] cancels it
  /// so navigating away from the chat screen never leaves a stray request or
  /// surfaces a spurious error state. The pattern is established here first
  /// (Gate 1 — D4/F1) and mirrored by every blueprint-feature provider.
  final CancelToken _cancelToken = CancelToken();

  String? _conversationId;

  CopilotStateNotifier(this._endpoints, [this._ref]) : super(const CopilotIdle());

  /// The backend tool name intercepted for maintenance quick-capture.
  static const recordMaintenanceToolName = 'record_maintenance';

  bool get _canScheduleMaintenance =>
      _ref?.read(permissionProvider).can(Permissions.scheduleMaintenance) ??
      false;

  /// The notifier's in-flight [CancelToken] (test seam).
  @visibleForTesting
  CancelToken get cancelToken => _cancelToken;

  /// True when the in-flight request was cancelled (test seam).
  @visibleForTesting
  bool get isCancelled => _cancelToken.isCancelled;

  @override
  void dispose() {
    _cancelToken.cancel();
    super.dispose();
  }

  String? get conversationId => _conversationId;

  /// Submit a text utterance to the Co-Pilot.
  Future<void> sendMessage(String utterance) async {
    if (utterance.trim().isEmpty) return;
    state = const CopilotProcessing();
    try {
      final response = await _endpoints.chat(
        utterance: utterance,
        conversationId: _conversationId,
        cancelToken: _cancelToken,
      );
      _conversationId = response.conversationId;
      await _handleResponse(response);
    } on DioException catch (e) {
      // Cancelling the token on dispose must never surface as an error state.
      if (e.type == DioExceptionType.cancel) return;
      state = const CopilotError(messageKey: 'copilot.error.unexpected');
    } catch (e) {
      state = const CopilotError(messageKey: 'copilot.error.unexpected');
    }
  }

  /// Confirm a plan that's awaiting confirmation.
  ///
  /// For Level 3 confirmation, pass the typed [confirmationPhrase].
  ///
  /// NOTE: `record_maintenance` plans NEVER arrive here — they are intercepted
  /// into [CopilotAwaitingMaintenanceCapture] and executed through the mobile
  /// mutation path (blueprint §9 item 4), so no parallel server execution
  /// exists for that step.
  Future<void> confirmPlan({String? confirmationPhrase}) async {
    final current = state;
    if (current is! CopilotAwaitingConfirmation) return;
    state = CopilotExecuting(timeline: current.plan.steps);
    try {
      await _endpoints.confirmPlan(
        current.plan.planId,
        _cancelToken,
        confirmationPhrase: confirmationPhrase,
      );
      state = const CopilotCompleted(summaryKey: 'copilot.summary.confirmed');
    } on DioException catch (e) {
      // Cancelling the token on dispose must never surface as an error state.
      if (e.type == DioExceptionType.cancel) return;
      state = const CopilotError(messageKey: 'copilot.error.unexpected');
    } catch (e) {
      state = const CopilotError(messageKey: 'copilot.error.unexpected');
    }
  }

  /// Confirm a `record_maintenance` quick-capture.
  ///
  /// The mutation itself is executed by the capture UI through
  /// [CopilotAwaitingMaintenanceCapture.submit] — the SAME top-level
  /// [submitRecordMaintenance] reference as the manual form. This method then
  /// cancels the pending server plan (the mobile owns execution for this
  /// step; no `confirmPlan`) and completes.
  Future<void> completeMaintenanceCapture() async {
    final current = state;
    if (current is! CopilotAwaitingMaintenanceCapture) return;
    try {
      // Best-effort: drop the pending plan so it cannot linger server-side.
      try {
        await _endpoints.cancelPlan(current.plan.planId);
      } catch (_) {
        // Non-fatal — the maintenance record itself is already persisted.
      }
      state = const CopilotCompleted(
        summaryKey: 'copilot.summary.maintenanceSaved',
      );
    } catch (_) {
      state = const CopilotError(messageKey: 'copilot.error.unexpected');
    }
  }

  /// Cancel the current plan.
  Future<void> cancelPlan() async {
    final current = state;
    final CopilotExecutionPlan plan;
    if (current is CopilotAwaitingConfirmation) {
      plan = current.plan;
    } else if (current is CopilotAwaitingMaintenanceCapture) {
      plan = current.plan;
    } else {
      return;
    }
    try {
      await _endpoints.cancelPlan(plan.planId);
      state = const CopilotIdle();
    } on DioException catch (e) {
      // Cancelling the token on dispose must never surface as an error state.
      if (e.type == DioExceptionType.cancel) return;
      state = const CopilotError(messageKey: 'copilot.error.unexpected');
    } catch (e) {
      state = const CopilotError(messageKey: 'copilot.error.unexpected');
    }
  }

  Future<void> _handleResponse(CopilotResponse response) async {
    if (response.clarificationQuestionKey != null) {
      state = CopilotAwaitingClarification(
        questionKey: response.clarificationQuestionKey!,
        params: response.clarificationParams,
      );
    } else if (response.plan != null && response.plan!.requiresConfirmation) {
      final plan = response.plan!;
      final step = _maintenanceStep(plan);
      if (step != null && _canScheduleMaintenance) {
        // Blueprint §9 item 4: the mobile owns `record_maintenance` execution.
        final prefill = MaintenancePrefill.fromStepParameters(step.parameters);
        final truckId = await _resolveTruckId(step.parameters);
        state = CopilotAwaitingMaintenanceCapture(
          plan: plan,
          prefill: prefill,
          truckId: truckId,
          submit: submitRecordMaintenance,
        );
      } else {
        state = CopilotAwaitingConfirmation(plan: plan);
      }
    } else if (response.summaryKey != null) {
      state = CopilotCompleted(
        summaryKey: response.summaryKey,
        params: response.summaryParams,
      );
    } else {
      state = const CopilotCompleted();
    }
  }

  /// The first `record_maintenance` step in [plan], if any.
  static CopilotExecutionStep? _maintenanceStep(CopilotExecutionPlan plan) {
    for (final step in plan.steps) {
      if (step.toolName == recordMaintenanceToolName) return step;
    }
    return null;
  }

  /// Resolves the target truck id for a `record_maintenance` step.
  ///
  /// Prefers `truck_id`; otherwise matches `plate_number` against the fleet
  /// cache (never the network — this is a read-only hint resolution).
  Future<String?> _resolveTruckId(Map<String, dynamic> parameters) async {
    final rawTruckId = parameters['truck_id'];
    if (rawTruckId != null) return rawTruckId.toString();
    final plate = parameters['plate_number']?.toString();
    if (plate == null || plate.isEmpty || _ref == null) return null;
    try {
      final trucks = await _ref.read(localDatabaseProvider).getCachedFleet();
      for (final t in trucks) {
        if (t['plate'] == plate) return t['id']?.toString();
      }
    } catch (_) {
      // Cache unavailable — the UI falls back to a truck picker.
    }
    return null;
  }

  void reset() {
    _conversationId = null;
    state = const CopilotIdle();
  }
}

final copilotStateProvider =
    StateNotifierProvider<CopilotStateNotifier, CopilotMobileState>((ref) {
  final endpoints = ref.watch(copilotEndpointsProvider);
  return CopilotStateNotifier(endpoints, ref);
});
