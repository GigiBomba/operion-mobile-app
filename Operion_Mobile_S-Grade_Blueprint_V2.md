# Operion Mobile App — S-Grade Upgrade Blueprint (V2)

> **Audience:** AI coding agents (OpenCode / DeepSeek V4 Pro / Kimi) executing under Gigi's supervision, and any human engineer reviewing their output.
> **Scope:** `mobile_app/` (Flutter/Dart) + backend additions under `backend/api/v1/mobile/` (FastAPI/PostgreSQL/Redis/Celery).
> **Goal:** Full functional parity between Dispatcher/Manager mobile experience and the PySide6 desktop app, executed as a sequence of small, independently verifiable phases.
> **How this document is organized:** Part 1 (sections 0–15) is the technical specification — what to build, exactly, with concrete schemas, endpoint contracts, provider signatures, and test targets. Part 2 (section 16 onward) is the **execution program** — one ready-to-paste implementation prompt per phase, followed by a ready-to-paste verification prompt for that same phase. An agent (or Gigi) should never move to the next phase's implementation prompt until that phase's verification prompt has come back clean.
>
> **⚠️ RECONCILIATION NOTICE (2026-08-03, per §14 item 10):** Phases 0–6 of this blueprint were implemented and the discrepancies between this document and the real codebase were recorded during execution. The complete registry of implementation-time adaptations is in **Appendix A — Implementation-Time Adaptations Registry** at the end of this document. Where this document and the real code disagree, **the real code wins** (per §15); the appendix records each known deviation so the document stays honest.

---

## Table of Contents — Part 1 (Specification)

