import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'user_role.dart';

/// A permission is a string key naming an exact backend `can_*` method.
///
/// The backend `services/permission_service.py` exposes methods named
/// `can_<action>`; every [Permissions] constant below is byte-for-byte
/// identical to the `permission` field in
/// `shared/test_vectors/permission_matrix.json` (backend-generated), so the
/// fixture can drive Dart tests (blueprint §13.4).
typedef Permission = String;

/// Canonical permission constants (blueprint §8.2).
///
/// One constant per backend `can_*` method — 31 total, mirroring
/// `services/permission_service.py` exactly. Aggregated/UI-level checks are
/// expressed at call sites via `PermissionState.canAny([...])`, never as
/// bespoke constants.
abstract final class Permissions {
  // Dispatch
  static const createDispatch = 'can_create_dispatch';
  static const cancelDispatch = 'can_cancel_dispatch';

  // Trips
  static const createTrip = 'can_create_trip';
  static const updateTrip = 'can_update_trip';

  /// Admin-only per blueprint §8.3.
  static const deleteTrip = 'can_delete_trip';

  // Documents
  static const uploadDocument = 'can_upload_document';
  static const deleteDocument = 'can_delete_document';
  static const emailDocument = 'can_email_document';

  // CMR
  static const generateCmr = 'can_generate_cmr';

  // Export
  static const exportData = 'can_export_data';

  // Maintenance
  static const scheduleMaintenance = 'can_schedule_maintenance';

  // Vehicles (fleet)
  static const createVehicle = 'can_create_vehicle';
  static const updateVehicle = 'can_update_vehicle';
  static const deleteVehicle = 'can_delete_vehicle';

  // Drivers
  static const createDriver = 'can_create_driver';
  static const updateDriver = 'can_update_driver';
  static const deleteDriver = 'can_delete_driver';

  // Clients / CRM
  static const createClient = 'can_create_client';
  static const updateClient = 'can_update_client';
  static const mergeClients = 'can_merge_clients';
  static const deleteClient = 'can_delete_client';

  // Invoicing
  static const createInvoice = 'can_create_invoice';
  static const cancelInvoice = 'can_cancel_invoice';
  static const finalizeInvoice = 'can_finalize_invoice';
  static const createProforma = 'can_create_proforma';
  static const updateProforma = 'can_update_proforma';
  static const createReceipt = 'can_create_receipt';
  static const updateReceipt = 'can_update_receipt';
  static const generatePayments = 'can_generate_payments';

  // Analytics
  static const viewAnalytics = 'can_view_analytics';

  // Communication
  static const sendEmail = 'can_send_email';

  // Phase 4B — Team Management & Company Settings (§4.9/§4.10)
  static const canManageUsers = 'can_manage_users';
  static const canViewCompanySettings = 'can_view_company_settings';
  static const canManageCompanySettings = 'can_manage_company_settings';

  /// All 34 backend permission names (one per `can_*` method).
  static const List<Permission> all = [
    cancelDispatch,
    cancelInvoice,
    createClient,
    createDispatch,
    createDriver,
    createInvoice,
    createProforma,
    createReceipt,
    createTrip,
    createVehicle,
    deleteClient,
    deleteDocument,
    deleteDriver,
    deleteTrip,
    deleteVehicle,
    emailDocument,
    exportData,
    finalizeInvoice,
    generateCmr,
    generatePayments,
    mergeClients,
    scheduleMaintenance,
    sendEmail,
    updateClient,
    updateDriver,
    updateProforma,
    updateReceipt,
    updateTrip,
    updateVehicle,
    uploadDocument,
    viewAnalytics,
    canManageUsers,
    canViewCompanySettings,
    canManageCompanySettings,
  ];
}

