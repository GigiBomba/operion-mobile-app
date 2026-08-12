import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/app.dart';
import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/auth/biometric_service.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/auth_endpoints.dart';
import 'package:operion_mobile/core/network/endpoints/dispatcher_endpoints.dart';
import 'package:operion_mobile/core/storage/local_db.dart';
import 'package:operion_mobile/core/storage/secure_token_store.dart';
import 'package:operion_mobile/core/sync/action_queue.dart';
import 'package:operion_mobile/features/dispatcher/home/dispatcher_providers.dart';
import 'package:operion_mobile/shared/models/user.dart';

// ---------------------------------------------------------------------------
// Shared mocks / stubs for the Phase-6 integration suite.
//
// These follow the exact conventions of the existing integration_test files
// (dispatcher_flow_test.dart / driver_daily_flow_test.dart): providers are
// overridden with in-memory fakes so no platform channel or network call is
// ever made.
// ---------------------------------------------------------------------------

/// In-memory [SecureTokenStore] pre-seeded with a session, so the ModeRouter
/// auto-restores the current user on launch.
class FakeSecureTokenStore extends SecureTokenStore {
  String? _accessToken = 'mock_access_token';
  String? _refreshToken = 'mock_refresh_token';

  @override
  Future<bool> hasTokens() async => _accessToken != null;

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
  }

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
  }
}

class FakeBiometricService extends BiometricService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

/// Stub [AuthEndpoints] returning a pre-authenticated session for [user].
class StubAuthEndpoints extends AuthEndpoints {
  StubAuthEndpoints(this.user)
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_access_token',
        ));

  final User user;

  @override
  Future<Response> login(String email, String password,
      {String? deviceId}) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        // Both key styles: AuthService.login reads camelCase-first, and the
        // ModeRouter's session restore (TokenManager.tryRefresh) reads
        // camelCase only — snake_case alone would fail the restore and land
        // the app on the LoginScreen.
        'access_token': 'mock_access_token',
        'refresh_token': 'mock_refresh_token',
        'accessToken': 'mock_access_token',
        'refreshToken': 'mock_refresh_token',
        'user': user.toJson(),
      },
    );
  }

  @override
  Future<Response> refreshToken(String refreshToken) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'access_token': 'mock_access_token',
        'refresh_token': 'mock_refresh_token',
        'accessToken': 'mock_access_token',
        'refreshToken': 'mock_refresh_token',
      },
    );
  }

  @override
  Future<Response> getMe() async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: user.toJson(),
    );
  }

  @override
  Future<Response> registerDevice({
    required String deviceId,
    required String platform,
    String? deviceName,
    String? fcmToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'status': 'registered'},
    );
  }

  @override
  Future<Response> logout() async {
    return Response(requestOptions: RequestOptions(path: ''), data: {});
  }
}

/// Stub [DispatcherEndpoints] returning realistic dispatcher data so the
/// manager shell boots cleanly (overview KPI cards, jobs, alerts).
class StubDispatcherEndpoints extends DispatcherEndpoints {
  StubDispatcherEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_access_token',
        ));

  @override
  Future<Response> getOverview() async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'activeJobs': 12,
        'activeDrivers': 8,
        'openAlerts': 3,
        'vehiclesOnRoad': 6,
        'lastUpdated': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  Future<Response> getFleet() async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: <Map<String, dynamic>>[],
    );
  }

  @override
  Future<Response> getJobs() async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: <Map<String, dynamic>>[],
    );
  }

  @override
  Future<Response> getDrivers({
    CancelToken? cancelToken,
    int? expiringWithinDays,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: <Map<String, dynamic>>[],
    );
  }

  @override
  Future<Response> getAlerts() async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: <Map<String, dynamic>>[],
    );
  }

  @override
  Future<Response> approveAction(String id) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'status': 'approved'},
    );
  }

  @override
  Future<Response> rejectAction(String id, {String? reason}) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'status': 'rejected'},
    );
  }
}

/// Mutable offline flag so tests can toggle "airplane mode".
class OfflineFlag {
  bool offline = false;
}

/// Standard manager user used across the Phase-6 feature flows.
const User managerUser = User(
  id: '2',
  email: 'manager@operion.ro',
  fullName: 'Test Manager',
  role: 'manager',
  companyId: '1',
);

/// Creates an initialised in-memory [LocalDatabase] — the fleet/drivers/
/// clients/invoices/team providers cache into it and it must be initialised
/// before any cache write (the app's default instance never calls
/// [LocalDatabase.initialize] in tests).
Future<LocalDatabase> initTestLocalDatabase() async {
  final db = LocalDatabase();
  await db.initialize();
  return db;
}

/// Base provider overrides for a pre-authenticated manager session.
///
/// [extra] appends feature-specific endpoint stubs. The app locale is pinned
/// to English so text assertions are deterministic regardless of the device
/// locale (the app default is Romanian).
List<Override> managerOverrides({
  required LocalDatabase db,
  required User user,
  OfflineFlag? offline,
  List<Override> extra = const [],
}) {
  return [
    secureTokenStoreProvider.overrideWithValue(FakeSecureTokenStore()),
    biometricServiceProvider.overrideWithValue(FakeBiometricService()),
    authEndpointsProvider.overrideWith((ref) => StubAuthEndpoints(user)),
    dispatcherEndpointsProvider
        .overrideWith((ref) => StubDispatcherEndpoints()),
    localDatabaseProvider.overrideWithValue(db),
    currentUserProvider.overrideWith((ref) => user),
    // The ModeRouter gates on authState (not just currentUser): without this
    // the default unauthenticated state renders the LoginScreen instead of
    // the manager shell.
    authStateProvider.overrideWith(
      (ref) => AuthStateNotifier(ref)..setAuthenticated(),
    ),
    localeProvider.overrideWith((ref) => const Locale('en')),
    isOfflineProvider.overrideWith((ref) => offline?.offline ?? false),
    ...extra,
  ];
}

/// Pumps the full app with [overrides] on a phone-sized viewport.
///
/// A phone viewport keeps the navigation in push-route mode (no tablet
/// master-detail nesting), which makes tile taps unambiguous and keeps the
/// journeys short and robust.
Future<void> pumpApp(
  WidgetTester tester, {
  required List<Override> overrides,
  ProviderContainer? container,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  if (container != null) {
    await tester.pumpWidget(OperionMobileApp(container: container));
  } else {
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const OperionMobileApp()),
    );
  }
  await tester.pumpAndSettle();
}

/// Switches the dispatcher-shell bottom navigation tab by label.
Future<void> tapBottomNav(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

/// Opens the Records tab (Fleet / Drivers / Clients / Trip & Route History).
Future<void> openRecordsTab(WidgetTester tester) =>
    tapBottomNav(tester, 'Records');

/// Opens the More tab (Analytics, Invoicing, Maintenance, Settings, ...).
Future<void> openMoreTab(WidgetTester tester) => tapBottomNav(tester, 'More');

/// Taps a tile / list item by its exact label and settles.
///
/// `.first` keeps this robust on tablet master-detail layouts where the label
/// can appear in both the tile and the detail pane — the tile is the
/// actionable one and precedes the detail pane in the widget tree.
///
/// [ensureVisible] first scrolls the target into view: the More hub is a
/// scrollable grid on phone widths, so tiles further down the grid (Settings,
/// Maintenance, Teams, Tachograph, Document Center) are off-screen on the
/// 390×844 test viewport and a bare `tap` would silently miss.
Future<void> tapByText(WidgetTester tester, String label) async {
  final finder = find.text(label).first;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
