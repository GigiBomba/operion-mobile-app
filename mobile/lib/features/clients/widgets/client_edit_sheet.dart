import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/client.dart';

/// Editable client form fields returned by [showClientEditSheet].
class ClientEditData {
  final String name;
  final String? vatNumber;
  final String? address;
  final int paymentTermsDays;
  final bool isActive;

  const ClientEditData({
    required this.name,
    this.vatNumber,
    this.address,
    this.paymentTermsDays = 0,
    this.isActive = true,
  });
}

/// Shows the client create/edit bottom sheet.
///
/// Pass [initial] to pre-fill the fields for editing. Returns the validated
/// [ClientEditData] or `null` when dismissed.
Future<ClientEditData?> showClientEditSheet(
  BuildContext context, {
  Client? initial,
}) {
  return showModalBottomSheet<ClientEditData>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _ClientEditSheet(initial: initial),
    ),
  );
}

class _ClientEditSheet extends StatefulWidget {
  const _ClientEditSheet({this.initial});

  final Client? initial;

  @override
  State<_ClientEditSheet> createState() => _ClientEditSheetState();
}

class _ClientEditSheetState extends State<_ClientEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _vat;
  late final TextEditingController _address;
  late final TextEditingController _paymentTerms;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _name = TextEditingController(text: c?.name ?? '');
    _vat = TextEditingController(text: c?.vatNumber ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _paymentTerms =
        TextEditingController(text: (c?.paymentTermsDays ?? 0).toString());
    _isActive = c?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _vat.dispose();
    _address.dispose();
    _paymentTerms.dispose();
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
              Text(loc.clients_editTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _name,
                labelText: loc.clients_name,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? loc.clients_nameRequired : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _vat,
                labelText: loc.clients_vatNumber,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _address,
                labelText: loc.clients_address,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _paymentTerms,
                labelText: loc.clients_paymentTerms,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(loc.clients_active),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
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
      ClientEditData(
        name: _name.text.trim(),
        vatNumber: _vat.text.trim().isEmpty ? null : _vat.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        paymentTermsDays: int.tryParse(_paymentTerms.text.trim()) ?? 0,
        isActive: _isActive,
      ),
    );
  }
}
