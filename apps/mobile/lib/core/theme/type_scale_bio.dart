/// **v02's type scale, fourth seam: the biological-age hero.**
///
/// Split out of `type_scale.dart` at the 400-line gate (Standards section 1),
/// the same way `type_scale_forms.dart` and `type_scale_dates.dart` were. These
/// nine sizes belong to ONE instrument — the bio hero and its withheld variant —
/// and four files in `shared/v02/` use them, none of which draws a panel.
///
/// **Colourless**, like the rest of the scale.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/typography.dart';

TextStyle _style(
  double size,
  FontWeight weight, {
  double height = 1.6,
  double tracking = 0,
}) => TextStyle(
  fontFamily: healtheeFontFamily,
  fontFamilyFallback: healtheeFontFallback,
  fontSize: size,
  fontWeight: weight,
  // Figtree is variable: drive the wght axis, not only the weight slot.
  fontVariations: <FontVariation>[FontVariation('wght', weight.value.toDouble())],
  height: height,
  letterSpacing: tracking,
  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
);

/// The bio hero's scale. Colourless; see the library docstring.
abstract final class BioType {
  /// `.bio-hero .bio-eyebrow` — the hero's label row.
  static final TextStyle bioEyebrow = _style(12, FontWeight.w600, height: 1.4);

  /// `.bio-hero .age-value` — the one 88px figure in the product.
  static final TextStyle bioAge = _style(
    88,
    FontWeight.w600,
    height: 1,
    tracking: -6,
  );

  /// `.bio-hero .age-value small` — its unit.
  static final TextStyle bioAgeUnit = _style(13, FontWeight.w400, height: 1);

  /// `motion.css`'s override: the figure centred inside the halo, 84 not 88.
  static final TextStyle bioAgeCentred = _style(
    84,
    FontWeight.w600,
    height: 1,
    tracking: -5,
  );

  /// `motion.css`: `small { display:block; font-size:11px; letter-spacing:1px }`.
  static final TextStyle bioAgeUnitCentred = _style(
    11,
    FontWeight.w400,
    height: 1.4,
    tracking: 1,
  );

  /// `.bio-hero .age-context` — the sentence under the figure.
  static final TextStyle bioContext = _style(12, FontWeight.w400);

  /// `.bio-bottom strong` — a hero footer statistic.
  static final TextStyle bioStat = _style(17, FontWeight.w600, height: 1.3);

  /// `.bio-bottom span` — its label.
  static final TextStyle bioStatLabel = _style(10, FontWeight.w400, height: 1.4);

  /// `.bio-hero .model-label` — which instrument produced the figure.
  static final TextStyle modelLabel = _style(9, FontWeight.w400, height: 1.4);
}
