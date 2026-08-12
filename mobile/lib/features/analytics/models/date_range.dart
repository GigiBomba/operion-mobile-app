/// A date-range selection for analytics and history screens.
///
/// Immutable value type; the same shape is sent to the backend as
/// `start_date` / `end_date` ISO query parameters (blueprint §4.4/§6.4).
class DateRange {
  const DateRange({required this.start, required this.end});

  /// Inclusive start of the range (date-only, no time).
  final DateTime start;

  /// Inclusive end of the range (date-only, no time).
  final DateTime end;

  /// Whether the range is empty / has no usable data window.
  bool get isEmpty => start.isAfter(end);

  /// `start_date` in `yyyy-MM-dd` form.
  String get startIso => _iso(start);

  /// `end_date` in `yyyy-MM-dd` form.
  String get endIso => _iso(end);

  /// Builds a range ending today covering the last 30 days.
  factory DateRange.last30Days({DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    return DateRange(
      start: today.subtract(const Duration(days: 29)),
      end: today,
    );
  }

  static String _iso(DateTime d) {
    final date = _dateOnly(d);
    final m = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$day';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DateRange($startIso → $endIso)';
}

/// Preset date-range options shown in the segmented control (§4.4).
enum DateRangePreset { last7Days, last30Days, qtd, ytd, custom }

/// Maps a [DateRangePreset] to a concrete [DateRange] relative to [now].
///
/// `custom` returns null — the caller falls back to a user-picked range.
DateRange? dateRangeForPreset(DateRangePreset preset, {DateTime? now}) {
  final today = DateRange._dateOnly(now ?? DateTime.now());
  switch (preset) {
    case DateRangePreset.last7Days:
      return DateRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      );
    case DateRangePreset.last30Days:
      return DateRange(
        start: today.subtract(const Duration(days: 29)),
        end: today,
      );
    case DateRangePreset.qtd:
      // Quarter start = Jan/Apr/Jul/Oct 1st of the current year.
      final quarterStartMonth = ((today.month - 1) ~/ 3) * 3 + 1;
      return DateRange(
        start: DateTime(today.year, quarterStartMonth, 1),
        end: today,
      );
    case DateRangePreset.ytd:
      return DateRange(start: DateTime(today.year, 1, 1), end: today);
    case DateRangePreset.custom:
      return null;
  }
}
