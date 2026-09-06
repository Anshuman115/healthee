/// The intraday chart: one column per fifteen minutes of a day.
///
/// The same picture as [V02BarChart] at ninety-six times the density, so it is
/// the same painter with a different bar fraction and no per-column labels — a
/// label under every quarter hour is ninety-six glyphs of noise under a chart
/// whose subject is when the day was busy.
///
/// ## What it will not do
///
/// **It will not fill in the hours the strap was off.** A `null` bucket draws
/// nothing; a bucket measured as zero draws a mark on the baseline. The
/// distinction is the whole reason this chart is worth drawing rather than
/// summarising — "you moved every hour except two" and "we only saw twenty-two
/// hours" are different days, and a chart that renders them identically is
/// telling the reader the first one when it only knows the second.
///
/// **It will not shade by magnitude.** The prototype highlights every fourth
/// column (`.step-bars i:nth-child(4n)`), which is an hour marker wearing a
/// data mark's clothes. Here every bucket is the same weight and [emphasis] —
/// the bucket the reader is being pointed at, usually the current one — is the
/// only one drawn louder.
library;

import 'package:flutter/material.dart';
import 'package:healthee/shared/charts/v02/chart_box.dart';
import 'package:healthee/shared/charts/v02/chart_ink.dart';
import 'package:healthee/shared/charts/v02/chart_ticks.dart';
import 'package:healthee/shared/charts/v02/chart_void.dart';
import 'package:healthee/shared/charts/v02/column_painter.dart';

/// A column per bucket of [values], revealed by [progress].
class V02BucketChart extends StatelessWidget {
  /// [values] is one bucket per interval, earliest first. A `null` bucket was
  /// not measured.
  const V02BucketChart(
    this.values, {
    required this.progress,
    this.captions = const <String>[],
    this.height = 120,
    this.emphasis,
    this.semanticLabel,
    super.key,
  });

  /// One value per interval, earliest first.
  final List<double?> values;

  /// 0–1 from `RevealOnce`.
  final double progress;

  /// The two edge captions — the first and last interval's time.
  final List<String> captions;

  /// The chart's height, held whether or not anything is drawn.
  final double height;

  /// Which bucket is being pointed at, or null for none.
  final int? emphasis;

  /// What a screen reader is told the chart is.
  final String? semanticLabel;

  /// Tighter than a bar chart's 0.58: at ninety-six columns the gaps matter
  /// more than the stems, and 0.58 would draw a picket fence.
  static const double _barFraction = 0.74;

  /// A single-bucket day should not draw one bar across the whole plot.
  static const double _maxBarWidth = 14;

  @override
  Widget build(BuildContext context) {
    if (!canDrawColumns(values)) {
      return ChartVoid(height: height);
    }
    final chart = SizedBox(
      height: height,
      child: CustomPaint(
        painter: ColumnPainter(
          values: values,
          ticks: ChartTicks.nice(
            values.whereType<double>(),
            zeroBased: true,
            target: 3,
          ),
          metrics: ChartMetrics.framed,
          ink: ChartInk.of(context),
          progress: progress,
          labels: const <String>[],
          captions: captions,
          target: null,
          emphasis: emphasis,
          barFraction: _barFraction,
          maxBarWidth: _maxBarWidth,
        ),
      ),
    );
    final label = semanticLabel;
    return label == null ? chart : Semantics(label: label, child: chart);
  }
}
