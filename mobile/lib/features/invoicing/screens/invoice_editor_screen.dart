import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/security/capture_blur_overlay.dart';
import '../../../core/security/screen_capture.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../clients/models/client.dart';
import '../../clients/providers/client_providers.dart';
import '../../history/providers/history_providers.dart';
import '../logic/invoice_calculation.dart';
import '../models/invoice.dart';
import '../providers/invoicing_providers.dart';
import '../widgets/status_stepper.dart';
import 'cmr_form_screen.dart';
import 'invoice_pdf_preview_screen.dart';

/// Invoice editor (blueprint §4.5).
///
/// - Trip picker (autocomplete over `tripHistoryProvider`).
/// - Line items via [ReorderableListView] (route_planner precedent) +
///   swipe/delete + add-line.
/// - Live totals footer driven by [InvoiceEditorNotifier.recompute], which
///   ALWAYS delegates to the P4 `calculateInvoiceLines` core.
/// - Primary action label per state (Save Draft / Finalize / Generate
///   e-Factura XML / Mark Paid) — each action runs the §12 biometric
///   gate before the transition call. (Gate-31: there is no ANAF Submit
///   step; xml_generated now fires mark_paid.)
/// - Status stepper in the header.
/// - FLAG_SECURE applied on init, cleared on dispose (§12).
class InvoiceEditorScreen extends ConsumerStatefulWidget {
  const InvoiceEditorScreen({super.key, this.invoiceId});

  /// Edits an existing invoice (loaded via `invoiceDetailProvider`).
  final String? invoiceId;

  /// Creates a brand-new invoice.
  factory InvoiceEditorScreen.newInvoice() => const InvoiceEditorScreen();

