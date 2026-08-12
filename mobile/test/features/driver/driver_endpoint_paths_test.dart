// ---------------------------------------------------------------------------
// driver_endpoint_paths_test.dart — B6/B9
//
// Asserts the corrected `/api/v1` prefixes for the driver feature endpoints:
//   1. userProfileProvider GETs  /api/v1/mobile/user/profile
//   2. expensesProvider  GETs  /api/v1/mobile/driver/expenses
//   3. NewExpenseScreen submit POSTs /api/v1/mobile/driver/expenses
//   4. DriverProfileScreen save PATCHes /api/v1/mobile/user/profile
// and the B9 guard: expensesProvider rethrows auth rejections (401) instead of
// swallowing them into an empty list.
// ---------------------------------------------------------------------------

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/auth/biometric_service.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/storage/secure_token_store.dart';
import 'package:operion_mobile/features/driver/expenses/expense_providers.dart';
import 'package:operion_mobile/features/driver/expenses/new_expense_screen.dart';
import 'package:operion_mobile/features/driver/profile/driver_profile_providers.dart';
import 'package:operion_mobile/features/driver/profile/driver_profile_screen.dart';

/// Resolves every request instantly and records it for assertions.
class _RecordingInterceptor extends Interceptor {
  final List<RequestOptions> requests = [];
  final int statusCode;
  final dynamic responseData;

  _RecordingInterceptor({this.statusCode = 200, this.responseData});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    handler.resolve(Response(
      requestOptions: options,
      statusCode: statusCode,
      data: responseData ?? {'status': 'ok'},
    ));
  }
}

ApiClient _client(_RecordingInterceptor interceptor) {
  final client = ApiClient.create(
    baseUrl: 'https://api.test.com',
    getAccessToken: () async => null,
  );
  client.dio.interceptors
    ..clear()
    ..add(interceptor);
  return client;
}

class _MockSecureTokenStore extends SecureTokenStore {
  @override
  Future<bool> hasTokens() async => false;
  @override
  Future<String?> getAccessToken() async => null;
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<void> saveTokens(String a, String r) async {}
  @override
  Future<void> clearTokens() async {}
}

class _MockBiometricService extends BiometricService {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<bool> authenticate({required String reason}) async => false;
}

Map<String, dynamic> _profileData() => {
      'id': 'u1',
      'fullName': 'Mihai Popescu',
      'email': 'mihai@test.com',
      'phone': '+40-700-000-000',
      'role': 'driver',
      'documents': <dynamic>[],
    };

void main() {
  group('Driver endpoint paths — /api/v1 prefix (B6)', () {
    test('userProfileProvider GETs /api/v1/mobile/user/profile', () async {
      final interceptor =
          _RecordingInterceptor(responseData: <String, dynamic>{'id': 'u1'});
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(_client(interceptor)),
      ]);
      addTearDown(container.dispose);

      await container.read(userProfileProvider.future);

      expect(interceptor.requests.single.method, 'GET');
      expect(
        interceptor.requests.single.path,
        '/api/v1/mobile/user/profile',
      );
    });

    test('expensesProvider GETs /api/v1/mobile/driver/expenses', () async {
      final interceptor = _RecordingInterceptor(responseData: <dynamic>[]);
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(_client(interceptor)),
      ]);
      addTearDown(container.dispose);

      await container.read(expensesProvider.future);

      expect(interceptor.requests.single.method, 'GET');
      expect(
        interceptor.requests.single.path,
        '/api/v1/mobile/driver/expenses',
      );
    });

    testWidgets('NewExpenseScreen submit POSTs /api/v1/mobile/driver/expenses',
        (tester) async {
      final interceptor = _RecordingInterceptor();
      final overrides = <Override>[
        apiClientProvider.overrideWithValue(_client(interceptor)),
        secureTokenStoreProvider.overrideWithValue(_MockSecureTokenStore()),
        biometricServiceProvider.overrideWithValue(_MockBiometricService()),
        currentUserProvider.overrideWith((ref) => null),
      ];
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          localizationsDelegates: [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: NewExpenseScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '100');
      await tester.tap(find.textContaining('ubmit'));
      await tester.pumpAndSettle();

      expect(
        interceptor.requests.any((r) =>
            r.method == 'POST' &&
            r.path == '/api/v1/mobile/driver/expenses'),
        isTrue,
      );
    });

    testWidgets('DriverProfileScreen save PATCHes /api/v1/mobile/user/profile',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final interceptor = _RecordingInterceptor();
      final overrides = <Override>[
        apiClientProvider.overrideWithValue(_client(interceptor)),
        secureTokenStoreProvider.overrideWithValue(_MockSecureTokenStore()),
        biometricServiceProvider.overrideWithValue(_MockBiometricService()),
        userProfileProvider.overrideWith((ref) async => _profileData()),
      ];
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          localizationsDelegates: [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DriverProfileScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.pencil));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        interceptor.requests.any((r) =>
            r.method == 'PATCH' &&
            r.path == '/api/v1/mobile/user/profile'),
        isTrue,
      );
    });
  });

  group('expensesProvider — auth rejection guard (B9)', () {
    test('rethrows a 401 instead of returning an empty list', () async {
      final client = ApiClient.create(
        baseUrl: 'https://api.test.com',
        getAccessToken: () async => null,
      );
      client.dio.interceptors
        ..clear()
        ..add(InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 401,
                data: {'detail': 'unauthorized'},
              ),
            ));
          },
        ));
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(client),
      ]);
      addTearDown(container.dispose);

      await expectLater(
        container.read(expensesProvider.future),
        throwsA(isA<DioException>()),
      );
    });
  });
}
