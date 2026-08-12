import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/permission_guard.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/master_detail_layout.dart';
import 'widgets/settings_sections.dart';

/// Settings screen accessible from both Driver and Dispatcher modes.
///
/// Provides:
/// * **Language** selector — Română / English (radio buttons).
/// * **Theme** selector — System / Light / Dark (radio buttons).
/// * **App version** display.
/// * **Phase 4B (§4.10) sections** — 7 new settings groups:
///   - Company Profile / SMTP / Fleet Tracking / Maintenance Thresholds
///     (manager-gated `canManageCompanySettings`);
///   - Notification Preferences / Data Usage / Biometric Lock (all roles).
/// * **Logout** button — red, at the bottom, with a confirmation dialog.
///
/// On tablet widths (≥600dp) the screen becomes a master-detail layout with a
/// section-navigation list pane and the selected section as the detail pane
/// (blueprint §9 item 5).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.enableTabletLayout = true});

  final bool enableTabletLayout;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedSection = 0;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final canManage = ref
        .watch(permissionProvider)
        .can(Permissions.canManageCompanySettings);

    final sections = _buildSections(loc, theme, locale, themeMode, canManage);
    final tablet = widget.enableTabletLayout && isTabletWidth(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.nav_settings),
      ),
      body: tablet
          ? MasterDetailLayout(
              selectedIndex: _selectedSection,
              listPane: _SettingsNavPane(
                sections: sections,
                selectedIndex: _selectedSection,
                onSelect: (i) => setState(() => _selectedSection = i),
              ),
              detailBuilder: (context, index) {
                final sel = index.clamp(0, sections.length - 1);
                // Section content is scrollable so tall panes never overflow.
                return SingleChildScrollView(
                  child: sections[sel].builder(context),
                );
              },
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _AppearancePane(
                  loc: loc,
                  theme: theme,
                  locale: locale,
                  themeMode: themeMode,
                  ref: ref,
                ),

                if (canManage) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  const CompanyProfileSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  const SmtpSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  const TrackingSection(),
                  const SizedBox(height: AppSpacing.xxl),
                  const MaintenanceThresholdsSection(),
                ],

                const SizedBox(height: AppSpacing.xxl),
                const NotificationPreferencesSection(),
                const SizedBox(height: AppSpacing.xxl),
                const DataUsageSection(),
                const SizedBox(height: AppSpacing.xxl),
                const BiometricLockSection(),

                const SizedBox(height: AppSpacing.xxxl),

                // ── Logout button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleLogout(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    ),
                    icon: const Icon(Icons.logout),
                    label: Text(loc.auth_logout),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }

  /// The tablet section-navigation definitions.
  List<_SettingsSectionDef> _buildSections(
    AppLocalizations loc,
    ThemeData theme,
    Locale locale,
    ThemeMode themeMode,
    bool canManage,
  ) {
    final sections = <_SettingsSectionDef>[
      _SettingsSectionDef(
        icon: Icons.palette_outlined,
        label: loc.settings_appearance,
        builder: (_) => _AppearancePane(
          loc: loc,
          theme: theme,
          locale: locale,
          themeMode: themeMode,
          ref: ref,
        ),
      ),
      _SettingsSectionDef(
        icon: Icons.notifications_outlined,
        label: loc.settings_notifications,
        builder: (_) => const NotificationPreferencesSection(),
      ),
      _SettingsSectionDef(
        icon: Icons.storage_outlined,
        label: loc.settings_dataUsage,
        builder: (_) => const DataUsageSection(),
      ),
      _SettingsSectionDef(
        icon: Icons.lock_outline,
        label: loc.settings_biometricLock,
        builder: (_) => const BiometricLockSection(),
      ),
    ];

    if (canManage) {
      sections.insertAll(1, [
        _SettingsSectionDef(
          icon: Icons.business_outlined,
          label: loc.settings_companyProfile,
          builder: (_) => const CompanyProfileSection(),
        ),
        _SettingsSectionDef(
          icon: Icons.alternate_email,
          label: loc.settings_smtp,
          builder: (_) => const SmtpSection(),
        ),
        _SettingsSectionDef(
          icon: Icons.gps_fixed,
          label: loc.settings_tracking,
          builder: (_) => const TrackingSection(),
        ),
        _SettingsSectionDef(
          icon: Icons.build_outlined,
          label: loc.settings_maintenanceThresholds,
          builder: (_) => const MaintenanceThresholdsSection(),
        ),
      ]);
    }

    sections.add(
      _SettingsSectionDef(
        icon: Icons.logout,
        label: loc.auth_logout,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _handleLogout(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.logout),
              label: Text(loc.auth_logout),
            ),
          ),
        ),
      ),
    );
    return sections;
  }

  /// Shows a confirmation dialog and, on confirm, clears tokens and auth state.
  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmationDialog.show(context,
      title: context.loc.auth_logout,
      message: context.loc.auth_logoutConfirm,
      confirmLabel: context.loc.auth_logout,
      isDangerous: true,
    );
    if (confirmed == true) {
      try {
        await ref.read(authServiceProvider).logout();
      } catch (_) {
        // Best-effort logout — clear local state regardless
      }
      ref.read(currentUserProvider.notifier).state = null;
      ref.read(authStateProvider.notifier).setUnauthenticated();
    }
  }
}

