# team_management

Blueprint §4.9 — team management (manager/admin).

## Implemented (Phase 4B)

- `models/team_member.dart` — `TeamMember` mirroring `TeamMemberOut`
  {id, email, display_name, role, is_active, created_at, driver_name?}.
- `providers/team_providers.dart` — `TeamEndpoints`
  (`GET /mobile/team`, `POST /mobile/team/invite`, `PATCH /mobile/team/{user_id}`),
  `teamMembersProvider` (dual-mode network→cache + banner),
  `teamMutationProvider` (invite / updateRole / deactivate — all gated
  `can_manage_users`; deactivation carries the §4.9 explicit device-revocation
  wording client-side).
- `widgets/role_badge.dart` — color-coded role chip (dispatcher/manager/driver;
  `admin` handled defensively, never surfaced).
- `widgets/invite_user_sheet.dart` — email + role dropdown restricted to
  {dispatcher, manager} (defense-in-depth; the server rejects admin too).
- `screens/team_management_screen.dart` — user list (RoleBadge + status),
  invite FAB, per-row PopupMenuButton (role change / deactivate with
  ConfirmationDialog).
- MoreHub tile: `LucideIcons.users`, gated `can_manage_users` (absent for
  dispatcher).

Backend contract source: `Calculator logistica` — `schemas/mobile.py`
(TeamMemberOut / TeamMemberInviteRequest / TeamUpdateRequest).
