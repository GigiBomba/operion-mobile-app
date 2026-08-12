import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../features/settings/providers/settings_providers.dart';

/// How long a successful confirmation stays valid before the next sensitive
/// action re-prompts (blueprint §12). In-memory only — a process restart
/// always prompts again.
const Duration kBiometricGraceWindow = Duration(minutes: 5);

/// Signature of the actual biometric/PIN check.
///
/// Injectable so tests can mock success/failure and count prompts without
/// touching the platform channel.
typedef BiometricAuthenticator = Future<bool> Function(String reason);

/// Gate for sensitive finance actions (blueprint §12).
///
/// - Prompts with `biometricOnly: false` so the user can fall back to the
///   device PIN/passcode (§12 requirement — a blocked biometric must never
///   strand a legitimately-authorized user).
/// - Enforces a 5-minute in-memory grace window: repeated sensitive actions
///   within [kBiometricGraceWindow] of a successful confirmation skip the
///   re-prompt.
/// - [skipConfirmation] (Phase 4B, §4.10): when provided and returning
///   `true`, the check short-circuits to "confirmed". Wired to the persisted
///   "require biometric for financial actions" toggle — default ON, so the
///   gate stays active unless the user explicitly disables it.
///
/// Callers MUST invoke [requireBiometricConfirmation] *before* any network
/// call for finalize/mark-paid transitions and CMR signature saves —
/// the API must be unreachable without a successful check (proven by tests).
class BiometricGate {
  BiometricGate({
    BiometricAuthenticator? authenticate,
    DateTime Function()? now,
    this.skipConfirmation,
  })  : _now = now ?? DateTime.now,
        _authenticate = authenticate ?? _defaultAuthenticator;

  final DateTime Function() _now;
  final BiometricAuthenticator _authenticate;

  /// Phase 4B financial-gate override (§4.10); `null` keeps the gate on.
  final bool Function()? skipConfirmation;

  /// Timestamp of the last successful confirmation (grace-window basis).
  DateTime? _lastConfirmedAt;

  /// Default localized prompt when the caller does not supply a reason.
  static const String defaultReason =
      'Authenticate to confirm this sensitive action';

  /// Returns `true` when the action may proceed:
  ///
  /// 0. The §4.10 "require biometric for financial actions" toggle is OFF
  ///    (short-circuit — no prompt, no grace recording).
  /// 1. A prior successful confirmation happened within [kBiometricGraceWindow]
  ///    (no re-prompt), or
  /// 2. The user just successfully authenticated via biometrics or the device
  ///    PIN/passcode fallback.
  ///
  /// Returns `false` when the user cancels, biometrics are unavailable, or
  /// authentication fails.
  Future<bool> requireBiometricConfirmation({String? reason}) async {
    if (skipConfirmation?.call() ?? false) return true;

    final last = _lastConfirmedAt;
    if (last != null && _now().difference(last) < kBiometricGraceWindow) {
      return true; // Grace window: skip the re-prompt.
    }

    final ok = await _authenticate(reason ?? defaultReason);
    if (ok) {
      _lastConfirmedAt = _now();
    }
    return ok;
  }

  /// Drops the grace window so the next sensitive action re-prompts.
  ///
  /// Used on logout and by tests to simulate grace expiry.
  void resetGraceWindow() => _lastConfirmedAt = null;

  static Future<bool> _defaultAuthenticator(String reason) async {
    try {
      final auth = LocalAuthentication();
      final deviceSupported = await auth.isDeviceSupported();
      var available = deviceSupported;
      if (!available) {
        available = await auth.canCheckBiometrics;
      }
      if (!available) return false;
      return await auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // PIN/passcode fallback — §12 explicitly allows it.
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } on Exception {
      // Cancellation, lockout, unavailable — treat as "not confirmed".
      return false;
    }
  }
}

/// Provides the singleton [BiometricGate] (real local_auth path).
///
/// Wired to the Phase 4B §4.10 "require biometric for financial actions"
/// toggle: when disabled, [BiometricGate.requireBiometricConfirmation]
/// short-circuits to `true` (no prompt). Default ON.
final biometricGateProvider = Provider<BiometricGate>((ref) {
  return BiometricGate(
    skipConfirmation: () =>
        !ref.read(biometricLockProvider).requireForFinancialActions,
  );
});
