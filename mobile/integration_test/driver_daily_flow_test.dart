import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:integration_test/integration_test.dart';

import 'package:operion_mobile/app.dart';
import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/auth/biometric_service.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/driver_endpoints.dart';
import 'package:operion_mobile/core/network/endpoints/auth_endpoints.dart';
import 'package:operion_mobile/core/storage/secure_token_store.dart';
import 'package:operion_mobile/shared/models/user.dart';
import 'package:operion_mobile/features/driver/home/driver_providers.dart';
import 'package:operion_mobile/core/providers/driver_providers.dart'
    as core_driver_providers;
import 'package:operion_mobile/features/driver/expenses/expense_providers.dart';

// ---------------------------------------------------------------------------
// Mock / Stub providers
// ---------------------------------------------------------------------------

class _MockSecureTokenStore extends SecureTokenStore {
  String? _accessToken = 'mock_token';
  String? _refreshToken = 'mock_refresh';

  @override
  Future<bool> hasTokens() async => true;

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

class _MockBiometricService extends BiometricService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

/// Stub AuthEndpoints that returns pre-authenticated session responses.
class _StubAuthEndpoints extends AuthEndpoints {
  _StubAuthEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_token',
        ));

  @override
  Future<Response> login(String email, String password, {String? deviceId}) async {
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
  Future<Response> refreshToken(String refreshToken) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'access_token': 'mock_new_access',
        'refresh_token': 'mock_new_refresh',
        'accessToken': 'mock_new_access',
        'refreshToken': 'mock_new_refresh',
      },
    );
  }

  @override
  Future<Response> getMe() async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: User(
        id: '1',
        email: 'driver@operion.ro',
        fullName: 'Test Driver',
        role: 'driver',
        companyId: '1',
      ).toJson(),
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
}

/// Simulates a driver session with pre-populated data.
class _StubDriverEndpoints extends DriverEndpoints {
  _StubDriverEndpoints()
      : super(ApiClient.create(
          baseUrl: '',
          getAccessToken: () async => 'mock_token',
        ));

  @override
  Future<Response> getMyDay() async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'activeTransports': 2,
        'nextStop': {'destination': 'Bucharest'},
        'transports': [
          {
            'id': 't1',
            'loadInfo': 'Steel coils — 20t',
            'origin': 'Cluj-Napoca, Str. Fabricii 12',
            'destination': 'Bucharest, Str. Industriilor 5',
            'status': 'in_transit',
            'companyId': '1',
            'waypoints': [],
            'scheduledDate': DateTime.now().toIso8601String(),
          },
          {
            'id': 't2',
            'loadInfo': 'Electronics — pallets',
            'origin': 'Timisoara, Str. Laminorului 3',
            'destination': 'Arad, Str. Constructorilor 8',
            'status': 'planned',
            'companyId': '1',
            'waypoints': [],
            'scheduledDate': DateTime.now().toIso8601String(),
          },
        ],
        'messages': [
          {
            'id': 'm1',
            'senderId': 'disp1',
            'senderName': 'Maria Dispatcher',
            'receiverId': '1',
            'text': 'Please confirm delivery time for transport #t1',
            'timestamp': DateTime.now().toIso8601String(),
            'isRead': false,
          },
        ],
        'lastUpdated': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  Future<Response> getTripOverview({CancelToken? cancelToken}) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'transport_id': 't1',
        'load_info': 'Steel coils — 20t',
        'origin': 'Cluj-Napoca',
        'destination': 'Bucharest',
        'status': 'in_transit',
        'status_since':
            DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'eta': DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
        'eta_confidence': 'live',
      },
    );
  }

  @override
  Future<Response> getTransports() async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: [
        {
          'id': 't1',
          'loadInfo': 'Steel coils — 20t',
          'origin': 'Cluj-Napoca, Str. Fabricii 12',
          'destination': 'Bucharest, Str. Industriilor 5',
          'status': 'in_transit',
          'companyId': '1',
          'waypoints': [],
          'scheduledDate': DateTime.now().toIso8601String(),
        },
        {
          'id': 't2',
          'loadInfo': 'Electronics — pallets',
          'origin': 'Timisoara, Str. Laminorului 3',
          'destination': 'Arad, Str. Constructorilor 8',
          'status': 'planned',
          'companyId': '1',
          'waypoints': [],
          'scheduledDate': DateTime.now().toIso8601String(),
        },
      ],
    );
  }

  @override
  Future<Response> getTransport(String id) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {
        'id': id,
        'loadInfo': 'Steel coils — 20t',
        'origin': 'Cluj-Napoca, Str. Fabricii 12',
        'destination': 'Bucharest, Str. Industriilor 5',
        'status': 'in_transit',
        'companyId': '1',
        'waypoints': [],
        'scheduledDate': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  Future<Response> updateStatus(String transportId, String status) async {
    return Response(
      requestOptions: RequestOptions(path: ''),
      data: {'status': status},
    );
  }
}

