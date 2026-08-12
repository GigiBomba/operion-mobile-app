# Operion Mobile — Multi-Phase Implementation Plan

**Status:** Ready for execution. Phase 0 begins after remaining tech decisions are signed off.
**Source documents:** `Mobile_App_Plan.md` (master blueprint), `Stack.md` (tech decisions), `Operion.md` (project context)
**Version:** 1.0

---

## Technology Decisions — Resolved & Pending

Per `Stack.md`, the following are **locked**:

| Decision | Choice | Source |
|----------|--------|--------|
| Cross-platform framework | **Flutter** | Stack.md |
| Language | **Dart** | Stack.md |
| Networking | **Dio** | Stack.md |
| Mapping | **Flutter Map** (vector tiles) or Google Maps Flutter | Stack.md |
| Local cache DB | **Isar** or **Hive** | Stack.md |
| State management | **Bloc** or **Riverpod** | Stack.md |
| Icons | **Lucide Icons Flutter** | Stack.md |

Still **pending Gigi's sign-off** (from Mobile_App_Plan.md §24):

1. ~~Cross-platform framework~~ — resolved: Flutter
2. Real-time transport mechanism: **WebSocket vs. SSE** — pending
3. Push notification provider: **FCM/APNs direct vs. existing dev toolkit** — pending
4. Dual-role mode switching in V1 — pending (deferred per plan)
5. "Ask Operion" interaction pattern — deferred until AI Co-Pilot desktop model solidifies
6. Tachograph driver-facing actions on mobile — pending

**Action before Phase 0 starts:** Resolve items 2–3 above. Item 2 defaults to **WebSocket** (bidirectional messaging + live tracking; check for existing backend WS infra). Item 3 defaults to **FCM/APNs direct** unless existing observability tooling already brokers push.

---

## Phase 0 — Foundations (No User-Facing Screens)

**Duration estimate:** 2–3 weeks
**Goal:** Standing infrastructure. No feature screens yet — every later phase builds on this.

### 0.1 — Project Scaffold

| # | Task | Deliverable | Dependencies |
|---|------|-------------|--------------|
| 0.1.1 | `flutter create operion_mobile` with proper org/package name | Flutter project with `android/`, `ios/`, `lib/` | None |
| 0.1.2 | Establish folder structure: `lib/` → `core/`, `features/`, `shared/`, `l10n/` | Clean module boundary | 0.1.1 |
| 0.1.3 | Set up analysis_options.yaml (strict linting, matching Dart/Flutter best practices) | Lint config | 0.1.1 |
| 0.1.4 | Configure flavors: `dev`, `staging`, `prod` (different API base URLs, feature flags) | Flavor config in android + ios | 0.1.1 |
| 0.1.5 | Set up CI pipeline (GitHub Actions or equivalent): lint → test → build | Green CI | 0.1.1 |

### 0.2 — Design Tokens & Theming

| # | Task | Deliverable | Dependencies |
|---|------|-------------|--------------|
| 0.2.1 | Translate existing design tokens (`design_tokens.py` from desktop) into Dart `ThemeData` | `core/theme/app_theme.dart` with `indigo #6366F1` primary, Inter font, light/dark | 0.1.2 |
| 0.2.2 | Build reusable widget primitives: `AppButton`, `AppCard`, `AppTextField`, `AppChip` styled from tokens | `shared/widgets/` | 0.2.1 |
| 0.2.3 | Create mode-specific theme variants (Driver: large targets, high contrast; Dispatcher: denser) | Theme extensions | 0.2.1 |

### 0.3 — Internationalization

| # | Task | Deliverable | Dependencies |
|---|------|-------------|--------------|
| 0.3.1 | Set up Flutter `flutter_localizations` + ARB files for `ro` (Romanian) and `en` (English) | `l10n/app_ro.arb`, `l10n/app_en.arb` | 0.1.2 |
| 0.3.2 | Implement `t()`-style wrapper (mirror desktop convention) for string lookups | `core/i18n/` | 0.3.1 |
| 0.3.3 | Populate initial strings: auth, errors, offline status, common actions | ARB files with initial keys | 0.3.2 |

### 0.4 — Networking Layer

| # | Task | Deliverable | Dependencies |
|---|------|-------------|--------------|
| 0.4.1 | Configure Dio instance with base URL (from flavor), timeouts, JSON interceptor | `core/network/api_client.dart` | 0.1.4 |
| 0.4.2 | Implement auth interceptor: attach JWT access token, handle 401 → attempt refresh → retry → force logout on double failure | `core/network/auth_interceptor.dart` | 0.4.1 |
| 0.4.3 | Shared API type definitions (Dart models) for core entities: `Transport`, `Driver`, `Vehicle`, `Document`, `Message`, `Alert` | `shared/models/` | 0.4.1 |
| 0.4.4 | Generate API client from FastAPI OpenAPI spec (or hand-write thin Dio wrappers per endpoint category) | `core/network/endpoints/` | 0.4.2, 0.4.3 |

