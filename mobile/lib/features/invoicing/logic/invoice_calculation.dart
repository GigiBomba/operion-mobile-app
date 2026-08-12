/// Invoice line calculation core — Phase 3 Step-1 financial parity.
///
/// Replicates the desktop `services/invoicing/service.py::_calculate_line_items`
/// EXACTLY (banker's rounding, stepwise rounding, qty-or-1.0, discount
/// precedence/cap, pre-set overrides, sequential sums). Blueprint §4.5's
/// idealized formula (Decimal HALF_UP) deliberately NOT used — real desktop
/// behavior wins; see features/invoicing/README.md.
///
/// All money math stays on IEEE-754 doubles (identical to Python floats) and
/// rounds stepwise at every boundary. Aggregates are computed with sequential
/// left-to-right additions in line order — byte-identical to the desktop.
library;

import 'dart:typed_data';

/// Banker's rounding to 2 decimals, reproducing Python `round(x, 2)`
/// bit-for-bit on IEEE-754 doubles.
///
/// Python's `round` operates on the EXACT binary value of the double, not on
/// `x * 100` — the double multiplication itself can round a value onto a false
/// tie (e.g. `3 * 0.005 * 100 == 1.5` exactly, yet Python `round(3 * 0.005, 2)
/// == 0.01`). This helper therefore scales the exact value (mantissa × 2^e)
/// by 100 with arbitrary-precision arithmetic and rounds the resulting
/// rational to the nearest integer, ties going to even:
/// `0.125 → 0.12`, `-0.125 → -0.12`, `2.675 → 2.67`.
double round2(double value) {
  if (!value.isFinite) return value;
  if (value == 0) return value; // Preserve -0.0 (Python round(-0.0, 2) == -0.0).

  // Extract the exact binary representation: value = mantissa * 2^e.
  final data = ByteData(8)..setFloat64(0, value);
  final bits = data.getUint64(0);
  final negative = bits & 0x8000000000000000 != 0;
  final exponentBits = ((bits >> 52) & 0x7FF).toInt();
  final significand = bits & 0xFFFFFFFFFFFFF;

  final int mantissa;
  final int e;
  if (exponentBits == 0) {
    // Subnormal: no implicit leading bit.
    mantissa = significand.toInt();
    e = -1074;
  } else {
    mantissa = (significand | 0x10000000000000).toInt();
    e = exponentBits - 1075;
  }

  // R = round_even(exact_value * 100) = round_even(mantissa * 100 * 2^e).
  final p = BigInt.from(mantissa) * BigInt.from(100);
  final BigInt rounded;
  if (e >= 0) {
    rounded = p << e; // Already an exact integer — no rounding needed.
  } else {
    final denominator = BigInt.one << (-e);
    final q = p ~/ denominator;
    final r = p % denominator;
    final half = denominator >> 1;
    if (r < half) {
      rounded = q;
    } else if (r > half) {
      rounded = q + BigInt.one;
    } else {
      rounded = q.isEven ? q : q + BigInt.one; // Exact tie → even.
    }
  }

  final magnitude = rounded.toDouble() / 100.0;
  return negative ? -magnitude : magnitude;
}

/// One invoice line item, mirroring the desktop `InvoiceLineItem` JSON.
///
/// Nullable fields reproduce Python's semantics exactly:
/// - `quantity` (null OR 0 → treated as 1.0)
/// - `unitPrice`, `discountPercent`, `discountAmount`, `vatRate`
///   (null OR 0 → treated as 0.0)
/// - `taxableAmount`, `vatAmount`, `lineTotal` are pre-set OVERRIDES:
///   only null falls back to the computed value (an explicit 0 is respected).
class InvoiceLineCalcInput {
  const InvoiceLineCalcInput({
    required this.description,
    this.quantity,
    this.unitOfMeasure,
    this.unitPrice,
    this.discountPercent,
    this.discountAmount,
    this.taxableAmount,
    this.vatRate,
    this.vatAmount,
    this.lineTotal,
  });

  final String description;
  final double? quantity;
  final String? unitOfMeasure;
  final double? unitPrice;
  final double? discountPercent;
  final double? discountAmount;
  final double? taxableAmount;
  final double? vatRate;
  final double? vatAmount;
  final double? lineTotal;

  /// Reads the snake_case desktop JSON shape (e.g. `unit_price`).
  factory InvoiceLineCalcInput.fromJson(Map<String, dynamic> json) {
    double? asDouble(Object? raw) => raw is num ? raw.toDouble() : null;
    return InvoiceLineCalcInput(
      description: json['description'] as String? ?? '',
      quantity: asDouble(json['quantity']),
      unitOfMeasure: json['unit_of_measure'] as String?,
      unitPrice: asDouble(json['unit_price']),
      discountPercent: asDouble(json['discount_percent']),
      discountAmount: asDouble(json['discount_amount']),
      taxableAmount: asDouble(json['taxable_amount']),
      vatRate: asDouble(json['vat_rate']),
      vatAmount: asDouble(json['vat_amount']),
      lineTotal: asDouble(json['line_total']),
    );
  }
}

