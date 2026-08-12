import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../network/endpoints/issue_endpoints.dart';

/// Shared [IssueEndpoints] wired to the global [ApiClient].
final issueEndpointsProvider = Provider<IssueEndpoints>((ref) {
  return IssueEndpoints(ref.read(apiClientProvider));
});
