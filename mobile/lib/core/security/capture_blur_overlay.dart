import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iOS screen-capture blur overlay (blueprint §12).
///
/// Android uses FLAG_SECURE (see [screen_capture.dart]); iOS cannot set
/// FLAG_SECURE, so the native side (`Runner/AppDelegate.swift`) observes
/// `UIScreen.capturedDidChangeNotification` / `userDidTakeScreenshotNotification`
/// and pushes the state over the `app_security` MethodChannel. This widget
/// consumes that channel and, while captured, blurs and dims its child so a
/// screen recording / mirror cannot leak sensitive invoice or CMR data.
///
/// Wrap a sensitive screen (invoice editor, CMR form) with this widget. The
/// live blur behavior is DEVICE-REQUIRED for verification (like the GPS
/// precedent) — the channel wiring itself is unit-tested.
class CaptureBlurOverlay extends StatefulWidget {
  const CaptureBlurOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<CaptureBlurOverlay> createState() => _CaptureBlurOverlayState();
}

class _CaptureBlurOverlayState extends State<CaptureBlurOverlay> {
  static const MethodChannel _channel = MethodChannel('app_security');
  bool _captured = false;

  @override
  void initState() {
    super.initState();
    if (!Platform.isIOS) return; // Android is covered by FLAG_SECURE.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'setCaptured') {
        final captured = call.arguments == true;
        if (mounted && captured != _captured) {
          setState(() => _captured = captured);
        }
      }
      return null;
    });
    // Sync with the native side (the app may launch already-captured).
    _channel.invokeMethod<bool>('getCaptured').then((value) {
      final captured = value == true;
      if (mounted && captured != _captured) {
        setState(() => _captured = captured);
      }
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    if (Platform.isIOS) {
      _channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_captured)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 48, color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Screen recording detected',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
