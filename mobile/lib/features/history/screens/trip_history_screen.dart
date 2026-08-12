import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/sync/wifi_gate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/master_detail_layout.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../providers/history_providers.dart';

/// Trip History screen (blueprint §4.8).
///
/// Filterable (status / date range / client) paginated list with pull-to-
/// refresh and infinite scroll (20 per page). Export triggers the async
/// export job, polls status, and opens the OS share sheet on completion.
/// Exports are never queued offline — the button is disabled with an inline
/// message.
///
/// On tablet widths (≥600dp) the filters + list become the list pane of a
/// master-detail layout with the selected trip as the detail pane (§9 item 5).
class TripHistoryScreen extends ConsumerStatefulWidget {
  const TripHistoryScreen({super.key, this.enableTabletLayout = true});

  final bool enableTabletLayout;

  @override
  ConsumerState<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends ConsumerState<TripHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _status;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int _page = 1;
  final List<TripHistoryEntry> _accumulated = [];
  bool _reachedEnd = false;
  bool _loadingMore = false;
  String? _activeJobId;
  int? _selectedTrip;

  static const _statusOptions = [
    'Planned',
    'Loading',
    'In Transit',
    'Delivered',
    'Invoiced',
    'Paid',
    'Cancelled',
  ];

  TripHistoryFilter get _filter => TripHistoryFilter(
        status: _status,
        startDate: _dateFrom,
        endDate: _dateTo,
        page: _page,
        pageSize: 20,
      );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _resetAndReload() {
    setState(() {
      _page = 1;
      _accumulated.clear();
      _reachedEnd = false;
    });
    ref.invalidate(tripHistoryProvider(_filter));
  }

