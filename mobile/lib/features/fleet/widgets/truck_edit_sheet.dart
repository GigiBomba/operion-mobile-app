import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/truck.dart';

/// The editable truck form fields returned by [showTruckEditSheet].
class TruckEditData {
  final String plate;
  final String brand;
  final String model;
  final String? vin;
  final int? year;

  const TruckEditData({
    required this.plate,
    required this.brand,
    required this.model,
    this.vin,
    this.year,
  });
}

/// Shows the truck create/edit bottom sheet.
///
/// Pass [initial] (an existing [Truck]) to pre-fill the fields for editing.
/// Returns the validated [TruckEditData] or `null` when dismissed.
Future<TruckEditData?> showTruckEditSheet(
  BuildContext context, {
  Truck? initial,
}) {
  return showModalBottomSheet<TruckEditData>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _TruckEditSheet(initial: initial),
    ),
  );
}

class _TruckEditSheet extends StatefulWidget {
  const _TruckEditSheet({this.initial});

  final Truck? initial;

  @override
  State<_TruckEditSheet> createState() => _TruckEditSheetState();
}

class _TruckEditSheetState extends State<_TruckEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plate;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _vin;
  late final TextEditingController _year;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _plate = TextEditingController(text: t?.plate ?? '');
    _brand = TextEditingController(text: t?.brand ?? '');
    _model = TextEditingController(text: t?.model ?? '');
    _vin = TextEditingController(text: t?.vin ?? '');
    _year = TextEditingController(text: t?.year?.toString() ?? '');
  }

  @override
  void dispose() {
    _plate.dispose();
    _brand.dispose();
    _model.dispose();
    _vin.dispose();
    _year.dispose();
    super.dispose();
  }

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
              Text(loc.fleet_editTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _plate,
                labelText: loc.fleet_plate,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? loc.fleet_plateRequired : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _brand,
                labelText: loc.fleet_brand,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? loc.fleet_brandRequired : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _model,
                labelText: loc.fleet_model,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? loc.fleet_modelRequired : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _vin,
                labelText: loc.fleet_vin,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _year,
                labelText: loc.fleet_year,
                keyboardType: TextInputType.number,
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
      TruckEditData(
        plate: _plate.text.trim(),
        brand: _brand.text.trim(),
        model: _model.text.trim(),
        vin: _vin.text.trim().isEmpty ? null : _vin.text.trim(),
        year: int.tryParse(_year.text.trim()),
      ),
    );
  }
}
