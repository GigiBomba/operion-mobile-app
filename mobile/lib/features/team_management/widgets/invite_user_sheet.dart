import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/team_providers.dart';

/// Roles a manager may invite/assign client-side (blueprint §4.9).
///
/// `admin` is deliberately NOT in this list — the server also rejects it
/// (defense-in-depth), but the dropdown never offers it.
const List<String> kInviteableRoles = ['dispatcher', 'manager'];

/// Bottom sheet for inviting a new team member (email + role).
///
/// The role dropdown is restricted to {dispatcher, manager} — admin is never
/// an option (the backend rejects it too).
class InviteUserSheet extends ConsumerStatefulWidget {
  const InviteUserSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const InviteUserSheet(),
    );
  }

  @override
  ConsumerState<InviteUserSheet> createState() => _InviteUserSheetState();
}

class _InviteUserSheetState extends ConsumerState<InviteUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _role = 'dispatcher';
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final loc = context.loc;
    try {
      await ref
          .read(teamMutationProvider.notifier)
          .invite(email: _emailController.text.trim(), role: _role);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.team_inviteSent)));
    } on TeamRequiresConnection {
      if (mounted) _showError(loc.team_requiresConnection);
    } on TeamNotPermitted {
      if (mounted) _showError(loc.team_notPermitted);
    } catch (_) {
      if (mounted) _showError(loc.team_inviteFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        top: AppSpacing.xxl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.team_inviteTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _emailController,
              labelText: loc.team_inviteEmail,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final email = v?.trim() ?? '';
                if (email.isEmpty) return loc.team_inviteEmailRequired;
                if (!email.contains('@')) return loc.team_inviteEmailInvalid;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: InputDecoration(
                labelText: loc.team_inviteRole,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final role in kInviteableRoles)
                  DropdownMenuItem(value: role, child: Text(role)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _role = v);
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton.primary(
              label: _busy ? loc.team_inviting : loc.team_inviteBtn,
              isLoading: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
