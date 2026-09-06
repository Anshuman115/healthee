/// What a chart draws when it has nothing to draw: **nothing, at full height.**
///
/// ## Both halves matter, and each fixes a shipped bug
///
/// **Nothing.** This app has drawn a series it did not have. `HArea([0, 0])` put
/// a flat line at zero across a card whose subject had not been measured, and an
/// invented 56-bpm fallback drew a resting rate nobody's heart produced. A
/// reader cannot tell a fabricated flat line from a real one — that is the whole
/// problem with it — so the only honest render of "not enough data" is an empty
/// slot with the card's own words explaining it.
///
/// **At full height.** The obvious version returns `SizedBox.shrink()`, and then
/// the card silently collapses: a panel that is 210 px tall with data and 96 px
/// tall without it makes every card below it jump when the sync lands, and makes
/// a withheld metric look like a metric the app forgot to include. Holding the
/// slot is what makes the absence *visible as an absence*.
///
/// Two charts on this project shipped at zero height because their tests only
/// asked whether the widget existed. So the height is asserted from the
/// rendered box, and this widget exists partly so that assertion has one place
/// to point at.
library;

import 'package:flutter/material.dart';

/// The slot a chart would have filled, empty.
class ChartVoid extends StatelessWidget {
  /// [height] is the chart's own height — the same number the drawn chart uses.
  const ChartVoid({required this.height, super.key});

  /// The height the drawn chart would have taken.
  final double height;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: height, width: double.infinity);
}

/// Whether [values] carries enough measurement to draw a series at all.
///
/// Two finite samples. One reading has no shape, and a line drawn through it
/// would be a trend asserted from a single number.
bool canDrawSeries(List<double?> values) {
  var measured = 0;
  for (final value in values) {
    if (value != null && value.isFinite) {
      measured++;
      if (measured >= 2) {
        return true;
      }
    }
  }
  return false;
}

/// Whether [values] carries at least one measured bar or bucket.
///
/// The bar charts' rule differs from [canDrawSeries] on purpose: a single day's
/// steps is a complete, drawable measurement — a column is a value, not a
/// trend — whereas a single point pretending to be a line is not.
bool canDrawColumns(List<double?> values) =>
    values.any((value) => value != null && value.isFinite);
