DateTime? _parseDateTime(dynamic value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(
        value > 1e12 ? value : value * 1000);
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class Driver {
  final String id;
  final String companyId;
  final String userId;
  final String fullName;
  final String phone;
  final String status; // available, driving, off
  final String? currentTransportId;
  final String? currentVehicleId;
  final DateTime? lastActivity;

  // ── Phase 1B extension (blueprint §4.2) ───────────────────────────
  // Parsed from the new DriverOut shape; each field also reads the legacy
  // camelCase key so existing callers keep working.
  final String? licenseNumber;
  final String? licenseCategory;
  final DateTime? licenseExpiry;
  final DateTime? medicalExpiry;
  final DateTime? adrCertificateExpiry;
  final String? currentTruckId;
  final bool isActive;

  const Driver({
    required this.id,
    required this.companyId,
    required this.userId,
    required this.fullName,
    required this.phone,
    this.status = 'available',
    this.currentTransportId,
    this.currentVehicleId,
    this.lastActivity,
    this.licenseNumber,
    this.licenseCategory,
    this.licenseExpiry,
    this.medicalExpiry,
    this.adrCertificateExpiry,
    this.currentTruckId,
    this.isActive = true,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      status: json['status'] as String? ?? 'available',
      currentTransportId: json['currentTransportId'] as String?,
      currentVehicleId: json['currentVehicleId'] as String?,
      lastActivity: _parseDateTime(json['lastActivity']),
      licenseNumber: json['license_number'] as String? ?? json['licenseNumber'] as String?,
      licenseCategory: json['license_category'] as String? ?? json['licenseCategory'] as String?,
      licenseExpiry: _parseDateTime(json['license_expiry'] ?? json['licenseExpiry']),
      medicalExpiry: _parseDateTime(json['medical_expiry'] ?? json['medicalExpiry']),
      adrCertificateExpiry:
          _parseDateTime(json['adr_certificate_expiry'] ?? json['adrCertificateExpiry']),
      currentTruckId:
          json['current_truck_id'] as String? ?? json['currentTruckId'] as String?,
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'userId': userId,
      'fullName': fullName,
      'phone': phone,
      'status': status,
      'currentTransportId': currentTransportId,
      'currentVehicleId': currentVehicleId,
      'lastActivity': lastActivity?.toIso8601String(),
      'license_number': licenseNumber,
      'license_category': licenseCategory,
      'license_expiry': licenseExpiry?.toIso8601String(),
      'medical_expiry': medicalExpiry?.toIso8601String(),
      'adr_certificate_expiry': adrCertificateExpiry?.toIso8601String(),
      'current_truck_id': currentTruckId,
      'is_active': isActive,
    };
  }

  Driver copyWith({
    String? id,
    String? companyId,
    String? userId,
    String? fullName,
    String? phone,
    String? status,
    String? currentTransportId,
    String? currentVehicleId,
    DateTime? lastActivity,
    String? licenseNumber,
    String? licenseCategory,
    DateTime? licenseExpiry,
    DateTime? medicalExpiry,
    DateTime? adrCertificateExpiry,
    String? currentTruckId,
    bool? isActive,
  }) {
    return Driver(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      currentTransportId: currentTransportId ?? this.currentTransportId,
      currentVehicleId: currentVehicleId ?? this.currentVehicleId,
      lastActivity: lastActivity ?? this.lastActivity,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseCategory: licenseCategory ?? this.licenseCategory,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      medicalExpiry: medicalExpiry ?? this.medicalExpiry,
      adrCertificateExpiry: adrCertificateExpiry ?? this.adrCertificateExpiry,
      currentTruckId: currentTruckId ?? this.currentTruckId,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Driver &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          companyId == other.companyId &&
          userId == other.userId &&
          fullName == other.fullName &&
          phone == other.phone &&
          status == other.status &&
          currentTransportId == other.currentTransportId &&
          currentVehicleId == other.currentVehicleId &&
          lastActivity == other.lastActivity &&
          licenseNumber == other.licenseNumber &&
          licenseCategory == other.licenseCategory &&
          licenseExpiry == other.licenseExpiry &&
          medicalExpiry == other.medicalExpiry &&
          adrCertificateExpiry == other.adrCertificateExpiry &&
          currentTruckId == other.currentTruckId &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(
        id,
        companyId,
        userId,
        fullName,
        phone,
        status,
        currentTransportId,
        currentVehicleId,
        lastActivity,
        licenseNumber,
        licenseCategory,
        licenseExpiry,
        medicalExpiry,
        adrCertificateExpiry,
        currentTruckId,
        isActive,
      );

  @override
  String toString() =>
      'Driver(id: $id, fullName: $fullName, phone: $phone, '
      'status: $status)';
}

/// Create/update driver input (DriverDraft) for `POST/PATCH /mobile/drivers`.
class DriverDraft {
  final String name;
  final String? phone;
  final String? email;
  final String? licenseNumber;
  final String? licenseCategory;
  final DateTime? licenseExpiry;
  final DateTime? medicalExpiry;
  final DateTime? adrCertificateExpiry;

  const DriverDraft({
    required this.name,
    this.phone,
    this.email,
    this.licenseNumber,
    this.licenseCategory,
    this.licenseExpiry,
    this.medicalExpiry,
    this.adrCertificateExpiry,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (email != null && email!.isNotEmpty) 'email': email,
        if (licenseNumber != null && licenseNumber!.isNotEmpty)
          'license_number': licenseNumber,
        if (licenseCategory != null && licenseCategory!.isNotEmpty)
          'license_category': licenseCategory,
        if (licenseExpiry != null) 'license_expiry': licenseExpiry!.toIso8601String().substring(0, 10),
        if (medicalExpiry != null) 'medical_expiry': medicalExpiry!.toIso8601String().substring(0, 10),
        if (adrCertificateExpiry != null)
          'adr_certificate_expiry': adrCertificateExpiry!.toIso8601String().substring(0, 10),
      };
}
