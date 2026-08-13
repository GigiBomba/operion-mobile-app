import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Loads the bundled Inter font into the test font registry so golden tests
/// render deterministic glyphs on every machine.
///
/// Why this exists: screens use `GoogleFonts.interTextTheme()`
/// (lib/core/theme/app_typography.dart). On machines where google_fonts has
/// Inter cached, goldens render real Inter glyphs; on fresh CI runners the
/// fetch is blocked at test time and google_fonts falls back to the default
/// font — producing text-only pixel diffs. By disabling runtime fetching and
/// registering the bundled TTF ourselves, both local and CI render the SAME
/// glyphs.
///
/// The same TTF is ALSO registered as 'Roboto' (Material's default font
/// family in the test environment) so any widget that does NOT go through
/// GoogleFonts — e.g. raw `Text` using the default `TextTheme` — still
/// renders the identical Inter glyphs. Every text pixel in the goldens is
/// therefore deterministic regardless of which font path a widget uses.
Future<void> loadGoldenFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  await inter.load();
  final roboto = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  await roboto.load();
}
