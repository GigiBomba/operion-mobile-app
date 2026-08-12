# Implementation Status & Production Readiness — Operion Mobile S-Grade Blueprint V2

> **Date:** 2026-08-03 · **Audit:** independent (fresh auditors) — blueprint conformance (A1) + production readiness (A2) · **Adjudication:** Oracle Gates 31–32 · **Record:** `.slim/deepwork/sgrade-phase0.md`

---

## Verdict

> **FEATURE-DoD: MET** — all 20 §2 rows shipped, all §7 offline rules wired, all §12 security gates applied.
> **QA-DoD: MET** — backend tests/mobile 318/318 · mobile 2310/2310 · integration 34/34 · RBAC 120 gates + 136-pair fixture · financial parity 29/29 both sides · copilot 3,555/0 · analyze 452 (0 errors).
> **DEPLOYMENT-READINESS (code): CODE-REMEDIATED** — all 10 Gate-31 code items shipped and verified (FCM PushSender, backend Sentry, Postgres mobile tables, Locust mobile endpoints, release-signing scaffolding, Firebase plugin prep, ConflictHandler §7 methods, notification icon, SDK pins, env/nginx/port fixes).
> **DEPLOYMENT-READINESS (config): BETA-GATED-ON-CONFIG+DEVICE** — 12 operator config items (credentials/secrets) + device-matrix manual pass + airplane-mode script + crash-free-rate from beta remain as the operator turnkey deliverable.
> **Phase-6 "READY FOR FAMILY-FLEET BETA" stands** for feature/QA coverage; the deployment gate is the config checklist below.

---

## 1. Blueprint Conformance Status (§0–§15 + Part 2)

