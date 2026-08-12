import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/settings_endpoints.dart';
import '../providers/settings_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Phase 4B settings sections (blueprint §4.10).
//
// The first four sections (Company Profile, SMTP, Fleet Tracking, Maintenance
// Thresholds) are manager-gated via `canManageCompanySettings`; the last three
// (Notification Preferences, Data Usage, Biometric Lock) are shown to every
// role. Secret fields (SMTP password / tracking API key) are MASKED and never
// pre-filled with a real value — only a '•••• configured' placeholder when the
// backend reports the secret as set.
// ─────────────────────────────────────────────────────────────────────────────

/// A settings section: uppercase header + Card body.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: child,
          ),
        ),
      ],
    );
  }
}

// ── Company Profile (manager-gated) ─────────────────────────────────────

class CompanyProfileSection extends ConsumerStatefulWidget {
  const CompanyProfileSection({super.key});

  @override
  ConsumerState<CompanyProfileSection> createState() =>
      _CompanyProfileSectionState();
}

class _CompanyProfileSectionState extends ConsumerState<CompanyProfileSection> {
  final _legalName = TextEditingController();
  final _vatNumber = TextEditingController();
  final _address = TextEditingController();
  final _invoiceFooter = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _legalName.dispose();
    _vatNumber.dispose();
    _address.dispose();
    _invoiceFooter.dispose();
    super.dispose();
  }

  void _seed(CompanySettings settings) {
    if (_seeded) return;
    _seeded = true;
    _legalName.text = settings.legalName;
    _vatNumber.text = settings.vatNumber;
    _address.text = settings.address;
    _invoiceFooter.text = settings.invoiceFooter;
  }

  Future<void> _save() async {
    final loc = context.loc;
    setState(() => _saving = true);
    try {
      await ref.read(companySettingsMutationProvider.notifier).save({
        'legal_name': _legalName.text.trim(),
        'vat_number': _vatNumber.text.trim(),
        'address': _address.text.trim(),
        'invoice_footer': _invoiceFooter.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.settings_saved)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.settings_saveFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final async = ref.watch(companySettingsProvider);
    async.whenData(_seed);
    final settings = async.valueOrNull;

    return SettingsSection(
      title: loc.settings_companyProfile,
      child: settings == null
          ? const _SectionLoading()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _legalName,
                  labelText: loc.settings_legalName,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _vatNumber,
                  labelText: loc.settings_vatNumber,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _address,
                  labelText: loc.settings_address,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _invoiceFooter,
                  labelText: loc.settings_invoiceFooter,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton.primary(
                  label: _saving ? loc.settings_saving : loc.settings_save,
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
    );
  }
}

// ── SMTP Configuration (manager-gated) ──────────────────────────────────

class SmtpSection extends ConsumerStatefulWidget {
  const SmtpSection({super.key});

  @override
  ConsumerState<SmtpSection> createState() => _SmtpSectionState();
}

class _SmtpSectionState extends ConsumerState<SmtpSection> {
  final _server = TextEditingController();
  final _port = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _seeded = false;
  bool _saving = false;
  bool _sending = false;

  @override
  void dispose() {
    _server.dispose();
    _port.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  void _seed(CompanySettings settings) {
    if (_seeded) return;
    _seeded = true;
    _server.text = settings.smtpServer;
    _port.text = settings.smtpPort;
    _user.text = settings.smtpUser;
  }

  Future<void> _save() async {
    final loc = context.loc;
    setState(() => _saving = true);
    try {
      await ref.read(companySettingsMutationProvider.notifier).save({
        'smtp_server': _server.text.trim(),
        'smtp_port': _port.text.trim(),
        'smtp_user': _user.text.trim(),
        // Write-only: only sent when the user typed something. An explicit
        // empty string is also valid (clears the secret server-side).
        if (_password.text.isNotEmpty) 'smtp_password': _password.text,
      });
      _password.clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.settings_saved)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.settings_saveFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendTestEmail() async {
    final loc = context.loc;
    setState(() => _sending = true);
    try {
      await ref
          .read(companySettingsMutationProvider.notifier)
          .sendTestEmail();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.settings_testEmailSent)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.settings_testEmailFailed)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final async = ref.watch(companySettingsProvider);
    async.whenData(_seed);
    final settings = async.valueOrNull;

    return SettingsSection(
      title: loc.settings_smtp,
      child: settings == null
          ? const _SectionLoading()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _server,
                  labelText: loc.settings_smtpServer,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _port,
                  labelText: loc.settings_smtpPort,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _user,
                  labelText: loc.settings_smtpUser,
                ),
                const SizedBox(height: AppSpacing.md),
                // MASKED password field — never pre-filled with a real value.
                // Only a '•••• configured' placeholder when the server reports
                // a password is set.
                AppTextField(
                  controller: _password,
                  labelText: loc.settings_smtpPassword,
                  obscureText: true,
                  hintText: settings.smtpPasswordIsSet
                      ? loc.settings_configuredPlaceholder
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton.primary(
                  label: _saving ? loc.settings_saving : loc.settings_save,
                  isLoading: _saving,
                  onPressed: _save,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _sending ? null : _sendTestEmail,
                  icon: _sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.mail, size: 18),
                  label: Text(loc.settings_sendTestEmail),
                ),
              ],
            ),
    );
  }
}

