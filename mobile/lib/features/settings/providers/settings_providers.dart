import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Persistence facade (Phase 4B, §4.10)
//
// Notification / data-usage / biometric-lock preferences are stored in
// [SharedPreferences] (client-side only — the backend knows nothing about
// them). The store never throws: when the platform channel is unavailable
// (e.g. widget tests without mock values) reads fall back to [fallback] and
// writes are no-ops.
// ---------------------------------------------------------------------------

/// Thin, exception-safe wrapper around [SharedPreferences].
class SettingsPrefsStore {
  SettingsPrefsStore(this._prefs);

  final Future<SharedPreferences> _prefs;

  Future<SharedPreferences?> get _instance async {
    try {
      return await _prefs;
    } catch (_) {
      return null;
    }
  }

  Future<bool> loadBool(String key, {required bool fallback}) async {
    final prefs = await _instance;
    return prefs?.getBool(key) ?? fallback;
  }

  Future<String> loadString(String key, {required String fallback}) async {
    final prefs = await _instance;
    return prefs?.getString(key) ?? fallback;
  }

  Future<void> saveBool(String key, bool value) async {
    final prefs = await _instance;
    await prefs?.setBool(key, value);
  }

  Future<void> saveString(String key, String value) async {
    final prefs = await _instance;
    await prefs?.setString(key, value);
  }
}

/// Provides the exception-safe [SharedPreferences] store.
final settingsPrefsStoreProvider = Provider<SettingsPrefsStore>((ref) {
  return SettingsPrefsStore(SharedPreferences.getInstance());
});

// ---------------------------------------------------------------------------
// Notification preferences
// ---------------------------------------------------------------------------

/// Per-severity push notification toggles + quiet-hours window (§4.10).
class NotificationPreferences {
  const NotificationPreferences({
    this.critical = true,
    this.warning = true,
    this.info = true,
    this.quietHoursEnabled = false,
    this.quietStart = '22:00',
    this.quietEnd = '07:00',
  });

  final bool critical;
  final bool warning;
  final bool info;
  final bool quietHoursEnabled;

  /// Quiet-hours start, 24h `HH:mm`.
  final String quietStart;

  /// Quiet-hours end, 24h `HH:mm`.
  final String quietEnd;

