/// Truck model + drafts for the fleet feature (blueprint §4.1).
///
/// Parsed from the real backend `TruckOut` / list-item shape:
/// `{id, company_id, plate, brand, model, vin, year, status, health_score,
/// current_driver_id, created_at, updated_at}`. `status` uses the REAL
/// strings `'Active'` / `'In Service'` / `'Inactive'` (not enum aliases) —
/// mapped via [TruckStatus.fromApiString].
library;

DateTime? _parseDateTime(dynamic value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value > 1e12 ? value : value * 1000);
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Truck lifecycle status (REAL backend strings).
enum TruckStatus {
  /// `'Active'` — roadworthy, in service.
  active('Active'),

  /// `'In Service'` — in the workshop / under maintenance.
  maintenance('In Service'),

  /// `'Inactive'` — decommissioned (soft-deleted).
  decommissioned('Inactive');

  const TruckStatus(this.apiValue);

  /// The exact backend string for this status.
  final String apiValue;

  /// Maps a raw backend status string to a [TruckStatus].
  ///
  /// Unknown/absent values resolve to [TruckStatus.active] (safe default —
  /// the server always sends one of the three real strings).
  static TruckStatus fromApiString(String? value) {
    for (final status in TruckStatus.values) {
      if (status.apiValue == value) return status;
    }
    return TruckStatus.active;
  }
}

/// A truck (fleet vehicle).
class Truck {
  final String id;
  final String companyId;
  final String plate;
  final String brand;
  final String model;
  final String? vin;
  final int? year;
  final TruckStatus status;
  final double? healthScore;
  final String? currentDriverId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Truck({
    required this.id,
    required this.companyId,
    required this.plate,
    required this.brand,
    required this.model,
    this.vin,
    this.year,
    this.status = TruckStatus.active,
    this.healthScore,
    this.currentDriverId,
    this.createdAt,
    this.updatedAt,
  });

