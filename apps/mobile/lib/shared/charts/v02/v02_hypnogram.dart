/// [V02Hypnogram] — the night's stage timeline, v02's shape.
///
/// `design/mobile-preview/charts.js::H.charts.sleep`:
///
/// ```js
/// const stages = ['awake', 'rem', 'light', 'deep'];        // top to bottom
/// content = stages.map((s, i) => text(0, 20 + i * 33, …));  // lane labels, left
/// timeline.forEach(item => {
///   const x = 55 + item.start_offset_min / 450 * 276;
///   const y = 8 + stages.indexOf(item.stage) * 33;
///   content += `<rect class="stage-${item.stage}" x=… y=… height="20" rx="5"/>`;
///   points.push([x, y + 10], [x + width, y + 10]);
/// });
/// content = `<path class="sleep-connector" d="${path(points)}"/>` + content;
/// content += text(55, 153, '23:00') + text(331, 153, '06:30', 'end');
/// ```
///
/// ## What is v02's here, against the pre-v02 `HHypnogram`
///
/// The bands and their lanes are the same claim. Three things are new and all
/// three come from the prototype: the **lane labels live inside the chart**
/// rather than in a 44 px column the card had to remember to leave room for;
/// a **connector** draws the walk between lanes, so a sequence of blocks reads
/// as one night; and the **first and last clock time** sit under the plot.
///
/// ## The window is the night's own, not a fixed 450 minutes
///
/// The prototype divides by a literal `450` because its fixture is one 7½-hour
/// night. A real night that ran longer would draw off the right edge. The span
/// here is the measured one — first start to last end — so the plot always ends
/// where the night did.
///
/// ## No hue is ever handed in
///
/// Stage hues resolve through `InstrumentHues.sleepStage`, the app's one stage
/// mapping (`core/theme/instrument_hues.dart`). The connector is the light-stage
/// hue, which is what `.sleep-connector { stroke: var(--chart-light) }` is.
/// (The suite that enforces that rule reads this file for the type's own name,
/// so the word is deliberately not written here.)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/data/models/last_sleep.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';
import 'package:healthee/shared/charts/v02/chart_box.dart';
import 'package:healthee/shared/charts/v02/chart_frame.dart';
import 'package:healthee/shared/charts/v02/chart_ink.dart';
import 'package:healthee/shared/charts/v02/chart_void.dart';

/// The lanes, top to bottom, in the prototype's order.
const List<String> kHypnogramLanes = <String>['awake', 'rem', 'light', 'deep'];

/// One night's stages, laid out along the time it took.
class V02Hypnogram extends StatelessWidget {
  /// [spans] is chronological; [startLabel] and [endLabel] are wall clocks.
  const V02Hypnogram(
    this.spans, {
    required this.progress,
    this.height = 165,
    this.startLabel,
    this.endLabel,
    this.semanticLabel,
    super.key,
  });

  /// The staged spans, oldest first.
  final List<SleepStageSpan> spans;

  /// How much of the reveal has run, 0–1.
  final double progress;

  /// How tall to draw it.
  final double height;

  /// The clock the night began at, drawn under the left edge.
  final String? startLabel;

  /// The clock it ended at, drawn under the right edge.
  final String? endLabel;

  /// What a screen reader is told.
  final String? semanticLabel;

  /// The label column, in logical pixels. The prototype's is 55 of 340.
  static const double laneGutter = 44;

  @override
  Widget build(BuildContext context) {
    if (spans.isEmpty) {
      return ChartVoid(height: height);
    }
    final chart = SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: HypnogramPainter(
          spans: spans,
          hues: context.hues,
          ink: ChartInk.of(context),
          progress: progress,
          captions: <String>[
            if (startLabel case final String start) start,
            if (endLabel case final String end) end,
          ],
        ),
      ),
    );
    final label = semanticLabel;
    return label == null ? chart : Semantics(label: label, child: chart);
  }
}

/// Draws the lanes, the connector and the bands.
class HypnogramPainter extends CustomPainter {
  /// Everything the timeline needs, already resolved from the theme.
  const HypnogramPainter({
    required this.spans,
    required this.hues,
    required this.ink,
    required this.progress,
    required this.captions,
  });

  /// The staged spans, oldest first.
  final List<SleepStageSpan> spans;

  /// The app's one stage mapping.
  final InstrumentHues hues;

  /// Grid, label and surface colours.
  final ChartInk ink;

  /// How much of the reveal has run.
  final double progress;

  /// The first and last wall clocks, or fewer.
  final List<String> captions;

  /// `rect … height="20" rx="5"` at the prototype's 33 px lane pitch.
  static const double bandFraction = 20 / 33;

  /// `rx="5"`.
  static const double bandRadius = 5;

