# Operion Mobile — Master Planning Blueprint

**Document status:** Planning only. No code, no screens, no implementation.
**Companion documents:** `Operion\_AI\_CoPilot\_Blueprint\_V4.md`, `Operion\_Freight\_Exchange\_Module\_Blueprint.md`, `operion\_website\_specification.md`
**Version:** V1
**Purpose:** This document is the single source of truth for planning, scoping, and sequencing the Operion Mobile application. It is written to be handed section-by-section to AI coding agents once implementation begins, following the same verification-gated methodology used for the AI Co-Pilot and Freight Exchange blueprints.

\---

## 0\. Executive Summary

Operion Mobile is not a shrunken version of the PySide6 desktop ERP. It is a **mobile-first companion** with two distinct experiences layered on the same backend:

1. **Driver Mode** — a full operational tool for drivers to eliminate paper and reduce communication overhead.
2. **Dispatcher/Manager Mode** — a monitoring, alerting, and quick-decision surface for dispatchers, managers, and owners.

A third, cross-cutting layer — **Operion AI** — is the strategic centerpiece. Rather than porting dozens of desktop screens to mobile, advanced functionality is exposed through a conversational/action interface that executes real backend operations under the authenticated user's role and permissions. Operion AI is currently **in blueprint/early-build stage on desktop** (see `Operion\_AI\_CoPilot\_Blueprint\_V4.md`) and is **not yet implemented**, but mobile is being architected from day one so that AI integration slots in without rework once the Reasoning Graph, World Model, and tool registry mature on the backend.

The mobile app talks exclusively to backend APIs. It duplicates no business logic. Database, services, permissions, AI, and business rules stay centralized; only presentation and mobile-specific concerns (offline cache, push, camera/OCR capture, GPS) live in the mobile layer.

\---

## 1\. Mobile Philosophy

### 1.1 Core Principles

* **Remote control, not a miniature ERP.** The phone is a control surface for the same backend the desktop uses — not a parallel implementation.
* **Two audiences, two apps, one codebase.** Driver Mode and Dispatcher/Manager Mode are structurally different experiences (different navigation, different information density, different interaction patterns), sharing auth, design tokens, networking, and offline infrastructure.
* **AI is a feature multiplier, not a decoration.** Rather than building a screen per capability, most "long-tail" functionality (the 80% of features used occasionally) is delivered through Operion AI once it exists. Screens are reserved for the 20% of workflows used constantly (assigned transports, status updates, live fleet view).
* **Desktop remains the power-user workstation.** Migration wizards, generators, report builders, and large editable tables stay on desktop by design — not as a temporary limitation, but as a permanent architectural decision. Mobile optimizes for glance-and-act, not deep configuration.
* **Offline is a first-class constraint, not an edge case.** Drivers operate in tunnels, rural EU roads, and border crossings with unreliable connectivity. The app must degrade gracefully, not fail.
* **Provider-agnostic where the desktop already is.** Mobile freight exchange, tracking, and OCR consumption follow the same abstraction boundaries already established for desktop (`FreightProviderAdapter`, tracking adapters, LLM abstraction layer) — mobile never talks to TIMOCOM, Wialon, or an OCR engine directly.

### 1.2 What Mobile Explicitly Is Not

|Not this|Why|
|-|-|
|A full port of desktop screens|Screen density and interaction models differ fundamentally on a 6" display|
|A second business-logic implementation|Violates the single-backend principle; creates drift and duplicate bugs|
|The primary invoicing/reporting tool|Desktop generators (PDF, CMR, Tahograf, complex reports) stay put|
|A replacement for the admin/setup console|Company configuration, migration, and tenant setup remain desktop-only|
|An offline-first database that syncs like a CRDT|Overkill for this domain; mobile needs a cache + queue, not a distributed database|

\---

## 2\. User Roles

Mobile inherits the backend's existing role model (shared with desktop) rather than defining a parallel one.

|Role|Mobile Mode|Notes|
|-|-|-|
|Driver (Șofer)|Driver Mode|Sees only their own assigned transports, vehicle, documents, messages|
|Dispatcher|Dispatcher/Manager Mode|Sees fleet-wide operational view, can reassign, approve, message|
|Fleet Manager|Dispatcher/Manager Mode|Superset of dispatcher view; maintenance, compliance alerts|
|Owner/Admin (developer role)|Dispatcher/Manager Mode|Full visibility, analytics, approvals; admin/setup screens excluded from mobile regardless of role|

Role and permission resolution happens **server-side**, identical to desktop. The mobile client never hard-codes "if role == driver" business rules beyond deciding which navigation shell to render — every action still passes through backend permission checks, especially the multi-tenant `company\_id` isolation invariant already established as a first-class safety rule in the security audit work.

