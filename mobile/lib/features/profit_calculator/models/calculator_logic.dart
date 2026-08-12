/// Pure client-side profit calculator aligned with the desktop Calculator
/// module. No backend calls.
///
/// Field set mirrors the desktop source exactly:
/// `Calculator profit/Calculator_profit.py:607`
///   profit = preto - cost_combustibil - taxa_total - salariu - costuri_extra
/// i.e. `profit = price - fuelCost - tollCost - driverCost - extraCosts`.
class ProfitCalculation {
  /// Total price (revenue) for the trip (`preto` on desktop).
  final double price;

  /// Fuel cost (`cost_combustibil`).
  final double fuelCost;

  /// Toll cost (`taxa_total`).
  final double tollCost;

  /// Driver salary (`salariu`).
  final double driverCost;

  /// Extra costs (`costuri_extra`; desktop auto-computes
  /// `round((km * 0.03) + (durata_zile * 12), 2)` — see
  /// `Calculator profit/Calculator_profit.py:583-586`).
  final double extraCosts;

  const ProfitCalculation({
    required this.price,
    required this.fuelCost,
    required this.tollCost,
    required this.driverCost,
    required this.extraCosts,
  });

  double get totalCosts =>
      fuelCost + tollCost + driverCost + extraCosts;

  double get profit => price - totalCosts;

  double get profitMargin =>
      price > 0 ? (profit / price) * 100 : 0.0;

  /// Returns profit formatted to 2 decimal places with currency symbol.
  String formatProfit(String currencySymbol) =>
      '$currencySymbol${profit.toStringAsFixed(2)}';
}
