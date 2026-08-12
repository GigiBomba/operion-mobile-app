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
import '../models/client.dart';
import '../providers/client_providers.dart';
import '../widgets/client_edit_sheet.dart';
import '../widgets/rating_stars.dart';
import 'client_detail_screen.dart';

/// Client list (blueprint §4.3): searchable, pull-to-refresh, dual-mode.
/// Create FAB is gated by `can_create_client` (§8.2).
///
/// On tablet widths (≥600dp) the list becomes the list pane of a
/// master-detail layout with the client detail as the detail pane (§9 item 5).
class ClientListScreen extends ConsumerStatefulWidget {
  const ClientListScreen({super.key, this.enableTabletLayout = true});

  final bool enableTabletLayout;

  @override
  ConsumerState<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends ConsumerState<ClientListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _localFilter = '';
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
        ref.read(clientSearchProvider.notifier).state = value.trim();
      }
    });
  }

  Future<void> _openCreate() async {
    final data = await showClientEditSheet(context);
    if (data == null || !mounted) return;
    await ref.read(clientMutationProvider.notifier).createClient(ClientDraft(
          name: data.name,
          vatNumber: data.vatNumber,
          address: data.address,
          paymentTermsDays: data.paymentTermsDays,
          isActive: data.isActive,
        ));
  }

  List<Client> _filter(ClientListData data) {
    return data.clients
        .where((c) =>
            _localFilter.isEmpty ||
            c.name.toLowerCase().contains(_localFilter))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final showCachedBanner = ref.watch(clientCachedBannerProvider);
    final listAsync = ref.watch(clientListProvider);
    final visibleClients = listAsync.valueOrNull == null
        ? const <Client>[]
        : _filter(listAsync.valueOrNull!);
    final tablet = widget.enableTabletLayout &&
        isTabletWidth(context) &&
        visibleClients.isNotEmpty;

    final listPane = Column(
      children: [
        if (showCachedBanner)
          Container(
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
                  loc.clients_cached,
                  style: const TextStyle(
                    color: AppColors.warningText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppTextField(
            controller: _searchController,
            hintText: loc.clients_searchHint,
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
                      onPressed: () => ref.invalidate(clientListProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(loc.general_retry),
                    ),
                  ],
                ),
              ),
            ),
            data: (_) {
              final clients = visibleClients;
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(clientListProvider);
                  await ref.read(clientListProvider.future);
                },
                child: clients.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: AppSpacing.xxl * 3),
                          EmptyState(
                            icon: const Icon(Icons.business, size: 56),
                            title: loc.clients_emptyTitle,
                            subtitle: loc.clients_emptyHint,
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        itemCount: clients.length,
                        itemBuilder: (context, index) {
                          final c = clients[index];
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              onTap: tablet
                                  ? () => setState(() => _selectedIndex = index)
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              ClientDetailScreen(clientId: c.id),
                                        ),
                                      ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          RatingStars(rating: c.rating),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${loc.clients_paymentTerms} · '
                                            '${c.paymentTermsDays} ${loc.clients_daysShort}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color:
                                                  AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      c.isActive
                                          ? loc.clients_active
                                          : loc.clients_inactive,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: c.isActive
                                            ? AppColors.successText
                                            : AppColors.neutralText,
                                      ),
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
      appBar: AppBar(title: Text(loc.nav_clients)),
      body: tablet
          ? MasterDetailLayout(
              selectedIndex: _selectedIndex ?? 0,
              listPane: listPane,
              detailBuilder: (context, index) {
                final sel = index.clamp(0, visibleClients.length - 1);
                return ClientDetailScreen(clientId: visibleClients[sel].id);
              },
            )
          : listPane,
      floatingActionButton: buildIfPermitted(
        ref,
        Permissions.createClient,
        () => FloatingActionButton(
          onPressed: _openCreate,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
