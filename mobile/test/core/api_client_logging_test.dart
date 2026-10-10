import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';

/// Verifies the Bug 1 fix: the request/response logging interceptor must be
/// absent in release builds (credentials, PII and the X-API-Key header must
/// never reach the console), and when enabled it must redact sensitive
/// headers and password-like body fields.
void main() {
  ApiClient createClient({bool? enableLogging}) => ApiClient.create(
        baseUrl: 'https://test.example.com',
        getAccessToken: () async => null,
        getRefreshToken: () async => null,
        saveTokens: (_, _) async {},
        clearTokens: () async {},
        enableLogging: enableLogging ?? false,
      );

  group('ApiClient logging guard (Bug 1)', () {
    test('no LogInterceptor when logging is disabled (release behaviour)',
        () {
      final client = createClient(enableLogging: false);
      final hasLogInterceptor =
          client.dio.interceptors.any((i) => i is LogInterceptor);
      expect(hasLogInterceptor, isFalse,
          reason: 'release builds must never log request/response bodies');
    });

    test('LogInterceptor is installed when logging is enabled', () {
      final client = createClient(enableLogging: true);
      final hasLogInterceptor =
          client.dio.interceptors.any((i) => i is LogInterceptor);
      expect(hasLogInterceptor, isTrue);
    });

    test('redacts sensitive headers (Authorization, X-API-Key)', () {
      final headers = RedactingLogInterceptor.redactHeaders({
        'Content-Type': 'application/json',
        'X-API-Key': 'super-secret-key',
        'Authorization': 'Bearer abc.def.ghi',
      });

      expect(headers['X-API-Key'], '[REDACTED]');
      expect(headers['Authorization'], '[REDACTED]');
      expect(headers['Content-Type'], 'application/json');
    });

    test('redacts password-like fields in request bodies (nested too)', () {
      final body = RedactingLogInterceptor.redactBody({
        'username': 'john.doe',
        'password': 'hunter2',
        'nested': {
          'password_confirmation': 'hunter2',
          'refresh_token': 'rt-123',
          'ok': 1,
        },
        'list': [
          {'secret': 's1'},
          'plain',
        ],
      });

      expect(body['password'], '[REDACTED]');
      expect(body['username'], 'john.doe');
      final nested = body['nested'] as Map;
      expect(nested['password_confirmation'], '[REDACTED]');
      expect(nested['refresh_token'], '[REDACTED]');
      expect(nested['ok'], 1);
      final list = body['list'] as List;
      expect((list[0] as Map)['secret'], '[REDACTED]');
      expect(list[1], 'plain');
    });
  });
}