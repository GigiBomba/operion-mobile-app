import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_guard.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../history/providers/history_providers.dart';
import '../../invoicing/providers/invoicing_providers.dart';
import '../models/client.dart';
import '../providers/client_providers.dart';
import '../widgets/client_edit_sheet.dart';
import '../widgets/client_merge_sheet.dart';
import '../widgets/contact_edit_sheet.dart';
import '../widgets/rating_stars.dart';

/// Client detail (blueprint §4.3) — 4 tabs: Details (editable, gated
/// `can_update_client`; merge entry gated `can_merge_clients` — admin-only in
/// the REAL matrix), Contacts (add/edit), Invoices (list filtered by client,
/// `GET /mobile/invoices?client_id=`), Trips (list filtered by client,
/// `GET /mobile/history/trips?client_id=`).
class ClientDetailScreen extends ConsumerStatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final detailAsync = ref.watch(clientDetailProvider(widget.clientId));
    final canUpdate = ref.watch(permissionProvider).can(Permissions.updateClient);
    final canMerge = ref.watch(permissionProvider).can(Permissions.mergeClients);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.nav_clients),
          actions: [
            if (canMerge)
              IconButton(
                icon: const Icon(Icons.call_merge_outlined),
                tooltip: loc.clients_merge,
                onPressed: () => _openMerge(context),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              _ClientTab(label: 'details'),
              _ClientTab(label: 'contacts'),
              _ClientTab(label: 'invoices'),
              _ClientTab(label: 'trips'),
            ],
          ),
        ),
        body: detailAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: List.generate(
              3,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: ShimmerCard(),
              ),
            ),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: AppSpacing.lg),
                  Text('${loc.general_error}: $e', textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.invalidate(clientDetailProvider(widget.clientId)),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(loc.general_retry),
                  ),
                ],
              ),
            ),
          ),
          data: (data) => TabBarView(
            children: [
              _DetailsTab(
                client: data.client,
                onEdit: canUpdate ? () => _editClient(context) : null,
              ),
              _ContactsTab(
                client: data.client,
                canEdit: canUpdate,
              ),
              _InvoicesTab(client: data.client, loc: loc),
              _TripsTab(client: data.client, loc: loc),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editClient(BuildContext context) async {
    final client = ref.read(clientDetailProvider(widget.clientId)).value?.client;
    if (client == null || !mounted) return;
    final data = await showClientEditSheet(context, initial: client);
    if (data == null || !mounted) return;
    await ref.read(clientMutationProvider.notifier).updateClient(
          widget.clientId,
          ClientDraft(
            name: data.name,
            vatNumber: data.vatNumber,
            address: data.address,
            paymentTermsDays: data.paymentTermsDays,
            isActive: data.isActive,
          ),
        );
  }

  Future<void> _openMerge(BuildContext context) async {
    final clients = ref.read(clientListProvider).value?.clients ?? [];
    final target = ref.read(clientDetailProvider(widget.clientId)).value?.client;
    await ClientMergeSheet.show(
      context,
      clients: clients.isEmpty ? [?target] : clients,
      initialTargetId: target?.id,
    );
  }
}

/// Tab labels resolved lazily via [AppLocalizations] in the build phase.
class _ClientTab extends StatelessWidget {
  const _ClientTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final text = switch (label) {
      'details' => loc.clients_details,
      'contacts' => loc.clients_contacts,
      'invoices' => loc.clients_invoices,
      'trips' => loc.clients_trips,
      _ => label,
    };
    return Tab(text: text);
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.client, this.onEdit});

  final Client client;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        client.name,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (onEdit != null)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: loc.general_edit,
                        onPressed: onEdit,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(label: loc.clients_vatNumber, value: client.vatNumber ?? loc.teams_notAssigned),
                _DetailRow(label: loc.clients_address, value: client.address ?? loc.teams_notAssigned),
                _DetailRow(
                  label: loc.clients_paymentTerms,
                  value: '${client.paymentTermsDays} ${loc.clients_daysShort}',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      loc.clients_rating,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    RatingStars(rating: client.rating),
                    const SizedBox(width: AppSpacing.sm),
                    Text(client.rating.toStringAsFixed(1)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  client.isActive ? loc.clients_active : loc.clients_inactive,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: client.isActive
                        ? AppColors.successText
                        : AppColors.neutralText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactsTab extends ConsumerWidget {
  const _ContactsTab({required this.client, required this.canEdit});

  final Client client;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    if (!canEdit) {
      return EmptyState(
        icon: const Icon(Icons.contacts_outlined, size: 56),
        title: loc.clients_contacts,
        subtitle: loc.clients_noPermission,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => _addContact(context, ref),
            icon: const Icon(Icons.person_add_alt, size: 18),
            label: Text(loc.clients_addContact),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (client.contacts.isEmpty)
          EmptyState(
            icon: const Icon(Icons.contacts_outlined, size: 56),
            title: loc.clients_noContacts,
            subtitle: loc.clients_addContactHint,
          )
        else
          for (final contact in client.contacts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(contact.name),
                  subtitle: Text(
                    [contact.role, contact.phone, contact.email]
                        .where((s) => s != null && s.isNotEmpty)
                        .join(' · '),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: loc.general_edit,
                    onPressed: () => _editContact(context, ref, contact),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _addContact(BuildContext context, WidgetRef ref) async {
    final data = await showContactEditSheet(context);
    if (data == null || !context.mounted) return;
    await ref.read(clientMutationProvider.notifier).addContact(
          client.id,
          ClientContactDraft(
            name: data.name,
            role: data.role,
            phone: data.phone,
            email: data.email,
          ),
        );
  }

  Future<void> _editContact(
    BuildContext context,
    WidgetRef ref,
    ClientContact contact,
  ) async {
    final data = await showContactEditSheet(context, initial: contact);
    if (data == null || !context.mounted) return;
    // The locked Phase-1B contract exposes only POST /clients/{id}/contacts,
    // so an edit is modelled as a re-POST of the updated contact.
    await ref.read(clientMutationProvider.notifier).addContact(
          client.id,
          ClientContactDraft(
            name: data.name,
            role: data.role,
            phone: data.phone,
            email: data.email,
          ),
        );
  }
}

class _InvoicesTab extends ConsumerWidget {
  const _InvoicesTab({required this.client, required this.loc});

  final Client client;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(
      invoiceListProvider(InvoiceListFilter(clientId: client.id)),
    );
    return invoicesAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: ShimmerCard(),
          ),
        ),
      ),
      error: (e, _) => _TabError(
        message: '${loc.general_error}: $e',
        onRetry: () => ref.invalidate(
          invoiceListProvider(InvoiceListFilter(clientId: client.id)),
        ),
      ),
      data: (data) => data.invoices.isEmpty
          ? EmptyState(
              icon: const Icon(Icons.receipt_long_outlined, size: 56),
              title: loc.clients_noInvoices,
              subtitle: loc.clients_noInvoicesHint,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: data.invoices.length,
              itemBuilder: (context, index) {
                final invoice = data.invoices[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: ListTile(
                      leading: const Icon(
                        Icons.receipt_long_outlined,
                        color: AppColors.accent,
                      ),
                      title: Text(invoice.invoiceNumber),
                      subtitle: Text(invoice.totalAmount.toStringAsFixed(2)),
                      trailing: StatusBadge(statusKey: invoice.status.apiValue),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _TripsTab extends ConsumerWidget {
  const _TripsTab({required this.client, required this.loc});

  final Client client;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(
      tripHistoryProvider(TripHistoryFilter(clientId: client.id)),
    );
    return tripsAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: ShimmerCard(),
          ),
        ),
      ),
      error: (e, _) => _TabError(
        message: '${loc.general_error}: $e',
        onRetry: () => ref.invalidate(
          tripHistoryProvider(TripHistoryFilter(clientId: client.id)),
        ),
      ),
      data: (data) => data.items.isEmpty
          ? EmptyState(
              icon: const Icon(Icons.route_outlined, size: 56),
              title: loc.clients_noTrips,
              subtitle: loc.clients_noTripsHint,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: data.items.length,
              itemBuilder: (context, index) {
                final trip = data.items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: ListTile(
                      leading: const Icon(Icons.route_outlined, color: AppColors.accent),
                      title: Text(
                        '${trip.origin} → ${trip.destination}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(trip.truckNumber),
                      trailing: StatusBadge(statusKey: trip.status),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Error state with retry for a tab body.
class _TabError extends StatelessWidget {
  const _TabError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                AppLocalizations.of(context).general_retry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
