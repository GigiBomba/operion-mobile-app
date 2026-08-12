# operion_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase (push notifications) — operator checklist

The app uses `firebase_core` + `firebase_messaging`. The config files are
**not** committed and must be placed by the operator (see
[`docs/firebase-config.md`](../docs/firebase-config.md) for the full steps):

- `android/app/google-services.json` — required; without it the Gradle build
  fails fast with *"File google-services.json is missing."*
- `ios/Runner/GoogleService-Info.plist` — required for iOS builds.

**APNs entitlement note:** `aps-environment` is an *entitlement*, not a plist
key. The project uses a single shared `ios/Runner/Runner.entitlements` for all
build configurations, so `aps-environment` must **not** be hardcoded there —
enable the **Push Notifications** capability in Xcode (Signing & Capabilities)
so Xcode provisions the correct per-configuration value (development vs
production), as described in `docs/firebase-config.md` §4.
