import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/driver_endpoints.dart';
import 'package:operion_mobile/features/driver/home/driver_providers.dart';
import 'package:operion_mobile/features/freight_exchange/models/freight_load.dart';
import 'package:operion_mobile/features/freight_exchange/providers/freight_exchange_providers.dart';
import 'package:operion_mobile/features/freight_exchange/screens/freight_exchange_screen.dart';

import 'helpers.dart';

/// Fake [DriverEndpoints] serving the transport picker fixture.
class _FakeDriverEndpoints extends DriverEndpoints {
  _FakeDriverEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));

  @override
  Future<Response> getTransports() async {
    return Response(
      requestOptions: RequestOptions(path: '/api/v1/mobile/driver/transports'),
      data: [transportFixture()],
      statusCode: 200,
    );
  }
}

/// Builds an [ApiClient] wired to [adapter].
ApiClient _clientWith(MockDioAdapter adapter) {
  final client = ApiClient.create(
    baseUrl: 'https://test.com',
    getAccessToken: () async => null,
  );
  client.dio.httpClientAdapter = adapter;
  return client;
}

void main() {
  group('FreightExchangeAcceptNotifier', () {
    test('accept carries an Idempotency-Key on the import request', () async {
      final adapter = MockDioAdapter(
        // Live re-check passes — load still on the board.
        onGet: (options) => jsonResponse(freightLoadFixture()),
        onPost: (options) =>
            jsonResponse({'trip_id': 42, 'source': 'freight_exchange'}),
      );
      final notifier = FreightExchangeAcceptNotifier(_clientWith(adapter));
      addTearDown(notifier.dispose);

      final load = FreightLoad.fromJson(freightLoadFixture()[0]);
      await notifier.accept(
        load: load,
        filter: const FreightLoadFilter(),
        transportId: 'tr-1',
      );

      expect(notifier.state.status, FreightAcceptStatus.accepted);
      expect(adapter.postRequestCount, 1);

      final postRequest = adapter.requests.last;
      // Import endpoint URL built from the composite provider-agnostic id.
      expect(postRequest.path, '/api/v1/freight/loads/exch-a/load-1/import');
      // §1.7 — the accept call carries an Idempotency-Key.
      expect(
        postRequest.headers['Idempotency-Key'],
        isNotNull,
        reason: 'accept must send Idempotency-Key',
      );
      expect(
        postRequest.headers['Idempotency-Key'],
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
      );
      // The assignment target is attached.
      expect(postRequest.data, {'transport_id': 'tr-1'});
    });

    test('re-check finds the load taken → conflict state, no import call',
        () async {
      final adapter = MockDioAdapter(
        // Live re-check returns an empty board — the load was just taken.
        onGet: (options) => jsonResponse([]),
        onPost: (options) =>
            jsonResponse({'trip_id': 42, 'source': 'freight_exchange'}),
      );
      final notifier = FreightExchangeAcceptNotifier(_clientWith(adapter));
      addTearDown(notifier.dispose);

      final load = FreightLoad.fromJson(freightLoadFixture()[0]);
      await notifier.accept(
        load: load,
        filter: const FreightLoadFilter(),
        transportId: 'tr-1',
      );

      expect(notifier.state.status, FreightAcceptStatus.taken);
      expect(notifier.state.messageKey, 'freightExchange_taken');
      // No import attempt was made after the conflict.
      expect(adapter.postRequestCount, 0);
    });

    test('import returning 409 → conflict state', () async {
      final adapter = MockDioAdapter(
        // Re-check passes…
        onGet: (options) => jsonResponse(freightLoadFixture()),
        // …but another session accepted it before our import landed.
        onPost: (options) =>
            jsonResponse({'detail': 'load already imported'}, statusCode: 409),
      );
      final notifier = FreightExchangeAcceptNotifier(_clientWith(adapter));
      addTearDown(notifier.dispose);

      final load = FreightLoad.fromJson(freightLoadFixture()[0]);
      await notifier.accept(
        load: load,
        filter: const FreightLoadFilter(),
        transportId: 'tr-1',
      );

      expect(notifier.state.status, FreightAcceptStatus.taken);
      expect(notifier.state.messageKey, 'freightExchange_taken');
      expect(adapter.postRequestCount, 1);
    });

    test('network failure → error state', () async {
      final adapter = MockDioAdapter(
        onGet: (options) => jsonResponse(freightLoadFixture()),
        onPost: (options) => throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
            ),
      );
      final notifier = FreightExchangeAcceptNotifier(_clientWith(adapter));
      addTearDown(notifier.dispose);

      final load = FreightLoad.fromJson(freightLoadFixture()[0]);
      await notifier.accept(
        load: load,
        filter: const FreightLoadFilter(),
        transportId: 'tr-1',
      );

      expect(notifier.state.status, FreightAcceptStatus.error);
      expect(notifier.state.messageKey, 'freightExchange_acceptError');
    });

    test('unresolvable provider id → localized error, never a "current" guess',
        () async {
      final adapter = MockDioAdapter(
        // Live re-check passes — the bare-id load is still on the board.
        onGet: (options) => jsonResponse([
          {'id': 'load-99', 'origin': 'Berlin', 'destination': 'Bucharest'},
        ]),
      );
      final notifier = FreightExchangeAcceptNotifier(_clientWith(adapter));
      addTearDown(notifier.dispose);

      // A bare load id without an explicit provider_id segment cannot be
      // routed to an import endpoint (Gate 2 — M1).
      final load = FreightLoad.fromJson({
        'id': 'load-99',
        'origin': 'Berlin',
        'destination': 'Bucharest',
      });

      await notifier.accept(
        load: load,
        filter: const FreightLoadFilter(),
        transportId: 'tr-1',
      );

      expect(notifier.state.status, FreightAcceptStatus.error);
      expect(notifier.state.messageKey, 'freightExchange_acceptError');
      // No import request was attempted.
      expect(adapter.postRequestCount, 0);
    });
  });

  group('FreightExchangeAcceptNotifier — CancelToken lifecycle (§1.2)', () {
    test('dispose cancels the notifier token', () {
      final adapter = MockDioAdapter(onGet: (options) => jsonResponse([]));
      final notifier = FreightExchangeAcceptNotifier(_clientWith(adapter));
      expect(notifier.cancelToken.isCancelled, isFalse);
      notifier.dispose();
      expect(notifier.cancelToken.isCancelled, isTrue);
    });

    test('a cancelled request never surfaces as a provider error', () async {
      final adapter = MockDioAdapter(
        onGet: (options) => throw DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
            ),
      );
      final notifier = FreightExchangeAcceptNotifier(_clientWith(adapter));
      addTearDown(notifier.dispose);

      final load = FreightLoad.fromJson(freightLoadFixture()[0]);
      await notifier.accept(
        load: load,
        filter: const FreightLoadFilter(),
        transportId: 'tr-1',
      );

      expect(notifier.state.status, isNot(FreightAcceptStatus.error),
          reason: 'cancellation is a graceful no-op, not an error');
    });
  });

  group('FreightExchangeScreen — conflict flow', () {
    testWidgets(
        'conflict shows the localized "just taken" message and refreshes the list',
        (tester) async {
      final adapter = MockDioAdapter(
        onGet: (options) => jsonResponse(freightLoadFixture()),
        onPost: (options) =>
            jsonResponse({'detail': 'load already imported'}, statusCode: 409),
      );
      final client = _clientWith(adapter);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          driverEndpointsProvider.overrideWithValue(_FakeDriverEndpoints()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: FreightExchangeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Board renders from fixture.
      expect(find.text('Berlin → Bucharest'), findsOneWidget);

      // Open the load detail.
      await tester.tap(find.text('Berlin → Bucharest'));
      await tester.pumpAndSettle();

      // Accept & Assign → transport picker.
      await tester.tap(find.text('Accept & Assign'));
      await tester.pumpAndSettle();

      // Pick "Truck A".
      await tester.tap(find.text('Truck A'));
      await tester.pumpAndSettle();

      // Localized conflict message.
      expect(find.text('This load was just taken'), findsOneWidget);

      // The board was refreshed: initial fetch + re-check + post-conflict
      // refresh ⇒ at least 3 GETs to the load board.
      expect(
        adapter.getRequestCount,
        greaterThanOrEqualTo(3),
        reason: 'conflict must trigger a list refresh',
      );
    });
  });
}
