/// The type system: Inter, and tabular figures wherever a number lives.
///
/// ## Tabular figures are on by default, and that is a correctness decision
///
/// This app's screens are columns of numbers that change every day. With
/// proportional figures a 1 is narrower than an 8, so a resting heart rate moving
/// 55 → 58 shifts every glyph beside it and a 30-night strip visibly ripples as
/// you scroll. `FontFeature.tabularFigures()` fixes every digit to one advance
/// width, so columns line up and a changing value does not move its neighbours.
///
/// `docs/APP_DESIGN_BRIEF.md` §7 makes it a hard constraint — *"Tabular figures
/// everywhere. Non-tabular numerals in a metric column is a defect."* It is
/// applied to the whole [TextTheme] rather than to a numeric style, because the
/// alternative is remembering, and a number set in the wrong style is exactly the
/// kind of miss nobody files a bug for. Prose loses nothing.
///
/// ## The scale is the approved design's, measured rather than invented
///
/// Brief §2: "Sizes run 10–18px for body and labels, 26–34px for hero figures."
/// The sizes below are the ones `Healthee.html` actually uses, whose histogram
/// clusters at 10–15 for body and labels and 26–34 for hero figures. Weight sits
/// at 600 far more often than 700 — this is an instrument, and hierarchy comes
/// from weight and spacing rather than from large type.
///
/// ## The face is Inter — it replaced Manrope, which replaced Instrument Sans
///
/// Owner decision 2026-08-05: *Instrument Sans reads "newspaper" at display
/// sizes.* It does — its high-contrast, tight-apertured caps carry an editorial
/// texture, which is the one direction `docs/APP_DESIGN_BRIEF.md` §2 rules out by
/// name ("modern instrument. **Not editorial**"). Both replacements are the
/// opposite build:
/// open apertures, near-uniform stroke, a wide and untroubled `0`.
///
/// **The old family is deleted, not left beside the new one.** Two vendored
/// families is two things a `TextStyle` can name and one of them wrong, and the
/// wrongness is invisible — a stray `fontFamily: 'Instrument Sans'` would render
/// perfectly and simply not be the app's face.
///
/// Two measurements came with the swap, because a face is not a drop-in:
///
///   * **Tabular figures survive.** Inter ships `tnum`, which is what
///     [FontFeature.tabularFigures] selects. That mattered more than the face —
///     brief §7 makes it a hard constraint, and a face without it would have been
///     rejected whatever it looked like.
///   * **Inter runs narrower than Manrope**, so display-size strings gained
///     room rather than losing it; the widths were re-checked
///     against overflow (`test/core/typography_test.dart`), and the subscript in
///     `SpO₂` was checked for a glyph. Instrument Sans **had none** — U+2082 drew
///     a tofu box on the live screen, as did the `σ` in the recovery ladder's
///     caption. Inter covers both, and covers the arrows Manrope did not.
///
/// ## The font is vendored, not fetched
///
/// `assets/fonts/` holds four weights of Inter (SIL OFL, no Reserved Font
/// Name; see the OFL.txt beside them), instanced from upstream's variable font at
/// the exact weights below. Bundling costs ~290 KB and buys a binary with no
/// network dependency at paint time, against a cold-start budget of 2 s to first
/// meaningful paint (Standards §1).
///
/// [healtheeFontFallback] still names the platform faces, so a failed asset
/// degrades to the system font rather than to Flutter's fallback box glyphs.
library;

import 'package:flutter/material.dart';

/// The bundled family name, as declared in pubspec.yaml.
///
/// **Inter, replacing Manrope on 2026-09-07.** The owner, looking at the
/// installed build: *"choose some other better font manrope is not looking good
/// as well."*
///
/// Inter is also what removes the emoji-arrow defect at its source rather than
/// routing around it. Manrope is a text-only family: verified against its own
/// `cmap`, it has **no `↔` (U+2194)** and **no `↗` (U+2197)**, so Android went
/// looking and the platform face that covers U+2194 is `NotoColorEmoji`. Inter
/// carries both, so the fallback below is now defence rather than the fix.
///
/// It also keeps what the type scale depends on: `tnum` tabular figures, so
/// columns of numbers stay aligned, and the four weights the scale asks for.
const String healtheeFontFamily = 'Inter';

