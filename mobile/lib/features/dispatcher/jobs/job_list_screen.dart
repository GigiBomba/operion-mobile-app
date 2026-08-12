import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../global_search/screens/global_search_screen.dart';
import '../home/dispatcher_providers.dart';
import 'job_detail_screen.dart';
import 'job_providers.dart';

/// View-mode selector for the dispatch board (§2 parity).
enum ViewMode {
  /// Classic filterable list.
  list,

  /// 4-column drag-and-drop board (Planned / Loading / In Transit / Delivered).
  kanban,

  /// Per-truck timeline positioned by start/end dates.
  timeline,
}

/// Kanban columns. [status] is the canonical backend display status sent to
/// `PATCH /api/v1/mobile/transports/{id}/status`.
enum KanbanColumn {
  planned('Planned'),
  loading('Loading'),
  inTransit('In Transit'),
  delivered('Delivered');

  final String status;

  const KanbanColumn(this.status);
}

/// Maps a mobile job status string to a [KanbanColumn] defensively.
///
/// Normalises whitespace/underscores and case before matching; unknown
/// statuses fall back to [KanbanColumn.planned] so the board never drops a
/// job. Delivered-terminal aliases (`completed`, `done`, `paid`) all map to
/// the Delivered column.
KanbanColumn kanbanColumnForStatus(String status) {
  final normalized =
      status.trim().toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
  switch (normalized) {
    case 'planned':
    case 'pending':
    case 'scheduled':
      return KanbanColumn.planned;
    case 'loading':
      return KanbanColumn.loading;
    case 'in transit':
    case 'intransit':
      return KanbanColumn.inTransit;
    case 'delivered':
    case 'completed':
    case 'done':
    case 'paid':
      return KanbanColumn.delivered;
    default:
      return KanbanColumn.planned;
  }
}

/// Filter options for the job list.
enum JobFilter {
  /// Show all jobs regardless of status.
  all,

  /// Jobs awaiting approval (`pending` status key).
  pending,

  /// Filter by `in_transit` status.
  inTransit,

  /// Filter by `loading` status.
  loading,

  /// Filter by `overdue` status.
  delayed,
}

/// Maps a [JobFilter] to its corresponding API status key.
/// Returns `null` for [JobFilter.all] meaning no filter is applied.
String? _statusKeyForFilter(JobFilter filter) {
  switch (filter) {
    case JobFilter.all:
      return null;
    case JobFilter.pending:
      return 'pending';
    case JobFilter.inTransit:
      return 'in_transit';
    case JobFilter.loading:
      return 'loading';
    case JobFilter.delayed:
      return 'overdue';
  }
}

/// Returns the localised label for a given filter.
String _filterLabel(JobFilter filter, AppLocalizations loc) {
  switch (filter) {
    case JobFilter.all:
      return loc.dispatcher_all;
    case JobFilter.pending:
      return loc.jobs_pending;
    case JobFilter.inTransit:
      return loc.transport_status_in_transit;
    case JobFilter.loading:
      return loc.transport_status_loading;
    case JobFilter.delayed:
      return loc.transport_status_overdue;
  }
}

/// Localised label for a [KanbanColumn].
String _kanbanColumnLabel(KanbanColumn column, AppLocalizations loc) {
  switch (column) {
    case KanbanColumn.planned:
      return loc.transport_status_planned;
    case KanbanColumn.loading:
      return loc.transport_status_loading;
    case KanbanColumn.inTransit:
      return loc.transport_status_in_transit;
    case KanbanColumn.delivered:
      return loc.transport_status_delivered;
  }
}

/// A pending (optimistic) Kanban move awaiting the undo window.
class _PendingMove {
  final int jobId;
  final KanbanColumn fromColumn;
  final KanbanColumn toColumn;

  const _PendingMove({
    required this.jobId,
    required this.fromColumn,
    required this.toColumn,
  });
}

