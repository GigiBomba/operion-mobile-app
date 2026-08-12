import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/features/settings/providers/settings_endpoints.dart';

import 'test_support.dart';

/// Stub [SettingsEndpoints] returning company settings with both secrets
/// reported as set (`*_is_set: true`) — the UI must show them as masked
/// placeholders, never as plaintext.
class _StubSettingsEndpoints extends SettingsEndpoints {
  _StubSettingsEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_access_token',
        ));

  @override
  Future<Response> getCompanySettings({CancelToken? cancelToken}) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'legal_name': 'Operion SRL',
        'vat_number': 'RO99999999',
        'address': 'Bucharest, Romania',
        'invoice_footer': 'Thank you!',
        'smtp_server': 'smtp.operion.ro',
        'smtp_port': '587',
        'smtp_user': 'noreply@operion.ro',
        'smtp_password_is_set': true,
        'tracking_provider': 'wialon',
        'tracking_api_key_is_set': true,
        'maintenance_alert_days_ahead': 30,
        'tacho_warning_days': 45,
        'tacho_critical_days': 15,
      },
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Flow', () {
    testWidgets(
      '1. Settings sections render and secret fields are masked',
      (tester) async {
        final db = await initTestLocalDatabase();
        final overrides = managerOverrides(
          db: db,
          user: managerUser,
          extra: [
            settingsEndpointsProvider
                .overrideWith((ref) => _StubSettingsEndpoints()),
          ],
        );

        await pumpApp(tester, overrides: overrides);

        // More tab → Settings tile.
        await openMoreTab(tester);
        await tapByText(tester, 'Settings');

        // Appearance / language sections render (headers are uppercased).
        expect(find.text('LANGUAGE'), findsOneWidget);
        // The current-language value renders once in the section header and
        // once as the highlighted option in the language picker list.
        expect(find.text('English'), findsWidgets);
        expect(find.text('APP VERSION'), findsOneWidget);

        // Scroll to the SMTP section: the password field is masked and shows
        // the "•••• configured" placeholder (never the plaintext secret).
        await tester.scrollUntilVisible(
          find.text('SMTP password'),
          300,
          scrollable: find.byType(Scrollable).hitTestable().first,
        );
        await tester.pumpAndSettle();
        expect(find.text('SMTP CONFIGURATION'), findsOneWidget);
        expect(
          find.textContaining('configured'),
          findsWidgets,
          reason: 'Secret fields with values set show the masked configured '
              'placeholder.',
        );

        // The SMTP password field must be an obscured TextField.
        final smtpField = tester.widget<TextField>(
          find.ancestor(
            of: find.text('SMTP password'),
            matching: find.byType(TextField),
          ),
        );
        expect(smtpField.obscureText, isTrue,
            reason: 'The SMTP password field must never show its value.');

        // Scroll further to the fleet tracking section and check the API key
        // field is also masked.
        await tester.scrollUntilVisible(
          find.text('Tracking API key'),
          300,
          scrollable: find.byType(Scrollable).hitTestable().first,
        );
        await tester.pumpAndSettle();
        final trackingField = tester.widget<TextField>(
          find.ancestor(
            of: find.text('Tracking API key'),
            matching: find.byType(TextField),
          ),
        );
        expect(trackingField.obscureText, isTrue,
            reason: 'The tracking API key field must never show its value.');
      },
    );
  });
}
