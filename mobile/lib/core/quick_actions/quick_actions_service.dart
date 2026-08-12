import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../features/dispatcher/alerts/alert_inbox_screen.dart';
import '../../features/dispatcher/jobs/job_list_screen.dart';
import '../../features/document_center/screens/document_center_screen.dart';
import '../auth/auth_providers.dart';
import '../i18n/app_localizations.dart';
import '../navigation/app_navigator.dart';

/// Test seam over the `quick_actions` plugin's instance-level API.
abstract class QuickActionsBridge {
  Future<void> initialize(QuickActionHandler handler);

  Future<void> setShortcutItems(List<ShortcutItem> items);
}

/// Default bridge delegating to the real plugin.
class QuickActionsBridgeImpl implements QuickActionsBridge {
  const QuickActionsBridgeImpl({QuickActions? actions})
      : _actions = actions ?? const QuickActions();

  final QuickActions _actions;

  @override
  Future<void> initialize(QuickActionHandler handler) =>
      _actions.initialize(handler);

  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) =>
      _actions.setShortcutItems(items);
}

/// Registers and routes the app's home-screen quick actions (§9.2).
///
/// Shortcuts:
/// - `approve_pending` → [JobListScreen] with the pending filter pre-applied.
/// - `alert_check`     → [AlertInboxScreen].
/// - `scan_document`   → [DocumentCenterScreen] straight into the camera /
///                       OCR automation tab (deep-links PAST the list).
///
/// Auth gating: when the shortcut fires before the session is restored, the
/// type is deferred and routed as soon as [authStateProvider] reaches
/// [AuthState.authenticated] (deferred routing survives the restore window).
class QuickActionService {
  QuickActionService({QuickActionsBridge? bridge, WidgetPusher? pusher})
      : _bridge = bridge ?? const QuickActionsBridgeImpl(),
        _pusher = pusher ?? _defaultPusher;

  /// Process-wide singleton (wired from `main()`).
  static final QuickActionService instance = QuickActionService();

  static const String approvePending = 'approve_pending';
  static const String alertCheck = 'alert_check';
  static const String scanDocument = 'scan_document';

  final QuickActionsBridge _bridge;
  final WidgetPusher _pusher;

  ProviderContainer? _container;
  String? _deferredShortcut;
  ProviderSubscription<AuthState>? _authSubscription;

  /// True when the plugin is initialized (test seam / guard).
  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Registers the three shortcuts and the callback. Call once from
  /// `main()` after the app's [ProviderContainer] exists.
  Future<void> initialize(ProviderContainer container) async {
    if (_initialized) return;
    _container = container;

    await _bridge.initialize(_onShortcut);
    final loc = AppLocalizations(container.read(localeProvider));
    await _bridge.setShortcutItems(_buildItems(loc));
    _initialized = true;

    // Deferred routing: a shortcut tapped while the session is still being
    // restored (or before login) is executed the moment auth completes.
    _authSubscription = container.listen<AuthState>(
      authStateProvider,
      (_, next) {
        if (next == AuthState.authenticated) {
          _maybeExecuteDeferred();
        }
      },
    );
  }

  /// The three registered shortcuts (R8 note: the Android icons are native
  /// drawable resources referenced by name — keep them in `res/drawable*` or
  /// the R8 shrinker will strip them from the merged manifest).
  List<ShortcutItem> _buildItems(AppLocalizations loc) {
    return [
      ShortcutItem(
        type: approvePending,
        localizedTitle: loc.quickAction_approvePending,
        localizedSubtitle: loc.quickAction_approvePendingSubtitle,
        icon: 'ic_quick_approve',
      ),
      ShortcutItem(
        type: alertCheck,
        localizedTitle: loc.quickAction_alertCheck,
        localizedSubtitle: loc.quickAction_alertCheckSubtitle,
        icon: 'ic_quick_alerts',
      ),
      ShortcutItem(
        type: scanDocument,
        localizedTitle: loc.quickAction_scanDocument,
        localizedSubtitle: loc.quickAction_scanDocumentSubtitle,
        icon: 'ic_quick_scan',
      ),
    ];
  }

  void _onShortcut(String type) {
    final container = _container;
    if (container == null) return;
    if (_isAuthenticated(container)) {
      _route(type, container);
    } else {
      _deferredShortcut = type;
      developer.log(
        'QuickActions: deferring "$type" until authenticated',
        name: 'QuickActions',
      );
    }
  }

  void _maybeExecuteDeferred() {
    final container = _container;
    final deferred = _deferredShortcut;
    if (container == null || deferred == null) return;
    // Keep the deferred shortcut until it can actually be routed — auth may
    // flip to `authenticated` a tick before `currentUserProvider` is set.
    if (!_isAuthenticated(container)) return;
    _deferredShortcut = null;
    _route(deferred, container);
  }

  bool _isAuthenticated(ProviderContainer container) {
    return container.read(authStateProvider) == AuthState.authenticated &&
        container.read(currentUserProvider) != null;
  }

  void _route(String type, ProviderContainer container) {
    switch (type) {
      case approvePending:
        _pushOrRetry(const JobListScreen(initialFilter: JobFilter.pending));
      case alertCheck:
        _pushOrRetry(const AlertInboxScreen());
      case scanDocument:
        _pushOrRetry(const DocumentCenterScreen(initialTab: 1));
      default:
        developer.log('QuickActions: unknown shortcut "$type"',
            name: 'QuickActions');
    }
  }

  void _pushOrRetry(Widget page) {
    // The navigator may not be attached during the very first frame of a
    // cold-start from a shortcut — retry briefly before giving up.
    if (!_pusher(page)) {
      _retryPush(page);
    }
  }

  void _retryPush(Widget page) {
    Timer(const Duration(milliseconds: 300), () {
      if (!_pusher(page)) {
        _retryPush(page);
      }
    });
  }

  void dispose() {
    _authSubscription?.close();
  }
}

/// Pushes [page] on the root navigator; returns `false` when the navigator
/// is not yet mounted (retry is handled by [QuickActionService]).
typedef WidgetPusher = bool Function(Widget page);

bool _defaultPusher(Widget page) => pushOnRootNavigator(page);
