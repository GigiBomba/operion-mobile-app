import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

// ---------------------------------------------------------------------------
// GPS acquisition seams (blueprint §7.2.3).
//
// The screen depends on the small [GpsService] interface, never on the
// geolocator plugin directly, so tests can override [gpsServiceProvider] with
// a fake implementation (deterministic permission states + injected fixes).
// ---------------------------------------------------------------------------

/// A single GPS fix as consumed by the turn-by-turn layer.
class GpsFix {
  final double lat;
  final double lng;
  final double? accuracyMeters;

  const GpsFix({required this.lat, required this.lng, this.accuracyMeters});
}

/// Location permission state relevant to turn-by-turn navigation.
class GpsPermission {
  /// Whether the app may receive location updates while in the foreground.
  final bool foregroundAllowed;

  /// Whether the app may also receive updates when backgrounded
  /// (Android "Allow all the time" / iOS "Always").
  final bool backgroundAllowed;

  const GpsPermission({
    required this.foregroundAllowed,
    required this.backgroundAllowed,
  });
}

/// Seam for GPS acquisition. Tests override [gpsServiceProvider] with a fake
/// implementation; the real one wraps the `geolocator` plugin.
abstract class GpsService {
  /// Raw position stream. The 5s / 20m cadence decision (whichever first) is
  /// applied by `shouldEmitGpsUpdate` in `logic/gps_logic.dart`.
  Stream<GpsFix?> get positionStream;

  /// Resolves the current location permission state.
  Future<GpsPermission> get permission;
}

/// Real implementation backed by the `geolocator` plugin.
///
/// The platform stream is requested with a small [distanceFilter] so the
/// app-layer cadence logic can observe the 20 m threshold; the 5 s half of
/// the cadence is enforced by [shouldEmitGpsUpdate] on each fix.
class GeolocatorGpsService implements GpsService {
  const GeolocatorGpsService();

  static const LocationSettings _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5,
  );

  @override
  Stream<GpsFix?> get positionStream => Geolocator.getPositionStream(
        locationSettings: _settings,
      ).map(
        (position) => GpsFix(
          lat: position.latitude,
          lng: position.longitude,
          accuracyMeters: position.accuracy,
        ),
      );

  @override
  Future<GpsPermission> get permission async {
    var status = await Geolocator.checkPermission();
    // First launch: the system permission dialog has not been shown yet —
    // request it now (Android + iOS show their own platform dialog).
    if (status == LocationPermission.denied) {
      status = await Geolocator.requestPermission();
    }
    // Elevate a freshly-granted foreground permission to the background level
    // (idempotent when there is nothing left to request, so re-entering this
    // getter is safe):
    //   * Android — geolocator's second request adds ACCESS_BACKGROUND_LOCATION
    //     to the system dialog ("Allow all the time", Android 10+).
    //   * iOS — the same call consults the Always plist keys
    //     (NSLocationAlwaysAndWhenInUseUsageDescription) and surfaces the
    //     granted level. A denied "Always" degrades to foreground-only — the
    //     existing §7.2.3 banner path, not a crash or a silent stop.
    if (status == LocationPermission.whileInUse &&
        (Platform.isAndroid || Platform.isIOS)) {
      status = await Geolocator.requestPermission();
    }
    final foreground = status == LocationPermission.whileInUse ||
        status == LocationPermission.always;
    final background = status == LocationPermission.always;
    return GpsPermission(
      foregroundAllowed: foreground,
      backgroundAllowed: background,
    );
  }
}

/// Injectable GPS service (override in tests).
final gpsServiceProvider = Provider<GpsService>((ref) {
  return const GeolocatorGpsService();
});

/// Raw GPS position stream at the platform cadence. Null events represent a
/// lost/dropped fix and are ignored by the navigation layer.
final gpsPositionProvider = StreamProvider<GpsFix?>((ref) {
  final service = ref.watch(gpsServiceProvider);
  return service.positionStream;
});

/// Current location permission state (§7.2.3 graceful degradation: a denied
/// background/"Always" permission degrades to foreground-only tracking with a
/// persistent banner — never a crash or a silent stop).
final gpsPermissionProvider = FutureProvider<GpsPermission>((ref) async {
  final service = ref.watch(gpsServiceProvider);
  return service.permission;
});
