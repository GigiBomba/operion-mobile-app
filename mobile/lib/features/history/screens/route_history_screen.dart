import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/master_detail_layout.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../providers/history_providers.dart';

/// Route History screen (blueprint §4.8).
///
/// Same paginated list pattern as Trip History. Rows show a schematic route
/// thumbnail (`GET /mobile/history/routes/{route_id}/thumbnail`), name,
/// origin→destination, distance/duration and date. Thumbnails fall back to a
/// route-icon placeholder while loading or on 404/missing geometry (contract
/// §2 row 16). No duplicate/archive actions.
///
/// On tablet widths (≥600dp) the filters + list become the list pane of a
/// master-detail layout with the selected route as the detail pane (§9 item 5).
class RouteHistoryScreen extends ConsumerStatefulWidget {
  const RouteHistoryScreen({super.key, this.enableTabletLayout = true});

  final bool enableTabletLayout;

  @override
  ConsumerState<RouteHistoryScreen> createState() =>
      _RouteHistoryScreenState();
}

class _RouteHistoryScreenState extends ConsumerState<RouteHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int _page = 1;
  final List<RouteHistoryEntry> _accumulated = [];
  bool _reachedEnd = false;
  bool _loadingMore = false;
  int? _selectedRoute;

  RouteHistoryFilter get _filter => RouteHistoryFilter(
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
    ref.invalidate(routeHistoryProvider(_filter));
  }

  void _loadMore() {
    if (_reachedEnd || _loadingMore) return;
    final last = ref.read(routeHistoryProvider(_filter)).value;
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
        .read(routeHistoryProvider(next).future)
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

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final async = ref.watch(routeHistoryProvider(_filter));

    // Thumbnails are plain `Image.network` URLs: the endpoint exposes a path
    // and the caller applies the API base URL. `AppConstants.baseUrl` is the
    // same value `ApiClient` is created with, so no provider construction is
    // needed here (and tests that stub `routeHistoryProvider` directly keep
    // working without an ApiClient override).
    const thumbnailBase = AppConstants.baseUrl;

    final baseItems =
        async.valueOrNull?.items ?? const <RouteHistoryEntry>[];
    final combined = _accumulated.isEmpty ? baseItems : _accumulated;
    final tablet = widget.enableTabletLayout &&
        isTabletWidth(context) &&
        combined.isNotEmpty;

    final listWidget = async.when(
      loading: _page == 1 && _accumulated.isEmpty
          ? () => const _ListShimmer()
          : () => const SizedBox.shrink(),
      error: (err, _) => _buildError(context, err),
      data: (_) {
        if (combined.isEmpty) {
          return EmptyState(
            icon: const Icon(Icons.route_outlined),
            title: loc.history_emptyRoutes,
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            _resetAndReload();
            await ref.read(routeHistoryProvider(_filter).future);
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
              return _RouteRow(
                entry: combined[index],
                thumbnailUrl: '$thumbnailBase'
                    '${HistoryEndpoints.routeThumbnailUrl('${combined[index].id}')}',
                onTap: tablet
                    ? () => setState(() => _selectedRoute = index)
                    : null,
              );
            },
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(title: Text(loc.history_routeTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Row(
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
          ),
          Expanded(
            child: tablet
                ? MasterDetailLayout(
                    selectedIndex: _selectedRoute ?? 0,
                    listPane: listWidget,
                    detailBuilder: (context, index) => _RouteDetailPane(
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
            onPressed: () => ref.invalidate(routeHistoryProvider(_filter)),
            icon: const Icon(Icons.refresh),
            label: Text(loc.general_retry),
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.entry, required this.thumbnailUrl, this.onTap});

  final RouteHistoryEntry entry;
  final String thumbnailUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    final distance = entry.totalDistanceKm != null
        ? loc.history_distanceKm.replaceAll('{distance}',
            entry.totalDistanceKm!.toStringAsFixed(0))
        : null;
    final duration = entry.durationMin != null
        ? loc.history_durationMin
            .replaceAll('{duration}', '${entry.durationMin}')
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RouteThumbnail(url: thumbnailUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.name.isEmpty ? '—' : entry.name,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.createdAt != null)
                          Text(
                            DateFormat.yMMMd().format(entry.createdAt!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${entry.origin} → ${entry.destination}',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (distance != null || duration != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [distance, duration].whereType<String>().join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Route schematic thumbnail (~120×68) for a history row.
///
/// Loads the polyline PNG via `Image.network`; while loading or on failure it
/// falls back to a muted placeholder with the route icon so the row never
/// shows a broken-image slot.
class _RouteThumbnail extends StatelessWidget {
  const _RouteThumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.lgAll,
      child: SizedBox(
        width: 120,
        height: 68,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const _ThumbnailPlaceholder(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const _ThumbnailPlaceholder();
          },
        ),
      ),
    );
  }
}

/// Muted thumbnail fallback: route icon on a surface-variant tile.
class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(Icons.route_outlined, size: 24, color: AppColors.accent),
      ),
    );
  }
}

/// Read-only route summary shown as the tablet detail pane (§9 item 5).
class _RouteDetailPane extends StatelessWidget {
  const _RouteDetailPane({required this.entry});

  final RouteHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final distance = entry.totalDistanceKm != null
        ? loc.history_distanceKm.replaceAll('{distance}',
            entry.totalDistanceKm!.toStringAsFixed(0))
        : '—';
    final duration = entry.durationMin != null
        ? loc.history_durationMin
            .replaceAll('{duration}', '${entry.durationMin}')
        : '—';
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(loc.history_routeDetails, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.route_outlined,
                        size: 16, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        entry.name.isEmpty ? '—' : entry.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _RouteDetailLine(
                  label: loc.history_routeTitle,
                  value: '${entry.origin} → ${entry.destination}',
                ),
                const SizedBox(height: AppSpacing.xs),
                _RouteDetailLine(
                  label: loc.history_distanceKm
                      .replaceAll('{distance}', ''),
                  value: distance,
                ),
                const SizedBox(height: AppSpacing.xs),
                _RouteDetailLine(
                  label: loc.history_durationMin
                      .replaceAll('{duration}', ''),
                  value: duration,
                ),
                if (entry.createdAt != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _RouteDetailLine(
                    label: loc.history_dateFrom,
                    value: DateFormat.yMMMd().format(entry.createdAt!),
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

class _RouteDetailLine extends StatelessWidget {
  const _RouteDetailLine({required this.label, required this.value});

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
