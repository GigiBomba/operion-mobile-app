import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../teams/providers/teams_providers.dart' show kExpiringLicensesDefaultDays;

/// Expiry status badge (blueprint §4.2 compliance view).
///
/// Thresholds use the real backend constant [kExpiringLicensesDefaultDays]
/// (30 days — `driver_repository.get_expiring_licenses` default):
/// - `daysRemaining < 0` → red `EXPIRED`;
/// - `daysRemaining <= 30` → amber `N d`;
/// - otherwise → green formatted date.
///
/// [now] is injectable so tests can pin the clock.
class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({super.key, required this.expiry, this.now});

  final DateTime? expiry;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    if (expiry == null) return const SizedBox.shrink();

    final reference = now ?? DateTime.now();
    final days = expiry!.difference(reference).inDays;

    final (Color textColor, Color bgColor, String label) = days < 0
        ? (AppColors.errorText, AppColors.errorSubtle, loc.teams_expired)
        : days <= kExpiringLicensesDefaultDays
            ? (
                AppColors.warningText,
                AppColors.warningSubtle,
                '$days ${loc.teams_daysShort}',
              )
            : (AppColors.successText, AppColors.successSubtle, _formatDate(expiry!));

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

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}
