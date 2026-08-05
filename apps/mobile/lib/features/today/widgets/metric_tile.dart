/// One cell of legacy's Today grid, and the two-up row it sits in.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart` —
/// `_MetricModule` (860) and `_Content._grid` (388). Geometry unchanged:
///
/// ```text
///   ┌──────────────────────────┐
///   │ RESTING HR             ● │  eyebrow · dot, or a delta badge instead
///   │ 55 bpm                   │  27 px figure, 10 px unit on the baseline
///   │                          │  a Spacer — the chart is bottom-aligned
///   │ ▁▂▃▅▃▂▁                  │  a 30 px slot, always exactly 30
///   │ MED 55                   │  the foot
///   └──────────────────────────┘
///      the body is a fixed 92 px · two cells to a row · 10 px between them
/// ```
///
/// The row is `CrossAxisAlignment.start`, which is legacy's, so a taller cell
/// does not stretch its neighbour.
///
/// ## The delta badge replaces the dot rather than joining it
///
/// Legacy passes the badge as `HModule`'s `trailing`, and `trailing` is drawn
/// *instead of* the tag dot (`ui.dart:127`). A z of exactly 0 draws the dot, not
/// a `+0.0` badge — legacy's `dz != 0` guard — because zero movement is not a
/// direction and a badge is a claim about one.
///
/// ## What a cell does when there is no value, and why it is not legacy's dash
///
/// Legacy prints `'—'` and then draws a chart anyway, from a fabricated flat
/// series (`today_facts.dart` has that argument). Here the figure becomes a
/// [ValueHole] at the same footprint and the 30 px chart slot carries the
/// refusal's own sentence instead of a line. Same card, same title, same
/// position, no colour spent — `docs/APP_DESIGN_BRIEF.md` §3's "card with a
/// number-shaped hole".
///
/// The cell has room for the reason because the reason is short and because it
/// has to: legacy's Today gives these six metrics no detail screen to point at,
/// so a cell that said only WITHHELD would be a refusal with no explanation
/// anywhere on the device.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/shared/instrument/h_delta_badge.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/states/value_hole.dart';
import 'package:healthee/shared/states/withheld_card.dart';

/// A grid cell built from a [Reading].
class MetricTile extends StatelessWidget {
  /// [chart] is drawn in the 30 px slot when there is a value.
  const MetricTile({
    required this.label,
    required this.tag,
    required this.reading,
    required this.format,
    required this.chart,
    this.unit,
    this.valueColor,
    this.foot,
    this.delta,
    this.deltaFavorable,
    super.key,
  });

  /// The metric's name. Rendered uppercase.
  final String label;

  /// Its hue — the dot, and the chart's tint.
  final Color tag;

  /// The value and what the server was willing to say about it.
  final Reading<double> reading;

  /// Turns the value into the string the cell shows. Passed in rather than a
  /// decimal count, because a sleep duration is `6:20` and a heart rate is `55`.
  final String Function(double value) format;

  /// The 30 px chart. Never drawn when [reading] carries no value.
  final Widget chart;

  /// The unit beside the figure.
  final String? unit;

  /// Tints the figure. Legacy tints three of its six (`valueColor`).
  final Color? valueColor;

  /// The context line at the bottom — a median, a range, a stage split.
  final String? foot;

  /// The z-score behind the delta badge. Null draws the tag dot instead.
  final double? delta;

  /// Whether that z points the favourable way, or null when there is no view.
  final bool? deltaFavorable;

  /// Legacy's `SizedBox(height: 92)` around the whole body.
  static const double bodyHeight = 92;

  /// Legacy's `SizedBox(height: 30, child: chart)`.
  static const double chartHeight = 30;

  @override
  Widget build(BuildContext context) {
    // Legacy rounds the z to one decimal BEFORE testing it against zero, so a
    // z of 0.04 draws the dot rather than a `+0.0` badge that claims a movement
    // it has just rounded away.
    final rounded = delta == null
        ? null
        : double.parse(delta!.toStringAsFixed(1));
    return InstrumentModule(
      label: label,
      tag: tag,
      minHeight: 0,
      trailing: rounded != null && rounded != 0
          ? HDeltaBadge(rounded, good: deltaFavorable, size: 10)
          : null,
      children: [
        switch (reading) {
          Present<double>(:final value) => _body(context, value),
          Caveated<double>(:final value, :final caveats) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [_body(context, value), CaveatNote(caveats: caveats)],
          ),
          Withheld<double>(:final disclosure) => _Hole(
            message: disclosure.message,
            foot: foot,
          ),
          Excluded<double>(:final exclusions) => _Hole(
            message: exclusions.first.message,
            foot: foot,
          ),
        },
      ],
    );
  }

  Widget _body(BuildContext context, double value) {
    return SizedBox(
      height: bodyHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModuleValue(value: format(value), unit: unit, color: valueColor),
          const Spacer(),
          SizedBox(height: chartHeight, child: chart),
          if (foot case final String line) ModuleFoot(line),
        ],
      ),
    );
  }
}

/// The cell with the number taken out of it: a hole, then the reason.
class _Hole extends StatelessWidget {
  const _Hole({required this.message, this.foot});

  final String message;
  final String? foot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ConstrainedBox(
      // A floor, not a fixed height: the reason is one to three lines and
      // clipping the remedy would tell the owner half of how to fix it.
      constraints: const BoxConstraints(minHeight: MetricTile.bodyHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // `min` and no `Spacer`: this column is inside a shrink-wrapping card in
        // a vertical scrollable, where a flex child is a layout assertion rather
        // than a bottom-aligned foot. The footprint comes from the [minHeight]
        // above it instead, which is what actually has to hold.
        mainAxisSize: MainAxisSize.min,
        children: [
          const ValueHole(width: 64, height: 30),
          const SizedBox(height: 9),
          Text(message, style: HType.sans(colors.ink2, size: 11, height: 1.35)),
          // The median is still a real measurement and keeps its slot; only the
          // reading it was a comparison FOR has gone.
          if (foot case final String line) ModuleFoot(line),
        ],
      ),
    );
  }
}

/// Legacy's `_grid` — two cells, 10 px apart, top-aligned.
class MetricTileRow extends StatelessWidget {
  /// [left] and [right] are one row of the grid.
  const MetricTileRow({required this.left, required this.right, super.key});

  /// The first cell.
  final Widget left;

  /// The second.
  final Widget right;

  /// Legacy's `SizedBox(width: 10)`.
  static const double gap = 10;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: gap),
        Expanded(child: right),
      ],
    );
  }
}