/// Full-screen dispatcher jobs board with list / kanban / timeline views.
///
/// List mode keeps the classic [ChoiceChip] filters; Kanban refetches with the
/// §2 `statuses` param (`Planned,Loading,In Transit,Delivered`) so Delivered
/// jobs are included, and supports long-press → drag → drop with a 4-second
/// undo window (the status PATCH fires only after the window elapses).
class JobListScreen extends ConsumerStatefulWidget {
  const JobListScreen({super.key, this.initialFilter = JobFilter.all});

  /// The filter pre-applied when the screen opens (used by the
  /// `approve_pending` quick action to land on the pending-jobs view).
  final JobFilter initialFilter;

  @override
  ConsumerState<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends ConsumerState<JobListScreen> {
  late JobFilter _selectedFilter = widget.initialFilter;
  ViewMode _viewMode = ViewMode.list;

  /// Kanban statuses sent to the backend — Delivered included.
  static const _kanbanStatuses = [
    'Planned',
    'Loading',
    'In Transit',
    'Delivered',
  ];

  /// Optimistic column overrides: job id → target column status string.
  final Map<int, String> _kanbanOverrides = {};

  _PendingMove? _pendingMove;
  Timer? _undoTimer;

  /// Undo window — the PATCH fires only after this elapses.
  static const _undoWindow = Duration(seconds: 4);

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  // ── View switching ───────────────────────────────────────────────

  void _switchView(ViewMode mode) {
    _cancelPendingMove();
    setState(() => _viewMode = mode);
  }

  void _cancelPendingMove() {
    _undoTimer?.cancel();
    _undoTimer = null;
    final pending = _pendingMove;
    _pendingMove = null;
    if (pending != null) {
      setState(() => _kanbanOverrides.remove(pending.jobId));
    }
  }

  // ── Kanban move / undo semantics ─────────────────────────────────

  int _jobIdOf(Map<String, dynamic> job) {
    final id = job['id'];
    return id is int ? id : (id is String ? int.tryParse(id) ?? 0 : 0);
  }

  KanbanColumn _effectiveColumn(Map<String, dynamic> job) {
    final override = _kanbanOverrides[_jobIdOf(job)];
    if (override != null) return kanbanColumnForStatus(override);
    return kanbanColumnForStatus(job['status'] as String? ?? '');
  }

  List<Map<String, dynamic>> _jobsForColumn(
    List<Map<String, dynamic>> jobs,
    KanbanColumn column,
  ) {
    return jobs.where((job) => _effectiveColumn(job) == column).toList();
  }

  /// Called when a job card is dropped on [target].
  void _onDrop(Map<String, dynamic> job, KanbanColumn target) {
    final jobId = _jobIdOf(job);
    final source = _effectiveColumn(job);
    if (source == target) return;
    if (jobId == 0) return; // Unparseable id — never issue a blind PATCH.

    _undoTimer?.cancel();
    _pendingMove = _PendingMove(
      jobId: jobId,
      fromColumn: source,
      toColumn: target,
    );
    setState(() => _kanbanOverrides[jobId] = target.status);

    final loc = context.loc;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${loc.jobs_moved}: ${_kanbanColumnLabel(target, loc)}',
        ),
        behavior: SnackBarBehavior.floating,
        duration: _undoWindow,
        action: SnackBarAction(
          label: loc.jobs_undo,
          onPressed: _undoMove,
        ),
      ),
    );

    // The API call fires ONLY after the undo window elapses.
    _undoTimer = Timer(_undoWindow, _commitMove);
  }

  void _undoMove() {
    _undoTimer?.cancel();
    _undoTimer = null;
    final pending = _pendingMove;
    _pendingMove = null;
    if (pending == null) return;
    setState(() => _kanbanOverrides.remove(pending.jobId));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Commits the pending move — issues the transport-status PATCH.
  Future<void> _commitMove() async {
    final pending = _pendingMove;
    _pendingMove = null;
    _undoTimer = null;
    if (pending == null) return;

    final loc = context.loc;
    try {
      await ref
          .read(dispatcherEndpointsProvider)
          .updateTransportStatus('${pending.jobId}', pending.toColumn.status);
      if (!mounted) return;
      // Server is authoritative now; refetch the board (also drops stale
      // overrides that match the new server status).
      ref.invalidate(dispatcherJobsWithStatusesProvider(_kanbanStatuses));
    } catch (_) {
      if (!mounted) return;
      // Revert the optimistic move on failure.
      setState(() => _kanbanOverrides.remove(pending.jobId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.jobs_moveFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(dispatcherJobsProvider);
    final kanbanAsync = ref.watch(
      dispatcherJobsWithStatusesProvider(_kanbanStatuses),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.nav_jobs),
        centerTitle: true,
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ViewMode>(
                segments: [
                  ButtonSegment<ViewMode>(
                    value: ViewMode.list,
                    icon: const Icon(LucideIcons.list, size: 16),
                    label: Text(context.loc.jobs_viewList),
                  ),
                  ButtonSegment<ViewMode>(
                    value: ViewMode.kanban,
                    icon: const Icon(LucideIcons.columns3, size: 16),
                    label: Text(context.loc.jobs_viewKanban),
                  ),
                  ButtonSegment<ViewMode>(
                    value: ViewMode.timeline,
                    icon: const Icon(LucideIcons.clock4, size: 16),
                    label: Text(context.loc.jobs_viewTimeline),
                  ),
                ],
                selected: {_viewMode},
                onSelectionChanged: (selection) =>
                    _switchView(selection.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
                ),
              ),
            ),
          ),
        ),
      ),
      body: switch (_viewMode) {
        ViewMode.list => _buildListView(jobsAsync, context, ref),
        ViewMode.kanban => _buildKanbanView(kanbanAsync, context, ref),
        ViewMode.timeline => _buildTimelineView(jobsAsync, context, ref),
      },
    );
  }

  // ── List view ────────────────────────────────────────────────────

  Widget _buildListView(
    AsyncValue<List<Map<String, dynamic>>> jobsAsync,
    BuildContext context,
    WidgetRef ref,
  ) {
    return jobsAsync.when(
      loading: () => _buildLoadingShimmer(context),
      error: (error, stack) => _buildError(context, ref, error),
      data: (jobs) {
        final filtered = _applyFilter(jobs, _selectedFilter);
        return Column(
          children: [
            _buildFilterChips(context),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmpty(context)
                  : _buildList(context, ref, filtered),
            ),
          ],
        );
      },
    );
  }

  /// Filters the [jobs] list by the currently selected [_selectedFilter].
  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> jobs,
    JobFilter filter,
  ) {
    final statusKey = _statusKeyForFilter(filter);
    if (statusKey == null) return jobs;
    return jobs.where((j) => j['status'] == statusKey).toList();
  }

  // ── Kanban view ──────────────────────────────────────────────────

  Widget _buildKanbanView(
    AsyncValue<List<Map<String, dynamic>>> jobsAsync,
    BuildContext context,
    WidgetRef ref,
  ) {
    final loc = context.loc;
    return jobsAsync.when(
      loading: () => _buildLoadingShimmer(context),
      error: (error, stack) => _buildError(context, ref, error),
      data: (jobs) {
        if (jobs.isEmpty) return _buildEmpty(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(
                loc.jobs_kanbanHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
            ),
            Expanded(
              // Horizontal scrollable row — all four columns are always
              // built (unlike a lazy PageView), which also keeps the column
              // grouping testable.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final column in KanbanColumn.values)
                      _KanbanColumnView(
                        column: column,
                        columnLabel: _kanbanColumnLabel(column, loc),
                        jobs: _jobsForColumn(jobs, column),
                        onDrop: (job) => _onDrop(job, column),
                        onJobTap: (job) => _openDetail(
                          context,
                          _jobIdOf(job),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Timeline view ────────────────────────────────────────────────

  Widget _buildTimelineView(
    AsyncValue<List<Map<String, dynamic>>> jobsAsync,
    BuildContext context,
    WidgetRef ref,
  ) {
    final loc = context.loc;
    return jobsAsync.when(
      loading: () => _buildLoadingShimmer(context),
      error: (error, stack) => _buildError(context, ref, error),
      data: (jobs) {
        // Group jobs by vehicle_plate (fallback group for jobs without one).
        const noVehicle = '__no_vehicle__';
        final groups = <String, List<Map<String, dynamic>>>{};
        for (final job in jobs) {
          final plate = (job['vehicle_plate'] as String? ?? '').trim();
          final key = plate.isEmpty ? noVehicle : plate;
          groups.putIfAbsent(key, () => []).add(job);
        }

        // Global time window across all dated jobs for proportional layout.
        final dated = jobs
            .map(_JobDates.fromJob)
            .where((d) => d.hasDates)
            .toList();
        final hasAnyDates = dated.isNotEmpty;

        final sortedKeys = groups.keys.toList()
          ..sort((a, b) => a == noVehicle ? 1 : (b == noVehicle ? -1 : a.compareTo(b)));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dispatcherJobsProvider);
            await ref.read(dispatcherJobsProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (!hasAnyDates)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    loc.jobs_timelineNoDates,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ),
              for (final key in sortedKeys) ...[
                _TimelineRow(
                  plate: key == noVehicle ? loc.jobs_timelineUnassigned : key,
                  jobs: groups[key]!,
                  hasAnyDates: hasAnyDates,
                  onJobTap: (job) => _openDetail(context, _jobIdOf(job)),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: AppSpacing.xhuge),
            ],
          ),
        );
      },
    );
  }

  // ── Filter chips (list mode) ─────────────────────────────────────

  /// Horizontal row of [ChoiceChip] widgets for status filtering.
  Widget _buildFilterChips(BuildContext context) {
    final loc = context.loc;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: JobFilter.values.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(_filterLabel(filter, loc)),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedFilter = filter),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Loading / Error / Empty ──────────────────────────────────────

  /// Shimmer skeleton list (5 cards).
  Widget _buildLoadingShimmer(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => const ShimmerCard(),
    );
  }

  /// Centered error panel with retry button.
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
              onPressed: () {
                if (_viewMode == ViewMode.kanban) {
                  ref.invalidate(
                    dispatcherJobsWithStatusesProvider(_kanbanStatuses),
                  );
                } else {
                  ref.invalidate(dispatcherJobsProvider);
                }
              },
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: Text(loc.general_retry),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty state when no jobs match the current filter.
  Widget _buildEmpty(BuildContext context) {
    final loc = context.loc;
    return EmptyState(
      icon: const Icon(LucideIcons.clipboardList),
      title: loc.dispatcher_noJobs,
      subtitle: _selectedFilter != JobFilter.all ? loc.general_retry : null,
    );
  }

  // ── List ─────────────────────────────────────────────────────────

  /// Pull-to-refresh list of job cards.
  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> jobs,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dispatcherJobsProvider);
        await ref.read(dispatcherJobsProvider.future);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xhuge,
        ),
        itemCount: jobs.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final job = jobs[index];
          return _JobCard(
            job: job,
            onTap: () => _openDetail(context, _jobIdOf(job)),
          );
        },
      ),
    );
  }

  void _openDetail(BuildContext context, int jobId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(jobId: jobId),
      ),
    );
  }
}

