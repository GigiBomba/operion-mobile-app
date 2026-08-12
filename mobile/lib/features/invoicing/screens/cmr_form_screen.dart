import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:signature/signature.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/security/capture_blur_overlay.dart';
import '../../../core/security/screen_capture.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/invoice.dart';
import '../providers/invoicing_providers.dart';

/// CMR form (blueprint §4.5/§6.6): grouped UN/CEFACT sections adapted from the
/// desktop `CmrGenerateRequest` field set.
///
/// Sections: Sender / Consignee (server-filled from trip data — honest
/// placeholder) / Carrier / Goods (server-filled — honest placeholder) /
/// Instructions / Signatures (signature pad → PNG bytes → base64).
///
/// Save runs the §12 biometric gate BEFORE the CMR call and is NEVER queued
/// offline (§7). FLAG_SECURE is applied on init and cleared on dispose.
class CmrFormScreen extends ConsumerStatefulWidget {
  const CmrFormScreen({
    super.key,
    required this.invoiceId,
    this.tripId,
  });

  final String invoiceId;
  final int? tripId;

  @override
  ConsumerState<CmrFormScreen> createState() => _CmrFormScreenState();
}

class _CmrFormScreenState extends ConsumerState<CmrFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _senderName = TextEditingController();
  final _senderAddress = TextEditingController();
  final _carrierName = TextEditingController();
  final _carrierLicense = TextEditingController();
  final _remarks = TextEditingController();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  String _language = 'ro';
  int _copies = 1;
  bool _includeStamps = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Sensitive screen: block screenshots while visible (§12).
    enableSecureScreen();
  }

  @override
  void dispose() {
    disableSecureScreen();
    _senderName.dispose();
    _senderAddress.dispose();
    _carrierName.dispose();
    _carrierLicense.dispose();
    _remarks.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final loc = context.loc;

    // Signature → PNG bytes → base64 (contract: signature_png_base64).
    String? signatureBase64;
    final png = await _signatureController.toPngBytes();
    if (png != null && png.isNotEmpty) {
      signatureBase64 = base64Encode(png);
    }

    final draft = CmrFormDraft(
      tripId: widget.tripId,
      language: _language,
      copies: _copies,
      includeStamps: _includeStamps,
      senderName: _senderName.text.trim(),
      senderAddress: _senderAddress.text.trim(),
      carrierName: _carrierName.text.trim(),
      carrierLicense: _carrierLicense.text.trim(),
      remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
      signaturePngBase64: signatureBase64,
    );

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(cmrMutationProvider.notifier)
          .saveCmr(
            widget.invoiceId,
            draft,
            biometricReason: loc.invoicing_biometricReason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result != null && result.cmrNumber.isNotEmpty
                ? '${loc.invoicing_cmrSaved} ${result.cmrNumber}'
                : loc.invoicing_cmrSaved,
          ),
        ),
      );
      Navigator.of(context).pop();
    } on BiometricRequired {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.invoicing_biometricDenied)),
      );
    } on FinanceRequiresConnection {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.invoicing_requiresConnection)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.general_error)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return CaptureBlurOverlay(
      child: Scaffold(
        appBar: AppBar(title: Text(loc.invoicing_cmrTitle)),
        body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            // ── Sender ──
            _SectionHeader(icon: LucideIcons.user, label: loc.invoicing_cmrSender),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _senderName,
              labelText: loc.invoicing_cmrSenderName,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? loc.invoicing_cmrSenderNameRequired
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _senderAddress,
              labelText: loc.invoicing_cmrSenderAddress,
              maxLines: 2,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? loc.invoicing_cmrSenderAddressRequired
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Consignee (server-filled) ──
            _SectionHeader(icon: LucideIcons.package, label: loc.invoicing_cmrConsignee),
            const SizedBox(height: AppSpacing.xs),
            _ServerFilledNote(text: loc.invoicing_cmrFromTrip),
            const SizedBox(height: AppSpacing.lg),

            // ── Carrier ──
            _SectionHeader(icon: LucideIcons.truck, label: loc.invoicing_cmrCarrier),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _carrierName,
              labelText: loc.invoicing_cmrCarrierName,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _carrierLicense,
              labelText: loc.invoicing_cmrCarrierLicense,
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Goods (server-filled) ──
            _SectionHeader(icon: LucideIcons.box, label: loc.invoicing_cmrGoods),
            const SizedBox(height: AppSpacing.xs),
            _ServerFilledNote(text: loc.invoicing_cmrFromTrip),
            const SizedBox(height: AppSpacing.lg),

            // ── Instructions ──
            _SectionHeader(icon: LucideIcons.clipboardList, label: loc.invoicing_cmrInstructions),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _language,
                    decoration: InputDecoration(labelText: loc.invoicing_cmrLanguage),
                    items: const [
                      DropdownMenuItem(value: 'ro', child: Text('Română')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                      DropdownMenuItem(value: 'fr', child: Text('Français')),
                    ],
                    onChanged: (v) =>
                        setState(() => _language = v ?? 'ro'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _copies,
                    decoration: InputDecoration(labelText: loc.invoicing_cmrCopies),
                    items: [for (var i = 1; i <= 5; i++) DropdownMenuItem(value: i, child: Text('$i'))],
                    onChanged: (v) => setState(() => _copies = v ?? 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(loc.invoicing_cmrIncludeStamps),
              value: _includeStamps,
              onChanged: (v) => setState(() => _includeStamps = v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _remarks,
              labelText: loc.invoicing_cmrRemarks,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Signatures ──
            _SectionHeader(icon: LucideIcons.penLine, label: loc.invoicing_cmrSignatures),
            const SizedBox(height: AppSpacing.sm),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.md),
                border: Border.all(color: AppColors.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: Signature(
                controller: _signatureController,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _signatureController.clear(),
                  icon: const Icon(LucideIcons.rotateCcw, size: 16),
                  label: Text(loc.invoicing_cmrClearSignature),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            AppButton.primary(
              label: loc.invoicing_cmrSave,
              isLoading: _busy,
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton.secondary(
              label: loc.general_cancel,
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ServerFilledNote extends StatelessWidget {
  const _ServerFilledNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.infoSubtle,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.infoText),
      ),
    );
  }
}
