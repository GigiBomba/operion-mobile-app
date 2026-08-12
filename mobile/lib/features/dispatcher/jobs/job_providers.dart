import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/dispatcher_providers.dart';

/// Fetches dispatcher jobs restricted to the given [statuses].
///
/// Unlike [dispatcherJobsProvider] (which relies on the backend's default
/// terminal-status exclusion) this sends the §2 `statuses` comma-list param
/// which **replaces** the default exclusion. The Kanban board uses it to
/// include Delivered jobs: `Planned,Loading,In Transit,Delivered`.
final dispatcherJobsWithStatusesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, List<String>>(
        (ref, statuses) async {
  final endpoints = ref.watch(dispatcherEndpointsProvider);
  final response = await endpoints.getJobsWithStatuses(statuses);
  final data = response.data;
  if (data is! List) return [];
  return data.cast<Map<String, dynamic>>();
});

/// Fetches a single job by [jobId] from the cached jobs list.
///
/// Since [DispatcherEndpoints] does not expose a `getJob(id)` endpoint, this
/// provider reads from [dispatcherJobsProvider] and filters locally.
///
/// Returns an empty map when the job is not found; callers should handle
/// missing data gracefully.
final jobDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, jobId) async {
  final jobs = ref.watch(dispatcherJobsProvider).value;
  if (jobs == null) {
    return (await ref.read(dispatcherJobsProvider.future)).firstWhere(
      (j) {
        final id = j['id'];
        if (id is int) return id == jobId;
        if (id is String) return int.tryParse(id) == jobId;
        return false;
      },
      orElse: () => <String, dynamic>{},
    );
  }
  return jobs.firstWhere(
    (j) {
      final id = j['id'];
      if (id is int) return id == jobId;
      if (id is String) return int.tryParse(id) == jobId;
      return false;
    },
    orElse: () => <String, dynamic>{},
  );
});

/// Tracks whether a reassign API call is currently in-flight.
///
/// Set to `true` while [DispatcherEndpoints.reassignTransport] is executing
/// and reset to `false` on completion (success or error).
final reassigningProvider = StateProvider<bool>((ref) => false);
