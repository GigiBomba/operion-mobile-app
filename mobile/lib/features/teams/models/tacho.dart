/// Tacho timeline models (blueprint §4.2).
///
/// Parsed from `GET /mobile/drivers/{id}/tacho`:
/// `{days: [{date, driving_minutes, working_minutes, rest_minutes,
/// availability_minutes}], weekly_driving_minutes, weekly_limit_minutes: 3360}`.
library;

DateTime? _parseDateTime(dynamic value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value > 1e12 ? value : value * 1000);
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// A single day's tacho activity breakdown.
class TachoDay {
  final DateTime? date;
  final int drivingMinutes;
  final int workingMinutes;
  final int restMinutes;
  final int availabilityMinutes;

  const TachoDay({
    this.date,
    this.drivingMinutes = 0,
    this.workingMinutes = 0,
    this.restMinutes = 0,
    this.availabilityMinutes = 0,
  });

  /// Total tracked minutes in the day (driving + working + rest + other).
  /// "Other" (availability) is the remainder of the day not otherwise tracked.
  int get otherMinutes {
    final tracked = drivingMinutes + workingMinutes + restMinutes;
    return tracked >= 1440 ? 0 : 1440 - tracked;
  }

  factory TachoDay.fromJson(Map<String, dynamic> json) => TachoDay(
        date: _parseDateTime(json['date']),
        drivingMinutes: (json['driving_minutes'] as num?)?.toInt() ?? 0,
        workingMinutes: (json['working_minutes'] as num?)?.toInt() ?? 0,
        restMinutes: (json['rest_minutes'] as num?)?.toInt() ?? 0,
        availabilityMinutes: (json['availability_minutes'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'date': date?.toIso8601String(),
        'driving_minutes': drivingMinutes,
        'working_minutes': workingMinutes,
        'rest_minutes': restMinutes,
        'availability_minutes': availabilityMinutes,
      };
}

/// A driver's tacho week (7 days) plus weekly aggregates.
class TachoWeek {
  final List<TachoDay> days;
  final int weeklyDrivingMinutes;
  final int weeklyLimitMinutes;

  const TachoWeek({
    this.days = const [],
    this.weeklyDrivingMinutes = 0,
    this.weeklyLimitMinutes = 3360,
  });

  /// Whether the weekly driving allowance was exceeded.
  bool get isOverLimit =>
      weeklyLimitMinutes > 0 && weeklyDrivingMinutes > weeklyLimitMinutes;

  factory TachoWeek.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    return TachoWeek(
      days: rawDays is List
          ? rawDays
              .whereType<Map<String, dynamic>>()
              .map(TachoDay.fromJson)
              .toList()
          : const [],
      weeklyDrivingMinutes:
          (json['weekly_driving_minutes'] as num?)?.toInt() ?? 0,
      weeklyLimitMinutes: (json['weekly_limit_minutes'] as num?)?.toInt() ?? 3360,
    );
  }
}
