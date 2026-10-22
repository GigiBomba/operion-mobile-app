import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../models/report_thread.dart';
import '../providers/report_issue_providers.dart';

/// Opens the Report an Issue flow as a bottom sheet (blueprint 41.3e).
///
/// [conversationId] is supplied by a support-reply push deep link; when it is
/// omitted the controller resumes the persisted conversation (if any).
Future<void> showReportIssueSheet(
  BuildContext context, {
  String? conversationId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ReportIssueSheet(conversationId: conversationId),
  );
}

/// Compose/Thread content shared by the bottom sheet and the full-screen
/// push deep-link host.
///
/// Mode A (Compose) is shown when no active unresolved report exists; Mode B
/// (Thread) renders the status, original report, ARGO replies and - only
/// while ARGO awaits an answer - the reply composer (blueprint 41.3d/e).
class ReportIssueSheet extends ConsumerStatefulWidget {
  const ReportIssueSheet({super.key, this.conversationId});

  /// Existing thread to load, from a push tap or past-report entry.
  final String? conversationId;

  @override
  ConsumerState<ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends ConsumerState<ReportIssueSheet> {
  final TextEditingController _messageCtrl = TextEditingController();
  final TextEditingController _replyCtrl = TextEditingController();

  Timer? _ackTimer;
  bool _pickingScreenshot = false;

  @override
  void initState() {
    super.initState();
    _messageCtrl.addListener(_onMessageChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(reportIssueControllerProvider.notifier)
            .load(conversationId: widget.conversationId),
      );
    });
  }

  @override
  void dispose() {
    _ackTimer?.cancel();
    _messageCtrl.removeListener(_onMessageChanged);
    _messageCtrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  void _onMessageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickScreenshot() async {
    if (_pickingScreenshot) return;
    setState(() => _pickingScreenshot = true);
    try {
      final picked = await ref
          .read(reportScreenshotPickerProvider)
          .pickFromGallery();
      if (picked == null || !mounted) return;
      ref
          .read(reportIssueControllerProvider.notifier)
          .setAttachment(
            ReportAttachment(path: picked.path, name: picked.name),
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.loc.reportIssue_attachmentError),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingScreenshot = false);
    }
  }

  Future<void> _submit() async {
    final controller = ref.read(reportIssueControllerProvider.notifier);
    final ok = await controller.submit(_messageCtrl.text);
    if (!ok || !mounted) return;
    _messageCtrl.clear();
    // Blueprint 41.3d: the confirmation is visible briefly, then the sheet
    // closes on its own. Cancelled in dispose so no timer outlives the route.
    _ackTimer?.cancel();
    _ackTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (ref.read(reportIssueControllerProvider).submittedAck) {
        Navigator.of(context).maybePop();
      }
    });
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text;
    if (text.trim().isEmpty) return;
    final ok = await ref
        .read(reportIssueControllerProvider.notifier)
        .reply(text);
    if (!ok || !mounted) return;
    _replyCtrl.clear();
    // Re-read the canonical thread after the loop advances (status/replies),
    // keeping the merged local state visible while the request is in flight.
    unawaited(ref.read(reportIssueControllerProvider.notifier).refresh());
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportIssueControllerProvider);
    final loc = context.loc;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          child: state.submittedAck
              ? _buildAcknowledgement(loc)
              : state.mode == ReportIssueMode.compose
              ? _buildCompose(state, loc)
              : _buildThread(state, loc),
        ),
      ),
    );
  }

  // -- Header --------------------------------------------------------

  Widget _buildHeader({
    required AppLocalizations loc,
    required String title,
    required VoidCallback? onRefresh,
    Widget? statusChip,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (statusChip != null) ...[
                const SizedBox(height: AppSpacing.sm),
                statusChip,
              ],
            ],
          ),
        ),
        if (onRefresh != null)
          IconButton(
            tooltip: loc.reportIssue_refresh,
            onPressed: onRefresh,
            icon: const Icon(LucideIcons.refreshCw, size: 20),
          ),
        IconButton(
          tooltip: loc.reportIssue_close,
          onPressed: _close,
          icon: const Icon(Icons.close, size: 20),
        ),
      ],
    );
  }

  Widget _statusChip(ReportStatus status, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.accentSubtle,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        status.label(loc),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  // -- Mode A: Compose ------------------------------------------------

  Widget _buildCompose(ReportIssueState state, AppLocalizations loc) {
    final trimmed = _messageCtrl.text.trim();
    final tooShort = trimmed.isNotEmpty && trimmed.length < 10;
    final canSubmit = trimmed.length >= 10 && !state.submitting;
    final attachment = state.attachment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(loc: loc, title: loc.reportIssue_title, onRefresh: null),
        const SizedBox(height: AppSpacing.md),
        Text(
          loc.reportIssue_composeIntro,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _messageCtrl,
          minLines: 3,
          maxLines: 6,
          autofocus: false,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: loc.reportIssue_composeHint,
            errorText: tooShort ? loc.reportIssue_minChars : null,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (attachment == null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _pickingScreenshot ? null : _pickScreenshot,
              icon: _pickingScreenshot
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.imagePlus, size: 18),
              label: Text(loc.reportIssue_attachScreenshot),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.accentSubtle,
              borderRadius: AppRadius.lgAll,
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.imagePlus,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    attachment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                IconButton(
                  tooltip: loc.reportIssue_removeAttachment,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref
                      .read(reportIssueControllerProvider.notifier)
                      .clearAttachment(),
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
        if (state.error == ReportIssueError.submit ||
            state.error == ReportIssueError.attachmentUpload) ...[
          const SizedBox(height: AppSpacing.sm),
          _inlineError(
            state.error == ReportIssueError.attachmentUpload
                ? loc.reportIssue_attachmentError
                : loc.reportIssue_error,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton.primary(
          label: loc.reportIssue_submit,
          isLoading: state.submitting,
          onPressed: canSubmit ? _submit : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: state.submitting ? null : _close,
          child: Text(loc.general_cancel),
        ),
      ],
    );
  }

  // -- Mode B: Thread --------------------------------------------------

  Widget _buildThread(ReportIssueState state, AppLocalizations loc) {
    final thread = state.thread;
    if (state.loading && thread == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(
            loc: loc,
            title: loc.reportIssue_threadTitle,
            onRefresh: null,
          ),
          const SizedBox(height: AppSpacing.xxl),
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(loc.reportIssue_loading),
          const SizedBox(height: AppSpacing.xxl),
        ],
      );
    }

    if (thread == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(
            loc: loc,
            title: loc.reportIssue_threadTitle,
            onRefresh: null,
          ),
          const SizedBox(height: AppSpacing.lg),
          _inlineError(loc.reportIssue_threadError),
          const SizedBox(height: AppSpacing.md),
          AppButton.secondary(
            label: loc.general_retry,
            onPressed: () => ref
                .read(reportIssueControllerProvider.notifier)
                .load(conversationId: widget.conversationId),
          ),
        ],
      );
    }

    final original = thread.originalReport;
    final followUps = thread.followUps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(
          loc: loc,
          title: loc.reportIssue_threadTitle,
          statusChip: _statusChip(thread.status, loc),
          onRefresh: state.loading || state.submitting
              ? null
              : () =>
                    ref.read(reportIssueControllerProvider.notifier).refresh(),
        ),
        if (state.error == ReportIssueError.threadLoad) ...[
          const SizedBox(height: AppSpacing.sm),
          _inlineError(loc.reportIssue_threadError),
        ],
        if (state.loading) ...[
          const SizedBox(height: AppSpacing.sm),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (original == null && followUps.isEmpty)
          Text(loc.reportIssue_emptyThread)
        else ...[
          if (original != null) ...[
            _entryLabel(loc.reportIssue_originalReport),
            const SizedBox(height: AppSpacing.xs),
            _bubble(original, loc),
            const SizedBox(height: AppSpacing.md),
          ],
          for (final entry in followUps) ...[
            _entryLabel(
              entry.isCustomer
                  ? loc.reportIssue_you
                  : loc.reportIssue_argoSupport,
            ),
            const SizedBox(height: AppSpacing.xs),
            _bubble(entry, loc),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
        if (state.error == ReportIssueError.reply) ...[
          _inlineError(loc.reportIssue_replyError),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (state.showReplyInput) _buildReplyComposer(state, loc),
        if (!state.showReplyInput && !state.resolved) ...[
          Text(
            loc.reportIssue_waiting,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (state.resolved) ...[
          Text(
            loc.reportIssue_resolvedNote,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.successText),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            label: loc.reportIssue_newIssue,
            onPressed: state.submitting
                ? null
                : () => ref
                      .read(reportIssueControllerProvider.notifier)
                      .startNewReport(),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildReplyComposer(ReportIssueState state, AppLocalizations loc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _replyCtrl,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: loc.reportIssue_replyHint),
            onSubmitted: (_) => _sendReply(),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filled(
          tooltip: loc.reportIssue_replySend,
          onPressed: state.submitting ? null : _sendReply,
          icon: state.submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send, size: 18),
        ),
      ],
    );
  }

  Widget _entryLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _bubble(ReportEntry entry, AppLocalizations loc) {
    final isCustomer = entry.isCustomer;
    return Align(
      alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isCustomer ? AppColors.primary : AppColors.accentSubtle,
          borderRadius: AppRadius.lgAll,
        ),
        child: Text(
          entry.text,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: isCustomer ? AppColors.onPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // -- Acknowledgement -------------------------------------------------

  Widget _buildAcknowledgement(AppLocalizations loc) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(loc: loc, title: loc.reportIssue_title, onRefresh: null),
        const SizedBox(height: AppSpacing.xxl),
        const Icon(
          Icons.check_circle_outline,
          size: 56,
          color: AppColors.success,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          loc.reportIssue_ack,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton.primary(label: loc.reportIssue_done, onPressed: _close),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _inlineError(String message) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.errorSubtle,
        borderRadius: AppRadius.lgAll,
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: AppColors.errorText),
      ),
    );
  }
}
