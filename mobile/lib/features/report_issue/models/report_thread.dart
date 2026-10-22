import '../../../core/i18n/app_localizations.dart';

/// One message inside an async support report thread.
enum ReportEntryRole { customer, argo }

/// A single entry returned by `GET /api/v1/support/threads/{id}`.
class ReportEntry {
  const ReportEntry({
    required this.role,
    required this.text,
    this.createdAt,
  });

  final ReportEntryRole role;
  final String text;
  final DateTime? createdAt;

  bool get isCustomer => role == ReportEntryRole.customer;

  factory ReportEntry.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['role'] ?? '').toString().trim().toLowerCase();
    final isArgo = rawRole == 'argo' ||
        rawRole == 'assistant' ||
        rawRole == 'support' ||
        rawRole == 'agent' ||
        rawRole == 'bot';
    return ReportEntry(
      role: isArgo ? ReportEntryRole.argo : ReportEntryRole.customer,
      text: (json['text'] ?? json['message'] ?? '').toString(),
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      ),
    );
  }
}

/// Customer-facing coarse status (blueprint §6.9 / §41.3f).
enum ReportStatus {
  logged,
  beingInvestigated,
  fixInReview,
  fixed,
  needsCloserLook,
}

/// Maps the wire-level status (which may be an internal state name) onto the
/// six-state customer-facing vocabulary from §6.9. Unknown values fall back to
/// [ReportStatus.logged] instead of surfacing an internal enum name.
ReportStatus parseReportStatus(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'awaiting_reply':
    case 'awaiting_customer':
      // Still in the customer-facing "Logged" bucket: the thread is open and
      // the next move is the customer's answer, not an investigation step.
      return ReportStatus.logged;
    case 'being_investigated':
    case 'being_investigation':
    case 'investigating':
    case 'in_progress':
    case 'in_sandbox':
    case 'root_cause_analysis':
    case 'patch_generating':
      return ReportStatus.beingInvestigated;
    case 'fix_in_review':
    case 'pending_approval':
    case 'awaiting_release':
      return ReportStatus.fixInReview;
    case 'deployed':
    case 'fix_deployed':
    case 'fixed':
    case 'resolved':
    case 'wont_fix':
    case 'closed':
      return ReportStatus.fixed;
    case 'needs_engineering_attention':
    case 'escalated':
      return ReportStatus.needsCloserLook;
    case 'logged':
    case 'new':
    case 'triaged':
    case 'open':
    case '':
      return ReportStatus.logged;
    default:
      return ReportStatus.logged;
  }
}

/// True when the wire status means the report needs no further customer reply.
bool isResolvedStatus(String? raw) {
  return parseReportStatus(raw) == ReportStatus.fixed;
}

/// Localized customer-facing label for a status (§41.3f).
extension ReportStatusLabel on ReportStatus {
  String label(AppLocalizations loc) {
    switch (this) {
      case ReportStatus.logged:
        return loc.reportIssue_statusLogged;
      case ReportStatus.beingInvestigated:
        return loc.reportIssue_statusBeingInvestigated;
      case ReportStatus.fixInReview:
        return loc.reportIssue_statusFixInReview;
      case ReportStatus.fixed:
        return loc.reportIssue_statusFixed;
      case ReportStatus.needsCloserLook:
        return loc.reportIssue_statusNeedsAttention;
    }
  }
}

/// A report thread: the original report plus ARGO replies / clarifying
/// questions, and the flags that drive Compose/Thread mode selection.
class ReportThread {
  const ReportThread({
    required this.conversationId,
    this.ticketId,
    required this.status,
    required this.requiresReply,
    required this.resolved,
    required this.entries,
  });

  final String conversationId;
  final String? ticketId;
  final ReportStatus status;
  final bool requiresReply;
  final bool resolved;
  final List<ReportEntry> entries;

  /// The first customer entry is the original report (§41.3d Mode B item 2).
  ReportEntry? get originalReport {
    for (final entry in entries) {
      if (entry.isCustomer) return entry;
    }
    return null;
  }

  /// Everything after the original report, in display order.
  List<ReportEntry> get followUps {
    final original = originalReport;
    var skippedOriginal = false;
    final result = <ReportEntry>[];
    for (final entry in entries) {
      if (!skippedOriginal && identical(entry, original)) {
        skippedOriginal = true;
        continue;
      }
      result.add(entry);
    }
    return result;
  }

  /// A clarifying question awaits an answer only when the backend says so and
  /// the report is not resolved (§41.3d Mode B item 4).
  bool get canReply => requiresReply && !resolved;

