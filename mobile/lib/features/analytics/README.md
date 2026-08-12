# Analytics

Blueprints §4.4 / §6.4.

## Screen

`analytics_screen.dart` — four tabs driven by a shared `DateRange` in
`analyticsDateRangeProvider`:

- **Revenue** — `LineChart` (trend) + `BarChart` (per-client/per-route via a
  `SegmentedButton` toggle).
- **Fleet Utilization** — `PieChart` (status split) + a per-truck row list
  (trip count / total km).
- **Driver Performance** — sortable `DataTable` (trips completed / on-time % /
  profit-per-km / revenue).
- **Invoice Aging** — `BarChart` of the four real buckets
  (current / 31–60 / 61–90 / 90+).

Export (`IconButton(Icons.ios_share)` in the AppBar) calls the sync export
endpoint and opens the OS share sheet with the signed URL. Offline the export
is disabled with an inline message — exports are never queued (§7).

## Deviations (REAL WINS)

- **Driver Performance has no rating column.** The real backend
  (`AnalyticsService.get_driver_comparison`) exposes no driver-rating field,
  so the table shows trips/OTD%/profit-per-km/revenue only — §4.4's "avg
  rating" was not available.
- **401/403 surface as the tab error state** (no cache fallback — charts are
  pure network to avoid drift from desktop numbers).
- **Empty datasets render `EmptyState`** (never a zero-data chart) — a new
  company has no history, matching the `_EmptySection` precedent.
