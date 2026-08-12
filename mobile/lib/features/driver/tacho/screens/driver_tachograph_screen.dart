import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/tacho_week_view.dart';
import '../providers/driver_tacho_providers.dart';

/// Driver tachograph timeline (Tier-2 feature).
///
/// Fetches `GET /api/v1/mobile/driver/tacho` (network-only) and renders the
/// SHARED [TachoWeekView] (weekly driving gauge + 7-day stacked bars — the
/// same widget the teams driver-detail screen uses, so the visuals are
/// identical). The note explains that the data comes from tachograph imports
/// performed by dispatchers.
class DriverTachographScreen extends ConsumerWidget {
  const DriverTachographScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final tachoAsync = ref.watch(driverTachoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(loc.driver_tachograph_title)),
      body: tachoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertCircle, size: 48, color: AppColors.error),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '${loc.general_error}: $e',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(driverTachoProvider),
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: Text(loc.general_retry),
                ),
              ],
            ),
          ),
        ),
        data: (week) => Column(
          children: [
            Expanded(child: TachoWeekView(week: week, loc: loc)),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Text(
                loc.driver_tachograph_note,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
