import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../models/freight_load.dart';
import '../providers/freight_exchange_providers.dart';
import 'freight_load_detail_screen.dart';

/// Freight Exchange — provider-agnostic load board.
///
/// Implements all four §1.2 states: loading (shimmer), error (retry),
/// empty, and pull-to-refresh on the load list. Filtering happens via
/// [freightExchangeFilterProvider]; the board is keyed by that filter so a
/// filter change re-fetches.
class FreightExchangeScreen extends ConsumerStatefulWidget {
  const FreightExchangeScreen({super.key});

  @override
  ConsumerState<FreightExchangeScreen> createState() =>
      _FreightExchangeScreenState();
}

class _FreightExchangeScreenState extends ConsumerState<FreightExchangeScreen> {
  final _originCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _cargoTypeCtrl = TextEditingController();

  DateTime? _date;

  /// §2 parity — when set, the advanced-search results replace the load board.
  AdvancedSearchFilters? _advancedFilters;

  /// §2 parity — when set, the re-run saved-search results replace the board.
  String? _activeSavedSearchId;

  @override
  void dispose() {
    _originCtrl.dispose();
    _destinationCtrl.dispose();
    _cargoTypeCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(freightExchangeFilterProvider.notifier).state = FreightLoadFilter(
      origin: _originCtrl.text.trim(),
      destination: _destinationCtrl.text.trim(),
      date: _date,
      cargoType: _cargoTypeCtrl.text.trim(),
    );
  }

