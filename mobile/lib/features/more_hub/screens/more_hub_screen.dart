import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permission_guard.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/master_detail_layout.dart';
import '../../analytics/screens/analytics_screen.dart';
import '../../dispatcher/alerts/alert_inbox_screen.dart';
import '../../dispatcher/jobs/job_list_screen.dart';
import '../../document_center/screens/document_center_screen.dart';
import '../../driver/messages/message_list_screen.dart';
import '../../freight_exchange/screens/freight_exchange_screen.dart';
import '../../global_search/screens/global_search_screen.dart';
import '../../local_download/screens/local_download_screen.dart';
import '../../maintenance/screens/maintenance_screen.dart';
import '../../invoicing/screens/invoice_list_screen.dart';
import '../../profit_calculator/screens/profit_calculator_screen.dart';
import '../../report_issue/providers/report_issue_providers.dart';
import '../../report_issue/screens/report_issue_screen.dart';
import '../../report_issue/screens/report_issue_sheet.dart';
import '../../route_planner/screens/route_planner_screen.dart';
import '../../settings/settings_screen.dart';
import '../../tachograph/screens/tachograph_screen.dart';
import '../../team_management/screens/team_management_screen.dart';

/// A single More tab tile definition.
class MoreTileDef {
  final IconData icon;
  final String label;
  final WidgetBuilder builder;

  /// Any-of permission gate (§8.2): only renders when the user holds one.
  final Set<Permission> permissions;

  /// Lightweight input flows open as a bottom sheet (blueprint 41.3e); the
  /// [builder] remains the full-screen fallback for tablet master-detail and
  /// push deep links.
  final bool opensSheet;

  /// Unread-reply dot on the tile (More-tab badge propagation).
  final bool showBadge;

  const MoreTileDef({
    required this.icon,
    required this.label,
    required this.builder,
    required this.permissions,
    this.opensSheet = false,
    this.showBadge = false,
  });
}

/// All More tiles, permission-filtered before `itemCount`.
///
/// [showReportIssueBadge] is computed from [reportIssueBadgeProvider] by the
/// screen and painted on the "Report an Issue" tile.
List<MoreTileDef> buildMoreTiles(
  AppLocalizations loc,
  bool Function(Permission) can, {
  bool showReportIssueBadge = false,
}) {
  final all = [
    MoreTileDef(
      icon: LucideIcons.messageSquare,
      label: loc.nav_messages,
      builder: (_) => const MessageListScreen(),
      permissions: const {},
    ),
    MoreTileDef(
      icon: LucideIcons.barChart3,
      label: loc.nav_analytics,
      builder: (_) => const AnalyticsScreen(),
      permissions: const {Permissions.viewAnalytics},
    ),
    MoreTileDef(
      icon: LucideIcons.briefcase,
      label: loc.nav_jobs,
      builder: (_) => const JobListScreen(),
      permissions: const {},
    ),
    MoreTileDef(
      icon: LucideIcons.bell,
      label: loc.nav_alerts,
      builder: (_) => const AlertInboxScreen(),
      permissions: const {},
    ),
    MoreTileDef(
      icon: LucideIcons.calculator,
      label: loc.nav_profitCalculator,
      builder: (_) => const ProfitCalculatorScreen(),
      permissions: const {},
    ),
    MoreTileDef(
      icon: LucideIcons.route,
      label: loc.nav_routePlanner,
      builder: (_) => const RoutePlannerScreen(),
      permissions: const {},
    ),
    MoreTileDef(
      icon: LucideIcons.search,
      label: loc.nav_freightExchange,
      builder: (_) => const FreightExchangeScreen(),
      permissions: const {},
    ),
    MoreTileDef(
      icon: LucideIcons.folderOpen,
      label: loc.nav_documentCenter,
      builder: (_) => const DocumentCenterScreen(),
      permissions: const {},
    ),
    MoreTileDef(
      icon: LucideIcons.download,
      label: loc.nav_localDownload,
      builder: (_) => const LocalDownloadScreen(),
      permissions: const {},
    ),
    MoreTileDef(
      icon: LucideIcons.fileText,
      label: loc.nav_invoicing,
      builder: (_) => const InvoiceListScreen(enableTabletLayout: false),
      permissions: const {Permissions.createInvoice},
    ),
    MoreTileDef(
      icon: LucideIcons.wrench,
      label: loc.nav_maintenance,
      builder: (_) => const MaintenanceScreen(),
      permissions: const {Permissions.scheduleMaintenance},
    ),
    MoreTileDef(
      icon: LucideIcons.users,
      label: loc.nav_teamsManagement,
      builder: (_) => const TeamManagementScreen(enableTabletLayout: false),
      permissions: const {Permissions.canManageUsers},
    ),
    MoreTileDef(
      icon: LucideIcons.fileBadge,
      label: loc.nav_tachograph,
      builder: (_) => const TachographScreen(),
      permissions: const {Permissions.uploadDocument},
    ),
    MoreTileDef(
      icon: LucideIcons.flag,
      label: loc.nav_reportIssue,
      builder: (_) => const ReportIssueScreen(),
      permissions: const {},
      opensSheet: true,
      showBadge: showReportIssueBadge,
    ),
    MoreTileDef(
      icon: LucideIcons.settings,
      label: loc.nav_settings,
      builder: (_) => const SettingsScreen(enableTabletLayout: false),
      permissions: const {},
    ),
  ];
  return all
      .where((t) => t.permissions.isEmpty || t.permissions.any(can))
      .toList();
}

