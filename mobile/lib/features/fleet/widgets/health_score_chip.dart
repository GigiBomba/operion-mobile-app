import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// A colored health-score chip for a truck (blueprint §4.1).
///
/// Score thresholds: `>= 80` green, `50–79` amber, `< 50` red. `null`/absent
/// scores render a neutral dash chip.
class HealthScoreChip extends StatelessWidget {
  const HealthScoreChip({super.key, this.score});

  final double? score;

  @override
  Widget build(BuildContext context) {
    final (Color textColor, Color bgColor, String label) = switch (score) {
      null => (AppColors.neutralText, AppColors.neutralSubtle, '—'),
      final s when s >= 80 => (
          AppColors.successText,
          AppColors.successSubtle,
          s.round().toString(),
        ),
      final s when s >= 50 => (
          AppColors.warningText,
          AppColors.warningSubtle,
          s.round().toString(),
        ),
      final s => (AppColors.errorText, AppColors.errorSubtle, s.round().toString()),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.2,
        ),
      ),
    );
  }
}
