/// [HScatter] — one dot per paired day behind a finding.
///
/// The finding-detail screen used to print the prototype's own sentence here:
/// *"The response contains a summary, not the underlying paired values. A
/// scatter plot appears here when those values are available."* They are
/// available now (`docs/BACKEND_GAPS_FROM_UI.md` B1), so this is that promise
/// kept rather than a chart somebody thought of.
///
/// ## Why a bare cloud, and nothing fitted through it
///
/// **No trend line, no fit, no ellipse.** The screen this sits on is built
/// around one sentence — *"That doesn't tell us why"* — and its own tests assert
/// that no causal verb appears anywhere on it. A line through a cloud is a
/// causal verb drawn instead of written: it turns the reader's eye from "these
/// two moved together on these days" into "this one produces that one". The
/// effect size and its q-value are stated in words two lines above, which is
/// where a claim about strength belongs.
///
/// It is also the only honest option here. The server sends the pairs; it does
/// not send a regression, and computing one on the phone would be a second
/// statistic beside the one the payload carries, free to disagree with it. The
/// rank correlation the server reports is not even the quantity an ordinary
/// least-squares line would draw.
///
/// ## What the axes do and do not say
///
/// The extremes are labelled and nothing else is. There is no gridline and no
/// zero: both series are in their own units, on their own scales, and a shared
/// origin would imply a comparability they do not have. Each axis spans exactly
/// the range its own values occupy, so the cloud fills the box — the shape is
/// the reading, and the numbers at the ends are what stop that shape from being
/// mistaken for a magnitude.
///
/// A series that never moved draws its dots down the centre of its axis rather
/// than flush against an edge, for the reason `h_spark.dart` gives: pinned to
/// the floor, "did not vary" looks like "sat at its minimum".
///
/// `progress` is a parameter and this widget owns no ticker
/// (`chart_primitives.dart`).
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/models/finding.dart';

/// A cloud of paired observations, x = `metric_a`, y = `metric_b`.
class HScatter extends StatelessWidget {
  /// [points] are the finding's own pairs; [progress] is 0–1 from `RevealOnce`.
  const HScatter(
    this.points, {
    required this.color,
    required this.progress,
    this.height = 148,
    super.key,
  });

  /// The paired days. Fewer than [Finding.minPlottablePoints] draws nothing —
  /// the caller checks `isPlottable` and says so in words instead.
  final List<FindingPoint> points;

  /// The dot colour. An identity tag, never a judgement colour.
  final Color color;

  /// How much of the cloud has arrived, 0–1.
  final double progress;

  /// How tall to draw it.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.length < Finding.minPlottablePoints) {
      return SizedBox(height: height, width: double.infinity);
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ScatterPainter(
          points: points,
          color: color,
          progress: progress.clamp(0.0, 1.0),
        ),
      ),
    );
  }
}

class _ScatterPainter extends CustomPainter {
  const _ScatterPainter({
    required this.points,
    required this.color,
    required this.progress,
  });

  final List<FindingPoint> points;
  final Color color;
  final double progress;

  /// Room for a dot to sit at an extreme without being clipped in half.
  static const double _inset = 6;

  /// Dot radius. Small enough that a hundred of them stay a cloud.
  static const double _dotRadius = 3;

  /// Fill opacity. Dots overlap on a dense series, and a solid fill would turn
  /// the busiest region — the one carrying the most days — into a single blob.
  /// At this alpha the overlaps read as density, which is information.
  static const double _dotAlpha = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final xs = <double>[for (final p in points) p.a];
    final ys = <double>[for (final p in points) p.b];
    final scaleX = _Axis(xs, _inset, size.width - _inset);
    // y is inverted: a bigger value is higher on the screen.
    final scaleY = _Axis(ys, size.height - _inset, _inset);

    final paint = Paint()
      ..color = color.withValues(alpha: _dotAlpha * progress);
    for (final point in points) {
      canvas.drawCircle(
        Offset(scaleX.at(point.a), scaleY.at(point.b)),
        _dotRadius * progress,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScatterPainter old) =>
      old.progress != progress || old.points != points || old.color != color;
}

/// One axis: a value range mapped onto a pixel range.
///
/// Its own type because the flat-series rule has to hold on BOTH axes and a
/// pair of near-identical closures inside `paint` is how one of them ends up
/// fixed and the other not.
class _Axis {
  _Axis(List<double> values, this.from, this.to)
    : min = values.reduce((a, b) => a < b ? a : b),
      max = values.reduce((a, b) => a > b ? a : b);

  final double min;
  final double max;
  final double from;
  final double to;

  bool get isFlat => max == min;

  /// Where [value] lands. A series that never moved sits on the centre line
  /// rather than against an edge — see the library docstring.
  double at(double value) => isFlat
      ? (from + to) / 2
      : from + ((value - min) / (max - min)) * (to - from);
}