### 0.5 — Authentication

| # | Task | Deliverable | Dependencies |
|---|------|-------------|--------------|
| 0.5.1 | Login screen: email + password (reuse backend identity), error states | `features/auth/login_screen.dart` | 0.2.2, 0.4.2 |
| 0.5.2 | Secure token storage: refresh token in platform keystore (flutter_secure_storage) | `core/auth/token_store.dart` | 0.1.2 |
| 0.5.3 | Biometric unlock: local auth (fingerprint/Face ID) gating stored refresh token; no bypass of backend session | `core/auth/biometric_gate.dart` | 0.5.2 |
| 0.5.4 | Session restore flow: check stored token → validate with backend → route to mode shell | `core/auth/session_restore.dart` | 0.5.2, 0.4.2 |
| 0.5.5 | Role resolution on login: backend returns role → app routes to Driver or Dispatcher shell | `core/auth/role_resolver.dart` | 0.5.1 |
| 0.5.6 | Forced logout handling: detect 403/session-revoked → clear tokens → show login | Auth interceptor extension | 0.4.2 |
| 0.5.7 | Device registration on login (POST `/mobile/devices/register`) for push targeting | `core/notifications/device_registration.dart` | 0.4.2 |

### 0.6 — Sync & Offline Infrastructure

| # | Task | Deliverable | Dependencies |
|---|------|-------------|--------------|
| 0.6.1 | Decision: Isar vs. Hive — pick one, create local DB abstraction | `core/storage/local_db.dart` — repo layer wrapping chosen DB | None (do first) |
| 0.6.2 | Implement delta-sync client: `GET /mobile/sync?since=<cursor>` → merge into local cache, update cursor | `core/sync/delta_sync_service.dart` | 0.6.1, 0.4.2 |
| 0.6.3 | Implement offline action queue: enqueue with idempotency key, serialize to local DB, replay on connectivity | `core/sync/action_queue.dart` | 0.6.1 |
| 0.6.4 | Connectivity monitor (connectivity_plus): detect online/offline → trigger queue replay, update UI banner | `core/sync/connectivity_monitor.dart` | 0.6.3 |
| 0.6.5 | Staleness labeling: cached data always shows "last updated X min ago" / "pending sync" badge | `shared/widgets/staleness_indicator.dart` | 0.6.2 |
| 0.6.6 | Conflict handling: server-wins; rejected queued action → user sees specific failure message (not silent) | `core/sync/conflict_handler.dart` | 0.6.3 |

### 0.7 — Real-Time Transport

| # | Task | Deliverable | Dependencies |
|---|------|-------------|--------------|
| 0.7.1 | Decision: WebSocket vs. SSE — **default to WebSocket** (bidirectional messaging + live tracking) | Decision record in this doc | Pending sign-off |
| 0.7.2 | WebSocket client: connect, reconnect with exponential backoff, heartbeat/ping | `core/network/websocket_client.dart` | 0.7.1 |
| 0.7.3 | Message bus: internal pub/sub for real-time events (new message, status change, live position update) consumed by Bloc/Riverpod | `core/network/message_bus.dart` | 0.7.2 |

### 0.8 — Push Notifications

| # | Task | Deliverable | Dependencies |
|---|------|-------------|--------------|
| 0.8.1 | Decision: FCM/APNs direct vs. existing dev toolkit — **default to FCM/APNs direct** | Decision record | Pending sign-off |
| 0.8.2 | Integrate firebase_messaging (FCM) + APNs setup | Platform config + `core/notifications/push_service.dart` | 0.8.1 |
| 0.8.3 | Notification tap routing: tap push → open relevant screen (message → chat, alert → alert detail, etc.) | `core/notifications/notification_router.dart` | 0.8.2 |
| 0.8.4 | In-app notification center: persistent list, separate from push interruptions | `features/notifications/` (skeleton, flesh out in Phase 1) | 0.8.3 |

### 0.9 — Navigation Shell & Mode Routing

