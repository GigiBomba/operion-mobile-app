/// Centralised conflict resolution for offline-queued actions that are
/// rejected by the server.
///
/// Operion follows a **server-wins** strategy: when a queued PATCH/POST
/// targets a resource whose state has diverged (e.g. a transport was already
/// reassigned by another dispatcher), the server response takes precedence
/// and the local action is discarded.
///
/// Each method returns a user-facing message (in Romanian, the app's primary
/// locale) explaining what happened so the UI can show a non-intrusive toast
/// or snackbar.
class ConflictHandler {
  ConflictHandler._();

  /// Called when an attempt to change a transport's status is rejected
  /// because the current server-side status differs.
  ///
  /// Example: a driver taps "Delivered" while the transport was already
  /// marked "Cancelled" server-side.
  static String resolveStatusConflict(
    String transportId,
    String attemptedStatus,
    String currentStatus,
  ) {
    return 'Transportul $transportId are deja statusul "$currentStatus". '
        'Actualizarea la "$attemptedStatus" nu a fost posibilă. '
        'Datele au fost reîmprospătate.';
  }

  /// Called when a reassign action is rejected because the transport had
  /// already been reassigned to a different driver.
  static String resolveReassignConflict(
    String transportId,
    String attemptedDriver,
  ) {
    return 'Transportul $transportId a fost deja realocat altui șofer. '
        'Acțiunea ta a fost anulată.';
  }

  /// Generic message for an expired or invalid action.
  ///
  /// [actionDescription] is a short label like "Schimbare status" or
  /// "Atribuire șofer".
  static String resolveExpiredAction(String actionDescription) {
    return 'Acțiunea "$actionDescription" nu mai este valabilă. '
        'Datele s-au modificat între timp.';
  }

  /// Called when an edit of a truck (updateTruck) is rejected because the
  /// server's version is newer than the local queued action's baseline —
  /// server-wins: the local edit is discarded and the message tells the user
  /// when the truck was last changed by someone else.
  ///
  /// Blueprint §7: "Camionul TM-123 a fost modificat de altcineva …".
  static String resolveTruckEditConflict(
    String truckId,
    DateTime serverUpdatedAt,
  ) {
    return 'Camionul $truckId a fost modificat de un alt utilizator la '
        '${_formatDateTime(serverUpdatedAt)}. '
        'Modificările tale nu au fost aplicate — datele au fost reîmprospătate.';
  }

  /// Called when an edit of a driver (updateDriver) is rejected because the
  /// server's version is newer than the local queued action's baseline —
  /// server-wins, same pattern as [resolveTruckEditConflict].
  static String resolveDriverEditConflict(
    String driverName,
    DateTime serverUpdatedAt,
  ) {
    return 'Șoferul $driverName a fost modificat de un alt utilizator la '
        '${_formatDateTime(serverUpdatedAt)}. '
        'Modificările tale nu au fost aplicate — datele au fost reîmprospătate.';
  }

  /// Called when an edit of a client (updateClient) is rejected because the
  /// server's version is newer than the local queued action's baseline —
  /// server-wins, same pattern as [resolveTruckEditConflict].
  static String resolveClientEditConflict(
    String clientName,
    DateTime serverUpdatedAt,
  ) {
    return 'Clientul $clientName a fost modificat de un alt utilizator la '
        '${_formatDateTime(serverUpdatedAt)}. '
        'Modificările tale nu au fost aplicate — datele au fost reîmprospătate.';
  }

  /// Called when an invoice transition (finalize/cancel) is rejected because
  /// the invoice already reached a different status server-side.
  ///
  /// Server-wins: the queued transition is discarded — never silently retried
  /// against stale state (blueprint §7).
  static String resolveInvoiceTransitionConflict(
    String invoiceNumber,
    String currentStatus,
  ) {
    return 'Factura $invoiceNumber are deja statusul "$currentStatus". '
        'Tranziția nu a fost posibilă — datele au fost reîmprospătate.';
  }

  /// Formats [value] for user-facing conflict messages (local time,
  /// dd/MM/yyyy HH:mm) — same convention as the document-center and
  /// freight-load screens.
  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} $h:$m';
  }
}
