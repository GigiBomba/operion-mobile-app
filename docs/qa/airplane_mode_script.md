# Airplane-Mode Manual Test Script (Blueprint §13.5)

> **Status:** MANUAL / DEVICE-REQUIRED — run every release on a physical device (§13.5).
> **Purpose:** prove the §7 offline/queue contract end-to-end: queueable mutations enqueue while
> offline and replay on reconnect; blocked mutations stay blocked with inline messaging; the
> 24-hour action-queue TTL surfaces stale actions instead of auto-replaying them.
> **Automated equivalents exist** (unit tests per mutation type + wifi-gate tests) — this script is
> the on-device, real-network proof.

## Pre-conditions

- Device with Wi-Fi + mobile data; backend reachable at the staging URL; logged in as a
  dispatcher/manager test account.
- 1 test truck, 1 test driver, 1 test client seeded (use the staging seed script).
- Record the pre-test server state (list fleet/drivers/clients counts) to diff afterwards.

## Part A — Queueable mutations (fleet/drivers/clients)

1. Enable airplane mode (or kill the network). Note the app shows the offline banner.
2. Create a truck (Fleet FAB) → the mutation must **enqueue** (no error, no spinner hang).
3. Update a driver (Drivers → detail → Edit → save) → **enqueues**.
4. Update a client (Clients → detail → edit) → **enqueues**.
5. Record maintenance on a truck (Truck detail → Maintenance → Record work) → **enqueues**.
6. Add a client contact → **enqueues**.
7. Verify the queue indicator / pending count reflects N queued actions.
8. **Disable airplane mode** → within ~1s the queue must begin replaying FIFO (visible progress
   indicator), and all actions must land: re-fetch fleet/drivers/clients and confirm the created
   truck, updated driver, updated client, maintenance record, and contact are present server-side.
9. Diff against the pre-test state — every queued action must have executed exactly once
   (no duplicates; check the client-generated UUID/idempotency keys if available).

## Part B — Blocked mutations (never queued)

With airplane mode ON:

1. **Merge two clients** → Merge button must be disabled with the inline
   "Merging requires an internet connection" message. NOT queued (reconnect and verify no merge
   happened).
2. Invoice: try **Generate e-Factura XML**, **Submit**, **Mark Paid** → each blocked with the
   "requires connection" inline message; the action queue must remain empty for these.
3. **CMR signature save** → blocked with inline message.
4. **Tachograph .ddd import** → blocked (disabled with inline message).
5. **Trip history export** → blocked with inline message.
6. **Team management** (invite / role change / deactivate) → blocked with inline message.
7. Reconnect → verify NONE of the above executed (server state unchanged).

## Part C — Wi-Fi-only gate (§9 / §4.10 Data Usage)

1. Settings → Data Usage → enable "Wi-Fi only for large syncs".
2. Switch to cellular data (disable Wi-Fi).
3. Attempt a **tachograph upload** and a **history export** → both must be blocked with the inline
   Wi-Fi message (no network call — verify in the backend logs no request arrived).
4. Trigger a delta sync (pull-to-refresh on Records) → sync must **defer** (cursor untouched).
5. Reconnect Wi-Fi → the deferred sync and the blocked uploads now proceed.

## Part D — 24-hour queue TTL (§7/§12)

1. (Requires a seeded stale action — see test/QA tooling or manually backdate a queued action's
   `createdAt` in the local store.)
2. With a queued action older than 24h present, reconnect → the stale action must **NOT
   auto-replay**; the app surfaces "N pending actions need review".
3. Newer queued actions (< 24h) must replay normally.

## Pass criteria

- Part A: all 5 mutation types replay exactly once; server diff matches expectations.
- Part B: all 6 blocked types stay blocked; queue empty; server unchanged after reconnect.
- Part C: cellular blocks + Wi-Fi resumes behave as specified.
- Part D: stale actions surfaced, not replayed.

## Sign-off

| Date | Device/OS | Network conditions | Result (PASS/FAIL) | Tester |
|---|---|---|---|---|
|  |  |  |  |  |
