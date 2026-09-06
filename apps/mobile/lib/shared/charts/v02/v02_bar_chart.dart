/// Bars: steps by day, MVPA across a week, cardio load across a fortnight.
///
/// A column per period, the one being read at full weight, and — when the server
/// sent one — a target line the columns are read against, named underneath
/// rather than written across them.
///
/// ## Why the axis is pinned to zero here and nowhere else
///
/// A bar's meaning is its **length**. Cut the axis at 7,000 and a 9,000-step day
/// draws twice the bar of an 8,000-step day, which is a lie told by arithmetic
/// nobody can see. So [ChartTicks.nice] is asked for `zeroBased: true`, always,
/// and the line chart is not — a heart rate plotted from zero would spend nine
/// tenths of its plot on a range no living body occupies.
library;

import 'package:flutter/material.dart';
import 'package:healthee/shared/charts/chart_reference.dart';
import 'package:healthee/shared/charts/v02/chart_box.dart';
import 'package:healthee/shared/charts/v02/chart_ink.dart';
import 'package:healthee/shared/charts/v02/chart_ticks.dart';
import 'package:healthee/shared/charts/v02/chart_void.dart';
import 'package:healthee/shared/charts/v02/column_painter.dart';

/// A bar per slot of [values], revealed by [progress].
class V02BarChart extends StatelessWidget {
  /// [values] is oldest first; a `null` slot was not measured and draws
  /// nothing, while a measured zero draws a mark on the baseline.
  const V02BarChart(
    this.values, {
    required this.progress,
    this.labels = const <String>[],
    this.target,
    this.height = 150,
    this.emphasis,
    this.semanticLabel,
    super.key,
  });

  /// One value per period, oldest first.
  final List<double?> values;

  /// 0–1 from `RevealOnce`. Bars grow out of the baseline.
  final double progress;

  /// One short caption per bar — a weekday initial, a day of the month. Those
  /// that do not fit are dropped, never shrunk; `column_painter.dart` says why.
  final List<String> labels;

  /// The line the bars are read against — a goal, a habitual load. Named under
  /// the chart by `ChartReferenceCaption`.
  final ChartReference? target;

  /// The chart's height, held whether or not anything is drawn.
  final double height;

  /// Which bar is being read. Defaults to the newest measured one, which is
  /// what "current" means on every screen that shows this chart.
  final int? emphasis;

  /// What a screen reader is told the chart is.
  final String? semanticLabel;

  /// The prototype's `width * .58`.
  static const double _barFraction = 0.58;

  /// Seven bars in a wide card would otherwise be seven slabs.
  static const double _maxBarWidth = 30;

  @override
  Widget build(BuildContext context) {
    if (!canDrawColumns(values)) {
      return ChartVoid(height: height);
    }
    final line = target;
    final chart = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: ColumnPainter(
              values: values,
              ticks: ChartTicks.nice(
                values.whereType<double>(),
                include: <double>[if (line != null) line.value],
                zeroBased: true,
              ),
              metrics: ChartMetrics.framed,
              ink: ChartInk.of(context),
              progress: progress,
              labels: labels,
              captions: const <String>[],
              target: line,
              emphasis: emphasis ?? _newestMeasured,
              barFraction: _barFraction,
              maxBarWidth: _maxBarWidth,
            ),
          ),
        ),
        if (line != null) ChartReferenceCaption(<ChartReference>[line]),
      ],
    );
    final label = semanticLabel;
    return label == null ? chart : Semantics(label: label, child: chart);
  }

  /// The newest slot that was actually measured, or null if none was.
  int? get _newestMeasured {
    for (var i = values.length - 1; i >= 0; i--) {
      final value = values[i];
      if (value != null && value.isFinite) {
        return i;
      }
    }
    return null;
  }
}
