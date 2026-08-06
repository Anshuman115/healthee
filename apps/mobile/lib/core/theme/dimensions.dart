/// Spacing, radii and rule widths — the non-colour half of the token set.
///
/// Split out of `tokens.dart` when the colour roles grew: that file's one reason
/// to change is the palette, and this one's is the geometry (Standards §1).
library;

/// Spacing scale. One rhythm, so gaps compose instead of accumulating.
abstract final class Insets {
  /// 4 — hairline gaps, chip padding.
  static const double xs = 4;

  /// 8 — between a label and its value.
  static const double sm = 8;

  /// 12 — inside a dense row.
  static const double md = 12;

  /// 15 — the standard card padding in the approved design.
  static const double lg = 15;

  /// 24 — between cards.
  static const double xl = 24;

  /// 32 — between sections.
  static const double xxl = 32;
}

/// Corner radii — **legacy's ladder**, `theme.dart`'s `HRadius`.
///
/// Legacy names its rungs by size (`sm 10 · md 14 · lg 16 · xl 24 · pill`);
/// these are named by what wears them, which is the same five numbers plus two
/// the honesty layer needs. Every radius is drawn as a **continuous-corner
/// squircle** (`shapes.dart`), never a circular arc.
abstract final class Radii {
  /// 16 — legacy's `lg`: every module, card and banner.
  static const double card = 16;

  /// 24 — legacy's `xl`: sheets.
  static const double sheet = 24;

  /// 14 — legacy's `md`: badges and small tinted blocks.
  static const double badge = 14;

  /// 10 — legacy's `sm`: buttons, and the value-shaped hole in a withheld card.
  static const double button = 10;

  /// 8 — chips and small stamps. Below legacy's ladder; the honesty layer's own.
  static const double chip = 8;

  /// 6 — an inline hole, sitting on a single row.
  static const double inlineHole = 6;

  /// Fully rounded — pills, progress tracks, dots. Legacy's `pill`.
  static const double pill = 999;
}

/// The one border width the design uses for a rule or a card edge.
const double hairline = 1;
