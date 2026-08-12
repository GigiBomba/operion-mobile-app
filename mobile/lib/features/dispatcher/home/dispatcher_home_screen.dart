import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/staleness_indicator.dart';
import '../../driver/messages/message_list_screen.dart';
import '../../global_search/screens/global_search_screen.dart';
import '../alerts/alert_inbox_screen.dart';
import 'dispatcher_providers.dart';

/// The dispatcher's dashboard overview screen — a scrollable summary with
/// KPI cards, recent activity timestamp, and quick action shortcuts.
///
/// Watches [dispatcherOverviewProvider] and handles loading (shimmer grid),
/// error (retry), and empty states. Owns a minimal [AppBar] with the global
/// search action (§3) — the home tab previously had no AppBar at all.
class DispatcherHomeScreen extends ConsumerWidget {
  const DispatcherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(dispatcherOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.dispatcher_overview),
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
        ],
      ),
      body: overviewAsync.when(
        loading: () => _buildLoadingShimmer(context),
        error: (error, stack) => _buildError(context, ref, error),
        data: (data) => _buildDashboard(context, ref, data),
      ),
    );
  }

  /// Shimmer skeleton that mimics the dashboard layout while data loads.
  Widget _buildLoadingShimmer(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header shimmer
          _ShimmerBlock(height: 20, width: 0.4),
          const SizedBox(height: AppSpacing.lg),
          // 2x2 KPI card grid shimmer
          _buildKpiGridSkeleton(),
          const SizedBox(height: AppSpacing.xxl),
          // Section header shimmer
          _ShimmerBlock(height: 16, width: 0.35),
          const SizedBox(height: AppSpacing.md),
          // Quick actions placeholder
          SizedBox(
            height: 48,
            child: ShimmerLoader(
              child: Row(
                children: [
                  Container(
                    width: 120,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xhuge),
        ],
      ),
    );
  }

  /// A 2x2 grid of shimmer skeleton KPI cards.
  Widget _buildKpiGridSkeleton() {
    return ShimmerLoader(
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(child: _KpiCardSkeleton()),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: _KpiCardSkeleton()),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: const [
              Expanded(child: _KpiCardSkeleton()),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: _KpiCardSkeleton()),
            ],
          ),
        ],
      ),
    );
  }

  /// Centered error panel with a retry button.
  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    final loc = context.loc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.alertCircle,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              loc.general_error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => ref.invalidate(dispatcherOverviewProvider),
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: Text(loc.general_retry),
            ),
          ],
        ),
      ),
    );
  }

  /// Full dashboard when overview data is available.
  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> data,
  ) {
    final loc = context.loc;
    final theme = Theme.of(context);

    // ── Extract overview keys with safe fallbacks ─────────────
    final activeJobs = data['activeJobs'] as int? ?? 0;
    final activeDrivers = data['activeDrivers'] as int? ?? 0;
    final openAlerts = data['openAlerts'] as int? ?? 0;
    final vehiclesOnRoad = data['vehiclesOnRoad'] as int? ?? 0;
    final lastUpdated = data['lastUpdated'] != null
        ? DateTime.tryParse(data['lastUpdated'] as String)
        : null;

    // §2 parity — both are parsed defensively; absent/null → empty lists so
    // an older backend never breaks the dashboard.
    final revenueTrend = parseRevenueTrend(data['revenue_trend']);
    final recentActivity = parseRecentActivity(data['recent_activity']);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dispatcherOverviewProvider);
        await ref.read(dispatcherOverviewProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Staleness indicator ────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: StalenessIndicator(lastUpdated: lastUpdated),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── KPI cards 2x2 grid ───────────────────────────
            _KpiGrid(
              activeJobs: activeJobs,
              activeDrivers: activeDrivers,
              openAlerts: openAlerts,
              vehiclesOnRoad: vehiclesOnRoad,
              onJobTap: () =>
                  ref.read(dispatcherTabProvider.notifier).state = 2,
              onDriverTap: () =>
                  ref.read(dispatcherTabProvider.notifier).state = 4,
              onAlertTap: () =>
                  ref.read(dispatcherTabProvider.notifier).state = 3,
              onFleetTap: () =>
                  ref.read(dispatcherTabProvider.notifier).state = 1,
            ),
            const SizedBox(height: AppSpacing.xxl),

            // ── Revenue trend sparkline (§2 — only when data exists) ──
            if (revenueTrend.isNotEmpty) ...[
              _RevenueTrendCard(points: revenueTrend),
              const SizedBox(height: AppSpacing.xxl),
            ],

            // ── Recent activity feed (§2) ──────────────────────────
            Text(
              loc.dispatcher_activityFeed,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (recentActivity.isEmpty)
              _EmptyActivity()
            else
              _ActivityFeed(
                items: recentActivity,
                onAlertTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AlertInboxScreen(),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),

            // ── Quick Actions ─────────────────────────────────
            Text(
              loc.dispatcher_quickActions,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  switch (index) {
                    case 0:
                      return _QuickActionChip(
                        icon: LucideIcons.checkCircle,
                        label: loc.dispatcher_approve,
                        onTap: () =>
                            ref.read(dispatcherTabProvider.notifier).state = 3,
                      );
                    case 1:
                      return _QuickActionChip(
                        icon: LucideIcons.messageSquare,
                        label: loc.nav_messages,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MessageListScreen(),
                          ),
                        ),
                      );
                    case 2:
                      return _QuickActionChip(
                        icon: LucideIcons.map,
                        label: loc.dispatcher_liveFleet,
                        onTap: () =>
                            ref.read(dispatcherTabProvider.notifier).state = 1,
                      );
                    default:
                      return const SizedBox.shrink();
                  }
                },
              ),
            ),

            // Bottom spacing for nav bar clearance.
            const SizedBox(height: AppSpacing.xhuge),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Private helper widgets
