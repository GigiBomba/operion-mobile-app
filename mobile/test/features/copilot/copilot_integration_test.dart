import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/copilot_endpoints.dart';
import 'package:operion_mobile/features/copilot/models/copilot_models.dart';

/// Creates an [ApiClient] that resolves every request with a canned response.
ApiClient _fakeClient(Response Function() onResponse) {
  final client = ApiClient.create(
    baseUrl: 'https://test.com',
    getAccessToken: () async => null,
  );
  client.dio.interceptors.clear();
  client.dio.interceptors.add(QueuedInterceptorsWrapper(
    onRequest: (options, handler) {
      handler.resolve(onResponse());
    },
  ));
  return client;
}

/// Creates an [ApiClient] that throws a [DioException] on every request.
ApiClient _failingClient({
  int statusCode = 500,
  String? message,
}) {
  final client = ApiClient.create(
    baseUrl: 'https://test.com',
    getAccessToken: () async => null,
  );
  client.dio.interceptors.clear();
  client.dio.interceptors.add(QueuedInterceptorsWrapper(
    onRequest: (options, handler) {
      handler.reject(DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: statusCode,
          data: {'error': message ?? 'Internal Server Error'},
        ),
      ));
    },
  ));
  return client;
}

/// Creates an [ApiClient] that captures the request options for inspection.
ApiClient _capturingClient(
    void Function(RequestOptions options) onRequest) {
  final client = ApiClient.create(
    baseUrl: 'https://test.com',
    getAccessToken: () async => null,
  );
  client.dio.interceptors.clear();
  client.dio.interceptors.add(QueuedInterceptorsWrapper(
    onRequest: (options, handler) {
      onRequest(options);
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: <String, dynamic>{'ok': true},
      ));
    },
  ));
  return client;
}

void main() {
  group('CopilotEndpoints — chat', () {
    test('chat sends POST to /api/v1/copilot/chat with utterance', () async {
      RequestOptions? capturedOptions;
      final client = _capturingClient((options) {
        capturedOptions = options;
      });
      final endpoints = CopilotEndpoints(client);

      await endpoints.chat(utterance: 'find trucks');

      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.path, '/api/v1/copilot/chat');
      expect(capturedOptions!.method, 'POST');
      final data = capturedOptions!.data as Map<String, dynamic>;
      expect(data['utterance'], 'find trucks');
      expect(data.containsKey('conversation_id'), false);
      expect(data['language'], 'en');
    });

    test('chat sends conversationId when provided', () async {
      RequestOptions? capturedOptions;
      final client = _capturingClient((options) {
        capturedOptions = options;
      });
      final endpoints = CopilotEndpoints(client);

      await endpoints.chat(utterance: 'find trucks', conversationId: 'conv-1');

      final data = capturedOptions!.data as Map<String, dynamic>;
      expect(data['conversation_id'], 'conv-1');
    });

    test('chat returns CopilotResponse on success', () async {
      final client = _fakeClient(() => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {
          'conversation_id': 'conv-success',
          'summary_key': 'copilot.summary.done',
        },
      ));
      final endpoints = CopilotEndpoints(client);

      final result = await endpoints.chat(utterance: 'find trucks');

      expect(result, isA<CopilotResponse>());
      expect(result.conversationId, 'conv-success');
      expect(result.summaryKey, 'copilot.summary.done');
    });

    test('chat throws on server error', () async {
      final client = _failingClient(statusCode: 500, message: 'Server error');
      final endpoints = CopilotEndpoints(client);

      expect(
        () => endpoints.chat(utterance: 'find trucks'),
        throwsA(isA<DioException>()),
      );
    });

    test('chat throws on network error', () async {
      final client = _failingClient(statusCode: 0); // network error
      final endpoints = CopilotEndpoints(client);

      expect(
        () => endpoints.chat(utterance: 'find trucks'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('CopilotEndpoints — plans', () {
    test('confirmPlan sends POST to /api/v1/copilot/plans/{id}/confirm',
        () async {
      RequestOptions? capturedOptions;
      final client = _capturingClient((options) {
        capturedOptions = options;
      });
      final endpoints = CopilotEndpoints(client);

      await endpoints.confirmPlan('plan-1', null);

      expect(capturedOptions!.path, '/api/v1/copilot/plans/plan-1/confirm');
      expect(capturedOptions!.method, 'POST');
    });

    test('confirmPlan sends confirmation_phrase in body', () async {
      Map<String, dynamic>? requestBody;
      final client = _fakeClient(() => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {'status': 'completed'},
      ));
      client.dio.interceptors.clear();
      client.dio.interceptors.add(QueuedInterceptorsWrapper(
        onRequest: (options, handler) {
          requestBody = options.data as Map<String, dynamic>?;
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'status': 'completed'},
          ));
        },
      ));
      final endpoints = CopilotEndpoints(client);

      await endpoints.confirmPlan('plan-1', null,
          confirmationPhrase: 'I understand');

      expect(requestBody, isNotNull);
      expect(requestBody!['confirmation_phrase'], 'I understand');
    });

    test('confirmPlan sends null body when no phrase', () async {
      dynamic requestBody;
      final client = _fakeClient(() => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {'status': 'completed'},
      ));
      client.dio.interceptors.clear();
      client.dio.interceptors.add(QueuedInterceptorsWrapper(
        onRequest: (options, handler) {
          requestBody = options.data;
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'status': 'completed'},
          ));
        },
      ));
      final endpoints = CopilotEndpoints(client);

      await endpoints.confirmPlan('plan-1', null);

      expect(requestBody, isNull);
    });

    test('confirmPlan throws on error', () async {
      final client = _failingClient(statusCode: 403);
      final endpoints = CopilotEndpoints(client);

      expect(
        () => endpoints.confirmPlan('plan-1', null),
        throwsA(isA<DioException>()),
      );
    });

    test('cancelPlan sends POST to /api/v1/copilot/plans/{id}/cancel',
        () async {
      RequestOptions? capturedOptions;
      final client = _capturingClient((options) {
        capturedOptions = options;
      });
      final endpoints = CopilotEndpoints(client);

      await endpoints.cancelPlan('plan-1');

      expect(capturedOptions!.path, '/api/v1/copilot/plans/plan-1/cancel');
      expect(capturedOptions!.method, 'POST');
    });

    test('cancelPlan throws on error', () async {
      final client = _failingClient(statusCode: 500);
      final endpoints = CopilotEndpoints(client);

      expect(
        () => endpoints.cancelPlan('plan-1'),
        throwsA(isA<DioException>()),
      );
    });
  });
}
