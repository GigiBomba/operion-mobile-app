import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_errors.dart';
import '../../../core/network/paginated.dart';
import '../../../core/security/biometric_gate.dart';
import '../../../core/sync/action_queue.dart';
import '../logic/invoice_calculation.dart';
import '../models/invoice.dart';

/// Endpoint methods for the invoicing module (blueprint §4.5/§6.6).
///
/// All paths are relative to `/api/v1`. List endpoints follow the shared
/// `{items, total, page, page_size, total_pages}` envelope.
class InvoicingEndpoints {
  final ApiClient client;

  InvoicingEndpoints(this.client);

  /// `GET /mobile/invoices?status&client_id&search&page&page_size`.
  Future<Response> getInvoices(
    InvoiceListFilter filter, {
    CancelToken? cancelToken,
  }) =>
      client.get(
        '/api/v1/mobile/invoices',
        queryParameters: filter.toQuery(),
        cancelToken: cancelToken,
      );

  /// `GET /mobile/invoices/{id}` → InvoiceOut.
  Future<Response> getInvoice(String id, {CancelToken? cancelToken}) =>
      client.get('/api/v1/mobile/invoices/$id', cancelToken: cancelToken);

  /// `POST /mobile/invoices` (create draft) → InvoiceOut.
  Future<Response> createInvoice(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) =>
      client.post('/api/v1/mobile/invoices',
          data: data, cancelToken: cancelToken);

  /// `PATCH /mobile/invoices/{id}` (update draft) → InvoiceOut.
  Future<Response> updateInvoice(
    String id,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) =>
      client.patch('/api/v1/mobile/invoices/$id',
          data: data, cancelToken: cancelToken);

  /// `POST /mobile/invoices/{id}/transition` `{action}` → InvoiceOut.
  ///
  /// `action` is one of `finalize|generate_xml|mark_paid|cancel` (Gate-31:
  /// the backend removed the `submit` action — it now answers 422
  /// action_not_supported).
  Future<Response> transition(
    String id,
    String action, {
    CancelToken? cancelToken,
  }) =>
      client.post(
        '/api/v1/mobile/invoices/$id/transition',
        data: {'action': action},
        cancelToken: cancelToken,
      );

  /// `GET /mobile/invoices/{id}/pdf` → raw PDF bytes.
  Future<Response> getPdf(String id, {CancelToken? cancelToken}) =>
      client.get(
        '/api/v1/mobile/invoices/$id/pdf',
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.bytes),
      );

  /// `POST /mobile/invoices/{id}/cmr` → `{cmr_number, pdf_url}`.
  Future<Response> saveCmr(
    String id,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) =>
      client.post('/api/v1/mobile/invoices/$id/cmr',
          data: data, cancelToken: cancelToken);
}

/// Provides the singleton [InvoicingEndpoints] wired to the shared client.
final invoicingEndpointsProvider = Provider<InvoicingEndpoints>((ref) {
  return InvoicingEndpoints(ref.watch(apiClientProvider));
});

// ── List filter & list providers (dual-mode, §5) ──────────────────────

/// Filter state for the invoice list (status / client / search).
class InvoiceListFilter {
  final String? status;
  final String? clientId;
  final String? search;
  final int page;
  final int pageSize;

  const InvoiceListFilter({
    this.status,
    this.clientId,
    this.search,
    this.page = 1,
    this.pageSize = 20,
  });

