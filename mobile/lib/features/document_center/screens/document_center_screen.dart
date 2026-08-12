import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../providers/document_center_providers.dart';

/// Document Center screen — full company document browsing + OCR Automation.
///
/// Two tabs:
/// 1. Documents — browse all company documents (reuses existing document patterns)
/// 2. Automation — camera capture → OCR upload flow (§6.4)
///
/// The Automation flow posts to `POST /api/v1/ocr/process` and stops at
/// "upload confirmed, processing" — no polling loop, no local OCR storage.
class DocumentCenterScreen extends ConsumerStatefulWidget {
  const DocumentCenterScreen({super.key, this.initialTab = 0});

  /// The tab opened when the screen appears. The `scan_document` quick
  /// action deep-links PAST the document list straight into the camera /
  /// OCR automation flow (`initialTab: 1`).
  final int initialTab;

  @override
  ConsumerState<DocumentCenterScreen> createState() => _DocumentCenterScreenState();
}

class _DocumentCenterScreenState extends ConsumerState<DocumentCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Jump to the requested tab on the first frame (before the TabBarView
    // builds) so the deep-linked tab is the initially-visible one.
    if (widget.initialTab > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _tabController.animateTo(widget.initialTab);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.nav_documentCenter),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(LucideIcons.folderOpen), text: loc.documentCenter_documents),
            Tab(icon: const Icon(LucideIcons.camera), text: loc.documentCenter_automation),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DocumentsTab(),
          _AutomationTab(),
        ],
      ),
    );
  }
}

/// Documents list tab — all company documents (dispatcher/manager scope).
///
/// Implements §1.2: shimmer loading, error with retry, empty state, and
/// pull-to-refresh on the document list. §2 parity adds:
/// - a debounced (400ms) full-text search field (`query` param, FTS server-side)
/// - a category chips row (`All` + `GET /documents/categories`)
/// - a version-history detail sheet per document (`GET /documents/{id}/read`)
class _DocumentsTab extends ConsumerStatefulWidget {
  const _DocumentsTab();

  @override
  ConsumerState<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends ConsumerState<_DocumentsTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  /// Selected category ('' = All). Mirrors the server `category` filter.
  String _category = '';

  static const _debounceDuration = Duration(milliseconds: 400);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  DocumentListFilter get _filter =>
      DocumentListFilter(query: _searchController.text.trim(), category: _category);

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _onCategorySelected(String category) {
    setState(() => _category = category);
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(companyDocumentsProvider(_filter));
    await ref.read(companyDocumentsProvider(_filter).future);
  }

