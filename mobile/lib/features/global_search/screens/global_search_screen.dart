import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../clients/screens/client_detail_screen.dart';
import '../../fleet/screens/truck_detail_screen.dart';
import '../../teams/screens/driver_detail_screen.dart';
import '../providers/global_search_providers.dart';

/// Global Search screen (blueprint §6.11).
///
/// Debounced cross-entity search over trips/clients/drivers/trucks/documents.
/// Each section is capped at 5 items with an "N more" line when `total_count`
/// exceeds it. Clients/drivers/trucks navigate to the existing detail
/// screens; trips/documents render informational tiles (no detail route —
/// honest, the backend exposes none).
class GlobalSearchScreen extends ConsumerWidget {
  const GlobalSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final query = ref.watch(globalSearchQueryProvider);
    final results = ref.watch(globalSearchResultsProvider(query));

    return Scaffold(
      appBar: AppBar(title: Text(loc.globalSearch_title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: loc.globalSearch_hint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            ref.read(globalSearchQueryProvider.notifier).state = '',
                      )
                    : null,
              ),
              onChanged: (v) =>
                  ref.read(globalSearchQueryProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: _buildBody(context, ref, loc, query, results),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations loc,
    String query,
    AsyncValue<GlobalSearchResults> results,
  ) {
    if (query.trim().length < 2) {
      return Center(
        child: EmptyState(
          icon: const Icon(Icons.search),
          title: loc.globalSearch_minChars,
        ),
      );
    }
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text('$err', textAlign: TextAlign.center),
        ),
      ),
      data: (data) {
        if (data.isEmpty) {
          return EmptyState(
            icon: const Icon(Icons.search_off),
            title: loc.globalSearch_empty,
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            _SearchSection(
              title: loc.globalSearch_trips,
              section: data.trips,
              onTap: null, // informational — no trip detail route yet.
            ),
            _SearchSection(
              title: loc.globalSearch_clients,
              section: data.clients,
              onTap: (item) => _openClient(context, item),
            ),
            _SearchSection(
              title: loc.globalSearch_drivers,
              section: data.drivers,
              onTap: (item) => _openDriver(context, item),
            ),
            _SearchSection(
              title: loc.globalSearch_trucks,
              section: data.trucks,
              onTap: (item) => _openTruck(context, item),
            ),
            _SearchSection(
              title: loc.globalSearch_documents,
              section: data.documents,
              onTap: null, // informational — no document detail route yet.
            ),
          ],
        );
      },
    );
  }

  void _openClient(BuildContext context, Map<String, dynamic> item) {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClientDetailScreen(clientId: id),
      ),
    );
  }

  void _openDriver(BuildContext context, Map<String, dynamic> item) {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DriverDetailScreen(driver: item),
      ),
    );
  }

  void _openTruck(BuildContext context, Map<String, dynamic> item) {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TruckDetailScreen(truckId: id),
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({
    required this.title,
    required this.section,
    required this.onTap,
  });

  final String title;
  final SearchSection section;
  final void Function(Map<String, dynamic> item)? onTap;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    if (section.items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final item in section.items)
            AppCard(
              onTap: onTap == null ? null : () => onTap!(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chevron_right, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _display(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onTap == null)
                      const Icon(Icons.info_outline,
                          size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          if (section.remaining > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                loc.globalSearch_more.replaceAll('{count}', '${section.remaining}'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  String _display(Map<String, dynamic> item) {
    return item['name']?.toString() ??
        item['client_name']?.toString() ??
        item['plate']?.toString() ??
        item['title']?.toString() ??
        item['id']?.toString() ??
        '';
  }
}
