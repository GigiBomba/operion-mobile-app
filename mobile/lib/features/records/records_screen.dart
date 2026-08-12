import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/permission_guard.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/master_detail_layout.dart';
import '../clients/screens/client_list_screen.dart';
import '../fleet/screens/fleet_list_screen.dart';
import '../global_search/screens/global_search_screen.dart';
import '../history/screens/route_history_screen.dart';
import '../history/screens/trip_history_screen.dart';
import '../teams/screens/teams_screen.dart';

/// A single Records-grid tile definition.
class RecordsTileDef {
  final IconData icon;
  final String label;
  final WidgetBuilder builder;

  /// Any-of permission gate (§8.2): the tile renders only when the current
  /// user holds at least one of these.
  final Set<Permission> permissions;

  const RecordsTileDef({
    required this.icon,
    required this.label,
    required this.builder,
    required this.permissions,
  });
}

/// All Records tiles, permission-filtered.
///
/// The grid filters this list BEFORE `itemCount` (Gate-2 F4 / §8.2) — denied
/// tiles are never built, so there are no disabled-but-visible controls.
List<RecordsTileDef> buildRecordsTiles(
  AppLocalizations loc,
  bool Function(Permission) can,
) {
  final all = [
    RecordsTileDef(
      icon: Icons.local_shipping,
      label: loc.records_fleet,
      permissions: {
        Permissions.createVehicle,
        Permissions.updateVehicle,
      },
      // The list screens embed their own tablet master-detail when opened
      // standalone; inside the Records detail pane they render the plain list
      // to avoid nesting (§9 item 5).
      builder: (_) => const FleetListScreen(enableTabletLayout: false),
    ),
    RecordsTileDef(
      icon: Icons.group,
      label: loc.records_drivers,
      permissions: {
        Permissions.createDriver,
        Permissions.updateDriver,
      },
      builder: (_) => const TeamsScreen(enableTabletLayout: false),
    ),
    RecordsTileDef(
      icon: Icons.business,
      label: loc.records_clients,
      permissions: {
        Permissions.createClient,
        Permissions.updateClient,
      },
      builder: (_) => const ClientListScreen(enableTabletLayout: false),
    ),
    RecordsTileDef(
      icon: Icons.history,
      label: loc.records_tripHistory,
      permissions: const {Permissions.exportData},
      builder: (_) => const TripHistoryScreen(enableTabletLayout: false),
    ),
    RecordsTileDef(
      icon: Icons.route_outlined,
      label: loc.records_routeHistory,
      permissions: const {Permissions.exportData},
      builder: (_) => const RouteHistoryScreen(enableTabletLayout: false),
    ),
  ];
  return all.where((t) => t.permissions.any(can)).toList();
}

/// Records tab (blueprint §3): a searchable grid of entity tiles.
///
/// Fleet / Drivers (existing Teams screen) / Clients / Trip History /
/// Route History. Tiles are permission-filtered before itemCount. On tablet
/// widths (≥600dp) the grid renders as the list pane of a master-detail
/// layout (§9).
class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  final _search = TextEditingController();
  String _query = '';
  int? _selectedTile;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const GlobalSearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final permission = ref.watch(permissionProvider);

    // Permission-filtered BEFORE itemCount (§8.2).
    final permitted = buildRecordsTiles(loc, permission.can);
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? permitted
        : permitted
            .where((t) => t.label.toLowerCase().contains(q))
            .toList();

    final grid = visible.isEmpty
        ? EmptyState(
            icon: const Icon(Icons.search_off),
            title: loc.records_emptyTitle,
            subtitle: loc.records_emptyHint,
          )
        : _RecordsGrid(tiles: visible);

    final tablet = isTabletWidth(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.nav_records),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: loc.globalSearch_openSearch,
            onPressed: _openSearch,
          ),
        ],
      ),
      body: tablet && visible.isNotEmpty
          ? MasterDetailLayout(
              selectedIndex: _selectedTile ?? 0,
              listPane: Column(
                children: [
                  _buildSearchField(loc),
                  Expanded(
                    child: _RecordsGrid(
                      tiles: visible,
                      onTileTap: (index) =>
                          setState(() => _selectedTile = index),
                    ),
                  ),
                ],
              ),
              detailBuilder: (context, index) {
                final tile = visible[index.clamp(0, visible.length - 1)];
                return tile.builder(context);
              },
            )
          : Column(
              children: [
                _buildSearchField(loc),
                Expanded(child: grid),
              ],
            ),
    );
  }

  Widget _buildSearchField(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: AppTextField(
        controller: _search,
        hintText: loc.records_searchHint,
        prefixIcon: const Icon(Icons.search),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }
}

class _RecordsGrid extends ConsumerWidget {
  const _RecordsGrid({required this.tiles, this.onTileTap});

  final List<RecordsTileDef> tiles;

  /// Optional callback for tablet master-detail selection. When null, tiles
  /// push their destination screen (phone behavior).
  final void Function(int index)? onTileTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tiles.isEmpty) {
      return EmptyState(
        icon: const Icon(Icons.search_off),
        title: context.loc.records_emptyTitle,
        subtitle: context.loc.records_emptyHint,
      );
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final tile = tiles[index];
                return AppCard(
                  onTap: onTileTap != null
                      ? () => onTileTap!(index)
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: tile.builder),
                          ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(tile.icon, size: 28, color: AppColors.primary),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        tile.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: tiles.length,
            ),
          ),
        ),
      ],
    );
  }
}
