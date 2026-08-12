import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/security/biometric_gate.dart';
import '../../invoicing/providers/invoicing_providers.dart'
    show BiometricRequired;

/// Company settings (blueprint §4.10) — mirrors the backend
/// `CompanySettingsOut` exactly. Secrets are exposed ONLY as `*_is_set`
/// booleans; the plaintext is never serialized.
class CompanySettings {
  const CompanySettings({
    this.legalName = '',
    this.vatNumber = '',
    this.address = '',
    this.invoiceFooter = '',
    this.smtpServer = '',
    this.smtpPort = '',
    this.smtpUser = '',
    this.smtpPasswordIsSet = false,
    this.trackingProvider = '',
    this.trackingApiKeyIsSet = false,
    this.maintenanceAlertDaysAhead = 30,
    this.tachoWarningDays = 45,
    this.tachoCriticalDays = 15,
  });

  final String legalName;
  final String vatNumber;
  final String address;
  final String invoiceFooter;
  final String smtpServer;
  final String smtpPort;
  final String smtpUser;
  final bool smtpPasswordIsSet;
  final String trackingProvider;
  final bool trackingApiKeyIsSet;

  /// Maintenance thresholds (Phase 4A schema).
  final int maintenanceAlertDaysAhead;
  final int tachoWarningDays;
  final int tachoCriticalDays;

  factory CompanySettings.fromJson(Map<String, dynamic> json) =>
      CompanySettings(
        legalName: json['legal_name']?.toString() ?? '',
        vatNumber: json['vat_number']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        invoiceFooter: json['invoice_footer']?.toString() ?? '',
        smtpServer: json['smtp_server']?.toString() ?? '',
        smtpPort: json['smtp_port']?.toString() ?? '',
        smtpUser: json['smtp_user']?.toString() ?? '',
        smtpPasswordIsSet: json['smtp_password_is_set'] as bool? ?? false,
        trackingProvider: json['tracking_provider']?.toString() ?? '',
        trackingApiKeyIsSet: json['tracking_api_key_is_set'] as bool? ?? false,
        maintenanceAlertDaysAhead:
            (json['maintenance_alert_days_ahead'] as num?)?.toInt() ?? 30,
        tachoWarningDays: (json['tacho_warning_days'] as num?)?.toInt() ?? 45,
        tachoCriticalDays:
            (json['tacho_critical_days'] as num?)?.toInt() ?? 15,
      );
}

/// Endpoint methods for company settings (blueprint §4.10 / §6.10).
class SettingsEndpoints {
  final ApiClient client;

  SettingsEndpoints(this.client);

  /// `GET /mobile/settings/company` → CompanySettingsOut (never secrets).
  Future<Response> getCompanySettings({CancelToken? cancelToken}) =>
      client.get('/api/v1/mobile/settings/company', cancelToken: cancelToken);

  /// `PATCH /mobile/settings/company` — write-only semantics:
  /// omitted → unchanged; explicit `""` → clears; value → sets.
  Future<Response> patchCompanySettings(
    Map<String, dynamic> data, {
    CancelToken? cancelToken,
  }) =>
      client.patch('/api/v1/mobile/settings/company',
          data: data, cancelToken: cancelToken);

  /// `POST /mobile/settings/test-email` — bounded SMTP test via prefs.
  Future<Response> testEmail({CancelToken? cancelToken}) =>
      client.post('/api/v1/mobile/settings/test-email', cancelToken: cancelToken);
}

/// Provides the singleton [SettingsEndpoints] wired to the shared client.
final settingsEndpointsProvider = Provider<SettingsEndpoints>((ref) {
  return SettingsEndpoints(ref.watch(apiClientProvider));
});

/// Fetches `GET /mobile/settings/company`.
final companySettingsProvider = FutureProvider.autoDispose<CompanySettings>(
    (ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final endpoints = ref.watch(settingsEndpointsProvider);
  final response =
      await endpoints.getCompanySettings(cancelToken: cancelToken);
  final data = response.data;
  if (data is! Map<String, dynamic>) {
    throw StateError('Unexpected company settings response: ${data.runtimeType}');
  }
  return CompanySettings.fromJson(data);
});

/// PATCH state for company settings (write-only secrets handled by the UI).
final companySettingsMutationProvider =
    StateNotifierProvider<CompanySettingsMutationNotifier, AsyncValue<void>>(
        (ref) {
  return CompanySettingsMutationNotifier(ref);
});

class CompanySettingsMutationNotifier extends StateNotifier<AsyncValue<void>> {
  CompanySettingsMutationNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  /// Persists company settings (`PATCH /mobile/settings/company`).
  ///
  /// §12 biometric step-up: prompts BEFORE any network call — a failed
  /// confirmation throws [BiometricRequired] and the endpoint is never
  /// reached (test-proven, mirrors the invoicing finance pattern).
  Future<void> save(
    Map<String, dynamic> data, {
    String? biometricReason,
  }) async {
    final ok = await _ref
        .read(biometricGateProvider)
        .requireBiometricConfirmation(
          reason: biometricReason ?? BiometricGate.defaultReason,
        );
    if (!ok) {
      state = const AsyncError(BiometricRequired(), StackTrace.empty);
      throw const BiometricRequired();
    }
    state = const AsyncLoading();
    try {
      await _ref.read(settingsEndpointsProvider).patchCompanySettings(data);
      state = const AsyncData(null);
      _ref.invalidate(companySettingsProvider);
    } catch (e, s) {
      state = AsyncError(e, s);
      rethrow;
    }
  }

  Future<void> sendTestEmail() async {
    state = const AsyncLoading();
    try {
      await _ref.read(settingsEndpointsProvider).testEmail();
      state = const AsyncData(null);
    } catch (e, s) {
      state = AsyncError(e, s);
      rethrow;
    }
  }
}
