import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../features/driver/home/driver_providers.dart';
import '../../../shared/models/transport.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../models/freight_load.dart';
import '../models/freight_negotiation.dart';
import '../providers/freight_exchange_providers.dart';
import '../providers/freight_negotiation_providers.dart';

/// Detail view for a single freight-exchange load with the Accept & Assign
/// action and the §2 "Evaluate" profitability/risk card.
///
/// Accept & Assign runs the §1.6 live re-check + §1.7 `Idempotency-Key`
/// import via [FreightExchangeAcceptNotifier]. On a conflict the screen shows
/// the localized "this load was just taken" message and refreshes the board.
///
/// Evaluate fetches `GET /freight/loads/{provider_id}/{load_id}/evaluate`
/// and renders the meaningful `LoadEvaluation` fields defensively.
class FreightLoadDetailScreen extends ConsumerStatefulWidget {
  const FreightLoadDetailScreen({
    super.key,
    required this.load,
    required this.filter,
  });

  final FreightLoad load;
  final FreightLoadFilter filter;

  @override
  ConsumerState<FreightLoadDetailScreen> createState() =>
      _FreightLoadDetailScreenState();
}

class _FreightLoadDetailScreenState
    extends ConsumerState<FreightLoadDetailScreen> {
  bool _showEvaluation = false;

  FreightLoad get load => widget.load;
  FreightLoadFilter get filter => widget.filter;

  Future<void> _acceptAndAssign() async {
    final loc = context.loc;
    final transport = await showModalBottomSheet<Transport>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _TransportPickerSheet(locale: loc),
    );
    if (transport == null || !mounted) return;
    await ref
        .read(freightExchangeAcceptProvider.notifier)
        .accept(load: load, filter: filter, transportId: transport.id);
  }

  Future<void> _openNegotiation() async {
    final target = resolveImportTarget(load);
    if (target == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => FreightNegotiationSheet(
        target: target,
        currency: load.currency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final acceptState = ref.watch(freightExchangeAcceptProvider);
    final isChecking = acceptState.status == FreightAcceptStatus.checking;

    ref.listen<FreightAcceptState>(freightExchangeAcceptProvider, (prev, next) {
      if (prev?.status == next.status) return;
      switch (next.status) {
        case FreightAcceptStatus.accepted:
          ref.invalidate(freightLoadsProvider(filter));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.freightExchange_accepted),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
        case FreightAcceptStatus.taken:
          // Conflict — the load was taken between fetch and accept. Show the
          // localized message and refresh the board; never retry/substitute.
          ref.invalidate(freightLoadsProvider(filter));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.freightExchange_taken),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
        case FreightAcceptStatus.error:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.freightExchange_acceptError),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        case FreightAcceptStatus.idle:
        case FreightAcceptStatus.checking:
          break;
      }
    });

    final target = resolveImportTarget(load);

    return Scaffold(
      appBar: AppBar(title: Text(loc.freightExchange_loadDetails)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(
                    icon: LucideIcons.mapPin,
                    label: loc.freightExchange_origin,
                    value: load.origin,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DetailRow(
                    icon: LucideIcons.mapPinned,
                    label: loc.freightExchange_destination,
                    value: load.destination,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (load.price != null)
                    _DetailRow(
                      icon: LucideIcons.circleDollarSign,
                      label: loc.freightExchange_price,
                      value: '${load.price!.toStringAsFixed(2)} ${load.currency ?? ''}'
                          .trim(),
                    ),
                  if (load.cargoType != null && load.cargoType!.isNotEmpty)
                    _DetailRow(
                      icon: LucideIcons.box,
                      label: loc.freightExchange_cargoType,
                      value: load.cargoType!,
                    ),
                  if (load.weightKg != null)
                    _DetailRow(
                      icon: LucideIcons.weight,
                      label: loc.freightExchange_weight,
                      value: '${load.weightKg!.toStringAsFixed(0)} kg',
                    ),
                  if (load.distanceKm != null)
                    _DetailRow(
                      icon: LucideIcons.route,
                      label: loc.freightExchange_distance,
                      value: '${load.distanceKm} km',
                    ),
                  if (load.pickupDate != null)
                    _DetailRow(
                      icon: LucideIcons.calendarClock,
                      label: loc.freightExchange_pickupDate,
                      value: _formatDateTime(load.pickupDate!),
                    ),
                  if (load.deadlineDate != null)
                    _DetailRow(
                      icon: LucideIcons.clock,
                      label: loc.freightExchange_deadline,
                      value: _formatDateTime(load.deadlineDate!),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── §2 Evaluate ───────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => setState(() => _showEvaluation = true),
            icon: const Icon(LucideIcons.trendingUp, size: 18),
            label: Text(loc.freightExchange_evaluate),
          ),
          if (_showEvaluation) ...[
            const SizedBox(height: AppSpacing.md),
            _EvaluationCard(
              target: target,
              fallbackCurrency: load.currency,
              onRetry: () => setState(() => _showEvaluation = false),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      (target == null || isChecking) ? null : _openNegotiation,
                  icon: const Icon(LucideIcons.messageSquare, size: 18),
                  label: Text(loc.freightNegotiation_negotiate),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton.primary(
                  label: isChecking
                      ? loc.freightExchange_accepting
                      : loc.freightExchange_acceptAndAssign,
                  isLoading: isChecking,
                  onPressed: isChecking ? null : _acceptAndAssign,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            loc.freightExchange_takenHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} $h:$m';
  }
}

/// Fetches and renders the load evaluation (§2 parity).
///
/// Watches [freightLoadEvaluationProvider] and renders the meaningful
/// `LoadEvaluation` fields defensively: estimated revenue, expected profit,
/// margin, fuel/tolls/driver costs, deadhead, duration, risk score and
/// vehicle compatibility. No preview/stream — metadata only.
class _EvaluationCard extends ConsumerWidget {
  const _EvaluationCard({
    required this.target,
    required this.fallbackCurrency,
    required this.onRetry,
  });

  final ({String providerId, String loadId})? target;
  final String? fallbackCurrency;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final theme = Theme.of(context);

    if (target == null) {
      return _EvaluationError(
        message: loc.freightExchange_evaluationError,
        onRetry: onRetry,
      );
    }

    final evaluationAsync = ref.watch(
      freightLoadEvaluationProvider((providerId: target!.providerId, loadId: target!.loadId)),
    );

    return evaluationAsync.when(
      loading: () => const AppCard(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => _EvaluationError(
        message: loc.freightExchange_evaluationError,
        onRetry: onRetry,
      ),
      data: (evaluation) {
        final currency = evaluation.currency ?? fallbackCurrency;
        String money(double? value) => value == null
            ? '—'
            : '${value.toStringAsFixed(2)} ${currency ?? ''}'.trim();

        return AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.freightExchange_evaluation,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _EvalRow(
                  label: loc.freightExchange_estimatedRevenue,
                  value: money(evaluation.estimatedRevenue),
                  valueColor: AppColors.success,
                ),
                _EvalRow(
                  label: loc.freightExchange_expectedProfit,
                  value: money(evaluation.expectedProfit),
                  valueColor: AppColors.success,
                ),
                _EvalRow(
                  label: loc.freightExchange_profitMargin,
                  value: evaluation.profitMarginPct == null
                      ? '—'
                      : '${evaluation.profitMarginPct!.toStringAsFixed(1)}%',
                ),
                _EvalRow(
                  label: loc.freightExchange_fuelCost,
                  value: money(evaluation.fuelCost),
                ),
                _EvalRow(
                  label: loc.freightExchange_tollCost,
                  value: money(evaluation.tollCost),
                ),
                _EvalRow(
                  label: loc.freightExchange_driverSalary,
                  value: money(evaluation.driverSalary),
                ),
                _EvalRow(
                  label: loc.freightExchange_deadheadKm,
                  value: evaluation.deadheadDistanceKm == null
                      ? '—'
                      : '${evaluation.deadheadDistanceKm!.toStringAsFixed(0)} km',
                ),
                _EvalRow(
                  label: loc.freightExchange_durationHours,
                  value: evaluation.estimatedDurationHours == null
                      ? '—'
                      : '${evaluation.estimatedDurationHours!.toStringAsFixed(1)} h',
                ),
                const Divider(height: AppSpacing.lg),
                Row(
                  children: [
                    Text(
                      loc.freightExchange_riskScore,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const Spacer(),
                    _RiskBadge(score: evaluation.riskScore),
                  ],
                ),
                if (evaluation.vehicleCompatibility.isNotEmpty) ...[
                  const Divider(height: AppSpacing.lg),
                  Text(
                    loc.freightExchange_vehicleCompatibility,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final compat in evaluation.vehicleCompatibility)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          Icon(
                            compat.compatible
                                ? LucideIcons.checkCircle2
                                : LucideIcons.alertCircle,
                            size: 14,
                            color: compat.compatible
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              compat.compatible
                                  ? loc.freightExchange_vehicleCompatible
                                  : loc.freightExchange_vehicleIncompatible,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Error card for the evaluation section.
class _EvaluationError extends StatelessWidget {
  const _EvaluationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle, size: 28, color: AppColors.error),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: Text(context.loc.general_retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label/value row in the evaluation card.
class _EvalRow extends StatelessWidget {
  const _EvalRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// A colored risk badge (0.0 low → 1.0 high).
class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.score});

  final double? score;

  @override
  Widget build(BuildContext context) {
    if (score == null) return const Text('—');
    final color = score! < 0.33
        ? AppColors.success
        : (score! < 0.66 ? AppColors.warning : AppColors.error);
    final label = score! < 0.33
        ? context.loc.freightExchange_riskLow
        : (score! < 0.66
            ? context.loc.freightExchange_riskMedium
            : context.loc.freightExchange_riskHigh);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$label · ${(score! * 100).round()}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// A single detail row: icon + label + value.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

/// Bottom sheet listing the user's transports for the assignment step.
class _TransportPickerSheet extends ConsumerWidget {
  const _TransportPickerSheet({required this.locale});

  final AppLocalizations locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transportsAsync = ref.watch(transportsProvider);
    final theme = Theme.of(context);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
            child: Text(
              locale.freightExchange_selectTransport,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: transportsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: OutlinedButton.icon(
                  onPressed: () => ref.invalidate(transportsProvider),
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: Text(locale.general_retry),
                ),
              ),
              data: (transports) {
                if (transports.isEmpty) {
                  return Center(
                    child: EmptyState(
                      icon: const Icon(LucideIcons.truck, size: 56),
                      title: locale.freightExchange_noTransports,
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: transports.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final transport = transports[index];
                    return ListTile(
                      leading: const Icon(LucideIcons.truck, color: AppColors.accent),
                      title: Text(
                        transport.loadInfo.isNotEmpty
                            ? transport.loadInfo
                            : '${transport.origin} → ${transport.destination}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        transport.vehiclePlate?.isNotEmpty == true
                            ? '${transport.origin} → ${transport.destination} · ${transport.vehiclePlate}'
                            : '${transport.origin} → ${transport.destination}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).pop(transport),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal bottom sheet for load negotiation (Tier-2 feature).
///
/// Mirrors the saved-searches sheet conventions (SafeArea + `Column(min)`
/// inside a `showModalBottomSheet`). Shows the current negotiation thread;
/// when the thread is empty the BASE offer is composed from the Evaluate card
/// (`freightLoadEvaluationProvider` estimated revenue / expected profit).
///
/// Accept (primary) / Reject (danger) / Counter (expands an amount field)
/// call [FreightNegotiationNotifier] and refresh the thread on success.
/// Negotiation is a LIVE-CONNECTION action: offline the actions are disabled
/// with the inline 'requires connection' message and never queued.
class FreightNegotiationSheet extends ConsumerStatefulWidget {
  const FreightNegotiationSheet({
    super.key,
    required this.target,
    this.currency,
  });

  final ({String providerId, String loadId}) target;
  final String? currency;

  @override
  ConsumerState<FreightNegotiationSheet> createState() =>
      _FreightNegotiationSheetState();
}

class _FreightNegotiationSheetState
    extends ConsumerState<FreightNegotiationSheet> {
  final _counterCtrl = TextEditingController();
  bool _showCounter = false;

  @override
  void dispose() {
    _counterCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<bool> Function() action) async {
    final ok = await action();
    if (!mounted) return;
    if (ok) setState(() => _showCounter = false);
  }

  void _sendCounter() {
    final raw = _counterCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) return;
    _run(() => ref
        .read(freightNegotiationActionProvider.notifier)
        .counter(
          providerId: widget.target.providerId,
          loadId: widget.target.loadId,
          amountEur: amount,
        ));
  }

  static String _statusLabel(
          AppLocalizations loc, FreightNegotiationStatus status) =>
      switch (status) {
        FreightNegotiationStatus.offered =>
          loc.freightNegotiation_statusOffered,
        FreightNegotiationStatus.countered =>
          loc.freightNegotiation_statusCountered,
        FreightNegotiationStatus.accepted =>
          loc.freightNegotiation_statusAccepted,
        FreightNegotiationStatus.rejected =>
          loc.freightNegotiation_statusRejected,
        FreightNegotiationStatus.expired =>
          loc.freightNegotiation_statusExpired,
      };

  String _actionError(AppLocalizations loc, String key) => switch (key) {
        'freightNegotiation_offline' => loc.freightNegotiation_offline,
        'freightNegotiation_error' => loc.freightNegotiation_error,
        _ => key,
      };

  String _relativeTime(AppLocalizations loc, DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return loc.freightNegotiation_justNow;
    if (diff.inMinutes < 60) return loc.freightNegotiation_minAgo(diff.inMinutes);
    if (diff.inHours < 24) return loc.freightNegotiation_hoursAgo(diff.inHours);
    return loc.freightNegotiation_daysAgo(diff.inDays);
  }

  Widget _recordRow(
    BuildContext context,
    AppLocalizations loc,
    FreightNegotiation record,
  ) {
    final theme = Theme.of(context);
    final isOwn = record.direction == FreightNegotiationDirection.from;
    final author = isOwn
        ? loc.freightNegotiation_you
        : (record.counterpartyName.isEmpty ? '—' : record.counterpartyName);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              _statusLabel(loc, record.status),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.info,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.amountEur.toStringAsFixed(2)} ${record.currency}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$author · ${record.createdAt == null ? '—' : _relativeTime(loc, record.createdAt!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The base offer when the thread is empty — composed from the Evaluate
  /// card's estimated revenue / expected profit.
  Widget _baseOffer(AppLocalizations loc, ThemeData theme) {
    final evaluationAsync = ref.watch(freightLoadEvaluationProvider(widget.target));
    return evaluationAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          loc.freightNegotiation_empty,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
      data: (evaluation) {
        final currency = widget.currency ?? 'EUR';
        String money(double? v) =>
            v == null ? '—' : '${v.toStringAsFixed(2)} $currency'.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.freightNegotiation_baseOffer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _EvalRow(
              label: loc.freightExchange_estimatedRevenue,
              value: money(evaluation.estimatedRevenue),
              valueColor: AppColors.success,
            ),
            _EvalRow(
              label: loc.freightExchange_expectedProfit,
              value: money(evaluation.expectedProfit),
              valueColor: AppColors.success,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isOffline = ref.watch(isOfflineProvider);
    final threadAsync = ref.watch(freightNegotiationProvider(widget.target));
    final actionState = ref.watch(freightNegotiationActionProvider);
    final busy = actionState.busy;
    final thread = threadAsync.valueOrNull ?? const FreightNegotiationThread();
    final settled = thread.isSettled;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.freightNegotiation_title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (isOffline) ...[
              Text(
                loc.freightNegotiation_offline,
                style: const TextStyle(color: AppColors.warning, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (actionState.errorKey != null) ...[
              Text(
                _actionError(loc, actionState.errorKey!),
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Flexible(
              child: threadAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc.freightNegotiation_error,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(
                          freightNegotiationProvider(widget.target),
                        ),
                        icon: const Icon(LucideIcons.refreshCw, size: 16),
                        label: Text(loc.general_retry),
                      ),
                    ],
                  ),
                ),
                data: (data) => data.items.isEmpty
                    ? _baseOffer(loc, theme)
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final record in data.items)
                            _recordRow(context, loc, record),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (settled)
              Text(
                loc.freightNegotiation_settled,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              )
            else ...[
              if (_showCounter) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _counterCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: loc.freightNegotiation_counterAmount,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: busy || isOffline ? null : _sendCounter,
                      child: Text(loc.freightNegotiation_counterSend),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Row(
                children: [
                  Expanded(
                    child: AppButton.primary(
                      label: loc.freightNegotiation_accept,
                      onPressed: (busy || isOffline)
                          ? null
                          : () => _run(() => ref
                              .read(freightNegotiationActionProvider.notifier)
                              .accept(
                                providerId: widget.target.providerId,
                                loadId: widget.target.loadId,
                              )),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton.danger(
                      label: loc.freightNegotiation_reject,
                      onPressed: (busy || isOffline)
                          ? null
                          : () => _run(() => ref
                              .read(freightNegotiationActionProvider.notifier)
                              .reject(
                                providerId: widget.target.providerId,
                                loadId: widget.target.loadId,
                              )),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton.secondary(
                      label: loc.freightNegotiation_counter,
                      onPressed: (busy || isOffline)
                          ? null
                          : () => setState(() => _showCounter = !_showCounter),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
