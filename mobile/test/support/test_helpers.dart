import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Forces a phone-size (390x844 @1x) test surface.
///
/// The app's tablet master-detail layout (blueprint §9) engages at widths
/// ≥600dp. `flutter test` defaults to an 800x600 logical surface, which would
/// accidentally exercise the tablet path in phone-behaviour tests. Call this
/// at the start of any `testWidgets` that asserts phone single-pane behavior.
/// Resets automatically after the test.
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
