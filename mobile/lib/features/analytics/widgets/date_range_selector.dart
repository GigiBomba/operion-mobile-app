import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/date_range.dart';
import '../providers/analytics_providers.dart';

/// Segmented date-range selector for the analytics tabs (§4.4).
///
/// Presets `7d / 30d / QTD / YTD / Custom`; `Custom` opens
/// [showDateRangePicker]. Every selection writes [analyticsDateRangeProvider].
class DateRangeSelector extends ConsumerWidget {
  const DateRangeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final selected = ref.watch(analyticsDateRangeProvider);
    final current = _presetForRange(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<DateRangePreset>(
            segments: [
              ButtonSegment(
                value: DateRangePreset.last7Days,
                label: Text(loc.analytics_7d),
              ),
              ButtonSegment(
                value: DateRangePreset.last30Days,
                label: Text(loc.analytics_30d),
              ),
              ButtonSegment(
                value: DateRangePreset.qtd,
                label: Text(loc.analytics_qtd),
              ),
              ButtonSegment(
                value: DateRangePreset.ytd,
                label: Text(loc.analytics_ytd),
              ),
              ButtonSegment(
                value: DateRangePreset.custom,
                label: Text(loc.analytics_custom),
              ),
            ],
            selected: {current ?? DateRangePreset.custom},
            onSelectionChanged: (set) =>
                _applyPreset(context, ref, set.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 6),
              ),
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
            ),
          ),
        ),
        if (current == null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${DateFormat.yMMMd().format(selected.start)} → '
            '${DateFormat.yMMMd().format(selected.end)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Future<void> _applyPreset(
    BuildContext context,
    WidgetRef ref,
    DateRangePreset preset,
  ) async {
    final range = dateRangeForPreset(preset);
    if (range != null) {
      ref.read(analyticsDateRangeProvider.notifier).state = range;
      return;
    }
    // Custom → date-range picker.
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: ref.read(analyticsDateRangeProvider).start,
        end: ref.read(analyticsDateRangeProvider).end,
      ),
      helpText: context.loc.analytics_customRange,
    );
    if (picked != null) {
      ref.read(analyticsDateRangeProvider.notifier).state =
          DateRange(start: picked.start, end: picked.end);
    }
  }

  /// Best-effort mapping of the current range back to a preset; returns null
  /// for custom ranges (anything that isn't one of the fixed presets).
  DateRangePreset? _presetForRange(DateRange range) {
    for (final preset in DateRangePreset.values) {
      if (preset == DateRangePreset.custom) continue;
      final candidate = dateRangeForPreset(preset);
      if (candidate != null && candidate == range) return preset;
    }
    return null;
  }
}
