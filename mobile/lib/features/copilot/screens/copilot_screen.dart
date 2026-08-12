import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../fleet/models/truck.dart';
import '../../fleet/providers/fleet_providers.dart';
import '../../fleet/widgets/record_work_sheet.dart';
import '../../global_search/screens/global_search_screen.dart';
import '../providers/copilot_providers.dart';
import '../widgets/copilot_chat_bubble.dart';

/// Alias for use in shell routing — the shared Copilot chat surface for every role.
typedef CopilotChatScreen = CopilotScreen;

/// Main Co-Pilot chat screen.
///
/// Renders server-authoritative state from CopilotMobileState.
/// No locally-invented states for Level 1+ actions.
///
/// [initialUtterance] (optional): when provided AND the conversation is fresh
/// (no prior messages yet — the notifier has no conversation id), the message
/// is auto-sent once as the user's first message on first build. Bounded:
/// guarded by a one-shot flag so rebuilds never re-send; without a value the
/// screen behaves exactly as before.
class CopilotScreen extends ConsumerStatefulWidget {
  const CopilotScreen({super.key, this.initialUtterance});

  /// A context-seeding utterance to auto-send as the first user message
  /// (e.g. the driver-shell trip context). Null = unchanged behaviour.
  final String? initialUtterance;

  @override
  ConsumerState<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends ConsumerState<CopilotScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  /// One-shot guard: the initial utterance is sent at most once per screen
  /// lifecycle, even if the widget rebuilds many times.
  bool _initialSent = false;

  @override
  void initState() {
    super.initState();
    final utterance = widget.initialUtterance;
    if (utterance != null && utterance.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendInitialUtterance(utterance);
      });
    }
  }

  @override
  void didUpdateWidget(covariant CopilotScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The seed may arrive asynchronously (e.g. the driver shell composes it
    // from a FutureProvider that resolves after first build). Still bounded:
    // one-shot per screen lifecycle, fresh conversation only.
    final utterance = widget.initialUtterance;
    if (utterance == null || utterance.trim().isEmpty) return;
    if (_initialSent) return;
    if (oldWidget.initialUtterance == utterance) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendInitialUtterance(utterance);
    });
  }

  void _sendInitialUtterance(String utterance) {
    if (_initialSent || !mounted) return;
    // Fresh conversation only — never re-seed an in-progress one.
    final notifier = ref.read(copilotStateProvider.notifier);
    if (notifier.conversationId != null) return;
    _initialSent = true;
    setState(() {
      _messages.add(_ChatMessage(text: utterance, isUser: true));
    });
    notifier.sendMessage(utterance);
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
    });
    _messageController.clear();
    ref.read(copilotStateProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(copilotStateProvider);

    // Handle state transitions by adding AI messages
    ref.listen<CopilotMobileState>(copilotStateProvider, (_, state) {
      if (state is CopilotCompleted && state.summaryKey != null) {
        setState(() {
          _messages.add(_ChatMessage(
            text: state.summaryKey!,
            isUser: false,
            status: 'completed',
          ));
        });
      } else if (state is CopilotError) {
        setState(() {
          _messages.add(_ChatMessage(
            text: state.messageKey,
            isUser: false,
            status: 'error',
          ));
        });
      }
      _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.ai_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: context.loc.globalSearch_openSearch,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GlobalSearchScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(copilotStateProvider.notifier).reset();
              setState(() => _messages.clear());
            },
            tooltip: context.loc.ai_newConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(state: state)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return CopilotChatBubble(
                        text: msg.text,
                        isUser: msg.isUser,
                        statusLabel: msg.status,
                      );
                    },
                  ),
          ),

          // Confirmation UI
          if (state is CopilotAwaitingConfirmation)
            _ConfirmationBar(
              state: state,
              onCancel: () {
                ref.read(copilotStateProvider.notifier).cancelPlan();
              },
              onConfirmWithPhrase: (phrase) {
                ref.read(copilotStateProvider.notifier).confirmPlan(
                  confirmationPhrase: phrase.isEmpty ? null : phrase,
                );
              },
            ),

          // Record-maintenance quick-capture UI (blueprint §9 item 4).
          // The mobile owns execution: pre-filled sheet → the SAME
          // submitRecordMaintenance path, never confirmPlan.
          if (state is CopilotAwaitingMaintenanceCapture)
            _MaintenanceCaptureBar(
              state: state,
              onCancel: () {
                ref.read(copilotStateProvider.notifier).cancelPlan();
              },
              onConfirmed: () {
                ref
                    .read(copilotStateProvider.notifier)
                    .completeMaintenanceCapture();
              },
            ),

          // Clarification UI
          if (state is CopilotAwaitingClarification)
            _ClarificationBar(
              questionKey: state.questionKey,
              onRespond: (response) {
                ref
                    .read(copilotStateProvider.notifier)
                    .sendMessage(response);
              },
            ),

          // Input bar
          _InputBar(
            controller: _messageController,
            onSend: _sendMessage,
            isLoading: state is CopilotProcessing,
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final String? status;
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.status,
  });
}

