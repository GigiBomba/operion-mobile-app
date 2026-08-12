import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/invoicing_providers.dart';

/// PDF preview (blueprint §4.5): fetches `GET /mobile/invoices/{id}/pdf` via
/// [invoicePdfProvider] and renders it with pdfx ([PdfView] from bytes via
/// [PdfDocument.openData]).
///
/// pdfx renders through native PDF engines (PDFium / PDFKit), so live
/// rendering is DEVICE-REQUIRED; the widget handles loading and error states
/// in every environment.
class InvoicePdfPreviewScreen extends ConsumerStatefulWidget {
  const InvoicePdfPreviewScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<InvoicePdfPreviewScreen> createState() =>
      _InvoicePdfPreviewScreenState();
}

class _InvoicePdfPreviewScreenState
    extends ConsumerState<InvoicePdfPreviewScreen> {
  PdfController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _createController(Uint8List bytes) {
    if (_controller != null) return;
    // pdfx can open a document straight from memory.
    _controller = PdfController(document: PdfDocument.openData(bytes));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final pdfAsync = ref.watch(invoicePdfProvider(widget.invoiceId));

    return Scaffold(
      appBar: AppBar(title: Text(loc.invoicing_pdfTitle)),
      body: pdfAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.picture_as_pdf,
                    size: 56, color: AppColors.error),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${loc.general_error}: $e',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.invalidate(invoicePdfProvider(widget.invoiceId)),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(loc.general_retry),
                ),
              ],
            ),
          ),
        ),
        data: (bytes) {
          _createController(bytes);
          final controller = _controller;
          if (controller == null) {
            return const Center(child: CircularProgressIndicator());
          }
          // The pdfx native renderer cannot be exercised in the headless test
          // environment; the controller still drives the loading/error states.
          return ValueListenableBuilder<PdfLoadingState>(
            valueListenable: controller.loadingState,
            builder: (context, loading, _) {
              return switch (loading) {
                PdfLoadingState.loading =>
                  const Center(child: CircularProgressIndicator()),
                PdfLoadingState.success => PdfView(
                    controller: controller,
                    key: const ValueKey('invoice_pdf_view'),
                  ),
                PdfLoadingState.error => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf,
                            size: 56, color: AppColors.error),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          loc.invoicing_pdfError,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        OutlinedButton.icon(
                          onPressed: () {
                            controller.loadDocument(
                              PdfDocument.openData(bytes),
                            );
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(loc.general_retry),
                        ),
                      ],
                    ),
                  ),
              };
            },
          );
        },
      ),
    );
  }
}