  void _loadMore() {
    if (_reachedEnd || _loadingMore) return;
    final last = ref.read(tripHistoryProvider(_filter)).value;
    if (last == null) return;
    final nextPage = _page + 1;
    if (nextPage > last.totalPages) {
      setState(() => _reachedEnd = true);
      return;
    }
    setState(() {
      _page = nextPage;
      _loadingMore = true;
    });
    final next = _filter.copyWith(page: nextPage);
    ref
        .read(tripHistoryProvider(next).future)
        .then((page) {
          if (!mounted) return;
          setState(() {
            _accumulated.addAll(page.items);
            _loadingMore = false;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _loadingMore = false);
        });
  }

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? now.subtract(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now,
      helpText: context.loc.history_dateFrom,
    );
    if (picked != null) {
      _dateFrom = picked;
      _resetAndReload();
    }
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? now,
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now,
      helpText: context.loc.history_dateTo,
    );
    if (picked != null) {
      _dateTo = picked;
      _resetAndReload();
    }
  }

  Future<void> _export() async {
    final loc = context.loc;
    if (ref.read(isOfflineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.history_exportOffline)),
      );
      return;
    }
    final request = TripExportRequest(
      status: _status,
      startDate: _dateFrom,
      endDate: _dateTo,
    );
    try {
      final jobId = await ref.read(tripHistoryExportProvider(request).future);
      if (!mounted) return;
      setState(() => _activeJobId = jobId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.history_exportStarted)),
      );
    } on WifiGateBlocked {
      // Phase 4B §4.10: Wi-Fi-only is on and the device is on cellular.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.wifi_only_message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.history_exportFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final offline = ref.watch(isOfflineProvider);
    final async = ref.watch(tripHistoryProvider(_filter));

    final baseItems =
        async.valueOrNull?.items ?? const <TripHistoryEntry>[];
    final combined = _accumulated.isEmpty ? baseItems : _accumulated;
    final tablet = widget.enableTabletLayout &&
        isTabletWidth(context) &&
        combined.isNotEmpty;

    // React to export-job polling: terminal states drive the share sheet.
    if (_activeJobId != null) {
      ref.listen(exportJobStatusProvider(_activeJobId!), (prev, next) {
        final state = next.valueOrNull;
        if (state == null || !state.isTerminal || !mounted) return;
        if (state.status == ExportJobStatus.success &&
            state.downloadUrl != null) {
          Share.share(state.downloadUrl!);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.history_exportReady)),
          );
          setState(() => _activeJobId = null);
        } else if (state.status == ExportJobStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.history_exportFailed)),
          );
          setState(() => _activeJobId = null);
        }
      });
    }

    final listWidget = async.when(
      loading: _page == 1 && _accumulated.isEmpty
          ? () => const _ListShimmer()
          : () => const SizedBox.shrink(),
      error: (err, _) => _buildError(context, err),
      data: (_) {
        if (combined.isEmpty) {
          return EmptyState(
            icon: const Icon(Icons.history),
            title: loc.history_emptyTrips,
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            _resetAndReload();
            await ref.read(tripHistoryProvider(_filter).future);
          },
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.md,
              bottom: AppSpacing.xxl,
            ),
            itemCount: combined.length + 1,
            itemBuilder: (context, index) {
              if (index == combined.length) {
                if (_reachedEnd) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Center(
                      child: Text(
                        loc.history_noMore,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  );
                }
                if (_loadingMore) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return const SizedBox.shrink();
              }
              return _TripRow(
                entry: combined[index],
                onTap: tablet
                    ? () => setState(() => _selectedTrip = index)
                    : null,
              );
            },
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.history_tripTitle),
        actions: [
          if (offline)
            Tooltip(
              message: loc.history_exportOffline,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Icon(Icons.download_outlined, color: Colors.grey),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: loc.history_export,
              onPressed: _activeJobId == null ? _export : null,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(context),
          if (offline)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                loc.history_exportOffline,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (_activeJobId != null) _buildExportStatus(context),
          Expanded(
            child: tablet
                ? MasterDetailLayout(
                    selectedIndex: _selectedTrip ?? 0,
                    listPane: listWidget,
                    detailBuilder: (context, index) => _TripDetailPane(
                      entry:
                          combined[index.clamp(0, combined.length - 1)],
                    ),
                  )
                : listWidget,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final loc = context.loc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statusOptions.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ChoiceChip(
                    label: Text(loc.dispatcher_all),
                    selected: _status == null,
                    onSelected: (_) {
                      _status = null;
                      _resetAndReload();
                    },
                  );
                }
                final status = _statusOptions[index - 1];
                return ChoiceChip(
                  label: Text(status),
                  selected: _status == status,
                  onSelected: (_) {
                    _status = status;
                    _resetAndReload();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: loc.history_dateFrom,
                  value: _dateFrom,
                  onTap: _pickFrom,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _DateField(
                  label: loc.history_dateTo,
                  value: _dateTo,
                  onTap: _pickTo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportStatus(BuildContext context) {
    final loc = context.loc;
    final jobId = _activeJobId!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              loc.history_exportPolling,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(exportJobStatusProvider(jobId)),
            child: Text(loc.general_retry),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    final loc = context.loc;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () => ref.invalidate(tripHistoryProvider(_filter)),
            icon: const Icon(Icons.refresh),
            label: Text(loc.general_retry),
          ),
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.entry, this.onTap});

  final TripHistoryEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.clientName.isEmpty ? '—' : entry.clientName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(status: entry.status),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${entry.origin} → ${entry.destination}',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (entry.truckNumber.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${entry.truckNumber} · ${entry.driverName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            if (entry.startDate != null || entry.totalPriceEur != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  if (entry.startDate != null)
                    DateFormat.yMMMd().format(entry.startDate!),
                  if (entry.totalPriceEur != null)
                    '€ ${entry.totalPriceEur!.toStringAsFixed(0)}',
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

/// Read-only trip summary shown as the tablet detail pane (§9 item 5).
class _TripDetailPane extends StatelessWidget {
  const _TripDetailPane({required this.entry});

  final TripHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(loc.history_tripDetails, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.clientName.isEmpty ? '—' : entry.clientName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _StatusBadge(status: entry.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailLine(
                  label: loc.history_routeTitle,
                  value: '${entry.origin} → ${entry.destination}',
                ),
                if (entry.truckNumber.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _DetailLine(
                    label: loc.nav_fleet,
                    value: '${entry.truckNumber} · ${entry.driverName}',
                  ),
                ],
                if (entry.startDate != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _DetailLine(
                    label: loc.history_dateFrom,
                    value: DateFormat.yMMMd().format(entry.startDate!),
                  ),
                ],
                if (entry.endDate != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _DetailLine(
                    label: loc.history_dateTo,
                    value: DateFormat.yMMMd().format(entry.endDate!),
                  ),
                ],
                if (entry.distanceKm != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _DetailLine(
                    label: loc.history_distanceKm
                        .replaceAll('{distance}', ''),
                    value:
                        '${entry.distanceKm!.toStringAsFixed(0)} km',
                  ),
                ],
                if (entry.totalPriceEur != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _DetailLine(
                    label: loc.invoicing_total,
                    value: '€ ${entry.totalPriceEur!.toStringAsFixed(0)}',
                  ),
                ],
                if (entry.netProfit != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _DetailLine(
                    label: loc.history_netProfit,
                    value: '€ ${entry.netProfit!.toStringAsFixed(0)}',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Delivered' || 'Paid' => AppColors.success,
      'Cancelled' => AppColors.error,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        status.isEmpty ? '—' : status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Tappable date field (local_download pattern).
class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: AppRadius.lgAll,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 14),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                value == null ? '—' : DateFormat.yMMMd().format(value!),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListShimmer extends StatelessWidget {
  const _ListShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: List.generate(6, (_) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: ShimmerCard(),
      )),
    );
  }
}
