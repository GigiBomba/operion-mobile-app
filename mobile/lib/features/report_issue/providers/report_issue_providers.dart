import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/providers/issue_providers.dart';
import '../../document_center/providers/document_center_providers.dart';
import '../data/report_conversation_store.dart';
import '../models/report_thread.dart';

/// Which half of the Report an Issue sheet is visible.
///
/// Mode A (compose) is used when no active unresolved report exists; Mode B
/// (thread) shows the durable reply thread (blueprint 41.3d/e).
enum ReportIssueMode { compose, thread }

/// A screenshot selected from the camera roll and waiting to be submitted.
@immutable
class ReportAttachment {
  const ReportAttachment({required this.path, required this.name});

  final String path;
  final String name;
}

/// User-actionable failures surfaced inline in the sheet.
enum ReportIssueError { threadLoad, submit, attachmentUpload, reply }

/// Local UI state for the Report an Issue sheet.
@immutable
class ReportIssueState {
  const ReportIssueState({
    this.loading = false,
    this.submitting = false,
    this.submittedAck = false,
    this.thread,
    this.composingNew = false,
    this.threadRequested = false,
    this.error,
    this.attachment,
  });

  /// A persisted thread is being fetched (`GET /threads/{id}`).
  final bool loading;

  /// A submit / reply / screenshot upload is in flight.
  final bool submitting;

  /// The just-submitted report acknowledgement is being shown.
  final bool submittedAck;

  /// The active thread, or `null` when none is persisted/known.
  final ReportThread? thread;

  /// True after "Report a new issue" (or "Cancel") switches back to Mode A
  /// while an old thread still exists on the backend.
  final bool composingNew;

  /// True once a load for a known/persisted conversation has been attempted.
  ///
  /// Distinguishes "no report yet" (Compose) from "a report exists but the
  /// fetch failed" (Thread error state) when [thread] is still null.
  final bool threadRequested;

  final ReportIssueError? error;
  final ReportAttachment? attachment;

  bool get hasThread => thread != null && thread!.conversationId.isNotEmpty;

  ReportIssueMode get mode =>
      composingNew || (!threadRequested && !hasThread)
          ? ReportIssueMode.compose
          : ReportIssueMode.thread;

  /// The reply composer is shown ONLY while ARGO's clarifying question is
  /// still awaiting an answer (blueprint 41.3d Mode B item 4).
  bool get showReplyInput =>
      !composingNew && (thread?.canReply ?? false);

  bool get resolved => !composingNew && (thread?.resolved ?? false);

  ReportIssueState copyWith({
    bool? loading,
    bool? submitting,
    bool? submittedAck,
    ReportThread? thread,
    bool? composingNew,
    bool? threadRequested,
    Object? error = _unset,
    Object? attachment = _unset,
  }) {
    return ReportIssueState(
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      submittedAck: submittedAck ?? this.submittedAck,
      thread: thread ?? this.thread,
      composingNew: composingNew ?? this.composingNew,
      threadRequested: threadRequested ?? this.threadRequested,
      error: identical(error, _unset)
          ? this.error
          : error as ReportIssueError?,
      attachment: identical(attachment, _unset)
          ? this.attachment
          : attachment as ReportAttachment?,
    );
  }
}

const Object _unset = Object();

/// Picks a screenshot through the OS image picker.
///
/// A thin seam over [ImagePicker] so widget tests can exercise the compose
/// flow without a platform channel. The picker settings mirror the existing
/// document-upload flow (`DocumentUploadScreen`): gallery source, bounded
/// dimensions and JPEG quality.
class ReportScreenshotPicker {
  ReportScreenshotPicker({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<XFile?> pickFromGallery() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
  }
}

/// Persisted conversation-id store (company + customer scoped).
final reportConversationStoreProvider = Provider<ReportConversationStore>(
  (ref) => ReportConversationStore(),
);

/// OS screenshot picker used by the compose form.
final reportScreenshotPickerProvider = Provider<ReportScreenshotPicker>(
  (ref) => ReportScreenshotPicker(),
);

/// Drives both the Report an Issue sheet and the More-tab reply badge.
class ReportIssueController extends StateNotifier<ReportIssueState> {
  ReportIssueController(
    this._ref, {
    ReportConversationStore? store,
  })  : _store = store ?? ReportConversationStore(),
        super(const ReportIssueState());

