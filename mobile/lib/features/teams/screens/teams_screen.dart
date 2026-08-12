import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/permission_guard.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/master_detail_layout.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/status_badge.dart';
import '../providers/teams_providers.dart';
import '../widgets/driver_edit_sheet.dart';
import 'driver_detail_screen.dart';

/// Teams screen — drivers/roster view with filter chips.
///
/// Shows a list of all company drivers with status filtering.
/// Each driver shows avatar, name, status indicator, and current assignment.
/// Implements §1.2: shimmer loading, error with retry, empty state, and
/// pull-to-refresh on the driver list. The Add-driver FAB is gated by
/// `can_create_driver` (§8.2) and opens [DriverEditSheet] in CREATE mode
/// (offline-queued via [DriverMutationNotifier.createDriver] per §7).
///
/// On tablet widths (≥600dp) the list becomes the list pane of a
/// master-detail layout with the driver detail as the detail pane (§9 item 5).
class TeamsScreen extends ConsumerStatefulWidget {
  const TeamsScreen({super.key, this.enableTabletLayout = true});

  final bool enableTabletLayout;

  @override
  ConsumerState<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends ConsumerState<TeamsScreen> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final selectedFilter = ref.watch(teamsFilterProvider);
    final filtered = ref.watch(teamsFilteredDriversProvider);
    final tablet = widget.enableTabletLayout &&
        isTabletWidth(context) &&
        filtered.isNotEmpty;

    final listPane = Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: DriverFilter.values.map((filter) {
                final selected = selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: Text(_filterLabel(filter, loc)),
                    selected: selected,
                    onSelected: (_) {
                      ref.read(teamsFilterProvider.notifier).state = filter;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Driver list
        Expanded(
          child: ref.watch(teamsDriversProvider).when(
            loading: () => ListView.builder(
              itemCount: 6,
              itemBuilder: (_, _) => const ShimmerCard(),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.alertCircle,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${loc.general_error}: $e',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(teamsDriversProvider),
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      label: Text(loc.general_retry),
                    ),
                  ],
                ),
              ),
            ),
            data: (_) {
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(teamsDriversProvider);
                  await ref.read(teamsDriversProvider.future);
                },
                child: filtered.isEmpty
                    // Scrollable so pull-to-refresh still works on empty.
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: AppSpacing.xxl * 3),
                          EmptyState(
                            icon: const Icon(LucideIcons.users, size: 56),
                            title: loc.nav_teams,
                            subtitle: loc.teams_placeholder,
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final d = filtered[index];
                          return _driverTile(context, loc, theme, d, index, tablet);
                        },
                      ),
              );
            },
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(loc.nav_teams)),
      body: tablet
          ? MasterDetailLayout(
              selectedIndex: _selectedIndex ?? 0,
              listPane: listPane,
              detailBuilder: (context, index) {
                final sel = index.clamp(0, filtered.length - 1);
                return DriverDetailScreen(driver: filtered[sel]);
              },
            )
          : listPane,
      floatingActionButton: buildIfPermitted(
        ref,
        Permissions.createDriver,
        () => FloatingActionButton(
          onPressed: () => _openCreateDriver(context, ref),
          child: const Icon(Icons.person_add_alt),
        ),
      ),
    );
  }

  Widget _driverTile(
    BuildContext context,
    AppLocalizations loc,
    ThemeData theme,
    Map<String, dynamic> d,
    int index,
    bool tablet,
  ) {
    final name = d['name'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final transport = d['current_transport'] as String? ?? '';
    final vehicle = d['current_vehicle'] as String? ?? '';
    final assignment = [transport, vehicle].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: tablet
            ? () => setState(() => _selectedIndex = index)
            : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DriverDetailScreen(driver: d),
                  ),
                ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  if (assignment.isNotEmpty)
                    Text(
                      assignment,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            StatusBadge(statusKey: d['status'] as String? ?? ''),
          ],
        ),
      ),
    );
  }

  /// Opens [DriverEditSheet] in CREATE mode (no [DriverDetail]) and submits the
  /// draft through [DriverMutationNotifier.createDriver] (offline-queued §7).
  Future<void> _openCreateDriver(BuildContext context, WidgetRef ref) async {
    final draft = await showDriverEditSheet(context);
    if (draft == null || !context.mounted) return;
    await ref.read(driverMutationProvider.notifier).createDriver(draft);
  }

  String _filterLabel(DriverFilter filter, AppLocalizations loc) {
    switch (filter) {
      case DriverFilter.all:
        return loc.teams_filterAll;
      case DriverFilter.available:
        return loc.teams_filterAvailable;
      case DriverFilter.driving:
        return loc.teams_filterDriving;
      case DriverFilter.off:
        return loc.teams_filterOff;
      case DriverFilter.expiring:
        return loc.teams_filterExpiring;
    }
  }
}