A single account can only present one mode at a time (a dispatcher who occasionally drives does not get a hybrid UI); if this combined-role case exists in practice, it is deferred to a post-MVP decision (see §17.3).

\---

## 3\. Overall Architecture

```
┌─────────────────────────────┐        ┌─────────────────────────────┐
│   Operion Mobile (Driver)   │        │ Operion Mobile (Dispatcher) │
│  React Native / Flutter\*    │        │  React Native / Flutter\*    │
└──────────────┬───────────────┘        └──────────────┬───────────────┘
               │  HTTPS / REST + WebSocket (shared client SDK)         
               ▼                                        ▼
        ┌────────────────────────────────────────────────────────┐
        │              FastAPI Backend (shared)                   │
        │  Auth · Permissions · Business Services · AI Co-Pilot   │
        │  Freight Exchange Adapters · Tracking Adapters · OCR     │
        └───────────────────────┬──────────────────────────────────┘
                                 ▼
                       PostgreSQL (shared, single source of truth)
                                 ▼
        ┌────────────────────────────────────────────────────────┐
        │        Desktop PySide6 Client (unchanged)               │
        └────────────────────────────────────────────────────────┘
```

\*Framework choice is a §16 decision, not assumed here.

### 3.1 Layering Rules

1. **Presentation layer (mobile app):** UI, navigation, local cache, offline queue, push handling, camera/GPS capture.
2. **API layer (shared, existing FastAPI):** All business logic, validation, and permission enforcement. Mobile gets new **endpoints**, not new **logic**, wherever a desktop equivalent exists.
3. **Data layer (shared PostgreSQL):** No mobile-only tables except those strictly needed for mobile-specific concerns (device tokens, push subscriptions, offline sync checkpoints, mobile session metadata).
4. **AI layer (shared, in progress):** Mobile calls the same AI Co-Pilot orchestration endpoints the desktop will use; no mobile-specific prompt logic or tool registry.

### 3.2 New Backend Surface Required

Even though logic isn't duplicated, mobile will require **new, mobile-oriented API endpoints** layered over existing services:

* Condensed "dashboard summary" endpoints (avoid multiple round trips for a home screen)
* Push notification registration/device-token endpoints
* Mobile-optimized pagination/delta-sync endpoints (see §10)
* Document/photo upload endpoints tuned for mobile multipart upload with resumability
* A driver-scoped "my day" aggregation endpoint (transports + status + messages + alerts in one call)

These are additive API surface, not new business rules — the underlying service layer (transport service, document service, maintenance service, etc.) is reused as-is.

\---

## 4\. Driver Mode

### 4.1 Design Intent

Driver Mode optimizes for use **while working**, often one-handed, often with poor connectivity, sometimes while stationary at a loading dock. Priorities: minimum taps to update status, maximum offline resilience, camera-first document capture.

### 4.2 Driver Workflows