/// Per-role allowed permission sets.
///
/// DERIVED from `shared/test_vectors/permission_matrix.json` (backend
/// `PermissionService` introspection); keep in sync via
/// `scripts/export_permission_matrix.py`. For each role, the allowed set is
/// exactly `{permission | expected_allowed == true for that role in the
/// fixture}`:
///
/// - `driver`      → empty set (no `can_*` granted).
/// - `dispatcher`  → 8 permissions (dispatch, CMR, documents, trip basics).
/// - `manager`     → 29 permissions (no client/driver/trip/vehicle deletes,
///                   no `can_merge_clients`; + Phase 4B team/settings).
/// - `admin`       → all 34 permissions.
///
/// Verified by `test/core/permission_matrix_consistency_test.dart`.
const Map<UserRole, Set<Permission>> permissionsByRole = {
  UserRole.driver: <Permission>{},
  UserRole.dispatcher: <Permission>{
    Permissions.cancelDispatch,
    Permissions.createDispatch,
    Permissions.createTrip,
    Permissions.emailDocument,
    Permissions.exportData,
    Permissions.generateCmr,
    Permissions.updateTrip,
    Permissions.uploadDocument,
  },
  UserRole.manager: <Permission>{
    Permissions.cancelDispatch,
    Permissions.cancelInvoice,
    Permissions.createClient,
    Permissions.createDispatch,
    Permissions.createDriver,
    Permissions.createInvoice,
    Permissions.createProforma,
    Permissions.createReceipt,
    Permissions.createTrip,
    Permissions.createVehicle,
    Permissions.deleteDocument,
    Permissions.emailDocument,
    Permissions.exportData,
    Permissions.finalizeInvoice,
    Permissions.generateCmr,
    Permissions.generatePayments,
    Permissions.scheduleMaintenance,
    Permissions.sendEmail,
    Permissions.updateClient,
    Permissions.updateDriver,
    Permissions.updateProforma,
    Permissions.updateReceipt,
    Permissions.updateTrip,
    Permissions.updateVehicle,
    Permissions.uploadDocument,
    Permissions.viewAnalytics,
    Permissions.canManageUsers,
    Permissions.canViewCompanySettings,
    Permissions.canManageCompanySettings,
  },
  UserRole.admin: <Permission>{
    Permissions.cancelDispatch,
    Permissions.cancelInvoice,
    Permissions.createClient,
    Permissions.createDispatch,
    Permissions.createDriver,
    Permissions.createInvoice,
    Permissions.createProforma,
    Permissions.createReceipt,
    Permissions.createTrip,
    Permissions.createVehicle,
    Permissions.deleteClient,
    Permissions.deleteDocument,
    Permissions.deleteDriver,
    Permissions.deleteTrip,
    Permissions.deleteVehicle,
    Permissions.emailDocument,
    Permissions.exportData,
    Permissions.finalizeInvoice,
    Permissions.generateCmr,
    Permissions.generatePayments,
    Permissions.mergeClients,
    Permissions.scheduleMaintenance,
    Permissions.sendEmail,
    Permissions.updateClient,
    Permissions.updateDriver,
    Permissions.updateProforma,
    Permissions.updateReceipt,
    Permissions.updateTrip,
    Permissions.updateVehicle,
    Permissions.uploadDocument,
    Permissions.viewAnalytics,
    Permissions.canManageUsers,
    Permissions.canViewCompanySettings,
    Permissions.canManageCompanySettings,
  },
};

/// Immutable permission snapshot for the current session.
class PermissionState {
  const PermissionState(this._allowed);

  /// The set of permissions granted to the current user.
  final Set<Permission> _allowed;

  /// Whether the current user holds [permission].
  bool can(Permission permission) => _allowed.contains(permission);

  /// Whether the current user holds *any* of [permissions].
  bool canAny(Set<Permission> permissions) => permissions.any(can);

  /// The full set of granted permissions (unmodifiable view).
  Set<Permission> get allowed => Set.unmodifiable(_allowed);
}

/// Derives the current [PermissionState] from the live user role.
///
/// Watches [currentUserProvider]; unknown/missing roles resolve to an empty
/// (or minimal) permission set — never an exception.
final permissionProvider = Provider<PermissionState>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const PermissionState(<Permission>{});
  }
  final role = userRoleFromString(user.role);
  final allowed = permissionsByRole[role] ?? const <Permission>{};
  return PermissionState(allowed);
});

/// Reactive widget guard (blueprint §8.2).
///
/// Rebuilds whenever the permission set changes: renders [builder] only when
/// the current user holds [permission], otherwise renders
/// `SizedBox.shrink()`.
Widget buildIfPermitted(
  WidgetRef ref,
  Permission permission,
  Widget Function() builder,
) {
  return ref.watch(permissionProvider).can(permission)
      ? builder()
      : const SizedBox.shrink();
}

/// Imperative permission check for non-widget code.
///
/// Reads the current [permissionProvider] state once (no rebuild).
bool hasPermission(WidgetRef ref, Permission permission) {
  return ref.read(permissionProvider).can(permission);
}