  NotificationPreferences copyWith({
    bool? critical,
    bool? warning,
    bool? info,
    bool? quietHoursEnabled,
    String? quietStart,
    String? quietEnd,
  }) {
    return NotificationPreferences(
      critical: critical ?? this.critical,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferences &&
          runtimeType == other.runtimeType &&
          critical == other.critical &&
          warning == other.warning &&
          info == other.info &&
          quietHoursEnabled == other.quietHoursEnabled &&
          quietStart == other.quietStart &&
          quietEnd == other.quietEnd;

  @override
  int get hashCode =>
      Object.hash(critical, warning, info, quietHoursEnabled, quietStart, quietEnd);
}

/// Persisted notification-preferences notifier (§4.10, all roles).
class NotificationPreferencesNotifier
    extends StateNotifier<NotificationPreferences> {
  NotificationPreferencesNotifier(this._ref)
      : super(const NotificationPreferences());

  final Ref _ref;

  static const _kCritical = 'notif_critical';
  static const _kWarning = 'notif_warning';
  static const _kInfo = 'notif_info';
  static const _kQuietEnabled = 'notif_quiet_hours_enabled';
  static const _kQuietStart = 'notif_quiet_start';
  static const _kQuietEnd = 'notif_quiet_end';

  /// Hydrates state from [SharedPreferences]; safe to call more than once.
  Future<void> load() async {
    final store = _ref.read(settingsPrefsStoreProvider);
    final next = NotificationPreferences(
      critical: await store.loadBool(_kCritical, fallback: true),
      warning: await store.loadBool(_kWarning, fallback: true),
      info: await store.loadBool(_kInfo, fallback: true),
      quietHoursEnabled: await store.loadBool(_kQuietEnabled, fallback: false),
      quietStart: await store.loadString(_kQuietStart, fallback: '22:00'),
      quietEnd: await store.loadString(_kQuietEnd, fallback: '07:00'),
    );
    if (mounted) state = next;
  }

  Future<void> setCritical(bool value) async {
    state = state.copyWith(critical: value);
    await _ref.read(settingsPrefsStoreProvider).saveBool(_kCritical, value);
  }

  Future<void> setWarning(bool value) async {
    state = state.copyWith(warning: value);
    await _ref.read(settingsPrefsStoreProvider).saveBool(_kWarning, value);
  }

  Future<void> setInfo(bool value) async {
    state = state.copyWith(info: value);
    await _ref.read(settingsPrefsStoreProvider).saveBool(_kInfo, value);
  }

  Future<void> setQuietHoursEnabled(bool value) async {
    state = state.copyWith(quietHoursEnabled: value);
    await _ref
        .read(settingsPrefsStoreProvider)
        .saveBool(_kQuietEnabled, value);
  }

  Future<void> setQuietStart(String value) async {
    state = state.copyWith(quietStart: value);
    await _ref
        .read(settingsPrefsStoreProvider)
        .saveString(_kQuietStart, value);
  }

  Future<void> setQuietEnd(String value) async {
    state = state.copyWith(quietEnd: value);
    await _ref.read(settingsPrefsStoreProvider).saveString(_kQuietEnd, value);
  }
}

final notificationPreferencesProvider = StateNotifierProvider<
    NotificationPreferencesNotifier, NotificationPreferences>((ref) {
  final notifier = NotificationPreferencesNotifier(ref);
  unawaited(notifier.load());
  return notifier;
});

// ---------------------------------------------------------------------------
// Data usage preferences
// ---------------------------------------------------------------------------

/// Data-usage preferences (§4.10): the Wi-Fi-only large-transfer gate.
class DataUsagePreferences {
  const DataUsagePreferences({this.wifiOnlyLargeSyncs = false});

  /// When true, large transfers (delta sync, tacho upload, history export)
  /// are blocked on cellular connections.
  final bool wifiOnlyLargeSyncs;

  DataUsagePreferences copyWith({bool? wifiOnlyLargeSyncs}) {
    return DataUsagePreferences(
      wifiOnlyLargeSyncs: wifiOnlyLargeSyncs ?? this.wifiOnlyLargeSyncs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataUsagePreferences &&
          runtimeType == other.runtimeType &&
          wifiOnlyLargeSyncs == other.wifiOnlyLargeSyncs;

  @override
  int get hashCode => wifiOnlyLargeSyncs.hashCode;
}

/// Persisted data-usage notifier (§4.10, all roles).
class DataUsageNotifier extends StateNotifier<DataUsagePreferences> {
  DataUsageNotifier(this._ref) : super(const DataUsagePreferences());

  final Ref _ref;

  static const _kWifiOnly = 'data_wifi_only_large_syncs';

  Future<void> load() async {
    final store = _ref.read(settingsPrefsStoreProvider);
    final next = DataUsagePreferences(
      wifiOnlyLargeSyncs: await store.loadBool(_kWifiOnly, fallback: false),
    );
    if (mounted) state = next;
  }

  Future<void> setWifiOnlyLargeSyncs(bool value) async {
    state = state.copyWith(wifiOnlyLargeSyncs: value);
    await _ref.read(settingsPrefsStoreProvider).saveBool(_kWifiOnly, value);
  }
}

final dataUsageProvider = StateNotifierProvider<DataUsageNotifier,
    DataUsagePreferences>((ref) {
  final notifier = DataUsageNotifier(ref);
  unawaited(notifier.load());
  return notifier;
});

// ---------------------------------------------------------------------------
// Biometric lock preferences (§12 + §4.10)
// ---------------------------------------------------------------------------

/// Biometric-lock preferences.
class BiometricLockPreferences {
  const BiometricLockPreferences({
    this.biometricUnlockEnabled = false,
    this.requireForFinancialActions = true,
  });

  /// Whether the login screen offers biometric unlock (§12).
  final bool biometricUnlockEnabled;

  /// Whether sensitive finance actions require a fresh §12 biometric
  /// confirmation. Default ON — the financial gate is always active unless
  /// the user explicitly turns it off.
  final bool requireForFinancialActions;

  BiometricLockPreferences copyWith({
    bool? biometricUnlockEnabled,
    bool? requireForFinancialActions,
  }) {
    return BiometricLockPreferences(
      biometricUnlockEnabled:
          biometricUnlockEnabled ?? this.biometricUnlockEnabled,
      requireForFinancialActions:
          requireForFinancialActions ?? this.requireForFinancialActions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiometricLockPreferences &&
          runtimeType == other.runtimeType &&
          biometricUnlockEnabled == other.biometricUnlockEnabled &&
          requireForFinancialActions == other.requireForFinancialActions;

  @override
  int get hashCode => Object.hash(biometricUnlockEnabled, requireForFinancialActions);
}

/// Persisted biometric-lock notifier (§12, all roles).
class BiometricLockNotifier extends StateNotifier<BiometricLockPreferences> {
  BiometricLockNotifier(this._ref) : super(const BiometricLockPreferences());

  final Ref _ref;

  static const _kUnlock = 'biometric_unlock_enabled';
  static const _kFinancial = 'biometric_require_financial';

  Future<void> load() async {
    final store = _ref.read(settingsPrefsStoreProvider);
    final next = BiometricLockPreferences(
      biometricUnlockEnabled:
          await store.loadBool(_kUnlock, fallback: false),
      requireForFinancialActions:
          await store.loadBool(_kFinancial, fallback: true),
    );
    if (mounted) state = next;
  }

  Future<void> setBiometricUnlockEnabled(bool value) async {
    state = state.copyWith(biometricUnlockEnabled: value);
    await _ref.read(settingsPrefsStoreProvider).saveBool(_kUnlock, value);
  }

  Future<void> setRequireForFinancialActions(bool value) async {
    state = state.copyWith(requireForFinancialActions: value);
    await _ref.read(settingsPrefsStoreProvider).saveBool(_kFinancial, value);
  }
}

final biometricLockProvider = StateNotifierProvider<BiometricLockNotifier,
    BiometricLockPreferences>((ref) {
  final notifier = BiometricLockNotifier(ref);
  unawaited(notifier.load());
  return notifier;
});
