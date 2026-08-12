package com.operion.operion_mobile

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

  /**
   * Phase 3B — FLAG_SECURE screen-capture prevention (blueprint §12).
   *
   * Local replacement for the abandoned `flutter_windowmanager` plugin
   * (last published 2021, incompatible with the AGP 9 toolchain). Exposes the
   * SAME `flutter_windowmanager` method channel + `addFlags`/`clearFlags`
   * contract so `core/security/screen_capture.dart` is unchanged. Only
   * FLAG_SECURE (0x2000) is supported; unknown flags are rejected.
   */
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "flutter_windowmanager"
    ).setMethodCallHandler { call, result ->
      val flags = (call.argument<Number>("flags") ?: 0).toInt()
      if (flags != WindowManager.LayoutParams.FLAG_SECURE) {
        result.error(
          "FlutterWindowManagerPlugin",
          "Unsupported flag: " + Integer.toHexString(flags),
          null
        )
        return@setMethodCallHandler
      }
      val window = window ?: run {
        result.error("FlutterWindowManagerPlugin", "No window available", null)
        return@setMethodCallHandler
      }
      val current = window.attributes.flags
      val updated =
        if (call.method == "addFlags") current or flags else current and flags.inv()
      window.setFlags(updated, flags)
      result.success(true)
    }
  }
}
