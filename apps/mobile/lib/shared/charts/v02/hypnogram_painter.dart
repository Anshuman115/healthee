/// The mark [V02Hypnogram] draws — a continuous stepped ribbon of the night.
///
/// Split out of `v02_hypnogram.dart` when the ribbon rebuild took that file past
/// the 400-line limit. The division is the honest one: the widget decides *what
/// the chart is for* — its height, its empty state, what a screen reader is
/// told — and this decides *what the ink does*.
///
/// ## The shape, and what it replaced
///
/// It was pills at lane centres joined by a 2px stroke in the light-stage hue.
/// That reads on the prototype's fixture — one tidy night of about a dozen
/// spans — and not on a real one:
///
///   * **`rx: 5` eats a short bout.** A five-minute span is ~6px wide against a
///     24px band, so the radius consumed the rectangle and it drew as a
///     lozenge, the same visual weight as a forty-minute block.
///   * **A saturated connector outdrew the data.** Forty risers in a stage hue
///     is more ink than the bands they join, and every riser read as a
///     Light-stage event reaching up to Awake.
///   * **Two clocks are not a time axis.** A nine-hour night labelled only at
///     its ends gives no way to say *when* the long wake happened.
///
/// Now the night is **one ribbon**: a band of constant thickness that steps
/// between four levels, each step a riser in the colour of the stage being
/// entered. Blocks are square, so a one-minute bout draws one minute wide and a
/// forty-minute bout draws forty. Dotted rules mark the levels, a hairline box
/// bounds the plot, and four evenly spaced clocks run under it.
///
/// ## The lane labels are gone
///
/// `Awake / REM / Light / Deep` sat in a 44px gutter, repeating what the colour
/// key under the chart already says, on the one chart in the app that has a
/// legend directly beneath it. The gutter is the plot's now — about 15% more
/// width for the night itself.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/data/models/last_sleep.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';
import 'package:healthee/shared/charts/v02/chart_box.dart';
import 'package:healthee/shared/charts/v02/chart_ink.dart';
import 'package:healthee/shared/charts/v02/v02_hypnogram.dart';

/// Draws the box, the dotted levels, the ribbon and the clock axis.
class HypnogramPainter extends CustomPainter {
  /// Everything the timeline needs, already resolved from the theme.
  const HypnogramPainter({
    required this.spans,
    required this.hues,
    required this.ink,
    required this.progress,
    required this.axis,
  });

  /// The staged spans, oldest first.
  final List<SleepStageSpan> spans;

  /// The app's one stage mapping.
  final InstrumentHues hues;

  /// Grid, label and surface colours.
  final ChartInk ink;

  /// How much of the reveal has run.
  final double progress;

  /// The clocks under the plot, left to right, evenly spaced across the night.
  final List<String> axis;

  /// The ribbon's thickness as a fraction of one lane's pitch.
  static const double bandFraction = 0.42;

  /// The block's corner. Square enough that a short bout keeps its width.
  static const double bandRadius = 1.5;

  /// How wide a step between levels is drawn.
  static const double riserWidth = 4;

  /// Every hairline on this chart.
  static const double hairlineWidth = 1;

  /// The dotted level rule — dash, then gap.
  static const double dash = 2;
  static const double dashGap = 4;

  /// The strip under the plot that carries the clocks.
  static const double captionStrip = 22;

  /// Room above the plot box.
  static const double padTop = 6;

  /// The gap between the plot's bottom edge and the clocks.
  static const double captionGap = 6;

  /// The narrowest a block may draw. A one-minute bout on a nine-hour night is
  /// a third of a pixel; at that width it is not drawn at all, and a stage the
  /// night actually contained would be missing from the picture.
  static const double minBlockWidth = 1.5;

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
    _paintLevels(canvas, box, lane);
    _paintFrame(canvas, box);
    _paintRibbon(canvas, box, window, lane, band);
    _paintAxis(canvas, box);
  }

  /// The plot fills the width; the clocks sit in a strip beneath it.
  ChartBox _box(Size size) {
    const top = padTop;
    final bottom = size.height - captionStrip;
    return ChartBox(
      plot: Rect.fromLTRB(hairlineWidth, top, size.width - hairlineWidth, bottom),
      values: Rect.zero,
      captions: Rect.fromLTRB(0, bottom, size.width, size.height),
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

  /// A dotted rule at each level, so an empty level still reads as a level.
  void _paintLevels(Canvas canvas, ChartBox box, double lane) {
    final paint = Paint()
      ..color = revealed(ink.grid, progress)
      ..strokeWidth = hairlineWidth;
    for (var i = 0; i < kHypnogramLanes.length; i++) {
      final y = box.plot.top + lane * (i + 0.5);
      var x = box.plot.left;
      while (x < box.plot.right) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + dash, box.plot.right), y),
          paint,
        );
        x += dash + dashGap;
      }
    }
  }

  /// The box around the plot.
  void _paintFrame(Canvas canvas, ChartBox box) {
    canvas.drawRect(
      box.plot,
      Paint()
        ..color = revealed(ink.grid, progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = hairlineWidth,
    );
  }

  /// The night as one band that steps between levels.
  ///
  /// **The reveal sweeps along the night; it does not inflate the blocks.**
  /// Growing every band's height at once made the whole plot pulse, and a night
  /// is a sequence — so it arrives as one.
  void _paintRibbon(
    Canvas canvas,
    ChartBox box,
    double window,
    double lane,
    double band,
  ) {
    final t = progress.clamp(0.0, 1.0);
    if (t <= 0) {
      return;
    }
    final reach = box.plot.left + box.plot.width * t;
    for (var i = 0; i < spans.length; i++) {
      final span = spans[i];
      final left = _x(box, span.startOffsetMin, window);
      if (left > reach) {
        break;
      }
      final centre = _laneCentre(box, span.stage, lane);
      // The step INTO this stage, drawn first so the block's own square end
      // covers the join rather than the riser overprinting it.
      if (i > 0) {
        final from = _laneCentre(box, spans[i - 1].stage, lane);
        if (from != centre) {
          final top = math.min(from, centre) - band / 2;
          final bottom = math.max(from, centre) + band / 2;
          canvas.drawRect(
            Rect.fromLTRB(left, top, left + riserWidth, bottom),
            Paint()..color = sleepStageColor(hues, span.stage),
          );
        }
      }
      final right = math.min(_x(box, span.endOffsetMin, window), reach);
      final rect = Rect.fromLTWH(
        left,
        centre - band / 2,
        math.max(right - left, minBlockWidth),
        band,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(math.min(bandRadius, rect.width / 2)),
        ),
        Paint()..color = sleepStageColor(hues, span.stage),
      );
    }
  }

  /// The clocks, evenly spaced: the first flush left, the last flush right.
  void _paintAxis(Canvas canvas, ChartBox box) {
    if (axis.isEmpty) {
      return;
    }
    final style = ink.labelStyle.copyWith(color: revealed(ink.ink3, progress));
    final last = axis.length - 1;
    for (var i = 0; i < axis.length; i++) {
      final painter = chartLabel(axis[i], style);
      final at = last == 0 ? 0.0 : i / last;
      final x = box.plot.left + box.plot.width * at;
      // Flush at the ends, centred between them — a centred first label hangs
      // off the plot's left edge and reads as belonging to the card, not the
      // axis.
      final left = switch (i) {
        0 => x,
        _ when i == last => x - painter.width,
        _ => x - painter.width / 2,
      };
      painter.paint(canvas, Offset(left, box.captions.top + captionGap));
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
      old.axis != axis ||
      old.ink.family != ink.family;
}