/// A scrollable grid of quick-access tiles shown from the More tab.
///
/// Provides 10 tiles for navigating to dispatcher features. The Teams tile
/// lives in the Records tab (blueprint §3). Analytics is gated by
/// `can_view_analytics` (dispatcher sees no tile, §8.2). On tablet widths
/// (≥600dp) the grid becomes the list pane of a master-detail layout (§9).
class MoreHubScreen extends ConsumerStatefulWidget {
  const MoreHubScreen({super.key});

  @override
  ConsumerState<MoreHubScreen> createState() => _MoreHubScreenState();
}

class _MoreHubScreenState extends ConsumerState<MoreHubScreen> {
  int? _selectedTile;

  @override
  void initState() {
    super.initState();
    // Resume the persisted report thread on first open so the reply badge is
    // accurate before the customer taps the tile (blueprint 41.3e).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(reportIssueControllerProvider.notifier).load();
    });
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
    final showReportIssueBadge = ref.watch(reportIssueBadgeProvider);
    final tiles = buildMoreTiles(
      loc,
      permission.can,
      showReportIssueBadge: showReportIssueBadge,
    );
    final tablet = isTabletWidth(context) && tiles.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.nav_more),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: loc.globalSearch_openSearch,
            onPressed: _openSearch,
          ),
        ],
      ),
      body: tablet
          ? MasterDetailLayout(
              selectedIndex: _selectedTile ?? 0,
              listPane: Column(
                children: [
                  Expanded(
                    child: _MoreGrid(
                      tiles: tiles,
                      scrollable: true,
                      onTileTap: (index) =>
                          setState(() => _selectedTile = index),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmLogout(context, ref),
                        icon: const Icon(Icons.logout, color: AppColors.error),
                        label: Text(
                          loc.moreHub_logout,
                          style: const TextStyle(color: AppColors.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              detailBuilder: (context, index) {
                final tile = tiles[index.clamp(0, tiles.length - 1)];
                return tile.builder(context);
              },
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                _MoreGrid(tiles: tiles),
                const SizedBox(height: AppSpacing.xxl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context, ref),
                      icon: const Icon(Icons.logout, color: AppColors.error),
                      label: Text(
                        loc.moreHub_logout,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Shows a confirmation dialog and performs logout on confirm.
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final loc = context.loc;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.auth_logout),
        content: Text(loc.auth_logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.general_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.general_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authServiceProvider).logout();
      ref.read(authStateProvider.notifier).setUnauthenticated();
    }
  }
}

class _MoreGrid extends StatelessWidget {
  const _MoreGrid({required this.tiles, this.onTileTap, this.scrollable = false});

  final List<MoreTileDef> tiles;
  final void Function(int index)? onTileTap;

  /// When true the grid scrolls within its parent (tablet list pane);
  /// otherwise it shrink-wraps inside the phone ListView.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: !scrollable,
      physics: scrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.2,
      children: [
        for (var i = 0; i < tiles.length; i++)
          _MoreTile(
            icon: tiles[i].icon,
            label: tiles[i].label,
            showBadge: tiles[i].showBadge,
            onTap: onTileTap != null
                ? () => onTileTap!(i)
                : () {
                    if (tiles[i].opensSheet) {
                      showReportIssueSheet(context);
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: tiles[i].builder),
                    );
                  },
          ),
      ],
    );
  }
}

/// A single grid tile inside [MoreHubScreen].
///
/// Displays a Lucide icon and label text on an [AppCard].
class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showBadge;

  /// Test handle matching the app-wide unread-dot convention
  /// (`alert_inbox_screen.dart`: an 8x8 `AppColors.info` circle).
  static const Key badgeKey = Key('moreTileBadgeDot');

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 28, color: AppColors.primary),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (showBadge)
            Positioned(
              top: 0,
              right: 0,
              child: Tooltip(
                message: context.loc.reportIssue_badgeTooltip,
                child: Container(
                  key: badgeKey,
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.info,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