  final Ref _ref;
  final ReportConversationStore _store;

  String? _conversationId;

  /// The conversation currently bound to this controller (test seam).
  @visibleForTesting
  String? get activeConversationId => _conversationId;

  ({String companyId, String userId}) get _scope {
    final user = _ref.read(currentUserProvider);
    return (
      companyId: user?.companyId ?? '',
      userId: user?.id ?? '',
    );
  }

  /// Loads the persisted thread (or [conversationId] when supplied by a push
  /// deep link). No persisted id -> clean Compose mode.
  ///
  /// A 404 means the proxy no longer knows the thread (retention/erasure):
  /// drop the local id and start fresh instead of trapping the user on a
  /// permanently broken thread.
  Future<void> load({String? conversationId}) async {
    if (state.submitting) return;
    final scope = _scope;
    final explicit = (conversationId ?? '').trim();
    final target = explicit.isNotEmpty
        ? explicit
        : await _store.read(companyId: scope.companyId, userId: scope.userId);

    if (target == null || target.trim().isEmpty) {
      _conversationId = null;
      state = const ReportIssueState();
      return;
    }

    final generation = ++_loadGeneration;
    state = ReportIssueState(
      loading: true,
      threadRequested: true,
      thread: state.thread,
      attachment: state.attachment,
    );

    try {
      final response =
          await _ref.read(issueEndpointsProvider).getThread(target);
      final thread = _parseThread(response.data, fallback: target);
      if (!mounted || generation != _loadGeneration) return;
      _conversationId = thread.conversationId;
      if (thread.conversationId.isNotEmpty) {
        await _store.write(
          companyId: scope.companyId,
          userId: scope.userId,
          conversationId: thread.conversationId,
        );
      }
      if (!mounted || generation != _loadGeneration) return;
      state = ReportIssueState(
        thread: thread,
        threadRequested: true,
        attachment: state.attachment,
      );
    } on DioException catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      if (e.response?.statusCode == 404) {
        await _store.clear(
          companyId: scope.companyId,
          userId: scope.userId,
        );
        if (!mounted || generation != _loadGeneration) return;
        _conversationId = null;
        state = ReportIssueState(attachment: state.attachment);
      } else {
        state = ReportIssueState(
          thread: state.thread,
          threadRequested: true,
          error: ReportIssueError.threadLoad,
          attachment: state.attachment,
        );
      }
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      state = ReportIssueState(
        thread: state.thread,
        threadRequested: true,
        error: ReportIssueError.threadLoad,
        attachment: state.attachment,
      );
    }
  }

  int _loadGeneration = 0;

  /// Re-fetches the active thread (pull-to-refresh / after a push).
  Future<void> refresh() {
    return load(conversationId: _conversationId);
  }

  /// Submits a new report (Mode A).
  ///
  /// Requires at least 10 non-whitespace characters, matching the blueprint's
  /// "not trivially empty, but short reports still allowed" rule. When a
  /// screenshot is attached it is uploaded through the existing document
  /// endpoint first and the resulting document id is referenced in the
  /// message so ARGO/the ticket can find it.
  Future<bool> submit(String rawMessage) async {
    final message = rawMessage.trim();
    if (message.length < 10 || state.submitting) return false;

    state = state.copyWith(
      submitting: true,
      submittedAck: false,
      error: null,
    );

    final attachment = state.attachment;
    try {
      var outgoing = message;
      if (attachment != null) {
        try {
          final documentId = await _uploadScreenshot(attachment.path);
          if (documentId != null && documentId.isNotEmpty) {
            outgoing =
                '$message\n\nScreenshot attached (document $documentId).';
          }
        } catch (_) {
          if (!mounted) return false;
          state = state.copyWith(
            submitting: false,
            error: ReportIssueError.attachmentUpload,
          );
          return false;
        }
      }

      final response = await _ref.read(issueEndpointsProvider).submitIssue(
            conversationId: state.composingNew
                ? null
                : state.thread?.conversationId,
            message: outgoing,
          );
      final result = _parseResult(response.data);
      final conversationId = result.conversationId.trim();
      if (conversationId.isEmpty) {
        throw StateError('support proxy omitted conversation_id');
      }

      final thread = ReportThread(
        conversationId: conversationId,
        ticketId: result.ticketId,
        status: ReportStatus.logged,
        requiresReply: result.requiresReply,
        resolved: false,
        entries: [
          ReportEntry(role: ReportEntryRole.customer, text: message),
          if (result.reply.trim().isNotEmpty)
            ReportEntry(role: ReportEntryRole.argo, text: result.reply.trim()),
        ],
      );

      final scope = _scope;
      _conversationId = conversationId;
      await _store.write(
        companyId: scope.companyId,
        userId: scope.userId,
        conversationId: conversationId,
      );
      if (!mounted) return true;
      state = ReportIssueState(thread: thread, submittedAck: true);
      return true;
    } on DioException {
      if (!mounted) return false;
      state = state.copyWith(
        submitting: false,
        error: ReportIssueError.submit,
      );
      return false;
    } catch (_) {
      if (!mounted) return false;
      state = state.copyWith(
        submitting: false,
        error: ReportIssueError.submit,
      );
      return false;
    }
  }