/// Faces to fall back on, in order, when the bundled family has no glyph.
///
/// ## The text faces, and why the symbol faces are here too
///
/// The first group is the platform UI font, so a failed asset degrades to the
/// system face rather than to Flutter's fallback box glyphs.
///
/// The second group exists because of a defect Manrope shipped. Manrope is a
/// text family and covered none of the symbols this app draws: no `↔` (U+2194),
/// no `↗` (U+2197), no `ⓘ` (U+24D8), no `⌄` (U+2304). Android's `Roboto` has
/// **none of the arrows either**, so naming it alone left the chain to the
/// platform default — and the platform default that covers U+2194 is
/// **`NotoColorEmoji`**.
///
/// That is how `Overnight HRV ↔ recovery` shipped with a blue emoji box in the
/// middle of a sentence. `U+FE0E`, the text-presentation selector, cannot fix
/// it: the selector chooses between two presentations **within a font that has
/// the glyph**, and it cannot conjure a text form in a font that lacks the
/// codepoint entirely.
///
/// **Inter carries both arrows, so it is the actual fix.** These symbol faces
/// stay as defence: `fontFamilyFallback` is consulted in full before the
/// platform chain, so a glyph the bundled family lacks reaches a monochrome
/// face before it can reach the colour emoji font.
/// `test/theme/font_coverage_test.dart` reads the bundled `.ttf` and fails if
/// a character the app actually draws is covered by neither.
const List<String> healtheeFontFallback = <String>[
  // Text.
  'SF Pro Text', // iOS
  'Roboto', // Android
  'Segoe UI',
  'Helvetica Neue',
  'Arial',
  // Symbols — monochrome, and ahead of the platform's colour emoji font.
  'Noto Sans Symbols', // Android
  'Segoe UI Symbol', // Windows
  'Apple Symbols', // iOS / macOS
];

/// Every digit at one advance width.
const List<FontFeature> _numericFeatures = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// The app's text theme, coloured for the three ink roles.
///
/// Styles are named for ROLE, not size. [ink3] carries labels, units and captions
/// — the marginalia that must not compete with the number it annotates.
TextTheme healtheeTextTheme({
  required Color ink,
  required Color ink2,
  required Color ink3,
}) {
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
    // Hero figures — the recovery score, the VO₂max estimate.
    displayLarge: style(34, FontWeight.w600, ink, 1.05, -0.022 * 34),
    displayMedium: style(26, FontWeight.w600, ink, 1.1, -0.02 * 26),
    // Screen and section headings.
    headlineMedium: style(18, FontWeight.w600, ink, 1.25, -0.012 * 18),
    headlineSmall: style(17, FontWeight.w600, ink, 1.3, -0.01 * 17),
    // A card's own title.
    titleMedium: style(15, FontWeight.w600, ink, 1.35, 0),
    titleSmall: style(13.5, FontWeight.w600, ink, 1.35, 0),
    // Prose. `bodyMedium` is the app's default paragraph.
    bodyLarge: style(15, FontWeight.w400, ink, 1.5, 0),
    bodyMedium: style(13, FontWeight.w400, ink2, 1.5, 0),
    bodySmall: style(12, FontWeight.w400, ink2, 1.45, 0),
    // Units, captions, chips — the instrument's marginalia.
    labelLarge: style(13, FontWeight.w600, ink, 1.2, 0),
    labelMedium: style(11.5, FontWeight.w500, ink2, 1.3, 0.01 * 11.5),
    labelSmall: style(10.5, FontWeight.w500, ink3, 1.3, 0.04 * 10.5),
  );
}
