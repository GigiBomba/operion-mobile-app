# History — Trip History & Route History

Blueprints §4.8 / §6.8.

## Screens

- `trip_history_screen.dart` — filterable (status chips / date range / client)
  paginated `ListView` (20/page) with pull-to-refresh and infinite scroll.
  Export (`POST /mobile/history/trips/export`) is a fire-and-forget async job:
  snackbar "Export started — you will be notified when ready", then the
  `exportJobStatusProvider` polls `GET /mobile/history/trips/export/{job_id}/status`
  every 3 seconds until a terminal state, then opens the OS share sheet with
  the downloaded file.
- `route_history_screen.dart` — same list pattern. Rows show name,
  origin→destination, distance/duration and date.

## Honest omissions (no backend endpoint exists)

- **Route duplicate/archive actions** — the desktop has duplicate/archive
  route actions, but there is **no** `/mobile/history/routes/{id}/duplicate`
  or `.../archive` endpoint in the §6.8 contract. These are intentionally
  absent from the UI rather than stubbed with a dead button.
- **Route map thumbnail** — the contract's `RouteHistoryOut` has no
  pre-rendered thumbnail URL, and we do not snapshot `flutter_map` client-side
  (cost/bandwidth). Route rows show route info text instead.

These are flagged for a future phase if the backend adds the endpoints.

## Export contract (shared with Analytics)

Exports are **never queued offline** (§7): the export action is disabled with
an inline "Export requires an internet connection" message when `isOfflineProvider`
is true, matching the `mergeClients` pattern.
