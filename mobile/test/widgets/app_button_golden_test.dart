import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/shared/widgets/app_button.dart';

/// Wraps [child] in a [MaterialApp] with a constrained width for golden captures.
Widget wrapForGolden(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 300, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('AppButton primary golden', (tester) async {
    await tester.pumpWidget(wrapForGolden(
      AppButton.primary(label: 'Sign In', onPressed: () {}),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AppButton),
      matchesGoldenFile('app_button_primary.png'),
    );
  });

  testWidgets('AppButton secondary golden', (tester) async {
    await tester.pumpWidget(wrapForGolden(
      AppButton.secondary(label: 'Cancel', onPressed: () {}),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AppButton),
      matchesGoldenFile('app_button_secondary.png'),
    );
  });

  testWidgets('AppButton disabled golden', (tester) async {
    await tester.pumpWidget(wrapForGolden(
      AppButton.primary(label: 'Disabled', onPressed: null),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AppButton),
      matchesGoldenFile('app_button_disabled.png'),
    );
  });

  testWidgets('AppButton loading golden', (tester) async {
    await tester.pumpWidget(wrapForGolden(
      AppButton.primary(label: 'Loading', onPressed: () {}, isLoading: true),
    ));
    // The loading spinner animates indefinitely, so pumpAndSettle would never
    // settle. Advance to a fixed, deterministic frame for the golden capture.
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(AppButton),
      matchesGoldenFile('app_button_loading.png'),
    );
  });
}
