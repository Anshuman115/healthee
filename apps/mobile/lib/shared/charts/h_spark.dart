/// [HSpark] — the 30 px sparkline in every module of the legacy metric grid.
///
/// **Ported from** `design_reference/project/app/charts.jsx`'s `Sparkline`, with
/// its geometry unchanged: `x(i) = i/(n-1) * width`, `y(v) = height - 3 -
/// ((v-min)/span) * (height - 6)`, the same Catmull-Rom smoothing every other
/// chart here uses, a 2 px round-capped stroke, and a **2.6 px dot on the last
/// point**. The dot is not decoration — in a strip 30 px tall with no axis, it is
/// the only thing that says which end is today.
///
/// ## Not [HArea] with the fill turned off
///
/// They are different curves. `HArea` pads the y-range by 18% so a filled area
/// has headroom, and insets x by 4 px for its scrub bubble; this one uses the
/// full range and the full width, which is what makes a 30 px sparkline show any
/// shape at all. Two charts that look similar and are not is exactly the case
/// Standards §1 means by one reason to change — `HArea` changes when the big
/// scrubbable charts do, and this changes when the grid does.
///
/// `progress` is a parameter and this widget owns no ticker, for the reason
/// `chart_primitives.dart` sets out at length.
library;

import 'package:flutter/material.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';

/// A tiny smoothed line over [data], with a dot on the newest point.
class HSpark extends StatelessWidget {
  /// [data] is oldest first; [progress] is 0–1 from `RevealOnce`.
  const HSpark(
    this.data, {
    required this.color,
    required this.progress,
    this.height = 26,
    this.strokeWidth = 2,
    super.key,
  });

  /// The values, oldest first. Fewer than two draws nothing.
  final List<double> data;

  /// The line's colour. An identity tag, never a judgement colour.
  final Color color;

  /// How much of the line has drawn, 0–1.
  final double progress;

  /// How tall to draw it.
  final double height;

  /// Line weight.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    // A single point has no shape, and drawing a flat line through it would
    // assert a trend from one reading. Nothing is the honest render.
    if (data.length < 2) {
      return SizedBox(height: height, width: double.infinity);
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(
          data: data,
          color: color,
          progress: progress.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter({
    required this.data,
    required this.color,
    required this.progress,
    required this.strokeWidth,
  });

  final List<double> data;
  final Color color;
  final double progress;
  final double strokeWidth;

  /// Legacy's vertical inset — 3 px top and bottom.
  static const double _inset = 3;

  /// Legacy's end-point dot radius.
  static const double _dotRadius = 2.6;

  @override
  void paint(Canvas canvas, Size size) {
    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final flat = max == min;
    final span = flat ? 1.0 : (max - min);
    double x(int i) => (i / (data.length - 1)) * size.width;
    // The one departure from legacy's geometry, and it is a correctness fix
    // rather than a tidy-up. Legacy's `(v-min)/span` with a zero span puts a
    // FLAT series flush against the floor of the box, which reads as a metric
    // sitting at the bottom of its range when what actually happened is that it
    // did not move. A fortnight of identical readings is drawn on the centre
    // line, where "no change" is what it looks like.
    double y(double v) => flat
        ? size.height / 2
        : size.height - _inset - ((v - min) / span) * (size.height - _inset * 2);

    final points = [
      for (var i = 0; i < data.length; i++) Offset(x(i), y(data[i])),
    ];
    final path = smoothPath(points);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // The dot arrives with the line rather than before it, so a half-drawn
    // reveal never marks a point the stroke has not reached.
    canvas.drawCircle(
      points.last,
      _dotRadius * progress,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.progress != progress || old.data != data || old.color != color;
}
