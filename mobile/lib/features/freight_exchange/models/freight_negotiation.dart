/// Freight-exchange negotiation models.
///
/// Parsed from `GET /freight/loads/{provider_id}/{load_id}/negotiation`:
/// `{thread: [{id, provider_id, provider_load_id, direction, status,
/// amount_eur, currency, counterparty_name, parent_negotiation_id,
/// created_at}]}`.
library;

/// Direction of a negotiation record relative to the company.
///
/// The backend emits `inbound` (counterparty → company) / `outbound`
/// (company → counterparty); `to`/`from` are kept as legacy aliases.
enum FreightNegotiationDirection {
  to('to'),
  from('from');

  const FreightNegotiationDirection(this.apiValue);

  final String apiValue;

  static FreightNegotiationDirection fromApiString(String? value) {
    return switch (value) {
      'to' || 'inbound' => FreightNegotiationDirection.to,
      'from' || 'outbound' => FreightNegotiationDirection.from,
      _ => FreightNegotiationDirection.to,
    };
  }
}

/// Status of a negotiation record (backend fixed contract).
enum FreightNegotiationStatus {
  offered('offered'),
  countered('countered'),
  accepted('accepted'),
  rejected('rejected'),
  expired('expired');

  const FreightNegotiationStatus(this.apiValue);

  final String apiValue;

  static FreightNegotiationStatus fromApiString(String? value) {
    for (final s in values) {
      if (s.apiValue == value) return s;
    }
    return FreightNegotiationStatus.offered;
  }
}

/// A single negotiation record (offer / counter / accept / reject / expiry).
class FreightNegotiation {
  final String id;
  final String providerId;
  final String providerLoadId;
  final FreightNegotiationDirection direction;
  final FreightNegotiationStatus status;
  final double amountEur;
  final String currency;
  final String counterpartyName;
  final String? parentNegotiationId;
  final DateTime? createdAt;

  const FreightNegotiation({
    required this.id,
    required this.providerId,
    required this.providerLoadId,
    this.direction = FreightNegotiationDirection.to,
    this.status = FreightNegotiationStatus.offered,
    this.amountEur = 0,
    this.currency = 'EUR',
    this.counterpartyName = '',
    this.parentNegotiationId,
    this.createdAt,
  });

  factory FreightNegotiation.fromJson(Map<String, dynamic> json) =>
      FreightNegotiation(
        id: json['id']?.toString() ?? '',
        providerId: json['provider_id']?.toString() ?? '',
        providerLoadId: json['provider_load_id']?.toString() ?? '',
        direction:
            FreightNegotiationDirection.fromApiString(json['direction'] as String?),
        status: FreightNegotiationStatus.fromApiString(json['status'] as String?),
        amountEur: (json['amount_eur'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'EUR',
        counterpartyName: json['counterparty_name'] as String? ?? '',
        parentNegotiationId: json['parent_negotiation_id']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}

/// The negotiation thread for a load: an ordered list of records plus
/// convenience helpers for the sheet UI.
class FreightNegotiationThread {
  final List<FreightNegotiation> items;

  const FreightNegotiationThread({this.items = const []});

  factory FreightNegotiationThread.fromJson(Map<String, dynamic> json) {
    final raw = json['thread'];
    return FreightNegotiationThread(
      items: raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(FreightNegotiation.fromJson)
              .toList()
          : const [],
    );
  }

  bool get isEmpty => items.isEmpty;

  /// The most recent record (the current state of the negotiation).
  FreightNegotiation? get latest =>
      items.isEmpty ? null : items.last;

  /// Whether the negotiation has been settled (accepted / rejected / expired).
  bool get isSettled {
    final last = latest;
    if (last == null) return false;
    return last.status == FreightNegotiationStatus.accepted ||
        last.status == FreightNegotiationStatus.rejected ||
        last.status == FreightNegotiationStatus.expired;
  }
}
