/// Invoice models + drafts for the finance feature (blueprint §4.5).
///
/// Parsed from the real backend `InvoiceOut` shape:
/// `{id, invoice_number, client_id, client_name, trip_id, status, issue_date,
/// due_date, subtotal_net, total_vat, total_gross, total_amount, line_items:
/// [...], created_at, updated_at}`. `status` uses the REAL backend strings
/// (draft/finalized/xml_generated/...) — mapped via [InvoiceStatus.fromApiString].
library;

import '../logic/invoice_calculation.dart';

DateTime? _parseDateTime(dynamic value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value > 1e12 ? value : value * 1000);
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Invoice lifecycle status — REAL backend strings (Phase-0 contract,
/// "Contract decisions locked (3A/3B basis)").
///
/// Gate-31 business decision: the invoice generator does NOT submit to ANAF.
/// The machine is now `draft → finalized → xml_generated → paid` with
/// `cancelled` terminal. The backend removed the submission states
/// (submitted_externally / queued / submitting / accepted / rejected /
/// manual_review); [fromApiString] still parses those legacy strings
/// defensively so historical cached rows keep rendering sensibly.
enum InvoiceStatus {
  draft('draft'),
  finalized('finalized'),
  xmlGenerated('xml_generated'),
  paid('paid'),
  cancelled('cancelled');

  const InvoiceStatus(this.apiValue);

  /// The exact backend string for this status.
  final String apiValue;

  /// Legacy submission-state strings from the pre-Gate-31 machine. The
  /// backend no longer produces them, but locally-cached rows may still
  /// contain them — each is mapped to the closest current status so a
  /// historical row never silently renders as a fresh draft.
  static const Map<String, InvoiceStatus> _legacyStatusMap = {
    'submitted_externally': InvoiceStatus.xmlGenerated,
    'queued': InvoiceStatus.xmlGenerated,
    'submitting': InvoiceStatus.xmlGenerated,
    'accepted': InvoiceStatus.xmlGenerated,
    'rejected': InvoiceStatus.cancelled,
    'manual_review': InvoiceStatus.xmlGenerated,
  };

  /// Maps a raw backend status string to an [InvoiceStatus].
  ///
  /// Legacy submission strings are parsed defensively via [_legacyStatusMap];
  /// unknown/absent values resolve to [InvoiceStatus.draft] (safe default).
  static InvoiceStatus fromApiString(String? value) {
    final legacy = value == null ? null : _legacyStatusMap[value];
    if (legacy != null) return legacy;
    for (final status in InvoiceStatus.values) {
      if (status.apiValue == value) return status;
    }
    return InvoiceStatus.draft;
  }
}

/// The mobile stepper subset (§4.5, Gate-31): the linear happy path plus the
/// cancel branch, mapped to the REAL backend strings.
///
/// `draft → finalized → xml_generated → paid`, with `cancelled` as a terminal
/// side-branch. (The former `submitted_externally` step is gone — the invoice
/// generator no longer submits to ANAF.)
const List<InvoiceStatus> kStepperStatuses = [
  InvoiceStatus.draft,
  InvoiceStatus.finalized,
  InvoiceStatus.xmlGenerated,
  InvoiceStatus.paid,
];

/// One invoice line item (`InvoiceLineItem` in `InvoiceOut`).
class InvoiceLineItem {
  final String description;
  final double quantity;
  final double unitPrice;
  final double discountPercent;
  final double discountAmount;
  final double vatRate;
  final double taxableAmount;
  final double vatAmount;
  final double lineTotal;

  const InvoiceLineItem({
    required this.description,
    this.quantity = 1.0,
    this.unitPrice = 0.0,
    this.discountPercent = 0.0,
    this.discountAmount = 0.0,
    this.vatRate = 0.0,
    this.taxableAmount = 0.0,
    this.vatAmount = 0.0,
    this.lineTotal = 0.0,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) =>
      InvoiceLineItem(
        description: json['description']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
        discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0.0,
        discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
        vatRate: (json['vat_rate'] as num?)?.toDouble() ?? 0.0,
        taxableAmount: (json['taxable_amount'] as num?)?.toDouble() ?? 0.0,
        vatAmount: (json['vat_amount'] as num?)?.toDouble() ?? 0.0,
        lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount_percent': discountPercent,
        'discount_amount': discountAmount,
        'vat_rate': vatRate,
        'taxable_amount': taxableAmount,
        'vat_amount': vatAmount,
        'line_total': lineTotal,
      };

  /// Feeds the P4 calculation core (blueprint §4.5 mandate): recompute ALWAYS
  /// delegates to `calculateInvoiceLines`, never reimplements money math.
  InvoiceLineCalcInput toCalcInput() => InvoiceLineCalcInput(
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
        discountPercent: discountPercent,
        discountAmount: discountAmount,
        vatRate: vatRate,
      );

  InvoiceLineItem copyWith({
    String? description,
    double? quantity,
    double? unitPrice,
    double? discountPercent,
    double? discountAmount,
    double? vatRate,
    double? taxableAmount,
    double? vatAmount,
    double? lineTotal,
  }) {
    return InvoiceLineItem(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      vatRate: vatRate ?? this.vatRate,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      vatAmount: vatAmount ?? this.vatAmount,
      lineTotal: lineTotal ?? this.lineTotal,
    );
  }
}

/// An invoice (`InvoiceOut`).
class Invoice {
  final String id;
  final String invoiceNumber;
  final String clientId;
  final String clientName;
  final int? tripId;
  final InvoiceStatus status;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final double subtotalNet;
  final double totalVat;
  final double totalGross;
  final double totalAmount;
  final List<InvoiceLineItem> lineItems;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.clientId,
    required this.clientName,
    this.tripId,
    this.status = InvoiceStatus.draft,
    this.issueDate,
    this.dueDate,
    this.subtotalNet = 0,
    this.totalVat = 0,
    this.totalGross = 0,
    this.totalAmount = 0,
    this.lineItems = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final rawLines = json['line_items'];
    return Invoice(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      clientName: json['client_name']?.toString() ?? '',
      tripId: (json['trip_id'] as num?)?.toInt(),
      status: InvoiceStatus.fromApiString(json['status'] as String?),
      issueDate: json['issue_date'] != null
          ? DateTime.tryParse(json['issue_date'].toString())
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      subtotalNet: (json['subtotal_net'] as num?)?.toDouble() ?? 0,
      totalVat: (json['total_vat'] as num?)?.toDouble() ?? 0,
      totalGross: (json['total_gross'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      lineItems: rawLines is List
          ? rawLines
              .whereType<Map<String, dynamic>>()
              .map(InvoiceLineItem.fromJson)
              .toList()
          : const [],
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoice_number': invoiceNumber,
        'client_id': clientId,
        'client_name': clientName,
        'trip_id': tripId,
        'status': status.apiValue,
        'issue_date': issueDate?.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'subtotal_net': subtotalNet,
        'total_vat': totalVat,
        'total_gross': totalGross,
        'total_amount': totalAmount,
        'line_items': lineItems.map((l) => l.toJson()).toList(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Invoice copyWith({
    String? invoiceNumber,
    String? clientId,
    String? clientName,
    int? tripId,
    InvoiceStatus? status,
    DateTime? issueDate,
    DateTime? dueDate,
    double? subtotalNet,
    double? totalVat,
    double? totalGross,
    double? totalAmount,
    List<InvoiceLineItem>? lineItems,
  }) {
    return Invoice(
      id: id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      tripId: tripId ?? this.tripId,
      status: status ?? this.status,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      subtotalNet: subtotalNet ?? this.subtotalNet,
      totalVat: totalVat ?? this.totalVat,
      totalGross: totalGross ?? this.totalGross,
      totalAmount: totalAmount ?? this.totalAmount,
      lineItems: lineItems ?? this.lineItems,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Create/update invoice input (`POST/PATCH /mobile/invoices`).
class InvoiceDraft {
  final String clientId;
  final int? tripId;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final List<InvoiceLineItem> lineItems;

  const InvoiceDraft({
    required this.clientId,
    this.tripId,
    this.issueDate,
    this.dueDate,
    this.lineItems = const [],
  });

  Map<String, dynamic> toJson() => {
        'client_id': clientId,
        if (tripId != null) 'trip_id': tripId,
        if (issueDate != null) 'issue_date': _isoDate(issueDate!),
        if (dueDate != null) 'due_date': _isoDate(dueDate!),
        'line_items': lineItems.map((l) => l.toJson()).toList(),
      };
}

/// CMR form input (`POST /mobile/invoices/{id}/cmr`).
///
/// Field set adapted from the desktop `CmrGenerateRequest`; the backend fills
/// consignee/goods from the trip data and persists the signature PNG.
class CmrFormDraft {
  final int? tripId;
  final String language;
  final int copies;
  final bool includeStamps;
  final String senderName;
  final String senderAddress;
  final String carrierName;
  final String carrierLicense;
  final String? remarks;
  final String? signaturePngBase64;

  const CmrFormDraft({
    this.tripId,
    this.language = 'ro',
    this.copies = 1,
    this.includeStamps = false,
    this.senderName = '',
    this.senderAddress = '',
    this.carrierName = '',
    this.carrierLicense = '',
    this.remarks,
    this.signaturePngBase64,
  });

  Map<String, dynamic> toJson() => {
        if (tripId != null) 'trip_id': tripId,
        'language': language,
        'copies': copies,
        'include_stamps': includeStamps,
        'sender_name': senderName,
        'sender_address': senderAddress,
        'carrier_name': carrierName,
        'carrier_license': carrierLicense,
        if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
        if (signaturePngBase64 != null && signaturePngBase64!.isNotEmpty)
          'signature_png_base64': signaturePngBase64,
      };

  CmrFormDraft copyWith({
    int? tripId,
    String? language,
    int? copies,
    bool? includeStamps,
    String? senderName,
    String? senderAddress,
    String? carrierName,
    String? carrierLicense,
    String? remarks,
    String? signaturePngBase64,
  }) {
    return CmrFormDraft(
      tripId: tripId ?? this.tripId,
      language: language ?? this.language,
      copies: copies ?? this.copies,
      includeStamps: includeStamps ?? this.includeStamps,
      senderName: senderName ?? this.senderName,
      senderAddress: senderAddress ?? this.senderAddress,
      carrierName: carrierName ?? this.carrierName,
      carrierLicense: carrierLicense ?? this.carrierLicense,
      remarks: remarks ?? this.remarks,
      signaturePngBase64: signaturePngBase64 ?? this.signaturePngBase64,
    );
  }
}

/// CMR save result (`POST /mobile/invoices/{id}/cmr`).
class CmrResult {
  final String cmrNumber;
  final String? pdfUrl;

  const CmrResult({required this.cmrNumber, this.pdfUrl});

  factory CmrResult.fromJson(Map<String, dynamic> json) => CmrResult(
        cmrNumber: json['cmr_number']?.toString() ?? '',
        pdfUrl: json['pdf_url']?.toString(),
      );
}
