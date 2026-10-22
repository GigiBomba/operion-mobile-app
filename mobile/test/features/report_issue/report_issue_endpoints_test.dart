import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/issue_endpoints.dart';

/// Mock interceptor that captures the outgoing request and resolves instantly
/// (same harness as `test/core/api_endpoints_test.dart`).
class _MockInterceptor extends Interceptor {
  _MockInterceptor(this._capture, this.responseData);

  final void Function(RequestOptions) _capture;
  final Map<String, dynamic> responseData;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _capture(options);
    handler.resolve(
      Response(requestOptions: options, data: responseData, statusCode: 200),
    );
  }
}

IssueEndpoints _endpoints(
  void Function(RequestOptions) onRequest, {
  Map<String, dynamic>? responseData,
}) {
  final client = ApiClient.create(
    baseUrl: 'https://api.test.com',
    getAccessToken: () async => null,
    getRefreshToken: () async => null,
    saveTokens: (_, _) async {},
    clearTokens: () async {},
  );
  client.dio.interceptors
    ..clear()
    ..add(
      _MockInterceptor(
        onRequest,
        responseData ?? <String, dynamic>{'status': 'ok'},
      ),
    );
  return IssueEndpoints(client);
}

void main() {
  group('IssueEndpoints submit contract', () {
    test('new report posts message/channel/environment to the proxy', () async {
      late RequestOptions captured;
      final endpoints = _endpoints((options) => captured = options);

      await endpoints.submitIssue(message: 'Invoices crash on save');

      expect(captured.method, equals('POST'));
      expect(captured.path, equals('/api/v1/support/messages'));
      final data = captured.data as Map<String, dynamic>;
      expect(data['message'], equals('Invoices crash on save'));
      expect(data['channel'], equals('in_app'));
      expect(data['environment'], equals('mobile'));
      expect(data.containsKey('conversation_id'), isFalse);
    });

    test('resuming a thread includes conversation_id', () async {
      late RequestOptions captured;
      final endpoints = _endpoints((options) => captured = options);

      await endpoints.submitIssue(
        conversationId: 'conv-42',
        message: 'It still happens after the update',
      );

      final data = captured.data as Map<String, dynamic>;
      expect(data['conversation_id'], equals('conv-42'));
      expect(data['message'], equals('It still happens after the update'));
      expect(data['environment'], equals('mobile'));
    });

    test('blank conversation_id is omitted', () async {
      late RequestOptions captured;
      final endpoints = _endpoints((options) => captured = options);

      await endpoints.submitIssue(conversationId: '   ', message: 'Crash');

      final data = captured.data as Map<String, dynamic>;
      expect(data.containsKey('conversation_id'), isFalse);
    });
  });

  group('IssueEndpoints thread contract', () {
    test('getThread GETs the encoded thread path', () async {
      late RequestOptions captured;
      final endpoints = _endpoints((options) => captured = options);

      await endpoints.getThread('conv 1/2');

      expect(captured.method, equals('GET'));
      expect(captured.path, equals('/api/v1/support/threads/conv%201%2F2'));
    });

    test('replyToThread posts the reply message', () async {
      late RequestOptions captured;
      final endpoints = _endpoints((options) => captured = options);

      await endpoints.replyToThread('conv-42', 'Which screen?');

      expect(captured.method, equals('POST'));
      expect(captured.path, equals('/api/v1/support/threads/conv-42/reply'));
      final data = captured.data as Map<String, dynamic>;
      expect(data['message'], equals('Which screen?'));
    });
  });
}
