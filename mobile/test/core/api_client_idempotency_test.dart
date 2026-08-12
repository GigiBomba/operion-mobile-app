import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';

/// Captures request options and resolves requests instantly (mirrors the
/// mock-interceptor pattern used in api_endpoints_test.dart).
class _MockInterceptor extends Interceptor {
  final void Function(RequestOptions) onRequestCallback;

  _MockInterceptor({required this.onRequestCallback});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    onRequestCallback(options);
    handler.resolve(Response(
      requestOptions: options,
      data: {'status': 'ok'},
      statusCode: 200,
    ));
  }
}

ApiClient _createMockClient(void Function(RequestOptions) onRequest) {
  final client = ApiClient.create(
    baseUrl: 'https://api.test.com',
    getAccessToken: () async => null,
    getRefreshToken: () async => null,
    saveTokens: (_, _) async {},
    clearTokens: () async {},
  );
  // Remove all production interceptors (logging + auth) and add the mock.
  client.dio.interceptors
    ..clear()
    ..add(_MockInterceptor(onRequestCallback: onRequest));
  return client;
}

void main() {
  group('generateIdempotencyKey', () {
    test('returns a non-empty string', () {
      expect(generateIdempotencyKey(), isNotEmpty);
    });

    test('returns unique values on consecutive calls', () {
      final a = generateIdempotencyKey();
      final b = generateIdempotencyKey();
      expect(a, isNot(equals(b)));
    });
  });

  group('ApiClient.postWithIdempotencyKey', () {
    test('attaches an Idempotency-Key header to the request', () async {
      RequestOptions? captured;
      final client = _createMockClient((opts) {
        captured = opts;
      });

      await client.postWithIdempotencyKey('/api/v1/orders', data: {'x': 1});

      expect(captured, isNotNull);
      expect(captured!.method, equals('POST'));
      expect(captured!.path, equals('/api/v1/orders'));
      final key = captured!.headers['Idempotency-Key'];
      expect(key, isNotNull);
      expect(key, isNotEmpty);
    });

    test('forwards the body and query parameters unchanged', () async {
      RequestOptions? captured;
      final client = _createMockClient((opts) {
        captured = opts;
      });

      await client.postWithIdempotencyKey(
        '/api/v1/orders',
        data: {'status': 'shipped'},
        queryParameters: {'dry_run': 'true'},
      );

      expect((captured!.data as Map)['status'], equals('shipped'));
      expect(captured!.queryParameters, containsPair('dry_run', 'true'));
    });

    test('does not leak the idempotency header onto plain post()', () async {
      RequestOptions? captured;
      final client = _createMockClient((opts) {
        captured = opts;
      });

      await client.post('/api/v1/orders', data: {'x': 1});

      expect(captured!.headers['Idempotency-Key'], isNull);
    });
  });
}
