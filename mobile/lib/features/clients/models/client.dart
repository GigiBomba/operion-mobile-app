/// Client (CRM) models + drafts (blueprint §4.3).
///
/// Parsed from the real backend shapes:
/// - list item: `{id, company_id, name, vat_number, address,
///   payment_terms_days, rating, is_active, created_at, updated_at}`
/// - detail adds `contacts`, `recent_trip_count`, `recent_invoice_count`.
library;

DateTime? _parseDateTime(dynamic value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value > 1e12 ? value : value * 1000);
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// A client contact.
class ClientContact {
  final String id;
  final String name;
  final String? role;
  final String? phone;
  final String? email;

  const ClientContact({
    required this.id,
    required this.name,
    this.role,
    this.phone,
    this.email,
  });

  factory ClientContact.fromJson(Map<String, dynamic> json) => ClientContact(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        role: json['role'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'phone': phone,
        'email': email,
      };
}

/// A client (CRM record).
class Client {
  final String id;
  final String companyId;
  final String name;
  final String? vatNumber;
  final String? address;
  final int paymentTermsDays;
  final double rating;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Detail-only fields (empty/zero on list items).
  final List<ClientContact> contacts;
  final int recentTripCount;
  final int recentInvoiceCount;

  const Client({
    required this.id,
    required this.companyId,
    required this.name,
    this.vatNumber,
    this.address,
    this.paymentTermsDays = 0,
    this.rating = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.contacts = const [],
    this.recentTripCount = 0,
    this.recentInvoiceCount = 0,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    final rawContacts = json['contacts'];
    return Client(
      id: json['id']?.toString() ?? '',
      companyId: json['company_id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      vatNumber: json['vat_number'] as String?,
      address: json['address'] as String?,
      paymentTermsDays: (json['payment_terms_days'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      contacts: rawContacts is List
          ? rawContacts
              .whereType<Map<String, dynamic>>()
              .map(ClientContact.fromJson)
              .toList()
          : const [],
      recentTripCount: (json['recent_trip_count'] as num?)?.toInt() ?? 0,
      recentInvoiceCount: (json['recent_invoice_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'name': name,
        'vat_number': vatNumber,
        'address': address,
        'payment_terms_days': paymentTermsDays,
        'rating': rating,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'contacts': contacts.map((c) => c.toJson()).toList(),
        'recent_trip_count': recentTripCount,
        'recent_invoice_count': recentInvoiceCount,
      };

  Client copyWith({
    String? name,
    String? vatNumber,
    String? address,
    int? paymentTermsDays,
    double? rating,
    bool? isActive,
    List<ClientContact>? contacts,
    int? recentTripCount,
    int? recentInvoiceCount,
  }) {
    return Client(
      id: id,
      companyId: companyId,
      name: name ?? this.name,
      vatNumber: vatNumber ?? this.vatNumber,
      address: address ?? this.address,
      paymentTermsDays: paymentTermsDays ?? this.paymentTermsDays,
      rating: rating ?? this.rating,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      contacts: contacts ?? this.contacts,
      recentTripCount: recentTripCount ?? this.recentTripCount,
      recentInvoiceCount: recentInvoiceCount ?? this.recentInvoiceCount,
    );
  }
}

/// Create/update client input.
class ClientDraft {
  final String name;
  final String? vatNumber;
  final String? address;
  final int paymentTermsDays;
  final bool isActive;

  const ClientDraft({
    required this.name,
    this.vatNumber,
    this.address,
    this.paymentTermsDays = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (vatNumber != null && vatNumber!.isNotEmpty) 'vat_number': vatNumber,
        if (address != null && address!.isNotEmpty) 'address': address,
        'payment_terms_days': paymentTermsDays,
        'is_active': isActive,
      };
}

/// Add-contact input.
class ClientContactDraft {
  final String name;
  final String? role;
  final String? phone;
  final String? email;

  const ClientContactDraft({
    required this.name,
    this.role,
    this.phone,
    this.email,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (role != null && role!.isNotEmpty) 'role': role,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (email != null && email!.isNotEmpty) 'email': email,
      };
}

/// Result of a successful merge (`POST /mobile/clients/merge`).
class ClientMergeResult {
  final int mergedTripCount;
  final int mergedInvoiceCount;
  final int mergedContactCount;

  const ClientMergeResult({
    this.mergedTripCount = 0,
    this.mergedInvoiceCount = 0,
    this.mergedContactCount = 0,
  });

  factory ClientMergeResult.fromJson(Map<String, dynamic> json) =>
      ClientMergeResult(
        mergedTripCount: (json['merged_trip_count'] as num?)?.toInt() ?? 0,
        mergedInvoiceCount: (json['merged_invoice_count'] as num?)?.toInt() ?? 0,
        mergedContactCount: (json['merged_contact_count'] as num?)?.toInt() ?? 0,
      );
}