  @override
  ConsumerState<InvoiceEditorScreen> createState() =>
      _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends ConsumerState<InvoiceEditorScreen> {
  String? _liveInvoiceId;
  String? _seededInvoiceId;

  String? get _effectiveInvoiceId => widget.invoiceId ?? _liveInvoiceId;

  @override
  void initState() {
    super.initState();
    // Sensitive screen: block screenshots while visible (§12).
    enableSecureScreen();
    ref.read(invoiceEditorStateProvider.notifier).reset();
  }

  @override
  void dispose() {
    disableSecureScreen();
    super.dispose();
  }

  void _seedFromDetail(Invoice invoice) {
    if (_seededInvoiceId == invoice.id) return;
    _seededInvoiceId = invoice.id;
    ref.read(invoiceEditorStateProvider.notifier).loadInvoice(invoice);
  }

  Future<void> _pickClient() async {
    final result = await _showClientPickerSheet(context);
    if (result == null || !mounted) return;
    ref
        .read(invoiceEditorStateProvider.notifier)
        .setClient(clientId: result.$1, clientName: result.$2);
  }

  Future<void> _pickTrip() async {
    final result = await _showTripPickerSheet(context);
    if (result == null || !mounted) return;
    final notifier = ref.read(invoiceEditorStateProvider.notifier);
    notifier.setTrip(tripId: result.$1, clientName: result.$2);
    // Prefill the client when a trip's client matches a known client.
    final clientsAsync = ref.read(clientListProvider);
    final clients = clientsAsync.valueOrNull?.clients ?? const <Client>[];
    final match = clients.where((c) {
      final a = c.name.trim().toLowerCase();
      final b = result.$2.trim().toLowerCase();
      return a.isNotEmpty && b.isNotEmpty && a == b;
    }).toList();
    if (match.isNotEmpty) {
      notifier.setClient(clientId: match.first.id, clientName: match.first.name);
    }
  }

  Future<void> _editLine(int index) async {
    final editor = ref.read(invoiceEditorStateProvider);
    final updated = await _showLineItemSheet(context, editor.lineItems[index]);
    if (updated == null || !mounted) return;
    ref
        .read(invoiceEditorStateProvider.notifier)
        .updateLineItem(index, updated);
  }

  Future<void> _saveDraft() async {
    final notifier = ref.read(invoiceEditorStateProvider.notifier);
    try {
      final invoice = await notifier.saveDraft();
      if (invoice != null && mounted) {
        setState(() => _liveInvoiceId = invoice.id);
        _showMessage(context.loc.invoicing_savedDraft);
      } else if (mounted) {
        _showMessage(context.loc.invoicing_savedOffline);
      }
    } on InvalidInvoiceDraft {
      if (mounted) _showMessage(context.loc.invoicing_clientRequired);
    } catch (_) {
      if (mounted) _showMessage(context.loc.general_error);
    }
  }

  Future<void> _transition(
    InvoiceTransitionAction action, {
    required InvoiceStatus status,
  }) async {
    final notifier = ref.read(invoiceEditorStateProvider.notifier);
    try {
      final invoice = await notifier.transition(
        action,
        biometricReason: context.loc.invoicing_biometricReason,
      );
      if (invoice != null && mounted) {
        _showMessage(_transitionMessage(action, context.loc));
      } else if (mounted) {
        _showMessage(context.loc.invoicing_queuedOffline);
      }
    } on BiometricRequired {
      if (mounted) _showMessage(context.loc.invoicing_biometricDenied);
    } on FinanceRequiresConnection {
      if (mounted) {
        _showMessage(context.loc.invoicing_requiresConnection);
      }
    } catch (_) {
      if (mounted) _showMessage(context.loc.general_error);
    }
  }

  String _transitionMessage(InvoiceTransitionAction action, AppLocalizations loc) =>
      switch (action) {
        InvoiceTransitionAction.finalize => loc.invoicing_finalizedOk,
        InvoiceTransitionAction.generateXml => loc.invoicing_xmlGeneratedOk,
        InvoiceTransitionAction.markPaid => loc.invoicing_paidOk,
        InvoiceTransitionAction.cancel => loc.invoicing_cancelledOk,
      };

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final editorId = _effectiveInvoiceId;

    return CaptureBlurOverlay(
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.invoicing_title),
        actions: [
          if (editorId != null) ...[
            IconButton(
              icon: const Icon(LucideIcons.fileDown),
              tooltip: loc.invoicing_viewPdf,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      InvoicePdfPreviewScreen(invoiceId: editorId),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.fileSignature),
              tooltip: loc.invoicing_cmrTitle,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CmrFormScreen(
                    invoiceId: editorId,
                    tripId: ref.read(invoiceEditorStateProvider).tripId,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      body: editorId == null
          ? _EditorForm(
              invoice: null,
              onPickClient: _pickClient,
              onPickTrip: _pickTrip,
              onAddLine: () =>
                  ref.read(invoiceEditorStateProvider.notifier).addLineItem(),
              onEditLine: _editLine,
              onDeleteLine: (index) => ref
                  .read(invoiceEditorStateProvider.notifier)
                  .removeLineItem(index),
              onReorder: (o, n) => ref
                  .read(invoiceEditorStateProvider.notifier)
                  .reorderLineItems(o, n),
              onSaveDraft: _saveDraft,
              onTransition: _transition,
            )
          : Consumer(
              builder: (context, ref, _) {
                final invoiceId = editorId;
                final detailAsync = ref.watch(invoiceDetailProvider(invoiceId));
                // Seed the editor state when the detail resolves. The listener
                // fires OUTSIDE the build phase, so modifying the editor
                // provider here is safe (a write during `when`'s data builder
                // would throw "Tried to modify a provider while building").
                ref.listen(invoiceDetailProvider(invoiceId), (previous, next) {
                  next.whenData((data) => _seedFromDetail(data.invoice));
                });
                return detailAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text('${loc.general_error}: $e'),
                    ),
                  ),
                  data: (data) {
                    return _EditorForm(
                      invoice: data.invoice,
                      onPickClient: _pickClient,
                      onPickTrip: _pickTrip,
                      onAddLine: () => ref
                          .read(invoiceEditorStateProvider.notifier)
                          .addLineItem(),
                      onEditLine: _editLine,
                      onDeleteLine: (index) => ref
                          .read(invoiceEditorStateProvider.notifier)
                          .removeLineItem(index),
                      onReorder: (o, n) => ref
                          .read(invoiceEditorStateProvider.notifier)
                          .reorderLineItems(o, n),
                      onSaveDraft: _saveDraft,
                      onTransition: _transition,
                    );
                  },
                );
              },
            ),
        ),
      );
  }
}