| # | Task | Deliverable | Dependencies |
|---|------|-------------|--------------|
| 0.9.1 | Auth gate widget: checks session state → login or mode shell | `core/auth/auth_gate.dart` | 0.5.4, 0.5.5 |
| 0.9.2 | Driver Mode shell: bottom nav (4–5 items: Home, Transports, Messages, Notifications, Profile) with nested Navigator per tab | `features/driver/driver_shell.dart` | 0.5.5 |
| 0.9.3 | Dispatcher Mode shell: bottom nav (Home, Fleet Map, Jobs, Alerts, Messages/Profile) — structurally separate from Driver shell | `features/dispatcher/dispatcher_shell.dart` | 0.5.5 |
| 0.9.4 | Settings/Profile screen (both modes): logout, app version, language toggle | `features/settings/` | 0.9.2, 0.9.3 |

### Phase 0 Verification Gate

- [ ] App launches → shows login screen
- [ ] Login with backend credentials succeeds → tokens stored → routed to correct mode shell
- [ ] Token refresh works transparently
- [ ] Force logout (simulate revoked token) → back to login
- [ ] Biometric unlock gates session restore
- [ ] Offline queue: enqueue action offline → reconnect → action replays
- [ ] Delta sync: fetch → cursor advances → subsequent sync returns only changes
- [ ] Connectivity banner appears/disappears correctly
- [ ] Push notification received → tap opens correct screen
- [ ] WebSocket connects → receives message → updates UI
- [ ] Theme (indigo, Inter, light/dark) renders on both platforms
- [ ] All strings render in ro + en

---

## Phase 1 — Driver Mode MVP

**Duration estimate:** 3–4 weeks
**Goal:** Drivers can do their entire daily workflow without paper or desktop.

**Backend prerequisites** (parallel track — coordinate with backend dev):
- `GET /mobile/driver/my-day` — aggregate endpoint (transports + status + alerts + unread count)
- `GET /mobile/driver/transports` — assigned transports list
- `GET /mobile/driver/transports/{id}` — transport detail
- `PATCH /mobile/transports/{id}/status` — status update (wrapper over existing transport service)
- `POST /mobile/documents/upload` — multipart, resumable upload → feeds existing document service + OCR pipeline
- `GET /mobile/driver/vehicle` — assigned vehicle info
- `GET /mobile/messages` — driver-scoped messages
- `POST /mobile/messages` — send message
- `GET /mobile/driver/notifications` — notification history
- Push notification dispatch from backend events (new assignment, new message, schedule change)

### 1.1 — Driver Home ("My Day")

| # | Task | Deliverable |
|---|------|-------------|
| 1.1.1 | Fetch and cache `GET /mobile/driver/my-day` on load; show offline-stale state | `features/driver/home/` |
| 1.1.2 | UI: today's transport count, next stop summary, unread message count, unread notifications, quick status actions | Driver home screen |
| 1.1.3 | Pull-to-refresh triggers delta sync; swipe-to-navigate patterns | Home interactions |
| 1.1.4 | Staleness indicator: shows last sync time; "pending sync" if offline | Reuse 0.6.5 widget |

### 1.2 — Assigned Transports

| # | Task | Deliverable |
|---|------|-------------|
| 1.2.1 | Transport list: card per transport showing load info, status chip, destination address | `features/driver/transports/transport_list.dart` |
| 1.2.2 | Transport detail screen: full load info, route waypoints, navigation hand-off button, status update section, related documents, related messages | `features/driver/transports/transport_detail.dart` |
| 1.2.3 | Navigation hand-off: one-tap deep-link to Google Maps/Waze/Apple Maps with destination coords | `core/utils/navigation_handoff.dart` |
| 1.2.4 | Empty state: "No transports assigned" with illustration | List empty widget |
| 1.2.5 | Loading state: shimmer/skeleton cards, not a blank screen | Shimmer placeholder |

### 1.3 — Status Update

| # | Task | Deliverable |
|---|------|-------------|
| 1.3.1 | Status change UI: large, tappable status buttons (departed, arrived, loading, delivered, delayed) — 1–2 taps max | `features/driver/transports/status_update.dart` |
| 1.3.2 | Offline: queue status update locally with idempotency key; show "pending sync" badge until confirmed | Reuse 0.6.3 action queue |
| 1.3.3 | Post-submit: optimistic UI update → server confirms or rejects (conflict: show specific error, not silent) | Reuse 0.6.6 |
| 1.3.4 | "Delayed" status: optional reason input (minimal: dropdown of common reasons + free text if needed) | Delay reason picker |

### 1.4 — Document Upload

