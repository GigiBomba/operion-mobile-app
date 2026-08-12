import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/sync/wifi_gate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../models/tacho_compliance.dart';
import '../providers/tacho_providers.dart';

/// Tachograph import + compliance screen (blueprint §4.7).
///
/// Flow:
/// 1. Pick a driver (bottom sheet over `GET /mobile/drivers`).
/// 2. Import a `.ddd`/`.esm` file (file_picker filtered to those extensions).
/// 3. Upload with a live [LinearProgressIndicator], then poll the async job
///    every 3s until a terminal state.
/// 4. Render the compliance summary card + weekly-limit gauge and the
///    backend's VERBATIM violation strings — never recomputed client-side.
///
/// Phase 4B §4.10 Wi-Fi gate: when "Wi-Fi only for large syncs" is on and the
/// device is on cellular, the upload is blocked with an inline message.
class TachographScreen extends ConsumerStatefulWidget {
  const TachographScreen({super.key});

  @override
  ConsumerState<TachographScreen> createState() => _TachographScreenState();
}

class _TachographScreenState extends ConsumerState<TachographScreen> {
  String? _driverId;
  String? _driverName;
  String? _lastFileName;

  Future<void> _pickDriver() async {
    final result = await showModalBottomSheet<(String, String)?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DriverPickerSheet(),
    );
    if (result == null || !mounted) return;
    setState(() {
      _driverId = result.$1;
      _driverName = result.$2;
    });
  }

  Future<void> _importFile() async {
    final loc = context.loc;
    final driverId = _driverId;
    if (driverId == null) {
      _showMessage(loc.tacho_noDriverSelected);
      return;
    }

    // Phase 4B §4.10: pre-emptive inline message (the notifier also guards).
    if (ref.read(wifiGateProvider).blocksLargeTransfer) {
      _showMessage(loc.tacho_wifiOnly);
      return;
    }

    final picker = ref.read(tachoFilePickerProvider);
    final picked = await picker();
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final file = picked.files.first;
    final path = file.path;
    if (path == null) return;

    setState(() => _lastFileName = file.name);
    final notifier = ref.read(tachoImportProvider.notifier);
    try {
      await notifier.import(driverId: driverId, filePath: path);
    } on TachoUploadWifiBlocked {
      if (mounted) _showMessage(loc.tacho_wifiOnly);
    } on TachoUploadRequiresConnection {
      if (mounted) _showMessage(loc.tacho_requiresConnection);
    } catch (_) {
      if (mounted) _showMessage(loc.tacho_uploadFailed);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = ref.watch(tachoImportProvider);
    final wifiGate = ref.watch(wifiGateProvider);

    // React to job polling: a terminal success renders the compliance card.
    final jobId = state.jobId;
    if (jobId != null) {
      ref.listen(tachoImportJobStatusProvider(jobId), (prev, next) {
        final jobState = next.valueOrNull;
        if (jobState == null || !jobState.isTerminal || !mounted) return;
        final notifier = ref.read(tachoImportProvider.notifier);
        if (jobState.status == TachoImportStatus.success &&
            jobState.result != null) {
          notifier.onJobSuccess(jobState.result!);
        } else {
          notifier.onJobError(jobState.error ?? loc.tacho_uploadFailed);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc.nav_tachograph)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Wi-Fi gate inline message (§4.10) ──────────────────
          if (wifiGate.blocksLargeTransfer || state.wifiBlocked)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.warningSubtle,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.wifiOff,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      loc.tacho_wifiOnly,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Driver picker ───────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.tacho_selectDriverTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  InkWell(
                    onTap: _pickDriver,
                    borderRadius: AppRadius.lgAll,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: AppRadius.lgAll,
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.user, size: 18),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _driverName ?? loc.tacho_selectDriver,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton.primary(
                    label: state.isBusy ? loc.tacho_importing : loc.tacho_importFile,
                    isLoading: state.phase == TachoImportPhase.uploading,
                    onPressed: state.isBusy ? null : _importFile,
                  ),
                  if (_lastFileName != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _lastFileName!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                  if (state.phase == TachoImportPhase.uploading) ...[
                    const SizedBox(height: AppSpacing.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: state.progress,
                        minHeight: 6,
                      ),
                    ),
                  ],
                  if (state.phase == TachoImportPhase.processing) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            loc.tacho_processing,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (state.phase == TachoImportPhase.error &&
                      state.error != null &&
                      !state.wifiBlocked)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        loc.tacho_uploadFailed,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Compliance summary ─────────────────────────────────
          if (state.phase == TachoImportPhase.success && state.result != null)
            _ComplianceCard(result: state.result!),
          if (state.phase != TachoImportPhase.success &&
              state.phase != TachoImportPhase.uploading &&
              state.phase != TachoImportPhase.processing)
            EmptyState(
              icon: const Icon(LucideIcons.fileBadge),
              title: loc.tacho_empty,
              subtitle: loc.tacho_emptyHint,
            ),
        ],
      ),
    );
  }
}

