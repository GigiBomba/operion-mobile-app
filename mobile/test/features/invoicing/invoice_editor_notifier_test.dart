import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/security/biometric_gate.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/features/invoicing/logic/invoice_calculation.dart';
import 'package:operion_mobile/features/invoicing/models/invoice.dart';
import 'package:operion_mobile/features/invoicing/providers/invoicing_providers.dart';

import '../../support/fake_local_database.dart';

/// Minimal ActionQueue stand-in that records enqueue calls.
class _RecordingActionQueue implements ActionQueue {
  final List<(String, String, Map<String, dynamic>)> enqueued = [];

  @override
  int get pendingCount => enqueued.length;

  @override
  int get staleCount => 0;

  @override
  Stream<ActionQueueState> get state => const Stream.empty();

  @override
  Future<String> enqueue(
    String endpoint,
    String method, {
    Map<String, dynamic>? data,
  }) async {
    enqueued.add((endpoint, method, data ?? const {}));
    return 'fake-id';
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dequeue(String id) async {}

  @override
  Future<int> replayAll(
    Future<dynamic> Function(QueuedAction action) executor,
  ) async =>
      0;

  @override
  Future<void> clear() async {}

  @override
  Future<void> clearStale() async {}

  @override
  void dispose() {}
}

/// InvoicingEndpoints stub that records calls and returns a valid InvoiceOut.
class _RecordingInvoicingEndpoints extends InvoicingEndpoints {
  _RecordingInvoicingEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<(String, String)> transitions = [];
  final List<Map<String, dynamic>> createdDrafts = [];
  int cmrCalls = 0;

  static String _statusAfter(String action) => switch (action) {
        'finalize' => 'finalized',
        'generate_xml' => 'xml_generated',
        'mark_paid' => 'paid',
        'cancel' => 'cancelled',
        _ => 'draft',
      };

  Map<String, dynamic> invoiceJson({String id = 'inv-1', String status = 'draft'}) => {
        'id': id,
        'invoice_number': 'INV-2026-0001',
        'client_id': 'c1',
        'client_name': 'Client A',
        'trip_id': 10,
        'status': status,
        'issue_date': '2026-08-01',
        'due_date': '2026-08-31',
        'subtotal_net': 300.0,
        'total_vat': 57.0,
        'total_gross': 357.0,
        'total_amount': 357.0,
        'line_items': <dynamic>[],
        'created_at': '2026-08-01T10:00:00Z',
        'updated_at': '2026-08-01T10:00:00Z',
      };

  @override
  Future<Response> transition(
    String id,
    String action, {
    CancelToken? cancelToken,
  }) async {
    transitions.add((id, action));
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: invoiceJson(id: id, status: _statusAfter(action)),
      statusCode: 200,
    );
  }

  @override
  Future<Response> createInvoice(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    createdDrafts.add(data);
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: invoiceJson(),
      statusCode: 200,
    );
  }

  @override
  Future<Response> updateInvoice(
    String id,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    createdDrafts.add({'id': id, ...data});
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: invoiceJson(id: id),
      statusCode: 200,
    );
  }

  @override
  Future<Response> saveCmr(
    String id,
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    cmrCalls++;
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'cmr_number': 'CMR-1', 'pdf_url': null},
      statusCode: 200,
    );
  }
}

ProviderContainer _container({
  bool offline = false,
  _RecordingInvoicingEndpoints? endpoints,
  _RecordingActionQueue? queue,
  BiometricGate? gate,
  FakeLocalDatabase? db,
}) {
  return ProviderContainer(
    overrides: [
      isOfflineProvider.overrideWith((ref) => offline),
      localDatabaseProvider.overrideWithValue(db ?? FakeLocalDatabase()),
      invoicingEndpointsProvider
          .overrideWithValue(endpoints ?? _RecordingInvoicingEndpoints()),
      actionQueueProvider.overrideWithValue(queue ?? _RecordingActionQueue()),
      biometricGateProvider.overrideWithValue(
        gate ?? BiometricGate(authenticate: (_) async => true),
      ),
    ],
  );
}

