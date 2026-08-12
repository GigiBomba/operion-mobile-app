import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../providers/analytics_providers.dart';

/// Shared loading/error/empty scaffolding for every analytics tab.
class AnalyticsSection<T> extends ConsumerWidget {
  const AnalyticsSection({
    super.key,
    required this.provider,
    required this.builder,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.hasData,
  });

  /// The provider to watch (an `AsyncValue<T>`).
  final AsyncValue<T> Function() provider;

  final Widget Function(BuildContext, WidgetRef, T) builder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;

  /// Whether the payload has usable data; null defaults to "always data".
  final bool Function(T)? hasData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = provider();
    return async.when(
      loading: () => const _SectionShimmer(),
      error: (err, _) => _SectionError(message: '$err'),
      data: (data) {
        final usable = hasData?.call(data) ?? true;
        if (!usable) {
          return EmptyState(
            icon: Icon(emptyIcon),
            title: emptyTitle,
            subtitle: emptySubtitle,
          );
        }
        return builder(context, ref, data);
      },
    );
  }
}

/// Shimmer placeholder for a chart tab.
class _SectionShimmer extends StatelessWidget {
  const _SectionShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: List.generate(
        4,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: ShimmerCard(),
        ),
      ),
    );
  }
}

/// Full-screen error state with a retry button.
class _SectionError extends ConsumerWidget {
  const _SectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () {
                // Invalidate all analytics providers for a full retry.
                ref.invalidate(analyticsRevenueProvider);
                ref.invalidate(analyticsFleetUtilizationProvider);
                ref.invalidate(analyticsDriverPerformanceProvider);
                ref.invalidate(analyticsInvoiceAgingProvider);
              },
              icon: const Icon(Icons.refresh),
              label: Text(context.loc.general_retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared error state used inside individual data builders.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(message, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Revenue tab
// ═══════════════════════════════════════════════════════════════════════════

enum _RevenueGroup { period, client, route }

class RevenueTab extends ConsumerWidget {
  const RevenueTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(analyticsDateRangeProvider);
    final async = ref.watch(
      analyticsRevenueProvider((range: range, clientId: null)),
    );
    final loc = context.loc;
    return async.when(
      loading: () => const _SectionShimmer(),
      error: (err, _) => _SectionError(message: '$err'),
      data: (data) {
        if (!data.hasData) {
          return EmptyState(
            icon: const Icon(Icons.show_chart),
            title: loc.analytics_noData,
            subtitle: loc.analytics_emptyHint,
          );
        }
        return _RevenueBody(data: data);
      },
    );
  }
}

class _RevenueBody extends ConsumerStatefulWidget {
  const _RevenueBody({required this.data});

  final RevenueAnalytics data;

  @override
  ConsumerState<_RevenueBody> createState() => _RevenueBodyState();
}

class _RevenueBodyState extends ConsumerState<_RevenueBody> {
  _RevenueGroup _group = _RevenueGroup.period;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        SegmentedButton<_RevenueGroup>(
          segments: [
            ButtonSegment(
              value: _RevenueGroup.period,
              label: Text(loc.analytics_groupByPeriod),
            ),
            ButtonSegment(
              value: _RevenueGroup.client,
              label: Text(loc.analytics_groupByClient),
            ),
            ButtonSegment(
              value: _RevenueGroup.route,
              label: Text(loc.analytics_groupByRoute),
            ),
          ],
          selected: {_group},
          onSelectionChanged: (set) => setState(() => _group = set.first),
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 6),
            ),
            textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_group == _RevenueGroup.period)
          _TrendChart(points: widget.data.trend)
        else if (_group == _RevenueGroup.client)
          _BarChartCard(
            title: loc.analytics_groupByClient,
            points: widget.data.perClient,
          )
        else
          _BarChartCard(
            title: loc.analytics_groupByRoute,
            points: widget.data.perRoute,
          ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SizedBox(
          height: 220,
          child: points.length < 2
              ? const Center(child: Text('—'))
              : LineChart(
                  LineChartData(
                    minY: 0,
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      topTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= points.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                points[idx].label,
                                style: const TextStyle(fontSize: 9),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < points.length; i++)
                            FlSpot(i.toDouble(), points[i].value),
                        ],
                        isCurved: true,
                        color: AppColors.chartColors[0],
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.chartColors[0].withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  const _BarChartCard({required this.title, required this.points});

  final String title;
  final List<ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 220,
              child: points.isEmpty
                  ? const Center(child: Text('—'))
                  : BarChart(
                      BarChartData(
                        maxY: points
                            .map((p) => p.value)
                            .fold<double>(1, (a, b) => a > b ? a : b),
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(
                          leftTitles: AxisTitles(),
                          rightTitles: AxisTitles(),
                          topTitles: AxisTitles(),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        barGroups: [
                          for (var i = 0; i < points.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: points[i].value,
                                  color: AppColors
                                      .chartColors[i % AppColors.chartColors.length],
                                  width: 18,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.label,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      p.value.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Fleet Utilization tab
// ═══════════════════════════════════════════════════════════════════════════

class FleetUtilizationTab extends ConsumerWidget {
  const FleetUtilizationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(analyticsDateRangeProvider);
    final async = ref.watch(analyticsFleetUtilizationProvider(range));
    final loc = context.loc;
    return async.when(
      loading: () => const _SectionShimmer(),
      error: (err, _) => _SectionError(message: '$err'),
      data: (data) {
        if (!data.hasData) {
          return EmptyState(
            icon: const Icon(Icons.local_shipping),
            title: loc.analytics_noData,
            subtitle: loc.analytics_emptyHint,
          );
        }
        return _FleetUtilizationBody(data: data);
      },
    );
  }
}

class _FleetUtilizationBody extends StatelessWidget {
  const _FleetUtilizationBody({required this.data});

  final FleetUtilizationAnalytics data;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final split = data.statusSplit;
    final active = split['active'] ?? 0;
    final maintenance = split['maintenance'] ?? 0;
    final decommissioned = split['decommissioned'] ?? 0;

    final slices = <PieChartSectionData>[
      if (active > 0)
        PieChartSectionData(
          value: active.toDouble(),
          title: '$active',
          color: AppColors.chartColors[0],
          radius: 44,
        ),
      if (maintenance > 0)
        PieChartSectionData(
          value: maintenance.toDouble(),
          title: '$maintenance',
          color: AppColors.chartColors[2],
          radius: 44,
        ),
      if (decommissioned > 0)
        PieChartSectionData(
          value: decommissioned.toDouble(),
          title: '$decommissioned',
          color: AppColors.chartColors[4],
          radius: 44,
        ),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  child: slices.isEmpty
                      ? const Center(child: Text('—'))
                      : PieChart(
                          PieChartData(
                            sections: slices,
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _LegendDot(
                      color: AppColors.chartColors[0],
                      label: loc.analytics_status_active,
                    ),
                    _LegendDot(
                      color: AppColors.chartColors[2],
                      label: loc.analytics_status_maintenance,
                    ),
                    _LegendDot(
                      color: AppColors.chartColors[4],
                      label: loc.analytics_status_decommissioned,
                    ),
                  ],
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
                Text(
                  loc.analytics_fleetUtilizationTab,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.md),
                if (data.trucks.isEmpty)
                  const _InlineError(message: '—')
                else
                  for (final truck in data.trucks) ...[
                    _TruckUtilRow(truck: truck),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            ),
          ),
        ),
      ],
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
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TruckUtilRow extends StatelessWidget {
  const _TruckUtilRow({required this.truck});

  final Map<String, dynamic> truck;

  @override
  Widget build(BuildContext context) {
    final label = truck['truck']?.toString() ?? '—';
    final trips = (truck['trip_count'] as num?)?.toInt() ?? 0;
    final totalKm = (truck['total_km'] as num?)?.toDouble() ?? 0;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$trips · ${totalKm.toStringAsFixed(0)} km',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Driver Performance tab
// ═══════════════════════════════════════════════════════════════════════════

enum _DriverSort { trips, onTime, profitPerKm, revenue }

class DriverPerformanceTab extends ConsumerStatefulWidget {
  const DriverPerformanceTab({super.key});

  @override
  ConsumerState<DriverPerformanceTab> createState() =>
      _DriverPerformanceTabState();
}

class _DriverPerformanceTabState extends ConsumerState<DriverPerformanceTab> {
  _DriverSort _sort = _DriverSort.trips;
  bool _ascending = false;

  void _sortBy(_DriverSort sort) {
    if (_sort == sort) {
      setState(() => _ascending = !_ascending);
    } else {
      setState(() {
        _sort = sort;
        _ascending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(analyticsDateRangeProvider);
    final async = ref.watch(analyticsDriverPerformanceProvider(range));
    final loc = context.loc;
    return async.when(
      loading: () => const _SectionShimmer(),
      error: (err, _) => _SectionError(message: '$err'),
      data: (rows) {
        if (rows.isEmpty) {
          return EmptyState(
            icon: const Icon(Icons.people_outline),
            title: loc.analytics_noData,
            subtitle: loc.analytics_emptyHint,
          );
        }
        final sorted = [...rows]..sort(_compare);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
            sortColumnIndex: _indexFor(_sort),
            sortAscending: _ascending,
            columns: [
              DataColumn(
                label: Text(loc.analytics_driverCol),
                onSort: (index, _) => _sortBy(_DriverSort.trips),
              ),
              DataColumn(
                label: Text(loc.analytics_tripsCol),
                numeric: true,
                onSort: (index, _) => _sortBy(_DriverSort.trips),
              ),
              DataColumn(
                label: Text(loc.analytics_otdCol),
                numeric: true,
                onSort: (index, _) => _sortBy(_DriverSort.onTime),
              ),
              DataColumn(
                label: Text(loc.analytics_profitPerKmCol),
                numeric: true,
                onSort: (index, _) => _sortBy(_DriverSort.profitPerKm),
              ),
              DataColumn(
                label: Text(loc.analytics_revenueCol),
                numeric: true,
                onSort: (index, _) => _sortBy(_DriverSort.revenue),
              ),
            ],
            rows: [
              for (final row in sorted)
                DataRow(cells: [
                  DataCell(Text(row.driver)),
                  DataCell(Text('${row.tripsCompleted}')),
                  DataCell(Text('${row.onTimePct.toStringAsFixed(1)}%')),
                  DataCell(Text(row.profitPerKm.toStringAsFixed(2))),
                  DataCell(Text(row.revenue.toStringAsFixed(0))),
                ]),
            ],
          ),
          ),
        );
      },
    );
  }

  int _indexFor(_DriverSort sort) => switch (sort) {
        _DriverSort.trips => 1,
        _DriverSort.onTime => 2,
        _DriverSort.profitPerKm => 3,
        _DriverSort.revenue => 4,
      };

  int _compare(DriverPerformanceRow a, DriverPerformanceRow b) {
    int result;
    switch (_sort) {
      case _DriverSort.trips:
        result = a.tripsCompleted.compareTo(b.tripsCompleted);
      case _DriverSort.onTime:
        result = a.onTimePct.compareTo(b.onTimePct);
      case _DriverSort.profitPerKm:
        result = a.profitPerKm.compareTo(b.profitPerKm);
      case _DriverSort.revenue:
        result = a.revenue.compareTo(b.revenue);
    }
    return _ascending ? result : -result;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Invoice Aging tab
// ═══════════════════════════════════════════════════════════════════════════

class InvoiceAgingTab extends ConsumerWidget {
  const InvoiceAgingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(analyticsInvoiceAgingProvider);
    final loc = context.loc;
    return async.when(
      loading: () => const _SectionShimmer(),
      error: (err, _) => _SectionError(message: '$err'),
      data: (report) {
        if (!report.hasData) {
          return EmptyState(
            icon: const Icon(Icons.receipt_long_outlined),
            title: loc.analytics_noData,
            subtitle: loc.analytics_emptyHint,
          );
        }
        return _InvoiceAgingBody(report: report);
      },
    );
  }
}

class _InvoiceAgingBody extends StatelessWidget {
  const _InvoiceAgingBody({required this.report});

  final InvoiceAgingReport report;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final buckets = [
      (loc.analytics_aging_current, report.current),
      (loc.analytics_aging_31_60, report.bucket31_60),
      (loc.analytics_aging_61_90, report.bucket61_90),
      (loc.analytics_aging_overdue, report.overdue),
    ];
    final maxY = buckets
        .map((b) => b.$2)
        .fold<double>(1, (a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                    topTitles: AxisTitles(),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: [
                    for (var i = 0; i < buckets.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: buckets[i].$2,
                            color: AppColors.chartColors[i],
                            width: 28,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final bucket in buckets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    bucket.$1,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  bucket.$2.toStringAsFixed(0),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    loc.analytics_aging_total,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  report.totalOutstanding.toStringAsFixed(0),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