  InvoiceListFilter copyWith({
    String? status,
    String? clientId,
    String? search,
    int? page,
    int? pageSize,
    bool clearStatus = false,
    bool clearClientId = false,
    bool clearSearch = false,
  }) {
    return InvoiceListFilter(
      status: clearStatus ? null : status ?? this.status,
      clientId: clearClientId ? null : clientId ?? this.clientId,
      search: clearSearch ? null : search ?? this.search,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  Map<String, dynamic> toQuery() => {
        if (status != null) 'status': status,
        if (clientId != null && clientId!.isNotEmpty) 'client_id': clientId,
        if (search != null && search!.isNotEmpty) 'search': search,
        'page': page,
        'page_size': pageSize,
      };

  @override
  bool operator ==(Object other) =>
      other is InvoiceListFilter &&
      other.status == status &&
      other.clientId == clientId &&
      other.search == search &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(status, clientId, search, page, pageSize);
}

/// The current invoice list filter (the screen edits this; the family key and
/// the editor's post-mutation invalidation both read it).
final invoiceListFilterProvider =
    StateProvider<InvoiceListFilter>((ref) => const InvoiceListFilter());

/// True while the invoice list/detail is showing cached (stale) data.
final invoiceCachedBannerProvider = StateProvider<bool>((ref) => false);

/// Result of an invoice list fetch.
class InvoiceListData {
  final List<Invoice> invoices;
  final bool fromCache;

  const InvoiceListData({required this.invoices, required this.fromCache});
}

/// Result of an invoice detail fetch.
class InvoiceDetailData {
  final Invoice invoice;
  final bool fromCache;

  const InvoiceDetailData({required this.invoice, required this.fromCache});
}

/// Dual-mode invoice list (blueprint §5). Network first; on failure falls back
/// to the LocalDatabase invoices cache and flags the cached banner. On success
/// the cache is refreshed.
final invoiceListProvider = FutureProvider.autoDispose
    .family<InvoiceListData, InvoiceListFilter>((ref, filter) async {
  final endpoints = ref.watch(invoicingEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  try {
    final response = await endpoints.getInvoices(filter,
        cancelToken: cancelToken);
    final data = response.data;
    final invoices = data is Map<String, dynamic>
        ? PaginatedResponse.fromJson(data, Invoice.fromJson).items
        : data is List
            ? data.whereType<Map<String, dynamic>>().map(Invoice.fromJson).toList()
            : <Invoice>[];
    await ref
        .read(localDatabaseProvider)
        .cacheInvoices(invoices.map((i) => i.toJson()).toList());
    ref.read(invoiceCachedBannerProvider.notifier).state = false;
    return InvoiceListData(invoices: invoices, fromCache: false);
  } catch (e) {
    // 401/403 must surface (force-logout path), connection failures stay cached.
    if (isAuthRejection(e)) rethrow;
    final cached = await ref.read(localDatabaseProvider).getCachedInvoices();
    final invoices = cached.map(Invoice.fromJson).toList();
    ref.read(invoiceCachedBannerProvider.notifier).state = invoices.isNotEmpty;
    return InvoiceListData(invoices: invoices, fromCache: true);
  }
});

/// Dual-mode invoice detail (`GET /mobile/invoices/{id}`).
final invoiceDetailProvider = FutureProvider.autoDispose
    .family<InvoiceDetailData, String>((ref, invoiceId) async {
  final endpoints = ref.watch(invoicingEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  try {
    final response =
        await endpoints.getInvoice(invoiceId, cancelToken: cancelToken);
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected invoice detail response: ${data.runtimeType}');
    }
    final invoice = Invoice.fromJson(data);
    await ref
        .read(localDatabaseProvider)
        .cacheData('invoices', invoiceId, invoice.toJson());
    ref.read(invoiceCachedBannerProvider.notifier).state = false;
    return InvoiceDetailData(invoice: invoice, fromCache: false);
  } catch (e) {
    if (isAuthRejection(e)) rethrow;
    final cached =
        await ref.read(localDatabaseProvider).getCachedData('invoices', invoiceId);
    if (cached == null) rethrow;
    return InvoiceDetailData(invoice: Invoice.fromJson(cached), fromCache: true);
  }
});

/// `GET /mobile/invoices/{id}/pdf` → raw PDF bytes for the preview screen.
final invoicePdfProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, invoiceId) async {
  final endpoints = ref.watch(invoicingEndpointsProvider);
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final response = await endpoints.getPdf(invoiceId, cancelToken: cancelToken);
  final data = response.data;
  if (data is Uint8List) return data;
  if (data is List<int>) return Uint8List.fromList(data);
  throw StateError('Unexpected PDF response type: ${data.runtimeType}');
});

// ── Finance offline rules & typed exceptions (§7) ─────────────────────

/// Thrown when a finance action requires a live connection but the device is
/// offline. generate_xml / mark_paid transitions and CMR saves are
/// NEVER queued — the UI shows the inline 'requires connection' message.
class FinanceRequiresConnection implements Exception {
  const FinanceRequiresConnection();
}

/// Thrown when the §12 biometric gate rejects a sensitive finance action.
class BiometricRequired implements Exception {
  const BiometricRequired();
}

/// Thrown when a draft cannot be saved (e.g. missing client).
class InvalidInvoiceDraft implements Exception {
  final String reason;
  const InvalidInvoiceDraft(this.reason);