| # | Task | Deliverable |
|---|------|-------------|
| 1.4.1 | Camera capture: open camera → take photo of CMR/POD/invoice → preview → confirm or retake | `features/driver/documents/camera_capture.dart` |
| 1.4.2 | Gallery pick: select existing photos as fallback | Gallery picker |
| 1.4.3 | Offline queue: save photo to device storage → queue upload with idempotency key → retry on reconnect | Reuse 0.6.3 |
| 1.4.4 | Resumable upload: `POST /mobile/documents/upload` (multipart) with chunked upload + resume capability over flaky connections | `core/network/resumable_uploader.dart` |
| 1.4.5 | Image compression before upload (configurable quality, max dimension) | `core/utils/image_compressor.dart` |
| 1.4.6 | Document list (cross-transport): all driver's uploaded documents with status (synced/pending/failed) | `features/driver/documents/document_list.dart` |
| 1.4.7 | Upload progress indicator: per-document progress bar + overall queue status | Upload queue UI |

### 1.5 — Vehicle Info

| # | Task | Deliverable |
|---|------|-------------|
| 1.5.1 | Vehicle detail screen: truck/trailer info, registration, documents, compliance status | `features/driver/vehicle/vehicle_detail.dart` |
| 1.5.2 | Document expiry warnings (ITP, RCA, etc.) surfaced inline with color coding | Document card with expiry badge |
| 1.5.3 | Offline cache: vehicle data cached locally, refreshed via delta sync | Cached vehicle data |

### 1.6 — Messaging

| # | Task | Deliverable |
|---|------|-------------|
| 1.6.1 | Message thread list: recent conversations with dispatchers | `features/driver/messages/message_list.dart` |
| 1.6.2 | Chat screen: message bubbles, timestamps, read status, send (text only MVP) | `features/driver/messages/chat_screen.dart` |
| 1.6.3 | Real-time: new messages arrive via WebSocket → update chat + badge count | WebSocket message bus (0.7.3) |
| 1.6.4 | Offline: queue outgoing messages → send on reconnect; show "sending"/"sent" states | Action queue |
| 1.6.5 | Push notification for new message → tap opens correct chat thread | Notification router (0.8.3) |

### 1.7 — Notifications (Driver)

| # | Task | Deliverable |
|---|------|-------------|
| 1.7.1 | Notification center screen: grouped by date, read/unread states, tap → navigate | `features/driver/notifications/` |
| 1.7.2 | Notification types: new assignment, schedule change, new message, document approval/rejection | Type-specific list items |
| 1.7.3 | Badge count on bottom nav icon | Notification badge |

### Phase 1 Verification Gate

- [ ] Login as driver → "My Day" loads with correct transports, counts
- [ ] Tap transport → detail with route, navigation hand-off works (opens Maps/Waze)
- [ ] Update status offline → goes to queue → reconnect → status updates on backend
- [ ] Capture document offline → photo saved → reconnect → uploads with progress
- [ ] Uploaded document appears in document list
- [ ] Send message offline → queues → sends on reconnect
- [ ] Receive push for new message → tap → opens correct chat
- [ ] Vehicle info shows assigned vehicle, document expiry warnings
- [ ] All flows work in Romanian and English
- [ ] All flows work on both Android and iOS

---

## Phase 2 — Dispatcher/Manager Mode MVP

**Duration estimate:** 3–4 weeks
**Goal:** Dispatchers and managers can monitor operations, receive alerts, and take quick actions from mobile.

**Backend prerequisites:**
- `GET /mobile/dispatcher/overview` — fleet counts, active job counts, open alerts aggregate
- `GET /mobile/dispatcher/fleet` — live fleet positions (read from existing tracking adapters)
- `GET /mobile/dispatcher/jobs` — active jobs/transports
- `GET /mobile/dispatcher/drivers` — driver list + status
- `GET /mobile/dispatcher/alerts` — alert inbox
- `POST /mobile/dispatcher/approvals/{id}/approve` — approve action (thin wrapper)
- `POST /mobile/dispatcher/approvals/{id}/reject` — reject action (thin wrapper)
- `GET /mobile/dispatcher/messages` — dispatcher-scoped messages

### 2.1 — Dispatcher Home

| # | Task | Deliverable |
|---|------|-------------|
| 2.1.1 | Fetch and cache `GET /mobile/dispatcher/overview` | `features/dispatcher/home/` |
| 2.1.2 | Dashboard cards: active drivers count, active jobs, open alerts, vehicles on road, today's totals (if analytics available) | Dashboard layout |
| 2.1.3 | Tap card → drill into relevant section | Navigation wiring |

### 2.2 — Live Fleet Map

