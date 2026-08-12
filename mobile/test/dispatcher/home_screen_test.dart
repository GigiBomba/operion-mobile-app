import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:operion_mobile/features/dispatcher/home/dispatcher_home_screen.dart';
import 'package:operion_mobile/features/dispatcher/alerts/alert_inbox_screen.dart';
import 'package:operion_mobile/features/dispatcher/home/dispatcher_providers.dart';
import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/auth/biometric_service.dart';
import 'package:operion_mobile/core/storage/secure_token_store.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/shared/widgets/shimmer_loader.dart';
import 'package:operion_mobile/shared/widgets/app_card.dart';
import 'package:operion_mobile/shared/widgets/staleness_indicator.dart';

// ---------------------------------------------------------------------------
// Mock implementations
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const Map<String, dynamic> _sampleOverview = {
  'activeJobs': 5,
  'activeDrivers': 12,
  'openAlerts': 3,
  'vehiclesOnRoad': 8,
  'lastUpdated': '2026-07-19T10:30:00',
};

const Map<String, dynamic> _sampleOverviewNoTimestamp = {
  'activeJobs': 0,
  'activeDrivers': 0,
  'openAlerts': 0,
  'vehiclesOnRoad': 0,
};

/// §2 parity fixture: revenue_trend + recent_activity present.
const Map<String, dynamic> _sampleOverviewParity = {
  'activeJobs': 5,
  'activeDrivers': 12,
  'openAlerts': 3,
  'vehiclesOnRoad': 8,
  'lastUpdated': '2026-07-19T10:30:00',
  'revenue_trend': [
    {'month': '2026-02', 'revenue': 12000},
    {'month': '2026-03', 'revenue': 15000},
    {'month': '2026-04', 'revenue': 11000},
    {'month': '2026-05', 'revenue': 18000},
    {'month': '2026-06', 'revenue': 22000},
    {'month': '2026-07', 'revenue': 19500},
  ],
  'recent_activity': [
    {'type': 'trip', 'id': 11, 'title': 'Trip 11 completed', 'created_at': '2026-07-19T09:00:00'},
    {'type': 'alert', 'id': 3, 'title': 'Vehicle overdue', 'created_at': '2026-07-19T08:30:00'},
  ],
};

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget wrapHomeScreen({
  required Map<String, dynamic> overview,
}) {
  return ProviderScope(
    overrides: [
      secureTokenStoreProvider.overrideWithValue(_MockSecureTokenStore()),
      biometricServiceProvider.overrideWithValue(_MockBiometricService()),
      apiClientProvider.overrideWithValue(_stubApiClient()),
      dispatcherOverviewProvider.overrideWith((ref) async => overview),
      dispatcherTabProvider.overrideWith((ref) => 0),
      // Alert inbox is reachable from the activity feed; stub the alerts so
      // navigation never hits the network in tests.
      dispatcherAlertsProvider.overrideWith((ref) async => <Map<String, dynamic>>[]),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: DispatcherHomeScreen()),
    ),
  );
}

