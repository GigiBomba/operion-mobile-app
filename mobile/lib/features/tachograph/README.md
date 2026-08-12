# tachograph

Blueprint §4.7 — tachograph data import + compliance.

## Implemented (Phase 4B)

- `models/tacho_compliance.dart` — `TachoComplianceResult` / `TachoDay` /
  `TachoImportJobState` mirroring the backend payloads exactly (including the
  VERBATIM `violations` strings — never recomputed client-side).
- `providers/tacho_providers.dart` — `TachoEndpoints`
  (`POST /mobile/tacho/import` multipart → 202 `{job_id}`;
  `GET /mobile/tacho/import/{job_id}/status`), `tachoImportProvider`
  (idle → uploading(progress) → processing → success|error),
  `tachoImportJobStatusProvider` (3s poll until terminal),
  `tachoFilePickerProvider` (`.ddd`/`.esm` filter), `tachoDriversProvider`
  (driver picker via `driversEndpointsProvider.getDrivers`).
- `screens/tachograph_screen.dart` — driver picker bottom sheet, import button,
  upload `LinearProgressIndicator`, compliance summary card (days + weekly),
  VERBATIM warning banners, weekly-limit circular gauge
  (`weeklyDriving / 3360`, red past 100%).
- **Phase 4B §4.10 Wi-Fi gate**: when "Wi-Fi only for large syncs" is on and
  the device is on cellular, the upload is blocked with an inline message
  (`TachoUploadWifiBlocked`; no network call).

Backend contract source: `Calculator logistica` — `schemas/mobile.py`
(TachoImportJobResponse / TachoComplianceResult / TachoImportJobStatusResponse).
