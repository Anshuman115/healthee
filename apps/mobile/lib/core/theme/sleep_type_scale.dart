/// The Sleep screen's own v02 type, transcribed from `richer.css`.
///
/// These belong with [TypeScale] and are only in a second file because that one
/// is 364 lines against the standards' 400-line ceiling; a screen-shaped block
/// of fifteen more styles would have pushed it over. Nothing here invents a
/// size — every entry names the rule it came from, the same way `TypeScale`'s
/// do, and a call site uses whichever of the two files has the rule it needs.
///
/// ```css
/// .sleep-reading .big-duration        { font-size:64px; line-height:1;
///                                       font-weight:600; letter-spacing:-3px }
/// .sleep-reading .big-duration small  { font-size:22px; font-weight:400 }
/// .sleep-device strong                { font-size:27px }
/// .sleep-device span                  { font-size:9px }
/// .sleep-check h3                     { font-size:12px }   /* h3 → bold */
/// .sleep-check strong                 { font-size:13px }
/// .check-target                       { font-size:11px }
/// .check-detail                       { font-size:10px; line-height:1.7 }
/// .check-result                       { font-size:18px; font-weight:600 }
/// .data-table                         { font-size:11px }
/// .vital-row .vital-label             { font-size:11px }
/// .vital-row strong                   { font-size:14px }
/// .vital-row strong small             { font-size:9px; font-weight:400 }
/// @media(max-width:359px) .sleep-reading .big-duration { font-size:54px }
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
  // Figtree is variable: drive the wght axis, not only the weight slot.
  fontVariations: <FontVariation>[FontVariation('wght', weight.value.toDouble())],
  height: height,
  letterSpacing: tracking,
  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
);

/// The Sleep screen's type, in v02's own sizes.
abstract final class SleepType {
  /// `.sleep-reading .big-duration` — the night's headline figure.
  static final TextStyle duration = _style(
    64,
    FontWeight.w600,
    height: 1,
    tracking: -3,
  );

  /// The same figure under the prototype's 359 px breakpoint.
  static final TextStyle durationNarrow = _style(
    54,
    FontWeight.w600,
    height: 1,
    tracking: -3,
  );

  /// `.sleep-reading .big-duration small` — the `h` and the `m`, in the family.
  static final TextStyle durationUnit = _style(22, FontWeight.w400, height: 1);

  /// `.sleep-device strong` — the strap's own score.
  static final TextStyle deviceScore = _style(27, FontWeight.w600, height: 1.2);

  /// `.sleep-device span` — the two lines naming that instrument.
  static final TextStyle deviceCaption = _style(9, FontWeight.w400, height: 1.5);

  /// `.sleep-check h3` — one check's name.
  static final TextStyle checkName = _style(
    12,
    FontWeight.w700,
    height: 1.5,
    tracking: -0.2,
  );

  /// `.sleep-check strong` — its reading.
  static final TextStyle checkValue = _style(13, FontWeight.w700, height: 1.5);

  /// `.check-target` — the published range it was read against.
  static final TextStyle checkTarget = _style(11, FontWeight.w400, height: 1.5);

  /// `.check-detail` — how far outside it, in words.
  static final TextStyle checkDetail = _style(10, FontWeight.w400, height: 1.7);

  /// `.check-result` — the tick, or the dash that is not one.
  static final TextStyle checkMark = _style(18, FontWeight.w600, height: 1);

  /// `.data-table th` and `td`.
  static final TextStyle tableCell = _style(11, FontWeight.w400, height: 1.5);

  /// `.vital-row .vital-label`.
  static final TextStyle vitalLabel = _style(11, FontWeight.w400, height: 1.4);

  /// `.vital-row strong`.
  static final TextStyle vitalValue = _style(14, FontWeight.w700, height: 1.3);

  /// `.vital-row strong small`.
  static final TextStyle vitalUnit = _style(9, FontWeight.w400, height: 1.3);

  /// Below this width the prototype drops the duration to 54 px.
  static const double narrowWidth = 360;
}
