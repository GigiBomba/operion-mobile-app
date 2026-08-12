import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_guard.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/master_detail_layout.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/invoice.dart';
import '../providers/invoicing_providers.dart';
import 'invoice_editor_screen.dart';

/// Invoice list (blueprint §4.5): status chips + debounced search, dual-mode
/// (network → cached banner). Rows show invoice number, client, status badge,
/// totals and due date. Create FAB is gated by `can_create_invoice` (§8.2).
///
/// On tablet widths (≥600dp) the list becomes the list pane of a
/// master-detail layout with the invoice editor as the detail pane (§9 item 5).
class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key, this.enableTabletLayout = true});

  final bool enableTabletLayout;

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _localFilter = '';
  InvoiceStatus? _selectedStatus;
  int? _selectedIndex;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _localFilter = value.trim().toLowerCase());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _setFilter(search: value.trim());
      }
    });
  }

  void _setFilter({String? search, InvoiceStatus? status}) {
    final current = ref.read(invoiceListFilterProvider);
    ref.read(invoiceListFilterProvider.notifier).state = current.copyWith(
      search: search,
      status: status?.apiValue,
      clearSearch: search == null,
      clearStatus: status == null,
    );
  }

  void _selectStatus(InvoiceStatus? status) {
    setState(() => _selectedStatus = status);
    _setFilter(status: status);
  }

  Future<void> _openCreate() async {
    final editor = InvoiceEditorScreen.newInvoice();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => editor),
    );
  }

  Future<void> _openDetail(Invoice invoice) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoiceEditorScreen(invoiceId: invoice.id),
      ),
    );
  }

  List<Invoice> _filter(InvoiceListData data) {
    return data.invoices
        .where((i) =>
            _localFilter.isEmpty ||
            i.invoiceNumber.toLowerCase().contains(_localFilter) ||
            i.clientName.toLowerCase().contains(_localFilter))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final showCachedBanner = ref.watch(invoiceCachedBannerProvider);
    final filter = ref.watch(invoiceListFilterProvider);
    final listAsync = ref.watch(invoiceListProvider(filter));
    final visibleInvoices = listAsync.valueOrNull == null
        ? const <Invoice>[]
        : _filter(listAsync.valueOrNull!);
    final tablet = widget.enableTabletLayout &&
        isTabletWidth(context) &&
        visibleInvoices.isNotEmpty;

    final listPane = Column(
      children: [
        if (showCachedBanner) _CachedBanner(label: loc.invoicing_cached),
        _StatusChips(
          selected: _selectedStatus,
          onSelect: _selectStatus,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: AppTextField(
            controller: _searchController,
            hintText: loc.invoicing_searchHint,
            prefixIcon: const Icon(Icons.search),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: listAsync.when(
            loading: () => ListView.builder(
              itemCount: 6,
              itemBuilder: (_, _) => const ShimmerCard(),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${loc.general_error}: $e',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(invoiceListProvider(filter)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(loc.general_retry),
                    ),
                  ],
                ),
              ),
            ),
            data: (_) {
              final invoices = visibleInvoices;
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(invoiceListProvider(filter));
                  await ref.read(invoiceListProvider(filter).future);
                },
                child: invoices.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: AppSpacing.xxl * 3),
                          EmptyState(
                            icon: const Icon(Icons.receipt_long, size: 56),
                            title: loc.invoicing_emptyTitle,
                            subtitle: loc.invoicing_emptyHint,
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        itemCount: invoices.length,
                        itemBuilder: (context, index) {
                          final invoice = invoices[index];
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              onTap: tablet
                                  ? () => setState(() => _selectedIndex = index)
                                  : () => _openDetail(invoice),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            invoice.invoiceNumber,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        StatusBadge(
                                          statusKey:
                                              _badgeKey(invoice.status),
                                          label:
                                              _statusLabel(invoice.status, loc),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      invoice.clientName,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '${loc.invoicing_total}: '
                                            '${_money(invoice.totalGross)}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (invoice.dueDate != null)
                                          Flexible(
                                            child: Text(
                                              '${loc.invoicing_due}: '
                                              '${_date(invoice.dueDate!)}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              );
            },
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(loc.nav_invoicing)),
      body: tablet
          ? MasterDetailLayout(
              selectedIndex: _selectedIndex ?? 0,
              listPane: listPane,
              detailBuilder: (context, index) {
                final sel = index.clamp(0, visibleInvoices.length - 1);
                return InvoiceEditorScreen(
                    invoiceId: visibleInvoices[sel].id);
              },
            )
          : listPane,
      floatingActionButton: buildIfPermitted(
        ref,
        Permissions.createInvoice,
        () => FloatingActionButton(
          onPressed: _openCreate,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  static String _money(double value) => value.toStringAsFixed(2);

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _badgeKey(InvoiceStatus status) => switch (status) {
        InvoiceStatus.draft => 'planned',
        InvoiceStatus.finalized => 'in_progress',
        InvoiceStatus.xmlGenerated => 'in_progress',
        InvoiceStatus.paid => 'paid',
        InvoiceStatus.cancelled => 'cancelled',
      };

  static String _statusLabel(InvoiceStatus status, AppLocalizations loc) =>
      switch (status) {
        InvoiceStatus.draft => loc.invoicing_statusDraft,
        InvoiceStatus.finalized => loc.invoicing_statusFinalized,
        InvoiceStatus.xmlGenerated => loc.invoicing_statusXml,
        InvoiceStatus.paid => loc.invoicing_statusPaid,
        InvoiceStatus.cancelled => loc.invoicing_statusCancelled,
      };
}

/// Horizontally scrollable status filter chips (All + the §4.5 stepper subset
/// mapped to real statuses).
class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.selected, required this.onSelect});

  final InvoiceStatus? selected;
  final ValueChanged<InvoiceStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final options = <(InvoiceStatus?, String)>[
      (null, loc.invoicing_statusAll),
      (InvoiceStatus.draft, loc.invoicing_statusDraft),
      (InvoiceStatus.finalized, loc.invoicing_statusFinalized),
      (InvoiceStatus.xmlGenerated, loc.invoicing_statusXml),
      (InvoiceStatus.paid, loc.invoicing_statusPaid),
      (InvoiceStatus.cancelled, loc.invoicing_statusCancelled),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final (status, label) = options[index];
          final active = status == selected;
          return ChoiceChip(
            label: Text(label),
            selected: active,
            onSelected: (_) => onSelect(status),
          );
        },
      ),
    );
  }
}

/// Non-blocking "showing cached data" banner (dual-mode §5).
class _CachedBanner extends StatelessWidget {
  const _CachedBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warningSubtle,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16, color: AppColors.warningText),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.warningText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