0. [Design Philosophy: Parity ≠ Cloning](#0-design-philosophy-parity--cloning)
1. [Current State: Gap Analysis vs Desktop](#1-current-state-gap-analysis-vs-desktop)
2. [Target Feature Parity Matrix](#2-target-feature-parity-matrix)
3. [Information Architecture Redesign](#3-information-architecture-redesign)
4. [New/Upgraded Screens — Full Technical Spec](#4-newupgraded-screens--full-technical-spec)
5. [State Management — Exact Provider Contracts](#5-state-management--exact-provider-contracts)
6. [Backend — Exact Endpoint Contracts](#6-backend--exact-endpoint-contracts)
7. [Offline & Sync — Exact Extension Points](#7-offline--sync--exact-extension-points)
8. [RBAC on Mobile — Exact Permission Matrix](#8-rbac-on-mobile--exact-permission-matrix)
9. [Convenience & Mobile-Native Features](#9-convenience--mobile-native-features)
10. [Visual & Interaction Design (S-Grade UI)](#10-visual--interaction-design-s-grade-ui)
11. [Performance & Reliability Targets](#11-performance--reliability-targets)
12. [Security Hardening (Mobile-Specific)](#12-security-hardening-mobile-specific)
13. [QA Strategy — Exact Test Suites](#13-qa-strategy--exact-test-suites)
14. [Master Definition of Done](#14-master-definition-of-done)

## Table of Contents — Part 2 (Execution Program)

15. [How To Use These Prompts](#15-how-to-use-these-prompts)
16. [Phase 0 — Foundations & Scaffolding](#phase-0--foundations--scaffolding)
17. [Phase 1 — Records Core (Fleet, Drivers, Clients)](#phase-1--records-core-fleet-drivers-clients)
18. [Phase 2 — Analytics, History & Global Search](#phase-2--analytics-history--global-search)
19. [Phase 3 — Finance (Invoicing, e-Factura, CMR, Maintenance)](#phase-3--finance-invoicing-e-factura-cmr-maintenance)
20. [Phase 4 — Configuration & Admin (Team Mgmt, Settings, Tachograph)](#phase-4--configuration--admin-team-mgmt-settings-tachograph)
21. [Phase 5 — Convenience Layer](#phase-5--convenience-layer)
22. [Phase 6 — Full-System Release QA](#phase-6--full-system-release-qa)

---

# PART 1 — SPECIFICATION

## 0. Design Philosophy: Parity ≠ Cloning

"Let dispatcher/manager do as much as the PC version can" means **functional parity in mobile-native form**, not a shrunk desktop clone:

- Every **action** available on desktop (create a trip, edit a driver, finalize an invoice, resolve an alert, approve a freight load, assign a truck) must be reachable on mobile.
- Every **piece of information** on desktop (analytics, tachograph compliance, maintenance forecasts, invoice aging) must be viewable on mobile, laid out for a 6" screen, not squeezed into it.
- Heavy, low-frequency, high-screen-real-estate workflows (multi-stop route optimization with a full map sidebar, box-by-box CMR editing on a fixed desktop grid, raw e-Factura XML inspection) get a **mobile-adapted flow**, not a shrunk widget.
- The two current symbols of the old scope-limited mobile app — the Analytics placeholder and the Freight Exchange stub — are eliminated by this blueprint. There should be **zero** "open on desktop" dead ends left for a dispatcher/manager role after Phase 4 ships.
- **Non-goal:** Migration Center (bulk import/export tooling) is explicitly *not* ported to mobile. It has no mobile use case and porting it would violate the "don't clone the desktop" principle. This is a decision, not an oversight — it is recorded once here and should not be re-litigated per phase.

---

## 1. Current State: Gap Analysis vs Desktop

| Desktop Capability | Current Mobile State | Gap Severity |
|---|---|---|
| Full Analytics (revenue/period/client/route, fleet utilization, driver performance, invoice aging) | Placeholder screen: "open on desktop" | **Critical** |
| Freight Exchange (search, import, saved searches, Trans.eu negotiation) | Placeholder: search bar + empty state | **Critical** |
| Fleet Manager (CRUD trucks, health score, maintenance history, documents, assignments) | Not present (only live position on map) | **Missing entirely** |
| Driver Manager (CRUD drivers, license/medical/ADR expiry, tacho timeline) | Read-only "Teams" list with status filter only | **Read-only, no CRUD, no compliance detail** |
| Client CRM (create/update/merge, contacts, invoices/trips tabs, revenue charts) | Not present | **Missing entirely** |
| Invoicing/Generators (invoice editor, VAT/discount calc, e-Factura export, CMR form, receipts) | Not present | **Missing entirely** |
| Trip History / Route History (sortable tables, export PDF/Excel/CSV) | Not present (only live Jobs list) | **Missing entirely** |
| Maintenance Control (scheduled maintenance, work orders, overdue alerts) | Not present | **Missing entirely** |
| Tachograph Import & Compliance | Not present | **Missing entirely** |
| Team / User Management (invite, role assignment) | Not present | **Missing entirely** |
| Migration Center (import/export) | Not present | **Deliberately out of scope — see §0** |
| Settings (company info, branding, SMTP, fleet tracking provider, maintenance thresholds) | Language/theme/logout only | **Major gap** |
| Route Planner (multi-stop, truck profile, country exclusions) | Origin/destination + waypoints, basic map | **Partial** |
| Document Center | List + camera OCR capture | **Partial — missing FTS5 depth, versioning, entity-link browsing** |
| Dispatch Board (Kanban/Timeline/Alerts) | Jobs list (approve/reject/reassign) | **Partial — no Kanban/Timeline, no drag-drop** |
| AI Copilot (ARGO) | Full chat + voice, Level 3 confirmation | **At parity** |

---

## 2. Target Feature Parity Matrix

| # | Desktop View | Mobile Destination | Route Name (Flutter) | Adaptation Strategy |
|---|---|---|---|---|
| 1 | Overview | `DispatcherHomeScreen` (expanded) | `/dispatcher/home` | Add profit sparkline + activity feed |
| 2 | Analytics | `AnalyticsScreen` (new) | `/dispatcher/more/analytics` | Tabbed: Revenue/Fleet/Drivers/Invoice Aging, `fl_chart`, date-range picker |
| 3 | Route Planner | `RoutePlannerScreen` (upgraded) | `/dispatcher/ops/route-planner` | Add truck profile selector, country exclusion chips |
| 4 | Calculator | `ProfitCalculatorScreen` | `/dispatcher/ops/calculator` | Already at parity |
| 5 | Dispatch Board | `JobListScreen` (upgraded) | `/dispatcher/ops/jobs` | Add Kanban + Timeline view modes |
| 6 | Live Tracking | `FleetMapScreen` | `/dispatcher/ops/map` | Already at parity |
| 7 | Freight Exchange | `FreightExchangeScreen` (rebuilt) | `/dispatcher/ops/freight` | Real search/import/saved searches; guided negotiation flow |
| 8 | Fleet | `FleetScreen` → `TruckDetailScreen` (new) | `/dispatcher/records/fleet`, `/.../fleet/:id` | Full CRUD, health score, maintenance, documents |
| 9 | Driver Manager | `TeamsScreen` (upgraded) → `DriverDetailScreen` (new) | `/dispatcher/records/drivers`, `/.../drivers/:id` | Full CRUD, expiry compliance, tacho timeline |
| 10 | Clients | `ClientsScreen` → `ClientDetailScreen` (new) | `/dispatcher/records/clients`, `/.../clients/:id` | CRUD, contacts, tabs, merge (manager) |
| 11 | Documents | `DocumentCenterScreen` (upgraded) | `/dispatcher/records/documents` | Full FTS5 search, category tree, versioning |
| 12 | Maintenance | `MaintenanceScreen` (new) | `/dispatcher/more/maintenance` | Cost trends + schedule + record-work action |
| 13 | Tachograph | `TachographScreen` (new) | `/dispatcher/more/tachograph` | `.ddd` upload, compliance summary/timeline |
| 14 | Generators | `InvoicingScreen` → `InvoiceEditorScreen`/`CmrFormScreen` (new) | `/dispatcher/more/invoicing/...` | Line-item editor, PDF preview, e-Factura submit |
| 15 | Trip History | `TripHistoryScreen` (new) | `/dispatcher/records/trip-history` | Filterable list, async export |
| 16 | Route History | `RouteHistoryScreen` (new) | `/dispatcher/records/route-history` | List + map thumbnail |
| 17 | AI Copilot | `CopilotChatScreen` | `/dispatcher/copilot` | Already at parity |
| 18 | Migration Center | *not ported* | — | Deliberate omission, §0 |
| 19 | Team Mgmt | `TeamManagementScreen` (new, manager/admin) | `/dispatcher/more/team` | Invite, role assign, deactivate |
| 20 | Settings | `SettingsScreen` (expanded) | `/dispatcher/more/settings` | Company config, SMTP, tracking provider, thresholds |
| 21 | Fleet Dashboard | Folded into Home + Fleet | — | No standalone screen |

---

## 3. Information Architecture Redesign

```
DispatcherShell (bottom nav, 5 tabs)
├── Tab 0: Home          — /dispatcher/home
├── Tab 1: Operations    — /dispatcher/ops/{map,jobs,route-planner,freight,calculator}
├── Tab 2: Copilot       — /dispatcher/copilot
├── Tab 3: Records       — /dispatcher/records/{fleet,drivers,clients,documents,trip-history,route-history}
└── Tab 4: More          — /dispatcher/more/{analytics,invoicing,maintenance,tachograph,team,messages,alerts,settings}
```

- Each of Records/More renders as a **searchable grid**, not a flat tile wall — a `SliverGrid` with a `TextField` filter at top, consistent with how the Copilot's Help Mode search already behaves.
- **Global search** (`GlobalSearchScreen`, reachable via a persistent `IconButton(Icons.search)` in every tab's `AppBar`) queries across trips/clients/drivers/trucks/documents in a single debounced request (see §6.11).
- Tiles a role cannot access **do not render** (see §8.2) — the grid `itemCount` reflects only permitted tiles, it is never `itemCount: allTiles.length` with a locked overlay.

---

## 4. New/Upgraded Screens — Full Technical Spec

Directory convention for all new features (matches existing `mobile_app/lib/features/<feature>/` layout: `models/`, `providers/`, `screens/`, `widgets/`):

```
mobile_app/lib/features/
├── fleet/            (new)
├── drivers/          (upgrade of existing "teams" feature — see 4.2)
├── clients/          (new)
├── analytics/        (new)
├── invoicing/        (new)
├── maintenance/       (new)
├── tachograph/        (new)
├── history/           (new — trip_history + route_history)
├── team_management/   (new)
├── global_search/     (new)
└── settings/          (upgrade of existing feature)
```

### 4.1 Fleet — `features/fleet/`

**Model** (`models/truck.dart`):
```dart
class Truck {
  final String id;               // UUID
  final String companyId;
  final String plate;            // e.g. "DJ-07-XYZ"
  final String? brand;
  final String? model;
  final String? vin;
  final int? year;
  final TruckStatus status;      // enum: active, maintenance, decommissioned
  final double? healthScore;     // 0.0–100.0, nullable if not yet computed
  final String? currentDriverId; // nullable
  final DateTime createdAt;
  final DateTime updatedAt;
}
enum TruckStatus { active, maintenance, decommissioned }
```

**Screens:**
- `screens/fleet_list_screen.dart` — `ListView.builder` over `fleetListProvider`; each row: plate (bold), brand/model (subtitle), health-score color chip (green ≥80, amber 50–79, red <50 — same thresholds as desktop `FleetHealthCalculator`), status badge. Search `TextField` filters client-side over the cached page plus triggers server search after 400ms debounce for full-dataset match. FAB `+` visible only if `can(Permission.createVehicle)` (§8).
- `screens/truck_detail_screen.dart` — `DefaultTabController` with 4 tabs: **Overview** (plate/brand/model/VIN/year, editable via `IconButton(Icons.edit)` → `truck_edit_sheet.dart` bottom sheet, visible only if `can(Permission.updateVehicle)`), **Maintenance** (history list + "Record work" FAB, see §4.6), **Documents** (reuses `DocumentPickerWidget` from Document Center, filtered by `entityType: 'truck', entityId: truck.id`), **Assignments** (current + historical driver↔truck pairs, read-only list).
- Decommission action: `PopupMenuButton` item "Decommission," visible only if `can(Permission.deleteVehicle)` — per §8.3 this is **admin-only**, so it will not render for manager or dispatcher roles at all.

### 4.2 Drivers — `features/drivers/` (upgrades existing `teams/`)

**Model extension** (`models/driver.dart` — extend existing `Driver` model, do not replace):
```dart
class Driver {
  // ...existing fields (id, companyId, name, phone, status)...
  final String? licenseNumber;
  final DateTime? licenseExpiry;
  final DateTime? medicalExpiry;
  final DateTime? adrCertificateExpiry;   // nullable — not all drivers carry ADR
  final String? currentTruckId;           // nullable
}
```

**Compliance badge logic** (`widgets/expiry_badge.dart`) — shared across license/medical/ADR:
```
daysRemaining = expiryDate.difference(now).inDays
if daysRemaining < 0        -> red,   label "EXPIRED"
if daysRemaining <= 30      -> amber, label "$daysRemaining d"
else                        -> green, label formatted date
```
This exactly mirrors the desktop's `driver_compliance_service.py` thresholds — **do not invent new thresholds**; if the desktop thresholds differ from 30 days, pull the actual constant from `backend/services/driver_compliance_service.py` and use that value, not the number written here.

**Screens:**
- `screens/driver_list_screen.dart` — extend existing filter chips (`all/available/driving/off`) with a 5th chip **"Expiring"** that filters to drivers where any of the three expiry dates is within 30 days or already expired.
- `screens/driver_detail_screen.dart` (new) — tabs: **Overview** (name/phone/license fields, edit sheet gated by `can(Permission.updateDriver)`), **Compliance** (three `ExpiryBadge` rows + a "Renew" quick-action that opens the edit sheet pre-focused on the relevant field), **Tacho Timeline** (calls `driverTachoProvider(driverId)`, renders a 7-day horizontal timeline bar per day: driving/working/rest/availability minutes stacked, plus a weekly-limit gauge capped at 3360 minutes — matching the desktop's `TachoComplianceEngine` constant), **Assignments** (current + history, read-only).

### 4.3 Clients — `features/clients/` (new)

**Model** (`models/client.dart`):
```dart
class Client {
  final String id;
  final String companyId;
  final String name;
  final String? vatNumber;
  final String? address;
  final int? paymentTermsDays;    // e.g. 30, 45, 60
  final double? rating;           // 0.0–5.0, nullable
  final List<ClientContact> contacts;
}
class ClientContact {
  final String id;
  final String name;
  final String? role;
  final String? phone;
  final String? email;
}
```

**Screens:**
- `screens/client_list_screen.dart` — search + rating stars indicator + payment-terms chip, FAB gated by `can(Permission.createClient)`.
- `screens/client_detail_screen.dart` — tabs: **Details** (editable, gated), **Contacts** (add/edit/remove contact, gated), **Invoices** (`invoiceListProvider(clientId: ...)`), **Trips** (`tripHistoryProvider(clientId: ...)`), plus a small revenue-over-time sparkline at the top of Details using `analyticsRevenueProvider(clientId: ...)`.
- **Merge flow** (`widgets/client_merge_sheet.dart`) — visible only if `can(Permission.mergeClients)` (manager+). UI: select "target" client to keep, select one-or-more "source" clients to merge into it, show a summary of what will move (trip count, invoice count, contact count), require the user to type the target client's exact name into a confirm field before the "Merge" button enables — mirrors the desktop's explicit-typed-confirmation pattern for irreversible actions, adapted to touch input.

### 4.4 Analytics — `features/analytics/` (new)

**Screens:**
- `screens/analytics_screen.dart` — `TabBar` with 4 tabs: Revenue / Fleet Utilization / Driver Performance / Invoice Aging. Each tab is its own stateless widget consuming its own `FutureProvider.family` keyed by the shared `DateRange` held in `analyticsDateRangeProvider` (a simple `StateProvider<DateRange>`).
- Date-range control: `widgets/date_range_selector.dart` — segmented control with presets `7d / 30d / QTD / YTD / Custom`; `Custom` opens `showDateRangePicker`.
- Chart library: `fl_chart` — Revenue tab uses `LineChart` (trend) + `BarChart` (per-client/per-route toggle via `SegmentedButton`); Fleet Utilization uses `PieChart` (active/maintenance/decommissioned split) + a horizontal bar list for per-truck utilization %; Driver Performance uses a sortable `DataTable` (on-time %, trips completed, avg rating) — a table is more legible than a chart here, matching how the desktop presents this same data as a table, not a chart; Invoice Aging uses a stacked `BarChart` (current / 1–30 / 31–60 / 61–90 / 90+ days overdue buckets).
- Export: `IconButton(Icons.ios_share)` in the `AppBar` triggers `analyticsExportProvider` which calls `/mobile/analytics/export` (returns a signed CSV download URL) and opens the OS share sheet — no local CSV generation on-device, keep the calculation server-side to avoid drift from desktop numbers.

### 4.5 Invoicing — `features/invoicing/` (new)

**Model** (`models/invoice.dart`):
```dart
class Invoice {
  final String id;
  final String companyId;
  final String clientId;
  final String? tripId;
  final InvoiceStatus status;   // enum below — must match backend exactly
  final List<InvoiceLineItem> lineItems;
  final double grossValue;
  final double discountAmount;
  final double taxableAmount;
  final double vatAmount;
  final double totalAmount;
  final DateTime issueDate;
  final DateTime? dueDate;
}
enum InvoiceStatus { draft, finalized, xmlGenerated, submittedExternally, paid, cancelled }
class InvoiceLineItem {
  final String id;
  final String description;
  final double quantity;
  final double unitPrice;
  final double discountPct;   // 0–100
  final double vatRatePct;    // e.g. 19.0 for standard RO VAT
}
```

**Calculation — must be byte-identical to desktop, see §13.3 for the shared test-vector contract:**
```
lineTotal        = quantity * unitPrice
lineDiscountAmt  = lineTotal * (discountPct / 100)
lineTaxable      = lineTotal - lineDiscountAmt
lineVat          = lineTaxable * (vatRatePct / 100)
lineGrandTotal   = lineTaxable + lineVat

invoice.grossValue     = sum(lineTotal)
invoice.discountAmount = sum(lineDiscountAmt)
invoice.taxableAmount  = sum(lineTaxable)
invoice.vatAmount      = sum(lineVat)
invoice.totalAmount    = sum(lineGrandTotal)
```
All rounding to `NUMERIC(12,2)` (2 decimal places, half-up) — implement via `Decimal`-safe arithmetic on the Dart side (`decimal` package), never raw `double` math, to avoid floating-point drift from the backend's `Decimal`-typed Postgres columns.

**Status state machine** — the mobile UI is a **stepper widget**, not free navigation:
```
draft --(finalize)--> finalized --(generate_xml)--> xmlGenerated --(submit)--> submittedExternally --(mark_paid)--> paid
draft --(cancel)--> cancelled
finalized --(cancel)--> cancelled   [manager approval required — see below]
```
Each transition is its own backend call (`POST /mobile/invoices/{id}/transition`, see §6.6) — the client never mutates `status` locally without a server round trip, since transition validity (e.g., "can't finalize an invoice with zero line items") is enforced server-side.

**Screens:**
- `screens/invoice_list_screen.dart` — filter chips by status, search by client name/invoice number.
- `screens/invoice_editor_screen.dart` — trip picker (autocomplete over `tripHistoryProvider`) → line items (`ReorderableListView` of `InvoiceLineItemTile`, swipe-to-delete, "+ Add line" button) → live-computed totals footer (recomputed client-side using the exact formula above for instant feedback, then re-validated server-side on save) → PDF preview button (`InvoicePdfPreviewScreen`, uses `pdfx` or `syncfusion_flutter_pdfviewer` to render the server-generated PDF) → primary action button whose label changes with state (`Save Draft` / `Finalize` / `Generate e-Factura XML` / `Submit`).
- `screens/cmr_form_screen.dart` — same UN/CEFACT numbered-box data structure as desktop, rendered as a scrollable form grouped into logical sections (Sender/Consignee/Carrier/Goods/Instructions/Signatures) rather than the desktop's fixed grid layout. Signature capture via the `signature` package, saved as PNG and attached to the CMR record.
- **Biometric step-up required** (§12) before the `Finalize`, `Submit`, and CMR-signature-save actions fire their API call — implemented via a shared `requireBiometricConfirmation()` helper in `core/security/biometric_gate.dart`, reused from the existing app-unlock `local_auth` integration.

### 4.6 Maintenance — `features/maintenance/` (new)

**Screens:**
- `screens/maintenance_screen.dart` — top section: cost trend `LineChart` + category breakdown `PieChart` (parity with desktop Maintenance Analytics); bottom section: scheduled maintenance list, overdue items rendered with a red left-border accent and sorted first.
- `widgets/record_work_sheet.dart` — bottom sheet: truck picker (defaults to context truck if opened from `TruckDetailScreen`), date picker, category dropdown (`enum MaintenanceCategory { oilChange, tires, brakes, engine, bodywork, inspection, other }` — must match backend enum exactly), cost field (`Decimal`), vendor text field, notes field, optional photo attachment (camera or gallery).

### 4.7 Tachograph — `features/tachograph/` (new)

**Screens:**
- `screens/tachograph_screen.dart` — driver picker → "Import .ddd file" button (`file_picker` package, filtered to `.ddd`/`.esm` extensions) → upload progress indicator → compliance summary card (daily driving/working/rest minutes for the imported period) → warning banners for any breach (e.g., "Daily driving limit exceeded on 2026-07-14: 612 min > 540 min cap") sourced verbatim from the backend's compliance-check response, not recomputed on-device.
- Weekly limit gauge: circular progress indicator, `value: weeklyDrivingMinutes / 3360`, red past 100%.

### 4.8 Trip History / Route History — `features/history/` (new)

**Screens:**
- `screens/trip_history_screen.dart` — filterable (status, date range, client) `ListView`, pull-to-refresh, infinite scroll pagination (`page`/`pageSize` params, 20 per page). Export button triggers `POST /mobile/history/trips/export` (§6.9) — this is a **fire-and-forget async job**: show a snackbar "Export started — you'll be notified when ready," poll job status via `exportJobStatusProvider` or wait for the push notification, then on completion open the OS share sheet with the downloaded file.
- `screens/route_history_screen.dart` — same list pattern, each row has a small static map thumbnail (via `flutter_map` snapshot or a pre-rendered image URL from backend) plus duplicate/archive `PopupMenuButton` actions.

### 4.9 Team Management — `features/team_management/` (new, manager/admin only)

**Screens:**
- `screens/team_management_screen.dart` — user list with role badge (`dispatcher`/`manager`/`admin` — though admin accounts should never actually appear here per §8.3, the UI must still handle the enum value defensively), invite FAB opens `invite_user_sheet.dart` (email field + role dropdown restricted to roles the current user is allowed to grant — a manager can invite dispatchers and other managers, never admins), `PopupMenuButton` per row for role change / deactivate.
- Deactivation confirmation dialog must state explicitly: "This will immediately revoke [name]'s mobile sessions and log them out of all devices" — matching the device-deregistration cascade in §12.

### 4.10 Settings — `features/settings/` (expanded)

New sections added to the existing `SettingsScreen`, each gated:
- **Company Profile** (manager/admin): legal name, VAT/CUI number, address, logo upload (reuses camera/gallery picker), invoice footer text.
- **SMTP Configuration** (manager/admin): host/port/username fields, password field **write-only** (never pre-filled from server, always shows a masked placeholder like "•••• configured" if already set), "Send test email" button.
- **Fleet Tracking Provider** (manager/admin): dropdown `Wialon / Frotcom / Traccar / None`, API-key field (same write-only masking rule as SMTP).
- **Maintenance Thresholds** (manager/admin): sliders for the km/day intervals that trigger "due soon" vs "overdue" badges elsewhere in the app.
- **Notification Preferences** (all roles): per-severity toggle (critical/warning/info alerts → push yes/no), quiet-hours time range picker.
- **Data Usage** (all roles): "Wi-Fi only for large syncs" toggle (documents, exports, tachograph uploads).
- **Biometric Lock** (all roles): toggle + "require for financial actions" sub-toggle (tied to §4.5/§12 biometric step-up).

### 4.11 Dispatch Board upgrade — `features/jobs/` (existing feature, extend)

Add a `ViewMode` enum (`list, kanban, timeline`) to the existing `JobListScreen` state, surfaced as a `SegmentedButton` in the `AppBar`:
- **Kanban**: horizontal `PageView` of 4 columns (`Planned/Loading/InTransit/Delivered`), each a `ListView` of job cards. Move between columns via **long-press to pick up → drag → drop with a highlighted drop-zone outline → on release, show a confirmation snackbar with an "Undo" action for 4 seconds before the API call actually commits** (see §7 — this is a deliberate deviation from desktop's instant-commit drag-drop, justified by touch drag's higher error rate).
- **Timeline**: horizontal Gantt-style view (`InteractiveViewer` for pinch-zoom/pan), one row per truck, jobs rendered as colored blocks positioned by start/end time.

### 4.12 Freight Exchange rebuild — `features/freight/` (existing stub, rebuild)

- `screens/freight_search_screen.dart` — real form (origin, destination, weight, truck type) → `POST /mobile/freight/search` → results list, each card showing a profitability badge (color-coded, sourced from the backend `EvaluationEngineService`, not recomputed client-side).
- One-tap "Import to trip" action on each result → pre-fills a new trip draft and navigates to the trip creation flow.
- `screens/saved_searches_screen.dart` — CRUD on saved search criteria, "re-run" action re-executes the search.
- `screens/negotiation_screen.dart` — guided linear flow (view offer → Accept / Reject / Counter-offer with an amount field) rather than the desktop's dense negotiation table — each state transition is its own explicit screen, not a table row inline-edit.

---

## 5. State Management — Exact Provider Contracts

All new providers follow the existing repo convention: `Provider`/`FutureProvider`/`StateNotifierProvider` defined in `providers/<feature>_providers.dart`, consumed via `ConsumerWidget`/`ConsumerStatefulWidget`. Every list/detail `FutureProvider` follows the existing **dual-mode pattern** already used by `dispatcherOverviewProvider`: try network → on failure fall back to `LocalDatabase` cache → surface a non-blocking "showing cached data from [timestamp]" banner.

```dart
// features/fleet/providers/fleet_providers.dart
final fleetListProvider = FutureProvider.autoDispose<List<Truck>>((ref) async { ... });
final truckDetailProvider = FutureProvider.autoDispose.family<Truck, String>((ref, truckId) async { ... });
final truckMaintenanceHistoryProvider = FutureProvider.autoDispose.family<List<MaintenanceRecord>, String>((ref, truckId) async { ... });
final fleetMutationProvider = StateNotifierProvider<FleetMutationNotifier, AsyncValue<void>>((ref) => FleetMutationNotifier(ref));
class FleetMutationNotifier extends StateNotifier<AsyncValue<void>> {
  Future<void> createTruck(TruckDraft draft);
  Future<void> updateTruck(String id, TruckDraft patch);
  Future<void> decommissionTruck(String id);   // enqueues via actionQueueProvider if offline
  Future<void> recordMaintenance(String truckId, MaintenanceRecordDraft draft);
}

// features/drivers/providers/driver_providers.dart
final driverListProvider = FutureProvider.autoDispose<List<Driver>>((ref) async { ... });
final driverDetailProvider = FutureProvider.autoDispose.family<Driver, String>((ref, driverId) async { ... });
final driverTachoProvider = FutureProvider.autoDispose.family<TachoTimeline, String>((ref, driverId) async { ... });
final driverMutationProvider = StateNotifierProvider<DriverMutationNotifier, AsyncValue<void>>((ref) => DriverMutationNotifier(ref));

// features/clients/providers/client_providers.dart
final clientListProvider = FutureProvider.autoDispose<List<Client>>((ref) async { ... });
final clientDetailProvider = FutureProvider.autoDispose.family<Client, String>((ref, clientId) async { ... });
final clientMutationProvider = StateNotifierProvider<ClientMutationNotifier, AsyncValue<void>>((ref) => ClientMutationNotifier(ref));
class ClientMutationNotifier extends StateNotifier<AsyncValue<void>> {
  Future<void> createClient(ClientDraft draft);
  Future<void> updateClient(String id, ClientDraft patch);
  Future<void> addContact(String clientId, ClientContact contact);
  Future<void> mergeClients({required String targetId, required List<String> sourceIds}); // NEVER queued offline — see §7
}

// features/analytics/providers/analytics_providers.dart
final analyticsDateRangeProvider = StateProvider<DateRange>((ref) => DateRange.last30Days());
final analyticsRevenueProvider = FutureProvider.autoDispose.family<RevenueAnalytics, ({DateRange range, String? clientId})>((ref, args) async { ... });
final analyticsFleetUtilizationProvider = FutureProvider.autoDispose.family<FleetUtilizationAnalytics, DateRange>((ref, range) async { ... });
final analyticsDriverPerformanceProvider = FutureProvider.autoDispose.family<List<DriverPerformanceRow>, DateRange>((ref, range) async { ... });
final analyticsInvoiceAgingProvider = FutureProvider.autoDispose<InvoiceAgingReport>((ref) async { ... });

// features/invoicing/providers/invoicing_providers.dart
final invoiceListProvider = FutureProvider.autoDispose.family<List<Invoice>, InvoiceListFilter>((ref, filter) async { ... });
final invoiceEditorStateProvider = StateNotifierProvider.autoDispose.family<InvoiceEditorNotifier, InvoiceEditorState, String?>((ref, invoiceId) => InvoiceEditorNotifier(ref, invoiceId));
class InvoiceEditorNotifier extends StateNotifier<InvoiceEditorState> {
  void addLineItem(InvoiceLineItem item);
  void removeLineItem(String lineItemId);
  void updateLineItem(String lineItemId, InvoiceLineItem patch);
  InvoiceTotals recompute();               // pure client-side, Decimal-safe, mirrors §4.5 formula exactly
  Future<void> saveDraft();
  Future<void> transition(InvoiceTransition transition); // finalize | generateXml | submit | markPaid | cancel
}

// features/maintenance/providers/maintenance_providers.dart
final maintenanceScheduleProvider = FutureProvider.autoDispose<List<ScheduledMaintenance>>((ref) async { ... });
final maintenanceCostTrendProvider = FutureProvider.autoDispose.family<MaintenanceCostTrend, DateRange>((ref, range) async { ... });

// features/tachograph/providers/tachograph_providers.dart
final tachographImportProvider = StateNotifierProvider.autoDispose<TachographImportNotifier, TachographImportState>((ref) => TachographImportNotifier(ref));
// state: idle -> uploading(progress: double) -> processing -> success(TachoComplianceResult) | error(String)

// features/history/providers/history_providers.dart
final tripHistoryProvider = FutureProvider.autoDispose.family<PaginatedResult<TripHistoryEntry>, TripHistoryFilter>((ref, filter) async { ... });
final routeHistoryProvider = FutureProvider.autoDispose.family<PaginatedResult<RouteHistoryEntry>, RouteHistoryFilter>((ref, filter) async { ... });
final exportJobStatusProvider = StreamProvider.autoDispose.family<ExportJobStatus, String>((ref, jobId) { /* polls every 3s until terminal state */ });

// features/team_management/providers/team_providers.dart
final teamMembersProvider = FutureProvider.autoDispose<List<TeamMember>>((ref) async { ... }); // must check can(Permission.manageUsers) before even building the request — see §8.2
final teamMutationProvider = StateNotifierProvider<TeamMutationNotifier, AsyncValue<void>>((ref) => TeamMutationNotifier(ref));

// features/settings/providers/company_settings_providers.dart
final companySettingsProvider = FutureProvider.autoDispose<CompanySettings>((ref) async { ... });
final companySettingsMutationProvider = StateNotifierProvider<CompanySettingsNotifier, AsyncValue<void>>((ref) => CompanySettingsNotifier(ref));

// features/global_search/providers/global_search_providers.dart
final globalSearchQueryProvider = StateProvider<String>((ref) => '');
final globalSearchResultsProvider = FutureProvider.autoDispose<GlobalSearchResults>((ref) async {
  final query = ref.watch(globalSearchQueryProvider);
  if (query.trim().length < 2) return GlobalSearchResults.empty();
  // debounce 350ms via ref.read(_debouncerProvider) before firing network call
  ...
});
```

**Sync/queue extensions** (extend existing files, do not create parallel ones):
```dart
// core/sync/sync_cursors.dart — extend the existing enum
enum SyncEntityType {
  trips, alerts, messages,                 // existing
  fleet, drivers, clients, invoices, maintenance, // NEW
}

// core/sync/action_queue.dart — extend the existing QueuedActionType
enum QueuedActionType {
  approveJob, rejectJob, reassignJob,      // existing
  createTruck, updateTruck, decommissionTruck, recordMaintenance,   // NEW
  createDriver, updateDriver,                                       // NEW
  createClient, updateClient, addClientContact,                     // NEW — mergeClients is EXPLICITLY EXCLUDED, see §7
  saveInvoiceDraft, transitionInvoice,                               // NEW — transitionInvoice queuing rules in §7
  scheduleMaintenance,                                               // NEW
}
```

---

## 6. Backend — Exact Endpoint Contracts

All new routes live under `backend/api/v1/mobile/`, one router module per entity (`fleet.py`, `drivers.py`, `clients.py`, `analytics.py`, `invoicing.py`, `maintenance.py`, `tachograph.py`, `history.py`, `team.py`, `settings.py`, `search.py`), registered in `backend/api/v1/mobile/__init__.py`'s `mobile_router`. Every route handler's **first line of business logic** must be a `PermissionService.require(current_user, Permission.X)` call (raising `403` on failure) — see §8.1. Pagination uses `page: int = 1, page_size: int = Query(20, le=100)` query params consistently across all list endpoints.

### 6.1 Fleet
```
GET    /mobile/fleet?page=&page_size=&search=&status=          -> PaginatedResponse[TruckOut]
POST   /mobile/fleet                                            -> TruckOut          [requires: create_vehicle]
GET    /mobile/fleet/{truck_id}                                 -> TruckDetailOut
PATCH  /mobile/fleet/{truck_id}                                 -> TruckOut          [requires: update_vehicle]
DELETE /mobile/fleet/{truck_id}   (soft: sets status=decommissioned) -> 204          [requires: delete_vehicle, ADMIN ONLY]
GET    /mobile/fleet/{truck_id}/maintenance?page=&page_size=    -> PaginatedResponse[MaintenanceRecordOut]
POST   /mobile/fleet/{truck_id}/maintenance                     -> MaintenanceRecordOut [requires: record_maintenance]
```
`TruckOut` fields: `id, company_id, plate, brand, model, vin, year, status, health_score, current_driver_id, created_at, updated_at`.

### 6.2 Drivers
```
GET    /mobile/drivers?page=&page_size=&search=&status=&expiring_within_days=
POST   /mobile/drivers                                           [requires: create_driver]
GET    /mobile/drivers/{driver_id}
PATCH  /mobile/drivers/{driver_id}                                [requires: update_driver]
GET    /mobile/drivers/{driver_id}/tacho?start_date=&end_date=   -> TachoTimelineOut
```
`expiring_within_days` implements the "Expiring" filter chip server-side (avoids shipping the full roster to compute it client-side).

### 6.3 Clients
```
GET    /mobile/clients?page=&page_size=&search=
POST   /mobile/clients                                            [requires: create_client]
GET    /mobile/clients/{client_id}                                -> ClientDetailOut (includes contacts, recent invoices/trips counts)
PATCH  /mobile/clients/{client_id}                                 [requires: update_client]
POST   /mobile/clients/{client_id}/contacts                        [requires: update_client]
POST   /mobile/clients/merge   body: {target_id, source_ids: [...]} [requires: merge_clients, MANAGER+]
                                -> 200 {merged_trip_count, merged_invoice_count, merged_contact_count}
```
`POST /mobile/clients/merge` **must be synchronous and must never be queued client-side offline** — it requires a live connection by contract (see §7). The endpoint itself must be wrapped in a DB transaction with row-level locking on both target and source client rows to avoid a race with a concurrent desktop-side merge.

### 6.4 Analytics
```
GET /mobile/analytics/revenue?start_date=&end_date=&group_by=period|client|route
GET /mobile/analytics/fleet-utilization?start_date=&end_date=
GET /mobile/analytics/driver-performance?start_date=&end_date=
GET /mobile/analytics/invoice-aging
GET /mobile/analytics/export?report=revenue|fleet|drivers|invoice_aging&start_date=&end_date=   -> {download_url, expires_at}
```
These are a **new mobile-facing aggregation layer** — they must NOT simply proxy the desktop's Plotly-data-shaped responses. Each returns pre-aggregated, small (<50KB typical) JSON suited to `fl_chart` input shapes, computed by a new `MobileAnalyticsAggregator` service that wraps the existing `AnalyticsService` queries but reshapes the output. `download_url` in the export endpoint is a short-lived (10 minute) signed URL to a Celery-generated CSV in object storage, not an inline base64 payload.

### 6.5 Maintenance
```
GET  /mobile/maintenance/schedule?page=&page_size=&overdue_only=
POST /mobile/maintenance/schedule                                  [requires: manage_maintenance]
GET  /mobile/maintenance/cost-trend?start_date=&end_date=
```

### 6.6 Invoicing
```
GET    /mobile/invoices?page=&page_size=&status=&client_id=&search=
POST   /mobile/invoices                          body: InvoiceDraftIn  -> InvoiceOut (status=draft)  [requires: create_invoice]
GET    /mobile/invoices/{invoice_id}             -> InvoiceDetailOut
PATCH  /mobile/invoices/{invoice_id}             body: InvoiceDraftIn (only valid while status=draft) [requires: update_invoice]
POST   /mobile/invoices/{invoice_id}/transition  body: {action: "finalize"|"generate_xml"|"submit"|"mark_paid"|"cancel"}
                                                  -> InvoiceOut (new status)   [requires: transition-specific permission, see §8.4]
POST   /mobile/invoices/{invoice_id}/cmr         body: CmrFormIn        -> CmrOut  [requires: create_cmr]
```
Server-side validation on `POST .../transition` must reject (422, not 500) illegal transitions (e.g., `finalize` on an invoice with zero line items, or `submit` before `generate_xml`) with a machine-readable `error_code` the client maps to a user-facing message — never a raw stack trace surfaced to the mobile UI.

### 6.7 Tachograph
```
POST /mobile/tacho/import     multipart/form-data: {driver_id, file: <.ddd binary>}
                               -> 202 {job_id}   (async parse job)
GET  /mobile/tacho/import/{job_id}/status  -> {status: "processing"|"success"|"error", result?: TachoComplianceResult}
```
Import is async (Celery) because `.ddd` parsing can take several seconds for a full month of data — the client polls `job_id` status (or receives a push notification, same pattern as history export).

### 6.8 History
```
GET  /mobile/history/trips?page=&page_size=&status=&client_id=&start_date=&end_date=
POST /mobile/history/trips/export   body: {format: "pdf"|"xlsx"|"csv", filters: {...}}  -> 202 {job_id}
GET  /mobile/history/trips/export/{job_id}/status -> {status, download_url?}
GET  /mobile/history/routes?page=&page_size=&start_date=&end_date=
```

### 6.9 Team Management
```
GET    /mobile/team                              [requires: manage_users, MANAGER+]
POST   /mobile/team/invite   body: {email, role: "dispatcher"|"manager"}   [requires: manage_users; role param constrained server-side to roles below the caller's own — a manager cannot invite an admin]
PATCH  /mobile/team/{user_id}   body: {role?, is_active?}                  [requires: manage_users]
```
On `is_active: false`, the handler must (in the same transaction): (1) set the user inactive, (2) delete all rows in `mobile_devices` for that user, (3) revoke all outstanding refresh tokens for that user — this is the device-deregistration cascade from §12, and it is a **backend** responsibility, not something the mobile client can be trusted to trigger for another user's session.

### 6.10 Settings
```
GET   /mobile/settings/company                    [requires: view_company_settings]
PATCH /mobile/settings/company   body: CompanySettingsIn   [requires: manage_company_settings, MANAGER+]
```
`CompanySettingsIn`'s `smtp_password` and `tracking_api_key` fields are **write-only**: `GET` never returns their actual values, only a boolean `smtp_password_is_set: bool` / `tracking_api_key_is_set: bool`. `PATCH` with these fields omitted leaves the stored value unchanged; `PATCH` with an explicit empty string clears it.

### 6.11 Global Search
```
GET /mobile/search?q=&types=trips,clients,drivers,trucks,documents   -> {trips: [...], clients: [...], drivers: [...], trucks: [...], documents: [...]}
```
Backed by a lightweight cross-table FTS query (reuses the existing PostgreSQL FTS/pgvector infrastructure already in place for the Copilot's Help Mode and Document Center, does not stand up a new search index). Each result-type array capped at 5 items with a `total_count` per type so the UI can show "12 more clients — see all."

---

## 7. Offline & Sync — Exact Extension Points

The existing `ActionQueue` / `DeltaSyncService` / `ConflictHandler` architecture is extended, not replaced.

**Read-side (delta sync):** `SyncEntityType` gains `fleet, drivers, clients, invoices, maintenance` (§5). Each new type gets a cursor row in the local `sync_cursors` table (`entity_type TEXT PRIMARY KEY, last_synced_at TIMESTAMP, last_cursor TEXT`) and a corresponding `_syncFleet()`, `_syncDrivers()`, etc. method in `DeltaSyncService`, following the exact same shape as the existing `_syncTrips()` method: fetch `?since=<last_cursor>`, upsert into local SQLite cache tables, advance cursor on success, retry with exponential backoff on failure.

**Write-side (action queue) — exact rules per new mutation type:**

| Mutation | Queueable offline? | Notes |
|---|---|---|
| `createTruck` / `updateTruck` / `decommissionTruck` | Yes | Idempotency key = client-generated UUID, same pattern as existing queued actions |
| `recordMaintenance` | Yes | |
| `createDriver` / `updateDriver` | Yes | |
| `createClient` / `updateClient` / `addClientContact` | Yes | |
| **`mergeClients`** | **No — blocked offline** | Requires live row-locking on the backend (§6.3); UI disables the Merge button with inline text "Merging requires an internet connection" when offline, rather than silently queuing something that could double-merge or race with a desktop-side merge |
| `saveInvoiceDraft` | Yes | Draft-only; safe to queue since drafts have no external side effects |
| `transitionInvoice` (finalize/submit/etc.) | **Conditional** — `finalize` and `cancel` are queueable; `generate_xml`, `submit`, and `mark_paid` are **not queueable offline** | The latter three either call external systems (e-Factura/ANAF) or are financially terminal — queuing them risks a stale-state submission. UI shows "requires connection" for these specific actions when offline, matching the same principle as `mergeClients` |
| `scheduleMaintenance` | Yes | |
| Tachograph `.ddd` import | **No — blocked offline** | File upload + async parse job requires connectivity by nature; disabled with inline messaging, never queued |
| Trip/route history export | **No — blocked offline** | Server-side render job requires connectivity; disabled with inline messaging |

**New conflict-resolution methods in `ConflictHandler`** (Romanian-localized, server-wins pattern, matching existing style):
```dart
ConflictResolution resolveTruckEditConflict(Truck local, Truck server);
ConflictResolution resolveDriverEditConflict(Driver local, Driver server);
ConflictResolution resolveClientEditConflict(Client local, Client server);
ConflictResolution resolveInvoiceTransitionConflict(Invoice local, Invoice server);
```
Each follows the existing pattern: if the server's `updated_at` is newer than the local queued action's `based_on_updated_at`, the server version wins and the queued action is discarded with a localized toast (e.g., `"Camionul TM-123 a fost modificat de altcineva — modificările tale nu au fost aplicate."`); the queued mutation is never silently retried against stale data.

**Session-bound queue TTL** (also referenced in §12): any queued action older than 24 hours (`queued_at` older than `DateTime.now().subtract(Duration(hours: 24))`) is **not auto-replayed** on reconnect — instead it surfaces in a "Pending actions need review" screen requiring explicit per-item confirm-or-discard before it fires, to avoid a day-old edit (e.g., a driver reassignment) executing unexpectedly.

**Read caching depth:** Fleet/Driver/Client full-snapshot caching is bounded but not artificially limited — given the target company size (10–50 trucks per the product's SME positioning), a full local cache of all three entity types is on the order of a few hundred rows total, trivial for local SQLite. No pagination-aware partial caching is needed for these three; **do** apply pagination-aware partial caching for Trip History and Invoices, which can grow unbounded over a company's lifetime — cache only the most recently synced N pages (`N = 5` by default, configurable) plus anything currently on-screen.

---

## 8. RBAC on Mobile — Exact Permission Matrix

This is the load-bearing requirement of "as much as the PC version can": **identical** permissions to desktop, not a mobile-specific relaxed or stricter set.

### 8.1 Server Is the Source of Truth

Every new `/mobile/*` endpoint's handler must call the shared `PermissionService` — the *same* service class the desktop-facing routers already call, imported from the same module (`backend/services/permission_service.py`), not a mobile-specific reimplementation:
```python
@router.post("/fleet")
async def create_truck(payload: TruckIn, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    PermissionService.require(current_user, Permission.CREATE_VEHICLE, db)  # raises HTTPException(403) on failure
    ...
```
If a permission check is missing on any new endpoint, that is a release-blocking bug per §13.4/§13.9, not a follow-up ticket.

### 8.2 Client-Side Visibility Rule

A tile, button, or menu item that a role cannot use **must not be present in the widget tree** — not `disabled: true`, not greyed-out-with-tooltip. Implementation pattern (add to `core/auth/permission_guard.dart` if not already present in a similar form):
```dart
Widget buildIfPermitted(WidgetRef ref, Permission permission, Widget Function() builder) {
  final can = ref.watch(permissionProvider).can(permission);
  return can ? builder() : const SizedBox.shrink();
}
```
Every new screen/tile/FAB/menu-item added by this blueprint must be wrapped with this helper (or the grid-level filtering equivalent for the Records/More tabs described in §3), verified by the RBAC fixture test in §13.4.

### 8.3 Exact Role × Action Matrix (Dispatcher / Manager / Admin)

Pull the authoritative version of this table from `backend/services/permission_service.py` at implementation time — the table below reflects the source blueprint's documented matrix and must be treated as a **starting reference, not an override**, if the two ever disagree the backend code wins:

| Action | Dispatcher | Manager | Admin |
|---|---|---|---|
| View fleet/drivers/clients | ✅ | ✅ | ✅ |
| Create/update trip, dispatch | ✅ | ✅ | ✅ |
| Generate CMR | ✅ | ✅ | ✅ |
| Upload documents | ✅ | ✅ | ✅ |
| Export data (history, analytics CSV) | ✅ | ✅ | ✅ |
| Record maintenance work | ✅ | ✅ | ✅ |
| Create/update vehicle | ❌ | ✅ | ✅ |
| Create/update driver | ❌ | ✅ | ✅ |
| Create/update client | ❌ | ✅ | ✅ |
| Merge clients | ❌ | ✅ | ✅ |
| Create/finalize/submit invoice | ❌ | ✅ | ✅ |
| View analytics | ❌ | ✅ | ✅ |
| Manage users (invite/role/deactivate) | ❌ | ✅ (cannot grant admin) | ✅ |
| Manage company settings/SMTP/tracking provider | ❌ | ✅ | ✅ |
| Delete vehicle / driver / client / trip | ❌ | ❌ | ✅ |
| Admin role itself | — | — | **no mobile login surface at all — matches desktop's zero-DB env-var gate; this blueprint does not add a mobile admin experience** |

### 8.4 Invoice Transition Permissions (Fine-Grained)

Because §6.6's transitions vary in stakes, permission checks are per-transition, not a single blanket `update_invoice`:

| Transition | Required Permission |
|---|---|
| `finalize` | `create_invoice` (manager+) |
| `generate_xml` | `create_invoice` (manager+) |
| `submit` | `submit_invoice` (manager+, plus biometric step-up client-side per §4.5) |
| `mark_paid` | `create_invoice` (manager+) |
| `cancel` (on a `draft` invoice) | `create_invoice` (manager+) |
| `cancel` (on a `finalized` invoice) | `submit_invoice` (manager+) — cancelling a finalized invoice is treated as higher-stakes than cancelling a draft |

### 8.5 Driver Role Isolation

`ModeRouter` (existing) already gates Driver-role users out of the entire Dispatcher shell at the router level — this blueprint does not touch that gate and every new screen described in §4 lives exclusively under the Dispatcher/Manager shell's routes. A regression test in §13.4 asserts no new route added by this blueprint is reachable from `ModeRouter`'s Driver branch.

---

## 9. Convenience & Mobile-Native Features

These have no desktop equivalent — they are what makes the mobile app *more* convenient than a shrunk desktop clone, which is the actual point of a companion app rather than a second desktop.

- **Home-screen widgets** (iOS `WidgetKit` via `home_widget` package / Android App Widgets): "Today's KPIs" (revenue-to-date, active jobs count, alerts count) for dispatcher/manager; "Next stop / active trip" for driver. No app-open required; refreshed on a background fetch cadence (15 min) plus push-triggered refresh on relevant events.
- **Quick actions / long-press app icon shortcuts** (`QuickActions` plugin): "Approve pending jobs," "New alert check," "Scan document" — each deep-links past the shell directly into the relevant screen/action sheet.
- **Rich push notifications with inline actions**: alert notifications carry Approve/Snooze/View action buttons (Android `NotificationCompat.Action` / iOS `UNNotificationAction`) so a dispatcher can act without opening the app.
- **One-handed reachability**: every new screen in §4 places its primary action (FAB, primary button) in the bottom two-thirds of the screen — audited explicitly per screen in the Phase implementation prompts (Part 2), not left to incidental layout.
- **Voice-first quick capture**: extend the existing Copilot voice input so a phrase like "record maintenance on TM-123, brake pads, 450 lei" pre-fills `record_work_sheet.dart` for one-tap confirm rather than manual typing — implemented as a new Copilot intent (`RecordMaintenanceIntent`) routed to the same `fleetMutationProvider.recordMaintenance()` call the manual form uses, so there is exactly one code path for the actual mutation regardless of entry method.
- **Camera-first document flows everywhere**, not just Document Center — e.g. attaching a photo directly from `TruckDetailScreen`'s Documents tab or from `record_work_sheet.dart`, reusing the existing `DocumentPickerWidget`.
- **Biometric quick-unlock for sensitive actions**: covered in detail in §4.5/§12.
- **Wi-Fi-only sync mode**: covered in §4.10, implemented as a `connectivity_plus`-driven gate in `DeltaSyncService` and the export/tachograph-upload code paths — when enabled and the current connection is cellular, large-payload operations queue until Wi-Fi is detected rather than silently consuming mobile data.
- **Tablet/large-screen layout**: at width ≥ 600dp (`MediaQuery.sizeOf(context).width`), Records and More tabs switch from push-navigation to a `Row`-based master-detail layout (list pane fixed at ~360dp, detail pane fills remainder) using Flutter's `NavigationRail`-friendly pattern rather than `BottomNavigationBar` at that breakpoint.
- **Dark mode**: every new screen designed dark-first (matches the existing theme system's default), verified via golden tests in both `ThemeMode.light` and `ThemeMode.dark` per §13.

---

## 10. Visual & Interaction Design (S-Grade UI)

- **No new visual system.** Reuse existing: `google_fonts` Inter, `lucide_icons_flutter`, the existing `AppColors`/`AppTypography` theme tokens. Any new color (e.g., health-score bands) must be added to the existing theme token file, not hardcoded as a raw hex in a widget.
- **Consistent List → Detail push pattern** across Fleet/Drivers/Clients — same `Hero` transition tag convention, same `AppBar` action-icon placement (edit top-right, overflow menu far top-right), learned once and reused.
- **Status/health color coding must match desktop exactly** — pull the actual hex/threshold values from the desktop's `theme/colors.py` or equivalent rather than approximating them; a dispatcher who's used the desktop app should have zero relearning cost for what "amber" means.
- **Skeleton loading, never bare spinners**, for every new list/detail screen — extend the existing `ShimmerSkeleton` widget already used on the driver home screen rather than introducing `CircularProgressIndicator` as the primary loading affordance.
- **Instructive empty states**: every new list screen (Clients, Fleet, Invoices, Team) has a dedicated empty-state widget with an icon, one sentence of context, and a direct CTA button — not a bare "No data" text.
- **Undo over confirm-dialog** for reversible actions (unassign driver, archive route, snooze alert) — a 4-second snackbar with an `Undo` action, per the Kanban drag-drop pattern in §4.11. Reserve blocking modal confirmation for genuinely irreversible actions: decommission truck, merge clients, delete (admin), invoice `submit`/`mark_paid` transitions.

---

## 11. Performance & Reliability Targets

| Metric | Target |
|---|---|
| Cold start to interactive (Home screen) | < 2.0s on mid-range Android (4GB RAM) |
| Screen transition (push navigation) | < 150ms perceived |
| Fleet/Driver/Client list render (50 items) | < 300ms from cache, < 1.2s from network |
| Delta sync cycle (per entity type) | < 2s on 4G for a typical SME dataset (10–50 trucks) |
| Offline → online action queue replay | Begins within 1s of connectivity restoration, FIFO order, visible progress indicator |
| Crash-free session rate | ≥ 99.5%, tracked via a newly added crash-reporting SDK (Sentry or Firebase Crashlytics — **new addition to the stack**, see Phase 0) |
| Background GPS battery draw (driver role) | No regression vs. current baseline; new dispatcher/manager screens perform zero background work |
| App size (APK/IPA) growth | Tracked per phase; new PDF-viewer/chart/signature/decimal packages evaluated for size impact before adoption (see Phase 0 dependency audit) |

---

## 12. Security Hardening (Mobile-Specific)

All desktop-side defense layers (JWT/refresh rotation, rate limiting, input sanitization, audit logging) apply unchanged to every new endpoint in §6. Mobile-specific additions introduced by this blueprint:

- **Biometric step-up** (`requireBiometricConfirmation()`, §4.5) required immediately before: invoice `finalize`/`submit`/`mark_paid` transitions, CMR signature save, client merge, user deactivation, company settings save. Implemented via `local_auth`'s `authenticate()` with `biometricOnly: false` (allow device PIN fallback) and a maximum 5-minute grace window during which a repeated sensitive action doesn't re-prompt.
- **No client-side caching of secrets.** `smtp_password` and `tracking_api_key` are never cached in `LocalDatabase` even in encrypted form — every Settings screen load re-fetches the masked `*_is_set` booleans fresh from the server.
- **Screen capture prevention** on `InvoiceEditorScreen`, `CmrFormScreen`, and the Settings screens carrying credentials — Android `FLAG_SECURE` on the relevant `Activity`/route, iOS equivalent via a `UIScreen.capturedDidChangeNotification` blur-overlay (iOS has no true prevention API, so a same-effect blur-on-capture-attempt is the accepted mitigation).
- **Session-bound action-queue TTL**: 24-hour cutoff for auto-replay, requiring explicit review past that window — detailed in §7.
- **Device deregistration cascade** on user deactivation: covered in §6.9, implemented server-side as a single transaction (set inactive + delete `mobile_devices` rows + revoke refresh tokens), never left to the mobile client to "ask nicely."

---

## 13. QA Strategy — Exact Test Suites

### 13.1 Test Pyramid Targets

| Layer | Current | Target Post-Blueprint | Tooling |
|---|---|---|---|
| Unit tests (models, providers, services) | ~50 | **~180+** | `flutter_test` |
| Widget tests (screen-level) | included in ~50 | **~90+** | `flutter_test` |
| Golden tests (visual regression, light+dark) | shared widgets only | **all new list/detail/form screens** | `flutter_test` golden |
| Integration tests (full-app flows) | ~10 | **~35+** | `integration_test` |
| Backend contract tests (new `/mobile/*` endpoints) | n/a | **1:1 with every endpoint in §6** | `pytest` |
| RBAC fixture tests (blocking) | none | **mandatory** — §13.4 | `flutter_test` + `pytest` |
| Manual exploratory QA (device matrix) | ad hoc | **structured pass per release** — §13.6 | manual |

### 13.2 Directory Layout

```
mobile_app/test/features/
├── fleet/                # CRUD flows, health-score badge thresholds, decommission gating
├── drivers/               # CRUD, expiry badge thresholds, tacho timeline rendering
├── clients/                # CRUD, merge flow (incl. typed-confirmation gate), contacts
├── analytics/               # chart rendering w/ mocked data, date-range edge cases, empty-dataset states
├── invoicing/                 # VAT/discount math parity (13.3), status stepper transitions, PDF preview
├── maintenance/                 # schedule CRUD, record-work sheet, overdue sort order
├── tachograph/                    # .ddd upload flow, async job polling, compliance breach banners
├── history/                        # trip/route filters, async export job lifecycle
├── team_management/                 # invite, role change, deactivate + device-deregistration assertion
├── global_search/                     # debounce behavior, per-type result capping
└── settings_company/                    # company config CRUD, write-only secret field behavior, role gating

backend/tests/mobile/
├── test_fleet_endpoints.py
├── test_drivers_endpoints.py
├── test_clients_endpoints.py           # includes merge-race-condition test w/ concurrent transactions
├── test_analytics_endpoints.py
├── test_invoicing_endpoints.py         # includes the shared test-vector parity fixture, §13.3
├── test_maintenance_endpoints.py
├── test_tachograph_endpoints.py
├── test_history_endpoints.py
├── test_team_endpoints.py              # includes device-deregistration-cascade assertion
├── test_settings_endpoints.py          # write-only secret field assertions
├── test_search_endpoint.py
└── test_mobile_rbac_matrix.py           # §13.4
```

### 13.3 Financial Correctness — Zero Tolerance

Invoice math (`grossValue`, `discountAmount`, `taxableAmount`, `vatAmount`, `totalAmount`, and per-line equivalents) must produce **byte-identical results** to the desktop's `services/invoicing/` calculations for the same inputs.

- **Shared test-vector fixture**: `shared/test_vectors/invoice_calculations.json` — an array of `{input: {...}, expected: {...}}` pairs generated once from the desktop's actual calculation service (Phase 0 task: write a one-off script that calls the real desktop calculation function across a spread of representative inputs — varied VAT rates, discount percentages, quantities, negative-edge-case attempts — and dumps the results). This single JSON file is consumed by **both** `backend/tests/mobile/test_invoicing_endpoints.py` and `mobile_app/test/features/invoicing/invoice_calculation_test.dart`. Any future formula change on either side that isn't mirrored on the other fails both suites immediately.
- **Property-based fuzzing**: mirror the desktop's `hypothesis`-based approach — fuzz discount %, VAT rate, and quantity to assert no negative totals, correct 2-decimal half-up rounding, and no floating-point drift (this is exactly why §4.5 mandates the `decimal` package client-side, not raw `double`).

### 13.4 RBAC Fixture Tests (Mandatory, Blocking CI Gate)

- A generation script (`backend/scripts/export_permission_matrix.py`, Phase 0 task) introspects the real `PermissionService`/`Permission` enum and dumps `shared/test_vectors/permission_matrix.json`: every `(role, permission)` pair and its expected boolean outcome.
- `backend/tests/mobile/test_mobile_rbac_matrix.py` walks this fixture and asserts every new `/mobile/*` endpoint returns `403` for a role that should not have the permission it requires, and succeeds (or returns the correct non-403 status) for a role that should.
- `mobile_app/test/core/permission_guard_test.dart` walks the same fixture and asserts every gated widget/tile added by this blueprint (§8.2's `buildIfPermitted` usages) is absent from the widget tree for a role lacking the permission.
- **This is a required-to-merge CI gate**, not a nightly job — RBAC regressions are a security defect, treated with the same severity as the desktop's existing Auth & Security invariant suite.

### 13.5 Offline/Sync Regression Suite (Extended)

- `action_queue_extended_test.dart`: every new queueable mutation type from §7's table, through queue → replay → conflict-resolution, plus explicit tests asserting `mergeClients`, `generate_xml`/`submit`/`mark_paid` transitions, tachograph import, and history export are **rejected from the queue** (not silently accepted) when offline.
- `delta_sync_extended_test.dart`: cursor tracking for the 5 new `SyncEntityType` values, asserting no cross-entity cursor bleed (e.g., a fleet sync failure must not advance the drivers cursor).
- **Airplane-mode manual test script** (documented in `docs/qa/airplane_mode_script.md`, run every release): perform a full CRUD cycle across Fleet/Drivers/Clients while offline, reconnect, and diff the resulting server state against the expected end state field-by-field.

### 13.6 Device & Platform Matrix

| Dimension | Coverage |
|---|---|
| OS versions | Android 10–14 (per current `minSdkVersion`), iOS last 3 major versions |
| Device tiers | 1× low-end Android (2–3GB RAM), 1× mid-range Android (4GB), 1× flagship Android, 1× recent iPhone, 1× tablet (iPad or Android, for §9's tablet layout) |
| Network conditions | Wi-Fi, 4G, throttled 3G, airplane-mode toggling mid-action |
| Locale | Romanian (primary) + English — new string keys added to `ro.json`/`en.json` verified via the existing `test/i18n/` pattern |
| Accessibility | Screen reader pass (TalkBack/VoiceOver) on every new CRUD form; 44×44pt minimum tap-target audit, with particular attention to the Kanban drag handles (§4.11) and signature pad (§4.5) |

### 13.7 Performance & Load Testing (Mobile-Facing Backend)

New `/mobile/*` endpoints are added to the backend's existing Locust suite (`tests/loadtest/`) with mobile-realistic patterns: many short-lived connections, frequent small delta-sync polls, occasional large export-job triggers. Target: zero p95 latency regression on existing endpoints once mobile traffic shares the same infrastructure.

### 13.8 Business Invariant Coverage Extension

The desktop's existing data-layer business invariants (Financial/Fleet/Drivers/Trips/etc.) already run server-side and need no mobile duplication. Mobile QA adds **UI-level invariant surfacing** on top: e.g., verifying the mobile invoice editor prevents *submitting* a negative total client-side for fast feedback, in addition to the server's authoritative rejection — a UX-quality check layered on an existing rule, not a new rule.

### 13.9 Release Gate Checklist (per phase and at final release)

- [ ] All unit/widget/golden/integration suites green for the phase's scope
- [ ] RBAC fixture suite green (blocking, §13.4)
- [ ] Financial test-vector parity suite green where applicable (blocking, §13.3)
- [ ] Offline/sync extended suite green where applicable
- [ ] Device matrix manual pass completed and signed off (§13.6)
- [ ] Crash-free session rate from previous beta ≥ 99.5% (once crash reporting is live from Phase 0)
- [ ] No new accessibility regressions
- [ ] Phase's Feature Parity Matrix rows (§2) confirmed shipped, not silently dropped

---

## 14. Master Definition of Done

The entire initiative (all phases in Part 2) is complete when:

1. Every row in the Feature Parity Matrix (§2) is shipped, except the single documented exception (Migration Center, §0).
2. Every backend endpoint in §6 has a passing contract test and enforces identical `PermissionService` logic to its desktop counterpart.
3. The RBAC fixture suite (§13.4) is green and is a blocking CI gate.
4. The financial test-vector parity suite (§13.3) is green.
5. The offline/sync extended suite (§13.5) is green, including the airplane-mode manual script.
6. The device matrix (§13.6) manual pass is signed off for the final release build.
7. Crash reporting is live and reporting ≥99.5% crash-free sessions on the release-candidate beta.
8. Every new screen follows §10's visual/interaction rules, verified via golden tests + a design review pass.
9. No dispatcher/manager-facing screen remains a placeholder or "open on desktop" dead end.
10. This document has been updated to reflect any implementation-time deviation — code is authoritative over documentation, and the documentation must be kept honest, per the existing project convention.

---

# PART 2 — EXECUTION PROGRAM

## 15. How To Use These Prompts

- Each phase below has exactly two prompts: an **Implementation Prompt** and a **Verification Prompt**. Both are written to be pasted verbatim into an AI coding agent session (OpenCode, DeepSeek V4 Pro, Kimi) with this document (or the relevant sections of it) available in context or as an attached file.
- **Never run a phase's Verification Prompt in the same, uninterrupted agent turn as its Implementation Prompt.** Run Implementation → have the agent stop and report → review its diff yourself (or have a second, fresh agent session do so) → then run Verification as a separate pass. This is the "verification-gated execution discipline" this blueprint assumes.
- **Do not start Phase N+1's Implementation Prompt until Phase N's Verification Prompt has come back with zero blocking findings.** If it comes back with findings, feed those findings back into a follow-up implementation prompt for Phase N before moving on — do not carry known defects forward "to fix later."
- Every Implementation Prompt ends with an explicit **Stop Condition** — the point at which the agent must halt and report back rather than continuing to build. This is deliberate: it keeps each unit of work small enough to actually review.
- Every Verification Prompt ends with an explicit **Output Format** — a structured pass/fail report, not free-form prose, so Gigi can scan it quickly.
- References like "§4.1," "§6.3," "§13.4" refer to Part 1 sections above — the agent should treat Part 1 as authoritative for any technical detail not fully repeated inline in the prompt itself.
- If, during implementation, the agent discovers that a real desktop constant, enum, or formula (e.g., the driver-expiry-warning threshold in §4.2, or the exact `Permission` enum values in §8.3) differs from what's written in this document, **the real code wins** — the agent should follow the actual desktop source of truth and note the discrepancy in its stop-condition report so this document can be corrected.

---

## Phase 0 — Foundations & Scaffolding

**Purpose:** stand up the shared infrastructure every later phase depends on, so Phases 1–5 are pure feature work rather than repeatedly rebuilding plumbing.

### Phase 0 — Implementation Prompt

```
You are implementing Phase 0 (Foundations & Scaffolding) of the Operion Mobile S-Grade Blueprint.
Read sections 5, 6, 7, 8.1, 13.3, 13.4, and 14 of the blueprint document before starting.

Do the following, in order:

1. BACKEND SCAFFOLDING
   a. Create backend/api/v1/mobile/ if it does not already exist, with an empty router module
      per new entity: fleet.py, drivers.py, clients.py, analytics.py, invoicing.py,
      maintenance.py, tachograph.py, history.py, team.py, settings.py, search.py.
      Each module exports an APIRouter with a prefix and tag matching its filename.
   b. Register all of them in backend/api/v1/mobile/__init__.py under a single mobile_router,
      and mount mobile_router in the main API app alongside the existing desktop-facing routers.
   c. Confirm (read the actual source, do not assume) the exact class/module path of the existing
      PermissionService and the exact Permission enum values relevant to §8.3's matrix. Import
      PermissionService directly into every new mobile router module — do not create a parallel
      permission-checking utility.
   d. Write backend/scripts/export_permission_matrix.py: a script that introspects the real
      PermissionService/Permission enum and every real Role, and writes
      shared/test_vectors/permission_matrix.json as an array of
      {role, permission, expected_allowed: bool} objects covering every (role, permission) pair.
      Run it once and commit the resulting JSON.
   e. Write a one-off script backend/scripts/export_invoice_test_vectors.py that calls the REAL
      desktop invoicing calculation function(s) (locate them under services/invoicing/ or
      wherever the desktop app actually implements VAT/discount math) across at least 25
      representative input combinations (varied VAT rates, discount percentages, quantities,
      and at least 3 deliberate edge cases: zero quantity, 100% discount, a value that requires
      half-up rounding). Write the input/output pairs to
      shared/test_vectors/invoice_calculations.json. Run it once and commit the resulting JSON.

2. MOBILE APP SCAFFOLDING
   a. Create the feature directories listed in §4's directory tree under mobile_app/lib/features/
      (fleet, clients, analytics, invoicing, maintenance, tachograph, history, team_management,
      global_search) with empty models/, providers/, screens/, widgets/ subfolders and a
      placeholder README.md in each stating what will live there per §4.
   b. Add the `decimal` package to mobile_app/pubspec.yaml for Decimal-safe invoice math (§4.5).
      Add file_picker, signature, and a PDF viewer package (evaluate syncfusion_flutter_pdfviewer
      vs pdfx per current pub.dev popularity/maintenance status; pick one and record the choice
      in a short ADR comment at the top of invoicing/README.md).
   c. Extend (do not replace) core/sync/sync_cursors.dart's SyncEntityType enum and
      core/sync/action_queue.dart's QueuedActionType enum exactly as specified in §5's
      "Sync/queue extensions" code block.
   d. Implement core/auth/permission_guard.dart's buildIfPermitted() helper exactly as specified
      in §8.2, backed by a permissionProvider that loads shared/test_vectors/permission_matrix.json
      equivalent data from the live /mobile/... auth/me-style endpoint (whatever the existing
      current-user-permissions endpoint is called — locate it, do not invent a new one) rather
      than the static JSON fixture (the JSON fixture is for tests only, per 13.4).
   e. Add a crash-reporting SDK (Sentry or Firebase Crashlytics — pick based on what's already
      configured for the Flutter/FastAPI stack elsewhere in the codebase, if anything is; if
      neither is configured anywhere, default to Sentry for simpler self-hosting alignment with
      the existing PostgreSQL/Redis self-hosted stack) and wire it into the existing triple
      error-handling setup (FlutterError.onError, PlatformDispatcher.onError, runZonedGuarded)
      so all three report to it.

3. SHARED TEST INFRASTRUCTURE
   a. Add backend/tests/mobile/ directory with an empty conftest.py that provides fixtures for
      a test user of each role (dispatcher/manager/admin) with valid auth tokens, reusing
      existing test fixtures/factories from the desktop test suite wherever they already exist
      (do not duplicate factory logic).
   b. Add mobile_app/test/features/ subdirectories matching §13.2's layout, each with a single
      placeholder test file that just asserts `true` so the directory structure and CI test
      discovery are proven working before real tests are written in later phases.
   c. Confirm the CI pipeline configuration picks up backend/tests/mobile/ and
      mobile_app/test/features/ (check .github/workflows/ or equivalent) and add them if missing.

STOP CONDITION: Once steps 1–3 are complete and every new file compiles/runs (backend router
mounts without error, Flutter app builds without error), STOP and report:
  - The exact file paths created/modified
  - The exact PermissionService class path and Permission enum values you found (for §8.3
    reconciliation)
  - The exact desktop invoicing calculation function location and any discrepancy between its
    real formula and §4.5's documented formula
  - Which PDF viewer package and crash-reporting SDK you chose and why
  - Do NOT implement any actual feature screens yet — that begins in Phase 1.
```

### Phase 0 — Verification Prompt

```
You are verifying Phase 0 (Foundations & Scaffolding) of the Operion Mobile S-Grade Blueprint.
Review the actual repository state (not just the prior agent's self-report) against this checklist.
Read section 14 (Master Definition of Done) and Phase 0's Implementation Prompt for context.

Check and report on each of the following as PASS / FAIL / PARTIAL, with the specific file path
and line number as evidence for any FAIL or PARTIAL:

1. Do backend/api/v1/mobile/{fleet,drivers,clients,analytics,invoicing,maintenance,tachograph,
   history,team,settings,search}.py all exist, each exporting an APIRouter, and are they all
   registered in a single mobile_router mounted on the main app?
2. Does shared/test_vectors/permission_matrix.json exist, is it non-empty, and does spot-checking
   3 random entries against the real PermissionService produce matching results?
3. Does shared/test_vectors/invoice_calculations.json exist with at least 25 entries including
   the 3 required edge cases (zero quantity, 100% discount, half-up rounding case)? Manually
   recompute 2 random entries by hand against the documented §4.5 formula — do they match?
4. Do all feature directories listed in the prompt exist under mobile_app/lib/features/ with the
   correct subfolder structure?
5. Is the `decimal` package actually added to pubspec.yaml and does `flutter pub get` succeed?
6. Are core/sync/sync_cursors.dart and core/sync/action_queue.dart's enums extended exactly per
   §5, without any existing enum values removed or renamed?
7. Does core/auth/permission_guard.dart's buildIfPermitted() exist and does it read from a live
   permissions source (not a hardcoded stub)?
8. Is a crash-reporting SDK actually wired into all three existing error-handling entry points
   (FlutterError.onError, PlatformDispatcher.onError, runZonedGuarded), and does a deliberately
   thrown test exception actually appear in the crash-reporting dashboard/local test harness?
9. Do backend/tests/mobile/ and mobile_app/test/features/ placeholder tests actually run green
   in CI (or locally if CI isn't reachable in this session)?
10. Does the mobile app still build and run end-to-end (smoke test: launch, log in, reach the
    existing Dispatcher Home screen) with no regressions introduced by this phase's changes?

OUTPUT FORMAT — return exactly this structure:

## Phase 0 Verification Report
| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Router scaffolding | PASS/FAIL/PARTIAL | ... |
...(one row per check)...

## Blocking Findings
(list any FAIL/PARTIAL that must be fixed before Phase 1 begins, or write "None")

## Non-Blocking Notes
(anything worth flagging but not blocking, e.g. a naming inconsistency)

## Recommendation
PROCEED TO PHASE 1 / DO NOT PROCEED — fix blocking findings first
```

---

## Phase 1 — Records Core (Fleet, Drivers, Clients)

**Purpose:** close the highest-value gap — dispatchers/managers currently cannot manage fleet, driver, or client records at all on mobile.

### Phase 1 — Implementation Prompt

```
You are implementing Phase 1 (Records Core) of the Operion Mobile S-Grade Blueprint.
Phase 0 must already be complete and verified. Read sections 4.1, 4.2, 4.3, 5, 6.1, 6.2, 6.3,
7, 8.3, and 13.3 (for context on later financial dependencies — not needed yet) before starting.

BACKEND — implement exactly the endpoints specified in §6.1 (Fleet), §6.2 (Drivers), §6.3
(Clients) inside the router modules scaffolded in Phase 0:
  - Every handler's first business-logic line must call PermissionService.require(...) with the
    exact permission from §8.3's matrix for that action.
  - GET list endpoints must support page/page_size/search query params per the pagination
    convention in §6's preamble.
  - POST /mobile/clients/merge must be implemented with a DB transaction and row-level locking
    on both target and source rows, exactly as specified in §6.3 — write a concurrency test
    (two simultaneous merge attempts on overlapping client sets) to prove the locking works,
    not just a happy-path test.
  - DELETE /mobile/fleet/{truck_id} must require the ADMIN-only delete_vehicle permission per
    §8.3 — verify this against the real PermissionService, not just this document.

MOBILE — implement:
  - features/fleet/models/truck.dart, providers/fleet_providers.dart (fleetListProvider,
    truckDetailProvider, truckMaintenanceHistoryProvider, fleetMutationProvider) per §5,
    screens/fleet_list_screen.dart and screens/truck_detail_screen.dart per §4.1.
  - features/drivers/ — EXTEND the existing teams/ feature's Driver model per §4.2's extension
    (do not create a parallel Driver model), add the "Expiring" filter chip, build
    screens/driver_detail_screen.dart with the 4 tabs described in §4.2, and widgets/expiry_badge.dart
    using the REAL threshold constant from backend/services/driver_compliance_service.py (locate
    it — do not hardcode 30 days if the real constant differs).
  - features/clients/ — models/client.dart, providers/client_providers.dart,
    screens/client_list_screen.dart, screens/client_detail_screen.dart (4 tabs per §4.3),
    widgets/client_merge_sheet.dart with the typed-confirmation gate described in §4.3.
  - Wire all three list/detail providers into the dual-mode (network-then-cache) pattern
    described in §5's preamble, extending DeltaSyncService's _syncFleet()/_syncDrivers()/
    _syncClients() methods and the local SQLite cache tables for each.
  - Extend ActionQueue to handle createTruck/updateTruck/decommissionTruck/recordMaintenance/
    createDriver/updateDriver/createClient/updateClient/addClientContact per §7's table — and
    explicitly EXCLUDE mergeClients from being queueable; the Merge button in
    client_merge_sheet.dart must check connectivity and disable itself with the inline message
    from §7 when offline, calling the API directly (never through the queue) when online.
  - Apply §8.2's buildIfPermitted() wrapping to every gated action across all three features:
    create/update/decommission on Fleet, create/update on Drivers, create/update/merge on Clients.
  - Register the new routes (/dispatcher/records/fleet, /.../fleet/:id, /.../drivers/:id (new),
    /.../clients, /.../clients/:id) in the app's router, and add Fleet + Clients tiles to the
    Records tab grid described in §3 (Drivers tile already exists as "Teams" — verify it still
    routes correctly to the upgraded screen).

TESTS — write these now, not deferred to a later "testing phase":
  - backend/tests/mobile/test_fleet_endpoints.py, test_drivers_endpoints.py,
    test_clients_endpoints.py (including the merge concurrency test above), each covering every
    endpoint's happy path, permission-denial path (wrong role gets 403), and validation-error path.
  - mobile_app/test/features/fleet/, drivers/, clients/ — unit tests for providers/models,
    widget tests for list/detail screens (including empty state and gated-action visibility),
    golden tests for list and detail screens in both light and dark mode.
  - Do NOT write the full RBAC fixture suite yet (that's §13.4/Phase-agnostic, wire it up now
    incrementally: add this phase's new endpoints/screens to shared/test_vectors/
    permission_matrix.json coverage and to backend/tests/mobile/test_mobile_rbac_matrix.py /
    mobile_app/test/core/permission_guard_test.dart, extending the Phase 0 scaffolding rather
    than building a separate one-off check).

STOP CONDITION: Once Fleet, Drivers, and Clients are fully functional end-to-end (create, read,
update, decommission/merge where applicable, all gated correctly, all tests passing), STOP and
report:
  - Test pass/fail counts for this phase's new suites
  - The real driver-expiry threshold constant you found and used
  - Any endpoint where the real PermissionService's permission name differed from §8.3's naming
  - Do NOT start Analytics, History, or any Phase 2+ work.
```

### Phase 1 — Verification Prompt

```
You are verifying Phase 1 (Records Core) of the Operion Mobile S-Grade Blueprint.
Read §2 (rows 8, 9, 10), §4.1–4.3, §6.1–6.3, §7, §8.2–8.3, and §13.9's release gate checklist.

Check and report PASS / FAIL / PARTIAL with file/line evidence for each:

1. Do all Fleet, Driver, and Client endpoints from §6.1–6.3 exist and return correct responses
   for a manager-role test user (happy path)?
2. Does every mutation endpoint reject a dispatcher-role test user with 403 where §8.3 says it
   should (create/update/decommission vehicle, create/update driver, create/update/merge client)?
3. Does DELETE /mobile/fleet/{id} reject a MANAGER-role user with 403 (admin-only per §8.3) and
   succeed for an admin-role user?
4. Run the client-merge concurrency test — does it actually prove row-level locking (i.e., does
   it fail without the locking code and pass with it — check by temporarily reverting the lock
   if needed to confirm the test isn't a false positive)?
5. In the Flutter app, log in as a dispatcher-role test account and navigate to Fleet, Drivers,
   Clients screens — confirm create/edit/decommission/merge buttons are ABSENT from the widget
   tree (not just disabled) per §8.2.
6. Log in as a manager-role test account — confirm those same buttons ARE present and functional.
7. Turn on airplane mode and attempt: create a truck (should queue), update a driver (should
   queue), attempt to merge two clients (should be blocked with the inline offline message, NOT
   queued) — confirm all three behave per §7's table.
8. Reconnect from airplane mode — confirm the queued truck/driver actions replay successfully
   and the local cache reconciles with server state.
9. Do the expiry badges on Driver Detail use the REAL threshold from
   backend/services/driver_compliance_service.py (or wherever it actually lives), not a
   hardcoded value that might differ from that constant?
10. Are golden tests present and passing for Fleet/Driver/Client list and detail screens in
    both light and dark mode?
11. Does shared/test_vectors/permission_matrix.json now include entries for every new permission
    exercised in this phase, and does backend/tests/mobile/test_mobile_rbac_matrix.py /
    mobile_app/test/core/permission_guard_test.dart actually assert against them?
12. Full regression smoke test: do all previously-existing screens (Home, Jobs, Map, Copilot,
    Teams/Drivers list) still function with no regressions introduced by this phase?

OUTPUT FORMAT — same table + Blocking Findings + Non-Blocking Notes + Recommendation structure
as Phase 0's Verification Prompt.
```

---

## Phase 2 — Analytics, History & Global Search

**Purpose:** eliminate the Analytics placeholder, add Trip/Route History, and add cross-entity search — all read-heavy, lower-risk than Phase 3's financial work, but high visibility.

### Phase 2 — Implementation Prompt

```
You are implementing Phase 2 (Analytics, History & Global Search) of the Operion Mobile S-Grade
Blueprint. Phases 0–1 must already be complete and verified. Read sections 4.4, 4.8, 5, 6.4,
6.8, 6.11, and §9's tablet-layout note before starting.

BACKEND:
  - Implement §6.4's analytics endpoints via a NEW MobileAnalyticsAggregator service that wraps
    the existing AnalyticsService's queries but reshapes output into small, fl_chart-friendly
    JSON — do not simply proxy the desktop's Plotly-shaped payloads. Confirm this by inspecting
    an actual response payload size (should be well under 50KB for a typical date range).
  - Implement §6.4's export endpoint as a Celery-backed async job producing a signed, short-lived
    (10 min) object-storage URL — reuse the existing Celery worker infrastructure, do not stand
    up a parallel job queue.
  - Implement §6.8's trip/route history list endpoints (paginated) and the async export job
    endpoints, reusing the SAME Celery export-job pattern as the analytics export above where
    the code can reasonably be shared (e.g., a common ExportJobService).
  - Implement §6.11's global search endpoint, reusing the existing PostgreSQL FTS/pgvector
    infrastructure already backing the Copilot's Help Mode and Document Center — locate that
    existing infrastructure and extend it rather than building new search indices from scratch.

MOBILE:
  - features/analytics/ — build screens/analytics_screen.dart with the 4-tab structure from
    §4.4, widgets/date_range_selector.dart, and the exact chart-per-tab mapping specified
    (LineChart+BarChart for Revenue, PieChart+bar-list for Fleet Utilization, sortable DataTable
    for Driver Performance, stacked BarChart for Invoice Aging) using fl_chart.
  - features/history/ — screens/trip_history_screen.dart and route_history_screen.dart per §4.8,
    including the async export UX (snackbar → poll/notification → share sheet) and
    exportJobStatusProvider's polling StreamProvider per §5.
  - features/global_search/ — screens/global_search_screen.dart, globalSearchQueryProvider,
    globalSearchResultsProvider with the 350ms debounce specified in §5, wired to the persistent
    search icon in every tab's AppBar described in §3.
  - Add Analytics tile to the More tab, Trip History + Route History tiles to the Records tab,
    per §3's grid.
  - Since history export and analytics export are explicitly NOT queueable offline per §7,
    confirm the UI disables these actions (with the same inline-message pattern as §7's other
    non-queueable actions) when offline, rather than allowing a request to silently fail.
  - Implement the tablet/master-detail layout breakpoint (≥600dp) described in §9 for the
    Records and More tabs, since this phase introduces enough new list/detail pairs to make the
    breakpoint worth validating now rather than deferring it to Phase 5.

TESTS:
  - backend/tests/mobile/test_analytics_endpoints.py, test_history_endpoints.py,
    test_search_endpoint.py — happy path, permission-denial (dispatcher role denied analytics
    view per §8.3), pagination correctness, export-job async lifecycle (job created ->
    processing -> success with valid signed URL -> URL expires after 10 min).
  - mobile_app/test/features/analytics/, history/, global_search/ — provider unit tests
    (including empty-dataset chart rendering, a real edge case worth testing explicitly since a
    brand-new company will have zero historical data), widget tests, golden tests for all 4
    analytics tabs in light+dark, golden tests for the tablet master-detail layout at ≥600dp.
  - Extend shared/test_vectors/permission_matrix.json and the RBAC fixture suites with this
    phase's new permissions/screens (view_analytics, etc.).

STOP CONDITION: Once Analytics (all 4 tabs), Trip/Route History, and Global Search are fully
functional with export flows working end-to-end, STOP and report:
  - Confirmed payload size for a representative analytics response (proving the "not a desktop
    proxy" requirement was met)
  - Test pass/fail counts
  - Any gap between the FTS infrastructure you found and what §6.11 assumed exists
  - Do NOT start Phase 3 (Invoicing/Finance) work.
```

### Phase 2 — Verification Prompt

```
You are verifying Phase 2 (Analytics, History & Global Search) of the Operion Mobile S-Grade
Blueprint. Read §2 (rows 2, 15, 16), §4.4, §4.8, §6.4, §6.8, §6.11, §8.3, §13.9.

Check and report PASS / FAIL / PARTIAL with evidence:

1. Does the Analytics screen render all 4 tabs (Revenue, Fleet Utilization, Driver Performance,
   Invoice Aging) with real (not mocked/placeholder) data for a manager-role test account?
2. Is the "open on desktop" placeholder text/screen fully removed from the codebase (grep for it
   to confirm no dead reference remains)?
3. Does a dispatcher-role test account get a 403 from every /mobile/analytics/* endpoint, and is
   the Analytics tile itself absent from that account's More tab grid?
4. Pick one analytics response and confirm its payload size — is it meaningfully smaller than
   the equivalent desktop Plotly-shaped payload (spot-check by comparing field verbosity), i.e.
   was this actually built as a real mobile-shaped aggregation layer and not a thin proxy?
5. Trigger a Trip History export — does it return 202 with a job_id, does polling the status
   endpoint eventually return a working signed download_url, and does that URL actually expire
   after ~10 minutes (test by waiting or by checking the expiry timestamp logic directly)?
6. Attempt a Trip History export while the app is in airplane mode — is the export action
   disabled/blocked with an inline message, not silently queued or silently failing?
7. Test Global Search with a 1-character query (should NOT fire a network request per the 2+
   character minimum in §5), then a 2+ character query (should fire after the debounce window,
   not on every keystroke) — confirm via network log inspection.
8. Does Global Search correctly cap each result type at 5 with a "N more" indicator when more
   than 5 matches exist for a given type?
9. Resize/test the app at ≥600dp width (tablet or simulator) — does the Records tab actually
   switch to a master-detail two-pane layout rather than remaining in push-navigation mode?
10. Are golden tests present and passing for all 4 analytics tabs (light+dark) and the tablet
    layout?
11. Full regression smoke test against Phase 0–1 functionality — any regressions?

OUTPUT FORMAT — same structure as prior phases.
```

---

## Phase 3 — Finance (Invoicing, e-Factura, CMR, Maintenance)

**Purpose:** the highest-stakes phase — real money and legal-compliance documents. Ship only after Phases 1–2 have proven the patterns (RBAC gating, offline queue rules, biometric step-up plumbing) at lower risk.

### Phase 3 — Implementation Prompt

```
You are implementing Phase 3 (Finance) of the Operion Mobile S-Grade Blueprint. Phases 0–2 must
already be complete and verified. This is the highest-stakes phase in the entire initiative —
treat every step involving money calculation or the invoice status machine with the same rigor
as the desktop's own financial code. Read sections 4.5, 4.6, 5, 6.5, 6.6, 8.4, 12, and 13.3 in
full, more than once if needed, before writing any code.

STEP 1 — FINANCIAL PARITY FIRST, BEFORE ANY UI:
  - Load shared/test_vectors/invoice_calculations.json (produced in Phase 0).
  - Implement the InvoiceEditorNotifier.recompute() function in
    features/invoicing/providers/invoicing_providers.dart using the `decimal` package (NOT raw
    double arithmetic) implementing exactly the formula in §4.5.
  - Write mobile_app/test/features/invoicing/invoice_calculation_test.dart that runs EVERY entry
    in invoice_calculations.json through this Dart function and asserts byte-identical output
    (down to the exact Decimal string representation) to the expected values. Do not proceed to
    step 2 until every one of these test vectors passes — this is a hard gate, not a suggestion.
  - Cross-check the same test vectors against the backend by writing the equivalent Python
    assertion in backend/tests/mobile/test_invoicing_endpoints.py's calculation-only test, so
    both sides of the wire are proven correct against the same ground truth before any endpoint
    or screen is built on top of them.

STEP 2 — BACKEND:
  - Implement §6.6's invoice endpoints, with the transition endpoint enforcing exactly the
    fine-grained per-transition permissions in §8.4 (not a single blanket update_invoice check).
  - Implement server-side transition validation (reject illegal transitions with 422 + a
    machine-readable error_code, per §6.6) — write a test for every illegal transition path
    (finalize with zero line items, submit before generate_xml, mark_paid before submit, etc.)
  - Implement §6.5's maintenance schedule/cost-trend endpoints.
  - Implement the CMR creation endpoint (POST /mobile/invoices/{invoice_id}/cmr).

STEP 3 — MOBILE:
  - features/invoicing/ — models/invoice.dart, the full provider set from §5, and
    screens/invoice_list_screen.dart, screens/invoice_editor_screen.dart (trip picker, reorderable
    line items, live-computed footer using the STEP-1-VERIFIED recompute() function,
    screens/cmr_form_screen.dart with the signature package integration, and
    screens/invoice_pdf_preview_screen.dart using the PDF viewer package chosen in Phase 0.
  - Implement the status-stepper widget described in §4.5 so the invoice's current state in the
    draft->finalized->xmlGenerated->submittedExternally->paid (or ->cancelled) machine is always
    visually explicit, not implied.
  - Implement core/security/biometric_gate.dart's requireBiometricConfirmation() helper (§4.5,
    §12) reusing the existing local_auth app-unlock integration, and wire it in as a REQUIRED
    gate immediately before the finalize, submit, and mark_paid transition calls, and before
    saving a CMR signature — confirm by testing that the API call literally cannot fire without
    a successful biometric/PIN check completing first.
  - Implement FLAG_SECURE (Android) / capture-blur (iOS) on InvoiceEditorScreen and
    CmrFormScreen per §12.
  - features/maintenance/ — screens/maintenance_screen.dart and widgets/record_work_sheet.dart
    per §4.6, wired to fleetMutationProvider.recordMaintenance() (the SAME mutation function
    Phase 1 built, reused here — do not create a second code path).
  - Extend ActionQueue per §7's finance-specific rules: saveInvoiceDraft and finalize/cancel
    transitions ARE queueable; generate_xml/submit/mark_paid transitions and CMR signature-save
    are NOT queueable — the UI must show the "requires connection" message for the latter set
    when offline, exactly like mergeClients in Phase 1.
  - Add Invoicing and Maintenance tiles to the More tab per §3.

TESTS:
  - backend/tests/mobile/test_invoicing_endpoints.py, test_maintenance_endpoints.py — cover every
    transition (legal and illegal), every §8.4 permission boundary, and the calculation
    cross-check from Step 1.
  - mobile_app/test/features/invoicing/, maintenance/ — the calculation test from Step 1, plus
    widget tests for the editor/status-stepper/biometric-gate flow (mock the biometric check in
    tests, but assert the API call is never invoked until the mock "succeeds"), golden tests.
  - A dedicated test asserting the offline-blocking behavior for generate_xml/submit/mark_paid/
    CMR-signature actions specifically (not just a general "offline queue" test).
  - Extend the RBAC fixture suites with every §8.4 fine-grained transition permission.

STOP CONDITION: Once every invoice transition, the CMR flow, and Maintenance recording are fully
functional with all financial test vectors passing on both sides of the wire, STOP and report:
  - Full pass/fail breakdown of the Step-1 financial-parity test run (must be 100% pass, report
    exact numbers)
  - Confirmation that biometric gating actually blocks the relevant API calls (describe how you
    verified this, not just that you wired the code)
  - Any illegal-transition case the real backend allows that §6.6 assumed should be rejected (or
    vice versa) — flag any such discrepancy explicitly, do not silently "fix" the spec yourself.
  - Do NOT start Phase 4 (Team Management/Settings/Tachograph) work.
```

### Phase 3 — Verification Prompt

```
You are verifying Phase 3 (Finance) of the Operion Mobile S-Grade Blueprint — the highest-stakes
phase in this initiative. Apply extra scrutiny here; a financial or RBAC bug in this phase is
more costly than in any other. Read §2 (row 14), §4.5, §4.6, §6.5, §6.6, §8.4, §12, §13.3, §13.9.

Check and report PASS / FAIL / PARTIAL with evidence — do not mark anything PASS on this phase
without having actually executed the relevant test yourself, not merely reading the prior
agent's report:

1. Run mobile_app/test/features/invoicing/invoice_calculation_test.dart yourself — does every
   single test vector from shared/test_vectors/invoice_calculations.json pass? Report the exact
   count (e.g., "25/25 passed") — any number less than 100% is a BLOCKING finding regardless of
   how small the discrepancy.
2. Run the equivalent backend calculation test — same 100%-or-blocking standard.
3. Manually construct one deliberately tricky invoice (e.g., 3 line items, mixed VAT rates,
   a discount that requires half-up rounding) through the actual UI, and hand-calculate the
   expected total yourself independently — does the app's displayed total match your
   hand-calculation to the cent?
4. Attempt every illegal transition listed in the implementation prompt (finalize with zero
   line items, submit before generate_xml, mark_paid before submit) via direct API call (not
   just through the UI, which might prevent the attempt before it reaches the server) — does
   the backend reject all of them with 422 and a sensible error_code?
5. As a manager-role user, attempt to `submit` an invoice — does the app require a biometric/PIN
   confirmation BEFORE the network call fires? Prove this by attempting to intercept/observe
   whether the API call happens if you cancel the biometric prompt (it must NOT fire).
6. As a dispatcher-role user, confirm the Invoicing tile/screens are entirely absent (§8.2 rule),
   and confirm a direct API call attempt to create/finalize an invoice as this role returns 403.
7. As a manager-role user, attempt to `cancel` a finalized invoice — per §8.4 this requires the
   submit_invoice permission specifically, not just create_invoice — confirm this fine-grained
   distinction is actually enforced, not just a blanket "manager can do everything invoice-related"
   implementation that happens to look right on the surface.
8. Turn on airplane mode: attempt `finalize` (should queue), then attempt `generate_xml`,
   `submit`, `mark_paid` (should all be blocked with inline messaging, NOT queued) — confirm
   exactly per §7's finance rules.
9. Attempt to screenshot/screen-record the Invoice Editor and CMR Form screens — is capture
   actually prevented/blurred per §12?
10. Complete a full CMR flow including the signature pad — is a biometric/PIN check required
    before the signature is saved?
11. Complete a full Maintenance "record work" flow from the Truck Detail screen — does it call
    the SAME fleetMutationProvider.recordMaintenance() function Phase 1 built (check the actual
    code path, not just the visible behavior) rather than a duplicate implementation?
12. Full regression smoke test against Phases 0–2 — any regressions?

OUTPUT FORMAT — same structure as prior phases, but add an explicit top-line verdict:
"FINANCIAL PARITY: 100% CONFIRMED" or "FINANCIAL PARITY: NOT CONFIRMED — DO NOT SHIP" before the
detailed table.
```

---

## Phase 4 — Configuration & Admin (Team Mgmt, Settings, Tachograph)

**Purpose:** manager-only, lower daily-use-frequency features — safe to land after the higher-value/higher-risk phases are stable.

### Phase 4 — Implementation Prompt

```
You are implementing Phase 4 (Configuration & Admin) of the Operion Mobile S-Grade Blueprint.
Phases 0–3 must already be complete and verified. Read sections 4.7, 4.9, 4.10, 5, 6.7, 6.9,
6.10, 8.3, and 12 before starting.

BACKEND:
  - Implement §6.7's tachograph import endpoints (async Celery job pattern, reusing the same
    ExportJobService-style async-job infrastructure built in Phase 2 where the shape fits, since
    both are "upload/trigger -> poll or notify -> retrieve result" patterns).
  - Implement §6.9's team management endpoints, with the invite endpoint's role param
    SERVER-SIDE constrained so a manager-role caller literally cannot successfully invite an
    admin-role user (this must be enforced in the endpoint logic, not just hidden in the UI) —
    write a test that attempts this via direct API call as a manager and confirms rejection.
  - Implement the device-deregistration cascade in the same transaction as user deactivation,
    per §6.9 and §12: deactivate + delete mobile_devices rows + revoke refresh tokens, all
    atomic. Write a test that deactivates a user with an active mobile session and confirms
    that session's subsequent API calls are rejected (401) immediately after deactivation.
  - Implement §6.10's company settings endpoints with the write-only secret field behavior
    exactly as specified: GET never returns smtp_password/tracking_api_key values, only
    *_is_set booleans; PATCH with a field omitted leaves it unchanged; PATCH with an explicit
    empty string clears it. Write tests for all three of these behaviors specifically.

MOBILE:
  - features/tachograph/ — screens/tachograph_screen.dart per §4.7: driver picker, file_picker
    integration filtered to .ddd/.esm, upload progress, compliance summary card, warning banners
    sourced verbatim from the backend response (do not recompute compliance logic client-side),
    and the weekly-limit circular gauge capped at 3360 minutes (verify this constant against
    the real desktop TachoComplianceEngine, per the same "real code wins" rule as Phase 1's
    driver-expiry threshold).
  - features/team_management/ — screens/team_management_screen.dart per §4.9: user list with
    role badges, invite sheet with the role dropdown correctly restricted client-side to match
    the server-side restriction above (defense in depth, but the server check from the backend
    step above is what actually matters), deactivate confirmation dialog with the explicit
    device-revocation wording specified in §4.9.
  - features/settings/ — expand the existing SettingsScreen with the 7 new sections from §4.10
    (Company Profile, SMTP Configuration, Fleet Tracking Provider, Maintenance Thresholds,
    Notification Preferences, Data Usage, Biometric Lock), each gated per §8.3 (first 4
    manager/admin-only, last 3 available to all roles). Confirm the SMTP/tracking-provider
    password fields render as masked placeholders and are NEVER pre-filled with a real secret
    value fetched from the server.
  - Wire the "Wi-Fi only for large syncs" toggle (Data Usage section) into DeltaSyncService and
    into the tachograph-upload and history-export code paths from Phases 2–3, via a
    connectivity_plus-driven gate, per §9.
  - Add Team Management, Settings expansion, and Tachograph tiles/sections to the More tab,
    ensuring Team Management is entirely absent (not disabled) for dispatcher AND manager
    viewing an admin-only sub-affordance if any exists (there should not be one per §8.3 — admin
    has no mobile login surface at all; just confirm no stray admin-only UI leaked in here).

TESTS:
  - backend/tests/mobile/test_tachograph_endpoints.py, test_team_endpoints.py (including the
    manager-cannot-invite-admin test and the deactivation-cascade session-revocation test),
    test_settings_endpoints.py (including the three write-only-field behavior tests).
  - mobile_app/test/features/tachograph/, team_management/, settings_company/ — provider/widget/
    golden tests, plus a specific test confirming the compliance warning banners render the
    backend's literal message text rather than a client-recomputed one.
  - Extend RBAC fixture suites with this phase's permissions.

STOP CONDITION: Once Tachograph import, Team Management, and expanded Settings are fully
functional, STOP and report:
  - Confirmation (with evidence, e.g. a failed API response) that the manager-cannot-invite-admin
    restriction is enforced server-side, not just hidden client-side
  - Confirmation (with evidence) that a deactivated user's existing session is actually rejected
    post-deactivation
  - The real weekly tacho limit constant you found and used
  - Do NOT start Phase 5 (Convenience Layer) work.
```

### Phase 4 — Verification Prompt

```
You are verifying Phase 4 (Configuration & Admin) of the Operion Mobile S-Grade Blueprint.
Read §2 (rows 13, 19, 20), §4.7, §4.9, §4.10, §6.7, §6.9, §6.10, §8.3, §12, §13.9.

Check and report PASS / FAIL / PARTIAL with evidence:

1. As a manager-role user, attempt (via direct API call, not just the UI) to invite a new user
   with role="admin" — is it actually rejected server-side?
2. Deactivate a test user who has an active, valid mobile session/token — attempt an API call
   using that now-deactivated user's token immediately after — is it rejected (401)? Confirm the
   mobile_devices rows for that user were actually deleted (check the DB directly if possible).
3. GET /mobile/settings/company as a manager — confirm the response contains
   smtp_password_is_set/tracking_api_key_is_set booleans and NEVER the actual secret values.
4. PATCH company settings omitting the smtp_password field — confirm the previously-set value
   is unchanged. PATCH again with smtp_password="" — confirm it's now cleared (is_set becomes
   false). PATCH with a real new value — confirm is_set becomes true and a "Send test email"
   action using it succeeds.
5. As a dispatcher-role user, confirm Team Management and the manager-gated Settings sections
   (Company Profile, SMTP, Tracking Provider, Maintenance Thresholds) are entirely absent from
   the UI, and confirm direct API calls to those endpoints as a dispatcher return 403.
6. Upload a real (or realistic test-fixture) .ddd file via the Tachograph screen — does the
   async job complete and does the compliance summary display the backend's actual response
   text for any warning banners (verify by comparing the exact string against the API response,
   not a paraphrase)?
7. Confirm the weekly tacho gauge's cap value matches the REAL constant from the desktop's
   TachoComplianceEngine (or wherever it actually lives) — flag if the implementation used a
   hardcoded 3360 that doesn't match the real constant.
8. Toggle "Wi-Fi only for large syncs" on, switch to a simulated cellular connection, and attempt
   a tachograph upload and a history export — do both correctly defer/block rather than silently
   consuming cellular data?
9. Confirm no admin-only UI affordance leaked into the mobile app anywhere (grep the new code
   for any reference to an admin role in the mobile client) — admin has no mobile login surface
   per §8.3 and this phase should not have introduced one.
10. Full regression smoke test against Phases 0–3 — any regressions?

OUTPUT FORMAT — same structure as prior phases.
```

---

## Phase 5 — Convenience Layer

**Purpose:** polish pass once functional parity (Phases 1–4) is stable — widgets, quick actions, rich notifications, voice quick-capture.

### Phase 5 — Implementation Prompt

```
You are implementing Phase 5 (Convenience Layer) of the Operion Mobile S-Grade Blueprint.
Phases 0–4 must already be complete and verified — this phase adds mobile-native convenience on
top of a functionally complete app, it does not add any new business capability. Read section 9
in full before starting.

Implement, in this order (each is independent, no cross-dependencies, but do them in this order
so simpler items are proven working before the more complex voice-capture integration):

1. HOME-SCREEN WIDGETS (home_widget package):
   - iOS WidgetKit + Android App Widget: "Today's KPIs" widget for dispatcher/manager
     (revenue-to-date, active jobs count, alerts count) and "Next stop / active trip" widget
     for driver role.
   - Background refresh cadence: 15 minutes, plus push-triggered refresh on relevant backend
     events (new alert, job status change) via a silent push payload the widget listens for.
   - Test on both a real/simulated iOS and Android device — widget behavior is notoriously
     platform-specific and hard to fully unit test; a manual verification pass is expected here
     and should be documented, not skipped in favor of only automated tests.

2. QUICK ACTIONS / APP ICON SHORTCUTS (QuickActions plugin):
   - "Approve pending jobs" -> deep-links to /dispatcher/ops/jobs with a pending filter applied
   - "New alert check" -> deep-links to the alerts screen
   - "Scan document" -> deep-links directly into the document camera capture flow, bypassing
     the Document Center list screen entirely

3. RICH PUSH NOTIFICATIONS WITH INLINE ACTIONS:
   - Extend the existing push notification handling to attach Approve/Snooze/View actions
     (Android NotificationCompat.Action / iOS UNNotificationAction) to alert-type notifications.
   - Wire each inline action to call the SAME mutation functions the in-app Alert screen uses
     (do not create a parallel action-handling code path) — background execution must handle
     the case where the app is fully closed (not just backgrounded).

4. VOICE-FIRST QUICK CAPTURE:
   - Add a new Copilot intent, RecordMaintenanceIntent, that recognizes a spoken/typed phrase
     matching the pattern "record maintenance on <truck>, <category>, <cost>" (reuse the
     existing Copilot NLU pipeline, do not build a separate parser) and routes to pre-filling
     features/maintenance/widgets/record_work_sheet.dart for one-tap confirm.
   - Confirm this calls the EXACT SAME fleetMutationProvider.recordMaintenance() function used
     by the manual form (Phase 3) and the Truck Detail quick-action (Phase 1) — there must be
     exactly one code path for this mutation regardless of entry point; verify this by code
     inspection, not just behavioral testing.

5. TABLET LAYOUT COMPLETION:
   - Phase 2 introduced the ≥600dp master-detail breakpoint for Records/More. Extend the same
     breakpoint treatment to any screens from Phases 1, 3, 4 that were built before this pattern
     existed (Fleet, Drivers, Clients, Invoicing, Team Management, Settings) so the tablet
     experience is consistent across the entire app, not just the Phase 2 screens.

6. ONE-HANDED REACHABILITY AUDIT:
   - Go through every screen added in Phases 1–4 and confirm the primary action (FAB, primary
     button) sits in the bottom two-thirds of the screen per §9 — this is a design audit, not a
     new feature; fix any screen found to violate this by relocating the primary action.

7. DARK MODE GOLDEN TEST SWEEP:
   - Confirm every screen added across Phases 1–4 has a dark-mode golden test (some phases may
     have only tested light mode under time pressure) — fill any gaps found.

TESTS:
   - Widget tests for QuickActions deep-link routing and inline-notification-action handling
     (mock the OS-level triggers, assert the correct provider/mutation function is invoked).
   - A specific test confirming RecordMaintenanceIntent and the manual maintenance form both
     resolve to the identical function reference (not just equivalent behavior).
   - Golden test gap-fill from item 7 above.
   - Manual device-matrix pass (per §13.6) specifically exercising widgets, quick actions, and
     notification actions on real devices, since these are OS-integration features that are
     inherently harder to fully automate.

STOP CONDITION: Once all 7 items above are implemented and the manual device-matrix pass for
this phase is documented, STOP and report:
  - Confirmation that RecordMaintenanceIntent resolves to the exact same function as the manual
    form (with the specific evidence, e.g. a shared reference/import)
  - Results of the manual widget/quick-action/notification device pass
  - Any screen found and fixed during the reachability audit (item 6) and the dark-mode gap-fill
    (item 7)
  - Do NOT start Phase 6 (Full-System Release QA) — that is a separate, dedicated pass.
```

### Phase 5 — Verification Prompt

```
You are verifying Phase 5 (Convenience Layer) of the Operion Mobile S-Grade Blueprint.
Read §9 and §13.6.

Check and report PASS / FAIL / PARTIAL with evidence:

1. Do the home-screen widgets (iOS + Android) actually display live data, and does the data
   refresh on the documented cadence and on push-triggered events (test by triggering a real
   backend event and observing the widget update)?
2. Do all 3 app icon quick actions deep-link to the correct screen/state (pending-filtered jobs,
   alerts, document camera capture) bypassing intermediate screens as specified?
3. Trigger a real alert-type push notification with the app fully closed (not backgrounded) —
   do the inline Approve/Snooze/View actions actually work, and do they call the same mutation
   functions as the in-app flow (verify by checking resulting state matches what the in-app flow
   would produce)?
4. Test the voice/typed RecordMaintenanceIntent phrase end-to-end — does it correctly parse a
   truck identifier, category, and cost, and does the resulting form pre-fill match, and does
   confirming it call fleetMutationProvider.recordMaintenance() (confirm via code inspection
   that this is literally the same function reference used elsewhere, not a lookalike copy)?
5. Spot-check the tablet master-detail layout on Fleet, Invoicing, and Team Management screens
   (representative sample from Phases 1/3/4) at ≥600dp — is the breakpoint treatment actually
   present and consistent with the Phase 2 screens' implementation?
6. Spot-check 5 screens from across Phases 1–4 for the one-handed reachability rule (primary
   action in bottom two-thirds) — any violations?
7. Confirm dark-mode golden tests now exist for every screen added in Phases 1–4 (cross-check
   file listing against the full screen inventory in §2's Feature Parity Matrix).
8. Full regression smoke test against Phases 0–4 — any regressions, especially around background
   task / push notification handling interfering with existing driver-role GPS background
   tracking?

OUTPUT FORMAT — same structure as prior phases.
```

---

## Phase 6 — Full-System Release QA

**Purpose:** the final, holistic pass before this blueprint's Master Definition of Done (§14) is declared met — not a phase that writes new code, a phase that proves the whole system together.

### Phase 6 — Verification-Only Prompt (no implementation prompt — this phase is pure QA)

```
You are conducting Phase 6 (Full-System Release QA) of the Operion Mobile S-Grade Blueprint —
the final gate before declaring the Master Definition of Done (§14) met. This phase does not add
new code except to fix any defect this pass uncovers. Read §14 in full, plus §13 end to end,
before starting.

Execute, in order:

1. FULL TEST SUITE RUN: run every backend/tests/mobile/*.py file and every
   mobile_app/test/features/*/**.dart file together (not per-phase in isolation) — report the
   total counts (unit/widget/golden/integration/backend-contract) and confirm they meet or
   exceed the targets in §13.1 (~180+ unit, ~90+ widget, ~35+ integration, 1:1 backend contract
   coverage per endpoint).

2. RBAC FIXTURE SUITE: run the complete permission_matrix.json-driven suite (both backend and
   mobile sides) covering every permission introduced across all 6 phases — this must be 100%
   green with zero exceptions, per §13.4's "blocking, not a nightly job" standard.

3. FINANCIAL PARITY SUITE: run the complete invoice_calculations.json-driven suite on both sides
   of the wire — must be 100% green per §13.3.

4. OFFLINE/SYNC REGRESSION SUITE: run the complete extended suite covering every mutation type
   from every phase's §7 table entries, plus execute the airplane-mode manual script
   (docs/qa/airplane_mode_script.md) end-to-end across Fleet/Drivers/Clients/Invoicing.

5. DEVICE & PLATFORM MATRIX: execute the full manual pass from §13.6 across the entire device/
   OS/network/locale/accessibility matrix — every checkbox, not a sample.

6. FEATURE PARITY MATRIX AUDIT: go through EVERY row of §2's table one at a time and confirm
   each is genuinely shipped and functional (not just "a screen exists" — actually exercise the
   core action of each row), with the single documented exception of Migration Center. Any row
   found incomplete is a BLOCKING finding, full stop, regardless of which phase was supposed to
   have delivered it.

7. CRASH-FREE SESSION RATE: pull the actual crash-reporting dashboard data from the
   release-candidate beta (family-member test fleet, per Gigi's stated plan) and confirm
   ≥99.5% crash-free sessions over a meaningful sample period, not a single day.

8. SECURITY RE-CHECK: re-verify every item in §12 (biometric step-up on all 5 specified actions,
   no client-side secret caching, screen-capture prevention on the 2 specified screens, 24-hour
   action-queue TTL enforcement, device-deregistration cascade) as a single consolidated pass —
   these were tested per-phase already, but re-verify them together since cross-phase
   interactions (e.g., does biometric-gated invoice submission still work correctly after the
   Phase 5 background task changes?) are exactly the kind of regression a per-phase pass alone
   cannot catch.

9. DOCUMENTATION RECONCILIATION: compare this blueprint document against the actual final
   codebase for every place where an implementation prompt's stop-condition report noted a
   discrepancy between the documented spec and the real desktop source of truth (permission
   names, thresholds, formulas, package choices). Confirm this document has been updated to
   match reality per §14 item 10 — if it hasn't, that is itself a blocking finding, since an
   inaccurate blueprint undermines future maintenance.

OUTPUT FORMAT:

## Phase 6 — Full-System Release QA Report

### Master Definition of Done — Item-by-Item (§14, items 1–10)
| Item | Status | Evidence |
|---|---|---|
| 1. Feature Parity Matrix shipped | ... | ... |
...(all 10 items)...

### Test Suite Totals
(actual counts vs §13.1 targets)

### Blocking Findings
(anything that must be fixed before public launch — list explicitly, with the phase it
originated in if identifiable)

### Non-Blocking Notes

### FINAL VERDICT
"MASTER DEFINITION OF DONE: MET — READY FOR FAMILY-FLEET BETA" or
"MASTER DEFINITION OF DONE: NOT MET — [N] BLOCKING FINDINGS REMAIN"
```

---

> **End of Blueprint (V2)**
>
> This is a living reference. Every implementation prompt in Part 2 explicitly requires the
> executing agent to report back any discrepancy it finds between this document and the real
> desktop codebase (permission names, thresholds, formulas, package availability). Those reports
> must be folded back into this document — via direct edits to the relevant Part 1 section — as
> each phase completes, so that by Phase 6 this document and the shipped app are in full
> agreement. Cross-check against `OPERION_BLUEPRINT.md` (the master system blueprint) throughout,
> since the desktop's actual schema, permission matrix, and service code are authoritative over
> anything written here.

---

# Appendix A — Implementation-Time Adaptations Registry (Phases 0–6, 2026-08-03)

Per §14 item 10 and §15 ("the real code wins"), every discrepancy found between this document and
the shipped implementation during Phases 0–6 is recorded here. Where a Part 1 section contradicts
this registry, the registry reflects the real shipped behavior.

## Repository layout
- `mobile_app/` in this document = `mobile/` in the `operion-mobile-app` repo.
- `backend/`, `shared/test_vectors/`, desktop `ui/`, `scripts/`, `tests/` = the SEPARATE
  `Calculator logistica` repo. Two independent git repos + two independent CIs.
- `shared/test_vectors/` is canonical in the backend repo; `mobile/test/test_vectors/` holds a
  vendored copy (byte-identical, verified by SHA-256 in Phase-6 QA).

## Phase 0 — Foundations
- **Permission model:** the desktop has NO `Permission` enum and NO `require()` method.
  `PermissionService` exposes `can_*` methods returning `PermissionCheckResult`; handlers gate
  mutations imperatively (`PermissionService(db).can_X(user_id)` → 403). Reads gate via
  `require_dispatcher`/`require_manager` dependencies. `permission_matrix.json` is keyed on real
  `can_*` method names (136 pairs: 34 permissions × 4 roles, generated by
  `scripts/export_permission_matrix.py`).
- **Invoice calculation (§4.5):** the real desktop calc (`services/invoicing/service.py:66-112`)
  differs from the documented formula: it rounds at EVERY intermediate step with Python
  `round(x,2)` (banker's rounding, ties-to-even on the exact binary double), treats `qty 0/None`
  as 1.0, caps discount at gross, honors pre-set `taxable/vat/line_total` fields, and sums
  sequentially. The mobile calc core (`invoice_calculation.dart`) replicates this EXACTLY —
  `decimal`/HALF_UP is NOT used for the calculation (only for display/formatting). Ground truth =
  `shared/test_vectors/invoice_calculations.json` (29 vectors, byte-identical both sides).
- **Crash reporting:** Sentry (`sentry_flutter`) chosen — nothing configured anywhere; self-hosted
  alignment (no-DSN no-op guard).
- **PDF viewer:** `pdfx` chosen over `syncfusion_flutter_pdfviewer` (BSD-3 vs commercial license;
  ADR in `mobile/lib/features/invoicing/README.md`).
- **Sync/queue enums:** `SyncEntityType`/`QueuedActionType` did not exist — created per §5 in
  `core/sync/sync_cursors.dart` + `core/sync/action_queue.dart` (purely additive; the queue
  remains string-typed).
- **permissionProvider:** no live permissions endpoint exists; the provider derives permissions
  from the authenticated role via a fixture-derived matrix mirror (fixture = tests only).

## Phase 1 — Records Core
- **`can_merge_clients` = ADMIN-ONLY** in the real backend (delegates to `can_delete_client`);
  §8.3's "manager+" does not hold — manager gets 403. REAL WINS.
- **`can_schedule_maintenance` = admin+manager** (dispatcher 403) — §8.3 row "dispatcher ✓" does
  not hold. REAL WINS.
- **TruckStatus:** no enum — real status strings `'Active'/'In Service'/'Inactive'`; mobile
  `TruckStatus` maps them.
- **Client merge contract:** multi-source `{target_id, source_ids}` with dialect-aware locking
  (SQLite `BEGIN IMMEDIATE` / PostgreSQL `SELECT … FOR UPDATE`), in-lock re-validation, single
  transaction. Desktop merge is single-source `{from_id, to_id}`.
- **Records tab (§3):** implemented as the 5th bottom-nav tab; Teams tile moved from More to
  Records.
- **Driver-expiry threshold:** 30 days (real constant `driver_repository.get_expiring_licenses`
  default). Maintenance records table already existed
  (`maintenance_type`→category, `service_provider`→vendor).

## Phase 2 — Analytics, History & Global Search
- **§6.11 search infrastructure does not exist for the new entities:** no FTS/pgvector for
  trips/clients/drivers/trucks (documents alone have SQLite FTS5). Global search is
  dialect-safe `LIKE … ESCAPE '\'`; documents use `fts_search` + LIKE fallback. §6.11's "reuse
  existing FTS/pgvector" was adapted accordingly.
- **Analytics payloads are genuinely mobile-shaped:** measured 102–895 B per endpoint (asserted
  <50 KB) — a real aggregation layer, not a Plotly proxy.
- **Analytics export:** synchronous CSV + 10-minute signed token (no Celery needed). History
  export: Celery jobs via the `export_jobs` table (`kind='trips_export'`).
- **`page_size` bound = `le=200`** (repo-wide desktop convention) vs §6 preamble's `le=100`.
- **No driver rating column exists** — the Driver Performance table shows trips/OTD%/profit-per-km/
  revenue instead of "avg rating".
- **Invoice aging buckets** come from `get_invoice_aging` (4 real buckets); Phase-6 updated the
  filter to `LOWER(status) NOT IN ('paid','cancelled')` so new-machine invoices count.
- **Tablet master-detail (§9)** implemented for Records/More (Phase 2), extended to 8 more
  screens in Phase 5.

## Phase 3 — Finance
- **Invoice status machine:** the desktop's REAL machine uses underscore strings
  (`draft/finalized/xml_generated/paid/cancelled`); §4.5's camelCase names (`xmlGenerated` etc.)
  map to these. **Gate-33 (2026-08-06) — ANAF submission chain REMOVED by business decision:**
  the machine is now `draft→[finalized,cancelled]`, `finalized→[xml_generated,cancelled,paid]`,
  `xml_generated→[paid,draft]`, `paid/cancelled` terminal — the submission states
  (submitted_externally/queued/submitting/accepted/rejected/manual_review) no longer exist
  anywhere; `submit` → permanent 422 `action_not_supported`; the `ENABLE_ANAF_SUBMISSION` flag
  and the EFAC- id are gone; `efactura_status` + `efactura_xml_path` are kept (the UBL CIUS-RO
  XML file is the legal deliverable); mobile parses legacy submission strings defensively
  (`_legacyStatusMap`). The old `can_submit_invoice` mapping (§8.4) is no longer relevant.
- **Invoice PDF:** served via `InvoiceGenerator` (`services/invoicing/generator.py`).
- **CMR:** implemented with the pydantic `CmrGenerateRequest` API + additive `sig_sender_path`
  (signature PNG persisted as a document, entity_type='cmr'); a pre-existing double sequence-
  allocation defect in `CMRGenerator` was fixed (response number == PDF number == trip row).
- **Biometric gate (§12):** `requireBiometricConfirmation()` — `biometricOnly:false` (PIN
  fallback) + 5-minute grace; wired INSIDE the mutation notifiers (API unreachable without a
  successful check). Capture prevention: Android FLAG_SECURE (Phase 5 replaced the abandoned
  `flutter_windowmanager` with an equivalent local MethodChannel), iOS blur overlay via the
  `app_security` channel.
- **Illegal transitions** → 422 + machine-readable `error_code` (never 500).

## Phase 4 — Configuration & Admin
- **Three permissions ADDED to the real PermissionService** (they did not exist):
  `can_manage_users`, `can_view_company_settings`, `can_manage_company_settings` (admin+manager);
  `permission_matrix.json` regenerated (136 pairs).
- **Team invite:** server-side role ∈ {dispatcher, manager}; manager→admin = 422
  `role_not_allowed` (endpoint logic, direct-API tested). No invite-email infra exists — users
  get a temporary bcrypt password.
- **Deactivation cascade:** one transaction — `is_active=0` + `mobile_devices` DELETE +
  `auth_sessions` DELETE + refresh-token sweep (the token store payload carries EMAIL, not
  user_id — revocation is by email; `users.email` is globally unique so this is safe).
  `get_current_user` already checked `is_active` (401 after deactivation — tested with a real
  JWT).
- **Company settings:** write-only secrets (encrypted via `PreferencesManager._SENSITIVE_KEYS`);
  company identity fields stored as tenant-scoped settings keys (the desktop's
  `company_config.json` is a single global file — not multi-tenant-safe for the API).
- **Tachograph:** NO native `.ddd` parser exists — the real pipeline shells out to the external
  `tachograph.exe` (tachoparser binary, present locally); **`TachoComplianceEngine` does not
  exist** — the weekly limit constant is `EU_MAX_WEEKLY_DRIVING_MINUTES = 3360`
  (`services/tacho_service.py:54`). Import runs as a Celery job (`export_jobs` kind
  `'tacho_import'`); a missing binary yields an honest error status.
- **DB layer hardening:** a pre-existing WAL write-lock leak (failed DML leaving an implicit
  transaction open) was fixed at the source (`_rollback_if_implicit` in repositories + db_manager)
  with regression guards — it had surfaced as an indefinite RBAC-matrix-test deadlock.

## Phase 5 — Convenience
- **`record_maintenance` copilot tool added** (backend): params `truck_id|plate_number/category/
  cost/notes/date`; `required_permission=can_schedule_maintenance` (dispatcher excluded);
  `confirmation_level=2`. The mobile side intercepts the step and executes via the SHARED
  `submitRecordMaintenance` function (Dart `identical()` proof) — no server-side execution.
- **No FCM sender exists in the backend** — alert payloads are data-only by nature
  (AlertManager → EventBus → NotificationCenter → subscribers + SMTP for critical). Rich inline
  actions (Approve/Snooze/View) display via `flutter_local_notifications`; background/terminated
  actions persist and execute on the next authenticated launch (headless isolates cannot access
  secure storage).
- **Home widgets:** Android AppWidgets + iOS WidgetKit (home_widget data-push); 15-min
  main-isolate refresh + push-triggered + event-triggered; terminated = last-known data.
- **Copilot test hygiene:** 21 translation BOMs stripped; circuit-breaker class-level state leak
  fixed with an autouse fixture; `guided_overlay_widget` Qt timer-on-deleted-object crash fixed
  (member timers + `hideEvent`).

## Phase 6 — Release QA
- **Biometric step-up COMPLETED on all five §12 actions** (client merge, user deactivation, and
  company-settings save were added in 6B, joining invoice transitions + CMR).
- **24-hour action-queue TTL implemented** (`kActionQueueTtl`, `staleCount` on queue state;
  stale actions are surfaced, not auto-replayed).
- **§13.1 integration target:** 34 testWidgets (14 → 34) — **EXECUTED 34/34 GREEN** on Windows
  (per-file; the pre-existing Firebase C++ prebuilt-SDK vs MSVC 17.14 link failure was resolved via
  a semantics-equivalent STL compat shim + the firebase_core 4.13.0 / firebase_messaging 16.5.0
  upgrade; flutter_tools' multi-file single-invocation limitation on Windows is documented).
- **§2 rows 1/3/5/7/11 — IMPLEMENTED in the pending-items follow-up (2026-08-03):** overview profit
  sparkline + activity feed (revenue_trend + recent_activity added to the dispatcher overview); Route
  Planner truck-profile selector (truck/car/foot — backend whitelist verified) + country-exclusion
  chips (EU-27 → `excluded_countries` on /routes/calculate, wired to the real exclusion-APPLY path);
  Dispatch Board Kanban (4 columns: Planned/Loading/In Transit/Delivered, drag-drop with 4-second
  Undo snackbar → PATCH /mobile/transports/{id}/status) + Timeline (per-truck Gantt from the
  newly-added start/end dates + `statuses` param on the jobs endpoint); Freight saved searches
  (list/save/refresh — no DELETE endpoint exists, flagged) + advanced search (POST /freight/search)
  + evaluate (GET /freight/loads/{pid}/{lid}/evaluate → profitability/risk card); Documents FTS5
  search (400ms debounce → query param) + category chips (new GET /documents/categories) + version
  browsing (GET /documents/{id}/read versions; no read/stream endpoint exists for previews —
  documented). **Row 16 (Route History thumbnail) — IMPLEMENTED (2026-08-03):** new
  `GET /mobile/history/routes/{route_id}/thumbnail` endpoint (zlib-decode of the stored
  `geometry_compressed` → Pillow schematic polyline PNG, 320×180, company-scoped, degenerate-safe,
  404 for missing/cross-company/no-geometry/undecodable) + mobile 120×68 `Image.network` rendering
  with error/loading fallback to the route-icon placeholder.
- **Device/QA-pending items (honest, §13.6):** device-matrix manual pass (widgets, quick actions,
  notification inline actions), airplane-mode manual script execution, crash-free-session-rate
  from the release-candidate beta. Documentation: `docs/convenience-device-pass.md` +
  `docs/qa/airplane_mode_script.md`.