/// Provider overrides for driver flow test.
List<Override> driverFlowOverrides() => [
      secureTokenStoreProvider.overrideWithValue(_MockSecureTokenStore()),
      biometricServiceProvider.overrideWithValue(_MockBiometricService()),
      authEndpointsProvider.overrideWith((ref) => _StubAuthEndpoints()),
      driverEndpointsProvider.overrideWith((ref) => _StubDriverEndpoints()),
      // The trip-overview / route-share features read the CORE driver
      // endpoints provider (defined in core/providers/driver_providers.dart),
      // which is a DIFFERENT provider object from the features one above.
      core_driver_providers.driverEndpointsProvider
          .overrideWith((ref) => _StubDriverEndpoints()),
      currentUserProvider.overrideWith((ref) => User(
            id: '1',
            email: 'driver@operion.ro',
            fullName: 'Test Driver',
            role: 'driver',
            companyId: '1',
          )),
      // The ModeRouter gates on authState (not just currentUser): without
      // this the default unauthenticated state renders the LoginScreen.
      authStateProvider.overrideWith(
        (ref) => AuthStateNotifier(ref)..setAuthenticated(),
      ),
      expenseSubmittingProvider.overrideWith((ref) => false),
      isOfflineProvider.overrideWith((ref) => false),
      // The app default locale is Romanian; pin English so the text
      // assertions below are deterministic (Phase-6 i18n fix, non-weakening).
      localeProvider.overrideWith((ref) => const Locale('en')),
    ];

Widget createTestApp() => ProviderScope(
      overrides: driverFlowOverrides(),
      child: const OperionMobileApp(),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Driver Daily Flow', () {
    testWidgets('1. Login as driver and view home screen', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // The mode router should auto-restore session and show driver shell
      expect(
        find.byType(BottomNavigationBar),
        findsOneWidget,
        reason: 'Driver bottom navigation should be visible after auth.',
      );

      // The shell defaults to the Map tab; the assigned-trip overview lives
      // on the Overview tab.
      await tester.tap(find.text('Overview').first);
      await tester.pumpAndSettle();

      // The trip overview shows the assigned transport's load.
      expect(
        find.textContaining('Steel coils'),
        findsWidgets,
        reason: 'Trip overview should display the assigned transport.',
      );
    });

    testWidgets('2. Update the trip status from the overview', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overview').first);
      await tester.pumpAndSettle();

      // The transport summary card renders the load and the route.
      expect(find.textContaining('Steel coils'), findsWidgets);
      expect(
        find.text('Cluj-Napoca → Bucharest'),
        findsWidgets,
        reason: 'The trip overview shows the origin → destination route.',
      );

      // The in-transit trip offers the "Mark Delivered" transition; tapping
      // it calls the stubbed updateStatus and shows the confirmation snackbar.
      await tester.ensureVisible(find.text('Mark Delivered'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark Delivered'));
      await tester.pumpAndSettle();

      expect(
        find.text('Status updated'),
        findsWidgets,
        reason: 'Updating the status shows the confirmation snackbar.',
      );
    });

    testWidgets('3. Verify driver dashboard summary cards', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overview').first);
      await tester.pumpAndSettle();

      // The overview shows the transport summary plus the ETA and elapsed
      // time cards.
      expect(find.textContaining('Steel coils'), findsWidgets);
      expect(find.text('ETA'), findsOneWidget);
      expect(find.text('Elapsed Time'), findsOneWidget);
    });

    testWidgets('4. Pull-to-refresh on driver overview', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overview').first);
      await tester.pumpAndSettle();

      // The overview screen should be showing with RefreshIndicator
      expect(find.byType(RefreshIndicator), findsWidgets);

      // Drag down to trigger refresh
      await tester.fling(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      // After refresh, the trip overview data should still be shown
      expect(
        find.textContaining('Steel coils'),
        findsWidgets,
        reason:
            'After pull-to-refresh, the trip overview data remains visible.',
      );
    });
  });
}