/// The scrollable editor form (shared by new + existing invoices).
class _EditorForm extends ConsumerWidget {
  const _EditorForm({
    required this.invoice,
    required this.onPickClient,
    required this.onPickTrip,
    required this.onAddLine,
    required this.onEditLine,
    required this.onDeleteLine,
    required this.onReorder,
    required this.onSaveDraft,
    required this.onTransition,
  });

  final Invoice? invoice;
  final VoidCallback onPickClient;
  final VoidCallback onPickTrip;
  final VoidCallback onAddLine;
  final ValueChanged<int> onEditLine;
  final ValueChanged<int> onDeleteLine;
  final void Function(int, int) onReorder;
  final VoidCallback onSaveDraft;
  final void Function(InvoiceTransitionAction action, {required InvoiceStatus status}) onTransition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final editor = ref.watch(invoiceEditorStateProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        if (invoice != null) ...[
          InvoiceStatusStepper(status: invoice!.status),
          const SizedBox(height: AppSpacing.sm),
          const InvoiceStatusStepperLabels(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${loc.invoicing_invoiceNumber}: ${invoice!.invoiceNumber}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(loc.invoicing_client, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        _PickerTile(
          icon: Icons.business,
          text: editor.clientName?.isNotEmpty == true
              ? editor.clientName!
              : loc.invoicing_clientHint,
          muted: editor.clientName?.isNotEmpty != true,
          onTap: onPickClient,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(loc.invoicing_trip, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        _PickerTile(
          icon: Icons.route,
          text: editor.tripId != null
              ? '${loc.invoicing_tripShort} #${editor.tripId}'
              : loc.invoicing_tripHint,
          muted: editor.tripId == null,
          onTap: onPickTrip,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Text('${loc.invoicing_lineItems} (${editor.lineItems.length})',
                style: theme.textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: onAddLine,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: Text(loc.invoicing_addLine),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (editor.lineItems.isEmpty)
          EmptyState(
            icon: const Icon(LucideIcons.list, size: 48),
            title: loc.invoicing_noLines,
            subtitle: loc.invoicing_noLinesHint,
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: editor.lineItems.length,
            onReorderItem: (oldIndex, newIndex) => onReorder(oldIndex, newIndex),
            itemBuilder: (context, index) {
              final line = editor.lineItems[index];
              return Card(
                key: ValueKey('invoice_line_$index'),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: const Icon(LucideIcons.gripVertical, size: 20),
                  title: Text(
                    line.description.isEmpty
                        ? loc.invoicing_unnamedLine
                        : line.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${_num(line.quantity)} × ${_money(line.unitPrice)} '
                    '· ${loc.invoicing_vatShort} ${_num(line.vatRate)}%'
                    '${line.lineTotal > 0 ? ' · ${_money(line.lineTotal)}' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.pencil, size: 18),
                        tooltip: loc.general_edit,
                        onPressed: () => onEditLine(index),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.trash2, size: 18),
                        tooltip: loc.general_delete,
                        onPressed: () => onDeleteLine(index),
                      ),
                    ],
                  ),
                  onTap: () => onEditLine(index),
                ),
              );
            },
          ),
        const SizedBox(height: AppSpacing.lg),
        _TotalsFooter(totals: editor.totals),
        const SizedBox(height: AppSpacing.lg),
        ..._primaryActionButtons(
          invoice: invoice,
          editor: editor,
          loc: loc,
          onSaveDraft: onSaveDraft,
          onTransition: onTransition,
        ),
        if (editor.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            editor.error!,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ],
      ],
    );
  }

  /// Primary action per invoice state (§4.5), plus a secondary Cancel action
  /// for draft/finalized.
  List<Widget> _primaryActionButtons({
    required Invoice? invoice,
    required InvoiceEditorState editor,
    required AppLocalizations loc,
    required VoidCallback onSaveDraft,
    required void Function(InvoiceTransitionAction, {required InvoiceStatus status}) onTransition,
  }) {
    if (invoice == null) {
      return [
        AppButton.primary(
          label: loc.invoicing_saveDraft,
          isLoading: editor.busy,
          onPressed: editor.busy ? null : onSaveDraft,
        ),
      ];
    }

    final inv = invoice;

    final action = switch (inv.status) {
      InvoiceStatus.draft => (
          label: loc.invoicing_finalize,
          transition: InvoiceTransitionAction.finalize,
        ),
      InvoiceStatus.finalized => (
          label: loc.invoicing_generateXml,
          transition: InvoiceTransitionAction.generateXml,
        ),
      // Gate-31: the xml_generated primary action is Mark Paid — the former
      // Submit (ANAF) step no longer exists.
      InvoiceStatus.xmlGenerated => (
          label: loc.invoicing_markPaid,
          transition: InvoiceTransitionAction.markPaid,
        ),
      _ => (label: '', transition: null),
    };

    final canCancel =
        inv.status == InvoiceStatus.draft || inv.status == InvoiceStatus.finalized;

    return [
      if (action.transition != null)
        AppButton.primary(
          label: action.label,
          isLoading: editor.busy,
          onPressed: editor.busy
              ? null
              : () => onTransition(action.transition!, status: inv.status),
        )
      else
        AppButton.primary(
          label: loc.invoicing_noAction,
          onPressed: null,
        ),
      if (canCancel) ...[
        const SizedBox(height: AppSpacing.sm),
        AppButton.danger(
          label: loc.invoicing_cancel,
          onPressed: editor.busy
              ? null
              : () => onTransition(
                    InvoiceTransitionAction.cancel,
                    status: inv.status,
                  ),
        ),
      ],
    ];
  }

  static String _money(double value) => value.toStringAsFixed(2);
  static String _num(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

/// A tappable picker row (client / trip).
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.text,
    required this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted ? AppColors.textTertiary : null,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Live totals footer — every edit triggers [InvoiceEditorNotifier.recompute]
/// which delegates to the P4 `calculateInvoiceLines` core.
class _TotalsFooter extends StatelessWidget {
  const _TotalsFooter({required this.totals});

  final InvoiceCalculationResult? totals;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final t = totals;
    final subtotal = t?.subtotalNet ?? 0.0;
    final vat = t?.totalVat ?? 0.0;
    final gross = t?.totalGross ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Column(
        children: [
          _TotalRow(label: loc.invoicing_subtotal, value: subtotal),
          _TotalRow(label: loc.invoicing_vat, value: vat),
          const Divider(height: AppSpacing.md),
          _TotalRow(label: loc.invoicing_total, value: gross, emphasized: true),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasized
                  ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
                  : theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value.toStringAsFixed(2),
            style: emphasized
                ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Line-item editor sheet: the six editable fields. The returned item is fed
/// to [InvoiceEditorNotifier.updateLineItem] which recomputes totals via the
/// P4 core.
Future<InvoiceLineItem?> _showLineItemSheet(
  BuildContext context,
  InvoiceLineItem line,
) {
  return showModalBottomSheet<InvoiceLineItem>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _LineItemSheet(initial: line),
    ),
  );
}

class _LineItemSheet extends StatefulWidget {
  const _LineItemSheet({required this.initial});

  final InvoiceLineItem initial;

  @override
  State<_LineItemSheet> createState() => _LineItemSheetState();
}

class _LineItemSheetState extends State<_LineItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _description = TextEditingController(text: widget.initial.description);
  late final _quantity = TextEditingController(text: _fmt(widget.initial.quantity));
  late final _unitPrice = TextEditingController(text: _fmt(widget.initial.unitPrice));
  late final _discountPercent = TextEditingController(text: _fmt(widget.initial.discountPercent));
  late final _discountAmount = TextEditingController(text: _fmt(widget.initial.discountAmount));
  late final _vatRate = TextEditingController(text: _fmt(widget.initial.vatRate));

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _discountPercent.dispose();
    _discountAmount.dispose();
    _vatRate.dispose();
    super.dispose();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : '$v';

  double _parse(TextEditingController c, double fallback) =>
      double.tryParse(c.text.trim()) ?? fallback;

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final item = InvoiceLineItem(
      description: _description.text.trim(),
      quantity: _parse(_quantity, 1),
      unitPrice: _parse(_unitPrice, 0),
      discountPercent: _parse(_discountPercent, 0),
      discountAmount: _parse(_discountAmount, 0),
      vatRate: _parse(_vatRate, 0),
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(loc.invoicing_lineItem, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _description,
                labelText: loc.invoicing_description,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? loc.invoicing_descriptionRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _quantity,
                labelText: loc.invoicing_quantity,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final p = double.tryParse(v ?? '');
                  if (p == null || p <= 0) return loc.invoicing_quantityRequired;
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _unitPrice,
                labelText: loc.invoicing_unitPrice,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return loc.invoicing_priceRequired;
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _discountPercent,
                      labelText: loc.invoicing_discountPct,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      controller: _discountAmount,
                      labelText: loc.invoicing_discountAmount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _vatRate,
                labelText: loc.invoicing_vatRate,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton.primary(label: loc.general_save, onPressed: _submit),
              const SizedBox(height: AppSpacing.sm),
              AppButton.secondary(
                label: loc.general_cancel,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Trip picker sheet (autocomplete over tripHistoryProvider) ──────────

Future<(int, String)?> _showTripPickerSheet(BuildContext context) {
  return showModalBottomSheet<(int, String)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _TripPickerSheet(),
  );
}

class _TripPickerSheet extends ConsumerStatefulWidget {
  const _TripPickerSheet();

  @override
  ConsumerState<_TripPickerSheet> createState() => _TripPickerSheetState();
}

class _TripPickerSheetState extends ConsumerState<_TripPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _matches(TripHistoryEntry t, String q) {
    final haystack =
        '${t.clientName} ${t.origin} ${t.destination} ${t.id}'.toLowerCase();
    return haystack.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final tripsAsync = ref.watch(tripHistoryProvider(const TripHistoryFilter()));
    final q = _query.toLowerCase();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppTextField(
              controller: _controller,
              hintText: loc.invoicing_tripSearch,
              prefixIcon: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: tripsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (page) {
                final trips = page.items.where((t) => _matches(t, q)).toList();
                if (trips.isEmpty) {
                  return Center(
                    child: Text(
                      loc.invoicing_noTrips,
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final t = trips[index];
                    return ListTile(
                      title: Text(t.clientName),
                      subtitle: Text(
                        '${t.origin} → ${t.destination}\n'
                        '${t.startDate != null ? _date(t.startDate!) : ''}'
                        '${t.totalPriceEur != null ? ' · ${t.totalPriceEur!.toStringAsFixed(2)} €' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).pop((t.id, t.clientName)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Client picker sheet (autocomplete over clientListProvider) ─────────

Future<(String, String)?> _showClientPickerSheet(BuildContext context) {
  return showModalBottomSheet<(String, String)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ClientPickerSheet(),
  );
}

class _ClientPickerSheet extends ConsumerStatefulWidget {
  const _ClientPickerSheet();

  @override
  ConsumerState<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends ConsumerState<_ClientPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final clientsAsync = ref.watch(clientListProvider);
    final q = _query.toLowerCase();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppTextField(
              controller: _controller,
              hintText: loc.invoicing_clientSearch,
              prefixIcon: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: clientsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (data) {
                final clients =
                    data.clients.where((c) => c.name.toLowerCase().contains(q)).toList();
                if (clients.isEmpty) {
                  return Center(
                    child: Text(
                      loc.invoicing_noClients,
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final c = clients[index];
                    return ListTile(
                      leading: const Icon(Icons.business),
                      title: Text(c.name),
                      subtitle: Text(c.vatNumber?.isNotEmpty == true
                          ? c.vatNumber!
                          : loc.clients_active),
                      onTap: () =>
                          Navigator.of(context).pop((c.id, c.name)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