| § | Section | Status | Notes |
|---|---------|--------|-------|
| §0 | Design parity | IMPLEMENTED | Zero "open on desktop" dead ends; Migration Center deliberately not ported |
| §1 | Gap analysis | IMPLEMENTED | All 10 critical/major gaps closed |
| §2 | Feature Parity Matrix | IMPLEMENTED (20/20) | All rows incl. follow-ups: rows 1/3/5/7/11/16 shipped (sparkline+feed, profile+chips, Kanban/Timeline, freight saved-search+evaluate, docs search/categories/versions, route thumbnail) |
| §3 | IA | IMPLEMENTED (documented deviation) | 5 tabs; Records/More searchable permission-filtered grids; global-search icon; Operations items live in More, Map is a tab (documented) |
| §4 | Screens | IMPLEMENTED | All specified screens; spot-checks pass (health/expiry thresholds, merge typed-confirmation, stepper, biometric gates, masked secrets; client tabs + truck documents now real data) |
| §5 | Providers | IMPLEMENTED | Exact family keys/records; SyncEntityType 8 + QueuedActionType 15; dual-mode network→cache→banner; exportJobStatusProvider; 350ms debounce |
| §6 | Endpoints | IMPLEMENTED | 47 routes (44 spec + 3 extras); permission gates first-line; pagination le=200 (repo convention, documented) |
| §7 | Offline/Sync | IMPLEMENTED (2 notes) | Queue TTL 24h + staleCount; merge/blocked rules tested; **ConflictHandler §7 methods ADDED in remediation**; N=5 pagination-aware caching = documented accepted gap (trigger threshold ~500 rows) |
| §8 | RBAC | IMPLEMENTED | 136-pair fixture both repos; buildIfPermitted; ModeRouter driver gate; no admin mobile surface |
| §9 | Convenience | IMPLEMENTED | All 7 items (device verification pending per §13.6) |
| §10 | Visual/Interaction | IMPLEMENTED | 59 golden PNGs light+dark; zero raw hex in features; undo-over-confirm; empty states |
| §11 | Performance | PARTIAL (documented) | Shared-widget micro-benchmarks exist; headline targets (cold start/transition/list render) = device-profiling checklist item (PENDING-DEVICE) |
| §12 | Security | IMPLEMENTED | Biometric ×5, capture prevention, no secret caching, 24h TTL, device-deregistration cascade |
| §13 | QA strategy | IMPLEMENTED (2 notes) | Test pyramid exceeded; golden/RBAC/financial suites green; **Locust /mobile/* scenarios ADDED in remediation**; §13.5 named files = naming mapping documented (intent present); device matrix + airplane script PENDING-DEVICE |
| §14 | Master DoD | MET ×8, PENDING ×2 | Items 6 (device matrix) + 7 (crash-free rate) pending device/beta — honest |
| Part 2 | Phases 0–6 | IMPLEMENTED | All phases + follow-ups shipped; 32 Oracle gates cleared (1–32) |

**Conformance gaps found by the audit and their disposition:** ConflictHandler §7 methods (FIXED), §13.7 Locust mobile endpoints (FIXED), §7 N=5 page-caching (DOCUMENTED accepted gap with trigger threshold), §11 measured targets (DOCUMENTED — device-profiling checklist), §13.5 named test files (DOCUMENTED mapping), §13.1 integration 34 vs ~35+ (DOCUMENTED, executed green).

## 2. Production-Readiness Matrix (A2 audit, updated post-remediation)

| # | Item | Status (pre-remediation) | Status (post-remediation) |
|---|------|--------------------------|---------------------------|
| 1 | Outbound FCM push sender | 🔴 BLOCKED (CRITICAL — no sender) | ✅ **SHIPPED** — PushSender (firebase-admin, NotificationCenter subscription, data-only contract, token cleanup, retry); needs operator `OPERION_FIREBASE_CREDENTIALS` |
| 2 | Firebase platform config | 🔴 BLOCKED (no config files) | 🟡 CONFIG — plugin + fail-fast + APNs prep + `docs/firebase-config.md` done; operator supplies `google-services.json` + `GoogleService-Info.plist` |
| 3 | Release signing / artifact | 🔴 BLOCKED (debug-signed) | 🟡 CONFIG — env-var scaffolding + fail-fast GradleException done; operator supplies keystore + 4 envs (CI release pipeline = follow-up) |
| 4 | Mobile tables on PostgreSQL | 🔴 BLOCKED (absent from schema_pg) | ✅ **SHIPPED** — 3 tables PG-typed + idempotent + validation tests |
| 5 | Env consistency (SUPPORT_INTERNAL_AUTH) | 🟠 MATERIAL | 🟡 CONFIG — actionable error message done; operator sets the real value |
| 6 | Backend Sentry SDK | 🟠 MATERIAL (absent) | ✅ **SHIPPED** — sentry-sdk + DSN no-op init + capture; operator DSN |
| 7 | Tachograph parser deployability | 🟠 MATERIAL | 📄 DOCUMENTED — Wine / Linux-native provisioning story + honest error path |
| 8 | nginx copilot WS proxy | 🟠 MATERIAL | ✅ **SHIPPED** — Upgrade headers location added |
| 9 | Staging port mismatch | 🟠 MATERIAL | ✅ **SHIPPED** — reconciled to 8010 |
| 10 | Notification small icon | 🟠 MATERIAL | ✅ **SHIPPED** — ic_notification_small drawable |
| 11 | minSdk/targetSdk pins | 🟠 MATERIAL | ✅ **SHIPPED** — minSdk 29 / targetSdk 35 (version bump = operator) |
| 12 | API-key gate | INFO | 📄 DOCUMENTED — assert is dev-only; server middleware enforces |
| 13 | Crash-free rate / device matrix / airplane script | ⏳ PENDING-DEVICE | ⏳ PENDING-DEVICE — checklists turnkey, sign-off tables ready |

## 3. Code Remediation Shipped (Gate-31 batch — all verified)

**Backend** (`Calculator logistica`): FCM PushSender (10 tests) · Sentry SDK (6) · Postgres mobile tables + validation (6) · Locust `/mobile/*` scenarios (8) · config error message + nginx WS location + staging port. **tests/mobile 318/318 · loadtest 79/79 · openapi 232 paths.**
**Mobile** (`operion-mobile-app`): release-signing env scaffolding (no debug fallback) · Firebase Gradle plugin + APNs prep + `docs/firebase-config.md` · ConflictHandler §7 methods (32/32 tests) · notification small-icon drawable · minSdk 29/targetSdk 35. **analyze 452 (0 new).**

## 4. Operator Config Checklist (before beta launch — 12 items)

1. `google-services.json` (Firebase console, package `com.operion.operion_mobile`) → `mobile/android/app/`
2. `GoogleService-Info.plist` (bundle `com.operion.operionMobile`) → `mobile/ios/Runner/` + Podfile/pod-install + APNs capability
3. Firebase service-account JSON → `OPERION_FIREBASE_CREDENTIALS`
4. Release keystore + `KEYSTORE_PATH/STORE_PASSWORD/KEY_ALIAS/KEY_PASSWORD` (keytool command in the Gradle error)
5. `OPERION_SENTRY_DSN` (backend + mobile `--dart-define=SENTRY_DSN`)
6. `OPERION_API_KEY` (backend `.env` + mobile `--dart-define`)
7. `OPERION_SUPPORT_INTERNAL_AUTH` real value (`openssl rand -hex 32`)
8. Env consistency: `OPERION_ENV=production` + DB/Redis/Celery connection vars
9. `OPERION_TACHOGRAPH_PATH` (Wine or Linux-native parser) or accept the documented import-unavailable path
10. Version bump from `1.0.0+1`
11. ANAF submission: REMOVED per business decision (Gate-33). `generate_xml` produces the UBL CIUS-RO XML file (stored at `efactura_xml_path`) — the legal deliverable; no external ANAF submission, no flag needed (`submit` → 422 `action_not_supported`)
12. Device profiling pass (cold start / transitions / list renders per §11 + §13.6 checklist) + device-matrix sign-off + airplane-mode manual run + crash-free-rate from the beta

## 5. Documented Items (accepted gaps — honest)

- Tachograph parser provisioning story (Wine / Linux-native / accept-gap)
- API-key assert is dev-only; the server middleware is the real gate
- §7 N=5 pagination-aware caching deferred with trigger threshold (~500 rows)
- §13.5 test-file name mapping (`offline_queue_test` ≈ `action_queue_extended`, `sync_service_test` ≈ `delta_sync_extended`)
- §11 headline performance targets → device-profiling checklist (PENDING-DEVICE)

## 6. Evidence Summary

- Mobile: full suite **2310/2310** · integration **34/34** (Windows, per-file) · analyze **452** (0 errors) · l10n 681/681 · 59 golden PNGs · RBAC 136-pair walk · parity 29/29
- Backend: tests/mobile **318/318** · copilot **3,555/0** · security 354 · contracts 44 · freight 626 · loadtest 79/79 · openapi 232 paths · registry validation 0 errors
- 32 Oracle gates cleared (Gates 1–32), every finding remediated + validated; blueprint reconciled (Appendix A)
- Git: nothing committed in either repo (not requested) — **recommend committing both repos before the beta**, then executing the operator checklist
