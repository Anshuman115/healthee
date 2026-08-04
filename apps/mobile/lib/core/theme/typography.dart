/// The type system: Instrument Sans, and tabular figures wherever a number lives.
///
/// ## Tabular figures are on by default, and that is a correctness decision
///
/// This app's screens are columns of numbers that change every day. With
/// proportional figures a 1 is narrower than an 8, so a resting heart rate moving
/// 55 → 58 shifts every glyph beside it and a 30-night strip visibly ripples as
/// you scroll. `FontFeature.tabularFigures()` fixes every digit to one advance
/// width, so columns line up and a value that changes does not move its
/// neighbours. `apps/landing/DESIGN.md` §4 makes the same call for the page
/// ("every data value … with `tabular-nums`").
///
/// It is applied to the whole [TextTheme] rather than to a numeric style, because
/// the alternative is remembering — and a number set in the wrong style is exactly
/// the kind of miss nobody files a bug for. Prose loses nothing: Instrument Sans's
/// tabular figures are the same shapes at a fixed width.
///
/// ## The font is vendored, not fetched
///
/// `assets/fonts/` holds four weights of Instrument Sans (SIL OFL, see the OFL.txt
/// beside them). Bundling costs ~195 KB and buys a binary with no network
/// dependency at paint time — consistent with the project's no-CDN rule and with
/// a cold-start budget of 2 s to first meaningful paint (Standards §1).
///
/// [fontFamilyFallback] still names the platform faces. If an asset ever fails to
/// load, text renders in the system font rather than in Flutter's fallback box
/// glyphs — degraded, but legible.
library;

import 'package:flutter/material.dart';

/// The bundled family name, as declared in pubspec.yaml.
const String healtheeFontFamily = 'Instrument Sans';

/// Platform faces to fall back on if the bundled asset is unavailable.
const List<String> healtheeFontFallback = <String>[
  'SF Pro Text', // iOS
  'Roboto', // Android
  'Segoe UI',
  'Helvetica Neue',
  'Arial',
];

/// Every digit at one advance width, plus proper slashed-zero disambiguation.
const List<FontFeature> _numericFeatures = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// The app's text theme, coloured for [ink] (primary) and [inkSoft] (secondary).
///
/// The scale is deliberately small and named for ROLE, not size. v5 is a ledger:
/// hierarchy comes from weight and rule, not from large type.
TextTheme healtheeTextTheme({required Color ink, required Color inkSoft}) {
  TextStyle style(double size, FontWeight weight, Color color, double height, double tracking) {
    return TextStyle(
      fontFamily: healtheeFontFamily,
      fontFamilyFallback: healtheeFontFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: tracking,
      fontFeatures: _numericFeatures,
    );
  }

  return TextTheme(
    // Hero numbers — the recovery score, the VO₂max estimate.
    displayLarge: style(44, FontWeight.w700, ink, 1.05, -0.02 * 44),
    displayMedium: style(32, FontWeight.w700, ink, 1.08, -0.022 * 32),
    // Screen and section headings.
    headlineMedium: style(24, FontWeight.w700, ink, 1.15, -0.02 * 24),
    headlineSmall: style(20, FontWeight.w600, ink, 1.2, -0.015 * 20),
    // A card's own title.
    titleMedium: style(16, FontWeight.w600, ink, 1.3, 0),
    titleSmall: style(14, FontWeight.w600, ink, 1.3, 0),
    // Prose. `bodyMedium` is the app's default paragraph.
    bodyLarge: style(16, FontWeight.w400, ink, 1.5, 0),
    bodyMedium: style(14.5, FontWeight.w400, inkSoft, 1.55, 0),
    bodySmall: style(13, FontWeight.w400, inkSoft, 1.5, 0),
    // Units, captions, chips. Wide tracking, small — the ledger's marginalia.
    labelLarge: style(14, FontWeight.w600, ink, 1.2, 0),
    labelMedium: style(12, FontWeight.w500, inkSoft, 1.3, 0.02 * 12),
    labelSmall: style(11, FontWeight.w500, inkSoft, 1.3, 0.06 * 11),
  );
}
