import 'package:dio/dio.dart';

import '../../../features/copilot/models/copilot_models.dart';
import '../api_client.dart';

/// Endpoints for the AI Co-Pilot API (§30).
///
/// All endpoints sit under /api/v1/copilot/* and require JWT auth.
class CopilotEndpoints {
  final ApiClient _client;

  CopilotEndpoints(this._client);

  // ── Chat (§16, §30) ───────────────────────────────────────────────────

  /// Submit a text utterance through the Co-Pilot pipeline.
  Future<CopilotResponse> chat({
    required String utterance,
    String? conversationId,
    String language = 'en',
    CancelToken? cancelToken,
  }) async {
    final response = await _client.dio.post(
      '/api/v1/copilot/chat',
      data: {
        'utterance': utterance,
        if (conversationId != null) 'conversation_id': conversationId,
        'language': language,
      },
      cancelToken: cancelToken,
    );
    return CopilotResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  // ── Plans (§7, §12.1, §30) ────────────────────────────────────────────

  /// Confirm and execute a plan awaiting confirmation.
  ///
  /// For Level 3 confirmation, pass the typed [confirmationPhrase].
  Future<Map<String, dynamic>> confirmPlan(
    String planId,
    CancelToken? cancelToken, {
    String? confirmationPhrase,
  }) async {
    final data = <String, dynamic>{};
    if (confirmationPhrase != null) {
      data['confirmation_phrase'] = confirmationPhrase;
    }
    final response = await _client.dio.post(
      '/api/v1/copilot/plans/$planId/confirm',
      data: data.isNotEmpty ? data : null,
      cancelToken: cancelToken,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Cancel an in-flight plan.
  Future<Map<String, dynamic>> cancelPlan(String planId) async {
    final response = await _client.post(
      '/api/v1/copilot/plans/$planId/cancel',
    );
    return response.data as Map<String, dynamic>;
  }
}
