/// The type system: Figtree, and tabular figures wherever a number lives.
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
/// **Figtree, chosen by the owner on 2026-09-07** after Inter ("not good") and
/// Plus Jakarta Sans ("numbers too elongated"). The brief was "circular clean",
/// and Figtree is the only geometric face of that shape that survives what this
/// app actually draws: it keeps `₂` (SpO₂, VO₂max) and tabular figures, where
/// DM Sans, Outfit, Poppins and Jost each lose one or both.
///
/// The elongation complaint was real and measurable: Plus Jakarta's digits are
/// **0.769 em tall**, the tallest of twenty-one faces measured, against a
/// typical 0.72. Figtree's are 0.724 with a rounder 0.74 width-to-height ratio.
///
/// It is a VARIABLE font shipped as one file; `_style` drives the `wght` axis
/// directly rather than relying on four static instances.
const String healtheeFontFamily = 'Figtree';

/// Faces to fall back on, in order, when Figtree has no glyph for a character.
///
/// ## The first entry is BUNDLED, and that is the whole point
///
/// Figtree has no `↔` (U+2194) — nor `⌄`, `ρ`, `σ` or `ⓘ`. The app draws all of
/// them.
///
/// An earlier revision named platform symbol faces here (`Noto Sans Symbols`
/// and friends) and asserted that `fontFamilyFallback` is consulted before the
/// platform chain, so the colour emoji font could never be reached. **That was
/// never tested, because the face at the time was Inter, which HAS U+2194 — the
/// fallback never ran.** The moment Figtree shipped, `Overnight HRV ↔ recovery`
/// drew a blue emoji box again, on the device, exactly as before.
///
/// So [HealtheeSymbols] is a **bundled** family (Inter, in `assets/fonts/`),
/// named first. A bundled family is resolved by the engine's own font manager
/// rather than the platform's, and it does beat `NotoColorEmoji` — verified on
/// the device, which is the only way this has ever been established.
///
/// The platform faces stay behind it as a second line, and cost nothing.
///
/// `test/core/typography_test.dart` walks `lib/` and fails if a character the
/// app writes is covered by neither the bundled face nor the bundled fallback.
const List<String> healtheeFontFallback = <String>[
  // Bundled. Complete. Load-bearing — see above.
  'HealtheeSymbols',
  // Platform text faces, for the case where the bundled asset fails entirely.
  'SF Pro Text', // iOS
  'Roboto', // Android
  'Segoe UI',
  'Helvetica Neue',
  'Arial',
  // Platform symbol faces. Kept, but NOT relied on.
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
  // Figtree is variable: drive the wght axis, not only the weight slot.
  fontVariations: <FontVariation>[FontVariation('wght', weight.value.toDouble())],
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