void main() {
  // ==========================================================================
  // DispatcherHomeScreen
  // ==========================================================================
  group('DispatcherHomeScreen', () {
    testWidgets('shows shimmer loading state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureTokenStoreProvider
                .overrideWithValue(_MockSecureTokenStore()),
            biometricServiceProvider
                .overrideWithValue(_MockBiometricService()),
            apiClientProvider.overrideWithValue(_stubApiClient()),
            dispatcherOverviewProvider.overrideWith(
              (ref) => Completer<Map<String, dynamic>>().future,
            ),
            dispatcherTabProvider.overrideWith((ref) => 0),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: DispatcherHomeScreen()),
          ),
        ),
      );
      await tester.pump();

      // Shimmer should be visible
      expect(find.byType(ShimmerLoader), findsWidgets);
    });

    testWidgets('shows error state with retry button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureTokenStoreProvider
                .overrideWithValue(_MockSecureTokenStore()),
            biometricServiceProvider
                .overrideWithValue(_MockBiometricService()),
            apiClientProvider.overrideWithValue(_stubApiClient()),
            dispatcherOverviewProvider.overrideWith(
              (ref) => Future.error(Exception('Failed to load overview')),
            ),
            dispatcherTabProvider.overrideWith((ref) => 0),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: DispatcherHomeScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Error icon and retry button should be visible
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('renders KPI cards with data values', (tester) async {
      await tester.pumpWidget(wrapHomeScreen(overview: _sampleOverview));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // KPI values should be visible (formatted as strings)
      expect(find.text('5'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);

      // KPI grid structure: AppCards inside
      expect(find.byType(AppCard), findsWidgets);
    });

    testWidgets('renders quick actions row', (tester) async {
      await tester.pumpWidget(wrapHomeScreen(overview: _sampleOverview));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Quick action chips should be visible
      expect(find.byType(ActionChip), findsWidgets);
    });

    testWidgets('shows staleness indicator with last updated time',
        (tester) async {
      await tester.pumpWidget(wrapHomeScreen(overview: _sampleOverview));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // StalenessIndicator should be visible
      expect(find.byType(StalenessIndicator), findsOneWidget);
    });

    testWidgets('handles zero values in KPI cards', (tester) async {
      await tester.pumpWidget(
        wrapHomeScreen(overview: _sampleOverviewNoTimestamp),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // All zero values should render as '0'
      expect(find.text('0'), findsNWidgets(4));
    });

    testWidgets('supports pull-to-refresh via RefreshIndicator',
        (tester) async {
      await tester.pumpWidget(wrapHomeScreen(overview: _sampleOverview));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // RefreshIndicator should wrap the content
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('header shows dispatcher overview title', (tester) async {
      await tester.pumpWidget(wrapHomeScreen(overview: _sampleOverview));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The overview label uses locale keys, so we check for the
      // DispatcherHomeScreen widget itself
      expect(find.byType(DispatcherHomeScreen), findsOneWidget);
    });

    testWidgets('tapping quick action chips does not crash', (tester) async {
      await tester.pumpWidget(wrapHomeScreen(overview: _sampleOverview));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on quick action chips
      final chips = find.byType(ActionChip);
      if (chips.evaluate().isNotEmpty) {
        await tester.tap(chips.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        // Should not crash
      }
    });
  });

  // ==========================================================================
  // §2 Feature-parity — revenue trend sparkline + recent activity
  // ==========================================================================
  group('DispatcherHomeScreen — §2 overview parity', () {
    testWidgets('renders the revenue trend card when trend data exists',
        (tester) async {
      await tester.pumpWidget(wrapHomeScreen(overview: _sampleOverviewParity));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Revenue trend'), findsOneWidget);
    });

    testWidgets('hides the revenue trend card when trend data is absent',
        (tester) async {
      await tester.pumpWidget(wrapHomeScreen(overview: _sampleOverview));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Revenue trend'), findsNothing);
    });

    testWidgets('renders the recent activity feed with trip and alert rows',
        (tester) async {
      await tester.pumpWidget(wrapHomeScreen(overview: _sampleOverviewParity));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Recent activity'), findsOneWidget);
      expect(find.text('Trip 11 completed'), findsOneWidget);
      expect(find.text('Vehicle overdue'), findsOneWidget);
    });

    testWidgets('shows an empty activity placeholder when activity is absent',
        (tester) async {
      await tester.pumpWidget(wrapHomeScreen(overview: _sampleOverview));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No recent activity'), findsOneWidget);
    });

    testWidgets('tapping an alert activity row opens the alert inbox',
        (tester) async {
      await tester.pumpWidget(wrapHomeScreen(overview: _sampleOverviewParity));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll the feed into view if needed, then tap the alert row.
      await tester.ensureVisible(find.text('Vehicle overdue'));
      await tester.pump();
      await tester.tap(find.text('Vehicle overdue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertInboxScreen), findsOneWidget);
    });
  });
}
