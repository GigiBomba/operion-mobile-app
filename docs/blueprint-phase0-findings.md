# Phase 0 — Audit Findings (Blueprint §12 Phase 0 / §13 OD-1..OD-5)

**Blueprint:** `Operion_Mobile_Restructure_Blueprint.md` (999 lines, authoritative)
**Repos audited:** `operion-mobile-app/mobile/` + `Calculator logistica/` (sibling FastAPI monorepo)
**Audit date:** 2026-07-31 (findings consolidated from the implementation session; literal evidence = test artifacts + code refs below)
**Status:** All five OD items resolved. This document is the Phase 0 deliverable required by §12 before feature phases; features have since been implemented against these findings and re-verified.

---

## OD-1 — Route geometry availability (resolved: compute fresh via GraphHopper; endpoint added)

**Finding:** No geometry-bearing mobile endpoint existed before this work. Desktop route planning computes geometry via GraphHopper in `services/route_service.py`; the mobile surface needed a new endpoint.

**Delivered contract (matches blueprint §5.1 `RouteShareGeometry`):**
`GET /api/v1/mobile/driver/transports/{transport_id}/route-share` → `RouteShareResponse`:
- `points`: `[{lat: float, lng: float}, ...]`
- `instructions`: `[{text_key: str, distance_meters: float, point_index: int}, ...]` (empty if unavailable)
- `total_distance_meters`: float, `total_duration_seconds`: int
- `generated_at`: ISO-8601, `ttl_seconds`: int

