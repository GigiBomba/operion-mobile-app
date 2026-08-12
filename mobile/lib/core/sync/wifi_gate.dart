import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/settings_providers.dart';
import '../auth/auth_providers.dart';
import 'connectivity_monitor.dart';

/// Phase 4B Wi-Fi-only large-transfer gate (§4.10, Data Usage).
///
/// When the user enables "Wi-Fi only for large syncs", large transfers
/// (delta sync, tachograph .ddd upload, history export) must be blocked on
/// cellular connections and deferred with an inline message.
class WifiGate {
  const WifiGate({
    required this.wifiOnlyLargeSyncs,
    required this.onWifi,
    required this.online,
  });

  /// The user's Data Usage preference.
  final bool wifiOnlyLargeSyncs;

  /// Whether the device currently reports a Wi-Fi medium.
  final bool onWifi;

  /// Whether the device has network connectivity at all.
  final bool online;

  /// True when a large transfer must be blocked: the user opted into
  /// Wi-Fi-only and the device is online but NOT on Wi-Fi (offline transfers
  /// are blocked by their own connection gates anyway).
  bool get blocksLargeTransfer => wifiOnlyLargeSyncs && online && !onWifi;
}

/// Live [WifiGate] snapshot.
///
/// Unknown connectivity (before the first platform report) optimistically
/// counts as Wi-Fi so the gate never blocks a transfer on missing data.
final wifiGateProvider = Provider<WifiGate>((ref) {
  return WifiGate(
    wifiOnlyLargeSyncs: ref.watch(dataUsageProvider).wifiOnlyLargeSyncs,
    onWifi: ref.watch(isOnWifiProvider).value ?? true,
    online: !ref.watch(isOfflineProvider),
  );
});

/// Thrown when the Phase 4B Wi-Fi-only gate blocks a large transfer
/// (trip-history export, §4.10). Callers surface the inline message.
class WifiGateBlocked implements Exception {
  const WifiGateBlocked();
}
