// Settings expansion tests (Phase 4B §4.10).
//
// Covers: 7 sections render + role gating, SMTP masked password placeholder
// (never pre-filled), toggles persist via shared_preferences, test-email action.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/security/biometric_gate.dart';
import 'package:operion_mobile/features/settings/providers/settings_endpoints.dart';
import 'package:operion_mobile/features/settings/providers/settings_providers.dart';
import 'package:operion_mobile/features/settings/settings_screen.dart';
import 'package:operion_mobile/l10n/app_localizations.dart';
import 'package:operion_mobile/shared/models/user.dart';

import '../../support/test_helpers.dart';

const _managerUser = User(
  id: 'm1',
  email: 'manager@operion.ro',
  fullName: 'Manager',
  role: 'manager',
  companyId: 'c1',
);

const _dispatcherUser = User(
  id: 'u1',
  email: 'dispatcher@operion.ro',
  fullName: 'Dispatcher',
  role: 'dispatcher',
  companyId: 'c1',
);

const _companySettings = CompanySettings(
  legalName: 'Operion SRL',
  vatNumber: 'RO123456',
  address: 'Str. Exemplu 1',
  invoiceFooter: 'Multumim!',
  smtpServer: 'smtp.operion.ro',
  smtpPort: '587',
  smtpUser: 'noreply@operion.ro',
  smtpPasswordIsSet: true,
  trackingProvider: 'wialon',
  trackingApiKeyIsSet: true,
  maintenanceAlertDaysAhead: 30,
  tachoWarningDays: 45,
  tachoCriticalDays: 15,
);

class _RecordingSettingsEndpoints extends SettingsEndpoints {
  _RecordingSettingsEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  bool testEmailCalled = false;
  final List<Map<String, dynamic>> patches = [];

  @override
  Future<Response> testEmail({CancelToken? cancelToken}) async {
    testEmailCalled = true;
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'ok': true},
      statusCode: 200,
    );
  }

  @override
  Future<Response> patchCompanySettings(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    patches.add(data);
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {},
      statusCode: 200,
    );
  }
}

Widget _app(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(),
    ),  );
}

List<Override> _baseOverrides(
  _RecordingSettingsEndpoints endpoints, {
  User user = _managerUser,
}) {
  return [
    isOfflineProvider.overrideWith((ref) => false),
    currentUserProvider.overrideWith((ref) => user),
    settingsEndpointsProvider.overrideWithValue(endpoints),
    companySettingsProvider.overrideWith((ref) async => _companySettings),
    biometricGateProvider.overrideWithValue(
      BiometricGate(authenticate: (_) async => true),
    ),
  ];
}

