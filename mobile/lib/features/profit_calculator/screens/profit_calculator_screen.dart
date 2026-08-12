import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/calculator_logic.dart';

/// Profit Calculator screen — a pure client-side form.
///
/// Revenue minus costs with no backend calls.
class ProfitCalculatorScreen extends ConsumerStatefulWidget {
  const ProfitCalculatorScreen({super.key});

  @override
  ConsumerState<ProfitCalculatorScreen> createState() =>
      _ProfitCalculatorScreenState();
}

class _ProfitCalculatorScreenState
    extends ConsumerState<ProfitCalculatorScreen> {
  final _priceCtrl = TextEditingController();
  final _fuelCtrl = TextEditingController();
  final _tollCtrl = TextEditingController();
  final _driverCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();

  ProfitCalculation? _result;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _fuelCtrl.dispose();
    _tollCtrl.dispose();
    _driverCtrl.dispose();
    _extraCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final fuel = double.tryParse(_fuelCtrl.text) ?? 0;
    final toll = double.tryParse(_tollCtrl.text) ?? 0;
    final driver = double.tryParse(_driverCtrl.text) ?? 0;
    final extra = double.tryParse(_extraCtrl.text) ?? 0;

    setState(() {
      _result = ProfitCalculation(
        price: price,
        fuelCost: fuel,
        tollCost: toll,
        driverCost: driver,
        extraCosts: extra,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final currencySymbol = loc.profitCalculator_currencySymbol;

    return Scaffold(
      appBar: AppBar(title: Text(loc.nav_profitCalculator)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Input form ──────────────────────────────────────────
            AppTextField(
              controller: _priceCtrl,
              labelText: loc.profitCalculator_price,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _fuelCtrl,
              labelText: loc.profitCalculator_fuelCost,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _tollCtrl,
              labelText: loc.profitCalculator_tollCost,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _driverCtrl,
              labelText: loc.profitCalculator_driverCost,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _extraCtrl,
              labelText: loc.profitCalculator_extraCosts,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Calculate button ────────────────────────────────────
            AppButton.primary(
              label: loc.profitCalculator_calculate,
              onPressed: _calculate,
            ),

            // ── Results ─────────────────────────────────────────────
            if (_result != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ResultRow(
                      label: loc.profitCalculator_totalCosts,
                      value: '$currencySymbol${_result!.totalCosts.toStringAsFixed(2)}',
                    ),
                    const Divider(height: AppSpacing.lg),
                    _ResultRow(
                      label: loc.profitCalculator_profit,
                      value: _result!.formatProfit(currencySymbol),
                      valueStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _result!.profit >= 0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                    ),
                    const Divider(height: AppSpacing.lg),
                    _ResultRow(
                      label: loc.profitCalculator_profitMargin,
                      value:
                          '${_result!.profitMargin.toStringAsFixed(2)}%',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge,
          ),
          Text(
            value,
            style: valueStyle ?? theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