| # | Task | Deliverable |
|---|------|-------------|
| 2.2.1 | Decision: Flutter Map (vector tiles) vs. Google Maps Flutter — **default to Flutter Map** (OSS, no API key dependency, vector tile support) | Decision record |
| 2.2.2 | Map widget: rendered in Flutter Map, vehicle markers with status-color coding (moving/stopped/idle/offline) | `features/dispatcher/fleet/fleet_map.dart` |
| 2.2.3 | Live position updates via WebSocket: vehicle markers move smoothly (no jump-cuts) | WebSocket message bus → map state |
| 2.2.4 | Tap marker → vehicle detail card (driver name, load info, last update time, contact shortcut) | `features/dispatcher/fleet/vehicle_detail_card.dart` |
| 2.2.5 | Map clustering for dense fleets (Flutter Map cluster plugin) | Marker clustering |
| 2.2.6 | Offline: show last-known positions, clearly labeled "as of X min ago" | Staleness indicator |

### 2.3 — Active Jobs / Transports

| # | Task | Deliverable |
|---|------|-------------|
| 2.3.1 | Job list: card per transport showing driver, route, status, last update time | `features/dispatcher/jobs/job_list.dart` |
| 2.3.2 | Filter/sort: by status, driver, route | Filter chips |
| 2.3.3 | Job detail: full info, status timeline, assigned driver, related documents, quick actions (reassign button, message driver) | `features/dispatcher/jobs/job_detail.dart` |
| 2.3.4 | Quick action: reassign transport → pick new driver from available list → confirm | Reassign flow |
| 2.3.5 | Quick action: message driver from job detail → opens chat | Deep-link to messaging |

### 2.4 — Drivers

| # | Task | Deliverable |
|---|------|-------------|
| 2.4.1 | Driver list: card per driver with status (available/driving/off), current load, last activity | `features/dispatcher/drivers/driver_list.dart` |
| 2.4.2 | Driver detail: full info, documents, current vehicle, current transport, contact | `features/dispatcher/drivers/driver_detail.dart` |
| 2.4.3 | Filter by status (available/driving/off) | Status filter |

### 2.5 — Alerts & Approvals

| # | Task | Deliverable |
|---|------|-------------|
| 2.5.1 | Alert inbox: grouped by type (delay, maintenance, document expiry, compliance), urgency color-coding | `features/dispatcher/alerts/alert_inbox.dart` |
| 2.5.2 | Approval list: pending approvals (expenses, documents, exceptions) with swipe-to-approve pattern | `features/dispatcher/alerts/approval_list.dart` |
| 2.5.3 | Approval detail: shows item details + approve/reject buttons with optional reason | `features/dispatcher/alerts/approval_detail.dart` |
| 2.5.4 | Push notification for new alert/approval → high priority → tap opens correct item | Notification router |

### 2.6 — Dispatcher Messaging

| # | Task | Deliverable |
|---|------|-------------|
| 2.6.1 | Message thread list: all driver conversations | `features/dispatcher/messages/` |
| 2.6.2 | Chat screen: reuse chat widget from Driver mode (same component, different data source) | Shared chat component |
| 2.6.3 | Contextual messaging: "message driver" from job detail → pre-filled context in chat | Deep-link with context |

### Phase 2 Verification Gate

- [ ] Login as dispatcher → home dashboard loads with correct counts
- [ ] Fleet map: vehicles appear at correct positions, update live via WebSocket
- [ ] Tap vehicle marker → detail card with driver/load info
- [ ] Active jobs list: filterable, drillable to detail
- [ ] Reassign transport → pick driver → confirm → job updates
- [ ] Alert inbox: alerts grouped, color-coded, tappable
- [ ] Approval: swipe right to approve → confirm → status changes
- [ ] Message driver from job detail → chat opens with correct thread
- [ ] Push notification for alert → tap → opens alert detail
- [ ] All flows respect `company_id` isolation (test: dispatcher from company A cannot see company B data)
- [ ] All flows work on both Android and iOS

---

## Phase 3 — Hardening & Verification Gate

**Duration estimate:** 1–2 weeks
**Goal:** Prove mobile endpoints and flows are secure, reliable, and tenant-isolated before MVP declaration. **This phase produces verification evidence, not self-reported completion.**

### 3.1 — Security Regression Suite

| # | Task | Deliverable |
|---|------|-------------|
| 3.1.1 | Add mobile-facing endpoints to existing `tests/security/` suite in backend repo | Security tests |
| 3.1.2 | Test: driver token cannot access dispatcher endpoints | Auth boundary test |
| 3.1.3 | Test: driver token cannot enumerate other drivers (company A driver accessing company B data) | Tenant isolation test |
| 3.1.4 | Test: dispatcher token cannot access admin/setup endpoints | Role boundary test |
| 3.1.5 | Test: document upload with invalid file types, oversized payloads, malformed multipart | Upload abuse test |
| 3.1.6 | Test: rate limiting on upload endpoints | Rate limit test |
| 3.1.7 | Test: forced session revocation → next API call returns 403 → tokens cleared | Session revocation test |
| 3.1.8 | All security tests CI-blocking (fail = no merge) | CI config |

