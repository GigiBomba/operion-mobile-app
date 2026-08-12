import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/models/driver.dart';
import '../providers/teams_providers.dart' show DriverDetail;

/// Which compliance field the edit sheet should focus / pre-select.
enum DriverEditField {
  name,
  licenseNumber,
  licenseCategory,
  licenseExpiry,
  medicalExpiry,
  adrCertificateExpiry,
}

/// Shows the driver edit bottom sheet.
///
/// Supports both modes cleanly:
/// - **Edit** — pass [initial] (a [DriverDetail]) to pre-fill every field.
/// - **Create** — omit [initial]; all fields start empty and the returned
///   [DriverDraft] feeds [DriverMutationNotifier.createDriver].
///
/// Returns a [DriverDraft], or `null` when dismissed. When [focusField] is an
/// expiry field, the matching date picker is opened immediately (used by the
/// Renew quick-action in edit mode).
Future<DriverDraft?> showDriverEditSheet(
  BuildContext context, {
  DriverDetail? initial,
  DriverEditField? focusField,
}) {
  return showModalBottomSheet<DriverDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DriverEditSheet(initial: initial, focusField: focusField),
    ),
  );
}

class DriverEditSheet extends StatefulWidget {
  const DriverEditSheet({super.key, this.initial, this.focusField});

  final DriverDetail? initial;
  final DriverEditField? focusField;

  @override
  State<DriverEditSheet> createState() => _DriverEditSheetState();
}

class _DriverEditSheetState extends State<DriverEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _licenseNumber;
  late final TextEditingController _licenseCategory;
  DateTime? _licenseExpiry;
  DateTime? _medicalExpiry;
  DateTime? _adrExpiry;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _name = TextEditingController(text: d?.name ?? '');
    _phone = TextEditingController(text: d?.phone ?? '');
    _email = TextEditingController(text: d?.email ?? '');
    _licenseNumber = TextEditingController(text: d?.licenseNumber ?? '');
    _licenseCategory = TextEditingController(text: d?.licenseCategory ?? '');
    _licenseExpiry = d?.licenseExpiry;
    _medicalExpiry = d?.medicalExpiry;
    _adrExpiry = d?.adrCertificateExpiry;

    // Renew quick-action: open the targeted expiry picker immediately.
    if (widget.focusField == DriverEditField.licenseExpiry) {
      _pickExpiry(DriverEditField.licenseExpiry);
    } else if (widget.focusField == DriverEditField.medicalExpiry) {
      _pickExpiry(DriverEditField.medicalExpiry);
    } else if (widget.focusField == DriverEditField.adrCertificateExpiry) {
      _pickExpiry(DriverEditField.adrCertificateExpiry);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _licenseNumber.dispose();
    _licenseCategory.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry(DriverEditField field) async {
    final current = switch (field) {
      DriverEditField.licenseExpiry => _licenseExpiry,
      DriverEditField.medicalExpiry => _medicalExpiry,
      DriverEditField.adrCertificateExpiry => _adrExpiry,
      _ => null,
    };
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      switch (field) {
        case DriverEditField.licenseExpiry:
          _licenseExpiry = picked;
        case DriverEditField.medicalExpiry:
          _medicalExpiry = picked;
        case DriverEditField.adrCertificateExpiry:
          _adrExpiry = picked;
        default:
          break;
      }
    });
  }

  String _fmt(DateTime? value) =>
      value == null ? '' : value.toIso8601String().substring(0, 10);

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
              Text(loc.teams_editTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _name,
                labelText: loc.clients_name,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? loc.clients_nameRequired : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: _phone, labelText: loc.teams_phone),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: _email, labelText: loc.teams_email),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _licenseNumber,
                labelText: loc.teams_licenseNumber,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _licenseCategory,
                labelText: loc.teams_licenseCategory,
              ),
              const SizedBox(height: AppSpacing.md),
              _ExpiryPicker(
                label: loc.teams_licenseExpiry,
                value: _fmt(_licenseExpiry),
                onTap: () => _pickExpiry(DriverEditField.licenseExpiry),
              ),
              const SizedBox(height: AppSpacing.md),
              _ExpiryPicker(
                label: loc.teams_medicalExpiry,
                value: _fmt(_medicalExpiry),
                onTap: () => _pickExpiry(DriverEditField.medicalExpiry),
              ),
              const SizedBox(height: AppSpacing.md),
              _ExpiryPicker(
                label: loc.teams_adrExpiry,
                value: _fmt(_adrExpiry),
                onTap: () => _pickExpiry(DriverEditField.adrCertificateExpiry),
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

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      DriverDraft(
        name: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        licenseNumber: _licenseNumber.text.trim().isEmpty
            ? null
            : _licenseNumber.text.trim(),
        licenseCategory: _licenseCategory.text.trim().isEmpty
            ? null
            : _licenseCategory.text.trim(),
        licenseExpiry: _licenseExpiry,
        medicalExpiry: _medicalExpiry,
        adrCertificateExpiry: _adrExpiry,
      ),
    );
  }
}

class _ExpiryPicker extends StatelessWidget {
  const _ExpiryPicker({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(value.isEmpty ? '—' : value),
      ),
    );
  }
}