/// A fully computed line item, mirroring the desktop output JSON.
class InvoiceLineCalcResult {
  const InvoiceLineCalcResult({
    required this.description,
    required this.quantity,
    required this.unitOfMeasure,
    required this.unitPrice,
    required this.discountPercent,
    required this.discountAmount,
    required this.taxableAmount,
    required this.vatRate,
    required this.vatAmount,
    required this.lineTotal,
  });

  final String description;
  final double quantity;
  final String unitOfMeasure;
  final double unitPrice;
  final double discountPercent;
  final double discountAmount;
  final double taxableAmount;
  final double vatRate;
  final double vatAmount;
  final double lineTotal;

  /// Always null on the desktop — the `total_net` field stays null.
  final double? totalNet = null;
}

/// Aggregate result of [calculateInvoiceLines].
class InvoiceCalculationResult {
  const InvoiceCalculationResult({
    required this.lines,
    required this.subtotalNet,
    required this.totalVat,
    required this.totalGross,
  });

  final List<InvoiceLineCalcResult> lines;
  final double subtotalNet;
  final double totalVat;
  final double totalGross;
}

/// Computes every line item and the invoice aggregates, replicating
/// `_calculate_line_items` in `services/invoicing/service.py` exactly.
///
/// Line semantics (stepwise, per line):
/// 1. `qty = quantity or 1.0`, `price = unit_price or 0.0`,
///    `gross = round2(qty * price)`.
/// 2. `discount_pct = discount_percent or 0.0`,
///    `discount_amt = discount_amount or 0.0`; when `discount_amt == 0` and
///    `discount_pct > 0` it is derived as `round2(gross * pct / 100)`; then
///    capped: `discount_amt = min(discount_amt, gross)`.
/// 3. `taxable = taxable_amount ?? round2(gross - discount_amt)`.
/// 4. `vat_rate = vat_rate or 0.0`,
///    `vat_amount = vat_amount ?? round2(taxable * vat_rate / 100)`.
/// 5. `line_total = line_total ?? round2(taxable + vat_amount)`.
///    `unit_of_measure` defaults to `'buc'`; `total_net` stays null.
///
/// Aggregates are the sequential left-to-right float sums of the per-line
/// values (in input order), each rounded via [round2] — byte-identical to
/// Python's `round(sum(...), 2)`.
InvoiceCalculationResult calculateInvoiceLines(
  List<InvoiceLineCalcInput> inputs,
) {
  final lines = <InvoiceLineCalcResult>[];
  var subtotalNet = 0.0;
  var totalVat = 0.0;
  var totalGross = 0.0;

  for (final li in inputs) {
    // Python `x or fallback`: both null and 0 fall through (NOT `??` alone).
    final qty = (li.quantity == null || li.quantity == 0) ? 1.0 : li.quantity!;
    final price =
        (li.unitPrice == null || li.unitPrice == 0) ? 0.0 : li.unitPrice!;
    final grossValue = round2(qty * price);

    final discountPct = (li.discountPercent == null || li.discountPercent == 0)
        ? 0.0
        : li.discountPercent!;
    var discountAmt = (li.discountAmount == null || li.discountAmount == 0)
        ? 0.0
        : li.discountAmount!;
    if (discountAmt == 0 && discountPct > 0) {
      discountAmt = round2(grossValue * discountPct / 100);
    }
    if (discountAmt > grossValue) {
      discountAmt = grossValue;
    }

    final taxableAmount =
        li.taxableAmount ?? round2(grossValue - discountAmt);
    final vatRate = (li.vatRate == null || li.vatRate == 0) ? 0.0 : li.vatRate!;
    final vatAmount = li.vatAmount ?? round2(taxableAmount * vatRate / 100);
    final lineTotal = li.lineTotal ?? round2(taxableAmount + vatAmount);

    subtotalNet += taxableAmount;
    totalVat += vatAmount;
    totalGross += lineTotal;

    lines.add(InvoiceLineCalcResult(
      description: li.description,
      quantity: qty,
      unitOfMeasure: li.unitOfMeasure ?? 'buc',
      unitPrice: price,
      discountPercent: discountPct,
      discountAmount: discountAmt,
      taxableAmount: taxableAmount,
      vatRate: vatRate,
      vatAmount: vatAmount,
      lineTotal: lineTotal,
    ));
  }

  return InvoiceCalculationResult(
    lines: lines,
    subtotalNet: round2(subtotalNet),
    totalVat: round2(totalVat),
    totalGross: round2(totalGross),
  );
}
