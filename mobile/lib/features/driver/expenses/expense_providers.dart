import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/dio_errors.dart';

/// Provider that fetches the list of expenses for the current driver from
/// the `/api/v1/mobile/driver/expenses` endpoint.
///
/// Returns an empty list when the request fails (e.g. no expenses yet or
/// network error). Auth rejections (401/403) are rethrown so the force-logout
/// path runs (I1).
final expensesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(apiClientProvider);
  try {
    final response = await client.get('/api/v1/mobile/driver/expenses');
    final list = response.data as List;
    return list.cast<Map<String, dynamic>>();
  } catch (e) {
    if (isAuthRejection(e)) rethrow;
    // Return empty on any other error (network failure, type mismatch, etc.)
    return <Map<String, dynamic>>[];
  }
});

/// Provides the loading state for the expense submission flow.
///
/// Set to `true` while [NewExpenseScreen] is posting data and back to `false`
/// when the request completes.
final expenseSubmittingProvider = StateProvider<bool>((ref) => false);
