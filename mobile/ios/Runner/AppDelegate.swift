import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var appSecurityChannel: FlutterMethodChannel?
  private var isCaptured = UIScreen.main.isCaptured

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Phase 5A rich notifications (§9.3): flutter_local_notifications needs
    // the plugin registrant callback so inline-action taps that launch the
    // app cold (notification actions + Darwin notification responses) can
    // reach the Dart `onDidReceiveNotificationResponse` handler.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // ── Blueprint §12: iOS screen-capture prevention bridge ──────────
    // Observes UIScreen.capturedDidChangeNotification (screen recording /
    // AirPlay mirroring) and UIApplication.userDidTakeScreenshotNotification,
    // then pushes the capture state to the Flutter 'app_security'
    // MethodChannel. The Dart-side CaptureBlurOverlay widget (see
    // core/security/capture_blur_overlay.dart) blurs the sensitive finance
    // screens (invoice editor, CMR form) while captured.
    //
    // NOTE: code-complete, but live verification is DEVICE-REQUIRED — the
    // blur must be eyeballed on physical hardware (screen recording + the
    // invoice editor). Same limitation class as the GPS precedent
    // (blueprint §7.2.4(c)).
    appSecurityChannel = FlutterMethodChannel(
      name: "app_security",
      binaryMessenger: engineBridge.applicationRegistrar.messenger
    )
    // Initial state (the app can be launched while a capture is already active).
    appSecurityChannel?.invokeMethod("setCaptured", arguments: isCaptured)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(captureStateChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(captureStateChanged),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
  }

  @objc private func captureStateChanged() {
    let captured = UIScreen.main.isCaptured
    guard captured != isCaptured else { return }
    isCaptured = captured
    appSecurityChannel?.invokeMethod("setCaptured", arguments: captured)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
