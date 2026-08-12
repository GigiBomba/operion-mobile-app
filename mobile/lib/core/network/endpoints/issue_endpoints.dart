import 'package:dio/dio.dart';

import '../api_client.dart';

/// Endpoint methods for issue reporting / support requests.
class IssueEndpoints {
  final ApiClient client;

  IssueEndpoints(this.client);

  /// Submit a support/issue ticket via the in-app channel.
  Future<Response> submitIssue({
    required String subject,
    required String description,
  }) =>
      client.post('/api/v1/support/messages', data: {
        'channel': 'in_app',
        'subject': subject,
        'description': description,
      });
}
