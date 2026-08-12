import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:operion_mobile/core/i18n/app_localizations.dart';
import 'package:operion_mobile/features/route_planner/providers/route_planner_providers.dart';
import 'package:operion_mobile/features/route_planner/screens/route_planner_screen.dart';

/// Helper: wraps [child] in MaterialApp with localisations so that
/// `context.loc` works.
Widget wrapRoutePlanner() {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const RoutePlannerScreen(),
  );
}

void main() {
  // ==========================================================================
  // Initial state
  // ==========================================================================
  group('RoutePlannerScreen — initial state', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      expect(find.text('Route Planner'), findsOneWidget);
    });

    testWidgets('renders origin and destination text fields', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('shows origin and destination labels', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      expect(find.text('Origin'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
    });

    testWidgets('shows stop count as 0 initially', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      expect(find.text('Stops (0)'), findsOneWidget);
    });

    testWidgets('optimize button is on screen', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      expect(find.text('Optimize Route'), findsOneWidget);
    });
  });

  // ==========================================================================
  // Empty state — no waypoints
  // ==========================================================================
  group('RoutePlannerScreen — empty waypoints', () {
    testWidgets('shows empty state when no stops added', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      expect(find.text('No stops added'), findsOneWidget);
      expect(
        find.text('Add intermediate stops to optimize your route.'),
        findsOneWidget,
      );
    });

    testWidgets('shows add stop button', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      expect(find.text('Add Stop'), findsOneWidget);
    });
  });

  // ==========================================================================
  // Waypoint management
  // ==========================================================================
  group('RoutePlannerScreen — waypoints', () {
    testWidgets('adding a waypoint increments stop count', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Stop'));
      await tester.pumpAndSettle();

      expect(find.text('Stops (1)'), findsOneWidget);
      expect(find.text('Stop 1'), findsOneWidget);
    });

    testWidgets('adding multiple waypoints shows each stop', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Stop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Stop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Stop'));
      await tester.pumpAndSettle();

      expect(find.text('Stops (3)'), findsOneWidget);
      expect(find.text('Stop 1'), findsOneWidget);
      expect(find.text('Stop 2'), findsOneWidget);
      expect(find.text('Stop 3'), findsOneWidget);
    });

    testWidgets('removing a waypoint decreases stop count', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      // Add two stops
      await tester.tap(find.text('Add Stop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Stop'));
      await tester.pumpAndSettle();

      expect(find.text('Stops (2)'), findsOneWidget);

      // Remove the first stop using the trash2 icon (LucideIcons.trash2)
      await tester.tap(find.byIcon(LucideIcons.trash2).last);
      await tester.pumpAndSettle();

      expect(find.text('Stops (1)'), findsOneWidget);
    });
  });

  // ==========================================================================
  // Origin/destination input
  // ==========================================================================
  group('RoutePlannerScreen — origin/destination', () {
    testWidgets('accepts origin address input', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'Bucharest');
      await tester.pumpAndSettle();

      expect(find.text('Bucharest'), findsOneWidget);
    });

    testWidgets('accepts destination address input', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.last, 'Cluj-Napoca');
      await tester.pumpAndSettle();

      expect(find.text('Cluj-Napoca'), findsOneWidget);
    });

    testWidgets('optimize button is present when origin and destination are filled',
        (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'Bucharest');
      await tester.enterText(fields.last, 'Cluj-Napoca');
      await tester.pumpAndSettle();

      // Button should still be on screen
      expect(find.text('Optimize Route'), findsOneWidget);
    });
  });

  // ==========================================================================
  // Pull-to-refresh (form-reset semantics, §1.2)
  // ==========================================================================
  group('RoutePlannerScreen — pull-to-refresh', () {
    testWidgets('RefreshIndicator is present on the form', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('pull-to-refresh resets the form to its initial state',
        (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      // Fill the form: origin, destination, one waypoint.
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'Bucharest');
      await tester.enterText(fields.last, 'Cluj-Napoca');
      await tester.tap(find.text('Add Stop'));
      await tester.pumpAndSettle();

      expect(find.text('Stops (1)'), findsOneWidget);
      expect(find.text('Bucharest'), findsOneWidget);
      expect(find.text('Cluj-Napoca'), findsOneWidget);

      // Pull down to refresh.
      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      // The form is back to its initial state.
      expect(find.text('Stops (0)'), findsOneWidget);
      expect(find.text('Bucharest'), findsNothing);
      expect(find.text('Cluj-Napoca'), findsNothing);
    });
  });

  // ==========================================================================
  // §2 Feature-parity — routing profile selector
  // ==========================================================================
  group('RoutePlannerScreen — profile selector (§2)', () {
    testWidgets('renders the three backend-supported profiles', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      expect(find.text('Truck'), findsOneWidget);
      expect(find.text('Car'), findsOneWidget);
      expect(find.text('Pedestrian'), findsOneWidget);
    });

    testWidgets('switching profiles keeps the form working', (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Car'));
      await tester.pumpAndSettle();

      // Profile selection doesn't break the rest of the form.
      expect(find.text('Origin'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
    });
  });

  // ==========================================================================
  // §2 Feature-parity — countries to avoid
  // ==========================================================================
  group('RoutePlannerScreen — countries to avoid (§2)', () {
    testWidgets('opens the country picker sheet with the EU-27 list',
        (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Select countries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select countries'));
      await tester.pumpAndSettle();

      // Sheet title (matches the form section header key — appears twice once
      // the sheet opens) + a representative sample of the fixed EU list.
      expect(find.text('Countries to avoid'), findsNWidgets(2));
      expect(find.text('RO'), findsOneWidget);
      expect(find.text('DE'), findsOneWidget);
      expect(find.text('FR'), findsOneWidget);
    });

    testWidgets('selecting countries adds removable chips to the form',
        (tester) async {
      await tester.pumpWidget(wrapRoutePlanner());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Select countries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select countries'));
      await tester.pumpAndSettle();

      // Toggle RO + DE on and close the sheet (scroll each into view first).
      await tester.ensureVisible(find.text('DE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DE'));
      await tester.pump();
      await tester.ensureVisible(find.text('RO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RO'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Selected chips appear on the form with the count.
      expect(find.text('Select countries (2)'), findsOneWidget);
      expect(find.byType(InputChip), findsNWidgets(2));

      // Removing a chip updates the selection.
      await tester.tap(
        find
            .descendant(
              of: find.byType(InputChip).first,
              matching: find.byType(Icon),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Select countries (1)'), findsOneWidget);
    });

    test('buildRouteRequest includes excluded_countries only when selected',
        () {
      expect(
        buildRouteRequest(['A', 'B'], profile: 'truck'),
        {'points': ['A', 'B'], 'profile': 'truck'},
      );
      expect(
        buildRouteRequest(['A', 'B'], excludedCountries: ['HU']),
        {
          'points': ['A', 'B'],
          'profile': 'truck',
          'excluded_countries': ['HU'],
        },
      );
    });
  });
}
