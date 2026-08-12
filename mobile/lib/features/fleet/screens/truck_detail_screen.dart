import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_guard.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/truck.dart';
import '../providers/fleet_providers.dart';
import '../widgets/health_score_chip.dart';
import '../widgets/record_work_sheet.dart';
import '../widgets/truck_edit_sheet.dart';
import '../../document_center/providers/document_center_providers.dart';

/// Truck detail (blueprint §4.1) — 4 tabs:
/// Overview (fields + edit, gated `can_update_vehicle`; decommission via
/// popup menu gated `can_delete_vehicle`), Maintenance (history + record
/// work), Documents (entity-scoped list, `GET /api/v1/documents/?entity_type=
/// truck&entity_id=`), Assignments (read-only driver).
class TruckDetailScreen extends ConsumerStatefulWidget {
  const TruckDetailScreen({super.key, required this.truckId});

  final String truckId;

  @override
  ConsumerState<TruckDetailScreen> createState() => _TruckDetailScreenState();
}

class _TruckDetailScreenState extends ConsumerState<TruckDetailScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final detailAsync = ref.watch(truckDetailProvider(widget.truckId));
    final canDecommission =
        ref.watch(permissionProvider).can(Permissions.deleteVehicle);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.nav_fleet),
          actions: [
            // Decommission stays in the AppBar overflow — a destructive,
            // secondary action (§9/§10 one-handed reachability convention).
            // The primary Edit action lives on the FAB (bottom two-thirds).
            if (canDecommission)
              PopupMenuButton<String>(
                onSelected: (_) => _confirmDecommission(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'decommission',
                    child: Text(
                      loc.fleet_decommission,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
          ],
          bottom: TabBar(
            onTap: (i) => setState(() => _tabIndex = i),
            tabs: [
              Tab(text: loc.fleet_overview),
              Tab(text: loc.fleet_maintenance),
              Tab(text: loc.fleet_documents),
              Tab(text: loc.fleet_assignments),
            ],
          ),
        ),
        body: detailAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: List.generate(
              3,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: ShimmerCard(),
              ),
            ),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '${loc.general_error}: $e',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.invalidate(truckDetailProvider(widget.truckId)),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(loc.general_retry),
                  ),
                ],
              ),
            ),
          ),
          data: (data) => TabBarView(
            children: [
              _OverviewTab(truck: data.truck, loc: loc),
              _MaintenanceTab(truckId: widget.truckId),
              _DocumentsTab(truckId: widget.truckId, loc: loc),
              _AssignmentsTab(truck: data.truck, loc: loc),
            ],
          ),
        ),
        floatingActionButton: _tabIndex == 1
            ? buildIfPermitted(
                ref,
                Permissions.updateVehicle,
                () => FloatingActionButton(
                  onPressed: _recordWork,
                  tooltip: loc.fleet_recordWork,
                  child: const Icon(Icons.add),
                ),
              )
            // Primary Edit action relocated from the AppBar to the FAB
            // (one-handed reachability audit, blueprint §9 item 6).
            : buildIfPermitted(
                ref,
                Permissions.updateVehicle,
                () => FloatingActionButton(
                  onPressed: _editTruck,
                  tooltip: loc.fleet_edit,
                  child: const Icon(Icons.edit_outlined),
                ),
              ),
      ),
    );
  }

  Future<void> _editTruck() async {
    final truck = ref.read(truckDetailProvider(widget.truckId)).value?.truck;
    if (truck == null || !mounted) return;
    final data = await showTruckEditSheet(context, initial: truck);
    if (data == null || !mounted) return;
    await ref.read(fleetMutationProvider.notifier).updateTruck(
          widget.truckId,
          TruckUpdateDraft(
            plate: data.plate,
            brand: data.brand,
            model: data.model,
            vin: data.vin,
            year: data.year,
          ),
        );
  }

  Future<void> _confirmDecommission() async {
    final loc = context.loc;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: loc.fleet_decommission,
      message: loc.fleet_decommissionConfirm,
      confirmLabel: loc.general_confirm,
      cancelLabel: loc.general_cancel,
      isDangerous: true,
    );
    if (confirmed == true && mounted) {
      await ref.read(fleetMutationProvider.notifier).decommissionTruck(widget.truckId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _recordWork() async {
    final draft = await showRecordWorkSheet(context);
    if (draft == null || !mounted) return;
    await submitRecordMaintenance(ref, widget.truckId, draft);
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.truck, required this.loc});

  final Truck truck;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusKey, statusLabel) = switch (truck.status) {
      TruckStatus.active => ('paid', loc.fleet_statusActive),
      TruckStatus.maintenance => ('maintenance', loc.fleet_statusMaintenance),
      TruckStatus.decommissioned => ('cancelled', loc.fleet_statusDecommissioned),
    };

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${truck.brand} ${truck.model}'.trim(),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    StatusBadge(statusKey: statusKey, label: statusLabel),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(truck.plate, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.md),
                _InfoRow(label: loc.fleet_vin, value: truck.vin ?? loc.teams_notAssigned),
                _InfoRow(
                  label: loc.fleet_year,
                  value: truck.year?.toString() ?? loc.teams_notAssigned,
                ),
                _InfoRow(
                  label: loc.fleet_health,
                  child: HealthScoreChip(score: truck.healthScore),
                ),
                _InfoRow(
                  label: loc.fleet_currentDriver,
                  value: truck.currentDriverId ?? loc.teams_notAssigned,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MaintenanceTab extends ConsumerWidget {
  const _MaintenanceTab({required this.truckId});

  final String truckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final history = ref.watch(truckMaintenanceHistoryProvider(truckId));
    return history.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: ShimmerCard(),
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text('${loc.general_error}: $e'),
        ),
      ),
      data: (records) => records.isEmpty
          ? EmptyState(
              icon: const Icon(Icons.build, size: 56),
              title: loc.fleet_noMaintenance,
              subtitle: loc.fleet_recordWorkHint,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final r = records[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: ListTile(
                      leading: const Icon(Icons.build, color: AppColors.accent),
                      title: Text(r.category.apiValue),
                      subtitle: Text(
                        '${r.date} · ${r.vendor ?? ''}'.trim(),
                      ),
                      trailing: Text(
                        '${r.cost.toStringAsFixed(2)} RON',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _DocumentsTab extends ConsumerWidget {
  const _DocumentsTab({required this.truckId, required this.loc});

  final String truckId;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(
      entityDocumentsProvider(
        EntityDocumentsRequest(entityType: 'truck', entityId: truckId),
      ),
    );
    return docsAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: ShimmerCard(),
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${loc.general_error}: $e',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(
                  entityDocumentsProvider(
                    EntityDocumentsRequest(
                      entityType: 'truck',
                      entityId: truckId,
                    ),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(loc.general_retry),
              ),
            ],
          ),
        ),
      ),
      data: (docs) => docs.isEmpty
          ? EmptyState(
              icon: const Icon(Icons.folder_outlined, size: 56),
              title: loc.fleet_documents,
              subtitle: loc.fleet_noDocuments,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: ListTile(
                      leading: const Icon(
                        Icons.folder_outlined,
                        color: AppColors.accent,
                      ),
                      title: Text(
                        doc.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(doc.category),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _AssignmentsTab extends StatelessWidget {
  const _AssignmentsTab({required this.truck, required this.loc});

  final Truck truck;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.fleet_assignments, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(
                  label: loc.fleet_currentDriver,
                  value: truck.currentDriverId ?? loc.teams_notAssigned,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  loc.fleet_assignmentsNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value, this.child});

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: child ??
                Text(value ?? '', style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
