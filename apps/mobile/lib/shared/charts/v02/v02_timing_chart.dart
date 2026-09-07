/// [V02TimingChart] — bedtime and wake time on one "hours from 18:00" scale.
///
/// **This is the app's own timing chart, kept at the owner's request** and
/// re-dressed for v02. It replaces `shared/charts/h_timing_chart.dart`, which
/// was its only previous home; there is one timing chart in the app, not two.
///
/// > *"the current has a graph for sleeptime vs wake time I would love to keep
/// > that graph along with all v2 sleep."*
///
/// The prototype's own `H.charts.consistency` is **not** this chart — it draws
/// seven identical bars at fixed coordinates with no data behind them, one of
/// the unfinished charts we were asked to make beautiful. Swapping this for it
/// would have thrown away the only surface that says *when* the owner slept.
///
/// ## What did not change: what it plots
///
/// **The 18:00 origin is the whole idea.** A bedtime of 23:40 and one of 00:20
/// are forty minutes apart, but on a midnight-origin clock they are 23.7 and
/// 0.3 — a nearly full-height jump that reads as wild irregularity. Shifting the
/// origin to 18:00 puts a normal night's whole range inside one continuous run,
/// so the line shows drift rather than an artefact of where the day is cut.
///
/// Also unchanged: the ±0.5 h axis padding rounded outward, **five** gridlines
/// carrying wall-clock labels, and two series — bedtime in the sleep family,
/// wake in the movement family, which is the pair legacy drew and the pair the
/// prototype's own `.colour-key` names on this panel.
///
/// ## What changed: how it is dressed
///
/// - The clock labels moved from a bespoke left pad into v02's **right value
///   gutter** (`ChartMetrics.series`), which is where every other v02 chart puts
///   them, and the rules come from `paintChartFrame`.
/// - The bespoke tap handler and hand-rolled tooltip became `ChartScrub` — the
///   shared cursor, bubble and readout line.
/// - Night labels are drawn by `paintEdgeCaptions`, so they sit in the caption
///   strip and can never land on the plot.
/// - **`smoothPath` (Catmull-Rom) became `SeriesCurve.monotone`.** Recorded here
///   because it is a real change: Catmull-Rom overshoots, so it could draw a
///   bedtime earlier than any night measured — the same class of error as a
///   spline through nightly minimums drawing a minimum lower than any night.
///   Monotone cubic Hermite is range-preserving by construction, so the curve
///   still reads as drift and cannot invent a time nobody went to bed at.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';
import 'package:healthee/shared/charts/v02/chart_box.dart';
import 'package:healthee/shared/charts/v02/chart_curve.dart';
import 'package:healthee/shared/charts/v02/chart_frame.dart';
import 'package:healthee/shared/charts/v02/chart_ink.dart';
import 'package:healthee/shared/charts/v02/chart_scrub.dart';
import 'package:healthee/shared/charts/v02/chart_ticks.dart';
import 'package:healthee/shared/charts/v02/chart_void.dart';

/// Where the timing scale starts, in hours. See the library docstring.
const double kTimingOriginHour = 18;