  @override
  String toString() => 'InvalidInvoiceDraft($reason)';
}

// ── Transitions ───────────────────────────────────────────────────────

/// A transition action on `POST /mobile/invoices/{id}/transition`.
///
/// Gate-31 business decision: the invoice generator does NOT submit to ANAF —
/// there is no `submit` action. The machine is `draft→[finalized,cancelled]`,
/// `finalized→[xml_generated,cancelled,paid]`, `xml_generated→[paid,draft]`,
/// `paid/cancelled` terminal. The backend answers any legacy `submit` with
/// 422 action_not_supported.
enum InvoiceTransitionAction {
  finalize('finalize'),
  generateXml('generate_xml'),
  markPaid('mark_paid'),
  cancel('cancel');

  const InvoiceTransitionAction(this.apiValue);

  /// The exact backend `action` string.
  final String apiValue;

  /// Actions gated by the §12 biometric confirmation (§12 + 3B contract):
  /// finalize / mark_paid (+ CMR save). `cancel` and `generate_xml`
  /// do NOT require biometrics.
  bool get requiresBiometric => this == finalize || this == markPaid;
}

// ── Invoice editor (recompute delegates to the P4 core) ───────────────

/// Mutable editor state. `totals` is always the output of [recompute] which
/// delegates to the proven P4 `calculateInvoiceLines` — money math is never
/// reimplemented here.
class InvoiceEditorState {
  final String? invoiceId;
  final String? clientId;
  final String? clientName;
  final int? tripId;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final List<InvoiceLineItem> lineItems;
  final InvoiceCalculationResult? totals;
  final bool busy;
  final String? error;
  final bool savedOffline;

  const InvoiceEditorState({
    this.invoiceId,
    this.clientId,
    this.clientName,
    this.tripId,
    this.issueDate,
    this.dueDate,
    this.lineItems = const [],
    this.totals,
    this.busy = false,
    this.error,
    this.savedOffline = false,
  });

  InvoiceEditorState copyWith({
    String? invoiceId,
    String? clientId,
    String? clientName,
    int? tripId,
    DateTime? issueDate,
    DateTime? dueDate,
    List<InvoiceLineItem>? lineItems,
    InvoiceCalculationResult? totals,
    bool? busy,
    String? error,
    bool? savedOffline,
    bool clearError = false,
  }) {
    return InvoiceEditorState(
      invoiceId: invoiceId ?? this.invoiceId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      tripId: tripId ?? this.tripId,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      lineItems: lineItems ?? this.lineItems,
      totals: totals ?? this.totals,
      busy: busy ?? this.busy,
      error: clearError ? null : error ?? this.error,
      savedOffline: savedOffline ?? this.savedOffline,
    );
  }
}

/// Editor StateNotifier. [recompute] ALWAYS delegates to the P4 core
/// (`calculateInvoiceLines`) — byte-identical to the desktop service.
final invoiceEditorStateProvider =
    StateNotifierProvider<InvoiceEditorNotifier, InvoiceEditorState>((ref) {
  return InvoiceEditorNotifier(ref);
});

class InvoiceEditorNotifier extends StateNotifier<InvoiceEditorState> {
  InvoiceEditorNotifier(this._ref) : super(const InvoiceEditorState());

  final Ref _ref;

  bool get _isOffline => _ref.read(isOfflineProvider);

  /// Seeds the editor from an existing invoice (read-mode → edit-mode).
  void loadInvoice(Invoice invoice) {
    state = InvoiceEditorState(
      invoiceId: invoice.id,
      clientId: invoice.clientId,
      clientName: invoice.clientName,
      tripId: invoice.tripId,
      issueDate: invoice.issueDate,
      dueDate: invoice.dueDate,
      lineItems: [...invoice.lineItems],
    );
    recompute();
  }

  /// Resets the editor to an empty new-draft state.
  void reset() {
    state = const InvoiceEditorState();
  }

  void setClient({required String clientId, required String clientName}) {
    state = state.copyWith(clientId: clientId, clientName: clientName);
  }

  void setTrip({required int tripId, String? clientName}) {
    state = state.copyWith(tripId: tripId, clientName: clientName);
  }

  void setDates({DateTime? issueDate, DateTime? dueDate}) {
    state = state.copyWith(issueDate: issueDate, dueDate: dueDate);
  }

  void addLineItem() {
    state = state.copyWith(
      lineItems: [
        ...state.lineItems,
        const InvoiceLineItem(description: ''),
      ],
    );
    recompute();
  }