### 3.2 — Offline Queue Reliability

| # | Task | Deliverable |
|---|------|-------------|
| 3.2.1 | Test: enqueue 10 actions offline → reconnect → all replay in order | Queue replay test |
| 3.2.2 | Test: enqueue action → token expires while offline → reconnect → refresh → action succeeds | Token refresh + queue test |
| 3.2.3 | Test: enqueue status update → transport reassigned while offline → replay rejected → user sees specific error | Conflict test |
| 3.2.4 | Test: document upload interrupted (kill app) → resume on relaunch → upload completes | Upload resume test |
| 3.2.5 | Test: connectivity flapping (on/off rapid cycle) → queue doesn't duplicate, UI doesn't crash | Connectivity stress test |

### 3.3 — Permission & Tenant Isolation

| # | Task | Deliverable |
|---|------|-------------|
| 3.3.1 | End-to-end test: driver login → "My Day" only shows own transports | Integration test |
| 3.3.2 | End-to-end test: dispatcher login → fleet map only shows own company vehicles | Integration test |
| 3.3.3 | End-to-end test: role upgrade/downgrade mid-session → UI reflects new permissions | Role change test |

### 3.4 — Cross-Platform Verification

| # | Task | Deliverable |
|---|------|-------------|
| 3.4.1 | Full smoke test on Android (physical device, not just emulator) | Test report |
| 3.4.2 | Full smoke test on iOS (physical device) | Test report |
| 3.4.3 | Test on poor network (3G simulation, packet loss 10%) — all offline features work | Network quality test |
| 3.4.4 | Test cold-start time, app size, memory usage | Performance baseline |

### Phase 3 Exit Criteria

- [ ] All security tests pass (CI-blocking)
- [ ] All offline queue tests pass
- [ ] All tenant isolation tests pass
- [ ] No crash on Android + iOS under simulated poor connectivity
- [ ] Verification evidence documented (failing-then-passing test logs, not prose claims)

---

## Phase 4 — Fast-Follow Features (Post-MVP, Pre-AI)

**Duration estimate:** 3–4 weeks
**Goal:** Complete the non-AI feature set for both modes.

### 4.1 — OCR-Assisted Document Capture (Driver)

| # | Task | Deliverable |
|---|------|-------------|
| 4.1.1 | After document upload, backend OCR pipeline processes → returns extracted fields | Backend: OCR endpoint |
| 4.1.2 | Mobile: after upload, poll/push OCR results → pre-fill document metadata (CMR number, dates, amounts) | `features/driver/documents/ocr_result_card.dart` |
| 4.1.3 | User confirms/corrects OCR suggestions → submits final metadata | OCR confirmation flow |
| 4.1.4 | Feedback loop: user corrections sent back to improve OCR (if pipeline supports it) | OCR feedback endpoint |

### 4.2 — Expenses (Driver)

| # | Task | Deliverable |
|---|------|-------------|
| 4.2.1 | New expense screen: type (fuel/tolls/per diem/other), amount, date, receipt photo capture | `features/driver/expenses/new_expense.dart` |
| 4.2.2 | Receipt OCR: capture receipt → OCR extracts amount/date/vendor → pre-fill form | Receipt OCR |
| 4.2.3 | Expense list: all driver expenses with status (submitted/approved/rejected) | `features/driver/expenses/expense_list.dart` |
| 4.2.4 | Offline: capture expense + photo offline → queue for submission | Action queue |

### 4.3 — Driver Profile (Driver)

| # | Task | Deliverable |
|---|------|-------------|
| 4.3.1 | Profile screen: personal info, documents (licenses, certifications), expiry tracking | `features/driver/profile/` |
| 4.3.2 | Document self-upload: driver uploads license/certification → backend flags for admin review | Profile document upload |
| 4.3.3 | Edit personal info fields (phone, emergency contact) | Profile edit |

### 4.4 — Condensed Analytics (Dispatcher)

| # | Task | Deliverable |
|---|------|-------------|
| 4.4.1 | Analytics home: summary cards — today's profit, active transports, fleet utilization, driver hours | `features/dispatcher/analytics/` |
| 4.4.2 | Category drill-in (Financiar, Flotă, Rute, Clienți, Șoferi, Documente) — **condensed summary only, not full desktop analytics** | `features/dispatcher/analytics/category_detail.dart` |
| 4.4.3 | Cached last-fetched snapshot, clearly timestamped "as of X min ago" | Staleness indicator |
| 4.4.4 | "Open in desktop for full analytics" prompt where data is truncated | Desktop hand-off CTA |

