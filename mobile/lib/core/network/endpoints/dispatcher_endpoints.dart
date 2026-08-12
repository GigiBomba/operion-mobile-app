import 'package:dio/dio.dart';

import '../api_client.dart';

/// Endpoint methods for dispatcher-related API calls.
class DispatcherEndpoints {
  final ApiClient client;

  DispatcherEndpoints(this.client);

  /// Fetch the dispatcher overview dashboard data.
  ///
  /// Since §2 parity the payload also carries `revenue_trend`
  /// (last-6-months `[{month, revenue}]`) and `recent_activity`
  /// (`[{type: 'trip'|'alert', id, title, created_at}]`); the client parses
  /// both defensively (absent/null → empty).
  Future<Response> getOverview() => client.get('/api/v1/mobile/dispatcher/overview');

  /// Fetch the live fleet positions.
  Future<Response> getFleet() => client.get('/api/v1/mobile/dispatcher/fleet');

  /// Fetch all active jobs (backend default terminal-status exclusion).
  ///
  /// Signature intentionally unchanged from §1 so existing stubs/overrides
  /// keep compiling; the §2 status-filtered variant is [getJobsWithStatuses].
  Future<Response> getJobs() => client.get('/api/v1/mobile/dispatcher/jobs');

  /// Fetch jobs restricted to [statuses] (the §2 `statuses` comma-list param).
  ///
  /// Unlike [getJobs] the backend default exclusion is REPLACED — the Kanban
  /// board passes `Planned,Loading,In Transit,Delivered` so Delivered jobs
  /// appear. Each returned item carries `start_date` / `end_date`
  /// (ISO-8601, nullable) in addition to the §1 job fields.
  Future<Response> getJobsWithStatuses(List<String> statuses) => client.get(
        '/api/v1/mobile/dispatcher/jobs',
        queryParameters: statuses.isEmpty ? null : {'statuses': statuses.join(',')},
      );

  /// Fetch all drivers.
  ///
  /// An optional [cancelToken] ties the request to a provider/widget
  /// lifecycle — navigating away cancels the in-flight call (§1.2).
  /// [expiringWithinDays] narrows the response to drivers whose license
  /// expires within that window (Phase 1B, §4.2).
  Future<Response> getDrivers({
    CancelToken? cancelToken,
    int? expiringWithinDays,
  }) =>
      client.get(
        '/api/v1/mobile/dispatcher/drivers',
        queryParameters: expiringWithinDays != null
            ? {'expiring_within_days': expiringWithinDays}
            : null,
        cancelToken: cancelToken,
      );

  /// Fetch a single company-scoped driver (license data, contact info).
  ///
  /// `GET /api/v1/drivers/{driverId}` returns `DriverResponse` with
  /// `license_number`, `license_category`, `license_expiry`,
  /// `medical_expiry` plus contact/status fields. The company scope is
  /// derived from the JWT server-side; a foreign driver id yields 404.
  Future<Response> getDriverDetail(
    int driverId, {
    CancelToken? cancelToken,
  }) =>
      client.get('/api/v1/drivers/$driverId', cancelToken: cancelToken);

  /// Fetch all alerts.
  Future<Response> getAlerts() => client.get('/api/v1/mobile/dispatcher/alerts');

  /// Approve an action identified by [id].
  Future<Response> approveAction(String id) =>
      client.post('/api/v1/mobile/dispatcher/approvals/$id/approve');

  /// Reject an action identified by [id] with an optional [reason].
  Future<Response> rejectAction(String id, {String? reason}) =>
      client.post('/api/v1/mobile/dispatcher/approvals/$id/reject',
          data: {'reason': reason});

  /// Reassign [transportId] to a different driver identified by [driverId].
  Future<Response> reassignTransport(String transportId, String driverId) =>
      client.post('/api/v1/mobile/dispatcher/jobs/$transportId/reassign',
          data: {'driver_id': driverId});

  /// Update the [status] of a transport identified by [transportId].
  ///
  /// `PATCH /api/v1/mobile/transports/{transport_id}/status` with
  /// `{'status': status}` — the same contract as the driver app's
  /// `DriverEndpoints.updateStatus`; mirrored here so the dispatcher Kanban
  /// board does not depend on the driver feature module.
  Future<Response> updateTransportStatus(String transportId, String status) =>
      client.patch('/api/v1/mobile/transports/$transportId/status',
          data: {'status': status});
}