// ── Fleet Tracking Provider (manager-gated) ─────────────────────────────

const List<String> kTrackingProviders = ['', 'wialon', 'frotcom', 'traccar'];

class TrackingSection extends ConsumerStatefulWidget {
  const TrackingSection({super.key});

  @override
  ConsumerState<TrackingSection> createState() => _TrackingSectionState();
}

class _TrackingSectionState extends ConsumerState<TrackingSection> {
  final _apiKey = TextEditingController();
  String? _provider;
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _apiKey.dispose();
    super.dispose();
  }

  void _seed(CompanySettings settings) {
    if (_seeded) return;
    _seeded = true;
    _provider = settings.trackingProvider;
  }

  Future<void> _save() async {
    final loc = context.loc;
    setState(() => _saving = true);
    try {
      await ref.read(companySettingsMutationProvider.notifier).save({
        'tracking_provider': _provider ?? '',
        if (_apiKey.text.isNotEmpty) 'tracking_api_key': _apiKey.text,
      });
      _apiKey.clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.settings_saved)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.settings_saveFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final async = ref.watch(companySettingsProvider);
    async.whenData(_seed);
    final settings = async.valueOrNull;

    return SettingsSection(
      title: loc.settings_tracking,
      child: settings == null
          ? const _SectionLoading()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _provider ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Provider',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final provider in kTrackingProviders)
                      DropdownMenuItem(
                        value: provider,
                        child: Text(provider.isEmpty
                            ? loc.settings_trackingNone
                            : provider),
                      ),
                  ],
                  onChanged: (v) => setState(() => _provider = v),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _apiKey,
                  labelText: loc.settings_trackingApiKey,
                  obscureText: true,
                  hintText: settings.trackingApiKeyIsSet
                      ? loc.settings_configuredPlaceholder
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton.primary(
                  label: _saving ? loc.settings_saving : loc.settings_save,
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
    );
  }
}

// ── Maintenance Thresholds (manager-gated) ──────────────────────────────

class MaintenanceThresholdsSection extends ConsumerStatefulWidget {
  const MaintenanceThresholdsSection({super.key});

  @override
  ConsumerState<MaintenanceThresholdsSection> createState() =>
      _MaintenanceThresholdsSectionState();
}