void main() {
  group('InvoiceEditorNotifier.recompute → delegates to P4 core', () {
    test('totals and line outputs match calculateInvoiceLines exactly', () {
      final container = _container();
      addTearDown(container.dispose);
      final notifier = container.read(invoiceEditorStateProvider.notifier);

      notifier.addLineItem();
      notifier.updateLineItem(
        0,
        const InvoiceLineItem(
          description: 'Transport',
          quantity: 3,
          unitPrice: 100,
          vatRate: 19,
        ),
      );
      notifier.addLineItem();
      notifier.updateLineItem(
        1,
        const InvoiceLineItem(
          description: 'Warehouse',
          quantity: 1,
          unitPrice: 50,
          discountPercent: 10,
          vatRate: 19,
        ),
      );

      // Same inputs fed straight to the P4 core.
      final expected = calculateInvoiceLines(const [
        InvoiceLineCalcInput(
          description: 'Transport',
          quantity: 3,
          unitPrice: 100,
          vatRate: 19,
        ),
        InvoiceLineCalcInput(
          description: 'Warehouse',
          quantity: 1,
          unitPrice: 50,
          discountPercent: 10,
          vatRate: 19,
        ),
      ]);

      final state = container.read(invoiceEditorStateProvider);
      expect(state.totals!.subtotalNet, expected.subtotalNet);
      expect(state.totals!.totalVat, expected.totalVat);
      expect(state.totals!.totalGross, expected.totalGross);

      // Per-line computed outputs are also delegated (not reimplemented).
      for (var i = 0; i < expected.lines.length; i++) {
        final line = state.lineItems[i];
        final exp = expected.lines[i];
        expect(line.taxableAmount, exp.taxableAmount);
        expect(line.vatAmount, exp.vatAmount);
        expect(line.lineTotal, exp.lineTotal);
        expect(line.discountAmount, exp.discountAmount);
      }

      // Concrete spot-check (no discounts, 19% VAT).
      expect(state.totals!.subtotalNet, 300.0 + 45.0);
      expect(state.totals!.totalVat, closeTo(57.0 + 8.55, 1e-9));
      expect(state.totals!.totalGross, closeTo(357.0 + 53.55, 1e-9));
    });

    test('addLineItem / removeLineItem update the totals', () {
      final container = _container();
      addTearDown(container.dispose);
      final notifier = container.read(invoiceEditorStateProvider.notifier);

      notifier.addLineItem();
      notifier.updateLineItem(
        0,
        const InvoiceLineItem(description: 'A', quantity: 2, unitPrice: 10),
      );
      expect(container.read(invoiceEditorStateProvider).totals!.totalGross, 20.0);

      notifier.removeLineItem(0);
      expect(container.read(invoiceEditorStateProvider).lineItems, isEmpty);
      expect(container.read(invoiceEditorStateProvider).totals!.totalGross, 0.0);
    });

    test('reorderLineItems changes order and recomputes', () {
      final container = _container();
      addTearDown(container.dispose);
      final notifier = container.read(invoiceEditorStateProvider.notifier);

      notifier.addLineItem();
      notifier.updateLineItem(
        0,
        const InvoiceLineItem(description: 'First', unitPrice: 1),
      );
      notifier.addLineItem();
      notifier.updateLineItem(
        1,
        const InvoiceLineItem(description: 'Second', unitPrice: 2),
      );

      notifier.reorderLineItems(1, 0);
      final state = container.read(invoiceEditorStateProvider);
      expect(state.lineItems.first.description, 'Second');
      expect(state.lineItems.last.description, 'First');
    });
  });

  group('saveDraft — §7 offline queueing', () {
    test('online: POSTs the draft and stores the returned invoice id', () async {
      final endpoints = _RecordingInvoicingEndpoints();
      final container = _container(endpoints: endpoints);
      addTearDown(container.dispose);
      final notifier = container.read(invoiceEditorStateProvider.notifier);

      notifier.setClient(clientId: 'c1', clientName: 'Client A');
      notifier.addLineItem();
      notifier.updateLineItem(
        0,
        const InvoiceLineItem(description: 'Transport', unitPrice: 100),
      );

      final invoice = await notifier.saveDraft();

      expect(invoice, isNotNull);
      expect(invoice!.id, 'inv-1');
      expect(endpoints.createdDrafts, hasLength(1));
      expect(endpoints.createdDrafts.single['client_id'], 'c1');
      expect(container.read(invoiceEditorStateProvider).invoiceId, 'inv-1');
    });

    test('offline: enqueues POST /api/v1/mobile/invoices, endpoint not called',
        () async {
      final endpoints = _RecordingInvoicingEndpoints();
      final queue = _RecordingActionQueue();
      final container = _container(
        offline: true,
        endpoints: endpoints,
        queue: queue,
      );
      addTearDown(container.dispose);

      container.read(invoiceEditorStateProvider.notifier)
          .setClient(clientId: 'c1', clientName: 'Client A');
      final invoice = await container
          .read(invoiceEditorStateProvider.notifier)
          .saveDraft();

      expect(invoice, isNull);
      expect(queue.enqueued, hasLength(1));
      expect(queue.enqueued.single.$1, '/api/v1/mobile/invoices');
      expect(queue.enqueued.single.$2, 'POST');
      expect(endpoints.createdDrafts, isEmpty);
    });

    test('missing client throws InvalidInvoiceDraft', () async {
      final container = _container();
      addTearDown(container.dispose);
      expect(
        container.read(invoiceEditorStateProvider.notifier).saveDraft(),
        throwsA(isA<InvalidInvoiceDraft>()),
      );
    });
  });

  group('transition — biometric gate (§12)', () {
    test('biometric FAILS → the transition API is never called', () async {
      final endpoints = _RecordingInvoicingEndpoints();
      final container = _container(
        endpoints: endpoints,
        gate: BiometricGate(authenticate: (_) async => false),
      );
      addTearDown(container.dispose);
      final notifier = container.read(invoiceEditorStateProvider.notifier);

      notifier.setClient(clientId: 'c1', clientName: 'Client A');
      await notifier.saveDraft();

      expect(
        () => notifier.transition(InvoiceTransitionAction.finalize),
        throwsA(isA<BiometricRequired>()),
      );
      expect(endpoints.transitions, isEmpty,
          reason: 'API must be unreachable without a successful biometric check');
    });

    test('biometric SUCCEEDS → transition called once with the right action',
        () async {
      final endpoints = _RecordingInvoicingEndpoints();
      final container = _container(endpoints: endpoints);
      addTearDown(container.dispose);
      final notifier = container.read(invoiceEditorStateProvider.notifier);

      notifier.setClient(clientId: 'c1', clientName: 'Client A');
      await notifier.saveDraft();

      final invoice = await notifier.transition(
        InvoiceTransitionAction.markPaid,
        biometricReason: 'test-reason',
      );
      expect(invoice, isNotNull);
      expect(endpoints.transitions, hasLength(1));
      expect(endpoints.transitions.single.$2, 'mark_paid');
    });

    test('grace window: second sensitive transition skips the re-prompt',
        () async {
      var prompts = 0;
      final gate = BiometricGate(authenticate: (_) async {
        prompts++;
        return true;
      });
      final endpoints = _RecordingInvoicingEndpoints();
      final container = _container(endpoints: endpoints, gate: gate);
      addTearDown(container.dispose);
      final notifier = container.read(invoiceEditorStateProvider.notifier);

      notifier.setClient(clientId: 'c1', clientName: 'Client A');
      await notifier.saveDraft();

      await notifier.transition(InvoiceTransitionAction.finalize);
      await notifier.transition(InvoiceTransitionAction.markPaid);

      expect(prompts, 1,
          reason: 'mark_paid within the 5-min grace window must not re-prompt');
      expect(endpoints.transitions, hasLength(2));
    });

    test('generate_xml does NOT require biometric confirmation', () async {
      var prompts = 0;
      final gate = BiometricGate(authenticate: (_) async {
        prompts++;
        return true;
      });
      final container = _container(gate: gate);
      addTearDown(container.dispose);
      final notifier = container.read(invoiceEditorStateProvider.notifier);

      notifier.setClient(clientId: 'c1', clientName: 'Client A');
      await notifier.saveDraft();
      await notifier.transition(InvoiceTransitionAction.generateXml);

      expect(prompts, 0,
          reason: 'generate_xml is not a biometric-gated action');
    });
  });

  group('transition — §7 offline rules', () {
    /// Seeds the editor with an existing draft (id known) so transitions can
    /// queue against a real invoice id — the realistic offline-edit flow.
    void seedExisting(ProviderContainer container) {
      container.read(invoiceEditorStateProvider.notifier).loadInvoice(
            Invoice.fromJson({
              'id': 'inv-1',
              'invoice_number': 'INV-2026-0001',
              'client_id': 'c1',
              'client_name': 'Client A',
              'status': 'draft',
            }),
          );
    }

    test('finalize offline → queued, endpoint not called', () async {
      final endpoints = _RecordingInvoicingEndpoints();
      final queue = _RecordingActionQueue();
      final container = _container(
        offline: true,
        endpoints: endpoints,
        queue: queue,
      );
      addTearDown(container.dispose);
      seedExisting(container);
      final notifier = container.read(invoiceEditorStateProvider.notifier);

      final result = await notifier.transition(InvoiceTransitionAction.finalize);

      expect(result, isNull);
      expect(queue.enqueued, hasLength(1));
      expect(queue.enqueued.single.$1, '/api/v1/mobile/invoices/inv-1/transition');
      expect(queue.enqueued.single.$2, 'POST');
      expect(queue.enqueued.single.$3['action'], 'finalize');
      expect(endpoints.transitions, isEmpty);
    });

    test('generate_xml offline → blocked, queue empty', () async {
      final endpoints = _RecordingInvoicingEndpoints();
      final queue = _RecordingActionQueue();
      final container = _container(
        offline: true,
        endpoints: endpoints,
        queue: queue,
      );
      addTearDown(container.dispose);
      seedExisting(container);
      final notifier = container.read(invoiceEditorStateProvider.notifier);

      expect(
        () => notifier.transition(InvoiceTransitionAction.generateXml),
        throwsA(isA<FinanceRequiresConnection>()),
      );
      expect(queue.enqueued, isEmpty);
      expect(endpoints.transitions, isEmpty);
    });

    test('mark_paid offline → blocked, queue empty', () async {
      final endpoints = _RecordingInvoicingEndpoints();
      final queue = _RecordingActionQueue();
      final container = _container(
        offline: true,
        endpoints: endpoints,
        queue: queue,
      );
      addTearDown(container.dispose);
      seedExisting(container);
      final notifier = container.read(invoiceEditorStateProvider.notifier);

      expect(
        () => notifier.transition(InvoiceTransitionAction.markPaid),
        throwsA(isA<FinanceRequiresConnection>()),
      );
      expect(queue.enqueued, isEmpty);
      expect(endpoints.transitions, isEmpty);
    });

    test('cancel offline → queued (cancel is queueable)', () async {
      final endpoints = _RecordingInvoicingEndpoints();
      final queue = _RecordingActionQueue();
      final container = _container(
        offline: true,
        endpoints: endpoints,
        queue: queue,
      );
      addTearDown(container.dispose);
      seedExisting(container);
      final notifier = container.read(invoiceEditorStateProvider.notifier);

      final result =
          await notifier.transition(InvoiceTransitionAction.cancel);

      expect(result, isNull);
      expect(queue.enqueued, hasLength(1));
      expect(queue.enqueued.single.$3['action'], 'cancel');
      expect(endpoints.transitions, isEmpty);
    });
  });

  group('cmrMutationProvider — §7/§12', () {
    test('offline CMR save → blocked, never queued, endpoint not called',
        () async {
      final endpoints = _RecordingInvoicingEndpoints();
      final queue = _RecordingActionQueue();
      final container = _container(
        offline: true,
        endpoints: endpoints,
        queue: queue,
      );
      addTearDown(container.dispose);

      expect(
        () => container
            .read(cmrMutationProvider.notifier)
            .saveCmr('inv-1', const CmrFormDraft(senderName: 'S')),
        throwsA(isA<FinanceRequiresConnection>()),
      );
      expect(queue.enqueued, isEmpty);
      expect(endpoints.cmrCalls, 0);
    });

    test('online CMR save → biometric gate → endpoint called', () async {
      var prompts = 0;
      final gate = BiometricGate(authenticate: (_) async {
        prompts++;
        return true;
      });
      final endpoints = _RecordingInvoicingEndpoints();
      final container = _container(endpoints: endpoints, gate: gate);
      addTearDown(container.dispose);

      final result = await container
          .read(cmrMutationProvider.notifier)
          .saveCmr('inv-1', const CmrFormDraft(senderName: 'Sender'));
      expect(result?.cmrNumber, 'CMR-1');
      expect(endpoints.cmrCalls, 1);
      expect(prompts, 1);
    });

    test('online CMR save with biometric FAILURE → endpoint not called',
        () async {
      final endpoints = _RecordingInvoicingEndpoints();
      final container = _container(
        endpoints: endpoints,
        gate: BiometricGate(authenticate: (_) async => false),
      );
      addTearDown(container.dispose);

      expect(
        () => container
            .read(cmrMutationProvider.notifier)
            .saveCmr('inv-1', const CmrFormDraft(senderName: 'S')),
        throwsA(isA<BiometricRequired>()),
      );
      expect(endpoints.cmrCalls, 0);
    });
  });

  group('invoice list providers — dual mode (§5)', () {
    test('network failure falls back to the invoices cache', () async {
      final db = FakeLocalDatabase()
        ..seedCollection('invoices', [
          {
            'id': 'inv-cached',
            'invoice_number': 'INV-2025-0999',
            'client_id': 'c1',
            'client_name': 'Cached Client',
            'status': 'draft',
          },
        ]);
      final container = ProviderContainer(
        overrides: [
          isOfflineProvider.overrideWith((ref) => false),
          localDatabaseProvider.overrideWithValue(db),
          invoicingEndpointsProvider
              .overrideWithValue(_ThrowingInvoicingEndpoints()),
        ],
      );
      addTearDown(container.dispose);

      final data = await container
          .read(invoiceListProvider(const InvoiceListFilter()).future);

      expect(data.fromCache, isTrue);
      expect(container.read(invoiceCachedBannerProvider), isTrue);
      expect(data.invoices.single.invoiceNumber, 'INV-2025-0999');
    });
  });
}

class _ThrowingInvoicingEndpoints extends InvoicingEndpoints {
  _ThrowingInvoicingEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  @override
  Future<Response> getInvoices(
    InvoiceListFilter filter, {
    CancelToken? cancelToken,
  }) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/api/v1/mobile/invoices'),
      type: DioExceptionType.connectionError,
    );
  }
}
