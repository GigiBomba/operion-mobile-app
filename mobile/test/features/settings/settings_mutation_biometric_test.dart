// Company-settings save — §12 biometric step-up (mirrors the invoicing
// finance pattern: the API must be unreachable without a successful
// confirmation).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/security/biometric_gate.dart';
import 'package:operion_mobile/features/invoicing/providers/invoicing_providers.dart'
    show BiometricRequired;
import 'package:operion_mobile/features/settings/providers/settings_endpoints.dart';

/// Endpoints stub that records patchCompanySettings calls.
class _RecordingSettingsEndpoints extends SettingsEndpoints {
  _RecordingSettingsEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  final List<Map<String, dynamic>> patches = [];

  @override
  Future<Response> patchCompanySettings(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) async {
    patches.add(data);
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/settings/company'),
      data: {},
      statusCode: 200,
    );
  }
}

void main() {
  group('CompanySettingsMutationNotifier.save — §12 biometric step-up', () {
    test('biometric FAILURE → BiometricRequired, endpoint NOT called',
        () async {
      final endpoints = _RecordingSettingsEndpoints();
      final container = ProviderContainer(
        overrides: [
          settingsEndpointsProvider.overrideWithValue(endpoints),
          biometricGateProvider.overrideWithValue(
            BiometricGate(authenticate: (_) async => false),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(companySettingsMutationProvider.notifier)
            .save({'legal_name': 'Operion SRL'}),
        throwsA(isA<BiometricRequired>()),
      );
      expect(endpoints.patches, isEmpty,
          reason: 'API must be unreachable without a successful biometric check');
    });

    test('biometric SUCCESS → proceeds and calls the endpoint DIRECTLY',
        () async {
      final endpoints = _RecordingSettingsEndpoints();
      final container = ProviderContainer(
        overrides: [
          settingsEndpointsProvider.overrideWithValue(endpoints),
          biometricGateProvider.overrideWithValue(
            BiometricGate(authenticate: (_) async => true),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(companySettingsMutationProvider.notifier)
          .save({'legal_name': 'Operion SRL'});

      expect(endpoints.patches, hasLength(1));
      expect(endpoints.patches.single['legal_name'], 'Operion SRL');
    });
  });
}
