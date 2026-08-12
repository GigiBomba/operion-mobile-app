import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../models/download_manifest.dart';
import '../providers/local_download_providers.dart';

/// Local Download screen — pull-on-demand document downloads.
///
/// Select a category + optional date range → request the manifest →
/// download each file with per-file progress bars.
///
/// Implements §1.2 loading (shimmer) / error (retry) / empty states plus
/// pull-to-refresh on the file list. Pull-on-demand only: no background
/// scheduling exists anywhere in this feature.
class LocalDownloadScreen extends ConsumerStatefulWidget {
  const LocalDownloadScreen({super.key});

  @override
  ConsumerState<LocalDownloadScreen> createState() =>
      _LocalDownloadScreenState();
}

class _LocalDownloadScreenState extends ConsumerState<LocalDownloadScreen> {
  DownloadCategory? _selectedCategory;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? now.subtract(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now,
      helpText: context.loc.localDownload_dateFrom,
    );
    if (picked != null) setState(() => _dateFrom = picked);
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? now,
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now,
      helpText: context.loc.localDownload_dateTo,
    );
    if (picked != null) setState(() => _dateTo = picked);
  }

  /// Kicks off the manifest request and, once the manifest is available,
  /// starts the per-file downloads.
  Future<void> _startDownload() async {
    final category = _selectedCategory;
    if (category == null) return;

    final filter = DownloadRequestFilter(
      category: category,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    ref.read(localDownloadFilterProvider.notifier).state = filter;
    ref.read(localDownloadProvider.notifier).reset();

    try {
      final entries =
          await ref.read(downloadManifestProvider(filter).future);
      if (!mounted || entries.isEmpty) return;
      await ref.read(localDownloadProvider.notifier).startDownloads(entries);
    } catch (_) {
      // The manifest provider surfaces the error state below with a retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final filter = ref.watch(localDownloadFilterProvider);

    return Scaffold(
      appBar: AppBar(title: Text(loc.nav_localDownload)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            loc.localDownload_selectCategory,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          ...DownloadCategory.values.map((category) {
            final selected = _selectedCategory == category;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                onTap: () => setState(() => _selectedCategory = category),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        _iconForCategory(category),
                        color: selected ? AppColors.accent : null,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _categoryLabel(loc, category),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: selected ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(LucideIcons.check,
                            color: AppColors.accent, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),

          // ── Date-range filter ──────────────────────────────────
          if (_selectedCategory != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: loc.localDownload_dateFrom,
                    value: _dateFrom,
                    onTap: _pickFrom,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _DateField(
                    label: loc.localDownload_dateTo,
                    value: _dateTo,
                    onTap: _pickTo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: loc.localDownload_download,
              onPressed: _startDownload,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          // ── Manifest / download area ──────────────────────────
          if (filter != null) _ManifestSection(filter: filter),
        ],
      ),
    );
  }

  String _categoryLabel(AppLocalizations loc, DownloadCategory category) {
    switch (category) {
      case DownloadCategory.documents: return loc.localDownload_categoryDocuments;
      case DownloadCategory.invoices: return loc.localDownload_categoryInvoices;
      case DownloadCategory.receipts: return loc.localDownload_categoryReceipts;
      case DownloadCategory.ocrResults: return loc.localDownload_categoryOcrResults;
      case DownloadCategory.tripHistory: return loc.localDownload_categoryTripHistory;
    }
  }

  IconData _iconForCategory(DownloadCategory category) {
    switch (category) {
      case DownloadCategory.documents: return LucideIcons.fileText;
      case DownloadCategory.invoices: return LucideIcons.fileText;
      case DownloadCategory.receipts: return LucideIcons.receipt;
      case DownloadCategory.ocrResults: return LucideIcons.scanText;
      case DownloadCategory.tripHistory: return LucideIcons.history;
    }
  }
}

/// Tappable date field (NewExpenseScreen date-picker pattern).
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: AppRadius.lgAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  LucideIcons.calendar,
                  size: 16,
                  color: value == null
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                      : AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  value == null ? '—' : DateFormat.yMMMd().format(value!),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Manifest states: loading shimmer / error retry / empty / file list.
class _ManifestSection extends ConsumerWidget {
  const _ManifestSection({required this.filter});

  final DownloadRequestFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final manifestAsync = ref.watch(downloadManifestProvider(filter));

    return manifestAsync.when(
      loading: () => const _ManifestShimmer(),
      error: (err, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle,
                size: 40, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(loc.localDownload_manifestError,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.invalidate(downloadManifestProvider(filter)),
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: Text(loc.general_retry),
            ),
          ],
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: EmptyState(
              icon: const Icon(LucideIcons.folderOpen, size: 56),
              title: loc.localDownload_manifestEmpty,
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(downloadManifestProvider(filter));
            await ref.read(downloadManifestProvider(filter).future);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in entries) _FileRow(entry: entry),
              const SizedBox(height: AppSpacing.xhuge),
            ],
          ),
        );
      },
    );
  }
}

class _ManifestShimmer extends StatelessWidget {
  const _ManifestShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: ShimmerLoader(child: _ShimmerBlock(height: 72)),
        ),
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  final double height;
  const _ShimmerBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    );
  }
}

/// A single manifest entry with per-file download progress.
class _FileRow extends ConsumerWidget {
  const _FileRow({required this.entry});

  final DownloadManifestEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final status = ref.watch(
      localDownloadProvider.select(
        (state) => state.files[entry.recordId],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.fileText,
                      size: 18, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    _formatSize(entry.sizeBytes),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildStatus(context, loc, status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(
    BuildContext context,
    AppLocalizations loc,
    DownloadFileStatus? status,
  ) {
    final theme = Theme.of(context);
    if (status == null) {
      return Text(
        loc.localDownload_downloadAll,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }
    if (status.completed) {
      return Row(
        children: [
          const Icon(LucideIcons.checkCircle2,
              size: 16, color: AppColors.success),
          const SizedBox(width: AppSpacing.xs),
          Text(loc.localDownload_saved, style: theme.textTheme.bodySmall),
        ],
      );
    }
    if (status.error != null) {
      return Row(
        children: [
          const Icon(LucideIcons.alertCircle, size: 16, color: AppColors.error),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              status.error!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: status.progress),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${(status.progress * 100).toStringAsFixed(0)}%',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  static String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}