  void removeLineItem(int index) {
    if (index < 0 || index >= state.lineItems.length) return;
    final lines = [...state.lineItems]..removeAt(index);
    state = state.copyWith(lineItems: lines);
    recompute();
  }

  /// Moves a line item to a new position.
  ///
  /// [newIndex] follows the `onReorderItem` semantics of
  /// [ReorderableListView]: it is the final insertion index AFTER the item at
  /// [oldIndex] has been removed (no manual adjustment needed).
  void reorderLineItems(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= state.lineItems.length ||
        newIndex < 0 ||
        newIndex >= state.lineItems.length) {
      return;
    }
    final lines = [...state.lineItems];
    final item = lines.removeAt(oldIndex);
    lines.insert(newIndex, item);
    state = state.copyWith(lineItems: lines);
    recompute();
  }

  /// Replaces the editable fields of one line item (description/quantity/
  /// unit_price/discount_percent/discount_amount/vat_rate).
  void updateLineItem(int index, InvoiceLineItem item) {
    final lines = [...state.lineItems];
    lines[index] = item;
    state = state.copyWith(lineItems: lines);
    recompute();
  }

  /// Delegates to the P4 `calculateInvoiceLines` core (blueprint §4.5 mandate:
  /// never reimplement money math). Writes the computed OUTPUT fields
  /// (discount_amount/taxable_amount/vat_amount/line_total) back onto each line
  /// so the editor can display them, and stores the aggregates as [totals].
  void recompute() {
    final result = calculateInvoiceLines(
      state.lineItems.map((l) => l.toCalcInput()).toList(),
    );
    final computed = <InvoiceLineItem>[
      for (var i = 0; i < state.lineItems.length; i++)
        InvoiceLineItem(
          description: state.lineItems[i].description,
          quantity: state.lineItems[i].quantity,
          unitPrice: state.lineItems[i].unitPrice,
          discountPercent: state.lineItems[i].discountPercent,
          discountAmount: result.lines[i].discountAmount,
          vatRate: state.lineItems[i].vatRate,
          taxableAmount: result.lines[i].taxableAmount,
          vatAmount: result.lines[i].vatAmount,
          lineTotal: result.lines[i].lineTotal,
        ),
    ];
    state = state.copyWith(lineItems: computed, totals: result);
  }

