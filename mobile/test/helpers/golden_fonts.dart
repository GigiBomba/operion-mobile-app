import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Returns the platform-suffixed golden filename for [name].
///
/// Flutter golden PNGs containing real text are NOT portable across operating
/// systems: even with the same Flutter SDK and identical bundled static
/// fonts, Windows and Linux rasterize glyph edges differently (mean delta
/// ~55, spread across text rows — text-only goldens fail too). Tests compare
/// against `*-windows.png` when run on Windows and `*-linux.png` when run on
/// Linux (the CI runner); both sets are committed and CI's `--update-goldens`
/// run produces the Linux set.
String goldenFile(String name) =>
    '$name-${Platform.isLinux ? 'linux' : 'windows'}.png';

/// Loads the bundled static Inter fonts into the test font registry so golden
/// tests render deterministic glyphs on every machine.
///
/// Why this exists: screens use `GoogleFonts.interTextTheme()`
/// (lib/core/theme/app_typography.dart). On machines where google_fonts has
/// Inter cached, goldens render real Inter glyphs; on fresh CI runners the
/// fetch is blocked at test time and google_fonts falls back to the default
/// font — producing text-only pixel diffs.
///
/// Why STATIC per-weight TTFs (not the variable font): variable-font instance
/// resolution (opsz/wght axes) and hinting differ between the Windows engine
/// (where goldens are regenerated) and the Linux CI engine, and a family
/// registered without explicit weights collapses every requested weight to
/// the default instance. The static Inter-Regular/Medium/SemiBold/Bold TTFs
/// carry correct OS/2 weights, so a single [FontLoader] per family with all
/// four fonts lets the engine match the requested TextStyle weight to the
/// right file — identical rendering on Windows and Linux.
///
/// The same four files are ALSO registered as 'Roboto' (Material's default
/// font family in the test environment) so any widget that does NOT go
/// through GoogleFonts — e.g. plain `ThemeData(brightness:)` tests, AppBar
/// titles, `DefaultTextStyle` — renders the same deterministic glyphs.
Future<void> loadGoldenFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;

  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Inter-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf'));
  await inter.load();

  final roboto = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Inter-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Inter-Bold.ttf'));
  await roboto.load();
}
