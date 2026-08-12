import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/i18n/app_localizations.dart';
import '../../shared/models/transport.dart';
import '../../shared/widgets/offline_banner.dart';

import '../copilot/screens/copilot_screen.dart';
import '../settings/settings_screen.dart';
import 'home/driver_providers.dart';
import 'models/driver_trip_overview.dart';
import 'route_share/screens/route_share_nav_screen.dart';
import 'trip_overview/providers/trip_overview_providers.dart';
import 'trip_overview/screens/driver_trip_overview_screen.dart';

/// Driver-mode bottom navigation shell.
///
/// Provides four tabs:
/// 1. **Map** — turn-by-turn route navigation ([RouteShareNavScreen]).
/// 2. **Overview** — trip overview dashboard ([DriverTripOverviewScreen]).
/// 3. **AI Copilot** — AI-powered chat assistant ([CopilotChatScreen]).
/// 4. **Settings** — app settings, language, theme, logout ([SettingsScreen]).
///
/// Includes an [OfflineBanner] at the top when connectivity is lost.
///
/// Driver-specific styling:
/// * Large tap targets (Material 3 meets 48 pt by default).
/// * High-contrast icon/selection colours.
class DriverShell extends ConsumerStatefulWidget {
  const DriverShell({super.key});

  @override
  ConsumerState<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends ConsumerState<DriverShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(isOfflineProvider);
    final loc = context.loc;

    return Scaffold(
      body: Column(
        children: [
          // Offline banner pinned at the top
          OfflineBanner(isOffline: isOffline),
          // Main tab content fills remaining space
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
        // Larger, bolder labels for driver readability
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined),
            activeIcon: const Icon(Icons.map),
            label: loc.nav_map,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard),
            label: loc.nav_overview,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.auto_awesome_outlined),
            activeIcon: const Icon(Icons.auto_awesome),
            label: loc.nav_copilot,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: loc.nav_settings,
          ),
        ],
      ),
    );
  }

  /// Returns the screen widget for the currently selected tab.
  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const RouteShareNavScreen();
      case 1:
        return const DriverTripOverviewScreen();
      case 2:
        return const _DriverCopilotTab();
      case 3:
        return const SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Driver copilot tab: seeds the shared [CopilotChatScreen] with the driver's
/// current trip/transport context so the assistant starts the conversation
/// already aware of the assignment.
///
/// Composes the utterance from [tripOverviewProvider] (preferred) or
/// [transportsProvider] (fallback); when neither has data the utterance is
/// null and the copilot behaves exactly as before. The seeding is one-shot —
/// [CopilotScreen.initialUtterance] is only auto-sent for a fresh
/// conversation.
class _DriverCopilotTab extends ConsumerWidget {
  const _DriverCopilotTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final overview = ref.watch(tripOverviewProvider);
    final transports = ref.watch(transportsProvider);
    final utterance = composeContextUtterance(loc, overview, transports);
    return CopilotChatScreen(initialUtterance: utterance);
  }

  /// Composes the context-seeding utterance.
  ///
  /// Prefers the current trip overview (`origin → destination`); falls back
  /// to the first assigned transport (load info, then origin → destination).
  /// Returns `null` when there is no data — the copilot then behaves as
  /// today.
  @visibleForTesting
  static String? composeContextUtterance(
    AppLocalizations loc,
    AsyncValue<DriverTripOverview> overview,
    AsyncValue<List<Transport>> transports,
  ) {
    final trip = overview.valueOrNull;
    if (trip != null &&
        (trip.origin?.isNotEmpty ?? false) &&
        (trip.destination?.isNotEmpty ?? false)) {
      return loc.driver_copilotContextTrip(trip.origin!, trip.destination!);
    }
    final list = transports.valueOrNull;
    if (list != null && list.isNotEmpty) {
      final transport = list.first;
      if (transport.loadInfo.isNotEmpty) {
        return loc.driver_copilotContextTransport(transport.loadInfo);
      }
      return loc.driver_copilotContextTrip(
        transport.origin,
        transport.destination,
      );
    }
    return null;
  }
}
