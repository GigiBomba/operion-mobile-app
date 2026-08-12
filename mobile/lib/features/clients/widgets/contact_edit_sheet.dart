import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/client.dart';

/// Editable contact form fields returned by [showContactEditSheet].
class ContactEditData {
  final String name;
  final String? role;
  final String? phone;
  final String? email;

  const ContactEditData({
    required this.name,
    this.role,
    this.phone,
    this.email,
  });
}

/// Shows the contact add/edit bottom sheet.
///
/// Pass [initial] to pre-fill for editing. Returns the validated
/// [ContactEditData] or `null` when dismissed.
Future<ContactEditData?> showContactEditSheet(
  BuildContext context, {
  ClientContact? initial,
}) {
  return showModalBottomSheet<ContactEditData>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _ContactEditSheet(initial: initial),
    ),
  );
}

class _ContactEditSheet extends StatefulWidget {
  const _ContactEditSheet({this.initial});

  final ClientContact? initial;

  @override
  State<_ContactEditSheet> createState() => _ContactEditSheetState();
}

class _ContactEditSheetState extends State<_ContactEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _phone;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _name = TextEditingController(text: c?.name ?? '');
    _role = TextEditingController(text: c?.role ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _email = TextEditingController(text: c?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _phone.dispose();
    _email.dispose();
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
              Text(loc.clients_editContactTitle,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _name,
                labelText: loc.clients_contactName,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? loc.clients_contactNameRequired : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _role,
                labelText: loc.clients_contactRole,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _phone,
                labelText: loc.clients_contactPhone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _email,
                labelText: loc.clients_contactEmail,
                keyboardType: TextInputType.emailAddress,
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
      ContactEditData(
        name: _name.text.trim(),
        role: _role.text.trim().isEmpty ? null : _role.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      ),
    );
  }
}