  void _openVersionSheet(int docId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _DocumentVersionSheet(docId: docId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final documentsAsync = ref.watch(companyDocumentsProvider(_filter));
    final categoriesAsync = ref.watch(documentCategoriesProvider);

    return Column(
      children: [
        // ── Search + category chips ───────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: AppTextField(
            controller: _searchController,
            hintText: loc.documentCenter_searchHint,
            prefixIcon: const Icon(LucideIcons.search, size: 18),
            onChanged: _onSearchChanged,
          ),
        ),
        categoriesAsync.maybeWhen(
          data: (categories) => _CategoryChips(
            categories: categories,
            selected: _category,
            onSelected: _onCategorySelected,
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        Expanded(
          child: documentsAsync.when(
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: List.generate(
                4,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: ShimmerLoader(child: _ShimmerBlock(height: 72)),
                ),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.alertCircle,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      loc.documentCenter_documentsError,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(companyDocumentsProvider(_filter)),
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      label: Text(loc.general_retry),
                    ),
                  ],
                ),
              ),
            ),
            data: (documents) => RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: documents.isEmpty
                  // Scrollable so pull-to-refresh still works on empty.
                  ? ListView(
                      key: const ValueKey('documents_list_empty'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: AppSpacing.xxl * 3),
                        EmptyState(
                          icon: const Icon(LucideIcons.fileText, size: 56),
                          title: loc.documentCenter_documents,
                          subtitle: loc.documentCenter_documentsEmpty,
                        ),
                      ],
                    )
                  : ListView.separated(
                      key: const ValueKey('documents_list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: documents.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) => _DocumentRow(
                        document: documents[index],
                        onTap: () =>
                            _openVersionSheet(documents[index].id),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal category chips row: "All" + each category from the API.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<DocumentCategory> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final all = DocumentCategory(category: '', count: categories.fold(
      0,
      (sum, c) => sum + c.count,
    ));
    final chips = <DocumentCategory>[all, ...categories];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final isSelected = selected == chip.category;
          final label = chip.category.isEmpty
              ? loc.documentCenter_allCategories
              : chip.category;
          return ChoiceChip(
            label: Text(
              chip.count > 0 ? '$label (${chip.count})' : label,
              style: const TextStyle(fontSize: 12),
            ),
            selected: isSelected,
            onSelected: (_) => onSelected(chip.category),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

/// A single company document row: name + category + upload date.
class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document, this.onTap});

  final CompanyDocument document;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    final title = document.fileName.isNotEmpty
        ? document.fileName
        : document.title;

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(LucideIcons.fileText, size: 18, color: AppColors.accent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(loc),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: AppColors.neutralText,
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(AppLocalizations loc) {
    final parts = <String>[
      if (document.category.isNotEmpty) document.category,
      if (document.uploadedAt != null)
        '${loc.document_uploaded} ${_formatDate(document.uploadedAt!)}',
    ];
    return parts.join(' · ');
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

/// Bottom sheet listing a document's version history (§2 parity).
///
/// Versions come from `GET /documents/{id}/read` → `versions`. There is no
/// read/stream endpoint in the dispatcher contract, so this renders the
/// metadata list only — no preview (documented in the §2 report).
class _DocumentVersionSheet extends ConsumerWidget {
  const _DocumentVersionSheet({required this.docId});

  final int docId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final versionsAsync = ref.watch(documentVersionsProvider(docId));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.documentCenter_versions,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: versionsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    loc.documentCenter_documentsError,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                data: (versions) {
                  if (versions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        loc.documentCenter_noVersions,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: versions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final version = versions[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          LucideIcons.fileClock,
                          size: 20,
                          color: AppColors.accent,
                        ),
                        title: Text(
                          '${loc.documentCenter_versionNumber} ${version.versionNumber}'
                          '${version.fileName.isNotEmpty ? ' — ${version.fileName}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          [
                            if (version.createdAt != null)
                              _formatDateTime(version.createdAt!),
                            if (version.uploadedBy.isNotEmpty)
                              '${loc.documentCenter_uploadedBy}: ${version.uploadedBy}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        trailing: Tooltip(
                          message: loc.documentCenter_previewUnavailable,
                          child: const Icon(
                            LucideIcons.eyeOff,
                            size: 18,
                            color: AppColors.neutralText,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(loc.general_done),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} $h:$m';
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
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

/// Automation tab — camera capture → OCR upload flow.
///
/// Flow (Blueprint §6.4):
/// 1. Open camera → capture photo (`image_picker`)
/// 2. Generate an `Idempotency-Key` (UUID) for this upload action
/// 3. `POST /api/v1/ocr/process` with the image + key → `OcrUploadResponse`
/// 4. Show "upload confirmed, processing" — NO polling loop, NO local storage
class _AutomationTab extends ConsumerWidget {
  const _AutomationTab();

  Future<void> _captureAndUpload(BuildContext context, WidgetRef ref) async {
    final pickPath = ref.read(ocrImagePickProvider);
    final path = await pickPath();
    if (path == null) return; // User cancelled the camera.
    if (!context.mounted) return;
    await ref.read(ocrUploadProvider.notifier).upload(imagePath: path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upload = ref.watch(ocrUploadProvider);

    return switch (upload.phase) {
      OcrUploadPhase.idle => _AutomationIntro(
          onCapture: () => _captureAndUpload(context, ref),
        ),
      OcrUploadPhase.uploading => const _UploadInProgress(),
      OcrUploadPhase.confirmed => _UploadConfirmed(
          onCaptureAnother: () => _captureAndUpload(context, ref),
        ),
      OcrUploadPhase.error => _UploadFailed(
          onRetry: () => _captureAndUpload(context, ref),
        ),
    };
  }
}

class _AutomationIntro extends StatelessWidget {
  const _AutomationIntro({required this.onCapture});

  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.camera,
              size: 64,
              color: AppColors.accent.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              loc.documentCenter_ocrTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              loc.documentCenter_ocrDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton.primary(
              label: loc.documentCenter_capturePhoto,
              onPressed: onCapture,
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadInProgress extends StatelessWidget {
  const _UploadInProgress();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  loc.documentCenter_uploadInProgress,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadConfirmed extends StatelessWidget {
  const _UploadConfirmed({required this.onCaptureAnother});

  final VoidCallback onCaptureAnother;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.checkCircle2,
                    size: 48, color: AppColors.success),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  loc.documentCenter_uploadConfirmed,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  loc.documentCenter_processingHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton.secondary(
                  label: loc.documentCenter_captureAnother,
                  onPressed: onCaptureAnother,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadFailed extends StatelessWidget {
  const _UploadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle,
                size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              loc.documentCenter_uploadError,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.secondary(
              label: loc.general_retry,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