  factory Truck.fromJson(Map<String, dynamic> json) => Truck(
        id: json['id']?.toString() ?? '',
        companyId: json['company_id']?.toString() ?? '',
        plate: json['plate'] as String? ?? '',
        brand: json['brand'] as String? ?? '',
        model: json['model'] as String? ?? '',
        vin: json['vin'] as String?,
        year: (json['year'] as num?)?.toInt(),
        status: TruckStatus.fromApiString(json['status'] as String?),
        healthScore: (json['health_score'] as num?)?.toDouble(),
        currentDriverId: json['current_driver_id']?.toString(),
        createdAt: _parseDateTime(json['created_at']),
        updatedAt: _parseDateTime(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'plate': plate,
        'brand': brand,
        'model': model,
        'vin': vin,
        'year': year,
        'status': status.apiValue,
        'health_score': healthScore,
        'current_driver_id': currentDriverId,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Truck copyWith({
    String? plate,
    String? brand,
    String? model,
    String? vin,
    int? year,
    TruckStatus? status,
    double? healthScore,
    String? currentDriverId,
  }) {
    return Truck(
      id: id,
      companyId: companyId,
      plate: plate ?? this.plate,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      vin: vin ?? this.vin,
      year: year ?? this.year,
      status: status ?? this.status,
      healthScore: healthScore ?? this.healthScore,
      currentDriverId: currentDriverId ?? this.currentDriverId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Create-truck input (blueprint §4.1: `plate, brand, model, vin, year`).
class TruckDraft {
  final String plate;
  final String brand;
  final String model;
  final String? vin;
  final int? year;

  const TruckDraft({
    required this.plate,
    required this.brand,
    required this.model,
    this.vin,
    this.year,
  });

  Map<String, dynamic> toJson() => {
        'plate': plate,
        'brand': brand,
        'model': model,
        if (vin != null && vin!.isNotEmpty) 'vin': vin,
        if (year != null) 'year': year,
      };
}

/// PATCH input for updating a truck (only non-null fields are sent).
class TruckUpdateDraft {
  final String? plate;
  final String? brand;
  final String? model;
  final String? vin;
  final int? year;

  const TruckUpdateDraft({this.plate, this.brand, this.model, this.vin, this.year});

  Map<String, dynamic> toJson() => {
        if (plate != null && plate!.isNotEmpty) 'plate': plate,
        if (brand != null && brand!.isNotEmpty) 'brand': brand,
        if (model != null && model!.isNotEmpty) 'model': model,
        if (vin != null && vin!.isNotEmpty) 'vin': vin,
        if (year != null) 'year': year,
      };
}

/// A maintenance history record (`GET/POST /mobile/fleet/{id}/maintenance`).
class TruckMaintenanceRecord {
  final String id;
  final String truckId;
  final String date; // ISO date string as served
  final MaintenanceCategory category;
  final double cost;
  final String? vendor;
  final String? notes;

  const TruckMaintenanceRecord({
    required this.id,
    required this.truckId,
    required this.date,
    required this.category,
    required this.cost,
    this.vendor,
    this.notes,
  });

  factory TruckMaintenanceRecord.fromJson(Map<String, dynamic> json) =>
      TruckMaintenanceRecord(
        id: json['id']?.toString() ?? '',
        truckId: json['truck_id']?.toString() ?? '',
        date: json['date'] as String? ?? '',
        category: MaintenanceCategory.fromApiString(json['category'] as String?),
        cost: (json['cost'] as num?)?.toDouble() ?? 0,
        vendor: json['vendor'] as String?,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'truck_id': truckId,
        'date': date,
        'category': category.apiValue,
        'cost': cost,
        'vendor': vendor,
        'notes': notes,
      };
}

/// Maintenance work categories (mirrors the backend enum; stored as strings).
enum MaintenanceCategory {
  oilChange('oil_change'),
  tires('tires'),
  brakes('brakes'),
  engine('engine'),
  bodywork('bodywork'),
  inspection('inspection'),
  other('other');

  const MaintenanceCategory(this.apiValue);

  final String apiValue;

  static MaintenanceCategory fromApiString(String? value) {
    for (final category in MaintenanceCategory.values) {
      if (category.apiValue == value) return category;
    }
    return MaintenanceCategory.other;
  }
}

/// Input for recording a maintenance work entry.
class MaintenanceRecordDraft {
  final DateTime date;
  final MaintenanceCategory category;
  final double cost;
  final String? vendor;
  final String? notes;

  const MaintenanceRecordDraft({
    required this.date,
    required this.category,
    required this.cost,
    this.vendor,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().substring(0, 10),
        'category': category.apiValue,
        'cost': cost,
        if (vendor != null && vendor!.isNotEmpty) 'vendor': vendor,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

/// Voice quick-capture pre-fill (blueprint §9 item 4).
///
/// Maps the backend `record_maintenance` Copilot tool step parameters onto
/// the record-work sheet fields. `plateNumber` is used only to resolve the
/// target truck (via the fleet cache) when `truck_id` is absent — it is not a
/// sheet field itself.
class MaintenancePrefill {
  const MaintenancePrefill({
    this.plateNumber,
    this.category,
    this.cost,
    this.notes,
    this.date,
  });

  /// The truck plate mentioned by the voice/typed phrase (resolution hint).
  final String? plateNumber;

  /// The maintenance category (maps to the sheet dropdown).
  final MaintenanceCategory? category;

  /// The cost to pre-fill (may be absent → sheet opens empty).
  final double? cost;

  /// Free-form notes.
  final String? notes;

  /// The record date (defaults to today in the sheet when null).
  final DateTime? date;

  /// Maps backend `record_maintenance` step parameters (snake_case) to a
  /// sheet pre-fill. Unknown categories/costs degrade to `null` so the sheet
  /// remains valid for one-tap editing.
  factory MaintenancePrefill.fromStepParameters(Map<String, dynamic> params) {
    final rawCost = params['cost'];
    final rawDate = params['date'];
    return MaintenancePrefill(
      plateNumber: params['plate_number']?.toString(),
      category: params['category'] == null
          ? null
          : MaintenanceCategory.fromApiString(params['category'].toString()),
      cost: rawCost is num
          ? rawCost.toDouble()
          : double.tryParse(rawCost?.toString() ?? ''),
      notes: params['notes']?.toString(),
      date: rawDate != null ? DateTime.tryParse(rawDate.toString()) : null,
    );
  }
}
