import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/client.dart';
import '../providers/client_providers.dart';

/// Merge-clients bottom sheet (blueprint §4.3).
///
/// Admin-only (REAL matrix: `can_merge_clients` is admin-only). Requires:
/// - a target client (the surviving record),
/// - one or more source clients to merge into it,
/// - typing the target's EXACT name to confirm (typed-confirmation gate),
/// - a live connection (merge is NEVER queued — offline disables the button
///   and shows the inline "requires an internet connection" message).
class ClientMergeSheet extends ConsumerStatefulWidget {
  const ClientMergeSheet({
    super.key,
    required this.clients,
    this.initialTargetId,
  });

  final List<Client> clients;
  final String? initialTargetId;

  static Future<ClientMergeResult?> show(
    BuildContext context, {
    required List<Client> clients,
    String? initialTargetId,
  }) {
    return showModalBottomSheet<ClientMergeResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ClientMergeSheet(
        clients: clients,
        initialTargetId: initialTargetId,
      ),
    );
  }

  @override
  ConsumerState<ClientMergeSheet> createState() => _ClientMergeSheetState();
}

class _ClientMergeSheetState extends ConsumerState<ClientMergeSheet> {
  String? _targetId;
  final Set<String> _sourceIds = {};
  final _confirmation = TextEditingController();

  @override
  void initState() {
    super.initState();
    _targetId = widget.initialTargetId ?? (widget.clients.isNotEmpty ? widget.clients.first.id : null);
  }

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Client? get _target {
    for (final c in widget.clients) {
      if (c.id == _targetId) return c;
    }
    return null;
  }

  bool get _mergeEnabled {
    final target = _target;
    if (target == null) return false;
    if (_sourceIds.isEmpty) return false;
    if (_confirmation.text.trim() != target.name) return false;
    return !ref.read(isOfflineProvider);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isOffline = ref.watch(isOfflineProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(loc.clients_merge, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),

            // ── Target selector ────────────────────────────
            DropdownButtonFormField<String>(
              initialValue: _targetId,
              decoration: InputDecoration(labelText: loc.clients_mergeTarget),
              items: [
                for (final c in widget.clients)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() {
                _targetId = v;
                _sourceIds.remove(v);
              }),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Multi-source selector ───────────────────────
            Text(loc.clients_mergeSources, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            for (final c in widget.clients)
              if (c.id != _targetId)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(c.name),
                  value: _sourceIds.contains(c.id),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _sourceIds.add(c.id);
                    } else {
                      _sourceIds.remove(c.id);
                    }
                  }),
                ),

            const SizedBox(height: AppSpacing.md),

            // ── Estimated merged totals ────────────────────
            _MergeSummary(targetId: _targetId, sourceIds: _sourceIds),

            const SizedBox(height: AppSpacing.md),

            AppTextField(
              controller: _confirmation,
              labelText: loc.clients_mergeTypeConfirm,
              onChanged: (_) => setState(() {}),
            ),

            if (isOffline) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warningSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  loc.clients_mergeOffline,
                  style: const TextStyle(color: AppColors.warningText),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: loc.clients_mergeBtn,
              onPressed: _mergeEnabled ? _merge : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton.secondary(
              label: loc.general_cancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _merge() async {
    final target = _target;
    if (target == null) return;
    final result = await ref
        .read(clientMutationProvider.notifier)
        .mergeClients(targetId: target.id, sourceIds: _sourceIds.toList());
    if (mounted) Navigator.of(context).pop(result);
  }
}

/// Sums trip/invoice/contact counts across the target + selected sources by
/// watching the (dual-mode) [clientDetailProvider] for each.
class _MergeSummary extends ConsumerWidget {
  const _MergeSummary({required this.targetId, required this.sourceIds});

  final String? targetId;
  final Set<String> sourceIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final ids = <String>[
      ?targetId,
      ...sourceIds,
    ];

    var trips = 0;
    var invoices = 0;
    var contacts = 0;
    var loading = false;
    for (final id in ids) {
      final detail = ref.watch(clientDetailProvider(id));
      detail.whenData((data) {
        trips += data.client.recentTripCount;
        invoices += data.client.recentInvoiceCount;
        contacts += data.client.contacts.length;
      });
      if (detail.isLoading) loading = true;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            loc.clients_mergeSummary,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(
            loading
                ? '…'
                : '${loc.clients_tripsShort} $trips · '
                    '${loc.clients_invoicesShort} $invoices · '
                    '${loc.clients_contactsShort} $contacts',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