### 4.5 — Expanded Quick Actions (Dispatcher)

| # | Task | Deliverable |
|---|------|-------------|
| 4.5.1 | Basic transport create/edit (simplified form, not full desktop form) | `features/dispatcher/jobs/create_transport.dart` |
| 4.5.2 | "Open in desktop for advanced editing" CTA where fields are truncated | Desktop hand-off CTA |
| 4.5.3 | Multi-step approval chains (if backend supports multi-step workflows) | Approval flow extension |

---

## Phase 5 — Operion AI Integration (Post-MVP, AI-Gated)

**Duration estimate:** Ongoing, phased by AI backend tool coverage
**Goal:** Expose AI Co-Pilot through mobile as backend tool registry matures. No mobile release needed for most new AI features — only UI rendering improvements.

**Prerequisites:**
- AI Co-Pilot backend operational (Reasoning Graph, World Model, tool registry, execution state machine)
- `POST /ai/copilot/query` endpoint live (shared with desktop)
- Feature flag infrastructure on backend for tier-gated AI access

### 5.1 — "Ask Operion" Surface (Both Modes)

| # | Task | Deliverable |
|---|------|-------------|
| 5.1.1 | UI decision: persistent chat vs. command-palette — **defer until Co-Pilot desktop model solidifies** (per Mobile_App_Plan.md §17.3, §24) | — |
| 5.1.2 | Feature-flagged entry point: prominent position in bottom nav ("Ask Operion"), hidden if user's tier lacks AI access | `features/ai/ask_operion_entry.dart` |
| 5.1.3 | Chat/command surface: input (text + voice), conversation history, loading states, error states | `features/ai/chat_surface.dart` |
| 5.1.4 | Voice input (Driver Mode): reuse existing self-hosted Whisper STT architecture → mobile sends audio → backend transcribes → feeds into AI pipeline | `features/ai/voice_input.dart` |
| 5.1.5 | Structured response rendering: AI returns data → mobile renders as card/number/chart (not just plain text) | `features/ai/response_renderers/` |

### 5.2 — Confirmation & Safety (Both Modes)

| # | Task | Deliverable |
|---|------|-------------|
| 5.2.1 | Destructive/financial action confirmation: AI proposes action → mobile shows confirmation card with details → user explicitly confirms | `features/ai/confirmation_dialog.dart` |
| 5.2.2 | Required per Co-Pilot blueprint: proposed action → confirmation → execution → audit log entry → result display | Full confirmation flow |
| 5.2.3 | No "fire and forget" for high-impact actions from chat — mobile enforces confirmation step | Safety gate |

### 5.3 — Incremental Tool Rollout

Roll out AI capabilities incrementally as backend tool coverage grows. Each is a separate, verifiable increment (not one giant AI release):

| # | AI Capability | Mode | Backend Dependency |
|---|---------------|------|--------------------|
| 5.3.1 | "When is my next stop?" / "Who do I contact for this delivery?" | Driver | Transport service + contact data |
| 5.3.2 | "Reassign transport X to driver Y" | Dispatcher | Transport service + driver service |
| 5.3.3 | "Find another available truck for this load" | Dispatcher | Fleet service |
| 5.3.4 | "Generate invoice for transport X" | Dispatcher | Invoice generation service |
| 5.3.5 | "Show today's profit" | Dispatcher | Analytics service |
| 5.3.6 | "Why is delivery Y delayed?" | Dispatcher | Transport service + tracking adapters |
| 5.3.7 | "Search freight exchanges for a load matching Truck X" | Dispatcher | FreightProviderAdapter (TIMOCOM) |
| 5.3.8 | "Schedule maintenance for Vehicle V" | Dispatcher | Maintenance service |
| 5.3.9 | "Notify customer C about delivery ETA" | Dispatcher | Notification service |

### Phase 5 Exit Criteria (per increment)

- [ ] Feature flag correctly gates AI access by tier
- [ ] AI action executes as logged-in user (no elevated privilege)
- [ ] Destructive actions require explicit confirmation in mobile UI
- [ ] Tenant isolation applies to all AI tool calls
- [ ] Audit log entry created for every AI-executed action
- [ ] Error states handled gracefully (AI unavailable, timeout, invalid response)

---

## Phase 6 — Long-Term (Evaluate Later, Not Committed)

