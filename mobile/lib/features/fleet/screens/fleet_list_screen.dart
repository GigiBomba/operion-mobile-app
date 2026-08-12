import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_guard.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/master_detail_layout.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/truck.dart';
import '../providers/fleet_providers.dart';
import '../widgets/health_score_chip.dart';
import '../widgets/truck_edit_sheet.dart';
import 'truck_detail_screen.dart';

/// Fleet list (blueprint §4.1): searchable, pull-to-refresh, dual-mode
/// (network → cached banner). Create FAB is gated by `can_create_vehicle`
/// (§8.2 — no disabled-but-visible controls).
///
/// On tablet widths (≥600dp) the list becomes the list pane of a
/// master-detail layout with the truck detail as the detail pane (§9 item 5).
/// [enableTabletLayout] is turned off when this screen is itself embedded as
/// a detail pane (Records/More master-detail) to avoid nesting.
class FleetListScreen extends ConsumerStatefulWidget {
  const FleetListScreen({super.key, this.enableTabletLayout = true});

  final bool enableTabletLayout;

  @override
  ConsumerState<FleetListScreen> createState() => _FleetListScreenState();
}

class _FleetListScreenState extends ConsumerState<FleetListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _localFilter = '';
  int? _selectedIndex;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Client-side filter applies instantly; the server search is debounced.
    setState(() => _localFilter = value.trim().toLowerCase());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        ref.read(fleetSearchProvider.notifier).state = value.trim();
      }
    });
  }

  Future<void> _openCreate() async {
    final data = await showTruckEditSheet(context);
    if (data == null || !mounted) return;
    await ref
        .read(fleetMutationProvider.notifier)
        .createTruck(TruckDraft(
          plate: data.plate,
          brand: data.brand,
          model: data.model,
          vin: data.vin,
          year: data.year,
        ));
  }

  List<Truck> _filter(FleetListData data) {
    return data.trucks
        .where((t) =>
            _localFilter.isEmpty ||
            t.plate.toLowerCase().contains(_localFilter) ||
            t.brand.toLowerCase().contains(_localFilter) ||
            t.model.toLowerCase().contains(_localFilter))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final showCachedBanner = ref.watch(fleetCachedBannerProvider);
    final listAsync = ref.watch(fleetListProvider);
    final visibleTrucks =
        listAsync.valueOrNull == null ? const <Truck>[] : _filter(listAsync.valueOrNull!);
    final tablet =
        widget.enableTabletLayout && isTabletWidth(context) && visibleTrucks.isNotEmpty;

    final listPane = Column(
      children: [
        if (showCachedBanner) _CachedDataBanner(label: loc.fleet_cached),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppTextField(
            controller: _searchController,
            hintText: loc.fleet_searchHint,
            prefixIcon: const Icon(Icons.search),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: listAsync.when(
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
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${loc.general_error}: $e',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(fleetListProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(loc.general_retry),
                    ),
                  ],
                ),
              ),
            ),
            data: (_) {
              final trucks = visibleTrucks;
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(fleetListProvider);
                  await ref.read(fleetListProvider.future);
                },
                child: trucks.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: AppSpacing.xxl * 3),
                          EmptyState(
                            icon: const Icon(Icons.local_shipping, size: 56),
                            title: loc.fleet_emptyTitle,
                            subtitle: loc.fleet_emptyHint,
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        itemCount: trucks.length,
                        itemBuilder: (context, index) {
                          final truck = trucks[index];
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              onTap: tablet
                                  ? () =>
                                      setState(() => _selectedIndex = index)
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => TruckDetailScreen(
                                              truckId: truck.id),
                                        ),
                                      ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            truck.plate,
                                            style:
                                                theme.textTheme.titleSmall
                                                    ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${truck.brand} ${truck.model}'
                                                .trim(),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color:
                                                  AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    HealthScoreChip(score: truck.healthScore),
                                    const SizedBox(width: AppSpacing.sm),
                                    _statusBadge(truck, loc),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              );
            },
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(loc.nav_fleet)),
      body: tablet
          ? MasterDetailLayout(
              selectedIndex: _selectedIndex ?? 0,
              listPane: listPane,
              detailBuilder: (context, index) {
                final sel = index.clamp(0, visibleTrucks.length - 1);
                return TruckDetailScreen(truckId: visibleTrucks[sel].id);
              },
            )
          : listPane,
      floatingActionButton: buildIfPermitted(
        ref,
        Permissions.createVehicle,
        () => FloatingActionButton(
          onPressed: _openCreate,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _statusBadge(Truck truck, AppLocalizations loc) {
    final (key, label) = switch (truck.status) {
      TruckStatus.active => ('paid', loc.fleet_statusActive),
      TruckStatus.maintenance => ('maintenance', loc.fleet_statusMaintenance),
      TruckStatus.decommissioned => ('cancelled', loc.fleet_statusDecommissioned),
    };
    return StatusBadge(statusKey: key, label: label);
  }
}

/// Non-blocking "showing cached data" banner (dual-mode §5).
class _CachedDataBanner extends StatelessWidget {
  const _CachedDataBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warningSubtle,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16, color: AppColors.warningText),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.warningText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
