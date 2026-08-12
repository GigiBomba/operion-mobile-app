import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Color-coded role chip (blueprint §4.9).
///
/// Maps the backend role strings `dispatcher`, `manager`, `driver` to a
/// colored pill. `admin` is handled defensively (grey) but is never expected
/// in this list — the server constrains invites/role-changes to
/// `{dispatcher, manager}` and the client mirrors that restriction.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, this.compact = false});

  final String role;

  /// When true the badge renders smaller (row contexts).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      'manager' => AppColors.accent,
      'driver' => AppColors.success,
      'dispatcher' => AppColors.warning,
      _ => AppColors.textSecondaryLight,
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