| # | Potential Feature | Notes |
|---|-------------------|-------|
| 6.1 | Customer-facing tracking portal | New role: Customer. Reuses same shell pattern (auth → role → mode). Requires customer-scoped API endpoints. |
| 6.2 | Wearable / in-cab hardware companion | Simplified Driver Mode on wearable or in-cab display. API-first design means no backend rework needed. |
| 6.3 | Expanded freight exchange mobile browsing | Only if user demand emerges; currently desktop-only per Mobile_App_Plan.md §15. |
| 6.4 | Tachograph driver-facing actions | Only if use case exists beyond passive backend data ingestion. |
| 6.5 | Dual-role mode switching | For owner-drivers who need both modes on one device. Deferred per Mobile_App_Plan.md §17.3. |

---

## Cross-Cutting Architecture Notes

### Reusable Components (Build Once, Use Everywhere)

| Component | Location | Used By |
|-----------|----------|---------|
| Staleness indicator ("12 min ago", "pending sync") | `shared/widgets/staleness_indicator.dart` | Every screen showing cached data |
| Offline banner | `shared/widgets/offline_banner.dart` | App shell (both modes) |
| Document upload queue UI | `shared/widgets/upload_queue.dart` | Driver documents, expenses |
| Chat message bubble | `shared/widgets/chat_bubble.dart` | Driver + Dispatcher messaging |
| Confirmation dialog (destructive actions) | `shared/widgets/confirmation_dialog.dart` | Quick actions, AI actions, approvals |
| Empty state illustration | `shared/widgets/empty_state.dart` | Lists throughout the app |
| Loading skeleton/shimmer | `shared/widgets/shimmer.dart` | All async screens |
| Desktop hand-off CTA ("Open in desktop for...") | `shared/widgets/desktop_handoff.dart` | Anywhere full desktop workflow is truncated |

### Backend Coordination

All mobile-facing endpoints are **additive** to the existing FastAPI service layer. The mobile team must coordinate with backend development on:

1. **Endpoint contracts** (request/response DTOs) — define together before implementation
2. **Delta-sync cursor format** — agree on cursor/since mechanism
3. **Upload protocol** — multipart format, chunking, resume tokens
4. **WebSocket message format** — standardize event types and payloads
5. **Push notification payload** — agree on data payload for routing taps to correct screens
6. **Feature flag format** — consistent tier-gating across all clients (desktop, web, mobile)

### State Management Approach

Based on Stack.md (Bloc or Riverpod):

- **Riverpod** is recommended for this project: simpler mental model than Bloc for a team coming from React Query patterns, good support for async data with `AsyncNotifier`, and less boilerplate than Bloc for the "cache + server state" pattern mobile uses.
- If Riverpod: each feature screen gets provider(s) that fetch from cache first, then API, then cache results. Offline queue providers manage the action queue state.
- If Bloc: each feature gets a Bloc + events + states. More structured but more boilerplate.

### Local Storage

Decision between Isar vs. Hive:
- **Isar** is recommended: faster queries, better Dart 3 support, and strongly needed for delta-sync merge logic (query "what transports changed since cursor X"). Hive is simpler but less capable for structured queries.
- Use Isar for: transport cache, message cache, offline action queue, delta-sync cursor store
- Use `flutter_secure_storage` for: refresh tokens (not Isar)

---

## Open Decisions Requiring Gigi's Sign-Off

Copied from Mobile_App_Plan.md §24, updated with current status:

| # | Decision | Status |
|---|----------|--------|
| 1 | Cross-platform framework | ✅ Resolved: Flutter (Stack.md) |
| 2 | Real-time transport: WebSocket vs. SSE | ⏳ **Default: WebSocket** — awaiting sign-off |
| 3 | Push provider: FCM/APNs vs. dev toolkit | ⏳ **Default: FCM/APNs direct** — awaiting sign-off |
| 4 | Dual-role mode switching in V1 | ⏳ Deferred per plan — not blocking Phase 0–3 |
| 5 | "Ask Operion" interaction pattern | ⏳ Deferred until AI Co-Pilot desktop model solidifies — not blocking Phase 0–4 |
| 6 | Tachograph driver-facing actions | ⏳ Deferred — not blocking any phase |

---

## Verification Discipline (Inherited from Blueprint)

From Mobile_App_Plan.md §21, Phase 3:

> This phase produces the verification evidence (failing-then-passing tests, not self-reported completion) required before MVP is declared done.

This applies to every phase gate:

- **No "it works on my machine."** Verify on both physical Android and iOS devices.
- **No "I think security is fine."** CI-blocking regression tests that fail before fix, pass after fix.
- **No "offline probably works."** Simulated network interruption tests with specific pass/fail criteria.
- **No "permissions should be fine."** Tenant-isolation tests that cross company boundaries and verify rejection.

---

*End of IMPLEMENTATION_PLAN.md — ready for Phase 0 kickoff after remaining sign-offs.*