class _MaintenanceThresholdsSectionState
    extends ConsumerState<MaintenanceThresholdsSection> {
  int _maintenanceAlertDays = 30;
  int _tachoWarningDays = 45;
  int _tachoCriticalDays = 15;
  bool _seeded = false;
  bool _saving = false;

  void _seed(CompanySettings settings) {
    if (_seeded) return;
    _seeded = true;
    _maintenanceAlertDays = settings.maintenanceAlertDaysAhead;
    _tachoWarningDays = settings.tachoWarningDays;
    _tachoCriticalDays = settings.tachoCriticalDays;
  }

  Future<void> _save() async {
    final loc = context.loc;
    setState(() => _saving = true);
    try {
      await ref.read(companySettingsMutationProvider.notifier).save({
        'maintenance_alert_days_ahead': _maintenanceAlertDays,
        'tacho_warning_days': _tachoWarningDays,
        'tacho_critical_days': _tachoCriticalDays,
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.settings_saved)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.settings_saveFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final async = ref.watch(companySettingsProvider);
    async.whenData(_seed);

    return SettingsSection(
      title: loc.settings_maintenanceThresholds,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ThresholdSlider(
            label: loc.settings_maintenanceAlertDays,
            value: _maintenanceAlertDays.toDouble(),
            min: 1,
            max: 365,
            onChanged: (v) => setState(() => _maintenanceAlertDays = v.round()),
          ),
          const Divider(height: 1),
          _ThresholdSlider(
            label: loc.settings_tachoWarningDays,
            value: _tachoWarningDays.toDouble(),
            min: 1,
            max: 365,
            onChanged: (v) => setState(() => _tachoWarningDays = v.round()),
          ),
          const Divider(height: 1),
          _ThresholdSlider(
            label: loc.settings_tachoCriticalDays,
            value: _tachoCriticalDays.toDouble(),
            min: 1,
            max: 365,
            onChanged: (v) => setState(() => _tachoCriticalDays = v.round()),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            label: _saving ? loc.settings_saving : loc.settings_save,
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          SizedBox(
            width: 200,
            child: Slider(
              value: value,
              min: min,
              max: max,
              label: '${value.round()}',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${value.round()}',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification Preferences (all roles) ────────────────────────────────

class NotificationPreferencesSection extends ConsumerWidget {
  const NotificationPreferencesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final prefs = ref.watch(notificationPreferencesProvider);
    final notifier = ref.read(notificationPreferencesProvider.notifier);

    return SettingsSection(
      title: loc.settings_notifications,
      child: Column(
        children: [
          SwitchListTile(
            title: Text(loc.settings_notifCritical),
            value: prefs.critical,
            onChanged: notifier.setCritical,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            title: Text(loc.settings_notifWarning),
            value: prefs.warning,
            onChanged: notifier.setWarning,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            title: Text(loc.settings_notifInfo),
            value: prefs.info,
            onChanged: notifier.setInfo,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            title: Text(loc.settings_quietHours),
            subtitle: Text(
              '${prefs.quietStart} – ${prefs.quietEnd}',
            ),
            value: prefs.quietHoursEnabled,
            onChanged: notifier.setQuietHoursEnabled,
          ),
          if (prefs.quietHoursEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Start',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: notifier.setQuietStart,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'End',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: notifier.setQuietEnd,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Data Usage (all roles) ──────────────────────────────────────────────

class DataUsageSection extends ConsumerWidget {
  const DataUsageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final prefs = ref.watch(dataUsageProvider);

    return SettingsSection(
      title: loc.settings_dataUsage,
      child: SwitchListTile(
        title: Text(loc.settings_wifiOnlyLargeSyncs),
        subtitle: Text(loc.settings_wifiOnlyLargeSyncsHint),
        value: prefs.wifiOnlyLargeSyncs,
        onChanged: ref.read(dataUsageProvider.notifier).setWifiOnlyLargeSyncs,
      ),
    );
  }
}

// ── Biometric Lock (all roles) ──────────────────────────────────────────

class BiometricLockSection extends ConsumerWidget {
  const BiometricLockSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final prefs = ref.watch(biometricLockProvider);

    return SettingsSection(
      title: loc.settings_biometricLock,
      child: Column(
        children: [
          SwitchListTile(
            title: Text(loc.settings_biometricUnlock),
            subtitle: Text(loc.settings_biometricUnlockHint),
            value: prefs.biometricUnlockEnabled,
            onChanged: ref
                .read(biometricLockProvider.notifier)
                .setBiometricUnlockEnabled,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // §12 financial gate — DEFAULT ON, never silently disabled.
          SwitchListTile(
            title: Text(loc.settings_requireFinancial),
            subtitle: Text(loc.settings_requireFinancialHint),
            value: prefs.requireForFinancialActions,
            onChanged: ref
                .read(biometricLockProvider.notifier)
                .setRequireForFinancialActions,
          ),
        ],
      ),
    );
  }
}

/// Compact loading placeholder for a manager-gated section.
class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
