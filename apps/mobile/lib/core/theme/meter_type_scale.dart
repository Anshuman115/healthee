/// The two meters v02 draws against a baseline, in `charts.css`'s own sizes.
///
/// These belong with [TypeScale] and are only in a second file because that one
/// is exactly at the standards' 400-line ceiling; `sleep_type_scale.dart` was
/// split off for the same reason and records the same argument. Nothing here
/// invents a size — every entry names the rule it came from.
///
/// ```css
/// .signal-chart-key  { font-size: 8px }                    charts.css
/// .signal-row        { font-size: 11px }                   charts.css
/// .signal-row b      { font-size: 10px; font-weight: 500 } charts.css
/// .comparison-row    { font-size: 10px }                   richer.css
/// ```
///
/// `.signal-row`'s own 11 px is [TypeScale.factorRow] — the same rule at the
/// same size on the same kind of row — rather than a fourth entry here saying
/// the same thing.
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

/// The type the baseline meters are set in.
abstract final class MeterType {
  /// `.signal-chart-key` — `Lower · Your baseline · Higher`.
  static final TextStyle signalKey = _style(8, FontWeight.w400, height: 1.4);

  /// `.signal-row b` — the reading at the end of a signal row.
  static final TextStyle signalReading = _style(
    10,
    FontWeight.w500,
    height: 1.4,
  );

  /// `.comparison-row` — both of a comparison row's labels.
  static final TextStyle comparisonRow = _style(
    10,
    FontWeight.w400,
    height: 1.4,
  );
}
