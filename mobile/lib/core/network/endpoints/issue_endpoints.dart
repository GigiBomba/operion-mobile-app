import 'package:dio/dio.dart';

import '../api_client.dart';

/// Endpoint methods for async issue reporting / support threads.
///
/// Blueprint §41.2 / §41.3e: clients never call the ops support service
/// directly - every call goes through the backend proxy, which resolves
/// `company_id` / `customer_id` from the JWT.
///
/// Payload contract for [submitIssue]:
/// `{conversation_id?, message, channel, environment}`. `environment` is
/// required for mobile so newly created tickets are routed to the mobile repo
/// (W8/W9); it only matters on the first message of a conversation, but is
/// sent on every message so a resumed thread is unambiguous.
class IssueEndpoints {
  final ApiClient client;

  IssueEndpoints(this.client);

  /// Public support proxy base path (blueprint §41.2).
  ///
  /// The proxy router is mounted under the shared `/api/v1` prefix
  /// (`backend/api/v1/router.py`), exactly like every other mobile endpoint.
  static const String supportBasePath = '/api/v1/support';

  static const String mobileEnvironment = 'mobile';
  static const String inAppChannel = 'in_app';

  /// Submit an issue report or continue an existing conversation.
  ///
  /// [conversationId] is omitted for a new report and included to append to
  /// an existing one. [channel] is `in_app` for desktop/mobile async reports
  /// (§41.3b). The screenshot attachment is uploaded separately through the
  /// existing document-upload endpoint (see `ReportIssueController`).
  Future<Response> submitIssue({
    String? conversationId,
    required String message,
    String channel = inAppChannel,
    String environment = mobileEnvironment,
  }) {
    final data = <String, dynamic>{
      'message': message,
      'channel': channel,
      'environment': environment,
      if (conversationId != null && conversationId.trim().isNotEmpty)
        'conversation_id': conversationId.trim(),
    };
    return client.post('$supportBasePath/messages', data: data);
  }

  /// Read one report thread: status, entries and reply flags.
  Future<Response> getThread(String conversationId) {
    final encoded = Uri.encodeComponent(conversationId.trim());
    return client.get('$supportBasePath/threads/$encoded');
  }

  /// Answer a clarifying question on an existing report thread.
  Future<Response> replyToThread(String conversationId, String message) {
    final encoded = Uri.encodeComponent(conversationId.trim());
    return client.post(
      '$supportBasePath/threads/$encoded/reply',
      data: {'message': message},
    );
  }
}