  /// Answers ARGO's pending clarifying question (Mode B).
  Future<bool> reply(String rawMessage) async {
    final thread = state.thread;
    if (thread == null || !thread.canReply || state.submitting) return false;
    final message = rawMessage.trim();
    if (message.isEmpty) return false;

    state = state.copyWith(submitting: true, error: null);
    try {
      final response = await _ref
          .read(issueEndpointsProvider)
          .replyToThread(thread.conversationId, message);
      final result = _parseResult(response.data);
      if (!mounted) return true;
      state = ReportIssueState(thread: thread.mergeReply(result, message));
      return true;
    } on DioException {
      if (!mounted) return false;
      state = state.copyWith(
        submitting: false,
        error: ReportIssueError.reply,
      );
      return false;
    } catch (_) {
      if (!mounted) return false;
      state = state.copyWith(
        submitting: false,
        error: ReportIssueError.reply,
      );
      return false;
    }
  }

  /// Switches back to Mode A after a resolution. The old thread stays on the
  /// backend; only the local pointer is cleared.
  Future<void> startNewReport() async {
    final scope = _scope;
    await _store.clear(companyId: scope.companyId, userId: scope.userId);
    _conversationId = null;
    state = const ReportIssueState(composingNew: true);
  }

  /// Clears the acknowledgement card without submitting anything.
  void dismissAcknowledgement() {
    state = state.copyWith(submittedAck: false);
  }

  void setAttachment(ReportAttachment attachment) {
    state = state.copyWith(attachment: attachment, error: null);
  }

  void clearAttachment() {
    state = state.copyWith(attachment: null);
  }

  Future<String?> _uploadScreenshot(String path) async {
    final response = await _ref.read(documentEndpointsProvider).uploadDocument(
          category: 'other',
          entityType: 'support_report',
          entityId: state.thread?.conversationId,
          filePath: path,
        );
    final data = response.data;
    if (data is Map) {
      final id = data['id'] ?? data['document_id'] ?? data['documentId'];
      return id?.toString();
    }
    return null;
  }

  ReportThread _parseThread(Object? data, {required String fallback}) {
    final map = _asMap(data);
    if (map == null) {
      throw StateError('Unexpected thread response: ${data.runtimeType}');
    }
    return ReportThread.fromJson(map, fallbackConversationId: fallback);
  }

  ReportSubmitResult _parseResult(Object? data) {
    final map = _asMap(data);
    if (map == null) {
      throw StateError('Unexpected support response: ${data.runtimeType}');
    }
    return ReportSubmitResult.fromJson(map);
  }

  Map<String, dynamic>? _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}

/// The shared controller for the More-tab tile, sheet and push deep links.
final reportIssueControllerProvider =
    StateNotifierProvider<ReportIssueController, ReportIssueState>((ref) {
  return ReportIssueController(
    ref,
    store: ref.read(reportConversationStoreProvider),
  );
});

/// True when ARGO's latest reply needs a customer answer. Drives the in-app
/// badge dot on the More-tab "Report an Issue" tile (blueprint 41.3e).
final reportIssueBadgeProvider = Provider<bool>((ref) {
  final thread = ref.watch(
    reportIssueControllerProvider.select((state) => state.thread),
  );
  return thread?.requiresReply ?? false;
});
