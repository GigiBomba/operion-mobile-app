# Operion Mobile Restructure — Implementation Plan

**Source:** `Operion_Mobile_Restructure_Blueprint.md` (999 lines, authoritative)
**Codebase:** `mobile/` (Flutter 3.12+, Dart 3.12+, Riverpod, Dio, flutter_map, FCM, RO/EN l10n)
**Backend:** Not present in this repo (`Calculator logistica/` not found — Phase 0 deferred)
**Date:** 2026-07-19

---

## Table of Contents

- [0. Codebase State (What Exists)](#0-codebase-state-what-exists)
- [1. Phase Structure](#1-phase-structure)
- [2. Phase 1 — Navigation Restructure](#2-phase-1--navigation-restructure)
  - [Batch 1A — Role Model Refactor](#batch-1a--role-model-refactor)
  - [Batch 1B — I18n Keys](#batch-1b--i18n-keys)
  - [Batch 1C — Copilot Screen I18n Cleanup + Rename](#batch-1c--copilot-screen-i18n-cleanup--rename)
  - [Batch 1D — Driver Shell Rewrite](#batch-1d--driver-shell-rewrite)
  - [Batch 1E — Dispatcher Shell Rewrite + MoreHubScreen](#batch-1e--dispatcher-shell-rewrite--morehubscreen)
  - [Batch 1F — Existing Test Updates](#batch-1f--existing-test-updates)
- [3. Phase 2 — Driver Features](#3-phase-2--driver-features)
- [4. Phase 3 — Dispatcher/Manager Feature Ports](#4-phase-3--dispatchermanager-feature-ports)
- [5. Phase 4 — AI Copilot Wiring + RBAC](#5-phase-4--ai-copilot-wiring--rbac)
- [6. Phase 5 — Full Regression & Sign-Off](#6-phase-5--full-regression--sign-off)
- [7. File Change Summary](#7-file-change-summary)
- [8. Risks & Dependencies](#8-risks--dependencies)

---

## 0. Codebase State (What Exists)

The existing Flutter app at `mobile/` is well-architected and mature, not a scaffolding:

### Core Layer (`lib/core/`)

| Module | Files | Status |
|--------|-------|--------|
| Auth | `auth_providers.dart`, `mode_router.dart`, `role_resolver.dart`, `auth_service.dart`, `token_manager.dart`, `biometric_service.dart` | ✅ Full: login, session restore, biometric, force-logout, JWT refresh |
| Network | `api_client.dart`, `auth_interceptor.dart`, `websocket_client.dart`, `message_bus.dart`, `endpoints/` (8 endpoint files) | ✅ Dio singleton, auth interceptor with 401→refresh, WebSocket |
| Theme | `app_colors.dart`, `app_theme.dart`, `app_spacing.dart`, `app_typography.dart` | ✅ Indigo #6366F1, Inter font, Material 3 light/dark |
| Storage | `secure_token_store.dart`, `local_db.dart` | ✅ flutter_secure_storage + local DB abstraction |
| Sync/Offline | `connectivity_monitor.dart`, `delta_sync_service.dart`, `action_queue.dart`, `conflict_handler.dart`, `sync_providers.dart` | ✅ Full offline queue with idempotency |
| Notifications | `push_service.dart`, `notification_router.dart`, `device_registration.dart`, `notification_providers.dart` | ✅ Firebase Messaging + tap routing |
| i18n | `app_localizations.dart` (`context.loc` extension) | ✅ RO/EN via flutter_localizations |

### Feature Layer (`lib/features/`)

| Feature | Files | Key Contents |
|---------|-------|-------------|
| Auth | `login_screen.dart`, `session_expired_screen.dart` | Email/password + biometric unlock |
| Driver | `driver_shell.dart`, `home/`, `transports/`, `messages/`, `documents/`, `expenses/`, `vehicle/`, `notifications/`, `profile/` | 4-tab shell, full transport lifecycle, document upload, expenses, vehicle info, messaging |
| Dispatcher | `dispatcher_shell.dart`, `home/`, `fleet/`, `jobs/`, `drivers/`, `alerts/`, `analytics/` | 5-tab shell, fleet map (flutter_map + OSM), KPI dashboard, job management |
| Copilot | `screens/copilot_screen.dart`, `providers/copilot_providers.dart`, `models/copilot_models.dart`, `voice/copilot_voice_handler.dart`, `widgets/` | Full state machine (Idle→Processing→AwaitingConfirmation→Executing→Completed), chat UI, confirmation sheet |
| Settings | `settings_screen.dart` | Language/theme selectors, logout |

### Shared Layer (`lib/shared/`)

| Module | Count | Examples |
|--------|-------|---------|
| Models | 10 | `user`, `transport`, `driver`, `vehicle`, `document`, `message`, `alert`, `expense`, `fleet_position`, `sync_cursor` |
| Widgets | 9 | `AppButton`, `AppCard`, `AppTextField`, `ConfirmationDialog`, `EmptyState`, `OfflineBanner`, `ShimmerLoader`, `StalenessIndicator`, `StatusBadge` |

### Test Layer (`test/`)

25+ test files covering: core services (token_manager, auth_service, auth_interceptor, local_db, biometric_service, api_endpoints), feature screens (driver, dispatcher, auth, copilot), widget tests, connectivity, offline queue, sync service, i18n.

---

## 1. Phase Structure

### Engineering Standards (Blueprint §1, applies to all phases)

- New Flutter features live under `lib/features/<name>/{screens,providers,widgets,models}/`
- One `AsyncNotifier`/`StateNotifier` per screen-level concern
- No business logic in `build()` — calculations in providers or pure Dart helpers
- No magic strings — use enums/constants
- Every new network call: loading state (`ShimmerLoader`), error state (retry action), empty state (`EmptyState`), pull-to-refresh
- `CancelToken` per in-flight request, tied to widget lifecycle
- **Zero hardcoded UI strings** — all through `t()` backed by `ro.json` and `en.json`
- Only `AppColors`, `AppTheme`, `AppTypography`, `AppSpacing`, `AppRadius` — no ad hoc hex colors
- Reuse existing shared widgets before building new ones
- Test files mirror `lib/` structure under `test/`
- Tests must fail before fix and pass after — paste both outputs
- `Idempotency-Key` header for any mutation with real-world side effects
- Multi-tenant isolation: no client-supplied `company_id` — always from JWT

### Phase Dependencies

```
Phase 1 (Navigation) ──► Phase 2 (Driver) ──► Phase 3 (Manager) ──► Phase 4 (Copilot) ──► Phase 5 (Regression)
       │                       │                     │                       │
       │                       │                     │                       └── Depends on Phase 0 (RBAC audit)
       │                       │                     └── Depends on Phase 1 (shells/structure in place)
       │                       └── Depends on Phase 1 (shells/tabs in place)
       └── No backend dependency
```

**Phase 0 (Audit) is blocked** — the `Calculator logistica/` backend repo is not present in this codebase. OD-1 through OD-5 require the actual backend code or a running staging environment. Phase 1 has zero backend dependencies and can proceed immediately.

---

## 2. Phase 1 — Navigation Restructure

**Blueprint ref:** §3 (Role Model), §4 (Navigation Redesign), §12 Phase 1
**Goal:** Both shells restructured to 4-tab layouts, new `MoreHubScreen`, role model refactored
**Files:** 8 new, 9 modified, 1 deleted = **18 files total**
**Tests:** 4 new test files, ~25 test cases

### Target Shells

#### Manager Shell (4 tabs)

| Tab | Screen | i18n Key | Status |
|-----|--------|----------|--------|
| 1. Overview | `DispatcherHomeScreen` (unchanged) | `nav.overview` | ✅ Exists |
| 2. Fleet Tracker | `FleetMapScreen` (unchanged) | `nav.fleetTracker` | ✅ Exists |
| 3. AI Copilot | `CopilotChatScreen` (rename + i18n) | `nav.copilot` | 🟡 Needs work |
| 4. More | `MoreHubScreen` (new) | `nav.more` | ❌ New |

#### Driver Shell (4 tabs)

| Tab | Screen | i18n Key | Status |
|-----|--------|----------|--------|
| 1. Map | `RouteShareNavScreen` (Phase 2) | `nav.map` | ❌ Placeholder in P1 |
| 2. Overview | `DriverTripOverviewScreen` (Phase 2) | `nav.overview` | ❌ Placeholder in P1 |
| 3. AI Copilot | `CopilotChatScreen` (shared) | `nav.copilot` | 🟡 Needs work |
| 4. Settings | `SettingsScreen` (unchanged) | `nav.settings` | ✅ Exists |

### MoreHubScreen 11 Tiles

| # | Tile | i18n Key | Screen | Exists? |
|---|------|----------|--------|---------|
| 1 | Messages | `nav.messages` | `MessageListScreen` | ✅ |
| 2 | Teams | `nav.teams` | `DriverListScreen` (relabel) | ✅ |
| 3 | Analytics | `nav.analytics` | `DispatcherAnalyticsScreen` | ✅ |
| 4 | Jobs | `nav.jobs` | `JobListScreen` (was tab) | ✅ |
| 5 | Alerts | `nav.alerts` | `AlertInboxScreen` (was tab) | ✅ |
| 6 | Profit Calculator | `nav.profitCalculator` | Placeholder → Phase 3 | ❌ |
| 7 | Route Planner | `nav.routePlanner` | Placeholder → Phase 3 | ❌ |
| 8 | Freight Exchange | `nav.freightExchange` | Placeholder → Phase 3 | ❌ |
| 9 | Document Center | `nav.documentCenter` | Placeholder → Phase 3 | ❌ |
| 10 | Local Download | `nav.localDownload` | Placeholder → Phase 3 | ❌ |
| 11 | Settings | `nav.settings` | `SettingsScreen` | ✅ |

---

### Batch 1A — Role Model Refactor

**Blueprint ref:** §3
**Files:** 1 create, 2 modify, 1 delete
**Gate:** `test/core/auth/test_shell_routing.dart` passes

#### New: `lib/core/auth/user_role.dart`

```dart
enum UserRole { driver, dispatcher, manager, admin }
enum AppShellVariant { driverShell, managerShell }

extension AppShellRouting on UserRole {
  AppShellVariant get shellVariant => switch (this) {
    UserRole.driver => AppShellVariant.driverShell,
    UserRole.dispatcher || UserRole.manager || UserRole.admin
      => AppShellVariant.managerShell,
  };
}

UserRole userRoleFromString(String role) => switch (role) {
  'driver' || 'sofer' => UserRole.driver,
  'dispatcher' || 'fleet_manager' => UserRole.dispatcher,
  'manager' => UserRole.manager,
  'admin' || 'owner' => UserRole.admin,
  _ => UserRole.driver,
};
```

#### Modify: `lib/core/auth/auth_providers.dart`

Add `currentUserRoleProvider`:
```dart
final currentUserRoleProvider = Provider<UserRole?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return userRoleFromString(user.role);
});
```

#### Modify: `lib/core/auth/mode_router.dart`

Replace `RoleResolver.resolve(user.role)`:
```dart
final role = ref.watch(currentUserRoleProvider);
return switch (role?.shellVariant) {
  AppShellVariant.driverShell => const DriverShell(),
  AppShellVariant.managerShell => const DispatcherShell(),
  _ => const LoginScreen(),
};
```

#### Delete: `lib/core/auth/role_resolver.dart`

Content migrated to `user_role.dart`.

#### New: `test/core/auth/test_shell_routing.dart`

Parametrized test asserting all 4 roles + null resolve to correct `AppShellVariant`.

---

### Batch 1B — I18n Keys

**Blueprint ref:** §4 tables
**Files:** 2 modify, 1 new test
**Gate:** `test/i18n/test_locale_key_coverage.dart` passes

#### New l10n keys to add to both `app_en.arb` and `app_ro.arb`:

```
# Navigation labels
nav_overview: "Overview" / "Prezentare generală"
nav_fleetTracker: "Fleet Tracker" / "Flotă"
nav_copilot: "AI Copilot" / "AI Copilot"
nav_more: "More" / "Mai mult"
nav_map: "Map" / "Hartă"
nav_teams: "Teams" / "Echipe"
nav_profitCalculator: "Profit Calculator" / "Calculator profit"
nav_routePlanner: "Route Planner" / "Planificator rute"
nav_freightExchange: "Freight Exchange" / "Schimb mărfuri"
nav_documentCenter: "Document Center" / "Centru documente"
nav_localDownload: "Local Download" / "Descărcare locală"

# Copilot UI (currently hardcoded)
ai_title: "AI Co-Pilot" / "AI Co-Pilot"
ai_emptyStateMessage: "Ask me anything about your fleet" / "Întreabă-mă orice despre flota ta"
ai_emptyStatePrompt: 'Try: "Show my available trucks"' / 'Încearcă: "Arată camioanele disponibile"'
ai_clarifyPlaceholder: "Type your answer..." / "Scrie răspunsul..."
ai_newConversation: "New conversation" / "Conversație nouă"

# Driver overview (Phase 2 placeholder)
driverOverview_emptyState: "No active trip" / "Nicio cursă activă"
driverOverview_etaUnavailable: "ETA unavailable" / "ETA indisponibilă"

# More hub section labels
moreHub_sectionTitle: "Features" / "Funcționalități"
moreHub_logout: "Sign Out" / "Deconectare"

# Route share (Phase 2 placeholder)
routeShare_offRoute: "You appear to be off route" / "Pari a fi în afara rutei"
routeShare_backgroundBanner: "Navigation will pause when app is backgrounded" / "Navigarea se va întrerupe când aplicația este în fundal"

# Local download (Phase 3)
localDownload_categoryDocuments: "Documents" / "Documente"
localDownload_categoryInvoices: "Invoices" / "Facturi"
localDownload_categoryReceipts: "Receipts" / "Chitanțe"
localDownload_categoryOcrResults: "OCR Results" / "Rezultate OCR"
localDownload_categoryTripHistory: "Trip History" / "Istoric curse"
localDownload_download: "Download" / "Descarcă"
localDownload_manifestError: "Failed to get file list" / "Eroare la obținerea listei de fișiere"
```

#### New: `test/i18n/test_locale_key_coverage.dart`

Asserts every key referenced by `t()` in new screens exists in both `app_en.arb` and `app_ro.arb`. A key in one but not the other is a failing test.

---

### Batch 1C — Copilot Screen I18n Cleanup + Rename

**Blueprint ref:** §1.3 (zero hardcoded strings), §4 (wiring into both shells)
**Files:** 2 modify
**Gate:** Existing copilot tests still pass

#### Modify: `lib/features/copilot/screens/copilot_screen.dart`

- Add `typedef CopilotChatScreen = CopilotScreen;` at class site (minimal rename)
- Replace hardcoded strings with `context.loc.xxx`:
  - `'AI Co-Pilot'` → `context.loc.ai_title`
  - `'New conversation'` (tooltip) → `context.loc.ai_newConversation`
  - `'Ask me anything about your fleet'` → `context.loc.ai_emptyStateMessage`
  - `'Try: "Show my available trucks" or "Find loads near Berlin"'` → `context.loc.ai_emptyStatePrompt`
  - `'Cancel'` → `context.loc.general_cancel` (already exists)
  - `'Confirm'` → `context.loc.general_confirm` (already exists)
  - `'Type your answer...'` → `context.loc.ai_clarifyPlaceholder`
  - `'Ask the Co-Pilot...'` → `context.loc.ai_placeholder` (already exists)
- Replace `Step: ${...}` in `_ConfirmationBar` with localised text

#### Modify: `lib/features/copilot/copilot_integration.dart`

Add export for `CopilotChatScreen` typedef if needed for clean imports.

---

### Batch 1D — Driver Shell Rewrite

**Blueprint ref:** §4.2
**Files:** 1 rewrite, 2 new placeholders, 1 new test
**Gate:** `test/features/driver/test_driver_shell_nav.dart` passes

#### Rewrite: `lib/features/driver/driver_shell.dart`

Replace existing 4 tabs (Home, Transports, Messages, Profile) with:

```dart
// Tab 0: Map (Icons.map_outlined / Icons.map)
// Tab 1: Overview (Icons.dashboard_outlined / Icons.dashboard)
// Tab 2: AI Copilot (Icons.auto_awesome_outlined / Icons.auto_awesome)
// Tab 3: Settings (Icons.settings_outlined / Icons.settings)
```

Body mapping:
```dart
switch (_currentIndex) {
  case 0: return const RouteShareNavScreen();       // Phase 2 placeholder
  case 1: return const DriverTripOverviewScreen();   // Phase 2 placeholder
  case 2: return const CopilotChatScreen();
  case 3: return const SettingsScreen();
}
```

Keep `OfflineBanner` pinned at top. Remove `MessageBadge`, `_ProfileTab` helpers.
Remove imports for `DriverHomeScreen`, `TransportListScreen`, `MessageListScreen`, `DriverProfileScreen` — they are no longer tab contents.

#### New placeholder: `lib/features/driver/route_share/screens/route_share_nav_screen.dart`

```dart
/// Placeholder for Phase 2 turn-by-turn navigation.
class RouteShareNavScreen extends StatelessWidget {
  const RouteShareNavScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icon(Icons.map, size: 56),
        title: 'Route Navigation',
        subtitle: 'Coming in Phase 2',
      ),
    );
  }
}
```

#### New placeholder: `lib/features/driver/trip_overview/screens/driver_trip_overview_screen.dart`

```dart
/// Placeholder for Phase 2 driver trip overview.
class DriverTripOverviewScreen extends StatelessWidget {
  const DriverTripOverviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icon(Icons.dashboard, size: 56),
        title: 'Trip Overview',
        subtitle: 'Coming in Phase 2',
      ),
    );
  }
}
```

#### New: `test/features/driver/test_driver_shell_nav.dart`

- Assert `bottomNavigationBar.items.length == 4`
- Assert correct label set in both locales
- Assert each tab renders the correct screen type

---

### Batch 1E — Dispatcher Shell Rewrite + MoreHubScreen

**Blueprint ref:** §4.1
**Files:** 1 rewrite, 2 new, 1 new test
**Gate:** `test/features/more_hub/test_more_hub_screen.dart` passes

#### Rewrite: `lib/features/dispatcher/dispatcher_shell.dart`

Change 5 tabs → 4:

| Old Index | Old Tab | → | New Index | New Tab |
|-----------|---------|---|-----------|---------|
| 0 | Overview | → | 0 | Overview (unchanged) |
| 1 | Fleet | → | 1 | Fleet Tracker (unchanged) |
| 2 | Jobs | — | — | **Removed** (moves to More) |
| 3 | Alerts | — | — | **Removed** (moves to More) |
| 4 | More | → | 2 | **AI Copilot** (new) |
| — | — | | 3 | **MoreHubScreen** (was `_MoreTab`) |

Remove: `_MoreTab` class, `_MoreListTile` class, `_showComingSoon` function, `_AlertBadge` class
Remove: Old imports for `message_list_screen`, `driver_list_screen`, `settings_screen`, `analytics`
Update: `dispatcherTabProvider` comment (now indices 0-3)
Add: Import for `CopilotChatScreen`, `MoreHubScreen`

Body mapping:
```dart
switch (_currentIndex) {
  case 0: return const DispatcherHomeScreen();
  case 1: return const FleetMapScreen();
  case 2: return const CopilotChatScreen();
  case 3: return const MoreHubScreen();
}
```

#### New: `lib/features/more_hub/screens/more_hub_screen.dart`

A scrollable grid of `AppCard` tiles with Lucide icons, following the exact order from §4.1:

```dart
class MoreHubScreen extends ConsumerWidget {
  const MoreHubScreen({super.key});
  // ...
}
```

Tile data structure:
```dart
final _tiles = [
  _MoreTile(LucideIcons.messageSquare, 'nav.messages', () => push(MessageListScreen())),
  _MoreTile(LucideIcons.users, 'nav.teams', () => push(DriverListScreen())),
  _MoreTile(LucideIcons.barChart3, 'nav.analytics', () => push(DispatcherAnalyticsScreen())),
  _MoreTile(LucideIcons.briefcase, 'nav.jobs', () => push(JobListScreen())),
  _MoreTile(LucideIcons.bell, 'nav.alerts', () => push(AlertInboxScreen())),
  _MoreTile(LucideIcons.calculator, 'nav.profitCalculator', () => push(UnderConstructionScreen('Profit Calculator'))),
  _MoreTile(LucideIcons.route, 'nav.routePlanner', () => push(UnderConstructionScreen('Route Planner'))),
  _MoreTile(LucideIcons.search, 'nav.freightExchange', () => push(UnderConstructionScreen('Freight Exchange'))),
  _MoreTile(LucideIcons.folderOpen, 'nav.documentCenter', () => push(UnderConstructionScreen('Document Center'))),
  _MoreTile(LucideIcons.download, 'nav.localDownload', () => push(UnderConstructionScreen('Local Download'))),
  _MoreTile(LucideIcons.settings, 'nav.settings', () => push(SettingsScreen())),
];
```

Layout: `GridView.count(crossAxisCount: 2)` with `AppCard` per tile, plus a logout button at the bottom (reuse same confirmation pattern from existing `_MoreTab._confirmLogout`).

#### New: `lib/features/more_hub/screens/skeleton_screens.dart`

```dart
/// Placeholder for Phase 2/3 features not yet built.
class UnderConstructionScreen extends StatelessWidget {
  final String featureName;
  const UnderConstructionScreen(this.featureName, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(featureName)),
    body: EmptyState(
      icon: Icon(LucideIcons.construction, size: 56),
      title: 'Coming Soon',
      subtitle: '$featureName will be available in a future update',
    ),
  );
}
```

#### New: `test/features/more_hub/test_more_hub_screen.dart`

- Assert exactly 11 tiles render in the exact order from §4.1
- Assert each tile has a non-empty `t()`-resolved label in both locales
- Use `NavigatorObserver` to verify tap navigation to correct route

---

### Batch 1F — Existing Test Updates

**Files:** Possibly 2-5 existing tests need updates
**Gate:** `flutter test` passes green

Existing tests that may reference old shell structures and break:

| Test | Risk | Action |
|------|------|--------|
| `test/driver/driver_screens_test.dart` | High — references old tab structure | Update imports, remove tab assertions |
| `test/dispatcher/dispatcher_screens_test.dart` | High — references old 5-tab structure | Update imports, tab count assertions |
| `test/widgets/driver_home_screen_test.dart` | Low — screen itself unchanged | Likely fine if import paths unchanged |
| `test/widgets/driver_profile_screen_test.dart` | Low — screen kept | Likely fine |
| `test/core/state_notifiers_test.dart` | Medium — may reference old RoleResolver | Update if needed |

**Action:** Run `flutter test` after Batch 1E. Fix all failures. Ensure zero regressions.

---

## 3. Phase 2 — Driver Features

**Blueprint ref:** §7 (Driver-Specific Features), §12 Phase 2
**Goal:** DriverTripOverviewScreen + RouteShareNavScreen with full GPS/background handling
**Depends on:** Phase 1 (shells/tabs in place), Backend endpoints (trip-overview, route-share)

### New Files

| File | Purpose |
|------|---------|
| `lib/features/driver/trip_overview/screens/driver_trip_overview_screen.dart` | Trip overview UI (replace placeholder) |
| `lib/features/driver/trip_overview/providers/trip_overview_providers.dart` | Data fetching from `GET /mobile/driver/trip-overview` |
| `lib/features/driver/models/driver_trip_overview.dart` | `DriverTripOverview`, `TripStatus`, `EtaConfidence` enums |
| `lib/features/driver/route_share/screens/route_share_nav_screen.dart` | Turn-by-turn navigation (replace placeholder) |
| `lib/features/driver/route_share/providers/route_share_providers.dart` | GPS acquisition, geometry fetch, off-route detection |
| `lib/features/driver/models/route_share_geometry.dart` | `RoutePoint`, `RouteInstruction`, `RouteShareGeometry` |
| `lib/shared/widgets/turn_instruction_banner.dart` | New shared widget (§1.4: genuinely new pattern) |
| `lib/shared/widgets/transport_status_buttons.dart` | Extract from `TransportDetailScreen` §7.1.4 |
| `test/features/driver/trip_overview/test_trip_overview_screen.dart` | 3 fixture states + timer disposition |
| `test/features/driver/route_share/test_gps_update_cadence.dart` | Stationary + fast-moving GPS stream |
| `test/features/driver/route_share/test_background_permission_fallback.dart` | Denied permission → foreground fallback |
| `test/features/driver/models/test_route_share_geometry_model.dart` | Contract round-trip (Dart side) |
| Backend: `tests/contracts/test_driver_trip_overview_schema.py` | Contract round-trip (Python side) |
| Backend: `tests/contracts/test_route_share_geometry_schema.py` | Contract round-trip (Python side) |

### Modified Files

| File | Change |
|------|--------|
| `lib/features/driver/driver_shell.dart` | Replace placeholder screens with real implementations |
| `lib/l10n/app_en.arb` | Add trip overview + route share keys |
| `lib/l10n/app_ro.arb` | Same keys, Romanian |

### Key Implementation Details

#### DriverTripOverviewScreen (§7.1)
- Data source: `GET /api/v1/mobile/driver/trip-overview`
- States: loading (shimmer), error (retry), empty (no transport assigned)
- Content: transport summary card, ETA with confidence treatment, elapsed timer (1s, disposed), status transition buttons
- Status buttons extracted from `TransportDetailScreen.TransportStatusHelper` → shared widget

#### RouteShareNavScreen (§7.2)
- `flutter_map` + OSM tiles (consistent with `FleetMapScreen`)
- Current-position marker + route polyline (unvisited segment visually distinct)
- `TurnInstructionBanner` (new shared widget) — shows next instruction + distance
- Bottom sheet: remaining distance/time (locally computed from geometry + GPS)
- Off-route detection: >50m deviation for >10s → trigger re-fetch
- Offline: render last geometry, continue local ETA, suppress re-fetch, show `OfflineBanner`
- GPS: every 5s OR every 20m displacement (whichever fires first)
- **Android foreground service** with persistent notification
- **iOS "Always" location authorization**
- Graceful degradation to foreground-only on denied permission

---

## 4. Phase 3 — Dispatcher/Manager Feature Ports

**Blueprint ref:** §6 (Feature Ports), §12 Phase 3
**Goal:** 6 new feature screens behind MoreHubScreen tiles
**Depends on:** Phase 1 (shells/MoreHubScreen in place)

### 4.1 Profit Calculator (`lib/features/profit_calculator/`)

| File | Purpose |
|------|---------|
| `screens/profit_calculator_screen.dart` | Form: revenue, fuel, toll, maintenance, driver cost |
| `calculator_logic.dart` | Pure Dart function (no backend call — §6.1 decision) |
| `test/features/profit_calculator/test_calculator_logic.dart` | 3 fixed input sets, compared to desktop values |

**Decision from blueprint:** pure client-side calculation. If desktop actually calls a backend, **stop and report** (§0 item 4).

### 4.2 Teams (`lib/features/teams/`)

| File | Purpose |
|------|---------|
| `screens/teams_screen.dart` | Filter chips (All/Available/Driving/Off), driver list with StatusBadge |
| `screens/driver_detail_screen.dart` | License info, expiry status, assigned vehicle |
| `providers/teams_providers.dart` | Wraps existing `GET /drivers` endpoint |
| `test/features/teams/test_teams_filter.dart` | Filter chip narrows correctly against fixture |

**Decision resolved:** No new backend entity. Teams = enhanced Drivers list (§6.2).

### 4.3 Route Planner (`lib/features/route_planner/`)

| File | Purpose |
|------|---------|
| `screens/route_planner_screen.dart` | Multi-stop input, ReorderableListView, submit → render |
| `providers/route_planner_providers.dart` | Calls backend GraphHopper integration |
| `test/features/route_planner/test_route_planner_parity.dart` | Same input → diff desktop/mobile output |

**Backend:** Reuses existing `routes.py` GraphHopper multi-stop optimization.

### 4.4 Freight Exchange (`lib/features/freight_exchange/`)

| File | Purpose |
|------|---------|
| `screens/freight_exchange_screen.dart` | Load-board list, detail view, Accept & Assign |
| `providers/freight_exchange_providers.dart` | Filter/search, live re-check on accept |
| `models/freight_load.dart` | Load-board model (provider-agnostic — §6.3 rule) |
| Backend: `tests/copilot/test_freight_exchange_concurrency.py` | Two concurrent accepts → exactly one succeeds |

**Key rules:** Idempotency-Key on accept (§1.7), live re-check before mutation (§1.6), provider-agnostic models (§6.3).

### 4.5 Document Center + Automation (`lib/features/document_center/`)

| File | Purpose |
|------|---------|
| `screens/document_center_screen.dart` | Full document browser (all company docs) |
| `screens/automation_tab.dart` | Camera capture → OCR upload flow |
| `providers/document_center_providers.dart` | Upload with idempotency key |
| `models/ocr_upload_response.dart` | OcrUploadResponse model |
| `test/features/document_center/test_automation_upload_no_autopull.dart` | Negative assertion: no local OCR cache |

**Cloud-only constraint:** OCR result stays server-side until Local Download pulls it.

### 4.6 Local Download (`lib/features/local_download/`)

| File | Purpose |
|------|---------|
| `screens/local_download_screen.dart` | Category list + date range filter |
| `providers/local_download_providers.dart` | POST manifest → per-file download |
| `models/download_manifest.dart` | DownloadCategory enum, DownloadManifestEntry |
| `test/features/local_download/test_no_background_sync.dart` | Static assertion: no Timer/WorkManager |
| Backend: `tests/security/test_local_download_company_isolation.py` | Multi-tenant isolation test |

**Pull-on-demand only:** No background sync, no scheduled tasks.

### Modifications to Phase 1 Files

| File | Change |
|------|--------|
| `more_hub_screen.dart` | Replace `UnderConstructionScreen` placeholders with real screen imports for completed features |
| `dispatcher_shell.dart` (if needed) | Unlikely — all navigation is through MoreHub |

---

## 5. Phase 4 — AI Copilot Wiring + RBAC

**Blueprint ref:** §8 (AI Copilot), §12 Phase 4
**Goal:** Wire shared `CopilotChatScreen` to live backend; apply RBAC scoping fixes
**Depends on:** Phase 0 audit (OD-4, OD-5) — backend must be available

### Work Items

| Item | Change |
|------|--------|
| Wire `CopilotStateNotifier` to live `POST /api/v1/copilot/chat` | Currently has endpoint; validate response format matches model expectations |
| Add `currentUserRoleProvider` driven `available_tools` check | Optional — the backend resolves this. Mobile just renders what the server sends |
| Remove any per-role branching if present | Blueprint §8.1: "zero per-role branching in the Flutter widget tree" |
| Level 3 typed confirmation phrase | Add keyboard input to `_ConfirmationBar` for Level 3 actions per §8.2 |
| Backend: RBAC audit + scoping fixes from OD-4/OD-5 | Permission table adjustments in `copilot_router.py` |

### Verification Gate

Run identical command through desktop and mobile → paste both `ExecutionPlan` JSON payloads side by side. Assert identical tool-call sequence, confirmation level, and confirmation-sheet content.

### New Test

| File | Purpose |
|------|---------|
| `tests/copilot/test_driver_rbac_scope.py` (backend) | Assert driver `available_tools` excludes analytics, client payment tools |

---

## 6. Phase 5 — Full Regression & Sign-Off

**Blueprint ref:** §14 (Master Definition of Done)
**Goal:** All tests green, CI-blocking, no regressions

### Full Test Run

```
flutter test                          # All mobile tests
# Backend: pytest tests/              # Full backend suite
# Backend: pytest tests/security/     # No regression in company_id isolation
```

### Acceptance Checklist

- [ ] Manager shell renders exactly 4 tabs (Overview, Fleet Tracker, AI Copilot, More)
- [ ] More contains exactly 11 tiles in specified order, each localized in RO+EN
- [ ] Driver shell renders exactly 4 tabs (Map, Overview, AI Copilot, Settings)
- [ ] Every new screen implements loading/error/empty/pull-to-refresh (verified by widget tests)
- [ ] Every §5 data contract has passing round-trip test on both Python and Dart sides
- [ ] `RouteShareNavScreen` passes simulated GPS verification gate (§7.2.4)
- [ ] Freight Exchange passes provider-swap test + concurrency test
- [ ] Document Center Automation passes negative-assertion no-autopull test
- [ ] Local Download passes company-isolation + no-background-sync tests
- [ ] Driver Copilot RBAC scope test passes at registry level
- [ ] Desktop/mobile Copilot parity test passes with identical `ExecutionPlan` payloads
- [ ] Every §9 endpoint has corresponding `company_id` isolation test
- [ ] Full existing `tests/security/` suite passes (no regression)
- [ ] Every new locale key exists in both `ro.json` and `en.json`
- [ ] No hex color literals or raw `TextStyle(...)` outside `core/theme/`
- [ ] No new Dart file outside `lib/features/<name>/{screens,providers,widgets,models}`

---

## 7. File Change Summary

### Phase 1

| Type | Count | Details |
|------|-------|---------|
| **New files** | 8 | `user_role.dart`, `more_hub_screen.dart`, `skeleton_screens.dart`, `route_share_nav_screen.dart` (placeholder), `driver_trip_overview_screen.dart` (placeholder), 3 test files |
| **Modified files** | 9 | `mode_router.dart`, `auth_providers.dart`, `driver_shell.dart`, `dispatcher_shell.dart`, `copilot_screen.dart`, `copilot_integration.dart`, `app_en.arb`, `app_ro.arb`, `dispatcher_providers.dart` |
| **Deleted files** | 1 | `role_resolver.dart` |
| **New test cases** | ~25 | 4 test files |

### Phase 2

| Type | Count |
|------|-------|
| **New files** | ~12 | 2 screens, 2 providers, 2 models, 1 shared widget, 4 test files, 1 backend contract test |
| **Modified files** | 3 | `driver_shell.dart`, `app_en.arb`, `app_ro.arb` |

### Phase 3

| Type | Count |
|------|-------|
| **New files** | ~18 | 6 feature folders × ~3 files each |
| **Modified files** | 1 | `more_hub_screen.dart` (replace placeholders) |

### Phase 4

| Type | Count |
|------|-------|
| **Modified files** | 2-3 | `copilot_providers.dart`, copilot screen widgets |
| **Backend files** | TBD | `copilot_router.py`, RBAC config |

### Phase 5

| Type | Count |
|------|-------|
| **Test fixes** | Varies | Full regression pass |

---

## 8. Risks & Dependencies

### Critical: Backend Not Present in This Repo

The `Calculator logistica/` directory with FastAPI services does not exist in this repository. This blocks:

| Audit Item | What's Needed | Impact |
|------------|--------------|--------|
| **OD-1** | Inspect `routes.py`/`trips.py` for geometry-bearing endpoints | Cannot implement `GET /mobile/driver/transports/{id}/route-share` without knowing if geometry already exists |
| **OD-3** | Inspect GraphHopper integration response shape | Cannot build `RouteShareGeometry` Dart model without matching the actual backend response |
| **OD-4** | Inspect `driver` role's actual permission list | Cannot verify RBAC test |
| **OD-5** | Inspect service-layer scoping (`trip_service`, `route_service`, etc.) | Cannot verify driver scope isolation |

**Mitigation:** Phase 1 has zero backend dependencies — proceed immediately. For Phase 2+, coordinate with backend team to:
1. Confirm endpoint contracts match §5 schemas
2. Deploy mobile-facing endpoints to staging
3. Provide a staging API key and base URL for integration testing

### Medium: GPS Platform Permissions (Phase 2)

- Android: `ACCESS_FINE_LOCATION` + `ACCESS_BACKGROUND_LOCATION` + foreground service notification
- iOS: `NSLocationAlwaysAndWhenInUseUsageDescription` + `location` background mode
- Platform config changes needed in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`
- Physical device testing required (emulator GPS simulation is limited)

### Low: Copilot Screen Is Already Implemented

The existing `CopilotScreen` with full state machine (`CopilotMobileState`) and backend endpoints (`CopilotEndpoints`) means Phase 4 is largely wiring — not building from scratch. The main work is:
- i18n cleanup (Phase 1 Batch 1C)
- Level 3 typed confirmation phrase
- Any RBAC display adaptations

### Keep vs. Delete Decision: Old Tab Screens

| Screen | Phase 1 Action | Notes |
|--------|---------------|-------|
| `DriverHomeScreen` | **Keep file, remove from tab** | Still useful — could be integrated into DriverTripOverview in Phase 2 |
| `TransportListScreen` | **Keep file, remove from tab** | Still referenced by detail screens |
| `MessageListScreen` | **Keep file** | Still used by manager MoreHub tile |
| `DriverProfileScreen` | **Keep file** | Profile content may merge into Settings or trip screens |
| `JobListScreen` | **Keep file** | Moves from tab to MoreHub tile |
| `AlertInboxScreen` | **Keep file** | Moves from tab to MoreHub tile |
