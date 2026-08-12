/// Maintenance scheduling + cost trend models (blueprint §4.6).
///
/// Parsed from the real backend shapes: `MaintenanceScheduleOut{id, truck_id,
/// truck_plate, maintenance_type, interval_km, interval_months, last_done_km,
/// last_done_date, overdue, next_due}` and cost-trend `{monthly:
/// [{month, total}], by_type: [{type, total}]}`.
library;

DateTime? _parseDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

/// One maintenance schedule row.
class MaintenanceScheduleItem {
  final String id;
  final String truckId;
  final String truckPlate;
  final String maintenanceType;
  final int? intervalKm;
  final int? intervalMonths;
  final int? lastDoneKm;
  final DateTime? lastDoneDate;
  final bool overdue;
  final DateTime? nextDue;

  const MaintenanceScheduleItem({
    required this.id,
    required this.truckId,
    required this.truckPlate,
    required this.maintenanceType,
    this.intervalKm,
    this.intervalMonths,
    this.lastDoneKm,
    this.lastDoneDate,
    this.overdue = false,
    this.nextDue,
  });

  factory MaintenanceScheduleItem.fromJson(Map<String, dynamic> json) =>
      MaintenanceScheduleItem(
        id: json['id']?.toString() ?? '',
        truckId: json['truck_id']?.toString() ?? '',
        truckPlate: json['truck_plate']?.toString() ?? '',
        maintenanceType: json['maintenance_type']?.toString() ?? '',
        intervalKm: (json['interval_km'] as num?)?.toInt(),
        intervalMonths: (json['interval_months'] as num?)?.toInt(),
        lastDoneKm: (json['last_done_km'] as num?)?.toInt(),
        lastDoneDate: _parseDate(json['last_done_date']),
        overdue: json['overdue'] == true,
        nextDue: _parseDate(json['next_due']),
      );
}

/// Create-schedule input (`POST /mobile/maintenance/schedule`).
class MaintenanceScheduleDraft {
  final String truckId;
  final String maintenanceType;
  final int? intervalKm;
  final int? intervalMonths;
  final DateTime? fixedExpiryDate;

  const MaintenanceScheduleDraft({
    required this.truckId,
    required this.maintenanceType,
    this.intervalKm,
    this.intervalMonths,
    this.fixedExpiryDate,
  });

  Map<String, dynamic> toJson() => {
        'truck_id': truckId,
        'maintenance_type': maintenanceType,
        if (intervalKm != null) 'interval_km': intervalKm,
        if (intervalMonths != null) 'interval_months': intervalMonths,
        if (fixedExpiryDate != null)
          'fixed_expiry_date':
              '${fixedExpiryDate!.year}-${fixedExpiryDate!.month.toString().padLeft(2, '0')}-${fixedExpiryDate!.day.toString().padLeft(2, '0')}',
      };
}

/// One monthly cost-trend point.
class CostTrendPoint {
  final String month;
  final double total;

  const CostTrendPoint({required this.month, required this.total});

  factory CostTrendPoint.fromJson(Map<String, dynamic> json) =>
      CostTrendPoint(
        month: json['month']?.toString() ?? '',
        total: (json['total'] as num?)?.toDouble() ?? 0,
      );
}

/// One by-type cost slice (pie-chart input).
class CostByType {
  final String type;
  final double total;

  const CostByType({required this.type, required this.total});

  factory CostByType.fromJson(Map<String, dynamic> json) => CostByType(
        type: json['type']?.toString() ?? '',
        total: (json['total'] as num?)?.toDouble() ?? 0,
      );
}

/// Cost-trend payload (`GET /mobile/maintenance/cost-trend`).
class CostTrendData {
  final List<CostTrendPoint> monthly;
  final List<CostByType> byType;

  const CostTrendData({required this.monthly, required this.byType});

  factory CostTrendData.fromJson(Map<String, dynamic> json) => CostTrendData(
        monthly: _parseList(json['monthly'], CostTrendPoint.fromJson),
        byType: _parseList(json['by_type'], CostByType.fromJson),
      );
}

List<T> _parseList<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(fromJson)
      .toList();
}
