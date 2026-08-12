import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/features/analytics/models/date_range.dart';

void main() {
  group('DateRange', () {
    test('last30Days factory covers 30 calendar days inclusive', () {
      final now = DateTime(2026, 7, 31);
      final range = DateRange.last30Days(now: now);
      expect(range.end, DateTime(2026, 7, 31));
      expect(range.start, DateTime(2026, 7, 2));
      expect(range.end.difference(range.start).inDays, 29);
      expect(range.isEmpty, isFalse);
    });

    test('iso formatting emits yyyy-MM-dd', () {
      final range = DateRange(
        start: DateTime(2026, 3, 5),
        end: DateTime(2026, 4, 1),
      );
      expect(range.startIso, '2026-03-05');
      expect(range.endIso, '2026-04-01');
    });

    test('empty range detected', () {
      final range = DateRange(
        start: DateTime(2026, 5, 10),
        end: DateTime(2026, 5, 1),
      );
      expect(range.isEmpty, isTrue);
    });

    test('equality compares start and end', () {
      final a = DateRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 31));
      final b = DateRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 31));
      final c = DateRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 2, 1));
      expect(a, b);
      expect(a == c, isFalse);
    });
  });

  group('dateRangeForPreset', () {
    final now = DateTime(2026, 7, 31);

    test('7d covers the last 7 days', () {
      final range = dateRangeForPreset(DateRangePreset.last7Days, now: now)!;
      expect(range.start, DateTime(2026, 7, 25));
      expect(range.end, DateTime(2026, 7, 31));
    });

    test('30d covers the last 30 days', () {
      final range = dateRangeForPreset(DateRangePreset.last30Days, now: now)!;
      expect(range.start, DateTime(2026, 7, 2));
      expect(range.end, DateTime(2026, 7, 31));
    });

    test('qtd starts at quarter start', () {
      final q1 = dateRangeForPreset(DateRangePreset.qtd, now: DateTime(2026, 2, 15))!;
      expect(q1.start, DateTime(2026, 1, 1));
      final q3 = dateRangeForPreset(DateRangePreset.qtd, now: DateTime(2026, 8, 1))!;
      expect(q3.start, DateTime(2026, 7, 1));
    });

    test('ytd starts Jan 1', () {
      final range = dateRangeForPreset(DateRangePreset.ytd, now: now)!;
      expect(range.start, DateTime(2026, 1, 1));
      expect(range.end, DateTime(2026, 7, 31));
    });

    test('custom returns null', () {
      expect(dateRangeForPreset(DateRangePreset.custom, now: now), isNull);
    });
  });
}