  void _clearFilters() {
    _originCtrl.clear();
    _destinationCtrl.clear();
    _cargoTypeCtrl.clear();
    setState(() {
      _date = null;
      _advancedFilters = null;
      _activeSavedSearchId = null;
    });
    ref.read(freightExchangeFilterProvider.notifier).state =
        const FreightLoadFilter();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 90)),
      helpText: context.loc.freightExchange_date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Opens the advanced "More filters" sheet (POST /freight/search form).
  Future<void> _openAdvancedSearch() async {
    final filters = await showModalBottomSheet<AdvancedSearchFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const _AdvancedSearchSheet(),
    );
    if (filters == null) return;
    setState(() {
      _advancedFilters = filters;
      _activeSavedSearchId = null;
    });
  }

  /// Opens the saved-searches sheet (list + save current + re-run).
  Future<void> _openSavedSearches() async {
    final searchId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const _SavedSearchesSheet(),
    );
    if (searchId == null) return;
    setState(() {
      _activeSavedSearchId = searchId;
      _advancedFilters = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final filter = ref.watch(freightExchangeFilterProvider);
    final loadsAsync = _advancedFilters != null
        ? ref.watch(advancedSearchProvider(_advancedFilters!))
        : (_activeSavedSearchId != null
            ? ref.watch(refreshSavedSearchProvider(_activeSavedSearchId!))
            : ref.watch(freightLoadsProvider(filter)));

    return Scaffold(
      appBar: AppBar(title: Text(loc.nav_freightExchange)),
      body: Column(
        children: [
          _buildFilterBar(loc),
          Expanded(
            child: loadsAsync.when(
              loading: () => const _LoadBoardShimmer(),
              error: (err, stack) => _ErrorRetry(
                message: loc.freightExchange_loadError,
                onRetry: () {
                  if (_advancedFilters != null) {
                    ref.invalidate(advancedSearchProvider(_advancedFilters!));
                  } else if (_activeSavedSearchId != null) {
                    ref.invalidate(refreshSavedSearchProvider(_activeSavedSearchId!));
                  } else {
                    ref.invalidate(freightLoadsProvider(filter));
                  }
                },
              ),
              data: (loads) {
                if (loads.isEmpty) {
                  return _EmptyBoard(filterActive: filter.isActive);
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    if (_advancedFilters != null) {
                      ref.invalidate(advancedSearchProvider(_advancedFilters!));
                      await ref
                          .read(advancedSearchProvider(_advancedFilters!).future);
                    } else if (_activeSavedSearchId != null) {
                      ref.invalidate(
                        refreshSavedSearchProvider(_activeSavedSearchId!),
                      );
                      await ref.read(
                        refreshSavedSearchProvider(_activeSavedSearchId!).future,
                      );
                    } else {
                      ref.invalidate(freightLoadsProvider(filter));
                      await ref.read(freightLoadsProvider(filter).future);
                    }
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: loads.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final load = loads[index];
                      return _LoadCard(
                        load: load,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FreightLoadDetailScreen(
                              load: load,
                              filter: filter,
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
      ),
    );
  }

  Widget _buildFilterBar(AppLocalizations loc) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _originCtrl,
            hintText: loc.freightExchange_origin,
            prefixIcon: const Icon(LucideIcons.mapPin, size: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _destinationCtrl,
            hintText: loc.freightExchange_destination,
            prefixIcon: const Icon(LucideIcons.mapPinned, size: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _cargoTypeCtrl,
                  hintText: loc.freightExchange_cargoType,
                  prefixIcon: const Icon(LucideIcons.box, size: 18),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                onTap: _pickDate,
                borderRadius: AppRadius.lgAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkOverlay : AppColors.lightElevated,
                    borderRadius: AppRadius.lgAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.calendar,
                        size: 18,
                        color: _date == null
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                            : AppColors.accent,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        _date == null
                            ? loc.freightExchange_date
                            : '${_date!.day}/${_date!.month}/${_date!.year}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(LucideIcons.x, size: 16),
                  label: Text(loc.freightExchange_clearFilters),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(LucideIcons.search, size: 16),
                  label: Text(loc.freightExchange_applyFilters),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openAdvancedSearch,
                  icon: const Icon(LucideIcons.slidersHorizontal, size: 16),
                  label: Text(loc.freightExchange_moreFilters),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openSavedSearches,
                  icon: const Icon(LucideIcons.bookmark, size: 16),
                  label: Text(loc.freightExchange_savedSearches),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading shimmer
// ---------------------------------------------------------------------------

class _LoadBoardShimmer extends StatelessWidget {
  const _LoadBoardShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: List.generate(
        4,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: ShimmerLoader(child: _ShimmerBlock(height: 120)),
        ),
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  final double height;
  const _ShimmerBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: Text(loc.general_retry),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyBoard extends StatelessWidget {
  final bool filterActive;
  const _EmptyBoard({required this.filterActive});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Center(
      child: EmptyState(
        icon: Icon(
          filterActive ? LucideIcons.filter : LucideIcons.truck,
          size: 56,
        ),
        title: loc.freightExchange_empty,
        subtitle: loc.freightExchange_emptyHint,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Load card
// ---------------------------------------------------------------------------

class _LoadCard extends StatelessWidget {
  final FreightLoad load;
  final VoidCallback onTap;

  const _LoadCard({required this.load, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${load.origin} → ${load.destination}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (load.price != null)
                  Text(
                    '${load.price!.toStringAsFixed(2)} ${load.currency ?? ''}'
                        .trim(),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: AppColors.success),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (load.cargoType != null && load.cargoType!.isNotEmpty) ...[
                  const Icon(LucideIcons.box, size: 14, color: AppColors.info),
                  const SizedBox(width: AppSpacing.xs),
                  Text(load.cargoType!, style: theme.textTheme.bodySmall),
                ],
                if (load.distanceKm != null) ...[
                  const SizedBox(width: AppSpacing.lg),
                  const Icon(LucideIcons.route, size: 14, color: AppColors.info),
                  const SizedBox(width: AppSpacing.xs),
                  Text('${load.distanceKm} km', style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Advanced search sheet (§2 parity — POST /freight/search form)
// ---------------------------------------------------------------------------

/// Bottom sheet with the bounded advanced-search form.
///
/// Fields mirror the backend `SearchRequest` (origin/destination locations,
/// pickup date range, weight min/max, trailer type, price min/max) — kept to
/// the most useful ~8 fields per §2. Returns an [AdvancedSearchFilters] via
/// `Navigator.pop` when the user runs the search.
class _AdvancedSearchSheet extends StatefulWidget {
  const _AdvancedSearchSheet();

  @override
  State<_AdvancedSearchSheet> createState() => _AdvancedSearchSheetState();
}

class _AdvancedSearchSheetState extends State<_AdvancedSearchSheet> {
  final _originCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _weightMinCtrl = TextEditingController();
  final _weightMaxCtrl = TextEditingController();
  final _priceMinCtrl = TextEditingController();
  final _priceMaxCtrl = TextEditingController();

  DateTime? _pickupFrom;
  DateTime? _pickupTo;
  String? _trailerType;

  static const _trailerTypes = [
    'general',
    'reefer',
    'curtain',
    'flatbed',
    'tanker',
    'container',
  ];

  @override
  void dispose() {
    _originCtrl.dispose();
    _destinationCtrl.dispose();
    _weightMinCtrl.dispose();
    _weightMaxCtrl.dispose();
    _priceMinCtrl.dispose();
    _priceMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (_pickupFrom ?? now)
        : (_pickupTo ?? now.add(const Duration(days: 7)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: isFrom
          ? context.loc.freightExchange_pickupFrom
          : context.loc.freightExchange_pickupTo,
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _pickupFrom = picked;
        } else {
          _pickupTo = picked;
        }
      });
    }
  }

  double? _toDouble(TextEditingController ctrl) =>
      double.tryParse(ctrl.text.trim().replaceAll(',', '.'));

  void _run() {
    Navigator.of(context).pop(
      AdvancedSearchFilters(
        originLocation: _originCtrl.text.trim(),
        destinationLocation: _destinationCtrl.text.trim(),
        pickupDateFrom: _pickupFrom,
        pickupDateTo: _pickupTo,
        weightKgMin: _toDouble(_weightMinCtrl),
        weightKgMax: _toDouble(_weightMaxCtrl),
        trailerType: _trailerType,
        priceMin: _toDouble(_priceMinCtrl),
        priceMax: _toDouble(_priceMaxCtrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fieldBg = isDark ? AppColors.darkOverlay : AppColors.lightElevated;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.freightExchange_advancedSearch,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _originCtrl,
              hintText: loc.freightExchange_origin,
              prefixIcon: const Icon(LucideIcons.mapPin, size: 18),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _destinationCtrl,
              hintText: loc.freightExchange_destination,
              prefixIcon: const Icon(LucideIcons.mapPinned, size: 18),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: loc.freightExchange_pickupFrom,
                    value: _pickupFrom,
                    onTap: () => _pickDate(isFrom: true),
                    bg: fieldBg,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _DateField(
                    label: loc.freightExchange_pickupTo,
                    value: _pickupTo,
                    onTap: () => _pickDate(isFrom: false),
                    bg: fieldBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _weightMinCtrl,
                    hintText: loc.freightExchange_weightMin,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(LucideIcons.weight, size: 18),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    controller: _weightMaxCtrl,
                    hintText: loc.freightExchange_weightMax,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(LucideIcons.weight, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: AppRadius.lgAll,
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _trailerType,
                hint: Text(loc.freightExchange_trailerType),
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                items: [
                  for (final type in _trailerTypes)
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: (value) => setState(() => _trailerType = value),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _priceMinCtrl,
                    hintText: loc.freightExchange_priceMin,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(LucideIcons.circleDollarSign, size: 18),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    controller: _priceMaxCtrl,
                    hintText: loc.freightExchange_priceMax,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(LucideIcons.circleDollarSign, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(loc.general_cancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _run,
                    icon: const Icon(LucideIcons.search, size: 16),
                    label: Text(loc.freightExchange_applyFilters),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable date field used by the advanced-search sheet.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.bg,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.lgAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.calendar,
              size: 18,
              color: value == null
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                  : AppColors.accent,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                value == null
                    ? label
                    : '${value!.day}/${value!.month}/${value!.year}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Saved searches sheet (§2 parity — GET/POST /freight/searches, refresh)
// ---------------------------------------------------------------------------

/// Bottom sheet listing saved searches with "Run" (refresh), swipe-to-delete
/// (confirmation + `DELETE /freight/searches/{search_id}`) and a "Save
/// current search" flow.
class _SavedSearchesSheet extends ConsumerStatefulWidget {
  const _SavedSearchesSheet();

  @override
  ConsumerState<_SavedSearchesSheet> createState() => _SavedSearchesSheetState();
}

class _SavedSearchesSheetState extends ConsumerState<_SavedSearchesSheet> {
  final _labelCtrl = TextEditingController();

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  /// Builds a `LoadSearchFilters`-compatible dict from the current filter
  /// state (the backend deserialises `filters` with `LoadSearchFilters(**...)`,
  /// so `pickup_date_from`/`pickup_date_to` are always present).
  Map<String, dynamic> _filtersFromCurrent() {
    final filter = ref.read(freightExchangeFilterProvider);
    final now = DateTime.now();
    final date = filter.date ?? now;
    return {
      if (filter.origin.isNotEmpty)
        'origin': {'location': filter.origin, 'radius_km': 50},
      if (filter.destination.isNotEmpty)
        'destination': {'location': filter.destination, 'radius_km': 30},
      'pickup_date_from': _isoDate(date.subtract(const Duration(days: 7))),
      'pickup_date_to': _isoDate(date.add(const Duration(days: 14))),
      if (filter.cargoType != null && filter.cargoType!.isNotEmpty)
        'trailer_type': [filter.cargoType],
    };
  }

  static String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  /// Confirms deletion of a saved search, then calls
  /// `DELETE /api/v1/freight/searches/{search_id}` via
  /// [deleteSavedSearchProvider]. On success the list provider is invalidated
  /// (the row disappears on refetch); failures surface a snackbar.
  Future<void> _confirmDeleteSearch(SavedFreightSearch search) async {
    final loc = context.loc;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: loc.freightExchange_deleteSearch,
      message: loc.freightExchange_deleteSearchConfirm,
      confirmLabel: loc.general_confirm,
      cancelLabel: loc.general_cancel,
      isDangerous: true,
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(deleteSavedSearchProvider.notifier)
        .delete(search.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.freightExchange_saveSearchError),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveCurrentSearch() async {
    final loc = context.loc;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.freightExchange_saveCurrentSearch),
        content: TextField(
          controller: _labelCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: loc.freightExchange_savedSearchLabelHint,
            labelText: loc.freightExchange_savedSearchLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.general_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.general_save),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) return;

    final ok = await ref
        .read(freightSearchSaveProvider.notifier)
        .save(label: label, filters: _filtersFromCurrent());
    if (!mounted) return;
    if (ok) {
      ref.invalidate(savedFreightSearchesProvider);
      _labelCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.freightExchange_searchSaved),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.freightExchange_saveSearchError),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final searchesAsync = ref.watch(savedFreightSearchesProvider);
    final saveState = ref.watch(freightSearchSaveProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    loc.freightExchange_savedSearches,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      saveState.status == FreightSearchSaveStatus.saving
                          ? null
                          : _saveCurrentSearch,
                  icon: const Icon(LucideIcons.bookmarkPlus, size: 16),
                  label: Text(loc.freightExchange_saveCurrentSearch),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: searchesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    loc.freightExchange_saveSearchError,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                data: (searches) {
                  if (searches.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        loc.freightExchange_noSavedSearches,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: searches.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final search = searches[index];
                      return Dismissible(
                        key: ValueKey('saved-search-${search.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(
                            LucideIcons.trash,
                            color: Colors.white,
                          ),
                        ),
                        confirmDismiss: (_) async {
                          await _confirmDeleteSearch(search);
                          // Removal happens via provider invalidation — return
                          // false so Dismissible doesn't double-remove.
                          return false;
                        },
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            LucideIcons.bookmark,
                            size: 20,
                            color: AppColors.accent,
                          ),
                          title: Text(
                            search.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                          subtitle: search.lastRefreshedAt != null
                              ? Text(
                                  '${loc.general_lastUpdated}: '
                                  '${search.lastRefreshedAt!.day}/'
                                  '${search.lastRefreshedAt!.month}/'
                                  '${search.lastRefreshedAt!.year}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                )
                              : null,
                          trailing: FilledButton.tonal(
                            onPressed: () =>
                                Navigator.of(context).pop(search.id),
                            child: Text(loc.freightExchange_runSearch),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
