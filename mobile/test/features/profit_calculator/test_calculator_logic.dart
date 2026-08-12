import 'package:flutter_test/flutter_test.dart';
import 'package:operion_mobile/features/profit_calculator/models/calculator_logic.dart';

void main() {
  group('ProfitCalculation — desktop parity', () {
    // ────────────────────────────────────────────────────────────────────────
    // Reference: Calculator profit/Calculator_profit.py
    //
    // Formula (line 607):
    //   profit = preto - cost_combustibil - taxa_total - salariu - costuri_extra
    //   i.e.   profit = price  - fuelCost       - tollCost   - driverCost - extraCosts
    //
    // costuri_extra auto-compute (lines 583-586):
    //   costuri_extra = round((km * 0.03) + (durata_zile * 12), 2)
    //
    // Reference trip used for all three fixed sets (values independently
    // computed from the desktop source):
    //   km = 1000, durata_zile = 10
    //   => costuri_extra = round((1000 * 0.03) + (10 * 12), 2)
    //                   = round(30.0 + 120.0, 2) = 150.00
    // ────────────────────────────────────────────────────────────────────────
    const extraCosts = 150.0;

    test('profitable trip', () {
      // Desktop inputs: preto=5000, combustibil=1800, taxa=350,
      //                 salariu=1000, costuri_extra=150.00
      // profit = 5000 - 1800 - 350 - 1000 - 150 = 1700.00
      // (matches Calculator_profit.py:607)
      const calc = ProfitCalculation(
        price: 5000,
        fuelCost: 1800,
        tollCost: 350,
        driverCost: 1000,
        extraCosts: extraCosts,
      );
      expect(calc.totalCosts, closeTo(3300.00, 0.001));
      expect(calc.profit, closeTo(1700.00, 0.001));
      expect(calc.profitMargin, closeTo(34.00, 0.01));
      expect(calc.formatProfit('\$'), '\$1700.00');
    });

    test('break-even trip', () {
      // Desktop inputs: preto=3300, combustibil=1800, taxa=350,
      //                 salariu=1000, costuri_extra=150.00
      // profit = 3300 - 1800 - 350 - 1000 - 150 = 0.00
      const calc = ProfitCalculation(
        price: 3300,
        fuelCost: 1800,
        tollCost: 350,
        driverCost: 1000,
        extraCosts: extraCosts,
      );
      expect(calc.totalCosts, closeTo(3300.00, 0.001));
      expect(calc.profit, closeTo(0.00, 0.001));
      expect(calc.profitMargin, closeTo(0.00, 0.01));
      expect(calc.formatProfit('\$'), '\$0.00');
    });

    test('loss trip', () {
      // Desktop inputs: preto=2500, combustibil=1800, taxa=350,
      //                 salariu=1000, costuri_extra=150.00
      // profit = 2500 - 1800 - 350 - 1000 - 150 = -800.00
      const calc = ProfitCalculation(
        price: 2500,
        fuelCost: 1800,
        tollCost: 350,
        driverCost: 1000,
        extraCosts: extraCosts,
      );
      expect(calc.totalCosts, closeTo(3300.00, 0.001));
      expect(calc.profit, closeTo(-800.00, 0.001));
      expect(calc.profitMargin, closeTo(-32.00, 0.01));
      expect(calc.formatProfit('\$'), '\$-800.00');
    });

    test('zero price yields zero profit margin (desktop guard: preto > 0)', () {
      // Desktop: margin = (profit / preto * 100) if preto > 0 else 0
      // (Calculator_profit.py:636)
      const calc = ProfitCalculation(
        price: 0,
        fuelCost: 100,
        tollCost: 50,
        driverCost: 30,
        extraCosts: 20,
      );
      expect(calc.totalCosts, closeTo(200.00, 0.001));
      expect(calc.profit, closeTo(-200.00, 0.001));
      expect(calc.profitMargin, 0);
    });
  });
}
