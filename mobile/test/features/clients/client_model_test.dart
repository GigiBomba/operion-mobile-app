import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/features/clients/models/client.dart';

void main() {
  group('Client.fromJson', () {
    test('parses the list-item shape', () {
      final client = Client.fromJson({
        'id': 42,
        'company_id': 'c1',
        'name': 'ACME Logistics',
        'vat_number': 'RO12345',
        'address': 'Bucuresti',
        'payment_terms_days': 30,
        'rating': 4.5,
        'is_active': true,
        'created_at': '2025-01-01T00:00:00',
      });

      expect(client.id, '42');
      expect(client.companyId, 'c1');
      expect(client.name, 'ACME Logistics');
      expect(client.vatNumber, 'RO12345');
      expect(client.address, 'Bucuresti');
      expect(client.paymentTermsDays, 30);
      expect(client.rating, 4.5);
      expect(client.isActive, isTrue);
      expect(client.contacts, isEmpty);
      expect(client.recentTripCount, 0);
    });

    test('parses the detail shape with contacts and recent counts', () {
      final client = Client.fromJson({
        'id': 'c-9',
        'company_id': 'c1',
        'name': 'Beta SRL',
        'is_active': false,
        'contacts': [
          {'id': 1, 'name': 'Ion', 'role': 'manager', 'phone': '0700', 'email': 'ion@beta.ro'},
          {'id': 2, 'name': 'Ana', 'role': 'admin', 'phone': '0701', 'email': 'ana@beta.ro'},
        ],
        'recent_trip_count': 12,
        'recent_invoice_count': 5,
      });

      expect(client.isActive, isFalse);
      expect(client.contacts, hasLength(2));
      expect(client.contacts.first.name, 'Ion');
      expect(client.contacts.first.role, 'manager');
      expect(client.recentTripCount, 12);
      expect(client.recentInvoiceCount, 5);
    });

    test('round-trips through toJson', () {
      final client = Client.fromJson({
        'id': 'c-1',
        'company_id': 'c1',
        'name': 'X',
        'payment_terms_days': 14,
        'rating': 3.0,
      });
      final json = client.toJson();
      expect(json['name'], 'X');
      expect(json['payment_terms_days'], 14);
      expect(json['rating'], 3.0);
    });
  });

  group('ClientContact.fromJson', () {
    test('parses contact fields', () {
      final c = ClientContact.fromJson({
        'id': 1,
        'name': 'Ion',
        'role': 'manager',
        'phone': '0700',
        'email': 'ion@beta.ro',
      });
      expect(c.id, '1');
      expect(c.name, 'Ion');
      expect(c.role, 'manager');
      expect(c.phone, '0700');
      expect(c.email, 'ion@beta.ro');
    });
  });

  group('ClientDraft / ClientContactDraft / ClientMergeResult', () {
    test('ClientDraft.toJson emits snake_case', () {
      const draft = ClientDraft(
        name: 'ACME',
        vatNumber: 'RO1',
        address: 'Str X',
        paymentTermsDays: 30,
        isActive: false,
      );
      final json = draft.toJson();
      expect(json['name'], 'ACME');
      expect(json['vat_number'], 'RO1');
      expect(json['payment_terms_days'], 30);
      expect(json['is_active'], isFalse);
    });

    test('ClientContactDraft omits empty optional fields', () {
      const draft = ClientContactDraft(name: 'Ion');
      expect(draft.toJson(), {'name': 'Ion'});
    });

    test('ClientMergeResult.fromJson parses merged counts', () {
      final result = ClientMergeResult.fromJson({
        'merged_trip_count': 3,
        'merged_invoice_count': 2,
        'merged_contact_count': 1,
      });
      expect(result.mergedTripCount, 3);
      expect(result.mergedInvoiceCount, 2);
      expect(result.mergedContactCount, 1);
    });
  });
}