  /// Saves the draft — `POST /mobile/invoices` (new) or
  /// `PATCH /mobile/invoices/{id}` (existing). Offline → queued via
  /// [actionQueueProvider] (blueprint §7: saveInvoiceDraft is queueable).
  ///
  /// Returns the saved [Invoice] when online, or `null` when the action was
  /// queued offline.
  Future<Invoice?> saveDraft() async {
    final clientId = state.clientId;
    if (clientId == null || clientId.isEmpty) {
      throw const InvalidInvoiceDraft('client_required');
    }
    final draft = InvoiceDraft(
      clientId: clientId,
      tripId: state.tripId,
      issueDate: state.issueDate,
      dueDate: state.dueDate,
      lineItems: state.lineItems,
    );

    final existingId = state.invoiceId;
    if (_isOffline) {
      await _enqueue(
        existingId == null
            ? '/api/v1/mobile/invoices'
            : '/api/v1/mobile/invoices/$existingId',
        existingId == null ? 'POST' : 'PATCH',
        draft.toJson(),
      );
      state = state.copyWith(busy: false, savedOffline: true);
      return null;
    }

    state = state.copyWith(busy: true, error: null);
    try {
      final response = existingId == null
          ? await _ref
              .read(invoicingEndpointsProvider)
              .createInvoice(draft.toJson())
          : await _ref
              .read(invoicingEndpointsProvider)
              .updateInvoice(existingId, draft.toJson());
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw StateError('Unexpected invoice save response: ${data.runtimeType}');
      }
      final invoice = Invoice.fromJson(data);
      state = state.copyWith(
        invoiceId: invoice.id,
        clientId: invoice.clientId,
        clientName: invoice.clientName,
        tripId: invoice.tripId,
        busy: false,
        error: null,
        savedOffline: false,
      );
      _ref.invalidate(invoiceListProvider(_ref.read(invoiceListFilterProvider)));
      if (existingId != null) {
        _ref.invalidate(invoiceDetailProvider(existingId));
      }
      return invoice;
    } catch (e, s) {
      state = state.copyWith(busy: false, error: '$e');
      Error.throwWithStackTrace(e, s);
    }
  }

  /// Runs a machine transition: finalize | generate_xml | mark_paid | cancel.
  ///
  /// §7 offline rules: finalize/cancel → queued offline; generate_xml/mark_paid
  /// → BLOCKED (throws [FinanceRequiresConnection], never queued).
  ///
  /// §12 biometric gate: finalize/mark_paid prompt BEFORE any network
  /// call — the API is unreachable without a successful check (test-proven).
  ///
  /// Returns the resulting [Invoice], or `null` when the action was queued
  /// offline.
  Future<Invoice?> transition(
    InvoiceTransitionAction action, {
    String? biometricReason,
  }) async {
    final invoiceId = state.invoiceId;
    if (invoiceId == null) {
      throw StateError('Cannot transition an unsaved invoice');
    }

    if (_isOffline) {
      switch (action) {
        case InvoiceTransitionAction.finalize:
        case InvoiceTransitionAction.cancel:
          // Queueable offline (§7).
          await _enqueue(
            '/api/v1/mobile/invoices/$invoiceId/transition',
            'POST',
            {'action': action.apiValue},
          );
          state = state.copyWith(busy: false, savedOffline: true);
          return null;
        case InvoiceTransitionAction.generateXml:
        case InvoiceTransitionAction.markPaid:
          // Never queued (§7): inline 'requires connection' surfaces.
          state = state.copyWith(busy: false, error: 'requires_connection');
          throw const FinanceRequiresConnection();
      }
    }

    if (action.requiresBiometric) {
      final ok = await _ref.read(biometricGateProvider).requireBiometricConfirmation(
            reason: biometricReason ?? BiometricGate.defaultReason,
          );
      if (!ok) {
        state = state.copyWith(busy: false, error: 'biometric_required');
        throw const BiometricRequired();
      }
    }

    state = state.copyWith(busy: true, error: null);
    try {
      final response = await _ref
          .read(invoicingEndpointsProvider)
          .transition(invoiceId, action.apiValue);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw StateError('Unexpected transition response: ${data.runtimeType}');
      }
      final invoice = Invoice.fromJson(data);
      state = state.copyWith(
        busy: false,
        error: null,
        savedOffline: false,
        invoiceId: invoice.id,
      );
      _ref.invalidate(invoiceDetailProvider(invoiceId));
      _ref.invalidate(invoiceListProvider(_ref.read(invoiceListFilterProvider)));
      return invoice;
    } catch (e, s) {
      state = state.copyWith(busy: false, error: '$e');
      Error.throwWithStackTrace(e, s);
    }
  }

  Future<void> _enqueue(
    String endpoint,
    String method,
    Map<String, dynamic> data,
  ) async {
    await _ref.read(actionQueueProvider).enqueue(endpoint, method, data: data);
  }
}

// ── CMR mutation (biometric-gated, never queued) ──────────────────────

/// CMR save state: `AsyncValue<CmrResult?>` — `null` when the response was
/// unexpected, errors surface [FinanceRequiresConnection]/[BiometricRequired].
final cmrMutationProvider =
    StateNotifierProvider<CmrMutationNotifier, AsyncValue<CmrResult?>>((ref) {
  return CmrMutationNotifier(ref);
});

class CmrMutationNotifier extends StateNotifier<AsyncValue<CmrResult?>> {
  CmrMutationNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  bool get _isOffline => _ref.read(isOfflineProvider);

  /// Saves a CMR for [invoiceId] — biometric-gated (§12) and NEVER queued
  /// offline (§7): an offline CMR would drop the signature and copy settings.
  Future<CmrResult?> saveCmr(
    String invoiceId,
    CmrFormDraft draft, {
    String? biometricReason,
  }) async {
    if (_isOffline) {
      state = const AsyncError(
        FinanceRequiresConnection(),
        StackTrace.empty,
      );
      throw const FinanceRequiresConnection();
    }

    final ok = await _ref.read(biometricGateProvider).requireBiometricConfirmation(
          reason: biometricReason ?? BiometricGate.defaultReason,
        );
    if (!ok) {
      state = const AsyncError(BiometricRequired(), StackTrace.empty);
      throw const BiometricRequired();
    }

    state = const AsyncLoading();
    try {
      final response = await _ref
          .read(invoicingEndpointsProvider)
          .saveCmr(invoiceId, draft.toJson());
      final data = response.data;
      final result =
          data is Map<String, dynamic> ? CmrResult.fromJson(data) : null;
      state = AsyncData(result);
      return result;
    } catch (e, s) {
      state = AsyncError(e, s);
      rethrow;
    }
  }
}
