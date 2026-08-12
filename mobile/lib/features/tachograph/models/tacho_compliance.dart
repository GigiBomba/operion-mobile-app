// ─────────────────────────────────────────────────────────────────────────────
// Tachograph compliance models (blueprint §4.7 / contract 4A-4B).
//
// `TachoComplianceResult` mirrors the backend `TachoComplianceResult` payload
// exactly — including the VERBATIM `violations` strings. The mobile client
// NEVER recomputes compliance; it renders what the backend returns.
// ─────────────────────────────────────────────────────────────────────────────

/// One driver-activity day inside a compliance result.
class TachoDay {
  const TachoDay({
    required this.date,
    required this.drivingMinutes,
    required this.workingMinutes,
    required this.restMinutes,
    required this.availabilityMinutes,
  });

  final String date;
  final int drivingMinutes;
  final int workingMinutes;
  final int restMinutes;
  final int availabilityMinutes;

  factory TachoDay.fromJson(Map<String, dynamic> json) => TachoDay(
        date: json['date']?.toString() ?? '',
        drivingMinutes: (json['driving_minutes'] as num?)?.toInt() ?? 0,
        workingMinutes: (json['working_minutes'] as num?)?.toInt() ?? 0,
        restMinutes: (json['rest_minutes'] as num?)?.toInt() ?? 0,
        availabilityMinutes:
            (json['availability_minutes'] as num?)?.toInt() ?? 0,
      );
}

/// Parsed compliance result of a `.ddd`/`.esm` import job.
class TachoComplianceResult {
  const TachoComplianceResult({
    required this.days,
    required this.weeklyDrivingMinutes,
    required this.weeklyLimitMinutes,
    required this.violations,
  });

  final List<TachoDay> days;
  final int weeklyDrivingMinutes;
  final int weeklyLimitMinutes;

  /// Backend-generated, VERBATIM warning strings — rendered as-is.
  final List<String> violations;

  factory TachoComplianceResult.fromJson(Map<String, dynamic> json) =>
      TachoComplianceResult(
        days: (json['days'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(TachoDay.fromJson)
                .toList() ??
            const [],
        weeklyDrivingMinutes:
            (json['weekly_driving_minutes'] as num?)?.toInt() ?? 0,
        weeklyLimitMinutes:
            (json['weekly_limit_minutes'] as num?)?.toInt() ?? 3360,
        violations: (json['violations'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
      );
}

/// Lifecycle of an async import job (mirrors the history export job shape).
enum TachoImportStatus { processing, success, error }

/// Parsed `GET /mobile/tacho/import/{job_id}/status` payload.
class TachoImportJobState {
  const TachoImportJobState({required this.status, this.result, this.error});

  final TachoImportStatus status;
  final TachoComplianceResult? result;

  /// Honest human-readable failure message (e.g. parser binary missing).
  final String? error;

  bool get isTerminal => status != TachoImportStatus.processing;

  factory TachoImportJobState.fromJson(Map<String, dynamic> json) {
    final status = switch (json['status']?.toString()) {
      'success' => TachoImportStatus.success,
      'error' => TachoImportStatus.error,
      _ => TachoImportStatus.processing,
    };
    final rawResult = json['result'];
    return TachoImportJobState(
      status: status,
      result: rawResult is Map<String, dynamic>
          ? TachoComplianceResult.fromJson(rawResult)
          : null,
      error: json['error']?.toString(),
    );
  }
}
