import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/truck.dart';

/// Shows the "record work" bottom sheet for a truck's maintenance history.
///
/// Collects date / category / cost / vendor / notes and returns a validated
/// [MaintenanceRecordDraft], or `null` when dismissed. When [prefill] is
/// provided the fields start pre-filled (voice quick-capture, blueprint §9
/// item 4) so the user can one-tap confirm.
Future<MaintenanceRecordDraft?> showRecordWorkSheet(
  BuildContext context, {
  MaintenancePrefill? prefill,
}) {
  return showModalBottomSheet<MaintenanceRecordDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _RecordWorkSheet(prefill: prefill),
    ),
  );
}

class _RecordWorkSheet extends StatefulWidget {
  const _RecordWorkSheet({this.prefill});

  final MaintenancePrefill? prefill;

  @override
  State<_RecordWorkSheet> createState() => _RecordWorkSheetState();
}

class _RecordWorkSheetState extends State<_RecordWorkSheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late MaintenanceCategory _category;
  final _cost = TextEditingController();
  final _vendor = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final prefill = widget.prefill;
    _date = prefill?.date ?? DateTime.now();
    _category = prefill?.category ?? MaintenanceCategory.other;
    final cost = prefill?.cost;
    if (cost != null) {
      _cost.text = _formatCost(cost);
    }
    final notes = prefill?.notes;
    if (notes != null && notes.isNotEmpty) {
      _notes.text = notes;
    }
  }

  static String _formatCost(double value) {
    // Locale-agnostic decimal format the sheet validator accepts.
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  @override
  void dispose() {
    _cost.dispose();
    _vendor.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
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
              Text(loc.fleet_recordWork, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: loc.fleet_date,
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(_date.toIso8601String().substring(0, 10)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<MaintenanceCategory>(
                initialValue: _category,
                decoration: InputDecoration(labelText: loc.fleet_category),
                items: [
                  for (final c in MaintenanceCategory.values)
                    DropdownMenuItem(
                      value: c,
                      child: Text(_categoryLabel(c, loc)),
                    ),
                ],
                onChanged: (v) => setState(() => _category = v ?? MaintenanceCategory.other),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _cost,
                labelText: loc.fleet_cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final parsed = double.tryParse(v ?? '');
                  if (parsed == null || parsed <= 0) return loc.fleet_costRequired;
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _vendor,
                labelText: loc.fleet_vendor,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _notes,
                labelText: loc.fleet_notes,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton.primary(
                label: loc.general_save,
                onPressed: _submit,
              ),
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
      MaintenanceRecordDraft(
        date: _date,
        category: _category,
        cost: double.parse(_cost.text.trim()),
        vendor: _vendor.text.trim().isEmpty ? null : _vendor.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }

  static String _categoryLabel(MaintenanceCategory category, AppLocalizations loc) {
    switch (category) {
      case MaintenanceCategory.oilChange:
        return loc.fleet_categoryOil;
      case MaintenanceCategory.tires:
        return loc.fleet_categoryTires;
      case MaintenanceCategory.brakes:
        return loc.fleet_categoryBrakes;
      case MaintenanceCategory.engine:
        return loc.fleet_categoryEngine;
      case MaintenanceCategory.bodywork:
        return loc.fleet_categoryBodywork;
      case MaintenanceCategory.inspection:
        return loc.fleet_categoryInspection;
      case MaintenanceCategory.other:
        return loc.fleet_categoryOther;
    }
  }
}
