/// One cell of the Today grid: a value, a chart, a foot — or a hole where the
/// value would have been.
///
/// **Ported from** the `Module` usages in
/// `design_reference/project/hh/screen_today.jsx`: label and tag dot at the top,
/// a 27 px figure with a small unit, the chart pushed to the bottom by
/// `marginTop: auto`, and one all-caps foot line under it.
///
/// ## The grid is an index, and this is the rule that makes that honest
///
/// A cell 118 px tall cannot carry a refusal's reason AND its remedy, and
/// `docs/APP_DESIGN_BRIEF.md` §3 is explicit that a withheld value gets both. So
/// a cell **never carries them and never stands alone**: it draws a [ValueHole]
/// where the figure would be and the word WITHHELD in its foot, and the full
/// [WithheldCard] — reason, remedy, no retry — is rendered by the section further
/// down the screen that owns that metric. `metric_grid.dart` documents the
/// pairing slot by slot, and `today_sections.dart` keeps every one of those
/// sections on the screen.
///
/// That is not a softening of the rule. The alternative shapes are worse in ways
/// this product has already argued about: a cell that vanishes makes the absence
/// invisible, and a cell that truncates the remedy tells the owner half of how to
/// fix it.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/features/today/widgets/instrument_module.dart';
import 'package:healthee/shared/charts/h_spark.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/value_hole.dart';

/// A grid cell built from a [Reading].
class GridModule extends StatelessWidget {
  /// [reading] decides whether there is a figure or a hole.
  const GridModule({
    required this.label,
    required this.tag,
    required this.reading,
    required this.format,
    required this.reveals,
    required this.revealId,
    this.unit,
    this.spark = const <double>[],
    this.foot,
    this.chart,
    super.key,
  });

  /// The metric's name, uppercased by [ModuleLabel].
  final String label;

  /// The identity tag — the dot, and the chart's tint.
  final Color tag;

  /// The value and what its source was willing to say about it.
  final Reading<double> reading;

  /// Turns the value into the string the cell shows. Passed in rather than a
  /// decimal count, because a sleep duration is `6:20` and a heart rate is `55`.
  final String Function(double value) format;

  /// Where "this cell has already animated" is remembered. The screen's.
  final RevealRegistry reveals;

  /// Stable and about the cell's subject, so inserting a card above it cannot
  /// make it "a different chart" and animate again.
  final Object revealId;

  /// The unit beside the figure, or null when it has none.
  final String? unit;

  /// The sparkline's values, oldest first. Empty draws no line.
  final List<double> spark;

  /// The context line at the bottom. Null when the cell has nothing to add.
  final String? foot;

  /// Drawn instead of the sparkline — a hypnogram, a bar strip.
  ///
  /// Takes the reveal progress so it animates on the same schedule as the rest
  /// of the cell rather than owning a ticker of its own.
  final Widget Function(BuildContext context, double progress)? chart;

  /// The foot a cell shows when its source declined to answer.
  static const String withheldFoot = 'Withheld — see below';

  @override
  Widget build(BuildContext context) {
    final value = reading.valueOrNull;
    return InstrumentModule(
      label: label,
      tag: tag,
      children: [
        if (value == null)
          const ValueHole(width: 64, height: 30)
        else
          ModuleValue(value: format(value), unit: unit),
        const Spacer(),
        RevealOnce(
          id: revealId,
          registry: reveals,
          builder: (context, t) => SizedBox(
            height: 28,
            child: switch (chart) {
              // A withheld value gets no chart. A trend drawn where today's
              // reading is missing invites the eye to read the last point as
              // today, which is the number we just declined to show.
              _ when value == null => const SizedBox.shrink(),
              final Widget Function(BuildContext, double) build => build(context, t),
              _ => HSpark(spark, color: tag, progress: t),
            },
          ),
        ),
        ModuleFoot(value == null ? withheldFoot : (foot ?? '')),
      ],
    );
  }
}

/// The grid's two-column layout. Legacy's `gridTemplateColumns: '1fr 1fr'`,
/// `gap: 10`.
///
/// `IntrinsicHeight` per row rather than a `GridView`: the cells must be equal
/// height within a row so their feet align, and they must size to their content
/// rather than to a `childAspectRatio` invented here — a fixed ratio is how a
/// two-line label clips on a small phone.
class ModuleGrid extends StatelessWidget {
  /// Lays [modules] out two to a row, in order.
  const ModuleGrid({required this.modules, super.key});

  /// The cells, in reading order.
  final List<Widget> modules;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < modules.length; i += 2) ...[
          if (i > 0) const SizedBox(height: Insets.sm + 2),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: modules[i]),
                const SizedBox(width: Insets.sm + 2),
                Expanded(
                  child: i + 1 < modules.length
                      ? modules[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
