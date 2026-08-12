/// A load listed on a freight exchange (provider-agnostic).
///
/// No provider-specific field names — the mobile client only consumes the
/// provider-agnostic backend endpoint. The backend adapter maps provider
/// fields to this shape.
class FreightLoad {
  final String id;
  final String origin;
  final String destination;
  final String? cargoType;
  final double? price;
  final String? currency;
  final DateTime? pickupDate;
  final DateTime? deadlineDate;
  final double? weightKg;
  final String? distanceKm;

  /// Optional provider segment (the active exchange adapter's id). Never a
  /// provider-specific *field name* — the backend may include `provider_id`
  /// in the list payload; when absent it is derived from the load id (see
  /// [idParts]).
  final String? providerId;

  const FreightLoad({
    required this.id,
    required this.origin,
    required this.destination,
    this.cargoType,
    this.price,
    this.currency,
    this.pickupDate,
    this.deadlineDate,
    this.weightKg,
    this.distanceKm,
    this.providerId,
  });

  /// Splits the provider-agnostic load [id] into `provider_id` / `load_id`
  /// segments for the import endpoint (`POST /freight/loads/{provider_id}/
  /// {load_id}/import`).
  ///
  /// The backend list endpoint returns a single `id` per load. When the
  /// payload carries an explicit `provider_id` it wins; otherwise the id is
  /// parsed as `provider_id/load_id` (or `provider_id:load_id`). When neither
  /// applies, the whole id is treated as the load id and [providerId] is null
  /// — the accept flow then surfaces an unresolvable-provider error rather
  /// than guessing a provider (see `resolveImportTarget`).
  ({String? providerId, String loadId}) get idParts {
    final explicit = providerId?.trim() ?? '';
    if (explicit.isNotEmpty) return (providerId: explicit, loadId: id);
    for (final sep in ['/', ':']) {
      final index = id.indexOf(sep);
      if (index > 0 && index < id.length - 1) {
        return (
          providerId: id.substring(0, index).trim(),
          loadId: id.substring(index + 1).trim(),
        );
      }
    }
    return (providerId: null, loadId: id);
  }

  factory FreightLoad.fromJson(Map<String, dynamic> json) => FreightLoad(
        id: json['id'] as String? ?? '',
        origin: json['origin'] as String? ?? '',
        destination: json['destination'] as String? ?? '',
        cargoType: json['cargo_type'] as String?,
        price: (json['price'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
        pickupDate: json['pickup_date'] != null
            ? DateTime.tryParse(json['pickup_date'] as String)
            : null,
        deadlineDate: json['deadline_date'] != null
            ? DateTime.tryParse(json['deadline_date'] as String)
            : null,
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
        distanceKm: json['distance_km'] as String?,
        providerId: json['provider_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'origin': origin,
        'destination': destination,
        'cargo_type': cargoType,
        'price': price,
        'currency': currency,
        'pickup_date': pickupDate?.toIso8601String(),
        'deadline_date': deadlineDate?.toIso8601String(),
        'weight_kg': weightKg,
        'distance_km': distanceKm,
        'provider_id': providerId,
      };
}
