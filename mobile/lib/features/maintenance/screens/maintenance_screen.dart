import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/permission_guard.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../fleet/models/truck.dart';
import '../../fleet/providers/fleet_providers.dart';
import '../../fleet/widgets/record_work_sheet.dart';
import '../models/maintenance.dart';
import '../providers/maintenance_providers.dart';

/// Maintenance screen (blueprint §4.6).
///
/// - Cost trend: LineChart (monthly) + category PieChart (by_type).
/// - Schedule list: overdue entries first with a red left-border accent.
/// - "Record work" REUSES the Phase-1 `showRecordWorkSheet` →
///   `fleetMutationProvider.recordMaintenance` — the same code path, no
///   duplicate (photo attachment omitted — documented).
/// - Add-schedule FAB gated by `can_schedule_maintenance` (§8.2; real backend
///   matrix: admin+manager).
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  bool _overdueOnly = false;

  void _toggleOverdue(bool value) {
    setState(() => _overdueOnly = value);
    ref.read(maintenanceScheduleFilterProvider.notifier).state =
        ref.read(maintenanceScheduleFilterProvider).copyWith(overdueOnly: value);
  }

  Future<void> _recordWork(MaintenanceScheduleItem schedule) async {
    final draft = await showRecordWorkSheet(context);
    if (draft == null || !mounted) return;
    // Same shared entry point as the truck-detail quick action and the
    // Copilot record_maintenance intent (§9 item 4).
    await submitRecordMaintenance(ref, schedule.truckId, draft);
  }

  Future<void> _addSchedule() async {
    final draft = await _showAddScheduleSheet(context);
    if (draft == null || !mounted) return;
    final loc = context.loc;
    try {
      await ref.read(maintenanceMutationProvider.notifier).scheduleMaintenance(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.maintenance_scheduleAdded)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.general_error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final filter = ref.watch(maintenanceScheduleFilterProvider);
    final scheduleAsync = ref.watch(maintenanceScheduleProvider(filter));
    final range = ref.watch(maintenanceCostTrendRangeProvider);
    final trendAsync = ref.watch(maintenanceCostTrendProvider(range));

    return Scaffold(
      appBar: AppBar(title: Text(loc.nav_maintenance)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(maintenanceScheduleProvider(filter));
          ref.invalidate(maintenanceCostTrendProvider(range));
          await Future.wait([
            ref.read(maintenanceScheduleProvider(filter).future),
            ref.read(maintenanceCostTrendProvider(range).future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            // ── Cost trend charts ──
            Text(loc.maintenance_costTrend, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            trendAsync.when(
              loading: () => const _ChartSkeleton(),
              error: (e, _) => AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text('${loc.general_error}: $e'),
                ),
              ),
              data: (trend) => _CostTrendSection(data: trend),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Schedule list ──
            Row(
              children: [
                Text(loc.maintenance_schedules,
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                FilterChip(
                  label: Text(loc.maintenance_overdueOnly),
                  selected: _overdueOnly,
                  onSelected: _toggleOverdue,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            scheduleAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: Text('${loc.general_error}: $e')),
              ),
              data: (page) {
                // Overdue first, then soonest next-due.
                final items = [...page.items]..sort((a, b) {
                    if (a.overdue != b.overdue) return a.overdue ? -1 : 1;
                    final ad = a.nextDue;
                    final bd = b.nextDue;
                    if (ad == null) return bd == null ? 0 : 1;
                    if (bd == null) return -1;
                    return ad.compareTo(bd);
                  });
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: EmptyState(
                      icon: const Icon(LucideIcons.wrench, size: 56),
                      title: loc.maintenance_emptyTitle,
                      subtitle: loc.maintenance_emptyHint,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final schedule in items) ...[
                      _ScheduleCard(
                        schedule: schedule,
                        onRecordWork: () => _recordWork(schedule),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: buildIfPermitted(
        ref,
        Permissions.scheduleMaintenance,
        () => FloatingActionButton(
          onPressed: _addSchedule,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

/// Cost trend: monthly LineChart + by-type PieChart with legend.
class _CostTrendSection extends StatelessWidget {
  const _CostTrendSection({required this.data});

  final CostTrendData data;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Column(
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              height: 180,
              child: data.monthly.length < 2
                  ? const Center(child: Text('—'))
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(
                          leftTitles: AxisTitles(),
                          rightTitles: AxisTitles(),
                          topTitles: AxisTitles(),
                          bottomTitles:
                              AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < data.monthly.length; i++)
                                FlSpot(i.toDouble(), data.monthly[i].total),
                            ],
                            isCurved: true,
                            color: AppColors.chartColors[0],
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color:
                                  AppColors.chartColors[0].withValues(alpha: 0.15),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    loc.maintenance_byType,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 160,
                  child: data.byType.isEmpty
                      ? const Center(child: Text('—'))
                      : PieChart(
                          PieChartData(
                            sections: [
                              for (var i = 0; i < data.byType.length; i++)
                                PieChartSectionData(
                                  value: data.byType[i].total,
                                  title:
                                      '${data.byType[i].total.round()}',
                                  color:
                                      AppColors.chartColors[i % AppColors.chartColors.length],
                                  radius: 44,
                                ),
                            ],
                            sectionsSpace: 2,
                            centerSpaceRadius: 36,
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (var i = 0; i < data.byType.length; i++)
                      _LegendDot(
                        color:
                            AppColors.chartColors[i % AppColors.chartColors.length],
                        label: data.byType[i].type,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One schedule row — red left-border accent when overdue.
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule, required this.onRecordWork});

  final MaintenanceScheduleItem schedule;
  final VoidCallback onRecordWork;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(
          color: schedule.overdue ? AppColors.error : AppColors.divider,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Overdue accent bar.
              Container(
                width: 4,
                color: schedule.overdue ? AppColors.error : Colors.transparent,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              schedule.truckPlate,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (schedule.overdue)
                            StatusPill(
                              label: loc.maintenance_overdue,
                              color: AppColors.error,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schedule.maintenanceType,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _detailLine(loc),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: onRecordWork,
                          icon: const Icon(LucideIcons.hammer, size: 16),
                          label: Text(loc.fleet_recordWork),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _detailLine(AppLocalizations loc) {
    final parts = <String>[
      if (schedule.intervalKm != null) '${loc.maintenance_every} ${schedule.intervalKm} km',
      if (schedule.intervalMonths != null)
        '${loc.maintenance_every} ${schedule.intervalMonths} ${loc.maintenance_months}',
      if (schedule.nextDue != null)
        '${loc.maintenance_nextDue}: ${_date(schedule.nextDue!)}',
      if (schedule.lastDoneKm != null)
        '${loc.maintenance_lastKm}: ${schedule.lastDoneKm}',
    ];
    return parts.join(' · ');
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

// ── Add-schedule sheet ─────────────────────────────────────────────────

Future<MaintenanceScheduleDraft?> _showAddScheduleSheet(BuildContext context) {
  return showModalBottomSheet<MaintenanceScheduleDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: const _AddScheduleSheet(),
    ),
  );
}

class _AddScheduleSheet extends ConsumerStatefulWidget {
  const _AddScheduleSheet();

  @override
  ConsumerState<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends ConsumerState<_AddScheduleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _type = TextEditingController();
  final _intervalKm = TextEditingController();
  final _intervalMonths = TextEditingController();
  String? _truckId;
  DateTime? _fixedExpiry;

  @override
  void dispose() {
    _type.dispose();
    _intervalKm.dispose();
    _intervalMonths.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fixedExpiry ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _fixedExpiry = picked);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final truckId = _truckId;
    if (truckId == null) return;
    Navigator.of(context).pop(
      MaintenanceScheduleDraft(
        truckId: truckId,
        maintenanceType: _type.text.trim(),
        intervalKm: int.tryParse(_intervalKm.text.trim()),
        intervalMonths: int.tryParse(_intervalMonths.text.trim()),
        fixedExpiryDate: _fixedExpiry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final trucksAsync = ref.watch(fleetListProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(loc.maintenance_addSchedule,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _truckId,
                decoration: InputDecoration(labelText: loc.maintenance_truck),
                items: [
                  for (final t in trucksAsync.valueOrNull?.trucks ??
                      const <Truck>[])
                    DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.plate} — ${t.brand} ${t.model}'.trim()),
                    ),
                ],
                onChanged: (v) => setState(() => _truckId = v),
                validator: (v) =>
                    v == null ? loc.maintenance_truckRequired : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _type,
                labelText: loc.maintenance_type,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? loc.maintenance_typeRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _intervalKm,
                      labelText: loc.maintenance_intervalKm,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      controller: _intervalMonths,
                      labelText: loc.maintenance_intervalMonths,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: _pickExpiry,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: loc.maintenance_fixedExpiry,
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _fixedExpiry == null
                        ? loc.maintenance_fixedExpiryHint
                        : '${_fixedExpiry!.year}-${_fixedExpiry!.month.toString().padLeft(2, '0')}-${_fixedExpiry!.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton.primary(label: loc.general_save, onPressed: _submit),
              const SizedBox(height: AppSpacing.sm),
              AppButton.secondary(
                label: loc.general_cancel,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
