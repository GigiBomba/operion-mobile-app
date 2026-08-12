# Global Search

Blueprints §3 / §6.11.

## Screen

`global_search_screen.dart` — debounced (350ms) cross-entity search over
trips/clients/drivers/trucks/documents. Each result type is capped at 5
items with an "N more" line when `total_count` exceeds the shown items.

Navigation taps:
- clients → `ClientDetailScreen`
- drivers → `DriverDetailScreen`
- trucks → `TruckDetailScreen`
- trips / documents → **informational tiles only** (no detail route) — the
  backend exposes no trip/document detail endpoint for the search contract,
  so this is an honest omission rather than a dead tap.

## Search icon placement

The persistent `IconButton(Icons.search)` is added to the AppBars of:

- `records_screen.dart`
- `more_hub_screen.dart`
- `dispatcher_home_screen.dart` (a minimal AppBar was ADDED — the home tab
  previously had none; layout otherwise unchanged)
- `job_list_screen.dart`
- `copilot_screen.dart`

`fleet_map_screen.dart` is **skipped**: it is an immersive live map with no
AppBar by design, so the search icon does not fit its chrome. Flagged for a
future phase if a map toolbar is introduced.
