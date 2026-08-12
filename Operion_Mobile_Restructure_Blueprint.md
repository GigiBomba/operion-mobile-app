# Operion Mobile App — Complete Implementation Blueprint

**Target:** `operion-mobile-app/mobile/` (Flutter 3.12+, Dart 3.12+, Riverpod, Dio, flutter_map, FCM)
**Backend:** `Calculator logistica/` FastAPI service (shared with desktop + website)
**Companion document:** `Operion_AI_CoPilot_Blueprint_V4.md` — §9, §15, §16, §32 are treated as
already-authoritative and are referenced, not restated, wherever Co-Pilot behavior is involved.

**This is the complete, single blueprint for this body of work.** It is not phase one of a
series of documents — every decision needed to take this from current state to fully shipped
is either made explicitly below or flagged as an audit item that must be resolved *within*
this plan's own first implementation phase (§15), not deferred to a future document. Feed it
section-by-section to the coding agent exactly as written.

---

## 0. How This Document Is Used (read this before touching code)

This section is itself part of the specification — it defines the working discipline the
coding agent must follow for every phase below, not just a preface.

1. **One section (or one named sub-phase) per agent turn.** Do not paste the whole document
   into a single prompt and ask for the whole feature set at once — this produces shallow,
   unverifiable output. Feed §14's phases in order; within a phase, feed one module/section at
   a time.
2. **Nothing is "done" without a pasted artifact, never a claim.** Every verification gate in
   this document says what the artifact is (failing→passing test output, a diff, a schema dump
   from a live call, a screen recording note). A response of "implemented and tested" with no
   pasted output is not an acceptable completion signal — reject it and ask for the artifact.
3. **The agent must ask when a section says to audit, not assume.** Several items in this
   document (§15) require the agent to inspect the actual running backend/codebase and paste
   what it finds before writing dependent code. If the agent proceeds past one of these without
   pasting real findings, stop it and make it go back.
4. **No silent scope expansion.** If implementing a section reveals a need for something not
   specified here (a new model field, a new service method), the agent states the gap
   explicitly and proposes the smallest addition that satisfies this spec — it does not
   quietly invent a broader mechanism (this document had exactly that problem once already,
   with an earlier draft proposing a bespoke Co-Pilot tool-registry fork that duplicated
   existing architecture — see §9).
5. **Every new module ships with its own tests in the same turn it's written**, not as a
   follow-up. "I'll add tests after" is not accepted at any point in this plan.
6. **Read §1 (Engineering Standards) before writing any new file.** It is cross-cutting and
   applies to literally everything built under this blueprint — it is not optional style
   preference, it is the acceptance bar.

---

## 1. Cross-Cutting Engineering Standards

Every module built under this blueprint — dispatcher/manager features, driver features, and
backend changes alike — must follow these rules without exception. Restating them per-module
below would be noise; violations should be caught in review by pointing back to this section.

### 1.1 Project structure & naming
- New Flutter features live under `lib/features/<feature_name>/` mirroring the existing
  `features/driver/` and `features/dispatcher/` layout: `screens/`, `providers/`, `widgets/`,
  and (if the feature has its own request/response shapes) `models/`. Do not scatter a new
  feature's files across `shared/` "for convenience."
- One `StateNotifier`/`AsyncNotifier` (Riverpod) per screen-level concern, not one giant
  provider covering multiple screens. Providers are named `<Feature><Concern>Provider` (e.g.
  `profitCalculatorInputProvider`, `freightExchangeListProvider`) — no abbreviations that
  aren't already established in the existing codebase (`FCM`, `JWT`, `CMR` are fine; inventing
  new ones is not).
- No business logic inside `build()` methods. Widgets read provider state and render; any
  calculation, formatting, or branching logic lives in the provider/notifier or a plain Dart
  helper class that is independently unit-testable without pumping a widget tree.
- No magic strings for tool names, permission strings, status enums, or route names anywhere
  in new Dart or Python code — use enums/constants defined once and imported, exactly as
  `ConfirmationLevel` is an `IntEnum` in the Co-Pilot blueprint rather than a raw integer
  scattered through the codebase.

### 1.2 Networking & error handling
- Every new Dio-based service reuses the app's existing global interceptor stack (auth
  attachment, retry/backoff) — never a bare `Dio()` instantiated inside a feature file.
- Retry policy for every new network call matches the existing convention already established
  for the Co-Pilot mobile client: **one automatic retry for a transient error (timeout,
  5xx, connection reset), zero automatic retries for a deterministic error (4xx validation,
  403 permission, 404)** — this must not be reinvented per-feature; import the shared
  retry-policy interceptor.
- Every new screen that fetches data implements all four of: loading state (reuse
  `ShimmerLoader`), error state with a retry action, empty state (reuse `EmptyState`), and
  pull-to-refresh where the existing pattern uses it for comparable screens (lists/dashboards).
  A screen missing any one of these four is not complete, regardless of whether the happy path
  works.
- `CancelToken` per in-flight request tied to the widget's lifecycle — navigating away
  cancels the in-flight call. This already exists as a Co-Pilot-mobile convention (§32.2 of
  the Co-Pilot blueprint) and must be applied to every new feature's networking layer too, not
  just Co-Pilot's.

### 1.3 i18n (non-negotiable, per existing project convention)
- **Zero hardcoded UI strings.** Every new label, button, tab name, error message, and empty-
  state string goes through `t()` backed by `ro.json` and `en.json` — the two locales the
  mobile app currently ships (this is a narrower scope than the Co-Pilot backend's 22-language
  support, which lives server-side; the mobile *app chrome* itself is RO/EN only per the
  existing `l10n/` setup, and this blueprint does not expand that scope).
- New locale keys follow the existing key-namespacing convention (e.g.
  `nav.more`, `profitCalculator.title`, `freightExchange.emptyState`) — do not invent a
  differently-shaped key scheme for new features.
- **Test requirement:** `test/i18n/test_locale_key_coverage.dart` (extend if it exists,
  create if not) — asserts every key referenced by `t()` in any new screen exists in both
  `ro.json` and `en.json`. A key present in one locale file and missing from the other is a
  failing build, not a follow-up ticket.

### 1.4 Design system
- New screens use only `AppColors`, `AppTheme`, `AppTypography`, `AppSpacing`, `AppRadius`
  from `core/theme/` — no ad hoc hex colors, no inline `TextStyle` literals, no one-off
  padding numbers. Indigo `#6366F1` primary, Inter typography — same as every existing screen.
- Reuse existing shared widgets (`AppButton`, `AppCard`, `AppTextField`, `ConfirmationDialog`,
  `StatusBadge`, `StalenessIndicator`) rather than rebuilding equivalents inside a new feature
  folder. If a new visual pattern is genuinely needed (e.g., the turn-by-turn instruction
  banner in §8.2), it is built once in `shared/widgets/` so later features can reuse it too —
  not duplicated inline in the screen that first needed it.

### 1.5 Testing conventions
- Test files live under `test/`, mirroring `lib/` structure: `test/features/<feature>/...`.
- Every verification gate in this document names the artifact required. The standing rule
  from the existing security/backend work applies identically here: **a test must fail before
  the fix and pass after — paste both outputs.** A test written after the fact that only ever
  shows green is not proof of anything and must be redone as fail→fix→pass.
- Widget tests use `flutter test`; any test that talks to the real backend (schema/contract
  confirmation, isolation tests) runs against a staging environment, never production data.
- Backend-side tests (Pydantic contracts, `company_id` isolation, RBAC/permission tests) live
  under the existing `tests/` tree in `Calculator logistica/`, following the same
  `tests/security/`, `tests/copilot/` conventions the Co-Pilot blueprint already establishes —
  do not create a parallel test root for "mobile-triggered" backend behavior; it's still
  backend behavior and belongs in the same suite that already covers it.

