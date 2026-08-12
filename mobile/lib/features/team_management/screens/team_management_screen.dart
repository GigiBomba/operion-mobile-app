import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/permission_guard.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/master_detail_layout.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../models/team_member.dart';
import '../providers/team_providers.dart';
import '../widgets/invite_user_sheet.dart';
import '../widgets/role_badge.dart';

/// Team Management screen (blueprint §4.9).
///
/// - User list with [RoleBadge] + active/inactive status.
/// - Invite FAB → [InviteUserSheet] (role restricted to {dispatcher, manager}).
/// - Per-row PopupMenuButton: role change (same restriction) / deactivate
///   with the §4.9 EXPLICIT revocation wording.
/// - Every mutation gates on `can_manage_users` (client + server).
///
/// Reachability audit (§9 item 6): the invite action is FAB-only (no AppBar
/// icon — the AppBar icon was redundant with the FAB). On tablet widths the
/// member list becomes the list pane of a master-detail layout with a
/// read-only member summary as the detail pane (§9 item 5).
class TeamManagementScreen extends ConsumerStatefulWidget {
  const TeamManagementScreen({super.key, this.enableTabletLayout = true});

  final bool enableTabletLayout;

  @override
  ConsumerState<TeamManagementScreen> createState() =>
      _TeamManagementScreenState();
}

class _TeamManagementScreenState extends ConsumerState<TeamManagementScreen> {
  int? _selectedIndex;

  Future<void> _openInvite(BuildContext context, WidgetRef ref) async {
    await InviteUserSheet.show(context);
    ref.invalidate(teamMembersProvider);
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    WidgetRef ref,
    TeamMember member,
  ) async {
    final loc = context.loc;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: loc.team_deactivateTitle,
      message: loc.team_deactivateMessage(member.displayName),
      confirmLabel: loc.team_deactivate,
      isDangerous: true,
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(teamMutationProvider.notifier)
          .deactivate(userId: member.id.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.team_deactivated)),
        );
      }
    } on TeamRequiresConnection {
      if (context.mounted) _showMessage(context, loc.team_requiresConnection);
    } on TeamNotPermitted {
      if (context.mounted) _showMessage(context, loc.team_notPermitted);
    } catch (_) {
      if (context.mounted) _showMessage(context, loc.team_actionFailed);
    }
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    TeamMember member,
    String role,
  ) async {
    final loc = context.loc;
    try {
      await ref
          .read(teamMutationProvider.notifier)
          .updateRole(userId: member.id.toString(), role: role);
      if (context.mounted) _showMessage(context, loc.team_roleUpdated);
    } on TeamRequiresConnection {
      if (context.mounted) _showMessage(context, loc.team_requiresConnection);
    } on TeamNotPermitted {
      if (context.mounted) _showMessage(context, loc.team_notPermitted);
    } catch (_) {
      if (context.mounted) _showMessage(context, loc.team_actionFailed);
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final membersAsync = ref.watch(teamMembersProvider);
    final cached = ref.watch(teamCachedBannerProvider);
    final members = membersAsync.valueOrNull?.members ?? const <TeamMember>[];
    final tablet =
        widget.enableTabletLayout && isTabletWidth(context) && members.isNotEmpty;

    final listPane = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cached)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              loc.team_cached,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.6,
                    ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: members.length,
            itemBuilder: (context, index) => _MemberTile(
              member: members[index],
              onTap: tablet
                  ? () => setState(() => _selectedIndex = index)
                  : null,
              onRoleChanged: (role) =>
                  _changeRole(context, ref, members[index], role),
              onDeactivate: () =>
                  _confirmDeactivate(context, ref, members[index]),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.nav_teamsManagement),
      ),
      // Invite is FAB-only (reachability audit §9 item 6) and gated by
      // can_manage_users (§8.2).
      floatingActionButton: buildIfPermitted(
        ref,
        Permissions.canManageUsers,
        () => FloatingActionButton(
          onPressed: () => _openInvite(context, ref),
          tooltip: loc.team_inviteBtn,
          child: const Icon(LucideIcons.userPlus),
        ),
      ),
      body: membersAsync.when(
        loading: () => const _TeamListShimmer(),
        error: (e, _) => Center(child: Text('$e')),
        data: (_) {
          if (members.isEmpty) {
            return EmptyState(
              icon: const Icon(LucideIcons.users),
              title: loc.team_emptyTitle,
              subtitle: loc.team_emptyHint,
            );
          }
          return tablet
              ? MasterDetailLayout(
                  selectedIndex: _selectedIndex ?? 0,
                  listPane: listPane,
                  detailBuilder: (context, index) {
                    final sel = index.clamp(0, members.length - 1);
                    return _MemberDetailPane(member: members[sel]);
                  },
                )
              : listPane;
        },
      ),
    );
  }
}

/// Read-only member summary shown as the tablet detail pane (§9 item 5).
class _MemberDetailPane extends StatelessWidget {
  const _MemberDetailPane({required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          loc.team_memberDetails,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                      child: Text(
                        member.displayName.isEmpty
                            ? '?'
                            : member.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName.isEmpty ? '—' : member.displayName,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            member.email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    RoleBadge(role: member.role),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      member.isActive ? loc.team_active : loc.team_inactive,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: member.isActive
                            ? AppColors.success
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.onRoleChanged,
    required this.onDeactivate,
    this.onTap,
  });

  final TeamMember member;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onDeactivate;

  /// Selection callback for the tablet detail pane (null on phone).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                child: Text(
                  member.displayName.isEmpty
                      ? '?'
                      : member.displayName[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName.isEmpty ? '—' : member.displayName,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        RoleBadge(role: member.role, compact: true),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            member.isActive
                                ? loc.team_active
                                : loc.team_inactive,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: member.isActive
                                  ? AppColors.success
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (member.role != 'admin')
                PopupMenuButton<String>(
                  tooltip: loc.team_moreActions,
                  onSelected: (value) {
                    if (value == 'deactivate') {
                      onDeactivate();
                    } else {
                      onRoleChanged(value);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'dispatcher', child: Text('dispatcher')),
                    const PopupMenuItem(value: 'manager', child: Text('manager')),
                    PopupMenuItem(
                      value: 'deactivate',
                      child: Text(loc.team_deactivate),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamListShimmer extends StatelessWidget {
  const _TeamListShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: List.generate(
        6,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: ShimmerCard(),
        ),
      ),
    );
  }
}
