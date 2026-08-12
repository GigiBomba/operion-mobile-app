# Convenience Layer — Manual Device Verification Pass (Blueprint Phase 5, §9 / §13.6)

> **Status:** CHECKLIST — requires a physical/simulated device pass before the Phase-5 release gate.
> **Scope:** home-screen widgets, quick actions, rich push notifications with inline actions, and the
> §9 item-8 regression check (background task / push interplay with driver GPS tracking).
> **Automated coverage exists for all logic paths** (see the test inventory below); the items on this
> checklist are the OS-integration behaviors that cannot be fully verified in CI (Windows dev
> environment: no iOS build, no physical devices).

## 1. Environment Limitations (honest, per the GPS-precedent)

| Item | Limitation | Status |
|---|---|---|
| iOS build | `flutter build ipa` requires macOS/Xcode — not available in this environment | Code-complete (WidgetKit SwiftUI sources, App Group entitlements, AppDelegate registrant); **DEVICE-REQUIRED** |
| iOS widget live behavior | WidgetKit renders in a separate process; cannot be exercised from Windows | **DEVICE-REQUIRED** |
| Notification inline actions when app TERMINATED | Headless isolate has no secure-storage access (FlutterSecureStorage is process-bound) — actions are persisted and executed on the next authenticated launch by design | Documented limitation; behavior verified by unit tests (persistence + drain) |
| Android 12+ trampoline | `showsUserInterface: true` actions require a foreground context; background actions are headless by OS design | Mitigated: View action is foreground-optimized; Approve/Snooze execute headless with deferred auth |

## 2. Device Matrix (§13.6)

| Dimension | Coverage required |
|---|---|
| Android OS | 10, 12, 14 (minSdk → current target) |
| iOS OS | Last 3 major versions (deployment target 13.0) |
| Device tiers | 1× low-end Android (2–3GB), 1× mid-range (4GB), 1× flagship, 1× recent iPhone, 1× tablet (Android or iPad — for widget + master-detail) |
| Network | Wi-Fi, 4G, airplane-mode toggle |
| Locale | Romanian (primary) + English |

## 3. Home-Screen Widgets — Checklist

**Data source:** widget data pushed from the app (main isolate) — Today's KPIs (active jobs, open alerts,
revenue-to-date) for dispatcher/manager; next-stop/active-trip for driver.

- [ ] Android: dispatcher/manager KPI widget renders (AppWidgetProvider wired via home_widget bridge)
- [ ] Android: driver widget renders (next-stop / active trip)
- [ ] iOS: WidgetKit widget renders (TimelineView reading the App Group)
- [ ] Data refreshes on the documented cadence (15-min in-app timer while app alive)
- [ ] Data refreshes on push-triggered refresh (data-only FCM message while app alive)
- [ ] Data refreshes after job/alert approve–reject events
- [ ] App fully terminated → widget shows last-pushed data (expected — no authenticated background fetch; documented)
- [ ] Tapping the widget opens the app (launch intent)
- [ ] Tablet widget layout acceptable (if tablet widget added)

## 4. Quick Actions (App Icon Shortcuts) — Checklist

- [ ] Long-press app icon → 3 shortcuts visible (Approve pending jobs / New alert check / Scan document)
- [ ] "Approve pending jobs" → Jobs list with the **Pending** filter pre-applied (past the shell)
- [ ] "New alert check" → Alerts inbox
- [ ] "Scan document" → Document Center camera tab (past the list)
- [ ] Cold start via shortcut (app not running) → routes after session restore (auth-gated deferral)
- [ ] Shortcut icons survive release builds (R8 keep rules)

## 5. Rich Push Notifications with Inline Actions — Checklist

- [ ] Alert push (data-only) displays a notification with **Approve / Snooze / View** actions
- [ ] **Approve** (app foreground) → calls the same `approveAction` endpoint as the in-app screen; alert state updates
- [ ] **Approve** (app backgrounded, engine alive) → executes immediately
- [ ] **Approve** (app terminated) → action persisted; executes on next authenticated launch (documented deferral)
- [ ] **Snooze** → notification re-shown after ~15 min **without** a Snooze action (no loop)
- [ ] **View** → opens the alert/approval detail screen
- [ ] Tap on the notification body (no action) → routes via the existing router to the alert detail
- [ ] No duplicate notifications on iOS 18 foreground (message-id dedupe)
- [ ] GPS foreground-service notification (driver) coexists with alert notifications (distinct channels)

## 6. §9 item-8 — Background/Push Interplay with Driver GPS Tracking

- [ ] Driver role: GPS turn-by-turn + foreground service continues while alert notifications arrive
- [ ] Approving an alert from the notification does not interfere with the navigation foreground service
- [ ] Widget refresh timer does not run in background isolates (main-isolate only — zero background draw)

## 7. Sign-off

| Device | OS | Date | Widgets | Quick actions | Notifications | GPS interplay | Tester |
|---|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |  |

## 8. Automated Coverage Inventory (already green — `flutter test` 2269/2269, analyze 452)

- Notification routing/persistence/dedupe: 13 tests (incl. headless persistence + drain on next authenticated launch)
- Quick actions deep-link routing + auth-gate deferral: 7 tests
- Widget data-push helper + defensive parse (incl. missing `revenue_to_date`): 9 tests
- Background handler registration: 7 static tests
- RecordMaintenanceIntent (voice quick-capture): 11 tests incl. `identical()` same-function proof
- Tablet master-detail completion (8 screens @800dp + phone @390dp): 11 tests
- Reachability audit (primary actions bottom two-thirds): 4 tests
- Golden light+dark: 38 screen PNGs incl. the 6 Phase-5 gap-fills

> Counts verified by the independent Phase-5 re-verification pass (2026-08-03); l10n parity 681/681.
