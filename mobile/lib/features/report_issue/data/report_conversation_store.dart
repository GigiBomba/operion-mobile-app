import 'package:shared_preferences/shared_preferences.dart';

/// Persists the active support `conversation_id` per company/customer scope.
///
/// Blueprint 41.3d/e: reopening "Report an Issue" must resume the existing
/// report thread instead of starting a new conversation on every launch. The
/// key is scoped by BOTH `company_id` and the signed-in customer/user id so
/// switching accounts (or a shared device) can never surface another tenant's
/// or another user's report.
///
/// `shared_preferences` is deliberate: the value is a non-secret opaque id
/// (never a token) and must be readable before the encrypted token store is
/// unlocked, e.g. while rendering the More tab badge.
class ReportConversationStore {
  ReportConversationStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  static const String keyPrefix = 'report_issue_conversation_id';

  /// Anonymous fallback scope used only when the session has no ids yet
  /// (first frame after restore). Never mixes with a real scope.
  static const String anonymousScope = 'anonymous';

  final Future<SharedPreferences> Function() _prefs;

  /// Deterministic storage key for a company/user pair.
  static String storageKeyFor({
    required String companyId,
    required String userId,
  }) {
    final company = companyId.trim().isEmpty
        ? anonymousScope
        : companyId.trim();
    final user = userId.trim().isEmpty ? anonymousScope : userId.trim();
    return '$keyPrefix::$company::$user';
  }

  /// Reads the persisted conversation id, or `null` when none is stored.
  Future<String?> read({
    required String companyId,
    required String userId,
  }) async {
    try {
      final prefs = await _prefs();
      final value = prefs.getString(storageKeyFor(
        companyId: companyId,
        userId: userId,
      ));
      final trimmed = value?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    } catch (_) {
      // Storage is best-effort: a first-frame read must never block the UI.
      return null;
    }
  }

  /// Stores [conversationId] for the scope.
  Future<void> write({
    required String companyId,
    required String userId,
    required String conversationId,
  }) async {
    final trimmed = conversationId.trim();
    if (trimmed.isEmpty) return;
    final prefs = await _prefs();
    await prefs.setString(
      storageKeyFor(companyId: companyId, userId: userId),
      trimmed,
    );
  }

  /// Drops the persisted id (resolved report -> "Report a new issue", or a
  /// 404 from the proxy for a thread the backend no longer knows).
  Future<void> clear({
    required String companyId,
    required String userId,
  }) async {
    try {
      final prefs = await _prefs();
      await prefs.remove(
        storageKeyFor(companyId: companyId, userId: userId),
      );
    } catch (_) {
      // Best-effort, same rationale as [read].
    }
  }
}