// ═════════════════════════════════════════════════════════════════════════════

/// The 2x2 grid of KPI stat cards.
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.activeJobs,
    required this.activeDrivers,
    required this.openAlerts,
    required this.vehiclesOnRoad,
    this.onJobTap,
    this.onDriverTap,
    this.onAlertTap,
    this.onFleetTap,
  });

  final int activeJobs;
  final int activeDrivers;
  final int openAlerts;
  final int vehiclesOnRoad;
  final VoidCallback? onJobTap;
  final VoidCallback? onDriverTap;
  final VoidCallback? onAlertTap;
  final VoidCallback? onFleetTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: LucideIcons.briefcase,
                label: context.loc.dispatcher_activeJobs,
                value: '$activeJobs',
                color: AppColors.accent,
                onTap: onJobTap,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiCard(
                icon: LucideIcons.userCheck,
                label: context.loc.dispatcher_activeDrivers,
                value: '$activeDrivers',
                color: AppColors.success,
                onTap: onDriverTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: LucideIcons.alertTriangle,
                label: context.loc.dispatcher_openAlerts,
                value: '$openAlerts',
                color: AppColors.warning,
                onTap: onAlertTap,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiCard(
                icon: LucideIcons.truck,
                label: context.loc.dispatcher_liveFleet,
                value: '$vehiclesOnRoad',
                color: AppColors.info,
                onTap: onFleetTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A KPI stat card with a large translucent background icon, bold value,
/// and small label. Tapping switches to the corresponding tab.
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      child: Stack(
        children: [
          // Large translucent background icon
          Positioned(
            right: -4,
            bottom: -4,
            child: Icon(
              icon,
              size: 48,
              color: color.withValues(alpha: 0.12),
            ),
          ),
          // Foreground content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder for [_KpiCard] during loading.
class _KpiCardSkeleton extends StatelessWidget {
  const _KpiCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 80,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pill-shaped quick-action chip for the horizontal scroll row.
class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );
  }
}

/// A generic shimmer block used in the loading skeleton.
class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({required this.height, required this.width});

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      child: FractionallySizedBox(
        widthFactor: width,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// §2 Feature-parity widgets — revenue sparkline + recent-activity feed
// ═════════════════════════════════════════════════════════════════════════════

/// Compact revenue sparkline card fed by the overview `revenue_trend`
/// (last 6 months). Rendered only when the trend list is non-empty.
class _RevenueTrendCard extends StatelessWidget {
  const _RevenueTrendCard({required this.points});

  final List<RevenueTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.loc.dispatcher_revenueTrend,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 88,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _shortMonth(points[idx].month),
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].revenue),
                      ],
                      isCurved: true,
                      color: AppColors.chartColors[0],
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color:
                            AppColors.chartColors[0].withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shortens a backend month label (`2026-02`, `Feb 2026`, ...) to a 3-char
  /// month token for the axis; falls back to the raw label.
  static String _shortMonth(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length < 3) return trimmed;
    // ISO `YYYY-MM` → "MM".
    if (trimmed.length == 7 && trimmed[4] == '-') {
      final mm = trimmed.substring(5);
      return mm;
    }
    // Already an abbreviated name like "Feb".
    final firstWord = trimmed.split(' ').first;
    return firstWord.length <= 3 ? firstWord : firstWord.substring(0, 3);
  }
}

/// Empty-state for the activity feed (no `recent_activity` payload).
class _EmptyActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Text(
        context.loc.dispatcher_activityEmpty,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// Recent-activity feed: one row per item with a type icon
/// (trip → route icon, alert → bell), title and relative time.
///
/// Alert items are tappable and open [AlertInboxScreen]; trip items currently
/// render as static rows (the backend contract carries no deep-link target).
class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.items, required this.onAlertTap});

  final List<RecentActivityItem> items;
  final VoidCallback onAlertTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(height: 1),
            _ActivityRow(
              item: items[i],
              onTap: items[i].isAlert ? onAlertTap : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// A single activity row.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, this.onTap});

  final RecentActivityItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAlert = item.isAlert;
    final color = isAlert ? AppColors.warning : AppColors.accent;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                isAlert ? LucideIcons.bell : LucideIcons.route,
                size: 16,
                color: color,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (item.createdAt != null)
              Text(
                _relativeTime(item.createdAt!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                LucideIcons.chevronRight,
                size: 14,
                color: AppColors.neutralText,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _relativeTime(DateTime date) {
    final delta = DateTime.now().difference(date);
    if (delta.inMinutes < 1) return 'now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m';
    if (delta.inHours < 24) return '${delta.inHours}h';
    return '${delta.inDays}d';
  }
}
