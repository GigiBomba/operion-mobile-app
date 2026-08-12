import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../features/teams/models/tacho.dart';
import 'app_card.dart';
import 'empty_state.dart';

/// Shared 7-day tacho timeline (extracted from the teams driver-detail screen
/// so the driver tachograph screen renders the SAME visual output).
///
/// Weekly driving gauge + one stacked bar per day. [TachoWeek] /
/// [TachoDay] come from `teams/models/tacho.dart` (shared); [loc] provides the
/// localized labels. Visual output is intentionally byte-identical to the
/// original private teams implementation — the teams screen renders the exact
/// same widget after the extraction.
class TachoWeekView extends StatelessWidget {
  const TachoWeekView({super.key, required this.week, required this.loc});

  final TachoWeek week;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gaugeValue = week.weeklyLimitMinutes > 0
        ? (week.weeklyDrivingMinutes / week.weeklyLimitMinutes).clamp(0.0, 1.0)
        : 0.0;
    final overLimit = week.isOverLimit;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Weekly gauge.
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: gaugeValue,
                        strokeWidth: 8,
                        backgroundColor: AppColors.neutralSubtle,
                        color: overLimit ? AppColors.error : AppColors.success,
                      ),
                      Text(
                        '${week.weeklyDrivingMinutes}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: overLimit ? AppColors.error : AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.teams_weeklyDriving,
                          style: theme.textTheme.titleSmall),
                      Text(
                        '${loc.teams_weeklyLimit} ${week.weeklyLimitMinutes}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: overLimit
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (overLimit)
                        Text(
                          loc.teams_weeklyOverLimit,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // 7-day stacked bars.
        if (week.days.isEmpty)
          EmptyState(
            icon: const Icon(LucideIcons.clock, size: 56),
            title: loc.teams_tachoEmpty,
          )
        else
          for (final day in week.days)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: TachoDayBar(day: day, loc: loc),
            ),
      ],
    );
  }
}

/// A single day's stacked activity bar (driving / working / rest / other).
class TachoDayBar extends StatelessWidget {
  const TachoDayBar({super.key, required this.day, required this.loc});

  final TachoDay day;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = [
      (day.drivingMinutes, AppColors.accent, loc.tacho_driving),
      (day.workingMinutes, AppColors.info, loc.tacho_working),
      (day.restMinutes, AppColors.success, loc.tacho_rest),
      (day.otherMinutes, AppColors.neutralSubtle, loc.tacho_availability),
    ];
    final total = segments.fold<int>(0, (sum, s) => sum + s.$1);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    day.date == null
                        ? '—'
                        : '${day.date!.day}/${day.date!.month}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Text(
                  '${loc.tacho_driving} ${day.drivingMinutes}m',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    for (final s in segments)
                      if (s.$1 > 0)
                        Expanded(
                          flex: total > 0 ? s.$1 : 1,
                          child: Container(color: s.$2),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              children: [
                for (final s in segments)
                  Text(
                    '${s.$3} ${s.$1}m',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
