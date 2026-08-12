# Firebase Configuration — Operion Mobile

Gate-31 release-remediation item. The app already depends on `firebase_core`
(`^4.13.0`) and `firebase_messaging` (`^16.5.0`). What is missing is the
**operator-provided Firebase project configuration** plus the iOS APNs
capability. This document is the checklist for the person who owns the
Firebase console — none of these secrets/credentials belong in the repo.

## 1. What to create in the Firebase console

1. Go to <https://console.firebase.google.com/> and open (or create) the
   Operion project.
2. **Android app:** click **Add app → Android**. The Android package name is
   `com.operion.operion_mobile`. Register it and download **`google-services.json`**.
3. **iOS app:** click **Add app → iOS**. The iOS bundle ID is
   `com.operion.operionMobile` (see `ios/Runner.xcodeproj/project.pbxproj`
   `PRODUCT_BUNDLE_IDENTIFIER`). Register it and download
   **`GoogleService-Info.plist`**.
4. Do NOT commit either file. Both are environment/operator credentials and
   are expected to be injected by CI or placed manually on the build machine.

## 2. Where to place the files

| File | Location (inside the `mobile/` repo) |
|---|---|
| `google-services.json` | `mobile/android/app/google-services.json` |
| `GoogleService-Info.plist` | `mobile/ios/Runner/GoogleService-Info.plist` |

Both paths are the exact locations the build tools probe:

- The **google-services Gradle plugin** (applied in
  `android/app/build.gradle.kts`) looks for `google-services.json` in the
  **app module** directory (`android/app/`), not the repo root.
- **CocoaPods** (`firebase_core`) copies `GoogleService-Info.plist` into the
  Runner bundle from `ios/Runner/` at pod-install time.

## 3. Android — the expected fail-fast

The google-services Gradle plugin is now applied unconditionally
(`mobile/android/app/build.gradle.kts`). If `google-services.json` is missing,
**every** Gradle build — including the debug build — fails during app
configuration with:

```
* What went wrong:
Execution failed for task ':app:processDebugGoogleServices'.
> File google-services.json is missing. The Google Services Plugin cannot
  function without it.
     ...
> Searched location:
  ...\mobile\android\app\google-services.json
```

This is **intentional** (desired fail-fast): a debug build that accidentally
ships without Firebase config would silently run with a broken push pipeline.
Place the file and the failure disappears. To generate a fresh project file,
register the Android app in the Firebase console (§1) with package
`com.operion.operion_mobile`.

## 4. iOS — pod install, Firebase, and the APNs capability

1. **Pod install** — there is no committed `Podfile` (it is gitignored and
   generated on first build). From `mobile/`:

   ```sh
   # on macOS, with CocoaPods installed
   cd ios
   pod install
   ```

   This generates the `Podfile` + `Podfile.lock` and downloads
   `firebase_core` / `firebase_messaging`. If the `Podfile` already exists on
   your machine, ensure the `Firebase`/`FirebaseMessaging` pods are not
   commented out and re-run `pod install` after adding the plist.

2. **`GoogleService-Info.plist`** must sit at `ios/Runner/GoogleService-Info.plist`
   **before** the first `pod install`, so the Firebase pod copies it into the
   Runner target. After adding or updating it, re-run `pod install`.

3. **Push capability + `aps-environment` entitlement.** The project uses a
   **single shared entitlements file** (`ios/Runner/Runner.entitlements`,
   referenced by every build configuration in the Xcode project). Because
   `aps-environment` is *environment-specific* (development vs production),
   it must **not** be hardcoded into that shared file. Instead:

   - In Xcode → **Runner target → Signing & Capabilities → + Capability →
     Push Notifications**. Xcode auto-manages the value and provisions the
     correct `aps-environment` per build configuration, or
   - Use Xcode's **build-settings-based entitlements** for `aps-environment`
     (e.g. a `CODE_SIGN_ENTITLEMENTS` per configuration), or
   - Provide the value at signing time via the provisioning profile /
     `aps-environment` entitlement from the Apple Developer portal.

   `aps-environment` is **not** a plist key — adding it to `Info.plist` does
   nothing. The entitlement must be present on the signed app. With the
   capability enabled, the entitlement appears in
   `Runner.entitlements`/provisioning profile as:

   ```xml
   <key>aps-environment</key>
   <string>development</string>
   <!-- or "production" for store/TestFlight builds -->
   ```

4. **AppDelegate setup** — `AppDelegate.swift` already registers
   `FirebaseApp` and wires the FCM delegate per the current phase; no code
   change is required for this item.

## 5. Verify

- Android: `flutter build apk --debug` succeeds once
  `google-services.json` is present (missing file = the §3 fail-fast).
- iOS: `flutter build ios` on macOS, then confirm the archived app's
  entitlements include `aps-environment` (`codesign -d --entitlements -` on
  the `.app`), and send a test push via FCM console / `curl`.
