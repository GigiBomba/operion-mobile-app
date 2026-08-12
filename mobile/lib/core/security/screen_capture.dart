import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MethodChannel;

/// Android `WindowManager.LayoutParams.FLAG_SECURE` (0x00002000).
const int _flagSecure = 0x00002000;

/// The `flutter_windowmanager` method channel, implemented locally in
/// `MainActivity.kt` (same contract as the abandoned pub package it replaces
/// — see the note there). Only FLAG_SECURE is exposed.
const MethodChannel _windowManagerChannel =
    MethodChannel('flutter_windowmanager');

/// Screen-capture prevention (blueprint §12).
///
/// Android: FLAG_SECURE via the `flutter_windowmanager` channel — applied
/// while a sensitive screen (invoice editor, CMR form) is visible and cleared
/// on dispose. Guarded for every failure mode: on non-Android platforms,
/// in tests, and on devices without the handler the calls are no-ops.
///
/// iOS: handled natively in `Runner/AppDelegate.swift` — a
/// `UIApplication.userDidTakeScreenshotNotification` / capture-did-change
/// observer flips a MethodChannel 'app_security' flag that the Flutter
/// `CaptureBlurOverlay` widget consumes to blur the screen. That path is
/// code-complete but DEVICE-REQUIRED for verification (documented like the
/// GPS precedent).
Future<void> enableSecureScreen() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    await _windowManagerChannel.invokeMethod<bool>(
      'addFlags',
      {'flags': _flagSecure},
    );
  } catch (_) {
    // Tests / unsupported devices: FLAG_SECURE is best-effort.
  }
}

/// Clears FLAG_SECURE when a protected screen is disposed.
Future<void> disableSecureScreen() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    await _windowManagerChannel.invokeMethod<bool>(
      'clearFlags',
      {'flags': _flagSecure},
    );
  } catch (_) {
    // Best-effort.
  }
}