  /// The strip under the plot that carries the two clocks.
  ///
  /// Three wider than `ChartMetrics`'s own 15: `paintEdgeCaptions` insets by
  /// its clearance before it writes, and at 15 the clock's descenders landed
  /// two pixels past the chart's own bottom edge. A label that is clipped is a
  /// label that is not there.
  static const double captionStrip = 18;

  /// `y = 8 + …`.
  static const double padTop = 8;

  /// The gap between a lane label and the plot.
  static const double labelGap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final box = _box(size);
    if (!box.isDrawable) {
      return;
    }
    final window = _window();
    if (window <= 0) {
      return;
    }
    final lane = box.plot.height / kHypnogramLanes.length;
    final band = math.min(lane * bandFraction, lane);
    _paintLaneLabels(canvas, box, lane);
    _paintConnector(canvas, box, window, lane, band);
    _paintBands(canvas, box, window, lane, band);
    paintEdgeCaptions(canvas, box, captions, ink: ink, progress: progress);
  }

  /// The lane labels sit left of the plot; the clocks sit under it.
  ChartBox _box(Size size) {
    const top = padTop;
    final bottom = size.height - captionStrip;
    return ChartBox(
      plot: Rect.fromLTRB(V02Hypnogram.laneGutter, top, size.width, bottom),
      values: Rect.zero,
      captions: Rect.fromLTRB(
        V02Hypnogram.laneGutter,
        bottom,
        size.width,
        size.height,
      ),
      bubble: Rect.zero,
    );
  }

  /// First start to last end — the night's own length, never a fixed window.
  double _window() {
    var start = spans.first.startOffsetMin;
    var end = spans.first.endOffsetMin;
    for (final span in spans) {
      start = math.min(start, span.startOffsetMin);
      end = math.max(end, span.endOffsetMin);
    }
    return end - start;
  }

  double _originMin() {
    var start = spans.first.startOffsetMin;
    for (final span in spans) {
      start = math.min(start, span.startOffsetMin);
    }
    return start;
  }

  void _paintLaneLabels(Canvas canvas, ChartBox box, double lane) {
    final style = ink.labelStyle.copyWith(color: revealed(ink.ink3, progress));
    for (var i = 0; i < kHypnogramLanes.length; i++) {
      final painter = chartLabel(sleepStageLabel(kHypnogramLanes[i]), style);
      final centre = box.plot.top + lane * (i + 0.5);
      final left = math.max(
        0.0,
        box.plot.left - labelGap - painter.width,
      );
      painter.paint(canvas, Offset(left, centre - painter.height / 2));
    }
  }

  /// The walk between lanes, under the bands so a band always wins.
  void _paintConnector(
    Canvas canvas,
    ChartBox box,
    double window,
    double lane,
    double band,
  ) {
    final points = <Offset>[];
    for (final span in spans) {
      final centre = _laneCentre(box, span.stage, lane);
      points
        ..add(Offset(_x(box, span.startOffsetMin, window), centre))
        ..add(Offset(_x(box, span.endOffsetMin, window), centre));
    }
    if (points.length < 2) {
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final paint = Paint()
      ..color = revealed(sleepStageColor(hues, 'light'), progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0)),
        paint,
      );
    }
  }

  void _paintBands(
    Canvas canvas,
    ChartBox box,
    double window,
    double lane,
    double band,
  ) {
    final grown = band * progress.clamp(0.0, 1.0);
    if (grown <= 0) {
      return;
    }
    for (final span in spans) {
      final left = _x(box, span.startOffsetMin, window);
      final right = _x(box, span.endOffsetMin, window);
      final centre = _laneCentre(box, span.stage, lane);
      final rect = Rect.fromLTWH(
        left,
        centre - grown / 2,
        math.max(right - left, 1),
        grown,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(math.min(bandRadius, grown / 2)),
        ),
        Paint()..color = sleepStageColor(hues, span.stage),
      );
    }
  }

  double _laneCentre(ChartBox box, String stage, double lane) {
    final index = kHypnogramLanes.indexOf(_laneOf(stage));
    final row = index < 0 ? kHypnogramLanes.length - 2 : index;
    return box.plot.top + lane * (row + 0.5);
  }

  /// `core` is the server's word for the strap's `light`. One stage, one lane.
  static String _laneOf(String stage) => stage == 'core' ? 'light' : stage;

  double _x(ChartBox box, double minutes, double window) =>
      box.plot.left +
      ((minutes - _originMin()) / window).clamp(0.0, 1.0) * box.plot.width;

  @override
  bool shouldRepaint(HypnogramPainter old) =>
      old.progress != progress ||
      old.spans != spans ||
      old.captions != captions ||
      old.ink.family != ink.family;
}