class _EmptyState extends StatelessWidget {
  final CopilotMobileState state;
  const _EmptyState({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state is CopilotProcessing) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 48, color: AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.loc.ai_emptyStateMessage,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.loc.ai_emptyStatePrompt,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationBar extends StatefulWidget {
  final CopilotAwaitingConfirmation state;
  final VoidCallback onCancel;
  final ValueChanged<String> onConfirmWithPhrase;

  const _ConfirmationBar({
    required this.state,
    required this.onCancel,
    required this.onConfirmWithPhrase,
  });

  @override
  State<_ConfirmationBar> createState() => _ConfirmationBarState();
}

class _ConfirmationBarState extends State<_ConfirmationBar> {
  final _phraseController = TextEditingController();
  bool _phraseMatch = false;

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLevel3 = widget.state.plan.isLevel3;
    final phrase = widget.state.plan.confirmationPhrase;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isLevel3 ? AppColors.error.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
        border: Border(top: BorderSide(color: isLevel3 ? AppColors.error : AppColors.warning)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLevel3 ? context.loc.copilot_level3_title : context.loc.ai_confirmMessage,
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isLevel3 && phrase != null) ...[
            Text(
              context.loc.copilot_level3_phrase(phrase),
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _phraseController,
              decoration: InputDecoration(
                hintText: context.loc.copilot_level3_hint,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _phraseMatch = value.trim() == phrase);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: widget.onCancel, child: Text(context.loc.general_cancel)),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: isLevel3
                    ? (_phraseMatch ? () => widget.onConfirmWithPhrase(_phraseController.text.trim()) : null)
                    : () => widget.onConfirmWithPhrase(''),
                child: Text(context.loc.general_confirm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaintenanceCaptureBar extends ConsumerStatefulWidget {
  const _MaintenanceCaptureBar({
    required this.state,
    required this.onCancel,
    required this.onConfirmed,
  });

  final CopilotAwaitingMaintenanceCapture state;
  final VoidCallback onCancel;

  /// Invoked after the shared [submitRecordMaintenance] path has persisted the
  /// record (drives the notifier's state completion).
  final VoidCallback onConfirmed;

  @override
  ConsumerState<_MaintenanceCaptureBar> createState() =>
      _MaintenanceCaptureBarState();
}

class _MaintenanceCaptureBarState
    extends ConsumerState<_MaintenanceCaptureBar> {
  String? _truckId;

  String? get _effectiveTruckId => widget.state.truckId ?? _truckId;

  String _summary(AppLocalizations loc) {
    final prefill = widget.state.prefill;
    final parts = <String>[
      if (prefill.plateNumber != null && prefill.plateNumber!.isNotEmpty)
        prefill.plateNumber!,
      if (prefill.category != null) prefill.category!.apiValue,
      if (prefill.cost != null) prefill.cost!.toStringAsFixed(2),
      if (prefill.notes != null && prefill.notes!.isNotEmpty) prefill.notes!,
    ];
    return parts.isEmpty ? loc.copilot_maintenanceEmpty : parts.join(' · ');
  }

  Future<void> _openSheet() async {
    final truckId = _effectiveTruckId;
    if (truckId == null || !mounted) return;
    // The SAME sheet the manual form uses, opened PRE-FILLED for one-tap
    // confirm (§9 item 4).
    final draft =
        await showRecordWorkSheet(context, prefill: widget.state.prefill);
    if (draft == null || !mounted) return;
    // Through the shared top-level entry point (identical to the manual form).
    await widget.state.submit(ref, truckId, draft);
    if (!mounted) return;
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final truckId = _effectiveTruckId;
    final trucksAsync = ref.watch(fleetListProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        border: const Border(top: BorderSide(color: AppColors.success)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.copilot_maintenanceCapture,
            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(_summary(loc), style: AppTypography.bodySmall),
          if (truckId == null) ...[
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _truckId,
              decoration: InputDecoration(
                labelText: loc.copilot_maintenanceSelectTruck,
                isDense: true,
              ),
              items: [
                for (final t in trucksAsync.valueOrNull?.trucks ??
                    const <Truck>[])
                  DropdownMenuItem(
                    value: t.id,
                    child: Text('${t.plate} — ${t.brand} ${t.model}'.trim()),
                  ),
              ],
              onChanged: (v) => setState(() => _truckId = v),
              validator: (v) => v == null ? loc.maintenance_truckRequired : null,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: widget.onCancel, child: Text(loc.general_cancel)),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: truckId == null ? null : _openSheet,
                child: Text(loc.copilot_maintenanceConfirm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClarificationBar extends StatelessWidget {
  final String questionKey;
  final ValueChanged<String> onRespond;
  const _ClarificationBar({
    required this.questionKey,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        border: const Border(top: BorderSide(color: AppColors.info)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(questionKey, style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: context.loc.ai_clarifyPlaceholder,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  onRespond(controller.text);
                  controller.clear();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  const _InputBar({
    required this.controller,
    required this.onSend,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isLoading,
              decoration: InputDecoration(
                hintText: context.loc.ai_placeholder,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              onSubmitted: isLoading ? null : (_) => onSend(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: isLoading ? null : onSend,
          ),
        ],
      ),
    );
  }
}