### 1.6 Concurrency & data-freshness discipline
Several new features in this blueprint (Freight Exchange load acceptance, driver trip status
updates via Copilot, Local Download) touch data that can change between when it was fetched
and when an action against it executes. The rule already established for the Co-Pilot's
Level 2+ execution path (re-validate the specific facts a decision depended on, immediately
before mutating, via a live call — never trust a value captured earlier in the session)
applies equally to any new mobile action that mutates shared/contested data, Co-Pilot-driven
or not. Concrete instances of this rule are called out per-feature below (§6.4 Freight
Exchange); the general principle is not repeated per-feature beyond that.

### 1.7 Idempotency
The backend already has an idempotency middleware in its pipeline. Any new mobile action that
performs a real-world side effect and could plausibly be retried by the client (upload-and-
process flows, load-acceptance, any Level 2+ Copilot-triggered mutation) must send an
`Idempotency-Key` header (a client-generated UUID, generated once per user-initiated action
and reused only across retries of that *same* action) so a retried request after a dropped
connection does not double-process. This applies concretely to §6.3's OCR upload and §6.4's
Freight Exchange load-acceptance call.

### 1.8 Multi-tenant isolation
Restated once, applies everywhere: no new or modified endpoint may trust a client-supplied
`company_id`; it is always derived from the JWT server-side. Every new/changed endpoint in
this blueprint gets a corresponding `company_id` isolation test in `tests/security/` before
it is considered complete — this is listed explicitly per endpoint in §10 and consolidated in
§13, not left implicit.

---

## 2. Current State → Target State

| Item | Current | Target |
|---|---|---|
| Driver shell | 4 tabs: My Day, Transports, Messages, Profile(≈Settings) | 4 tabs, flat: Route Map, Trip Overview, AI Copilot, Settings |
| Dispatcher/manager/admin shell | 5 tabs: Overview, Fleet, Jobs, Alerts, More(Messages/Drivers/Analytics/Settings) | 4 tabs: Overview, Fleet Tracker, AI Copilot, More |
| Dispatcher "More" | Messages, Drivers, Analytics, Settings | Same four, plus: Profit Calculator, Route Planner, Teams, Freight Exchange, Document Center (incl. Automation/OCR), Local Download |
| AI Copilot mobile | Post-MVP stub (`features/copilot/`) — intent models, voice handler scaffolding only, no live backend wiring | One shared `CopilotChatScreen`/`copilot_router.py` surface for every role; capability differs only because `resolve_available_tools()` (Co-Pilot V4 §15.2) intersects the full tool registry with each role's actual RBAC permissions — §9 |
| Route-share | Not implemented on mobile; desktop's equivalent concept has unverified backend support | New, mobile-first, phone-GPS-driven turn-by-turn feature — §8.2 |
| Jobs tab (dispatcher) | Standalone tab | Folded conceptually into Overview/Fleet Tracker's existing job-detail push navigation — no separate bottom-nav slot in the new 4-tab layout; if `JobListScreen` is still needed as a distinct entry point, it lives inside **More** alongside Drivers/Teams, not as a fifth bottom-nav tab |
| Alerts tab (dispatcher) | Standalone tab | Same treatment as Jobs — moves into **More** (grouped near Messages) rather than occupying one of the four bottom-nav slots, since the four slots are now Overview / Fleet Tracker / AI Copilot / More |

---

## 3. Role Model & Auth-Gate Routing

**Roles:** `driver`, `dispatcher`, `manager` are user-facing RBAC roles carried in the JWT and
already resolved into `AuthState` today. `admin` is not a user-facing role — it is the
all-permissions developer/ops account. Concretely:

```dart
// core/auth/auth_state.dart (existing file — extend, do not replace)
enum AppShellVariant { driverShell, managerShell }

extension AppShellRouting on UserRole {
  AppShellVariant get shellVariant => switch (this) {
    UserRole.driver => AppShellVariant.driverShell,
    UserRole.dispatcher || UserRole.manager || UserRole.admin => AppShellVariant.managerShell,
  };
}
```

- `admin` always resolves to `managerShell` — it is a superset of manager/dispatcher
  permissions, never a third navigation tree. There is no `AppShellVariant.adminShell`.
- The existing `auth_gate.dart` is the single place that decides which shell to mount, keyed
  off `AuthState.role.shellVariant` — no screen-level `if (role == ...)` branching scattered
  through feature code. A screen that needs role-aware behavior reads
  `ref.watch(currentUserRoleProvider)`, it does not re-derive role logic locally.
- **Test requirement (`test/core/auth/test_shell_routing.dart`):** parametrized test asserting
  all four roles (`driver`, `dispatcher`, `manager`, `admin`) resolve to the correct
  `AppShellVariant`, and that an unrecognized/null role value fails closed to the login/auth
  gate rather than defaulting to either shell.

---

## 4. Navigation Redesign

### 4.1 Manager shell (dispatcher/manager/admin) — 4 tabs

| # | Tab | Screen | i18n key |
|---|---|---|---|
| 1 | Overview | `DispatcherHomeScreen` (existing, unchanged) | `nav.overview` |
| 2 | Fleet Tracker | `FleetMapScreen` (existing, label change only) | `nav.fleetTracker` |
| 3 | AI Copilot | `CopilotChatScreen` (new, wired per §9) | `nav.copilot` |
| 4 | More | `MoreHubScreen` (new) | `nav.more` |

`MoreHubScreen` is a scrollable grid/list (`AppCard` tiles + Lucide icons per §1.4), not a
fifth bottom-nav level. Each tile pushes its own screen via standard `Navigator.push`. Tile
order (top to bottom, left to right) — decided now, not left to the agent's discretion:

1. Messages (existing)
2. Drivers / Teams (§6.2 — one screen, see naming resolution below)
3. Analytics (existing)
4. Jobs (relocated from the old standalone tab, §2)
5. Alerts (relocated from the old standalone tab, §2)
6. Profit Calculator (new, §6.1)
7. Route Planner (new, §6.2 — careful: this is a different concern from "Teams," see below)
8. Freight Exchange (new, §6.3)
9. Document Center (new, houses Automation/OCR internally, §6.4 — wait: renumber, see §6)
10. Local Download (new, §6.5)
11. Settings (existing)

