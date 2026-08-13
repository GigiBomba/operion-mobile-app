import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/auth/biometric_service.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/storage/secure_token_store.dart';
import 'package:operion_mobile/features/dispatcher/home/dispatcher_home_screen.dart';
import 'package:operion_mobile/features/dispatcher/home/dispatcher_providers.dart';
import '../helpers/golden_fonts.dart';

class _MockSecureTokenStore extends SecureTokenStore {
  @override
  Future<bool> hasTokens() async => false;
  @override
  Future<String?> getAccessToken() async => null;
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<void> saveTokens(String access, String refresh) async {}
  @override
  Future<void> clearTokens() async {}
}

class _MockBiometricService extends BiometricService {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<bool> authenticate({required String reason}) async => false;
}

ApiClient _stubApiClient() => ApiClient.create(
      baseUrl: '',
      apiKey: 'test-key',
      getAccessToken: () async => null,
    );

/// Fixed reference for relative-time rows â€” regenerated per run so the golden
/// is stable on any machine/date.
final DateTime _now = DateTime.now();

List<Override> _overrides() => [
      secureTokenStoreProvider.overrideWithValue(_MockSecureTokenStore()),
      biometricServiceProvider.overrideWithValue(_MockBiometricService()),
      apiClientProvider.overrideWithValue(_stubApiClient()),
      dispatcherTabProvider.overrideWith((ref) => 0),
      dispatcherAlertsProvider
          .overrideWith((ref) async => <Map<String, dynamic>>[]),
      dispatcherOverviewProvider.overrideWith((ref) async => {
            'activeJobs': 5,
            'activeDrivers': 12,
            'openAlerts': 3,
            'vehiclesOnRoad': 8,
            'lastUpdated': _now.subtract(const Duration(minutes: 3)).toIso8601String(),
            'revenue_trend': [
              {'month': '2026-02', 'revenue': 12000},
              {'month': '2026-03', 'revenue': 15000},
              {'month': '2026-04', 'revenue': 11000},
              {'month': '2026-05', 'revenue': 18000},
              {'month': '2026-06', 'revenue': 22000},
              {'month': '2026-07', 'revenue': 19500},
            ],
            'recent_activity': [
              {
                'type': 'trip',
                'id': 11,
                'title': 'Trip B-01-ABC completed',
                'created_at': _now.subtract(const Duration(minutes: 4)).toIso8601String(),
              },
              {
                'type': 'alert',
                'id': 3,
                'title': 'Vehicle 7 overdue for service',
                'created_at': _now.subtract(const Duration(minutes: 50)).toIso8601String(),
              },
              {
                'type': 'trip',
                'id': 12,
                'title': 'Trip B-02-XYZ dispatched',
                'created_at': _now.subtract(const Duration(hours: 2)).toIso8601String(),
              },
            ],
          }),
    ];

Widget _app(Brightness brightness) {
  return ProviderScope(
    overrides: _overrides(),
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const DispatcherHomeScreen(),
    ),
  );
}

Future<void> _pumpGolden(
  WidgetTester tester,
  Brightness brightness,
  String file,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(brightness));
  await tester.pumpAndSettle();
  await expectLater(find.byType(Scaffold), matchesGoldenFile(file));
}

void main() {
  setUpAll(loadGoldenFonts);
  testWidgets('DispatcherHomeScreen golden (light) â€” Â§2 parity', (tester) async {
    await _pumpGolden(tester, Brightness.light, 'dispatcher_home_light.png');
  });

  testWidgets('DispatcherHomeScreen golden (dark) â€” Â§2 parity', (tester) async {
    await _pumpGolden(tester, Brightness.dark, 'dispatcher_home_dark.png');
  });
}