Future<void> _pumpTall(WidgetTester tester, List<Override> overrides) async {
  await tester.binding.setSurfaceSize(const Size(900, 4200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(overrides));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('manager sees all 7 sections', (tester) async {
      usePhoneSurface(tester);
    final endpoints = _RecordingSettingsEndpoints();
    await _pumpTall(tester, _baseOverrides(endpoints));

    final loc = AppLocalizations(const Locale('en'));
    expect(find.text(loc.settings_companyProfile.toUpperCase()), findsOneWidget);
    expect(find.text(loc.settings_smtp.toUpperCase()), findsOneWidget);
    expect(find.text(loc.settings_tracking.toUpperCase()), findsOneWidget);
    expect(find.text(loc.settings_maintenanceThresholds.toUpperCase()),
        findsOneWidget);
    expect(find.text(loc.settings_notifications.toUpperCase()), findsOneWidget);
    expect(find.text(loc.settings_dataUsage.toUpperCase()), findsOneWidget);
    expect(find.text(loc.settings_biometricLock.toUpperCase()), findsOneWidget);
  });

  testWidgets('dispatcher sees only the 3 all-role sections', (tester) async {
      usePhoneSurface(tester);
    final endpoints = _RecordingSettingsEndpoints();
    await _pumpTall(tester,
        _baseOverrides(endpoints, user: _dispatcherUser));

    final loc = AppLocalizations(const Locale('en'));
    // Manager-gated sections absent.
    expect(find.text(loc.settings_companyProfile.toUpperCase()), findsNothing);
    expect(find.text(loc.settings_smtp.toUpperCase()), findsNothing);
    expect(find.text(loc.settings_tracking.toUpperCase()), findsNothing);
    expect(find.text(loc.settings_maintenanceThresholds.toUpperCase()),
        findsNothing);
    // All-role sections present.
    expect(find.text(loc.settings_notifications.toUpperCase()), findsOneWidget);
    expect(find.text(loc.settings_dataUsage.toUpperCase()), findsOneWidget);
    expect(find.text(loc.settings_biometricLock.toUpperCase()), findsOneWidget);
  });

  testWidgets('SMTP password field is masked with placeholder and never '
      'pre-filled', (tester) async {
      usePhoneSurface(tester);
    final endpoints = _RecordingSettingsEndpoints();
    await _pumpTall(tester, _baseOverrides(endpoints));

    final passwordField = find.widgetWithText(TextFormField, 'SMTP password');
    expect(passwordField, findsOneWidget);

    final field = tester.widget<TextFormField>(passwordField);
    expect(field.controller!.text, isEmpty,
        reason: 'A real password must NEVER be pre-filled into the field');

    // Masked + '•••• configured' placeholder (never a real value).
    final textField = tester.widget<TextField>(
      find.descendant(
        of: passwordField,
        matching: find.byType(TextField),
      ),
    );
    expect(textField.obscureText, isTrue,
        reason: 'The password field must stay masked');
    expect(textField.decoration?.hintText, '•••• configured',
        reason: 'The placeholder only advertises that a secret is configured');
  });

  testWidgets('data-usage toggle persists via shared_preferences',
      (tester) async {
      usePhoneSurface(tester);
    final endpoints = _RecordingSettingsEndpoints();
    await _pumpTall(tester, _baseOverrides(endpoints));

    // Toggle Wi-Fi-only ON.
    await tester.tap(find.text('Wi-Fi only for large syncs'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('data_wifi_only_large_syncs'), isTrue);
  });

  testWidgets('previously persisted data-usage toggle is hydrated on load',
      (tester) async {
      usePhoneSurface(tester);
    SharedPreferences.setMockInitialValues({
      'data_wifi_only_large_syncs': true,
    });
    final endpoints = _RecordingSettingsEndpoints();
    await _pumpTall(tester, _baseOverrides(endpoints));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    // The notifier hydrates asynchronously from the mock store.
    await tester.pumpAndSettle();
    expect(container.read(dataUsageProvider).wifiOnlyLargeSyncs, isTrue);
  });

  testWidgets('Send test email invokes the endpoint', (tester) async {
      usePhoneSurface(tester);
    final endpoints = _RecordingSettingsEndpoints();
    await _pumpTall(tester, _baseOverrides(endpoints));

    await tester.ensureVisible(find.text('Send test email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send test email'));
    await tester.pumpAndSettle();

    expect(endpoints.testEmailCalled, isTrue);
  });

  testWidgets('company profile save sends the text fields', (tester) async {
      usePhoneSurface(tester);
    final endpoints = _RecordingSettingsEndpoints();
    await _pumpTall(tester, _baseOverrides(endpoints));

    // Legal name is seeded from company settings.
    final legalName = find.widgetWithText(TextFormField, 'Legal name');
    expect(tester.widget<TextFormField>(legalName).controller!.text,
        'Operion SRL');

    await tester.ensureVisible(find.text('Save').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(endpoints.patches, isNotEmpty);
    expect(endpoints.patches.last['legal_name'], 'Operion SRL');
    expect(endpoints.patches.last['vat_number'], 'RO123456');
  });
}