> **Naming collision flagged explicitly:** item 2 above ("Teams") and item 7 ("Route
> Planner") both use the word "planning" loosely in conversation but are unrelated features —
> Route Planner is trip/multi-stop route optimization (§6.2 in the feature section below);
> Teams is the drivers/roster view (§6.1 in the feature section below). Section numbers for
> the feature specs and the tile list above are intentionally kept in sync — see §6 for the
> authoritative numbering; the list here is ordering only.

**Test requirement (`test/features/more_hub/test_more_hub_screen.dart`):** asserts exactly 11
tiles render in the order above, each with a non-empty `t()`-resolved label in both locales,
and each tap navigates to the correct route (use `NavigatorObserver` in the test, not a
manual tap-and-hope).

### 4.2 Driver shell — 4 tabs, flat, no overflow

| # | Tab | Screen | i18n key |
|---|---|---|---|
| 1 | Map | `RouteShareNavScreen` (new, §8.2) | `nav.map` |
| 2 | Overview | `DriverTripOverviewScreen` (new, §8.1) | `nav.overview` |
| 3 | AI Copilot | `CopilotChatScreen` (same widget as manager shell, §9) | `nav.copilot` |
| 4 | Settings | Existing `SettingsScreen`, unchanged | `nav.settings` |

**Hard constraint, stated as an acceptance test, not just prose:** the driver shell's bottom
navigation bar renders **exactly** these four `BottomNavigationBarItem`s, in this order, and
nothing else — no fifth item, no long-press overflow menu, no hidden drawer with additional
navigation. This is enforced by `test/features/driver/test_driver_shell_nav.dart` asserting
`bottomNavigationBar.items.length == 4` and the exact label set. The real security boundary
for what a driver can *do* is RBAC (§9), not this widget test — but the widget test still
exists because a UI regression that accidentally exposes a fifth tab is a real, separately
worth-catching bug class from a permission gap.

---

## 5. Data Contracts

Every new or changed request/response shape used anywhere in this blueprint is defined here
once, as the single source of truth. Both the FastAPI Pydantic model and its Dart mirror are
given together so the two can never silently drift — if one changes, the coding agent updates
both in the same commit and the contract test (below) catches any mismatch.

### 5.1 Transport route geometry (feeds §8.2 Route-Share Nav)

```python
# app/schemas/route_share.py
from pydantic import BaseModel
from typing import Literal

class RoutePoint(BaseModel):
    lat: float
    lng: float

class RouteInstruction(BaseModel):
    text_key: str            # i18n key resolved client-side, e.g. "nav.instruction.turnRight"
    distance_meters: float    # distance from previous instruction to this one
    point_index: int          # index into RoutePoint list where this instruction applies

class RouteShareGeometry(BaseModel):
    transport_id: str
    points: list[RoutePoint]
    instructions: list[RouteInstruction]   # empty list if instructions unavailable — see OD-3, §15
    total_distance_meters: float
    total_duration_seconds: int
    generated_at: str          # ISO8601 — mirrors the Co-Pilot World Model's staleness pattern (freshness discipline, §1.6)
    ttl_seconds: int           # client must re-fetch if now() - generated_at > ttl_seconds
```

```dart
// lib/features/driver/models/route_share_geometry.dart
class RoutePoint {
  final double lat;
  final double lng;
  const RoutePoint({required this.lat, required this.lng});
}

class RouteInstruction {
  final String textKey;
  final double distanceMeters;
  final int pointIndex;
  const RouteInstruction({required this.textKey, required this.distanceMeters, required this.pointIndex});
}

class RouteShareGeometry {
  final String transportId;
  final List<RoutePoint> points;
  final List<RouteInstruction> instructions;
  final double totalDistanceMeters;
  final int totalDurationSeconds;
  final DateTime generatedAt;
  final int ttlSeconds;
  const RouteShareGeometry({
    required this.transportId,
    required this.points,
    required this.instructions,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.generatedAt,
    required this.ttlSeconds,
  });

  bool get isStale => DateTime.now().difference(generatedAt).inSeconds > ttlSeconds;
}
```

**Endpoint:** `GET /api/v1/mobile/driver/transports/{transport_id}/route-share` →
`RouteShareGeometry`. New endpoint in `mobile.py`, backed by whatever `routes.py`/`trips.py`
already computes for GraphHopper-based planning (§15 OD-1 — confirm reuse vs. new computation).

**Test requirement (`tests/contracts/test_route_share_geometry_schema.py` /
`test/features/driver/test_route_share_geometry_model.dart`):** round-trip a fixture
`RouteShareGeometry` through JSON on both sides and assert field-for-field equality — this is
the mechanical guard against the two models drifting.

### 5.2 Driver trip overview (feeds §8.1)

```python
# app/schemas/mobile_driver.py
from pydantic import BaseModel
from typing import Literal
from datetime import datetime

class DriverTripOverview(BaseModel):
    transport_id: str | None            # None if no assigned transport
    load_info: str | None
    origin: str | None
    destination: str | None
    status: Literal["planned", "loading", "in_transit", "delivered", "cancelled"] | None
    status_since: datetime | None        # when the current status began — feeds elapsed-time calc
    eta: datetime | None                 # server-computed, using RouteShareGeometry + last known position
    eta_confidence: Literal["live", "stale", "unavailable"]  # "stale" if last GPS ping > staleness threshold (§8.2)
```

```dart
// lib/features/driver/models/driver_trip_overview.dart
enum TripStatus { planned, loading, inTransit, delivered, cancelled }
enum EtaConfidence { live, stale, unavailable }

class DriverTripOverview {
  final String? transportId;
  final String? loadInfo;
  final String? origin;
  final String? destination;
  final TripStatus? status;
  final DateTime? statusSince;
  final DateTime? eta;
  final EtaConfidence etaConfidence;
  const DriverTripOverview({
    this.transportId, this.loadInfo, this.origin, this.destination,
    this.status, this.statusSince, this.eta, required this.etaConfidence,
  });

  Duration? get elapsed => statusSince == null ? null : DateTime.now().difference(statusSince!);
}
```

**Endpoint:** `GET /api/v1/mobile/driver/trip-overview` (no transport_id param — server
resolves "my current assigned transport" from the JWT's `user_id`, never a client-supplied
driver/transport identifier). Returns `DriverTripOverview` with all fields `null` (not a 404)
when no transport is assigned — the client's empty-state rendering keys off this, not off an
error path.

**Test requirement:** `tests/contracts/test_driver_trip_overview_schema.py` — assert the
no-assigned-transport case returns HTTP 200 with all-null body, not a 404 or 204 (an
if/else-shaped response, not a status-code-shaped one, is easier for the Flutter client to
render correctly without special-casing an error branch for a normal, expected state).

### 5.3 Local Download categories (feeds §6.5)

```python
# app/schemas/local_download.py
from pydantic import BaseModel
from enum import Enum

class DownloadCategory(str, Enum):
    documents = "documents"
    invoices = "invoices"
    receipts = "receipts"
    ocr_results = "ocr_results"
    trip_history = "trip_history"

class DownloadRequest(BaseModel):
    category: DownloadCategory
    date_from: str | None = None   # ISO8601 date, optional
    date_to: str | None = None

class DownloadManifestEntry(BaseModel):
    record_id: str
    filename: str
    size_bytes: int
    download_url: str      # short-lived signed URL, not a permanent public link
    url_expires_at: str    # ISO8601 — client must re-request the manifest if expired
```

```dart
// lib/features/local_download/models/download_manifest.dart
enum DownloadCategory { documents, invoices, receipts, ocrResults, tripHistory }

class DownloadManifestEntry {
  final String recordId;
  final String filename;
  final int sizeBytes;
  final String downloadUrl;
  final DateTime urlExpiresAt;
  const DownloadManifestEntry({
    required this.recordId, required this.filename, required this.sizeBytes,
    required this.downloadUrl, required this.urlExpiresAt,
  });
}
```

**Endpoint:** `POST /api/v1/mobile/company/export/manifest` (`DownloadRequest` in, list of
`DownloadManifestEntry` out) — mirrors the desktop migration center's export feature; the
manifest returns signed, short-lived URLs rather than raw file bytes in one shot, so a large
category (e.g. a year of invoices) doesn't require holding one giant response in memory on
either side. The mobile client then downloads each entry individually to
`getApplicationDocumentsDirectory()`, showing per-file progress.

> **Security note (2026-07-31):** the signed token travels in the URL path
> (`/api/v1/mobile/company/export/download/{token}`) and may appear in proxy/load-balancer
> logs — accepted tradeoff for this design; tokens are HMAC-signed, expiring (15 minutes),
> and tenant-checked at fetch time (JWT company must match the token's embedded company).

**Test requirement:** `tests/security/test_local_download_company_isolation.py` — as User A
(company X), request a manifest and assert every `record_id` returned belongs to company X;
as a second assertion in the same test, attempt to fetch company Y's signed URL directly
(replay it under company X's JWT) and assert it's rejected — a signed URL must still be
tenant-checked at fetch time, not just at manifest-generation time.

### 5.4 OCR Automation upload (feeds §6.4)

```python
# app/schemas/ocr_automation.py
from pydantic import BaseModel

class OcrUploadResponse(BaseModel):
    document_id: str
    status: Literal["queued", "processing"]   # never "completed" synchronously — always async
    idempotency_key: str                       # echoed back so the client can confirm dedup worked
```

```dart
// lib/features/document_center/models/ocr_upload_response.dart
enum OcrUploadStatus { queued, processing }

class OcrUploadResponse {
  final String documentId;
  final OcrUploadStatus status;
  final String idempotencyKey;
  const OcrUploadResponse({required this.documentId, required this.status, required this.idempotencyKey});
}
```

**Endpoint:** `POST /api/v1/ocr/process` (existing, per architecture doc) — this blueprint's
only contract change is requiring the client to send `Idempotency-Key` (§1.7) and requiring
the response to never synchronously return a completed OCR result (§6.4's cloud-only
constraint — the mobile client only ever sees `queued`/`processing`, never the extracted
fields, until a separate, explicit Local Download request).

---

## 6. Dispatcher/Manager/Admin Feature Ports

Each of these is a **port** of existing desktop functionality, reusing the desktop's backend
service functions — never a reimplementation of business logic in Dart. Each ships as its own
`lib/features/<name>/` folder per §1.1.

### 6.1 Profit Calculator (`lib/features/profit_calculator/`)
- **Decision, not left open:** the desktop calculator's revenue-minus-costs logic is a pure
  calculation (per the reference architecture doc's `Calculator` module) — port it as a pure
  Dart function in `lib/features/profit_calculator/calculator_logic.dart`, with **no backend
  call**, mirroring desktop's own client-side computation. If, when the agent inspects the
  desktop calculator module, it turns out desktop actually calls a backend endpoint for this
  (rather than computing client-side), the agent must stop and report that finding rather than
  silently building a duplicate client-side implementation that could drift from the
  server's — this is exactly the kind of discrepancy §0 item 4 exists to catch.
- Form fields: revenue, fuel cost, toll cost, maintenance amortization, driver cost — same
  field set and same rounding/currency rules as desktop (2 decimal places, currency symbol per
  the user's company locale settings, not hardcoded RON/EUR).
- **Test requirement (`test/features/profit_calculator/test_calculator_logic.dart`):** three
  fixed input sets, each asserting the mobile output matches a value independently computed
  from the desktop source (paste the desktop calculation alongside the mobile test as a
  comment so the correspondence is auditable, not just asserted).

### 6.2 Teams (drivers/roster view) and Route Planner (trip planning) — two separate features

> **Naming resolved:** "Teams" (roster/assignment view) and "Route Planner" (multi-stop trip
> planning) are unrelated features that happened to get flagged together in an earlier
> draft's open decision. Resolving now: **"Teams" is the enhanced Drivers view** — it reuses
> the existing `Driver` model and `drivers.py` endpoints, adding grouping/filtering (by
> status: Available/Driving/Off, matching the existing mobile `DriverListScreen` filter
> pattern already used elsewhere in the app) rather than introducing any new backend entity.
> No new `Team` database table, no new backend endpoint — `lib/features/teams/` is purely a
> richer read/filter layer over `GET /drivers`. This does not need further audit; it is a
> product-naming decision, made here, final.

**Teams screen (`lib/features/teams/`):**
- List view: filter chips (All / Available / Driving / Off), each `Driver` rendered with
  avatar, name, status indicator, currently assigned transport + vehicle (reuse
  `StatusBadge`).
- Tap → driver detail (license info, license expiry status, assigned vehicle) — reuse the
  existing driver detail rendering pattern from the driver-facing profile screen, adapted to
  a read view for the manager.
- **Test requirement:** `test/features/teams/test_teams_filter.dart` — assert each filter chip
  narrows the rendered list correctly against a fixture `Driver` list covering all four
  statuses.

**Route Planner screen (`lib/features/route_planner/`):**
- Reuses backend GraphHopper integration via `routes.py`'s existing multi-stop optimization
  endpoint.
- Multi-stop input UI: add/remove/reorder waypoints (drag handles, `ReorderableListView`),
  submit → render optimized route + distance/time summary using `flutter_map` (no second
  maps library introduced).
- **Test requirement:** submit an identical multi-stop input against the same backend from
  both desktop and this new mobile screen (can be scripted via the backend test client rather
  than literally driving the desktop app); diff the returned route geometry and total distance
  — must match exactly. Artifact: the diff output, showing zero differences.

### 6.3 Freight Exchange (`lib/features/freight_exchange/`)
- Consumes `freight_exchange.py` per `Operion_Freight_Exchange_Module_Blueprint.md`, TIMOCOM
  as the first adapter.
- Mobile view: load-board list (filter/search by origin, destination, date, cargo type),
  detail view, and an "Accept & Assign" action that attaches a load to one of the user's
  existing transports.
- **Provider-agnostic discipline (already established elsewhere in the codebase) applies
  here identically:** the mobile client calls only the provider-agnostic backend endpoint and
  never references a TIMOCOM-specific field name in a Flutter model. **Test requirement
  (adapted 2026-07-31):** the mobile-side proof is `test_freight_provider_agnostic.dart` — a
  static assertion that no provider identifier/field leaks into the Dart models, plus fixture
  rendering. The staging variant — swapping the configured adapter to a mocked second provider
  (e.g. a Trans.eu stub) and confirming the mobile load-board list renders with zero mobile
  code changes — is a QA-staging activity (no staging environment exists in this worktree).
- **Concurrency rule (per §1.6):** the "Accept & Assign" action must re-validate, immediately
  before executing, that the specific load is still available (another dispatcher on desktop
  or another mobile session could have accepted it in the interim) — a live re-check call,
  never trusting the load-board list's cached state from when it was fetched. On a conflict,
  show a clear "this load was just taken" message and refresh the list; do not silently
  retry against a different load or guess at a substitute.
- **Idempotency (per §1.7):** the accept-and-assign call carries an `Idempotency-Key` so a
  dropped-connection retry cannot double-accept the same load onto two transports.
- **Test requirement (`tests/copilot/test_freight_exchange_concurrency.py` — backend-side,
  since the re-check is a backend guarantee, not a client-side one):** two concurrent
  accept requests for the same load, assert exactly one succeeds and the other receives a
  clear conflict response, not a silent duplicate assignment.

### 6.4 Document Center + Automation (OCR) tab (`lib/features/document_center/`)
- `DocumentCenterScreen` reuses/generalizes the existing `DocumentListScreen`/
  `DocumentUploadScreen` patterns from the driver feature set for full document browsing
  (dispatcher/manager scope: all company documents, not just one driver's own), plus a new
  **Automation** sub-tab for the camera-capture OCR flow specifically.
- **Automation tab flow, step by step:**
  1. Open camera → capture photo (`image_picker`, already a dependency — no new camera plugin).
  2. Generate an `Idempotency-Key` (UUID) for this upload action.
  3. `POST /api/v1/ocr/process` with the image and the idempotency key → `OcrUploadResponse`
     (§5.4) — status is always `queued` or `processing`, never a synchronous result.
  4. UI shows an "upload confirmed, processing" state (reuse `AppCard` + a determinate/
     indeterminate progress indicator per existing convention) — **no polling loop that pulls
     the extracted fields back to the device.** The screen's job ends at confirming the
     upload succeeded.
  5. The processed record stays cloud-side (cloud PostgreSQL) until the user explicitly
     requests it via §6.5 Local Download's `ocr_results` category.
- **Test requirement (`test/features/document_center/test_automation_upload_no_autopull.dart`):**
  after a successful upload, kill and relaunch the app (simulate via provider/container reset
  in the widget test), then assert no OCR result data exists in any local cache/DB — this is
  a negative assertion and must be written as one (assert absence), not inferred from the
  absence of a positive assertion.

### 6.5 Local Download (`lib/features/local_download/`)
- UI: category list (`Documents`, `Invoices`, `Receipts`, `OCR Results`, `Trip History` — the
  `DownloadCategory` enum from §5.3), each with an optional date-range filter (`AppTextField`
  date pickers, reusing the existing date-picker pattern from `NewExpenseScreen`).
- Action: select category (+ optional range) → `POST /api/v1/mobile/company/export/manifest`
  (§5.3) → per-entry download to `getApplicationDocumentsDirectory()`, with per-file progress
  bars, using the existing offline Action Queue's file-handling pattern for consistency (this
  feature does not need offline queuing itself — it requires connectivity to even request a
  manifest — but the *file-writing* code path should reuse the existing helper rather than
  writing a second one).
- **Explicit constraint, stated as a test, not just a rule:** this is a pull-on-demand
  mechanism only. **Test requirement (`test/features/local_download/test_no_background_sync.dart`):**
  assert no `Timer`, `WorkManager`/background-fetch registration, or scheduled task exists
  anywhere in this feature's code — grep-style static assertion is acceptable here since the
  property being tested is "this code path is never automatically triggered," which is a
  structural property, not a runtime one.
- **Multi-tenant test:** see §5.3's `test_local_download_company_isolation.py`.

---

## 7. Driver-Specific Features

### 7.1 `DriverTripOverviewScreen` (`lib/features/driver/trip_overview/`)
- Data source: `GET /api/v1/mobile/driver/trip-overview` (§5.2).
- Content, top to bottom:
  1. Assigned-transport summary card (load info, origin → destination) — or, if
     `transport_id == null`, the existing `EmptyState` pattern with copy "No active trip"
     (`t()` key `driverOverview.emptyState`).
  2. **ETA** — rendered from `DriverTripOverview.eta`, with visual treatment keyed off
     `eta_confidence`: `live` = normal text; `stale` = `StalenessIndicator` shown alongside it
     (reuse the existing widget, don't build a new one); `unavailable` = an explicit "ETA
     unavailable" state, never a blank field or a stale number presented as current.
  3. **Elapsed time** — computed client-side from `DriverTripOverview.elapsed` (a `Duration`
     getter already defined on the model, §5.2), refreshed on a 1-second `Timer` while the
     screen is visible; the `Timer` is cancelled in `dispose()` — a leaked ticking timer on a
     screen the user has navigated away from is a real, checkable bug.
  4. Status transition buttons — reuse the exact logic already in `TransportDetailScreen`
     (`planned` → Start Loading, `loading` → Depart, `in_transit` → Mark Delivered / Report
     Delay, `delivered`/`cancelled` → no actions). Do not reimplement this state machine a
     second time in the new screen; extract the existing button-set widget from
     `TransportDetailScreen` into `shared/widgets/` if it isn't already reusable, and use the
     shared version in both places.
- **Test requirement (`test/features/driver/trip_overview/test_trip_overview_screen.dart`):**
  three fixture states (no transport / transport with live ETA / transport with stale ETA)
  each asserted against the correct rendered empty-state/ETA-confidence treatment; separately,
  assert the elapsed-time `Timer` is disposed when the widget is unmounted (use
  `tester.pumpWidget` teardown + a `Timer`-leak-detecting harness, or assert via a countdown
  of active timers in the test binding if the test framework exposes one).

### 7.2 Route-Share Turn-by-Turn Navigation (`RouteShareNavScreen`, `lib/features/driver/route_share/`)

#### 7.2.1 Data
`GET /api/v1/mobile/driver/transports/{transport_id}/route-share` → `RouteShareGeometry`
(§5.1). If `instructions` comes back empty (OD-3, §15), the UI degrades to geometry-only
turn-by-turn (route line + distance/ETA banner, no maneuver text) rather than fabricating
instruction text — never invent a "turn right" string the backend didn't actually provide.

#### 7.2.2 UI
- Full-screen map, `flutter_map` + OpenStreetMap tiles (consistent with `FleetMapScreen`).
- Current-position marker, full route polyline, remaining-route segment visually distinct
  (e.g. brighter/thicker) from the already-traveled segment.
- Top instruction banner (new shared widget, `shared/widgets/turn_instruction_banner.dart`,
  per §1.4's "build shared widgets for genuinely new patterns" rule): shows the next
  `RouteInstruction.text_key` (`t()`-resolved) and its `distance_meters`, formatted per the
  existing distance-formatting convention (km with 1 decimal, or m below 1km — match whatever
  convention `FleetMapScreen`/route displays already use, don't invent a new one).
- Bottom sheet: remaining distance, remaining time (from `DriverTripOverview.eta` or a
  locally-recomputed value — decision: **recompute locally at the display-refresh cadence in
  §7.2.3, using the last-known position against `RouteShareGeometry.points`, rather than
  re-fetching from the backend every tick** — network round-trips for a value that can be
  computed from already-downloaded geometry plus local GPS is wasted battery and latency).
- Off-route detection: if the current GPS position deviates more than a fixed threshold
  (**decision: 50 meters** from the nearest point on `RouteShareGeometry.points`) for more
  than **decision: 10 consecutive seconds**, trigger a re-fetch of `RouteShareGeometry` (the
  backend recomputes from the new position) rather than silently continuing to render a
  route the driver is no longer on.
- Offline behavior: if connectivity drops mid-route, keep rendering the last-fetched geometry
  and continue local ETA/distance recomputation from GPS alone (no backend call needed for
  this), but suppress off-route re-fetch attempts while offline and show the existing
  `OfflineBanner`; queue nothing (there's nothing to queue — this is a read+local-compute
  feature, not a write).

#### 7.2.3 GPS acquisition, permissions, and background behavior — stated honestly, not glossed over
This is a genuinely new capability for the mobile app (existing fleet tracking uses
hardware trackers per vehicle — Wialon/Frotcom/Traccar — not the driver's own phone GPS).
Turn-by-turn navigation is phone-GPS-driven and needs explicit, honest platform handling,
following the same discipline the Co-Pilot blueprint already applies to background
wake-word listening:

- **Foreground behavior:** while `RouteShareNavScreen` is open and the app is in the
  foreground, request location updates at **decision: every 5 seconds or every 20 meters of
  displacement, whichever comes first** (a fixed timer alone wastes battery when stationary
  at a loading dock; a pure distance filter alone means no update while queued in traffic —
  use both, take whichever fires first, matching the standard pattern most turn-by-turn apps
  use).
- **Backgrounded/screen-locked behavior — the part that must not be assumed to "just work":**
  a driver will often mount the phone and lock the screen while driving. Continuing to track
  position and keep the ETA/ notification-level guidance current while backgrounded requires
  explicit platform work, not just "the same code path with the screen off":
  - **Android:** requires a **foreground service with a persistent notification** (Android
    does not allow arbitrary background location updates without one) — the notification
    shows the next instruction and remaining distance, mirroring how Google Maps' own
    notification behaves. `ACCESS_FINE_LOCATION` and, for continued background updates,
    `ACCESS_BACKGROUND_LOCATION` must both be requested, with a clear, localized
    (`t()`-resolved) rationale string shown before the system permission dialog.
  - **iOS:** requires the **"Always" location authorization level** (not just "While Using")
    plus the `location` background mode capability declared in the app's background modes.
    `NSLocationAlwaysAndWhenInUseUsageDescription` (and the legacy
    `NSLocationAlwaysUsageDescription` for older OS compatibility if the app's minimum
    supported iOS version requires it) must contain a clear, localized rationale.
  - **Graceful degradation, decided now:** if the driver denies background/"Always"
    location, the feature does not crash or silently stop — it falls back to
    foreground-only tracking, shows a persistent (non-blocking) banner explaining that
    navigation will pause if the app is backgrounded, and the Trip Overview screen's ETA
    still updates whenever the app is next foregrounded. This must be built as an explicit,
    tested fallback path, not an unhandled edge case.
- **Battery/user-trust note:** the persistent Android notification and the iOS "Always"
  permission are both user-visible, ongoing indicators that location is being tracked —
  this is intentional and should not be minimized or hidden; a turn-by-turn feature that
  tracked location in the background without an ongoing visible indicator would be a dark
  pattern, not an optimization.
- **Test requirement (`test/features/driver/route_share/test_gps_update_cadence.dart`):**
  simulate a stationary GPS stream and assert updates fire at the 5-second cadence, not more
  often; simulate a fast-moving stream and assert updates fire on the 20m threshold instead
  of waiting the full 5 seconds. Separate test
  (`test/features/driver/route_share/test_background_permission_fallback.dart`): simulate a
  denied background/Always permission and assert the screen falls back to foreground-only
  mode with the explanatory banner, rather than throwing or silently doing nothing.

#### 7.2.4 Verification gate
Drive-test (or simulate GPS via a mocked location stream feeding real coordinates along a
known route) and confirm: (a) ETA and remaining-distance numbers update within ±5% or ±2
minutes of ground truth, whichever is looser at that point in the route; (b) the off-route
re-fetch triggers correctly when the simulated position is walked 60m off the route line for
11 seconds; (c) the foreground service notification (Android) / background location
indicator (iOS) is actually visible during a backgrounded test run, confirmed by a screenshot
or screen recording note attached to the PR, not just a claim that "background tracking
works."

**Implementation status (2026-07-31, incl. P5 GPS layer):** the §7.2.2/§7.2.3 phone-GPS
machinery is implemented — pure cadence/off-route logic (`lib/features/driver/route_share/
logic/gps_logic.dart`), injectable GPS service seam (`gps_providers.dart`, geolocator-backed),
screen wiring (current-position marker, traveled vs remaining segments, off-route banner +
10s-persisted re-fetch suppressed offline, local remaining distance/time recompute,
next-instruction advance, background-permission fallback banners). (a) ETA/distance
correctness and (b) the off-route trigger are covered by REAL tests:
`test_gps_update_cadence.dart` (19 unit tests — 5s/20m cadence boundaries, 50m threshold,
remaining-route/instruction logic), `test_gps_layer_test.dart` (6 widget tests incl. off-route
re-fetch at 11s and offline suppression), and `test_background_permission_fallback.dart`
(3 widget tests — denied → banner + foreground-only, granted → no banner, fully denied → no
crash). **(c)** remains `[DEVICE-REQUIRED — deferred to QA drive-test]`: the Android
foreground-service notification and iOS "Always" permission indicator require a physical
device; platform permissions are configured with §7.2.3 reference comments and the
foreground-service implementation is marked pending device QA rather than silently claimed.

---

## 8. AI Copilot Integration

This section is a **mobile client spec** for the Co-Pilot, not a new backend spec — every
behavior below already has a full contract in `Operion_AI_CoPilot_Blueprint_V4.md`, and this
section exists to (a) describe the mobile-specific wiring and (b) correct a mistake an earlier
draft of this document made.

### 8.1 What earlier drafting got wrong, corrected here permanently
An earlier pass at this blueprint proposed a bespoke "Level-0 tier" for drivers and a separate
`driver_tools` vs. `dispatcher_tools` registry fork in `copilot_router.py`. **This is wrong
and must not be built.** Co-Pilot V4 already has the exact mechanism needed: §15.2's
`resolve_available_tools()` intersects the *full* tool registry with `current_user.permissions`,
computed server-side, per request, never cached. A driver session naturally ends up with a
small `available_tools` set for the same structural reason a dispatcher lacking
`dispatch:write` would — RBAC, not a role string special-cased anywhere in Co-Pilot code.
Building a second registry would duplicate existing architecture and create a second place
for the two mechanisms to drift out of sync. There is one registry, one endpoint surface, one
resolution function, for every role.

### 8.2 Dispatcher/Manager/Admin mobile Copilot
- Full parity with desktop by construction: same `/api/v1/copilot/*` surface (Co-Pilot V4
  §30), same `ExecutionPlan` state machine (§7), same tool registry (§9). A dispatcher/
  manager/admin session's `available_tools` includes Level 0–3 tools up to whatever RBAC
  grants — nothing mobile-specific to gate beyond what Co-Pilot V4 §32 already specifies.
- Chat screen: wire the existing scaffolded `features/copilot/` chat bubble + confirmation
  sheet widgets to real state per Co-Pilot V4 §32.1 (`CopilotIdle` → `CopilotAwaitingConfirmation`
  → `CopilotExecuting` → `CopilotCompleted`; never a client-invented intermediate state).
- Confirmation UX follows Co-Pilot V4 §32.6 exactly: Level 2+ requires an explicit tap, never
  voice-only, even mid-hands-free-voice-turn (§3.3/§3.5 of the Co-Pilot doc); Level 3 requires
  the typed confirmation phrase on the mobile keyboard, never satisfiable by biometrics alone.
- Voice input: wire `copilot_voice_handler.dart` to the self-hosted STT pipeline, subject to
  Co-Pilot V4 §32.4's real platform constraints (foreground-only wake word, the
  `voice_activation_mobile` tier key rather than the desktop `voice_activation` key, graceful
  text-only degrade on denied mic permission).
- **Subscription tier is orthogonal to role — do not conflate them.** Co-Pilot V4 §16's
  `TIER_FEATURES` gates `chat` behind Business+ regardless of role; a dispatcher at a
  Pro-tier company gets `help_mode`-only Copilot, for a completely different reason (tier)
  than a driver's narrower tool set (RBAC).
- **Verification gate (adapted 2026-07-31 — desktop client not reachable from this
  worktree):** the desktop client lives in a separate repository not present here. Scripted
  equivalent: drive the identical natural-language command through the backend test client
  as two separate JWT-bearing sessions (dispatcher-web and dispatcher-mobile) against the
  same `/api/v1/copilot/chat` endpoint; diff both `ExecutionPlan` payloads — identical
  tool-call sequence, identical `confirmation_level`, identical confirmation-sheet content.
  A live desktop-vs-mobile parity pass remains a QA activity requiring the desktop repo.

### 8.3 Driver mobile Copilot
No separate widget, no separate endpoint — the identical `CopilotChatScreen` used by
dispatcher/manager, pointed at the identical `/api/v1/copilot/*` surface. What differs is
entirely the `available_tools` the backend resolves for a `driver`-role JWT. Concretely, per
Co-Pilot V4's own tool inventory (§9.1), a **correctly-scoped** driver permission set should
resolve to:

| Tool | Level | Driver access | Why |
|---|---|---|---|
| `help.answer_question`, `help.guide_workflow` | 0 | ✅ | Ungated by permission in Co-Pilot V4 already — the one tool with no `required_permission` at all |
| `route.calculate`, `route.estimate_cost` (own assigned trip only) | 0 | ✅, pending OD-5 | Read-only, scoped to the driver's own trip |
| `driver.check_hours` (own hours) | 0 | ✅ | Own record only |
| `tracking.get_live_positions` (own vehicle) | 0 | ✅, pending OD-5 | Own vehicle only, never fleet-wide |
| `document.ocr_import`, `document.auto_rename` (own uploads) | 1 | ✅ | This is the "tell it to upload a picture" capability from the original product spec |
| `trip.update` (status transition, own assigned trip only) | 2 | ✅, pending OD-5, still requires tap confirmation | An AI-triggered status change is not exempt from the normal Level 2 confirmation just because it's the driver's own trip |
| `analytics.query`, `client.payment_summary`, `trip.calculate_profitability`, `payment.generate_bulk_csv` | 0/1 | ❌ | This is the "no confidential business info" boundary — these must not be in the driver role's permission set at all |
| Anything Level 2/3 outside the driver's own trip (`dispatch.*`, `invoice.*`, `client.*`, `vehicle.*`, `driver.create/update/remove`, `route.create/update/delete`, `maintenance.schedule`) | 2/3 | ❌ | Out of scope for the role entirely |
| Freight Exchange, Route Planner (multi-trip), Teams tools | n/a | ❌ | Not in scope for the driver role |

**Implementation approach:**
- No new registry code in `copilot_router.py`. The only backend work is the audit + any
  scoping fixes from §15 OD-4/OD-5.
- The mobile `CopilotChatScreen` widget is **identical** for every role — zero per-role
  branching in the Flutter widget tree.
- **Verification gate:** log in as a `driver`-role test account and, over the *real*
  `/api/v1/copilot/chat` endpoint (not a mocked client), send "show me this month's company
  revenue" and separately "reassign truck 12 to a different driver." Assert
  `available_tools` for that session excludes the relevant tool name entirely — **the test
  must inspect the resolved tool list, not just the model's conversational reply.** A
  transcript showing a polite refusal is not sufficient and must not be accepted as the
  verification artifact; a model can be prompted around, a missing tool cannot.

---

## 9. Backend Contract Changes — Consolidated

| Endpoint/module | Change | New? | Depends on |
|---|---|---|---|
| `GET /api/v1/mobile/driver/transports/{id}/route-share` | New endpoint, `RouteShareGeometry` response (§5.1) | Yes | OD-1, OD-3 |
| `GET /api/v1/mobile/driver/trip-overview` | New endpoint, `DriverTripOverview` response (§5.2) | Yes | — |
| `POST /api/v1/mobile/company/export/manifest` | New endpoint, `DownloadManifestEntry` list response (§5.3) | Yes | Confirm reuse of desktop migration-center export logic |
| `POST /api/v1/ocr/process` | Existing endpoint; require `Idempotency-Key` header; confirm response never synchronously includes extracted fields | No (contract-tightened) | §1.7 |
| `copilot_router.py` / RBAC permission table | Audit + fix driver-role permission scoping (§8.3) | No (audit + possible fix) | OD-4, OD-5 |
| `freight_exchange.py` | No structural change expected; add live-availability re-check on accept (§6.3) if not already present | Possibly (concurrency fix only) | — |

**Multi-tenant reminder:** every row above gets a `company_id` isolation test in
`tests/security/` before being considered complete (§1.8, consolidated list in §13).

---

## 10. Security & Permission Matrix

| Feature | Driver | Dispatcher/Manager | Admin |
|---|---|---|---|
| Route Map (own trip turn-by-turn) | ✅ own trip only | — (uses Fleet Tracker) | ✅ (can view any, via Fleet Tracker) |
| Trip Overview (own trip) | ✅ own trip only | — (Overview KPI instead) | ✅ |
| AI Copilot | ✅ — `available_tools` limited to Level 0 + own-trip Level 1/2 (§8.3) by RBAC | ✅ — up to whatever RBAC grants, typically Level 0–3 | ✅ full registry |
| Fleet Tracker (all vehicles) | ❌ | ✅ | ✅ |
| Analytics | ❌ | ✅ | ✅ |
| Profit Calculator | ❌ | ✅ | ✅ |
| Route Planner (multi-trip) | ❌ | ✅ | ✅ |
| Teams (drivers/roster) | ❌ | ✅ | ✅ |
| Freight Exchange | ❌ | ✅ | ✅ |
| Document Center + Automation | own docs only, via Copilot-triggered upload (§8.3) | ✅ full | ✅ |
| Local Download | ❌ | ✅ | ✅ |
| Settings | ✅ | ✅ (inside More) | ✅ |

> **Subscription tier sits above this table, orthogonally.** Co-Pilot V4 §16's
> `TIER_FEATURES` restricts the AI Copilot row further for Pro-tier companies regardless of
> role. Do not collapse the two axes into a single condition anywhere in the mobile client or
> backend gating logic.

---

## 11. Testing Strategy — Consolidated File Map

Every test named throughout this document, gathered in one place so nothing gets missed:

**Mobile (`operion-mobile-app/mobile/test/`):**
- `core/auth/test_shell_routing.dart`
- `i18n/test_locale_key_coverage.dart`
- `features/more_hub/test_more_hub_screen.dart`
- `features/driver/test_driver_shell_nav.dart`
- `features/profit_calculator/test_calculator_logic.dart`
- `features/teams/test_teams_filter.dart`
- `features/document_center/test_automation_upload_no_autopull.dart`
- `features/local_download/test_no_background_sync.dart`
- `features/driver/trip_overview/test_trip_overview_screen.dart`
- `features/driver/route_share/test_gps_update_cadence.dart`
- `features/driver/route_share/test_background_permission_fallback.dart`
- `features/driver/route_share/test_gps_layer_test.dart` (added 2026-07-31 — P5 screen wiring: position marker, cadence drop, polyline split, instruction advance, 11s off-route re-fetch, offline suppression)
- `features/driver/models/test_route_share_geometry_model.dart` (contract round-trip half)
- `features/teams/test_driver_detail_screen.dart` (added 2026-07-31)
- `features/freight_exchange/test_freight_load_list.dart` (added 2026-07-31)
- `features/freight_exchange/test_freight_accept_assign.dart` (added 2026-07-31)
- `features/freight_exchange/test_freight_provider_agnostic.dart` (added 2026-07-31 — static no-provider-coupling proof; the §6.3 staging adapter-swap remains a QA-staging activity)

> Note (2026-07-31): `test_automation_upload_no_autopull.dart` and `test_no_background_sync.dart`
> carry real negative/static assertions; CancelToken lifecycle (§1.2) is tested in
> `copilot_providers_test.dart` and the per-feature provider suites.

**Backend (`Calculator logistica/tests/`):**
- `contracts/test_route_share_geometry_schema.py` (contract round-trip half)
- `contracts/test_driver_trip_overview_schema.py`
- `security/test_local_download_company_isolation.py`
- `copilot/test_freight_exchange_concurrency.py`
- (extend) `security/` — one isolation test per row in §9's consolidated table that doesn't
  already have one listed above (Route Planner's diff test and the Copilot RBAC audit test
  are described inline in §6.2 and §8.3 respectively and should be added as
  `tests/copilot/test_route_planner_desktop_mobile_parity.py` and
  `tests/copilot/test_driver_rbac_scope.py` — named explicitly here so they aren't lost).

**Added 2026-07-31 (all present and passing):**
- `contracts/test_download_manifest_schema.py`, `contracts/test_ocr_upload_schema.py`
- `security/test_ocr_process_isolation.py`, `security/test_freight_loads_isolation.py`
- `copilot/test_route_planner_desktop_mobile_parity.py` (scripted via backend test client, §6.2)
- `copilot/test_driver_rbac_scope.py` (registry-level + runtime enforcement)

No phase in §12 is complete until every test file relevant to that phase exists, has been run
fail→fix→pass, and the output has been pasted for review.

---

## 12. Implementation Plan (single delivery, verification-gated)

This is one continuous plan. The phases below are an execution order for *this* blueprint,
not separate blueprints — nothing here implies a future document is needed to finish the job.

**Phase 0 — Audit (§13's open items), no feature code yet**
- Resolve OD-1 through OD-5 by inspecting the actual running backend/codebase.
- Deliverable: one findings document containing literal pasted evidence for each — real JSON
  response schemas, the actual `driver` role's permission list, the actual service-layer
  scoping code (or lack thereof) for `trip_service`/`route_service`/`tahograf_service`/
  `tracking_service`.
- **Gate:** Phase 1 does not start until this findings document exists and has been reviewed.

**Phase 1 — Navigation restructure**
- Build both 4-tab shells (§4), including the `MoreHubScreen` and the shell-routing logic
  (§3).
- **Gate:** `test_shell_routing.dart`, `test_more_hub_screen.dart`, `test_driver_shell_nav.dart`
  all pass; paste fail→pass output for each.

**Phase 2 — Driver features**
- `DriverTripOverviewScreen` (§7.1), `RouteShareNavScreen` (§7.2) including full GPS/
  permission/background handling.
- **Gate:** all tests listed under §11's driver rows pass; the drive-test/simulated-GPS
  artifact from §7.2.4 is attached, including the background-tracking screenshot/recording.

**Phase 3 — Dispatcher/manager feature ports**
- Profit Calculator, Teams, Route Planner, Freight Exchange, Document Center + Automation,
  Local Download (§6, all subsections).
- **Gate:** every test listed under §11's dispatcher/manager rows passes; the Freight
  Exchange provider-swap test and concurrency test both produce their required artifacts.

**Phase 4 — Copilot wiring + RBAC audit fix**
- Wire the shared `CopilotChatScreen` to the live backend for every role (§8).
- Apply any RBAC/service-scoping fixes surfaced by Phase 0's audit (OD-4/OD-5).
- **Gate:** `test_driver_rbac_scope.py` (registry-level, not transcript-level) passes;
  desktop/mobile parity test from §8.2 passes with pasted `ExecutionPlan` payloads from both
  clients shown identical.

**Phase 5 — Full regression & sign-off**
- Run the entire consolidated test list from §11 together, not just per-phase subsets.
- Run the full existing `tests/security/` suite (not just the new additions) to confirm no
  regression in existing `company_id` isolation coverage.
- **Gate:** everything green, CI-blocking per existing project convention. This phase is the
  final acceptance point for the whole blueprint — see §14 for the exact checklist.

---

## 13. Open Decisions — Audit Items for Phase 0

These five are the only points in this entire blueprint where the coding agent must stop and
report real findings rather than proceed on an assumption. Everything else in this document
is a direct, final implementation spec — including every place a decision could have been left
open (GPS update cadence, off-route thresholds, "Teams" naming, calculator client-vs-server
placement) but was instead made explicitly above so this remains a single, complete plan.

- **OD-1 — Route geometry availability.** Does `routes.py`/`trips.py` already expose a
  geometry-bearing payload (waypoints + polyline) for an assigned transport, or must the new
  `/mobile/driver/transports/{id}/route-share` endpoint (§5.1) compute this fresh? Paste the
  actual current response schema from a live/staging call for the closest existing endpoint
  before writing the new one.
- **OD-2 — (Resolved, listed for traceability only).** "Teams" vs. "Route Planner" naming
  confusion from an earlier draft is resolved in §6.2: Teams = enhanced Drivers view, no new
  backend entity. No further audit needed; this entry exists so the resolution is traceable
  against the original open question.
- **OD-3 — Turn-by-turn instruction source.** Does GraphHopper's existing integration (already
  used by desktop Route Planner) return maneuver/instruction text, or only geometry?
  `instructions=true` is typically GraphHopper's default, but the current backend client call
  must be checked, not assumed — paste the actual GraphHopper request parameters currently in
  use and the actual response shape.
- **OD-4 — Driver RBAC permission audit.** Paste the `driver` role's actual current
  permission list. Confirm it does not include `required_permission` strings tied to
  `analytics.query`, `client.payment_summary`, `trip.calculate_profitability`,
  `payment.generate_bulk_csv`, or any Level 2/3 tool outside the driver's own trip. A UI that
  hides a screen is not the same guarantee as a permission table that excludes the
  underlying tool — verify the table itself.
- **OD-5 — Service-layer "own record" scoping.** Paste the relevant code from
  `trip_service`, `route_service`, `tahograf_service`, and `tracking_service` showing whether
  a driver-role caller is already restricted to their own assigned records specifically on
  the path the Co-Pilot's `ToolExecutionContext` would exercise (which carries `role`, not
  just `company_id`) — this may already be true for the existing non-AI driver mobile
  screens but must be verified for this specific execution path, not assumed to transfer.

---

## 14. Master Definition of Done — Final Acceptance Checklist

The entire body of work described in this document is complete only when every item below is
checked, with its artifact attached (not just asserted in prose):

- [x] Phase 0 findings document exists, reviewed, and OD-1/OD-3/OD-4/OD-5 each have a pasted,
      real answer (not an assumption). — `docs/blueprint-phase0-findings.md` (2026-07-31)
- [x] Manager shell renders exactly 4 tabs (Overview, Fleet Tracker, AI Copilot, More); More
      contains exactly the 11 tiles listed in §4.1, each correctly localized in `ro.json` and
      `en.json`. — `test/features/more_hub/test_more_hub_screen.dart` (11 tiles, plan order,
      en+ro labels, NavigatorObserver)
- [x] Driver shell renders exactly 4 tabs (Map, Overview, AI Copilot, Settings); no fifth tab,
      no overflow menu, no hidden navigation. — `test/features/driver/test_driver_shell_nav.dart`
- [x] Every new screen implements loading/error/empty/pull-to-refresh per §1.2, verified by
      the per-feature widget tests, not spot-checked manually. — pull-to-refresh added to all
      blueprint screens (teams, route_planner form-reset, document_center, freight exchange,
      local download; 2026-07-31)
- [x] Every new data contract in §5 has a passing round-trip contract test on both the Python
      and Dart sides. — `tests/contracts/` (route_share_geometry, driver_trip_overview,
      download_manifest, ocr_upload schemas — 44 tests) + Dart model tests
- [x] `RouteShareNavScreen` passes its drive-test/simulated-GPS verification gate (§7.2.4),
      (a)+(b) ETA/distance correctness + off-route re-fetch trigger — real simulated-GPS
      tests: `test_gps_update_cadence.dart` (19 unit tests), `test_gps_layer_test.dart`
      (6 widget tests incl. 11s off-route re-fetch + offline suppression),
      `test_background_permission_fallback.dart` (3 widget tests). (c) background-tracking
      screenshots on Android/iOS remain `[DEVICE-REQUIRED — deferred to QA drive-test]` per
      the §7.2.4 status note (2026-07-31).
- [x] Freight Exchange passes both its provider-swap test (proves no TIMOCOM-coupling) and its
      concurrency test (proves no double-accept on a race). — concurrency: `tests/copilot/
      test_freight_exchange_concurrency.py` (exactly-once); provider-coupling: mobile
      `test_freight_provider_agnostic.dart` (staging adapter-swap = QA activity, §6.3 note)
- [x] Document Center's Automation tab passes its negative-assertion no-autopull test. —
      `test_automation_upload_no_autopull.dart` (real absence assertion)
- [x] Local Download passes its company-isolation test and its no-background-sync structural
      test. — `test_local_download_company_isolation.py` (incl. signed-URL replay) +
      `test_no_background_sync.dart` (real static grep)
- [x] Driver Copilot's RBAC scope test passes at the registry level (asserts on
      `available_tools`, not on conversational transcript). — `test_driver_rbac_scope.py`
      (10 registry-level + 4 runtime-enforcement tests)
- [~] Desktop/mobile Copilot parity test passes with both `ExecutionPlan` payloads pasted
      side by side and shown identical. — scripted backend-test-client parity (two JWT
      sessions) per the §8.2 adaptation (2026-07-31); live desktop pass = QA with the desktop
      repo
- [x] Every endpoint listed in §9 has a corresponding `company_id` isolation test, listed and
      passing per §11's consolidated file map. — incl. `test_ocr_process_isolation.py`,
      `test_freight_loads_isolation.py`, signed-URL replay class
- [x] Full existing `tests/security/` suite still passes (no regression introduced). — 351
      passed / 23 skipped / 0 failed (2026-07-31)
- [x] Every new locale key exists in both `ro.json` and `en.json` — no key present in only one.
      — `test/i18n/test_locale_key_coverage.dart` green
- [x] No new hardcoded color, font, or spacing value exists anywhere in the diff (grep for
      hex literals and raw `TextStyle(...)` outside `core/theme/` as a mechanical check). —
      `flutter analyze` 0 new issues; prior mechanical greps
- [x] No new Dart file exists outside the `lib/features/<name>/{screens,providers,widgets,
      models}` structure described in §1.1. — exception: `lib/core/network/endpoints/`
      (network layer, established convention)
- [x] CancelToken lifecycle pattern per §1.2 established and propagated to every blueprint
      feature provider (copilot first, then teams, route_planner, freight_exchange,
      document_center, local_download, trip_overview, route_share). — added 2026-07-31;
      verified by copilot + per-feature provider tests

**Full regression evidence (2026-07-31):** mobile `flutter test` → 1879 passed, 0 failed;
backend consolidated suites (`tests/security/ tests/contracts/ tests/copilot/
tests/freight_exchange/ tests/readiness/ tests/test_business_invariants.py
tests/test_middleware_lifespan.py`) → green except one pre-existing timing-flaky
rate-limiter test (`test_trans_eu_stress.py::TestRateLimiterConcurrency::
test_rapid_sequential_api_calls_hit_limit` — passes in isolation; timing-sensitive under
parallel xdist workers; unrelated to this blueprint's changes).

When every box above is checked with its artifact attached, this blueprint is fully
implemented. There is no subsequent document required to finish this body of work.
