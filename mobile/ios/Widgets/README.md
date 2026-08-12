# Phase 5A — iOS WidgetKit (code-complete, DEVICE-REQUIRED)

iOS home-screen widgets CANNOT run Dart. Per the plugin contract, widget data is
pushed from the app via `HomeWidget.saveWidgetData` / `HomeWidget.updateWidget`
into the shared App Group; the widget extension only renders that last-known
data.

## What is already in the repo (code-complete)

| File | Purpose |
|------|---------|
| `Runner/Runner.entitlements` | App Group `group.com.operion.operionMobile` (also referenced by the app build settings). |
| `Widgets/OperionWidget.swift` | "Today's KPIs" widget (active jobs / open alerts / revenue MTD) + shared `OperionWidgetGroup.id`. |
| `Widgets/OperionWidgetsBundle.swift` | `WidgetBundle` registering both widgets (`OperionWidget` + `OperionDriverWidget`). |
| `Runner/AppDelegate.swift` | `FlutterLocalNotificationsPlugin.setPluginRegistrantCallback` (rich-notification action cold-start). |

## Remaining Xcode steps (ONE-TIME, must be done on macOS)

Windows cannot build iOS targets, so the widget **extension target** must be
created in Xcode on a Mac:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File ▸ New ▸ Target… ▸ Widget Extension** (or **App Extension ▸ WidgetKit
   Extension**), name it `Widgets`, bundle id `com.operion.operionMobile.Widgets`.
   - Delete the generated `Widget.swift`; add the repo files
     `ios/Widgets/OperionWidget.swift` and `ios/Widgets/OperionWidgetsBundle.swift`
     to the new target (uncheck the app target on both).
   - The new target needs its own Info.plist (Xcode generates one).
3. **App Group capability** on BOTH targets (Signing & Capabilities ▸ + App
   Groups) with `group.com.operion.operionMobile`.
4. The main app target already has `CODE_SIGN_ENTITLEMENTS =
   Runner/Runner.entitlements`; verify the extension target has its own
   entitlements containing the same App Group.
5. Set the widget extension deployment target to iOS 17+ (TimelineProvider).

## Live behavior verification (DEVICE-REQUIRED)

- Add the "Operion Today" / "Operion Trip" widgets to the home screen.
- Launch the app signed in as dispatcher → widget shows KPIs (push refresh).
- Tap the widget → app opens.
- Push an alert while the app runs → widget KPI refresh (push-triggered).
- **Known limitation (documented):** after force-quit, the widget shows the
  last-known data until the next app run — a background isolate has no access
  to the encrypted token store to refresh KPIs (same limitation class as the
  GPS background precedent).
