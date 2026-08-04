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

/// Corner radii, taken from the approved design.
///
/// Brief §2 asks for "generous radii, almost no shadow — depth from spacing and
/// contrast". These are the values `Healthee.html` actually uses; 16 is by far
/// the most common and is the card.
abstract final class Radii {
  /// 16 — cards, sheets, the illness banner.
  static const double card = 16;

  /// 10 — buttons, and the value-shaped hole in a withheld card.
  static const double button = 10;

  /// 8 — chips and small stamps.
  static const double chip = 8;

  /// 6 — an inline hole, sitting on a single row.
  static const double inlineHole = 6;

  /// Fully rounded — pills, progress tracks, dots.
  static const double pill = 999;
}

/// The one border width the design uses for a rule or a card edge.
const double hairline = 1;