  /// Parses the proxy thread payload defensively. Missing flags are derived
  /// from the status / entries so an older backend still renders.
  factory ReportThread.fromJson(
    Map<String, dynamic> json, {
    String? fallbackConversationId,
  }) {
    final rawStatus =
        (json['status'] ?? json['coarse_status'] ?? '').toString();
    final status = parseReportStatus(rawStatus);
    final resolved = _asBool(json['resolved']) || isResolvedStatus(rawStatus);
    final requiresReply = _asBool(json['requires_reply']) ||
        _asBool(json['requires_action']);
    final entries = <ReportEntry>[];
    final rawEntries = json['entries'] ?? json['messages'];
    if (rawEntries is List) {
      for (final item in rawEntries) {
        if (item is Map) {
          entries.add(
            ReportEntry.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return ReportThread(
      conversationId: (json['conversation_id'] ??
              json['conversationId'] ??
              fallbackConversationId ??
              '')
          .toString(),
      ticketId: json['ticket_id']?.toString(),
      status: status,
      requiresReply: requiresReply && !resolved,
      resolved: resolved,
      entries: entries,
    );
  }

  /// Applies the `POST /threads/{id}/reply` result to this thread.
  ///
  /// The reply endpoint returns the same additive `SupportResponse` shape as
  /// the submit endpoint (`reply` / `requires_reply` / `ticket_id`), not a
  /// full thread payload, so the local thread is extended in place. A reply
  /// with `requires_reply=false` is terminal for an async report: the loop
  /// reached a resolution (ticket created, answer given or escalation).
  ReportThread mergeReply(ReportSubmitResult result, String sentMessage) {
    final sent = sentMessage.trim();
    final argoReply = result.reply.trim();
    final terminal = !result.requiresReply && argoReply.isNotEmpty;
    return copyWith(
      ticketId: result.ticketId ?? ticketId,
      status: terminal ? ReportStatus.fixed : status,
      requiresReply: result.requiresReply,
      resolved: terminal || resolved,
      entries: [
        ...entries,
        if (sent.isNotEmpty)
          ReportEntry(role: ReportEntryRole.customer, text: sent),
        if (argoReply.isNotEmpty)
          ReportEntry(role: ReportEntryRole.argo, text: argoReply),
      ],
    );
  }

  ReportThread copyWith({
    String? conversationId,
    String? ticketId,
    ReportStatus? status,
    bool? requiresReply,
    bool? resolved,
    List<ReportEntry>? entries,
  }) {
    return ReportThread(
      conversationId: conversationId ?? this.conversationId,
      ticketId: ticketId ?? this.ticketId,
      status: status ?? this.status,
      requiresReply: requiresReply ?? this.requiresReply,
      resolved: resolved ?? this.resolved,
      entries: entries ?? this.entries,
    );
  }
}

/// Parsed `POST /api/v1/support/messages` response.
class ReportSubmitResult {
  const ReportSubmitResult({
    required this.conversationId,
    required this.reply,
    required this.requiresAction,
    required this.escalated,
    this.ticketId,
    required this.requiresReply,
  });

  final String conversationId;
  final String reply;
  final bool requiresAction;
  final bool escalated;
  final String? ticketId;
  final bool requiresReply;

  factory ReportSubmitResult.fromJson(Map<String, dynamic> json) {
    return ReportSubmitResult(
      conversationId: (json['conversation_id'] ?? json['conversationId'] ?? '')
          .toString(),
      reply: (json['reply'] ?? '').toString(),
      requiresAction: _asBool(json['requires_action']),
      escalated: _asBool(json['escalated']),
      ticketId: json['ticket_id']?.toString(),
      requiresReply: _asBool(json['requires_reply']) ||
          _asBool(json['requires_action']),
    );
  }

  /// Builds the local thread state shown immediately after a submit, without
  /// waiting for the resolution loop (§41.3b: ack first, thread later).
  ReportThread toThread(String submittedMessage) {
    final entries = <ReportEntry>[
      if (submittedMessage.trim().isNotEmpty)
        ReportEntry(
          role: ReportEntryRole.customer,
          text: submittedMessage.trim(),
        ),
      if (reply.trim().isNotEmpty)
        ReportEntry(role: ReportEntryRole.argo, text: reply.trim()),
    ];
    return ReportThread(
      conversationId: conversationId,
      ticketId: ticketId,
      status: ReportStatus.logged,
      requiresReply: requiresReply,
      resolved: false,
      entries: entries,
    );
  }
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}
