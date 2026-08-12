import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/permission_guard.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/tacho_week_view.dart';
import '../providers/teams_providers.dart';
import '../widgets/driver_edit_sheet.dart';
import '../widgets/expiry_badge.dart';

/// Read-view for a single driver (manager scope, §6.2) — 4 tabs (blueprint
/// §4.2):
/// 1. **Overview** — identity, license fields, expiry rows, assignments.
/// 2. **Compliance** — ExpiryBadge rows (license/medical/ADR) + Renew actions.
/// 3. **Tacho Timeline** — 7-day stacked bars + weekly driving gauge.
/// 4. **Assignments** — current truck (read-only).
///
/// The [driver] summary map renders immediately; license data is fetched via
/// `GET /api/v1/mobile/drivers/{id}` ([driverDetailProvider], full DriverOut
/// incl. ADR certificate) with §1.2 treatment.
class DriverDetailScreen extends ConsumerWidget {
  const DriverDetailScreen({super.key, required this.driver});

  /// The driver list entry used to push this screen.
  final Map<String, dynamic> driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final driverId = (driver['id'] ?? '').toString();
    final name = driver['name'] as String? ?? '';

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name.isEmpty ? loc.nav_teams : name),
          // Primary Edit action relocated from the AppBar to the FAB
          // (one-handed reachability audit, blueprint §9 item 6).
          bottom: const TabBar(
            tabs: [
              _DriverTab(label: 'overview'),
              _DriverTab(label: 'compliance'),
              _DriverTab(label: 'tacho'),
              _DriverTab(label: 'assignments'),
            ],
          ),
        ),
        body: _DriverDetailBody(driver: driver, driverId: driverId),
        floatingActionButton: buildIfPermitted(
          ref,
          Permissions.updateDriver,
          () => FloatingActionButton(
            onPressed: () => _editDriver(context, ref, driverId),
            tooltip: loc.teams_editDriver,
            child: const Icon(Icons.edit_outlined),
          ),
        ),
      ),
    );
  }

  Future<void> _editDriver(
    BuildContext context,
    WidgetRef ref,
    String driverId,
  ) async {
    final detail = ref.read(driverDetailProvider(driverId)).value?.driver;
    final draft = await showDriverEditSheet(context, initial: detail);
    if (draft == null || !context.mounted) return;
    await ref
        .read(driverMutationProvider.notifier)
        .updateDriver(driverId, draft);
  }
}

class _DriverTab extends StatelessWidget {
  const _DriverTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final text = switch (label) {
      'overview' => loc.teams_overview,
      'compliance' => loc.teams_compliance,
      'tacho' => loc.teams_tacho,
      _ => loc.teams_assignments,
    };
    return Tab(text: text);
  }
}

class _DriverDetailBody extends ConsumerWidget {
  const _DriverDetailBody({required this.driver, required this.driverId});

  final Map<String, dynamic> driver;
  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(driverDetailProvider(driverId));

