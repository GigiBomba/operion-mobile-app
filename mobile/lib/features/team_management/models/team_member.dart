// ─────────────────────────────────────────────────────────────────────────────
// Team management models (blueprint §4.9).
//
// `TeamMember` mirrors the backend `TeamMemberOut`:
// {id, email, display_name, role, is_active, created_at, driver_name?}.
// ─────────────────────────────────────────────────────────────────────────────

class TeamMember {
  const TeamMember({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.driverName,
  });

  final int id;
  final String email;
  final String displayName;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final String? driverName;

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        id: (json['id'] as num?)?.toInt() ?? 0,
        email: json['email']?.toString() ?? '',
        displayName: json['display_name']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        driverName: json['driver_name']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'role': role,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
        if (driverName != null) 'driver_name': driverName,
      };
}