/// A tablet settings section definition.
class _SettingsSectionDef {
  const _SettingsSectionDef({
    required this.icon,
    required this.label,
    required this.builder,
  });

  final IconData icon;
  final String label;
  final WidgetBuilder builder;
}

/// Tablet list pane: vertical section navigation.
class _SettingsNavPane extends StatelessWidget {
  const _SettingsNavPane({
    required this.sections,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_SettingsSectionDef> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        final selected = index == selectedIndex;
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : null,
          child: ListTile(
            leading: Icon(
              section.icon,
              color: selected ? AppColors.primary : null,
            ),
            title: Text(
              section.label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            onTap: () => onSelect(index),
          ),
        );
      },
    );
  }
}

/// Language / Theme / App version section (shared phone + tablet).
class _AppearancePane extends StatelessWidget {
  const _AppearancePane({
    required this.loc,
    required this.theme,
    required this.locale,
    required this.themeMode,
    required this.ref,
  });

  final AppLocalizations loc;
  final ThemeData theme;
  final Locale locale;
  final ThemeMode themeMode;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Language section ─────────────────────────────────────
        _SectionHeader(title: loc.settings_language),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: [
              RadioListTile<Locale>(
                title: Text(loc.settings_languageRo),
                subtitle: const Text('Română'),
                value: const Locale('ro'),
                groupValue: locale,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(localeProvider.notifier).state = value;
                  }
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              RadioListTile<Locale>(
                title: Text(loc.settings_languageEn),
                subtitle: const Text('English'),
                value: const Locale('en'),
                groupValue: locale,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(localeProvider.notifier).state = value;
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        // ── Theme section ────────────────────────────────────────
        _SectionHeader(title: loc.settings_theme),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: [
              RadioListTile<ThemeMode>(
                title: Text(loc.settings_themeSystem),
                subtitle: Text(
                  theme.brightness == Brightness.light ? 'Light' : 'Dark',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                value: ThemeMode.system,
                groupValue: themeMode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).state = value;
                  }
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              RadioListTile<ThemeMode>(
                title: Text(loc.settings_themeLight),
                value: ThemeMode.light,
                groupValue: themeMode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).state = value;
                  }
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              RadioListTile<ThemeMode>(
                title: Text(loc.settings_themeDark),
                value: ThemeMode.dark,
                groupValue: themeMode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).state = value;
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        // ── App version ──────────────────────────────────────────
        _SectionHeader(title: loc.settings_appVersion),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: ListTile(
            title: Text(loc.settings_appVersion),
            trailing: Text(
              '1.0.0+1',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A styled section header used in settings groups (iOS-style).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