/// Start/end dates of a job, parsed defensively (§2 contract).
class _JobDates {
  final DateTime? start;
  final DateTime? end;

  const _JobDates(this.start, this.end);

  factory _JobDates.fromJob(Map<String, dynamic> job) {
    final startRaw = job['start_date'];
    final endRaw = job['end_date'];
    return _JobDates(
      startRaw is String ? DateTime.tryParse(startRaw) : null,
      endRaw is String ? DateTime.tryParse(endRaw) : null,
    );
  }

  bool get hasDates => start != null;
}

/// One truck row in the timeline: plate label + proportional date blocks.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.plate,
    required this.jobs,
    required this.hasAnyDates,
    required this.onJobTap,
  });

  final String plate;
  final List<Map<String, dynamic>> jobs;
  final bool hasAnyDates;
  final ValueChanged<Map<String, dynamic>> onJobTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Global window for proportional positioning (computed from all dated
    // jobs across rows; approximated here from this row's own dates).
    final dated = jobs
        .map(_JobDates.fromJob)
        .where((d) => d.hasDates)
        .toList();
    final minStart = dated
        .map((d) => d.start!)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final maxEnd = dated
        .map((d) => d.end ?? d.start!)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final totalMs =
        maxEnd.difference(minStart).inMilliseconds.clamp(1, 1 << 62);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.truck, size: 14, color: AppColors.info),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                plate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${jobs.length}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 34,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                children: [
                  // Lane background
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  for (final job in jobs) _buildBlock(job, minStart, maxEnd, totalMs, width),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBlock(
    Map<String, dynamic> job,
    DateTime minStart,
    DateTime maxEnd,
    int totalMs,
    double width,
  ) {
    final dates = _JobDates.fromJob(job);
    final loadInfo = (job['load_info'] as String? ?? '').isNotEmpty
        ? (job['load_info'] as String)
        : '${job['origin'] ?? ''} → ${job['destination'] ?? ''}';

    if (!dates.hasDates) {
      // No dates — zero-width marker at the left edge (documented).
      return Positioned(
        left: 0,
        top: 2,
        bottom: 2,
        child: Tooltip(
          message: loadInfo,
          child: Container(
            width: 2,
            decoration: BoxDecoration(
              color: AppColors.neutralText,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      );
    }

    final start = dates.start!;
    final end = dates.end ?? start;
    final left = start.difference(minStart).inMilliseconds / totalMs * width;
    final blockWidth =
        (end.difference(start).inMilliseconds / totalMs * width).clamp(6.0, width - left);

    return Positioned(
      left: left,
      top: 2,
      bottom: 2,
      child: GestureDetector(
        onTap: () => onJobTap(job),
        child: Tooltip(
          message: loadInfo,
          child: Container(
            width: blockWidth,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: AppColors.chartColors[0].withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              loadInfo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Kanban widgets
// ═════════════════════════════════════════════════════════════════════════════

/// Drag payload for a Kanban job card.
class _KanbanDragData {
  final Map<String, dynamic> job;

  const _KanbanDragData(this.job);
}

/// A single Kanban column: header with count + [DragTarget] list of cards.
class _KanbanColumnView extends StatelessWidget {
  const _KanbanColumnView({
    required this.column,
    required this.columnLabel,
    required this.jobs,
    required this.onDrop,
    required this.onJobTap,
  });

  final KanbanColumn column;
  final String columnLabel;
  final List<Map<String, dynamic>> jobs;
  final ValueChanged<Map<String, dynamic>> onDrop;
  final ValueChanged<Map<String, dynamic>> onJobTap;

  /// Fixed column width so the horizontal-scroll row stays usable on phones.
  static const double width = 280;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Row(
                children: [
                  Text(
                    columnLabel,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${jobs.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: DragTarget<_KanbanDragData>(
                key: ValueKey('kanban_drop_${column.status}'),
                onWillAcceptWithDetails: (details) =>
                    _effective(details.data) != column,
                onAcceptWithDetails: (details) => onDrop(details.data.job),
                builder: (context, candidateData, rejectedData) {
                  final highlighted = candidateData.isNotEmpty;
                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: highlighted ? 0.5 : 0.3),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: highlighted
                          ? Border.all(color: AppColors.accent, width: 2)
                          : Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.15),
                            ),
                    ),
                    child: jobs.isEmpty
                        ? Center(
                            child: Text(
                              context.loc.jobs_kanbanEmpty,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            itemCount: jobs.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.xs),
                            itemBuilder: (context, index) {
                              final job = jobs[index];
                              return LongPressDraggable<_KanbanDragData>(
                                data: _KanbanDragData(job),
                                // The overlay gives the feedback unbounded
                                // width; bound it so the card's Expanded rows
                                // can lay out.
                                feedback: SizedBox(
                                  width: _KanbanColumnView.width - 16,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: _CompactJobCard(
                                      job: job,
                                      compact: true,
                                      onTap: () {},
                                    ),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.35,
                                  child: _CompactJobCard(
                                    job: job,
                                    compact: true,
                                    onTap: () => onJobTap(job),
                                  ),
                                ),
                                child: _CompactJobCard(
                                  job: job,
                                  compact: true,
                                  onTap: () => onJobTap(job),
                                ),
                              );
                            },
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static KanbanColumn _effective(_KanbanDragData data) {
    final status = data.job['status'] as String? ?? '';
    return kanbanColumnForStatus(status);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Job cards
// ═════════════════════════════════════════════════════════════════════════════

/// A single job card in the dispatcher job list.
///
/// Displays load info, origin → destination, driver + vehicle plate,
/// status badge, and last-updated timestamp.
class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.onTap,
  });

  /// The job data map. Expected keys:
  /// `id`, `load_info`, `driver_name`, `vehicle_plate`, `status`, `origin`,
  /// `destination`, `last_updated`.
  final Map<String, dynamic> job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final loadInfo = (job['load_info'] as String?) ?? '';
    final origin = (job['origin'] as String?) ?? '';
    final destination = (job['destination'] as String?) ?? '';
    final driverName = (job['driver_name'] as String?) ?? '';
    final vehiclePlate = (job['vehicle_plate'] as String?) ?? '';
    final status = (job['status'] as String?) ?? '';
    final lastUpdated = job['last_updated'] as String?;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: load info + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  loadInfo,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(statusKey: status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Origin → Destination
          Row(
            children: [
              Icon(
                LucideIcons.arrowRightLeft,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${_abbreviate(origin)} → ${_abbreviate(destination)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Bottom row: driver name + vehicle plate + last updated
          Row(
            children: [
              if (driverName.isNotEmpty) ...[
                Icon(
                  LucideIcons.user,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    driverName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              if (vehiclePlate.isNotEmpty) ...[
                Icon(
                  LucideIcons.truck,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  vehiclePlate,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
              const Spacer(),
              if (lastUpdated != null && lastUpdated.isNotEmpty)
                Text(
                  _formatTimestamp(lastUpdated),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shorten a location string to a city-level portion (before first comma
  /// or pipe).
  String _abbreviate(String location) {
    if (location.isEmpty) return location;
    const separators = [',', '|', ' - ', ' – '];
    for (final sep in separators) {
      final idx = location.indexOf(sep);
      if (idx > 0) return location.substring(0, idx).trim();
    }
    return location.length > 25
        ? '${location.substring(0, 22)}...'
        : location;
  }

  /// Formats an ISO-8601 timestamp into a short relative string.
  String _formatTimestamp(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '';
    final delta = DateTime.now().difference(date);
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m';
    if (delta.inHours < 24) return '${delta.inHours}h';
    return '${delta.inDays}d';
  }
}

/// Compact job card used on the Kanban board and drag feedback.
class _CompactJobCard extends StatelessWidget {
  const _CompactJobCard({
    required this.job,
    required this.compact,
    required this.onTap,
  });

  final Map<String, dynamic> job;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loadInfo = (job['load_info'] as String?) ?? '';
    final origin = (job['origin'] as String?) ?? '';
    final destination = (job['destination'] as String?) ?? '';
    final vehiclePlate = (job['vehicle_plate'] as String?) ?? '';
    final status = (job['status'] as String?) ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      loadInfo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  StatusBadge(statusKey: status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${origin.isNotEmpty ? origin : '·'} → ${destination.isNotEmpty ? destination : '·'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (vehiclePlate.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.truck,
                      size: 11,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vehiclePlate,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton placeholder for a list card during loading.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 140,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
