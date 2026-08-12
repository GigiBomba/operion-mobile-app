import 'package:flutter/material.dart';

/// Global [GlobalKey] attached to the root [MaterialApp] navigator.
///
/// Used by OS-integration services (quick actions, rich notification
/// actions, notification taps) that must push screens without owning a
/// [BuildContext] — e.g. when the app is launched cold from a home-screen
/// shortcut or a notification action.
///
/// The key is wired in `app.dart` (`MaterialApp(navigatorKey: ...)`).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Pushes a screen on the root navigator when the navigator is ready.
///
/// Returns `true` when the route was pushed, `false` when the navigator is
/// not yet mounted (e.g. during the very first frame before `runApp`).
bool pushOnRootNavigator(Widget page, {bool replace = false}) {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return false;
  final route = MaterialPageRoute<void>(builder: (_) => page);
  if (replace) {
    navigator.pushReplacement(route);
  } else {
    navigator.push(route);
  }
  return true;
}

/// Pops to the first route on the root navigator (used to clear the stack
/// before deep-linking into a shell tab).
void popRootToFirst() {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;
  navigator.popUntil((route) => route.isFirst);
}