|Workflow|Why it belongs on mobile|Desktop / Mobile / Both|Dependencies|Priority|
|-|-|-|-|-|
|View assigned transports|Core daily need; driver is rarely at a desktop|Mobile only (drivers don't use desktop)|Transport service API|MVP|
|Route/navigation info (address, waypoints, deep-link to Maps/Waze)|Drivers need turn-by-turn now, not a map redraw|Mobile only|Route data API, external map deep-linking|MVP|
|Job status updates (departed, arrived, loading, delivered, delayed)|Real-time operational signal for dispatch|Mobile only (input); Both (visibility)|Transport status endpoint, WebSocket/push to dispatcher|MVP|
|Document upload (CMR, POD, invoices, photos)|Camera-based capture only makes sense on a phone|Mobile only (capture); Both (viewing)|Document service, object storage, OCR pipeline|MVP|
|OCR-assisted document capture|Reduces manual data entry errors at the point of scanning|Mobile only|Existing dual-engine OCR routing (PaddleOCR/Gemma 3:4B) exposed via API|MVP (basic capture) → Fast-follow (auto-fill via OCR)|
|Notifications (new assignment, schedule change, alerts)|Drivers need push, not an email they'll never open|Mobile only|Push infrastructure (§11)|MVP|
|Messaging (dispatcher ⇄ driver)|Replaces phone calls/SMS with an auditable channel|Mobile only (driver side); Both (dispatcher side)|Messaging service, WebSocket|MVP|
|Vehicle information (assigned truck/trailer, documents, status)|Driver needs to know what they're driving and its compliance status|Mobile only (view); Both (data)|Fleet/vehicle service|MVP|
|Expenses (fuel, tolls, per diem, receipts photo)|Point-of-spend capture beats end-of-trip paperwork|Mobile only (capture); Both (approval on desktop/dispatcher)|Expense service, document/photo upload|Fast-follow|
|Profile (personal info, documents, certifications)|Self-service reduces admin overhead|Both|User service|Fast-follow|
|Tachograph (.DDD) related driver actions|Only if driver-facing action exists beyond passive data collection|Likely desktop-only for now (device-based ingestion)|Tachograph pipeline|Long-term / evaluate|
|Ask Operion AI (driver-scoped): "when is my next stop", "who do I contact for this delivery"|Reduces need for a dispatcher call for simple lookups|Mobile only, once AI exists|AI Co-Pilot backend, permission-scoped to driver role|Post-MVP (blocked on AI backend maturity)|

### 4.3 Driver Mode Non-Goals

* No analytics, no fleet-wide visibility, no financial data beyond their own expenses.
* No access to other drivers' data, transports, or documents (enforced server-side by `company\_id` + `driver\_id` scoping).
* No administrative actions of any kind.

\---

## 5\. Dispatcher / Manager Mode

### 5.1 Design Intent

This mode optimizes for **situational awareness and fast decisions** away from the desk — not for deep configuration. If a workflow requires sustained focus, large tables, or complex multi-field forms, it stays on desktop.

### 5.2 Dispatcher / Manager Workflows

|Workflow|Why it belongs on mobile|Desktop / Mobile / Both|Dependencies|Priority|
|-|-|-|-|-|
|Live fleet status (map view, vehicle states)|Managers check this away from the desk constantly|Both|Live tracking adapters (Wialon/Frotcom/Traccar)|MVP|
|Driver list + status|Quick "who's available / who's driving" check|Both|Driver/fleet service|MVP|
|Active jobs / transports overview|Core monitoring surface|Both|Transport service|MVP|
|Alerts (delays, maintenance due, document expiry, compliance)|Time-sensitive; needs push, not a dashboard someone forgets to open|Mobile-first (push); Both (viewing)|Alerting service, push infra|MVP|
|Quick actions (reassign transport, approve expense, approve document)|Decisions that don't need a full desktop session|Both, with mobile offering a reduced action set|Existing services; permission checks server-side|MVP (limited set) → expand later|
|Analytics (profit, KPIs, condensed dashboards)|Owners check numbers on the go|Mobile: summary views only; Both|Analytics service (existing six-tab analytics: Financiar, Flotă, Rute, Clienți, Șoferi, Documente) — mobile surfaces condensed versions|Fast-follow|
|Manage transports (create/edit at a basic level)|Occasionally needed away from desk|Both, mobile with simplified forms; complex editing stays desktop|Transport service|Fast-follow|
|Approvals (expenses, documents, exception handling)|Time-sensitive human-in-the-loop steps|Both|Relevant service + notification trigger|MVP|
|Messaging with drivers|Direct operational communication|Both|Messaging service|MVP|
|Ask Operion AI: "reassign transport X", "find another available truck", "generate invoice", "show today's profit", "why is delivery Y delayed"|This is the mechanism that avoids rebuilding dozens of desktop screens on mobile|Mobile-first interface to backend actions that already exist for desktop, once AI ships|AI Co-Pilot backend (Reasoning Graph, World Model, tool registry, execution state machine — see companion blueprint)|Post-MVP, phased as AI backend capabilities land|
|Migration wizard, large generators, report builders, massive editable tables, administrative setup|Requires sustained focus, large screen real estate, and low-risk-of-fat-finger-error input|**Desktop only**|N/A|Explicitly out of scope for mobile|

### 5.3 Quick Actions — Scope Discipline

"Quick actions" on mobile must remain genuinely quick: a small, curated set of single-step, low-ambiguity operations (approve, reject, reassign to a suggested candidate, acknowledge alert). Anything requiring multi-field configuration is either redirected to Operion AI (once available) or explicitly deferred to desktop, with the mobile UI stating so rather than offering a cramped form.

\---

## 6\. Operion AI on Mobile

### 6.1 Status and Sequencing Reality

Operion AI (the AI Co-Pilot) is **not yet implemented** as of this planning document. It exists as `Operion\_AI\_CoPilot\_Blueprint\_V4.md` (22 sections: Pydantic contracts, Reasoning Graph, World Model snapshot service, execution state machine, tool registry, OCR routing, confidence scoring, session memory, audit logging, tier gating, provider-agnostic LLM layer). Mobile development will proceed **in parallel** with AI backend development, not after it. This has direct architectural consequences:

* Mobile screens must cover the **MVP workflows independent of AI** (§4, §5 "MVP" rows) so the app is useful before AI exists.
* The mobile client must have a **stable AI integration seam** designed from day one — a single "Ask Operion" entry point (chat-style or command-style, TBD in UI/UX phase) that calls one well-defined backend endpoint, so that swapping in AI capability later is additive, not a rewrite.
* Feature flagging: AI-dependent capabilities on mobile should be gated behind a feature flag / tier check consistent with the existing subscription tier gating design in the Co-Pilot blueprint, so mobile can ship to some users before AI is fully rolled out.

### 6.2 Why AI Is the Primary Interface for "Advanced" Mobile Functionality

Building a dedicated mobile screen for every desktop capability is not sustainable for a solo-developer-led product. The AI Co-Pilot lets mobile expose **the same backend tool registry** the desktop will eventually use, through a single conversational surface, rather than requiring a bespoke screen per capability. This is explicitly the mechanism that keeps mobile development scope bounded.

### 6.3 Permission and Safety Requirements for Mobile AI

* Every AI-invoked action executes **as the logged-in user**, through the same permission checks as if that user had clicked a desktop button. The AI has no elevated privilege.
* The execution state machine (already specified in the Co-Pilot blueprint) applies identically on mobile: proposed action → confirmation (where required) → execution → audit log entry.
* Destructive or financially significant actions (reassigning a transport, generating an invoice, notifying a customer) require an explicit confirmation step in the mobile UI — the AI should not "fire and forget" high-impact actions from a chat bubble.
* Multi-tenant isolation (`company\_id`) applies to every AI tool call exactly as it does to REST endpoints; this is a non-negotiable inherited invariant from the existing security audit work.

### 6.4 Mobile-Specific AI UX Considerations (high-level, not implementation)

* Voice input is a natural fit for drivers (hands-busy context) — self-hosted Whisper STT is already an architectural decision for the platform and should be reused, not reimplemented for mobile.
* Dispatcher/manager AI usage is more likely typed/short-form ("today's profit", "reassign X to Y").
* AI responses that return data (e.g., "show today's profit") should render as structured mobile UI (a card, a number, a small chart) wherever possible, not just plain text — this is a rendering concern for the mobile client, not a backend concern.

\---

## 7\. Authentication Flow

### 7.1 Requirements

* Shared identity with desktop: same user accounts, same `company\_id` tenancy, same password/credential store.
* Token-based auth (JWT or equivalent already used by the FastAPI backend) with:

  * Access token (short-lived)
  * Refresh token (longer-lived, securely stored in platform keychain/keystore — never in plain storage)
* Biometric unlock (Face ID / fingerprint) as a **local re-authentication convenience** layered on top of the stored refresh token — not a replacement for backend auth.
* Device registration at login time, to support push notification targeting and "sign out of all devices" from desktop/admin.
* Role/mode resolution happens immediately post-login: the backend returns the user's role, and the mobile app renders Driver Mode or Dispatcher/Manager Mode accordingly — no client-side role guessing.

### 7.2 Session Edge Cases to Plan For

* Token expiry while offline (queued actions must re-authenticate on reconnect, not silently fail).
* Forced logout from admin/desktop (device should detect revoked session on next API call and prompt re-login).
* Company/tenant suspension or plan downgrade affecting available mobile features (tier gating check on login and periodically thereafter).

\---

## 8\. Navigation Structure \& Screen Hierarchy

### 8.1 Shared Shell

```
App Launch
 └─ Auth Gate (login / biometric unlock / session restore)
     └─ Role Resolution
         ├─ Driver Mode Shell
         └─ Dispatcher/Manager Mode Shell
```

### 8.2 Driver Mode — Screen Hierarchy (high-level, no implementation detail)

```
Driver Home ("My Day")
 ├─ Assigned Transports (list)
 │   └─ Transport Detail
 │       ├─ Route / Navigation hand-off
 │       ├─ Status update
 │       ├─ Document capture (CMR / POD / invoice / photo)
 │       └─ Related messages
 ├─ Documents (all, cross-transport)
 ├─ Messages
 ├─ Vehicle Info
 ├─ Expenses
 │   └─ New Expense (receipt capture)
 ├─ Notifications
 ├─ Ask Operion (post-MVP, feature-flagged)
 └─ Profile / Settings
```

### 8.3 Dispatcher/Manager Mode — Screen Hierarchy

```
Dispatcher Home (operational overview)
 ├─ Live Fleet Map
 ├─ Active Jobs / Transports
 │   └─ Transport Detail (view, reassign, message driver)
 ├─ Drivers (list + status)
 ├─ Alerts / Approvals Inbox
 │   └─ Approval Detail (approve/reject with reason)
 ├─ Analytics (condensed)
 │   └─ Category drill-in (Financiar / Flotă / Rute / Clienți / Șoferi / Documente — summary only)
 ├─ Messages
 ├─ Ask Operion (post-MVP, feature-flagged)
 └─ Profile / Settings
```

### 8.4 Navigation Principles

* Bottom navigation (or platform-equivalent) limited to 4–5 top-level destinations per mode; everything else is reachable via drill-in, not a second navigation bar.
* "Ask Operion," once live, is placed prominently (not buried) since it's the intended shortcut for anything not covered by a dedicated screen.
* No shared navigation shell between the two modes beyond the auth gate — they are structurally different apps sharing infrastructure, which should be reflected honestly in the navigation code, not forced into one generic shell with role-based hiding.

\---

## 9\. API Requirements

### 9.1 Principles

* Mobile consumes **versioned** REST endpoints (existing FastAPI backend), with WebSocket (or SSE, decision in §16) for real-time push (live tracking updates, new messages, alert delivery while app is foregrounded).
* Every new mobile endpoint is additive to the existing service layer — no parallel service implementations.
* Response payloads for mobile favor **condensed, purpose-built DTOs** over reusing full desktop payloads verbatim, to reduce bandwidth on mobile networks.

### 9.2 New/Adapted Endpoint Categories Needed

|Category|Example|Notes|
|-|-|-|
|Driver aggregate|`GET /mobile/driver/my-day`|Combines today's transports, status, alerts, unread messages in one call|
|Dispatcher aggregate|`GET /mobile/dispatcher/overview`|Fleet counts, active job counts, open alerts, in one call|
|Delta sync|`GET /mobile/sync?since=<cursor>`|Returns only changed records since last sync cursor (see §10)|
|Document upload|`POST /mobile/documents/upload` (multipart, resumable)|Feeds into existing document service + OCR pipeline|
|Device/push registration|`POST /mobile/devices/register`|Ties device token to user + company for targeted push|
|Status update|`PATCH /mobile/transports/{id}/status`|Thin wrapper over existing transport service|
|Expense submission|`POST /mobile/expenses`|Feeds existing expense/finance service|
|AI interaction (post-MVP)|`POST /ai/copilot/query` (shared with desktop, not mobile-specific)|Reused as-is once it exists — mobile is just another client|

### 9.3 Backend Requirements Summary

* Extend existing FastAPI services with mobile-facing endpoints; do not fork services.
* Add device/push token storage (new lightweight table).
* Add a sync-cursor mechanism (see §10) if not already present.
* Ensure all new endpoints enforce the same `company\_id` and role-based permission middleware already used elsewhere.
* Rate limiting / abuse protection on document upload endpoints (mobile uploads are a new, camera-driven volume source).

\---

## 10\. Synchronization Strategy

### 10.1 Approach: Cache + Delta Sync, Not Full Offline-First Replication

Given the operational (not collaborative-editing) nature of this data, a full CRDT/offline-first database is unnecessary complexity. Instead:

* **Read path:** Local cache (per-mode: driver's transports, dispatcher's overview) refreshed via a delta-sync endpoint using a cursor/timestamp, not full re-fetch each time.
* **Write path:** Local **action queue**. Actions performed offline (status update, expense submission, document capture) are queued locally with a client-generated idempotency key and replayed against the backend on reconnect, in order.
* **Conflict handling:** Given the domain (a transport has one authoritative status, one authoritative assignment), conflicts are rare and resolved **server-wins with client notification** — the mobile client does not attempt merge logic. If a queued action is rejected (e.g., transport was reassigned elsewhere while offline), the user is shown a clear, specific message, not a silent failure.

### 10.2 What Gets Cached Locally

|Data|Driver Mode|Dispatcher Mode|
|-|-|-|
|Assigned/active transports|Yes (own only)|Yes (fleet-wide, recent window)|
|Documents metadata|Yes (own)|Metadata only, not full files|
|Messages|Yes (recent thread)|Yes (recent threads)|
|Vehicle info|Yes (assigned vehicle)|Summary only|
|Alerts|N/A (drivers get push, not an alert inbox)|Yes|
|Analytics|No|Cached last-fetched snapshot only, clearly timestamped as "as of"|

\---

## 11\. Offline Support Strategy

### 11.1 Principles

* **Never block core driver actions on connectivity.** A driver must be able to update status and capture a document with zero signal; the app queues and syncs later.
* **Be explicit about staleness.** Any cached or queued data visible to the user should be visibly marked ("last updated 12 min ago", "pending sync") rather than presented as live truth.
* **Document capture works fully offline.** Photos/scans are stored locally (device storage) until upload succeeds; OCR processing can happen server-side after upload (no requirement for on-device OCR, though it remains an option to evaluate later if latency demands it).
* **Dispatcher/Manager mode has weaker offline requirements** than Driver Mode — this mode is inherently about live/current state (fleet position, live alerts), so offline here is about graceful degradation (show last-known snapshot, clearly labeled) rather than full offline operation.

### 11.2 Explicit Non-Requirements

* No offline AI interaction (Operion AI requires backend connectivity by nature).
* No offline analytics computation (server remains source of truth for aggregates).
* No offline multi-user conflict resolution UI — kept out of scope given the low collision domain.

\---

## 12\. Notifications

### 12.1 Channels

* **Push notifications** (APNs/FCM via existing dev toolkit or a standard provider) for: new assignment, schedule change, new message, alert (delay, maintenance due, document expiry), approval request.
* **In-app notification center** for a persistent, reviewable history (not everything needs to interrupt via push).

### 12.2 Role-Based Notification Behavior

|Event|Driver|Dispatcher/Manager|
|-|-|-|
|New transport assignment|Push (high priority)|N/A|
|Status change on a job they own/manage|N/A|Push|
|Document expiring soon|Push (own documents)|Push (fleet-wide, digest)|
|New message|Push|Push|
|Approval needed|N/A|Push (high priority)|
|Maintenance due|N/A (unless it affects their assigned vehicle, then informational)|Push|

### 12.3 Backend Requirement

Notification dispatch should be triggered from existing backend events (status changes, alert generation) via a shared notification service, not from mobile-side polling — this keeps behavior identical regardless of which client (if any) is open.

\---

## 13\. Security

### 13.1 Inherited, Non-Negotiable Invariants

* **Multi-tenant `company\_id` isolation** applies identically to every mobile endpoint, exactly as established in the desktop security audit. No exceptions for "mobile convenience."
* Driver-role tokens must be scoped so that even a compromised driver device cannot enumerate other drivers, other companies, or fleet-wide data — server-side scoping, not client-side hiding.
* All traffic over TLS; no plaintext fallback.
* Refresh tokens stored in platform-secure storage (iOS Keychain / Android Keystore), never in shared preferences or plain files.

### 13.2 Mobile-Specific Additions

* Remote session revocation (admin/desktop can force-logout a lost/stolen device).
* Local biometric lock as a UX convenience layered on top of, not instead of, backend session validity.
* Screenshot/screen-recording restriction consideration for financial/analytics screens (platform-dependent, evaluate per OS).
* Upload endpoints (documents/expenses) treated as an increased attack surface (file-type validation, size limits, malware scanning if feasible) since this is a new, camera-driven ingestion path not previously exposed to this volume.
* Regression coverage: mobile-facing endpoints should be added to the existing `tests/security/` permanent regression suite, keeping CI-blocking discipline consistent with the rest of the platform.

\---

## 14\. Permissions

* Permission model is **entirely backend-resolved** — the mobile client requests "what can I do" via the role/permission payload returned at login and after any relevant state change, and renders UI accordingly (hiding actions the user can't perform), but the backend independently re-validates every action regardless of what the client displays.
* No permission logic is duplicated or hardcoded in the mobile client beyond UI affordance (show/hide a button) — this mirrors the "no duplicated business logic" principle from §0.
* Approval actions (expense, document, transport changes) carry the same role-gating as desktop; mobile does not introduce a looser approval path "because it's convenient on the go."

\---

## 15\. Freight Exchange Integration on Mobile

* Mobile does **not** re-implement freight exchange search/matching logic. If freight exchange interaction is exposed on mobile at all in early phases, it is exposed through:

  1. **Read-only summaries** (e.g., "3 new matching loads found") surfaced via notification/alert, driving the user to act on desktop, or
  2. **Operion AI**, once available — "search freight exchanges for a load matching Truck X" is a natural AI Co-Pilot tool call using the existing provider-agnostic `FreightProviderAdapter` (TIMOCOM first, Trans.eu/Teleroute/Wtransnet later), not a mobile-native integration.
* Direct, full freight-exchange browsing/negotiation UI on mobile is explicitly deferred — this is a dense, desktop-appropriate workflow (see §5.2 non-goals) unless user research later shows strong demand for a lightweight mobile version.

\---

## 16\. Technology \& Platform Decisions Needed

These are **decisions to make before implementation begins**, not decisions this document makes unilaterally:

|Decision|Options|Recommendation basis|
|-|-|-|
|Cross-platform framework|React Native, Flutter, native (Swift/Kotlin)|Given the existing Vite/React/TypeScript SPA and team familiarity, React Native likely offers the most code/skill reuse (shared TypeScript types, similar mental model to the SPA) — but this should be a deliberate, explicit choice before Phase 1, not an assumption baked in here|
|Real-time transport|WebSocket vs. Server-Sent Events vs. polling|WebSocket likely preferred for bidirectional messaging + live tracking; confirm against existing backend real-time infrastructure, if any|
|Push provider|FCM (Android) + APNs (iOS) direct, or via existing internal dev toolkit|Reuse existing observability/notification tooling if it already brokers push; avoid standing up a redundant provider|
|Local storage/cache|SQLite, WatermelonDB, MMKV + simple JSON cache|Given the "cache + delta sync" strategy (not full offline-first), a lighter solution (SQLite or key-value + structured cache) is likely sufficient — avoid CRDT-grade tooling unless a concrete future need emerges|
|State management|Redux/Zustand/Recoil equivalent, or React Query-style server-state caching|Should mirror patterns already used in the operionerp.xyz SPA where reasonable, for cognitive consistency across the codebase|

This document intentionally does **not** lock these in — they should be resolved as the first concrete task of Phase 0 of implementation, with a short decision record, following the same "flag open decisions explicitly" discipline used elsewhere in Operion's planning process.

\---

## 17\. UI/UX Philosophy

### 17.1 Visual Identity

* Mobile inherits the existing design system: indigo `#6366F1` primary accent, Inter font family, and the token-driven approach already used in `design\_tokens.py` / QSS for desktop and the SPA's design tokens — translated into a mobile design-token equivalent rather than reinvented.
* `t()`-style i18n backed by `ro.json` / `en.json` is reused conceptually; mobile ships Romanian and English at minimum, consistent with desktop.

### 17.2 Interaction Principles

* **Driver Mode:** large touch targets, minimal text entry, camera-first flows, status changes achievable in 1–2 taps, legible in direct sunlight and while wearing gloves in cold-weather scenarios (a real EU road-freight condition worth designing for).
* **Dispatcher/Manager Mode:** information-dense but scannable — cards and lists over deep forms, drill-in rather than in-place heavy editing, quick actions surfaced contextually (swipe-to-approve style patterns are reasonable to explore, decided at UI design phase).
* Both modes: honest empty/loading/offline states (no silent spinners masking failure), consistent with the general principle of never treating AI or sync completion claims as self-reported/trusted without visible confirmation.

### 17.3 Open UX Questions to Resolve Before Visual Design

* Should a user with dual roles (e.g., an owner who also drives occasionally) be able to switch modes manually, or is this genuinely out of scope for V1? (Currently deferred — see §2.)
* Is "Ask Operion" a persistent chat-style surface or a command-palette-style overlay? Decide once the AI Co-Pilot's interaction model solidifies on desktop, to keep the mental model consistent across clients.

\---

## 18\. Mobile-Specific Optimizations

* **Bandwidth-aware payloads:** condensed DTOs (§9.3), image compression before upload, delta sync (§10) instead of full refreshes.
* **Battery-aware location usage:** live tracking data consumption (viewing fleet position) is read-only from the backend/tracking adapters — the mobile app is **not** itself a GPS tracking beacon for the vehicle (that role belongs to existing tracking hardware/adapters: Wialon, Frotcom, Traccar), avoiding unnecessary battery drain and scope creep into a device-tracking product.
* **Resumable uploads** for documents/photos over flaky connections (critical for CMR/POD capture at loading docks with poor signal).
* **Deep-linking to native navigation apps** (Maps/Waze) rather than building an in-app turn-by-turn experience — avoids reinventing a mature, safety-critical capability.
* **Push-first alerting** over in-app polling, to preserve battery and data.

\---

## 19\. Future Scalability

* **Additional tracking/freight adapters** (Trans.eu, Teleroute, Wtransnet; Wialon/Frotcom/Traccar) plug in without mobile changes, since mobile consumes provider-agnostic backend abstractions, not provider-specific integrations.
* **Expanded AI tool coverage:** as the AI Co-Pilot's tool registry grows on the backend, mobile's "Ask Operion" surface gains capability automatically — no mobile release required for many future AI features, only for UI/response-rendering improvements.
* **Additional roles** (e.g., a customer-facing portal role, if Operion ever exposes tracking to end customers) can reuse the same shell pattern (auth gate → role resolution → mode shell) established here.
* **Wearables / in-cab hardware** (e.g., a simplified driver display) is a plausible long-term extension of Driver Mode's API surface, without any backend rework, given the API-first design.

\---

## 20\. Feature Prioritization Summary

Legend: **MVP** = required for first usable release · **Fast-follow** = immediately after MVP, still pre-AI · **Post-MVP (AI-gated)** = blocked on Operion AI backend maturity · **Long-term** = evaluate later, not committed.

|Priority|Driver Mode|Dispatcher/Manager Mode|
|-|-|-|
|**MVP**|Assigned transports, navigation hand-off, status updates, document upload (manual, no OCR autofill yet), notifications, messaging, vehicle info|Live fleet status, driver list, active jobs, alerts, limited quick actions (approve/reject), messaging|
|**Fast-follow**|OCR-assisted capture, expenses, profile|Condensed analytics, basic transport management, expanded quick actions|
|**Post-MVP (AI-gated)**|Ask Operion (driver-scoped queries)|Ask Operion (reassign, find truck/driver, generate invoice, profit query, delay explanation, freight exchange search, maintenance scheduling, customer notification)|
|**Long-term**|Tachograph driver-facing actions (if any), in-cab hardware companion|Customer-facing tracking portal, expanded freight-exchange mobile browsing (if demand emerges)|

\---

## 21\. MVP Roadmap

**Phase 0 — Foundations (pre-screens)**

* Lock technology decisions (§16).
* Stand up shared auth flow (token issuance, refresh, device registration) reusing backend identity.
* Establish mobile design tokens derived from existing design system.
* Stand up delta-sync and offline-queue infrastructure (§10, §11) as reusable client infrastructure, before building feature screens on top of it.

**Phase 1 — Driver Mode MVP**

* Driver Home ("My Day"), Assigned Transports, Transport Detail, Status Update, Document Upload (manual), Vehicle Info, Messaging, Notifications.
* Backend: new mobile aggregate endpoints, device/push registration, upload endpoint.

**Phase 2 — Dispatcher/Manager Mode MVP**

* Dispatcher Home, Live Fleet Map (read-only, existing tracking adapters), Active Jobs, Driver List, Alerts/Approvals Inbox, Messaging.
* Backend: dispatcher aggregate endpoint, approval action endpoints (thin wrappers).

**Phase 3 — Hardening \& Verification Gate**

* Security regression suite extended to mobile endpoints.
* Offline queue replay tested against real network interruption scenarios.
* Permission/tenant-isolation tests specifically targeting mobile-only endpoints.
* This phase produces the verification evidence (failing-then-passing tests, not self-reported completion) required before MVP is declared done, consistent with Gigi's established blueprint discipline.

## 22\. Long-Term Roadmap

* **Phase 4:** OCR-assisted document capture, expenses, driver profile self-service.
* **Phase 5:** Condensed analytics on Dispatcher/Manager mode; expanded quick actions (multi-step but still mobile-appropriate).
* **Phase 6:** Operion AI integration — "Ask Operion" surfaces on both modes, feature-flagged and rolled out incrementally as backend tool coverage grows (reassignment → invoice generation → profit/analytics queries → delay explanations → freight exchange search → maintenance scheduling → customer notification), each gated by its own verification step rather than shipped as one giant AI release.
* **Phase 7+ (evaluate, not committed):** Customer-facing tracking view, wearable/in-cab companion, expanded freight-exchange mobile browsing, tachograph driver-facing actions.

\---

## 23\. Summary of Explicit Desktop-Only Exclusions

For clarity and to prevent scope creep during implementation, the following remain **desktop-only for the foreseeable future**, regardless of role:

* Migration wizard
* Large document/report generators (PDF invoices, CMR, Tahograf batch generation)
* Complex report builders
* Massive editable tables
* Company/tenant administrative setup
* Full freight exchange browsing/negotiation UI
* Deep multi-tab analytics (Financiar / Flotă / Rute / Clienți / Șoferi / Documente in full) — mobile gets condensed summaries only

\---

## 24\. Open Decisions Requiring Gigi's Sign-Off Before Implementation

1. Cross-platform framework choice (§16).
2. Real-time transport mechanism (WebSocket vs. SSE) (§16).
3. Push notification provider path (direct FCM/APNs vs. existing dev toolkit) (§16).
4. Whether dual-role users (e.g., owner-drivers) need a mode switch in V1 or can be deferred (§17.3).
5. "Ask Operion" interaction pattern (persistent chat vs. command-palette) — best deferred until the AI Co-Pilot's desktop interaction model is further along.
6. Whether tachograph driver-facing actions belong on mobile at all, or remain purely a backend/device ingestion concern.

\---

*End of Mobile\_App\_Plan.md — planning only. No implementation, no code, no screens have been produced as part of this document.*