// ── Compliance card (days + weekly gauge + verbatim banners) ────────────

class _ComplianceCard extends StatelessWidget {
  const _ComplianceCard({required this.result});

  final TachoComplianceResult result;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.tacho_complianceTitle,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                _WeeklyGauge(
                  weeklyDrivingMinutes: result.weeklyDrivingMinutes,
                  weeklyLimitMinutes: result.weeklyLimitMinutes,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.tacho_weeklyDriving,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${result.weeklyDrivingMinutes} / '
                        '${result.weeklyLimitMinutes} min',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (result.weeklyDrivingMinutes >
                          result.weeklyLimitMinutes) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          loc.tacho_overLimit,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Days table
        if (result.days.isNotEmpty) ...[
          Text(
            loc.tacho_days,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < result.days.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                  _DayRow(day: result.days[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── VERBATIM violation banners (never recomputed) ─────────
        if (result.violations.isNotEmpty) ...[
          Text(
            loc.tacho_violations,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final violation in result.violations)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.errorSubtle,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(LucideIcons.alertTriangle,
                        size: 16, color: AppColors.error),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      violation, // Backend verbatim — rendered as-is (§4.7).
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ] else ...[
          Text(
            loc.tacho_noViolations,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});

  final TachoDay day;

  String _minutes(int m) => '${m ~/ 60}h ${m % 60}m';

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              day.date,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _MiniStat(label: loc.tacho_driving, value: _minutes(day.drivingMinutes)),
          _MiniStat(label: loc.tacho_working, value: _minutes(day.workingMinutes)),
          _MiniStat(label: loc.tacho_rest, value: _minutes(day.restMinutes)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Weekly-driving circular gauge (§4.7): value = weekly / 3360, red past 100%.
class _WeeklyGauge extends StatelessWidget {
  const _WeeklyGauge({
    required this.weeklyDrivingMinutes,
    required this.weeklyLimitMinutes,
  });

  final int weeklyDrivingMinutes;
  final int weeklyLimitMinutes;

  @override
  Widget build(BuildContext context) {
    final limit = weeklyLimitMinutes > 0 ? weeklyLimitMinutes : 3360;
    final over = weeklyDrivingMinutes > limit;
    final value = limit > 0 ? (weeklyDrivingMinutes / limit).clamp(0.0, 1.0) : 0.0;
    final color = over ? AppColors.error : AppColors.success;

    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 8,
              backgroundColor: AppColors.success.withValues(alpha: 0.15),
              color: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${weeklyDrivingMinutes ~/ 60}h',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700, color: color),
              ),
              Text(
                '${weeklyDrivingMinutes % 60}m',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Driver picker sheet (invoice trip-picker pattern) ───────────────────

class _DriverPickerSheet extends ConsumerStatefulWidget {
  const _DriverPickerSheet();

  @override
  ConsumerState<_DriverPickerSheet> createState() => _DriverPickerSheetState();
}

class _DriverPickerSheetState extends ConsumerState<_DriverPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final driversAsync = ref.watch(tachoDriversProvider);
    final q = _query.toLowerCase();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppTextField(
              controller: _controller,
              hintText: loc.tacho_driverSearch,
              prefixIcon: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: driversAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (drivers) {
                final filtered = drivers
                    .where((d) =>
                        (d['name']?.toString() ?? '').toLowerCase().contains(q) ||
                        (d['email']?.toString() ?? '').toLowerCase().contains(q))
                    .toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      loc.tacho_noDrivers,
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final d = filtered[index];
                    final id = d['id']?.toString() ?? '';
                    final name = d['name']?.toString() ?? '';
                    return ListTile(
                      leading: const Icon(LucideIcons.user),
                      title: Text(name),
                      subtitle: Text(d['email']?.toString() ?? ''),
                      onTap: () =>
                          Navigator.of(context).pop((id, name)),
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