    return detailAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: List.generate(
          4,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: ShimmerLoader(child: _ShimmerBlock(height: 96)),
          ),
        ),
      ),
      error: (e, _) => _DetailError(
        message: '${driver['name'] ?? ''}',
        onRetry: () => ref.invalidate(driverDetailProvider(driverId)),
      ),
      data: (data) => TabBarView(
        children: [
          _OverviewTab(driver: driver, detail: data.driver),
          _ComplianceTab(detail: data.driver, driverId: driverId),
          _TachoTab(driverId: driverId),
          _AssignmentsTab(driver: driver, detail: data.driver),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.driver, required this.detail});

  final Map<String, dynamic> driver;
  final DriverDetail detail;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final name = driver['name'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ── Identity + status ─────────────────────────────
        AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    if (detail.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail.phone,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              StatusBadge(statusKey: driver['status'] as String? ?? ''),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── License card ──────────────────────────────────
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _hasLicenseData(detail)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                        icon: LucideIcons.idCard,
                        label: loc.teams_licenseNumber,
                        value: detail.licenseNumber.isEmpty
                            ? loc.teams_notAssigned
                            : detail.licenseNumber,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _DetailRow(
                        icon: LucideIcons.badgeCheck,
                        label: loc.teams_licenseCategory,
                        value: detail.licenseCategory.isEmpty
                            ? loc.teams_notAssigned
                            : detail.licenseCategory,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ExpiryRow(
                        icon: LucideIcons.calendarClock,
                        label: loc.teams_licenseExpiry,
                        expiry: detail.licenseExpiry,
                        loc: loc,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ExpiryRow(
                        icon: LucideIcons.stethoscope,
                        label: loc.teams_medicalExpiry,
                        expiry: detail.medicalExpiry,
                        loc: loc,
                      ),
                    ],
                  )
                : Column(
                    children: [
                      const Icon(LucideIcons.idCard,
                          size: 40, color: AppColors.textTertiary),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        loc.profile_noDriverInfo,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Assignment card ───────────────────────────────
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(
                  icon: LucideIcons.truck,
                  label: loc.teams_assignedTransport,
                  value: (driver['current_transport'] as String?)?.isNotEmpty ==
                          true
                      ? driver['current_transport'] as String
                      : loc.teams_notAssigned,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  icon: LucideIcons.carFront,
                  label: loc.teams_assignedVehicle,
                  value: (driver['current_vehicle'] as String?)?.isNotEmpty ==
                          true
                      ? driver['current_vehicle'] as String
                      : loc.teams_notAssigned,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  bool _hasLicenseData(DriverDetail detail) {
    return detail.licenseNumber.isNotEmpty ||
        detail.licenseCategory.isNotEmpty ||
        detail.licenseExpiry != null ||
        detail.medicalExpiry != null;
  }
}

class _ComplianceTab extends ConsumerWidget {
  const _ComplianceTab({required this.detail, required this.driverId});

  final DriverDetail detail;
  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final canUpdate = ref.watch(permissionProvider).can(Permissions.updateDriver);

    Widget row({
      required IconData icon,
      required String label,
      required DateTime? expiry,
      required DriverEditField focusField,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
                    if (canUpdate)
                      TextButton(
                        onPressed: () => _renew(context, ref, focusField),
                        child: Text(loc.teams_renew),
                      ),
                  ],
                ),
                if (expiry != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      ExpiryBadge(expiry: expiry),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _formatDate(expiry),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        row(
          icon: LucideIcons.idCard,
          label: loc.teams_licenseExpiry,
          expiry: detail.licenseExpiry,
          focusField: DriverEditField.licenseExpiry,
        ),
        row(
          icon: LucideIcons.stethoscope,
          label: loc.teams_medicalExpiry,
          expiry: detail.medicalExpiry,
          focusField: DriverEditField.medicalExpiry,
        ),
        row(
          icon: LucideIcons.shieldCheck,
          label: loc.teams_adrExpiry,
          expiry: detail.adrCertificateExpiry,
          focusField: DriverEditField.adrCertificateExpiry,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${loc.teams_expiryWindow} ${teamsWindowDays()} ${loc.teams_daysShort}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Future<void> _renew(
    BuildContext context,
    WidgetRef ref,
    DriverEditField focusField,
  ) async {
    final draft = await showDriverEditSheet(
      context,
      initial: detail,
      focusField: focusField,
    );
    if (draft == null || !context.mounted) return;
    await ref
        .read(driverMutationProvider.notifier)
        .updateDriver(driverId, draft);
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

/// The real 30-day expiring window (backend constant, see teams_providers).
int teamsWindowDays() => kExpiringLicensesDefaultDays;

class _TachoTab extends ConsumerWidget {
  const _TachoTab({required this.driverId});

  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final tachoAsync = ref.watch(driverTachoProvider(driverId));
    return tachoAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: List.generate(
          4,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: ShimmerLoader(child: _ShimmerBlock(height: 72)),
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertCircle, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${loc.general_error}: $e',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(driverTachoProvider(driverId)),
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: Text(loc.general_retry),
              ),
            ],
          ),
        ),
      ),
      data: (week) => TachoWeekView(week: week, loc: loc),
    );
  }
}

class _AssignmentsTab extends StatelessWidget {
  const _AssignmentsTab({required this.driver, required this.detail});

  final Map<String, dynamic> driver;
  final DriverDetail detail;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.teams_assignments, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(
                  icon: LucideIcons.truck,
                  label: loc.teams_assignedVehicle,
                  value: detail.currentTruckId ?? loc.teams_notAssigned,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  loc.teams_assignmentsNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A single detail row: icon + label + value.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

/// Expiry date row with the expiry-status treatment (valid / expiring soon /
/// expired). Classification via [licenseExpiryStatusFor].
class _ExpiryRow extends StatelessWidget {
  const _ExpiryRow({
    required this.icon,
    required this.label,
    required this.expiry,
    required this.loc,
  });

  final IconData icon;
  final String label;
  final DateTime? expiry;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = licenseExpiryStatusFor(expiry);
    final formatted = expiry == null ? null : _formatDate(expiry!);
    final badgeKey = switch (status) {
      LicenseExpiryStatus.valid => 'paid',
      LicenseExpiryStatus.expiringSoon => 'in_transit',
      LicenseExpiryStatus.expired => 'overdue',
    };
    final badgeLabel = switch (status) {
      LicenseExpiryStatus.valid => loc.teams_licenseValid,
      LicenseExpiryStatus.expiringSoon => loc.teams_licenseExpiringSoon,
      LicenseExpiryStatus.expired => loc.teams_licenseExpired,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatted ?? loc.teams_notAssigned,
                style: theme.textTheme.bodyMedium,
              ),
              if (expiry != null) ...[
                const SizedBox(height: AppSpacing.xs),
                StatusBadge(statusKey: badgeKey, label: badgeLabel),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

/// §1.2 error state with a retry action.
class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle,
                size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              loc.teams_detailLoadError,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: Text(loc.general_retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  final double height;
  const _ShimmerBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
