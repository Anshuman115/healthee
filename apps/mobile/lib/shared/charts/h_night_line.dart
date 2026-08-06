/// [HNightLine] — a fortnight of nightly readings, joined by STRAIGHT segments.
///
/// ## Connected, and that reverses this file's first revision
///
/// It shipped on 2026-08-06 as `HNightDots`: one unconnected mark a night, on
/// the argument that a line between Tuesday's overnight minimum and Wednesday's
/// asserts saturations at times nobody was asleep. The owner reversed it the
/// same day — *"blood oxygen you just made it bad"* — and the corpus is on his
/// side. `wearable_spo2_validity` D1 is that SpO2 is trustworthy **as a trend
/// over multiple nights**; a scatter of fourteen identical dots is the shape
/// that makes a trend hardest to see, so the mark was arguing against the only
/// reading the note permits.
///
/// The join is **straight, never smoothed**, and that is the honest half of the
/// reversal kept:
///
///   * a Catmull-Rom curve through fourteen nights overshoots between them, so
///     the drawn minimum can sit BELOW every night actually measured. On a chart
///     whose whole subject is the nightly low, an invented lower low is the one
///     artefact that must not exist. `smoothPath` is therefore not used here.
///   * every night still carries its own mark, so the reader can see which
///     points are measurements and which pixels are interpolation.
///
/// ## Every night is drawn the same
///
/// D1/D3: *"a trend over multiple nights, never a single-reading alarm"*, and
/// *"never call out individual low-reading minutes (most are sensor
/// artefacts)"*. So no night below the reference is coloured, enlarged or ringed
/// — the only thing allowed to say anything is a sustained run, and it says it
/// in prose beside the chart (`metric_note.dart`).
///
/// ## The window
///
/// [window] fixes the y-scale instead of fitting it to the fortnight. See
/// [ChartScale.window] for the measurement argument; the caller states it when a
/// night falls outside.
///
/// ## No scrub
///
/// Same call as [HDeviation], same reason: the caption under this chart already
/// prints the two numbers that matter (last night's low, the fortnight's
/// lowest), and a third copy of `HArea`'s touch state machine is the duplication
/// Standards §1 forbids.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/charts/chart_reference.dart';

/// A straight-segment line over [data] with a mark on every night.
class HNightLine extends StatelessWidget {
  /// [data] is oldest first and is never padded.
  const HNightLine(
    this.data, {
    required this.color,
    required this.progress,
    this.reference,
    this.window,
    this.height = 52,
    this.radius = 2.6,
    this.strokeWidth = 2,
    super.key,
  });

  /// The nightly values, oldest first.
  final List<double> data;

  /// The metric's hue. Every night takes it — see the library docstring.
  final Color color;

  /// How much of the series has appeared, 0–1.
  final double progress;

  /// The line the nights are read against, or null.
  final ChartReference? reference;

  /// A fixed y-scale, widened only by values outside it. Null auto-scales.
  final ({double low, double high})? window;

  /// How tall to draw it.
  final double height;

  /// Night-mark radius at full reveal.
  final double radius;

  /// Line weight.
  final double strokeWidth;

  /// Two nights is the floor: one night is a reading, not a fortnight.
  static const int minimumNights = 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _NightLinePainter(
          data: data,
          color: color,
          ink3: colors.ink3,
          progress: progress,
          radius: radius,
          strokeWidth: strokeWidth,
          reference: reference,
          window: window,
        ),
      ),
    );
  }
}

class _NightLinePainter extends CustomPainter {
  const _NightLinePainter({
    required this.data,
    required this.color,
    required this.ink3,
    required this.progress,
    required this.radius,
    required this.strokeWidth,
    required this.reference,
    required this.window,
  });

  final List<double> data;
  final Color color;
  final Color ink3;
  final double progress;
  final double radius;
  final double strokeWidth;
  final ChartReference? reference;
  final ({double low, double high})? window;

  /// The same x-padding the line charts use, so a night and a curve in the same
  /// column begin at the same pixel.
  static const double _padX = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < HNightLine.minimumNights) {
      return;
    }
    final line = reference;
    final bounds = window;
    final include = <double>[if (line != null) line.value];
    final scale = bounds == null
        ? ChartScale.of(data, include: include)
        : ChartScale.window(
            data,
            low: bounds.low,
            high: bounds.high,
            include: include,
          );
    if (line != null) {
      paintChartReference(
        canvas,
        size,
        line,
        scale: scale,
        color: ink3,
        progress: progress,
      );
    }

    double x(int i) =>
        _padX + (i / (data.length - 1)) * (size.width - _padX * 2);
    final points = <Offset>[
      for (var i = 0; i < data.length; i++)
        Offset(x(i), scale.y(data[i], size.height)),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
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

    // Each night's mark grows in as the reveal reaches it, so the fortnight
    // fills left to right with the line rather than appearing all at once.
    final arrived = progress * data.length;
    final paint = Paint()..color = color;
    for (var i = 0; i < points.length; i++) {
      final grown = (arrived - i).clamp(0.0, 1.0);
      if (grown == 0) {
        continue;
      }
      canvas.drawCircle(points[i], radius * grown, paint);
    }
  }

  @override
  bool shouldRepaint(_NightLinePainter old) =>
      old.progress != progress ||
      old.data != data ||
      old.color != color ||
      old.window != window ||
      old.reference != reference;
}
