# Firebase Setup — 10-Minute Walkthrough (push notifications)

> You chose to set up Firebase so the app's alert/approval **push notifications** work.
> The code is fully built (mobile receive side + backend `PushSender`); what's missing are
> **config files only you can download** (they're generated inside your Google account).
> Until these files exist: Android APK builds **fail fast by design** (see note at the end);
> desktop/CI tests are unaffected.

## What Firebase does here
The backend asks Google's push servers to deliver a notification to each registered phone
(e.g. an alert with Approve/Snooze/View buttons). No Firebase = no phone notifications
(in-app alerts still work).

## Steps

### 1. Create the project
1. Go to **console.firebase.google.com** (sign in with any Google account — free tier).
2. **Add project** → name it (e.g. `operion`) → Analytics can be **disabled** (we don't need it) → Create.

### 2. Register the Android app + get `google-services.json`
1. In the project, tap the **Android** icon (or Add app → Android).
2. Package name: **`com.operion.operion_mobile`** (exact — check `mobile/android/app/build.gradle.kts`).
3. Download **`google-services.json`** → save it to **`mobile/android/app/google-services.json`**.
4. You can skip the "add the SDK" steps — already done in the code.

### 3. Register the iOS app + get `GoogleService-Info.plist` (only needed if you ship iOS)
1. Add app → **iOS**.
2. Bundle ID: **`com.operion.operionMobile`** (exact — check `mobile/ios/Runner/Info.plist`).
3. Download **`GoogleService-Info.plist`** → save it to **`mobile/ios/Runner/GoogleService-Info.plist`**.
4. iOS APNs: in Firebase → Project settings → Cloud Messaging → **Apple app configuration** →
   upload an APNs Auth Key from your Apple Developer account (iOS-only; skip until you do iOS).

### 4. Backend sender credential (the service account)
The backend's `PushSender` needs a private key to talk to Firebase:
1. Firebase → **Project settings** → **Service accounts** tab.
2. **Generate new private key** → download the JSON file.
3. Give the backend this file: either set the env var
   `OPERION_FIREBASE_CREDENTIALS` to the file's path (server-side), or set
   `GOOGLE_APPLICATION_CREDENTIALS` to the path.
4. Restart the backend. No credentials → the sender stays a safe no-op (nothing breaks).

## When you're done
Tell me (or open a session) and I will:
1. Verify both config files exist + wire any remaining platform bits (iOS `Podfile` + `pod install` on a Mac).
2. Run the verification: tokens register via `POST /mobile/devices/register`, and a test alert
   actually arrives on the phone with the Approve/Snooze/View actions.
3. Update the readiness checklist.

## Note: Android builds fail-fast until `google-services.json` exists
By design (Gate-31), the Gradle build **refuses to build an APK** without the file, so a
missing config can't silently ship a push-less app. Desktop (`flutter test`/Windows) and CI
tests don't need it. The moment you drop the file in place, Android builds work again.

## Also see
- `docs/sentry-setup.md` — crash reporting (separate, optional, inert until configured).
- `docs/implementation-status-and-production-readiness.md` — full readiness checklist.