Plus a JWT-resolved variant matching the mobile call path:
`GET /api/v1/mobile/driver/route-share` (no path transport id — server resolves the driver's current non-terminal transport; 404 when none; shares `_build_route_share_response` so both endpoints are byte-identical).

**Artifact:** `tests/contracts/test_route_share_geometry_schema.py` + `tests/contracts/test_route_share_jwt_endpoint.py` — 27/27 contract tests pass (`pytest tests/contracts/ -v`).

---

## OD-2 — "Teams" vs "Route Planner" naming (resolved, traceability only)

Teams = enhanced Drivers/roster view over the existing `GET /drivers` data — no new backend entity, no `Team` table. Route Planner = multi-stop trip optimization via GraphHopper. Two unrelated features (§6.2). Implemented accordingly: `lib/features/teams/` (filter chips All/Available/Driving/Off + `teams_providers.dart`) and `lib/features/route_planner/` (real `POST /api/v1/routes/calculate` wiring via `RoutesEndpoints`).

---

## OD-3 — Turn-by-turn instruction source (resolved: GraphHopper returns instructions; text→`text_key` client-side)

**Finding (from `services/route_service.py`, `_build_route_result` lines 364-376):** the GraphHopper client returns:
- `distance_km`: float, `duration_min`: float
- `geometry`: list of `(lat, lng)` tuples
- `instructions`: `[{text, distance_meters, time_seconds, sign, interval_start, interval_end, point_index}]` — instructions ARE present (GraphHopper `instructions=true` default retained)
- `graphhopper_response`: raw dict; `routing_method`: "POST" | "GET"

**Contract decision applied:** mobile `RouteInstruction.textKey` is resolved client-side from backend `text` (blueprint §5.1's `text_key` semantics — the Dart model holds the key, screens resolve via `t()`). `test_route_share_geometry_schema.py` round-trips the fixture on the Python side against the Dart contract; instructions degrade to geometry-only UI when empty (never fabricated).

**Artifact:** `tests/contracts/test_route_share_geometry_schema.py` (passing, in the 27).

---

## OD-4 — Driver RBAC permission audit (resolved: matrix defined + enforced at runtime)

**Finding (from the actual permission resolution path):** tool filtering existed (`backend/copilot/context.py` `resolve_available_tools`, tool `required_permission` in `backend/copilot/tools/base.py`) but was NOT wired into the production request path (`copilot_router.py` → `process_utterance()` → `planner.py` `get_tool()` had no role check) — a driver could have executed `analytics.query`. Fixed during the session.

**Actual `driver` role permission set (single source of truth: `backend/copilot/role_permissions.py`):**
- ✅ Allowed: `help.answer_question`, `help.guide_workflow` (Level 0, ungated); `route.calculate`, `route.estimate_cost` (own assigned trip only); `driver.check_hours` (own hours); `tracking.get_live_positions` (own vehicle only); `document.ocr_import`, `document.auto_rename` (own uploads); `trip.update` (own trip only, Level 2, tap confirmation required).
- ❌ Excluded: `analytics.query`, `client.payment_summary`, `trip.calculate_profitability`, `payment.generate_bulk_csv`; all Level 2/3 outside own trip (`dispatch.*`, `invoice.*`, `client.*`, `vehicle.*`, `driver.create/update/remove`, `route.create/update/delete`, `maintenance.schedule`); Freight Exchange / Route Planner multi-trip / Teams tools.

**Runtime enforcement:** per-request `get_role_permissions(role)` → `resolve_available_tools(global_ctx, user_perms)` in `copilot_router.py` for `/chat` and `/voice`; denied intent → `copilot.error.permission_denied` clarification, empty timeline, null plan_id; defense-in-depth check in `compile_execution_plan`.

**Artifact:** `tests/copilot/test_driver_rbac_scope.py` — 10 registry-level tests (driver excludes the 4 confidential-info tools + owns own-trip tools; dispatcher/manager include; matrix/registry consistency) + 4 runtime-enforcement tests (driver → analytics intent → denial surfaced over the real endpoint). `pytest tests/copilot/ -v` → 3500 passed / 81 skipped / 2 xpassed.

---

## OD-5 — Service-layer "own record" scoping (resolved: company scoping verified + hardened)

**Finding:** mobile endpoints already scoped by `company_id` from the JWT (`backend/api/v1/mobile.py`: `company_id = current_user["company_id"]`, `WHERE t.id = ? AND t.company_id = ?` patterns); `TripRepository` scoped. BUT the broader repository layer had cross-tenant holes (trip/client/driver/fleet read/update/delete paths returned 200/422 instead of 404 — 17 failing security tests, some real IDORs). Fixed during the session.

**Post-fix state (the path `ToolExecutionContext` exercises carries `role` + `company_id`):**
- Repositories now use explicit company scoping helpers (`repositories/__init__.py` `_company_filter_for`/`_company_params_for`) across `trip_repository`, `client_repository`, `driver_repository`, `fleet_repository` + create-time tenant stamping.
- Cross-tenant reads/updates/deletes → 404; list/search/pagination + client-invoice reads company-scoped.
- Endpoints never accept client-supplied `company_id` (JWT-only).

**Artifact:** `tests/security/` — 305 passed / 23 skipped / 0 failures, including `test_realworld_attacks.py` (cross-tenant now asserts 404), `test_tenant_isolation.py`, `test_concurrent_multi_tenant.py`, `test_local_download_company_isolation.py`, `test_mobile_security.py`. Contract suites: `tests/contracts/` 27/27.

---

## Consolidated residual risks carried forward (see blueprint-completion deepwork state)

1. Local Download manifest contract (§5.3) — current implementation returns metadata without signed short-lived URLs; blueprint contract (signed URLs + tenant-checked fetch + replay-rejection test) not yet satisfied. **Decision pending Gate 1.**
2. OCR endpoint (§5.4) — blueprint's `POST /api/v1/ocr/process` does not exist; existing `/ocr/run` returns extracted fields synchronously (blueprint violation). **Decision pending Gate 1.**
3. Profit Calculator formula (§6.1) — mobile formula differs from desktop (`Calculator profit/Calculator_profit.py`). **Decision pending Gate 1.**
4. CancelToken (§1.2) / pull-to-refresh (§1.2) compliance on new feature screens. **Pending Gate 1 scope decision.**
5. Route Planner desktop/mobile parity test file (`tests/copilot/test_route_planner_desktop_mobile_parity.py`, blueprint §11) — not present; scriptable via backend test client per §6.2. **Pending.**
6. Teams `driver_detail_screen.dart` (§6.2) — backend `GET /api/v1/drivers/{driver_id}` EXISTS with license fields (`license_number`, `license_category`, `license_expiry`, `medical_expiry`); mobile detail screen + endpoints method not yet built. **Pending.**
7. Freight Exchange mobile (§6.3) — placeholder screen; no provider/list/detail/Accept & Assign. **Pending.**
8. Environment-limited gates (§7.2.4 GPS drive-test background screenshots; §8.2 desktop Copilot parity): require physical device / desktop client not present in reachable repos → blueprint adaptation needed. **Pending Gate 1.**
