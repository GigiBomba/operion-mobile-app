import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/features/fleet/models/truck.dart';

void main() {
  group('TruckStatus.fromApiString — REAL backend strings', () {
    test('maps Active → active', () {
      expect(TruckStatus.fromApiString('Active'), TruckStatus.active);
    });

    test('maps In Service → maintenance', () {
      expect(TruckStatus.fromApiString('In Service'), TruckStatus.maintenance);
    });

    test('maps Inactive → decommissioned', () {
      expect(TruckStatus.fromApiString('Inactive'), TruckStatus.decommissioned);
    });

    test('unknown/absent → active (safe default)', () {
      expect(TruckStatus.fromApiString('bogus'), TruckStatus.active);
      expect(TruckStatus.fromApiString(null), TruckStatus.active);
    });
  });

  group('Truck.fromJson', () {
    test('parses the full TruckOut shape', () {
      final truck = Truck.fromJson({
        'id': 42,
        'company_id': 'c1',
        'plate': 'B-100-ABC',
        'brand': 'Volvo',
        'model': 'FH16',
        'vin': 'VIN123',
        'year': 2021,
        'status': 'In Service',
        'health_score': 62.5,
        'current_driver_id': 7,
        'created_at': '2025-01-01T00:00:00',
        'updated_at': '2025-06-01T00:00:00',
      });

      expect(truck.id, '42');
      expect(truck.companyId, 'c1');
      expect(truck.plate, 'B-100-ABC');
      expect(truck.brand, 'Volvo');
      expect(truck.model, 'FH16');
      expect(truck.vin, 'VIN123');
      expect(truck.year, 2021);
      expect(truck.status, TruckStatus.maintenance);
      expect(truck.healthScore, 62.5);
      expect(truck.currentDriverId, '7');
      expect(truck.createdAt, DateTime(2025, 1, 1));
    });

    test('round-trips through toJson preserving the real status string', () {
      final truck = Truck.fromJson({
        'id': 't1',
        'company_id': 'c1',
        'plate': 'B-1',
        'brand': 'MAN',
        'model': 'TGX',
        'status': 'Inactive',
      });
      expect(truck.toJson()['status'], 'Inactive');
    });

    test('absent numeric fields are null/0 without throwing', () {
      final truck = Truck.fromJson({
        'id': 't2',
        'company_id': 'c1',
        'plate': 'B-2',
        'brand': 'Scania',
        'model': 'R500',
      });
      expect(truck.year, isNull);
      expect(truck.healthScore, isNull);
      expect(truck.status, TruckStatus.active);
    });
  });

  group('MaintenanceCategory', () {
    test('stores categories as strings matching the backend enum', () {
      expect(MaintenanceCategory.oilChange.apiValue, 'oil_change');
      expect(MaintenanceCategory.tires.apiValue, 'tires');
      expect(MaintenanceCategory.brakes.apiValue, 'brakes');
      expect(MaintenanceCategory.engine.apiValue, 'engine');
      expect(MaintenanceCategory.bodywork.apiValue, 'bodywork');
      expect(MaintenanceCategory.inspection.apiValue, 'inspection');
      expect(MaintenanceCategory.other.apiValue, 'other');
    });

    test('unknown category falls back to other', () {
      expect(MaintenanceCategory.fromApiString('bogus'), MaintenanceCategory.other);
      expect(MaintenanceCategory.fromApiString(null), MaintenanceCategory.other);
    });
  });

  group('TruckMaintenanceRecord.fromJson', () {
    test('parses the maintenance history item', () {
      final record = TruckMaintenanceRecord.fromJson({
        'id': 1,
        'truck_id': 42,
        'date': '2026-07-15',
        'category': 'oil_change',
        'cost': 350.5,
        'vendor': 'AutoService',
        'notes': 'filter replaced',
      });
      expect(record.id, '1');
      expect(record.truckId, '42');
      expect(record.date, '2026-07-15');
      expect(record.category, MaintenanceCategory.oilChange);
      expect(record.cost, 350.5);
      expect(record.vendor, 'AutoService');
      expect(record.notes, 'filter replaced');
    });
  });

  group('MaintenanceRecordDraft.toJson', () {
    test('emits snake_case date and category', () {
      final draft = MaintenanceRecordDraft(
        date: DateTime(2026, 7, 15),
        category: MaintenanceCategory.brakes,
        cost: 120,
      );
      final json = draft.toJson();
      expect(json['date'], '2026-07-15');
      expect(json['category'], 'brakes');
      expect(json['cost'], 120.0);
    });
  });
}