/// Hours-from-18:00 back to a wall clock.
String timingClockAt(double hoursFromOrigin) {
  final wall = (hoursFromOrigin + kTimingOriginHour) % 24;
  final hour = wall.floor();
  final minute = ((wall - hour) * 60).round();
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

/// Two lines: when sleep began, and when it ended.
class V02TimingChart extends StatelessWidget {
  /// [bedtime] and [wake] are hours from 18:00, oldest first, the same length.
  const V02TimingChart({
    required this.bedtime,
    required this.wake,
    required this.progress,
    this.captions = const <String>[],
    this.nightLabels = const <String>[],
    this.height = 150,
    this.semanticLabel,
    super.key,
  });

  /// Sleep onset, in hours from 18:00.
  final List<double> bedtime;

  /// Wake, in the same units.
  final List<double> wake;

  /// How much of each line to draw, 0–1.
  final double progress;

  /// The first and last night's dates, drawn under the plot's two edges.
  final List<String> captions;

  /// One label per night, for the scrub readout.
  final List<String> nightLabels;

  /// How tall the plot is, before the readout line.
  final double height;

  /// What a screen reader is told.
  final String? semanticLabel;

  /// Legacy's five gridlines.
  static const int gridlines = 5;

  /// The plot plus the readout line under it.
  double get slotHeight => height + ChartScrub.readoutHeight;

  /// The axis: the measured span, padded half an hour and rounded outward.
  ///
  /// Returns null when there is nothing to place a value on — fewer than two
  /// readings, or a span that collapsed.
  ChartTicks? get ticks {
    final all = <double>[...bedtime, ...wake];
    if (all.length < 2 || bedtime.length != wake.length) {
      return null;
    }
    var low = all.first;
    var high = all.first;
    for (final value in all) {
      low = math.min(low, value);
      high = math.max(high, value);
    }
    final floor = (low - 0.5).floorToDouble();
    final ceiling = (high + 0.5).ceilToDouble();
    if (ceiling <= floor) {
      return null;
    }
    final step = (ceiling - floor) / (gridlines - 1);
    return ChartTicks(
      low: floor,
      high: ceiling,
      step: step,
      values: <double>[for (var i = 0; i < gridlines; i++) floor + i * step],
      decimals: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final axis = ticks;
    if (axis == null || bedtime.length < 2) {
      return ChartVoid(height: slotHeight);
    }
    final chart = ChartScrub(
      sampleCount: bedtime.length,
      height: height,
      metrics: ChartMetrics.series,
      chart: (context, index) => CustomPaint(
        painter: TimingPainter(
          bedtime: bedtime,
          wake: wake,
          ticks: axis,
          bedInk: ChartInk.tone(context, Tone.sleep),
          wakeInk: ChartInk.tone(context, Tone.movement),
          progress: progress,
          captions: captions,
          touch: index,
          bubbleText: index == null ? null : _reading(index),
        ),
      ),
      readout: (context, index) => ChartReadoutText(_readout(index)),
    );
    final label = semanticLabel;
    return label == null ? chart : Semantics(label: label, child: chart);
  }

  String _readout(int? index) {
    if (index == null || index < 0 || index >= bedtime.length) {
      return 'Touch the chart to explore · bedtime and wake';
    }
    final label = index < nightLabels.length ? nightLabels[index] : null;
    final reading = _reading(index);
    return label == null ? reading : '$label · $reading';
  }

  String _reading(int index) =>
      'bed ${timingClockAt(bedtime[index])} · '
      'wake ${timingClockAt(wake[index])}';
}

/// Draws the frame, the two series and the crosshair.
class TimingPainter extends CustomPainter {
  /// Everything already resolved from the theme.
  const TimingPainter({
    required this.bedtime,
    required this.wake,
    required this.ticks,
    required this.bedInk,
    required this.wakeInk,
    required this.progress,
    required this.captions,
    required this.touch,
    required this.bubbleText,
  });

  /// Sleep onset, in hours from 18:00.
  final List<double> bedtime;

  /// Wake, in the same units.
  final List<double> wake;

  /// The axis both series share.
  final ChartTicks ticks;

  /// The bedtime series' family, and the frame's grid and label colours.
  final ChartInk bedInk;

  /// The wake series' family.
  final ChartInk wakeInk;

  /// How much of each line to draw.
  final double progress;

  /// The two edge dates.
  final List<String> captions;

  /// Which night the finger is on, if any.
  final int? touch;

  /// What the bubble says.
  final String? bubbleText;

  /// Legacy's stroke.
  static const double strokeWidth = 2.2;

  /// The crosshair's two dots.
  static const double dotRadius = 3;

  /// The gap between the value gutter's right edge and a clock label.
  static const double gutterPad = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final box = ChartMetrics.series.box(size);
    if (!box.isDrawable || bedtime.length < 2) {
      return;
    }
    paintChartFrame(
      canvas,
      box,
      ticks,
      ink: bedInk,
      progress: progress,
      labelled: false,
    );
    _paintClocks(canvas, box);
    _paintSeries(canvas, box, bedtime, bedInk);
    _paintSeries(canvas, box, wake, wakeInk);
    paintEdgeCaptions(canvas, box, captions, ink: bedInk, progress: progress);
    _paintCrosshair(canvas, box);
  }

  /// The gridline labels are wall clocks, so they cannot come from
  /// [ChartTicks.label] — that formats a number.
  void _paintClocks(Canvas canvas, ChartBox box) {
    if (box.values.width <= 0) {
      return;
    }
    final style = bedInk.labelStyle.copyWith(
      color: revealed(bedInk.ink3, progress),
    );
    for (final value in ticks.values) {
      final painter = chartLabel(timingClockAt(value), style);
      final y = ticks.y(value, box.plot);
      final top = (y - painter.height / 2).clamp(
        0.0,
        box.plot.bottom - painter.height,
      );
      final left = math.max(
        box.values.left,
        box.values.right - gutterPad - painter.width,
      );
      painter.paint(canvas, Offset(left, top));
    }
  }

  void _paintSeries(
    Canvas canvas,
    ChartBox box,
    List<double> data,
    ChartInk ink,
  ) {
    final points = <Offset>[
      for (var i = 0; i < data.length; i++)
        Offset(box.x(i, data.length), ticks.y(data[i], box.plot)),
    ];
    // Monotone, never Catmull-Rom: a range-preserving curve cannot draw a
    // bedtime outside the ones measured. See the library docstring.
    final path = curvePath(points, SeriesCurve.monotone);
    final glow = ink.glow(strokeWidth);
    for (final metric in path.computeMetrics()) {
      final drawn = metric.extractPath(
        0,
        metric.length * progress.clamp(0.0, 1.0),
      );
      if (glow != null) {
        canvas.drawPath(drawn, glow);
      }
      canvas.drawPath(drawn, ink.stroke(strokeWidth));
    }
  }

  void _paintCrosshair(Canvas canvas, ChartBox box) {
    final index = touch;
    if (index == null || index < 0 || index >= bedtime.length) {
      return;
    }
    final x = box.x(index, bedtime.length);
    paintScrubCursor(
      canvas,
      x,
      top: box.plot.top,
      bottom: box.plot.bottom,
      ink: bedInk,
    );
    canvas
      ..drawCircle(
        Offset(x, ticks.y(bedtime[index], box.plot)),
        dotRadius,
        Paint()..color = bedInk.family,
      )
      ..drawCircle(
        Offset(x, ticks.y(wake[index], box.plot)),
        dotRadius,
        Paint()..color = wakeInk.family,
      );
    if (bubbleText case final String text) {
      paintScrubBubble(canvas, box, text, anchorX: x, ink: bedInk);
    }
  }

  @override
  bool shouldRepaint(TimingPainter old) =>
      old.progress != progress ||
      old.bedtime != bedtime ||
      old.wake != wake ||
      old.touch != touch ||
      old.bedInk.family != bedInk.family;
}
