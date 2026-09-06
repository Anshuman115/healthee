/// **v02's type scale, transcribed from the prototype's CSS.**
///
/// `typography.dart` builds the Material [TextTheme] the un-migrated screens are
/// written against; this file is the scale the v02 primitives use, and the two
/// coexist on purpose. Remapping `displayLarge` from 34 to v02's 88 would resize
/// every hero figure on every screen that has not been redesigned yet — a
/// restyle by side effect, and the phase boundary says no. When a screen moves to
/// v02 it moves onto these styles; when the last one has, `healtheeTextTheme`'s
/// role sizes go.
///
/// **Every style here is colourless.** The tone system supplies the colour at the
/// point of use (`context.family`, `context.colors.ink2`), so a style cannot
/// carry a hue that disagrees with the card it is in.
///
/// Sizes and tracking are the CSS's, to the pixel:
///
/// ```text
///   page h1        27px  -1px      richer.css .page-header h1
///   section h2     18px  -0.6px    richer.css .section-head h2 (size) + styles.css h2
///   panel title    13px  700       richer.css .panel-title
///   panel value    36px  600  -1.8 richer.css .panel-value
///   bio age        88px  600  -6   richer.css .bio-hero .age-value
///   tile value     24px       -1   richer.css .summary-tile strong
///   labels         8.5–11px        tile-meta · colour-key · panel-note · text-button
/// ```
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
  height: height,
  letterSpacing: tracking,
  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
);

/// v02's type scale. Colourless; see the library docstring.
abstract final class TypeScale {
  /// `.page-header h1` — the screen's name.
  static final TextStyle pageTitle = _style(
    27,
    FontWeight.w600,
    height: 1.2,
    tracking: -1,
  );

  /// `.page-header .date` — the date above it.
  static final TextStyle pageDate = _style(11, FontWeight.w500);

  /// `.section-head h2` — a section's name.
  static final TextStyle sectionTitle = _style(
    18,
    FontWeight.w700,
    height: 1.4,
    tracking: -0.6,
  );

  /// `.panel-title` — a panel's own title, beside its icon.
  static final TextStyle panelTitle = _style(13, FontWeight.w700, height: 1.35);

  /// `.panel-value` — the number a panel exists to show.
  static final TextStyle panelValue = _style(
    36,
    FontWeight.w600,
    height: 1.2,
    tracking: -1.8,
  );

  /// `.panel-value > small` — its unit.
  static final TextStyle panelUnit = _style(12, FontWeight.w400, height: 1.2);

  /// `.panel-note` — the sentence under a panel's chart.
  static final TextStyle panelNote = _style(11, FontWeight.w400, height: 1.7);

  /// `.panel .text-button` — a panel head's action.
  static final TextStyle textButton = _style(11, FontWeight.w700, height: 1.2);

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

  /// `.bio-hero .age-context` — the sentence under the figure.
  static final TextStyle bioContext = _style(12, FontWeight.w400);

  /// `.bio-bottom strong` — a hero footer statistic.
  static final TextStyle bioStat = _style(17, FontWeight.w600, height: 1.3);

  /// `.bio-bottom span` — its label.
  static final TextStyle bioStatLabel = _style(10, FontWeight.w400, height: 1.4);

  /// `.bio-hero .model-label` — which instrument produced the figure.
  static final TextStyle modelLabel = _style(9, FontWeight.w400, height: 1.4);

  /// `.summary-tile .tile-title` — a tile's label, in its family colour.
  static final TextStyle tileTitle = _style(10, FontWeight.w400, height: 1.4);

  /// `.summary-tile strong` — a tile's number.
  static final TextStyle tileValue = _style(
    24,
    FontWeight.w700,
    height: 1.2,
    tracking: -1,
  );

  /// `.summary-tile .tile-meta` — the qualifier under it.
  static final TextStyle tileMeta = _style(8.5, FontWeight.w400, height: 1.4);

  /// `.colour-key` — a legend entry.
  static final TextStyle colourKey = _style(10, FontWeight.w400, height: 1.4);

  /// `.context-bridge p` — the connective sentence between two panels.
  static final TextStyle bridge = _style(11, FontWeight.w400, height: 1.8);
}
