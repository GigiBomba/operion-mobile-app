import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/auth/auth_providers.dart';
import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/core/network/api_client.dart';
import 'package:operion_mobile/core/network/endpoints/copilot_endpoints.dart';
import 'package:operion_mobile/features/copilot/providers/copilot_providers.dart';
import 'package:operion_mobile/features/driver/driver_shell.dart';
import 'package:operion_mobile/features/driver/home/driver_providers.dart';
import 'package:operion_mobile/features/driver/models/driver_trip_overview.dart';
import 'package:operion_mobile/features/driver/trip_overview/providers/trip_overview_providers.dart';
import 'package:operion_mobile/shared/models/transport.dart';

class _FakeEndpoints extends CopilotEndpoints {
  _FakeEndpoints()
      : super(ApiClient.create(
          baseUrl: 'https://test.com',
          getAccessToken: () async => null,
        ));
}

/// Records sendMessage calls (no network).
class _RecordingCopilotNotifier extends CopilotStateNotifier {
  _RecordingCopilotNotifier() : super(_FakeEndpoints());

  int sendCount = 0;
  String? lastMessage;

  @override
  Future<void> sendMessage(String utterance) async {
    sendCount++;
    lastMessage = utterance;
  }
}

Widget _app(_RecordingCopilotNotifier notifier) {
  return ProviderScope(
    overrides: [
      isOfflineProvider.overrideWith((ref) => false),
      currentUserProvider.overrideWith((ref) => null),
      // The driver shell copilot tab composes the seed from these.
      tripOverviewProvider.overrideWith(
        (ref) async => const DriverTripOverview(
          transportId: 'T-1',
          origin: 'Warehouse A',
          destination: 'Store B',
          etaConfidence: EtaConfidence.unavailable,
        ),
      ),
      transportsProvider.overrideWith((ref) async => const <Transport>[]),
      copilotStateProvider.overrideWith((ref) => notifier),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: DriverShell(),
    ),
  );
}

void main() {
  group('DriverShell copilot tab — context seeding', () {
    testWidgets('composes the trip context and sends it once', (tester) async {
      final notifier = _RecordingCopilotNotifier();
      await tester.pumpWidget(_app(notifier));
      await tester.pumpAndSettle();

      // Switch to the AI Copilot tab (index 2).
      await tester.tap(find.text('AI Copilot'));
      await tester.pumpAndSettle();

      expect(notifier.sendCount, 1,
          reason: 'the seed utterance must be sent exactly once');
      expect(notifier.lastMessage, 'My current trip: Warehouse A → Store B');
    });

    testWidgets('staying on the tab does not re-send on rebuilds',
        (tester) async {
      final notifier = _RecordingCopilotNotifier();
      await tester.pumpWidget(_app(notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI Copilot'));
      await tester.pumpAndSettle();
      // Force a rebuild of the shell body (e.g. an unrelated setState).
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(notifier.sendCount, 1);
    });

    testWidgets('falls back to the transport label when no trip overview',
        (tester) async {
      final notifier = _RecordingCopilotNotifier();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          isOfflineProvider.overrideWith((ref) => false),
          currentUserProvider.overrideWith((ref) => null),
          tripOverviewProvider.overrideWith(
            (ref) async => const DriverTripOverview(
              etaConfidence: EtaConfidence.unavailable,
            ),
          ),
          transportsProvider.overrideWith(
            (ref) async => const [
              Transport(
                id: 'tr-1',
                companyId: 'c-1',
                loadInfo: 'Truck A load',
                origin: 'O',
                destination: 'D',
                waypoints: [],
                status: 'planned',
              ),
            ],
          ),
          copilotStateProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DriverShell(),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI Copilot'));
      await tester.pumpAndSettle();

      expect(notifier.lastMessage, 'My current transport: Truck A load');
    });
  });
}
