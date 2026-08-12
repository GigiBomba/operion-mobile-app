import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../document_center/providers/document_center_providers.dart';
import 'document_upload_screen.dart';

/// Displays the documents uploaded for the current transport.
///
/// Fetches `GET /api/v1/documents/?entity_type=transport&entity_id=` via
/// [entityDocumentsProvider] (shimmer → list / empty / error + retry). The
/// FAB navigates to [DocumentUploadScreen].
class DocumentListScreen extends ConsumerWidget {
  const DocumentListScreen({super.key, this.transportId});

  /// Optional transport ID to filter documents by. When null the list shows
  /// all transport-scoped documents.
  final String? transportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final docsAsync = ref.watch(
      entityDocumentsProvider(
        EntityDocumentsRequest(
          entityType: 'transport',
          entityId: transportId ?? '',
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(loc.driver_documents)),
      body: docsAsync.when(
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
                Text(
                  '${loc.general_error}: $e',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(
                    entityDocumentsProvider(
                      EntityDocumentsRequest(
                        entityType: 'transport',
                        entityId: transportId ?? '',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(loc.general_retry),
                ),
              ],
            ),
          ),
        ),
        data: (docs) => docs.isEmpty
            ? _buildEmptyState(context, loc, theme)
            : _buildDocumentList(loc, theme, docs),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToUpload(context),
        icon: const Icon(LucideIcons.upload),
        label: Text(loc.document_upload),
      ),
    );
  }

  /// Navigates to the [DocumentUploadScreen].
  void _navigateToUpload(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentUploadScreen(
          transportId: transportId ?? 'default',
        ),
      ),
    );
  }

  /// Empty state shown when no documents exist.
  Widget _buildEmptyState(BuildContext context, AppLocalizations loc, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyState(
            icon: const Icon(LucideIcons.fileText),
            title: loc.document_noDocuments,
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: AppButton.primary(
              label: loc.document_upload,
              icon: const Icon(LucideIcons.upload),
              onPressed: () => _navigateToUpload(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the list of document items.
  Widget _buildDocumentList(
    AppLocalizations loc,
    ThemeData theme,
    List<CompanyDocument> docs,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final doc = docs[index];
        return _DocumentListItem(doc: doc);
      },
    );
  }
}

/// A single document row in the list.
class _DocumentListItem extends StatelessWidget {
  const _DocumentListItem({required this.doc});

  final CompanyDocument doc;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);

    final category = doc.category.isEmpty ? loc.document_other : doc.category;

    return AppCard(
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: AppRadius.lgAll,
            ),
            child: const Icon(
              LucideIcons.file,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.fileName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        category,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (doc.uploadedAt != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '•',
                        style: TextStyle(color: AppColors.textSecondaryLight),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _formatDate(doc.uploadedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}
