# invoicing

<!-- ADR-2026-08-01 — PDF viewer choice (blueprint §4.5)
  DECISION: Use `pdfx` for PDF preview over `syncfusion_flutter_pdfviewer`.
  REASONS:
  - License: pdfx is BSD-3; Syncfusion requires the Community License
    registration, which imposes revenue/team-size eligibility limits.
  - Maintenance: pdfx is actively maintained and web/WASM-ready; our PDFs are
    server-rendered, so a lightweight viewer is sufficient.
  - Money math: `decimal` is mandated by §4.5 for byte-identical money
    arithmetic (no binary floating point on invoice totals).
-->

<!-- ADR-2026-08-02 — Invoice calculation core (Phase 3 Step-1 financial parity)
  DECISION: The mobile calculation core (`logic/invoice_calculation.dart`)
  replicates the DESKTOP `services/invoicing/service.py::_calculate_line_items`
  exactly — IEEE-754 doubles, Python `round(x, 2)` banker's rounding (ties-to-
  even on the exact binary value), stepwise rounding, qty-or-1.0, discount
  precedence/cap, pre-set overrides, and sequential left-to-right sums.
  Verified byte-identical against `test/test_vectors/invoice_calculations.json`.
  DEVIATION FROM §4.5: the blueprint's idealized Decimal HALF_UP formula is
  deliberately NOT used — the vendored vectors prove desktop behavior differs
  (e.g. 3 * 0.005 rounds to 0.01, a stepwise-rounded .xx5 case), and the mobile
  app must render invoices that match the desktop/PFD byte-for-byte. The
  `decimal` package remains in pubspec for DISPLAY/FORMATTING needs in Phase 3,
  not for the calculation core.
-->

Phase 0 scaffolding placeholder. Blueprint §4.5.

This feature will hold the invoice editor, CMR generation, and e-Factura:

- `models/` — invoice, CMR, and e-Factura models.
- `providers/` — invoice list/detail, draft persistence, transitions.
- `screens/` — invoice list, invoice editor, CMR editor.
- `widgets/` — line-item editors, PDF preview, totals panel.

PDF preview uses `pdfx` (see ADR below). Money math uses `decimal` for
byte-identical arithmetic mandated by §4.5.

Screens/providers arrive in Phase 1+; only the directory skeleton exists today.
