import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/analytics_providers.dart';
import '../widgets/date_range_selector.dart';
import 'analytics_tabs.dart';

/// Analytics screen (blueprint §4.4): four tabs driven by a shared date range.
///
/// - Revenue: line chart (trend) + bar chart (per-client/per-route toggle).
/// - Fleet Utilization: pie chart (status split) + per-truck rows.
/// - Driver Performance: sortable data table (no rating column — the real
///   backend has none).
/// - Invoice Aging: bar chart of the four real buckets.
///
/// Export (AppBar share icon) calls the sync export endpoint and opens the OS
/// share sheet with the signed URL. Offline the export is disabled with an
/// inline message — exports are never queued (§7).
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Maps the active tab index to the backend `report` parameter (§6.4).
  static String _reportForTab(int index) => switch (index) {
        0 => 'revenue',
        1 => 'fleet',
        2 => 'drivers',
        _ => 'invoice_aging',
      };

  Future<void> _export() async {
    final range = ref.read(analyticsDateRangeProvider);
    final report = _reportForTab(_tabController.index);
    if (ref.read(isOfflineProvider)) {
      _showMessage(context.loc.analytics_exportOffline);
      return;
    }
    setState(() => _exporting = true);
    try {
      final result = await ref
          .read(analyticsExportProvider((range: range, report: report)).future);
      await Share.share(result.downloadUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.analytics_exportStarted)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.analytics_exportError)),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final offline = ref.watch(isOfflineProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.nav_analytics),
        actions: [
          if (offline)
            Tooltip(
              message: loc.analytics_exportOffline,
              child: const Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: Icon(
                  Icons.ios_share,
                  color: Colors.grey,
                  semanticLabel: 'export-offline',
                ),
              ),
            )
          else
            IconButton(
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              tooltip: loc.analytics_export,
              onPressed: _exporting ? null : _export,
            ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: DateRangeSelector(),
          ),
          if (offline)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                loc.analytics_exportOffline,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                RevenueTab(),
                FleetUtilizationTab(),
                DriverPerformanceTab(),
                InvoiceAgingTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        dividerHeight: 0,
        tabs: const [
          _AnalyticsTabLabel(index: 0),
          _AnalyticsTabLabel(index: 1),
          _AnalyticsTabLabel(index: 2),
          _AnalyticsTabLabel(index: 3),
        ],
      ),
    );
  }
}

class _AnalyticsTabLabel extends StatelessWidget {
  const _AnalyticsTabLabel({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final label = switch (index) {
      0 => loc.analytics_revenueTab,
      1 => loc.analytics_fleetUtilizationTab,
      2 => loc.analytics_driverPerformanceTab,
      _ => loc.analytics_invoiceAgingTab,
    };
    return Tab(text: label);
  }
}
