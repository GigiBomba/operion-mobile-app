import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/turn_instruction_banner.dart';
import '../../models/route_share_geometry.dart';
import '../logic/gps_logic.dart';
import '../providers/gps_providers.dart';
import '../providers/route_share_providers.dart';
import '../services/foreground_navigation_service.dart';

/// Full-screen turn-by-turn navigation using phone GPS.
///
/// Renders a flutter_map with the route polyline, current position marker,
/// instruction banner, and bottom sheet with remaining distance/time.
/// Handles loading, error, empty (no route data), and offline states.
class RouteShareNavScreen extends ConsumerWidget {
  const RouteShareNavScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);
    final geometryAsync = ref.watch(routeShareGeometryProvider);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(routeShareGeometryProvider);
                await ref.read(routeShareGeometryProvider.future);
              },
              child: geometryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ErrorView(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(routeShareGeometryProvider),
                ),
                data: (geometry) => geometry.points.isEmpty
                    ? const _EmptyRouteView()
                    : _RouteMapView(geometry: geometry, isOffline: isOffline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

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
            Text(loc.general_error),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center, maxLines: 3),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
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

class _EmptyRouteView extends StatelessWidget {
  const _EmptyRouteView();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Center(
      child: EmptyState(
        icon: const Icon(Icons.map, size: 56),
        title: loc.routeShare_noData,
        subtitle: loc.routeShare_noDataSubtitle,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route map view
// ---------------------------------------------------------------------------

class _RouteMapView extends ConsumerStatefulWidget {
  final RouteShareGeometry geometry;
  final bool isOffline;
  const _RouteMapView({required this.geometry, required this.isOffline});

  @override
  ConsumerState<_RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends ConsumerState<_RouteMapView> {
  final MapController _mapController = MapController();

  /// The most recent GPS fix that passed the 5s / 20m cadence (§7.2.3).
  GpsFix? _displayedFix;

  /// When the last fix was emitted (drives the elapsed side of the cadence).
  DateTime? _displayedFixAt;

  /// When the current off-route deviation started (null when on route).
  DateTime? _offRouteSince;

  /// 10-second persistence window: the geometry re-fetch only fires after the
  /// deviation has been sustained (§7.2.2). A [Timer] (not wall-clock
  /// arithmetic) so the window is exercised by fake-async widget tests.
  Timer? _offRouteTimer;

  /// Guards against re-fetching repeatedly while still off route.
  bool _offRouteRefetchTriggered = false;

  /// Foreground-service controller (blueprint §7.2.3): keeps the persistent
  /// navigation notification live while backgrounded/screen-locked. Lazily
  /// created in [build] so the localized templates and the injected adapter
  /// are available; the adapter itself is Android-only (no-op elsewhere).
  ForegroundNavigationController? _foregroundController;

  List<LatLng> get _routePoints =>
      widget.geometry.points.map((p) => LatLng(p.lat, p.lng)).toList();

  ForegroundNavigationController _foregroundService() {
    return _foregroundController ??= ForegroundNavigationController(
          adapter: ref.read(foregroundServiceAdapterProvider),
          titleTemplate: context.loc.routeShare_fgNotificationTitle,
          bodyTemplate: context.loc.routeShare_fgNotificationBody,
        );
  }

  @override
  void initState() {
    super.initState();
    // Fit map to route bounds after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_routePoints.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(_routePoints),
            padding: const EdgeInsets.all(50),
          ),
        );
      }
    });
  }

  @override
  void didUpdateWidget(_RouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.geometry, widget.geometry)) {
      // Geometry was re-fetched (e.g. the off-route re-fetch): reset the
      // guard so a future deviation can trigger another re-fetch, and drop
      // any in-flight persistence window.
      _offRouteTimer?.cancel();
      _offRouteTimer = null;
      _offRouteSince = null;
      _offRouteRefetchTriggered = false;
      // Refresh the persistent notification against the new geometry (no-op
      // unless the service is running).
      final controller = _foregroundController;
      if (controller != null) _updateForegroundService(controller);
    }
  }

  @override
  void dispose() {
    _offRouteTimer?.cancel();
    _mapController.dispose();
    _foregroundController?.stop();
    super.dispose();
  }

  /// Applies the §7.2.3 cadence decision to a raw fix and — when it passes —
  /// promotes it to the displayed position and re-evaluates off-route state.
  void _onPositionChanged(GpsFix fix) {
    final points = widget.geometry.points;
    if (points.isEmpty) return;

    // 5s elapsed OR 20m displacement, whichever comes first.
    final elapsed = _displayedFixAt == null
        ? const Duration(days: 1) // first fix always emits
        : DateTime.now().difference(_displayedFixAt!);
    final displacementMeters = _displayedFix == null
        ? double.infinity
        : distanceMetersBetween(
            _displayedFix!.lat, _displayedFix!.lng, fix.lat, fix.lng);
    if (!shouldEmitGpsUpdate(
      elapsed: elapsed,
      displacementMeters: displacementMeters,
    )) {
      return;
    }

    setState(() {
      _displayedFix = fix;
      _displayedFixAt = DateTime.now();
    });

    _updateOffRouteTracking(fix);
    // Cadence-gated refresh of the persistent navigation notification: only
    // fixes that passed the 5s / 20m gate reach this point, so this is not
    // an event storm. The controller additionally skips identical content.
    final controller = _foregroundController;
    if (controller != null) _updateForegroundService(controller);
  }

  /// Tracks the 50m / 10s off-route persistence window (§7.2.2). A re-fetch of
  /// [routeShareGeometryProvider] fires only when the deviation has persisted
  /// 10s and the app is not offline (offline keeps rendering the last
  /// geometry — no re-fetch attempt).
  void _updateOffRouteTracking(GpsFix fix) {
    final points = widget.geometry.points;
    final offRoute = isOffRoute(fix.lat, fix.lng, points);

    if (offRoute) {
      _offRouteSince ??= DateTime.now();
      if (_offRouteTimer == null && !_offRouteRefetchTriggered) {
        _offRouteTimer = Timer(
          const Duration(seconds: 10),
          _onOffRoutePersisted,
        );
      }
    } else {
      _offRouteSince = null;
      _offRouteTimer?.cancel();
      _offRouteTimer = null;
      _offRouteRefetchTriggered = false;
    }
  }

  void _onOffRoutePersisted() {
    _offRouteTimer = null;
    if (!mounted) return;
    final fix = _displayedFix;
    if (fix == null) return;
    if (!isOffRoute(fix.lat, fix.lng, widget.geometry.points)) return;
    // Offline: render the last-fetched geometry, suppress the re-fetch (§7.2.2).
    if (ref.read(isOfflineProvider)) return;
    _offRouteRefetchTriggered = true;
    ref.invalidate(routeShareGeometryProvider);
  }

  // ── Foreground-service wiring (§7.2.3) ──────────────────────────────

  /// The guidance a persistent notification should show right now: the next
  /// instruction plus locally-recomputed remaining distance / time (same
  /// inputs the on-screen banner/bottom bar use; no fix → first instruction
  /// + the total route values, mirroring the no-fix fallback).
  ({String instruction, double distanceMeters, int durationSeconds})
      _currentNavigationState() {
    final points = widget.geometry.points;
    final displayedFix = _displayedFix;
    final instructions = widget.geometry.instructions;
    final instructionIndex = displayedFix == null
        ? 0
        : nextInstructionIndexFor(
            displayedFix.lat, displayedFix.lng, instructions, points);
    final distanceMeters = displayedFix == null
        ? widget.geometry.totalDistanceMeters
        : remainingDistanceMeters(displayedFix.lat, displayedFix.lng, points);
    final durationSeconds = displayedFix == null
        ? widget.geometry.totalDurationSeconds
        : remainingDurationSeconds(
            displayedFix.lat,
            displayedFix.lng,
            points,
            totalDistanceMeters: widget.geometry.totalDistanceMeters,
            totalDurationSeconds: widget.geometry.totalDurationSeconds,
          );
    return (
      instruction: instructions.isEmpty ? '' : instructions[instructionIndex].textKey,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  /// Starts the service with the current guidance. Only invoked when the map
  /// view is active AND background tracking is permitted (foreground-only
  /// mode never starts it — the existing banner explains the pause).
  Future<void> _ensureForegroundServiceStarted(
    ForegroundNavigationController controller,
  ) async {
    if (controller.isRunning) return;
    final state = _currentNavigationState();
    final channelName = context.loc.routeShare_fgChannelName;
    await controller.start(
      instructionText: state.instruction,
      distanceLabel: formatDistance(state.distanceMeters),
      etaLabel: formatDuration(state.durationSeconds),
      channelName: channelName,
    );
  }

  /// Refreshes the notification content. No-op unless the service is running
  /// (the controller also skips content identical to the last push).
  Future<void> _updateForegroundService(
    ForegroundNavigationController controller,
  ) async {
    if (!controller.isRunning) return;
    final state = _currentNavigationState();
    await controller.update(
      instructionText: state.instruction,
      distanceLabel: formatDistance(state.distanceMeters),
      etaLabel: formatDuration(state.durationSeconds),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Keep the position stream alive and react to raw platform fixes.
    ref.listen(gpsPositionProvider, (previous, next) {
      final fix = next.valueOrNull;
      if (fix != null) _onPositionChanged(fix);
    });

    // Foreground service lifecycle (blueprint §7.2.3): start once the map is
    // active and background tracking is permitted; tear down on any
    // permission regression (e.g. revoked mid-route). Foreground-only mode
    // (background denied) never starts the service — the existing banner
    // explains the pause.
    final foregroundController = _foregroundService();
    ref.listen(gpsPermissionProvider, (previous, next) {
      final permission = next.valueOrNull;
      if (permission == null) return;
      if (permission.foregroundAllowed && permission.backgroundAllowed) {
        _ensureForegroundServiceStarted(foregroundController);
      } else {
        foregroundController.stop();
      }
    });

    final loc = context.loc;
    final points = _routePoints;
    final displayedFix = _displayedFix;
    final geometryPoints = widget.geometry.points;

    // ── Permission-driven banner state (§7.2.3 graceful degradation) ──
    final permission = ref.watch(gpsPermissionProvider).valueOrNull;
    final backgroundDenied =
        permission != null && permission.foregroundAllowed && !permission.backgroundAllowed;
    final locationDenied = permission != null && !permission.foregroundAllowed;

    // ── Off-route state ──
    final isOffRouteNow = displayedFix != null &&
        isOffRoute(displayedFix.lat, displayedFix.lng, geometryPoints);

    // ── Traveled vs remaining segments (visual distinction) ──
    final nearestIndex = displayedFix == null
        ? 0
        : nearestPointIndex(displayedFix.lat, displayedFix.lng, geometryPoints);
    final remainingPoints = geometryPoints
        .sublist(nearestIndex)
        .map((p) => LatLng(p.lat, p.lng))
        .toList();
    final traveledPoints = geometryPoints
        .sublist(0, nearestIndex + 1)
        .map((p) => LatLng(p.lat, p.lng))
        .toList();

    // ── Locally-recomputed remaining distance / time (blueprint §7.2.2:
    //    last-known fix + downloaded geometry — never a per-tick re-fetch) ──
    final double remainingDistance;
    final int remainingDuration;
    if (displayedFix != null) {
      remainingDistance = remainingDistanceMeters(
          displayedFix.lat, displayedFix.lng, geometryPoints);
      remainingDuration = remainingDurationSeconds(
        displayedFix.lat,
        displayedFix.lng,
        geometryPoints,
        totalDistanceMeters: widget.geometry.totalDistanceMeters,
        totalDurationSeconds: widget.geometry.totalDurationSeconds,
      );
    } else {
      remainingDistance = widget.geometry.totalDistanceMeters;
      remainingDuration = widget.geometry.totalDurationSeconds;
    }

    // ── Instruction banner advance (no fix → first instruction) ──
    final instructions = widget.geometry.instructions;
    final instructionIndex = displayedFix == null
        ? 0
        : nextInstructionIndexFor(
            displayedFix.lat, displayedFix.lng, instructions, geometryPoints);
    final instruction = instructions.isEmpty ? null : instructions[instructionIndex];

    return Stack(
      children: [
        // ── Full-screen map ──
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: points.isNotEmpty
                ? points.first
                : const LatLng(46.0, 25.0),
            initialZoom: 12.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.operion.mobile',
            ),
            if (points.isNotEmpty)
              PolylineLayer(
                polylines: [
                  if (displayedFix != null)
                    // Traveled segment — dimmed, thinner.
                    Polyline(
                      points: traveledPoints,
                      color: AppColors.accent.withValues(alpha: 0.30),
                      strokeWidth: 3.0,
                    ),
                  // Remaining segment — bright, thicker.
                  Polyline(
                    points: remainingPoints,
                    color: AppColors.accent,
                    strokeWidth: 5.0,
                  ),
                ],
              ),
            if (points.isNotEmpty)
              MarkerLayer(
                markers: [
                  // Start marker
                  Marker(
                    point: points.first,
                    width: 30,
                    height: 30,
                    child: const Icon(Icons.trip_origin,
                        color: AppColors.success, size: 30),
                  ),
                  // End marker
                  Marker(
                    point: points.last,
                    width: 30,
                    height: 30,
                    child: const Icon(Icons.location_on,
                        color: AppColors.error, size: 30),
                  ),
                  // Current position marker (updates with the GPS stream)
                  if (displayedFix != null)
                    Marker(
                      point: LatLng(displayedFix.lat, displayedFix.lng),
                      width: 34,
                      height: 34,
                      child: const _CurrentPositionMarker(),
                    ),
                ],
              ),
          ],
        ),

        // ── Instruction banner + status banners at top ──
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TurnInstructionBanner(
                  instructionText: instruction?.textKey,
                  distanceMeters: instruction?.distanceMeters ?? remainingDistance,
                  etaText: formatDuration(remainingDuration),
                ),
                if (isOffRouteNow)
                  _StatusBanner(
                    text: loc.routeShare_offRoute,
                    color: AppColors.warning,
                    icon: Icons.wrong_location,
                  ),
                if (backgroundDenied)
                  _StatusBanner(
                    text: loc.routeShare_backgroundBanner,
                    color: AppColors.info,
                    icon: Icons.info_outline,
                  ),
                if (locationDenied)
                  _StatusBanner(
                    text: loc.routeShare_permissionDenied,
                    color: AppColors.error,
                    icon: Icons.location_off,
                  ),
              ],
            ),
          ),
        ),

        // ── Bottom sheet: remaining distance/time ──
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomInfoBar(
            distanceMeters: remainingDistance,
            durationSeconds: remainingDuration,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Current position marker
// ---------------------------------------------------------------------------

class _CurrentPositionMarker extends StatelessWidget {
  const _CurrentPositionMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.navigation, size: 16, color: Colors.white),
    );
  }
}

// ---------------------------------------------------------------------------
// Non-blocking status banner (off-route / permission fallback)
// ---------------------------------------------------------------------------

class _StatusBanner extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _StatusBanner({
    required this.text,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom info bar
// ---------------------------------------------------------------------------

class _BottomInfoBar extends StatelessWidget {
  final double distanceMeters;
  final int durationSeconds;
  const _BottomInfoBar(
      {required this.distanceMeters, required this.durationSeconds});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _InfoItem(
              icon: LucideIcons.map,
              label: loc.routeShare_distance,
              value: formatDistance(distanceMeters),
            ),
            _InfoItem(
              icon: LucideIcons.clock,
              label: loc.routeShare_estimatedTime,
              value: formatDuration(durationSeconds),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
