import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reactive connectivity monitor that wraps [connectivity_plus].
///
/// Exposes:
/// - [isOnline] – a synchronous snapshot of the current state.
/// - [onConnectivityChanged] – a broadcast stream that emits `true` (online)
///   or `false` (offline) whenever the network state changes.
/// - [connectivityType] – the last known [ConnectivityResult] (`null` before
///   the first platform report).
/// - [onTypeChanged] – a broadcast stream that emits the current type
///   whenever it changes (Phase 4B Wi-Fi-only gate, §4.10).
///
/// The initial state is optimistically `true`; after [initialize] completes,
/// it reflects the actual platform-reported state.
class ConnectivityMonitor {
  final Connectivity _connectivity;
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();
  final StreamController<ConnectivityResult?> _typeController =
      StreamController<ConnectivityResult?>.broadcast();

  StreamSubscription? _connectivitySubscription;
  bool _isOnline = true;
  ConnectivityResult? _type;

  /// Whether the device currently has network connectivity.
  bool get isOnline => _isOnline;

  /// The last reported [ConnectivityResult], or `null` when the platform has
  /// not reported yet (Phase 4B).
  ConnectivityResult? get connectivityType => _type;

  /// Broadcast stream that fires `true` (online) or `false` (offline).
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Broadcast stream that fires whenever the connectivity *type* changes
  /// (e.g. mobile → Wi-Fi). Used by the Wi-Fi-only large-transfer gate.
  Stream<ConnectivityResult?> get onTypeChanged => _typeController.stream;

  ConnectivityMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// Initialises the monitor by reading the current connectivity state and
  /// listening for further changes.
  ///
  /// Must be called once before using [onConnectivityChanged].
  Future<void> initialize() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateState(results);
    } catch (e) {
      developer.log(
        'ConnectivityMonitor.initialize: $e',
        name: 'ConnectivityMonitor',
      );
      // Keep optimistic true on failure so the app is not blocked.
    }

    // Listen for ongoing connectivity changes.
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      _updateState(results);
    });
  }

  /// Updates the internal state and fires the stream when the value changes.
  void _updateState(List<ConnectivityResult> results) {
    // Online if at least one result is NOT ConnectivityResult.none.
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      developer.log(
        'ConnectivityMonitor: ${online ? "online" : "offline"}',
        name: 'ConnectivityMonitor',
      );
      _controller.add(online);
    }

    // Prefer a concrete transport (Wi-Fi first, then any non-none) so the
    // Wi-Fi-only gate sees the real medium.
    final type = results.firstWhere(
      (r) => r == ConnectivityResult.wifi,
      orElse: () => results.firstWhere(
        (r) => r != ConnectivityResult.none,
        orElse: () => ConnectivityResult.none,
      ),
    );
    if (type != _type) {
      _type = type;
      _typeController.add(type);
    }
  }

  /// Tears down the stream controller.
  ///
  /// After calling this the monitor should no longer be used.
  void dispose() {
    // Defensive: pure-Dart tests (no binding) may never have established the
    // platform subscription; cancelling a lazy EventChannel subscription there
    // throws on the missing binary messenger.
    try {
      _connectivitySubscription?.cancel();
    } catch (_) {
      _connectivitySubscription = null;
    }
    _controller.close();
    _typeController.close();
  }
}

// ── Riverpod providers ───────────────────────────────────────────────

/// Provides the singleton [ConnectivityMonitor] instance.
final connectivityProvider = Provider<ConnectivityMonitor>((ref) {
  final monitor = ConnectivityMonitor();
  monitor.initialize();
  ref.onDispose(() => monitor.dispose());
  return monitor;
});

/// Reactive online/offline stream backed by [connectivityProvider].
///
/// Emits `true` when the device goes online, `false` when it goes offline.
/// The initial value is obtained by calling [ConnectivityMonitor.initialize]
/// inside a [ref.onResume] or app-startup logic.
final isOnlineProvider = StreamProvider<bool>((ref) {
  final monitor = ref.watch(connectivityProvider);
  return monitor.onConnectivityChanged;
});

/// Reactive "currently on Wi-Fi" stream (Phase 4B, §4.10).
///
/// Emits `true` while the device reports a Wi-Fi medium and `false`
/// otherwise. The current type is yielded immediately so callers never wait
/// for the first platform event; before the first report the optimistic
/// value is `true` (never block a transfer on unknown connectivity).
final isOnWifiProvider = StreamProvider<bool>((ref) async* {
  final monitor = ref.watch(connectivityProvider);
  yield monitor.connectivityType == ConnectivityResult.wifi;
  yield* monitor.onTypeChanged.map((t) => t == ConnectivityResult.wifi);
});
