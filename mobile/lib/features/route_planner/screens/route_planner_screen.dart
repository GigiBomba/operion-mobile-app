import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/route_planner_providers.dart';

/// Route Planner screen — multi-stop trip planning with drag-to-reorder.
///
/// Users add/remove/reorder waypoints, then submit for optimized route.
/// The optimized route renders on a flutter_map view.
class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final List<String> _waypoints = [];
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  /// §2 parity — routing profile (truck / car / foot, verified against the
  /// backend's profile handling).
  RouteProfile _profile = RouteProfile.truck;

  /// §2 parity — ISO alpha-2 countries the route should avoid (sent as
  /// `excluded_countries` on calculate).
  final Set<String> _excludedCountries = {};

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _addWaypoint() {
    setState(() => _waypoints.add(''));
  }

  void _removeWaypoint(int index) {
    setState(() => _waypoints.removeAt(index));
  }

  /// Pull-to-refresh semantics for a form screen (§1.2): there is no list to
  /// reload, so refresh resets the whole form (origin, destination, stops) to
  /// its initial empty state — the sensible minimal version, documented in the
  /// P3 report. §2 additions (profile, excluded countries) are reset too.
  Future<void> _resetForm() async {
    _originController.clear();
    _destinationController.clear();
    setState(() {
      _waypoints.clear();
      _profile = RouteProfile.truck;
      _excludedCountries.clear();
    });
  }

  /// Collects the ordered route points (origin + non-empty waypoints +
  /// destination) from the form fields.
  List<String> _collectRoutePoints() {
    return [
      if (_originController.text.trim().isNotEmpty)
        _originController.text.trim(),
      ..._waypoints.where((w) => w.trim().isNotEmpty).map((w) => w.trim()),
      if (_destinationController.text.trim().isNotEmpty)
        _destinationController.text.trim(),
    ];
  }

  void _showRouteResult(BuildContext context) {
    final points = _collectRoutePoints();
    if (points.length < 2) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _RouteResultSheet(
        config: RouteRequestConfig(
          points: points,
          profile: _profile.id,
          excludedCountries: _excludedCountries.toList()..sort(),
        ),
        originLabel: _originController.text,
        destinationLabel: _destinationController.text,
      ),
    );
  }

  /// Opens the "countries to avoid" picker sheet and applies the selection.
  Future<void> _pickAvoidedCountries() async {
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _CountryPickerSheet(selected: _excludedCountries),
    );
    if (selected == null) return;
    setState(() {
      _excludedCountries
        ..clear()
        ..addAll(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(loc.nav_routePlanner)),
      body: RefreshIndicator(
        onRefresh: _resetForm,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Origin
            Text(loc.routePlanner_origin, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _originController,
              hintText: loc.routePlanner_originHint,
              prefixIcon: const Icon(Icons.trip_origin, size: 20),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Destination
            Text(loc.routePlanner_destination, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _destinationController,
              hintText: loc.routePlanner_destinationHint,
              prefixIcon: const Icon(Icons.location_on, size: 20),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── §2: Routing profile selector ──────────────────────────
            Text(loc.routePlanner_profile, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<RouteProfile>(
                segments: [
                  for (final profile in RouteProfile.values)
                    ButtonSegment<RouteProfile>(
                      value: profile,
                      label: Text(_profileLabel(loc, profile)),
                    ),
                ],
                selected: {_profile},
                onSelectionChanged: (selection) =>
                    setState(() => _profile = selection.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── §2: Countries to avoid ────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.routePlanner_avoidCountries,
                  style: theme.textTheme.titleSmall,
                ),
                TextButton.icon(
                  onPressed: _pickAvoidedCountries,
                  icon: const Icon(LucideIcons.mapPinOff, size: 16),
                  label: Text(
                    _excludedCountries.isEmpty
                        ? loc.routePlanner_selectCountries
                        : '${loc.routePlanner_selectCountries} (${_excludedCountries.length})',
                  ),
                ),
              ],
            ),
            if (_excludedCountries.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final code in _excludedCountries.toList()..sort())
                    InputChip(
                      label: Text(code, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () =>
                          setState(() => _excludedCountries.remove(code)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Waypoints
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${loc.routePlanner_stops} (${_waypoints.length})', style: theme.textTheme.titleSmall),
                TextButton.icon(
                  onPressed: _addWaypoint,
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: Text(loc.routePlanner_addStop),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            if (_waypoints.isEmpty)
              EmptyState(
                icon: const Icon(LucideIcons.mapPin, size: 48),
                title: loc.routePlanner_noStops,
                subtitle: loc.routePlanner_noStopsHint,
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _waypoints.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _waypoints.removeAt(oldIndex);
                    _waypoints.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  return Card(
                    key: ValueKey('waypoint_$index'),
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      leading: Icon(LucideIcons.gripVertical, size: 20),
                      title: Text('${loc.routePlanner_stopNumber} ${index + 1}'),
                      trailing: IconButton(
                        icon: const Icon(LucideIcons.trash2, size: 18),
                        onPressed: () => _removeWaypoint(index),
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: AppSpacing.xxl),

            // Submit button
            AppButton.primary(
              label: loc.routePlanner_optimize,
              onPressed: _originController.text.isNotEmpty && _destinationController.text.isNotEmpty
                  ? () => _showRouteResult(context)
                  : null,
            ),

            const SizedBox(height: AppSpacing.xhuge),
          ],
          ),
        ),
      ),
    );
  }

  /// Localized label for a routing profile.
  String _profileLabel(AppLocalizations loc, RouteProfile profile) {
    switch (profile.id) {
      case 'car':
        return loc.routePlanner_profileCar;
      case 'foot':
        return loc.routePlanner_profilePedestrian;
      default:
        return loc.routePlanner_profileTruck;
    }
  }
}

// ---------------------------------------------------------------------------
// Countries-to-avoid picker sheet (§2 parity)
// ---------------------------------------------------------------------------

/// Modal sheet listing the fixed EU-27 country set as FilterChips.
///
/// Returns the selected ISO alpha-2 codes via `Navigator.pop`; "Done" applies
/// the selection.
class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.selected});

  final Set<String> selected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  late final Set<String> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.routePlanner_avoidCountries,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              loc.routePlanner_avoidCountriesHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final code in kAvoidableCountries)
                      FilterChip(
                        label: Text(code, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        selected: _selected.contains(code),
                        onSelected: (value) => setState(() {
                          if (value) {
                            _selected.add(code);
                          } else {
                            _selected.remove(code);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text(loc.general_done),
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

// ---------------------------------------------------------------------------
// Route result sheet — loads the route from the backend provider
// ---------------------------------------------------------------------------

/// Bottom-sheet content that resolves the optimized route via
/// [routeCalculateProvider] and renders loading / error / result states.
class _RouteResultSheet extends ConsumerWidget {
  const _RouteResultSheet({
    required this.config,
    required this.originLabel,
    required this.destinationLabel,
  });

  /// Ordered route points + profile + excluded countries.
  final RouteRequestConfig config;
  final String originLabel;
  final String destinationLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(routeCalculateProvider(config));

    return resultAsync.when(
      loading: () => const _RouteLoadingView(),
      error: (error, _) => _RouteErrorView(
        message: '$error',
        onRetry: () => ref.invalidate(routeCalculateProvider(config)),
      ),
      data: (result) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _RouteOptimizationResult(
          waypoints: result.geometry,
          distanceMeters: result.distanceMeters,
          durationSeconds: result.durationSeconds,
          originLabel: originLabel,
          destinationLabel: destinationLabel,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _RouteLoadingView extends StatelessWidget {
  const _RouteLoadingView();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(loc.general_loading, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _RouteErrorView extends StatelessWidget {
  const _RouteErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle, size: 56, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '${loc.general_error}: $message',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.secondary(
              label: loc.general_retry,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route optimization result — full-screen bottom sheet content
// ---------------------------------------------------------------------------

class _RouteOptimizationResult extends StatelessWidget {
  final List<LatLng> waypoints;
  final double distanceMeters;
  final int durationSeconds;
  final String originLabel;
  final String destinationLabel;
  final ScrollController scrollController;

  const _RouteOptimizationResult({
    required this.waypoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.originLabel,
    required this.destinationLabel,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;

    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              loc.routePlanner_optimize,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Map ──
          SizedBox(
            height: 240,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: waypoints.isNotEmpty
                    ? waypoints.first
                    : const LatLng(44.4268, 26.1025),
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.operion.mobile',
                ),
                if (waypoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: waypoints,
                        color: AppColors.accent,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
                if (waypoints.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: waypoints.first,
                        width: 30,
                        height: 30,
                        child: const Icon(Icons.trip_origin,
                            color: AppColors.success, size: 30),
                      ),
                      Marker(
                        point: waypoints.last,
                        width: 30,
                        height: 30,
                        child: const Icon(Icons.location_on,
                            color: AppColors.error, size: 30),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Distance / Time summary ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    icon: LucideIcons.map,
                    label: loc.routeShare_distance,
                    value: _formatDistance(distanceMeters),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _SummaryTile(
                    icon: LucideIcons.clock,
                    label: loc.routeShare_estimatedTime,
                    value: _formatDuration(durationSeconds),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Waypoint list ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              loc.routePlanner_stops,
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Origin
          _WaypointTile(
            index: 0,
            label: originLabel,
            icon: Icons.trip_origin,
            iconColor: AppColors.success,
          ),

          // Intermediate waypoints
          ...waypoints.asMap().entries.map((entry) {
            if (entry.key == 0 || entry.key == waypoints.length - 1) {
              return const SizedBox.shrink();
            }
            return _WaypointTile(
              index: entry.key,
              label: '${loc.routePlanner_stopNumber} ${entry.key + 1}',
              icon: LucideIcons.mapPin,
              iconColor: AppColors.accent,
            );
          }),

          // Destination
          _WaypointTile(
            index: waypoints.length - 1,
            label: destinationLabel,
            icon: Icons.location_on,
            iconColor: AppColors.error,
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Route note ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, size: 18, color: AppColors.info),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      loc.routePlanner_notice,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.toInt()} m';
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.accent),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaypointTile extends StatelessWidget {
  final int index;
  final String label;
  final IconData icon;
  final Color iconColor;

  const _WaypointTile({
    required this.index,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: iconColor.withValues(alpha: 0.15),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            '#${index + 1}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
