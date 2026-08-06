/// [HDeviation] — a series drawn as **distance from the owner's own normal**.
///
/// ## What makes this a different chart and not a restyled one
///
/// [HArea] fills from the curve down to the **floor of the box**, so its ink
/// encodes the absolute value: a taller fill means a bigger number. That is the
/// right mark for a quantity (steps, calories, a heart rate over a day).
///
/// It is the wrong mark for HRV. Absolute RMSSD is noisy, individual, and means
/// almost nothing on its own — `hrv_recovery_marker` and the coach both read it
/// as *movement against the person's own baseline*, and the card's own note has
/// always said "trends matter far more than any single night". So this painter
/// fills from the curve to the **baseline line**, and its ink encodes the one
/// thing worth reading: how far from normal, and which side.
///
/// Above and below are the SAME colour. `palette.dart` rations `fav`/`unf` to
/// judgement, and a night above baseline is not a merit badge — it is a night
/// above baseline. The reader sees the size of the departure; the note beside
/// the chart is where any reading of it belongs.
///
/// ## With no baseline it draws a bare line, and the card says why
///
/// [reference] is nullable on purpose. The server ships a 30-day median for a
/// metric or it does not (`read/recovery.py`, `read/today_series.py`), and the
/// client must never invent one — a median of the fourteen points on screen is a
/// *second definition* of the owner's normal, computed over a different window
/// from the one every other surface quotes. `CLAUDE.md` forbids exactly that,
/// and this repo has already shipped a fabricated flat line once.
///
/// So: no baseline → no fill, no line, and the caller states the absence.
///
/// Owner-directed departure from the verbatim-legacy rule, 2026-08-06; see
/// `chart_reference.dart`.
///
/// ## No scrub, unlike [HArea]
///
/// Deliberate, and it is a real (small) loss. `HArea` and `HBars` each carry
/// their own ported copy of the touch-scrub state machine; a third copy would be
/// the duplication Standards §1 forbids, and extracting it would mean editing
/// two verbatim-ported painters inside a change that is about something else.
/// The card's header carries the current reading and its note carries the
/// comparison, so no number is unreachable. Reported.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';
import 'package:healthee/shared/charts/chart_reference.dart';

/// A line over [data], filled to [reference] rather than to the floor.
class HDeviation extends StatelessWidget {
  /// [data] is oldest first and is never padded; [reference] is the server's
  /// baseline, or null when it ships none.
  const HDeviation(
    this.data, {
    required this.color,
    required this.progress,
    this.reference,
    this.height = 52,
    this.strokeWidth = 2.2,
    super.key,
  });

  /// The values, oldest first.
  final List<double> data;

  /// The metric's hue.
  final Color color;

  /// How much of the line to draw, 0–1.
  final double progress;

  /// The owner's own normal, from the server. Null draws no fill at all.
  final ChartReference? reference;

  /// How tall to draw it.
  final double height;

  /// Line weight.
  final double strokeWidth;

  /// The two-points floor every chart here shares: one point is a reading, not a
  /// trend, and a line needs two.
  static const int minimumPoints = 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _DeviationPainter(
          data: data,
          color: color,
          ink3: colors.ink3,
          progress: progress,
          strokeWidth: strokeWidth,
          reference: reference,
        ),
      ),
    );
  }
}

class _DeviationPainter extends CustomPainter {
  const _DeviationPainter({
    required this.data,
    required this.color,
    required this.ink3,
    required this.progress,
    required this.strokeWidth,
    required this.reference,
  });

  final List<double> data;
  final Color color;
  final Color ink3;
  final double progress;
  final double strokeWidth;
  final ChartReference? reference;

  /// [HArea]'s x-padding, so a deviation chart and an area chart in the same
  /// column start and end their series at the same two pixels.
  static const double _padX = 4;

  /// Flat enough that the baseline line stays legible through it.
  static const double _fillAlpha = 0.22;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < HDeviation.minimumPoints) {
      return;
    }
    final line = reference;
    final scale = ChartScale.of(
      data,
      include: <double>[if (line != null) line.value],
    );
    double x(int i) =>
        _padX + (i / (data.length - 1)) * (size.width - _padX * 2);
    final points = <Offset>[
      for (var i = 0; i < data.length; i++)
        Offset(x(i), scale.y(data[i], size.height)),
    ];
    final path = smoothPath(points);

    if (line != null) {
      _paintDeparture(canvas, size, path, scale.y(line.value, size.height));
      paintChartReference(
        canvas,
        size,
        line,
        scale: scale,
        color: ink3,
        labelStyle: _label.copyWith(color: ink3),
        progress: progress,
      );
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
  }

  /// The region between the curve and the baseline, on whichever side it falls.
  ///
  /// One closed path does both sides: the lobes above and below wind opposite
  /// ways, and non-zero fill takes any region with a non-zero winding number, so
  /// a series that crosses its baseline fills correctly on both sides of the
  /// crossing without the painter having to find the crossings.
  void _paintDeparture(Canvas canvas, Size size, Path curve, double baselineY) {
    if (!baselineY.isFinite) {
      return;
    }
    final region = Path.from(curve)
      ..lineTo(size.width - _padX, baselineY)
      ..lineTo(_padX, baselineY)
      ..close();
    canvas.drawPath(
      region,
      Paint()..color = color.withValues(alpha: _fillAlpha * progress),
    );
  }

  @override
  bool shouldRepaint(_DeviationPainter old) =>
      old.progress != progress ||
      old.data != data ||
      old.color != color ||
      old.reference != reference;
}

const TextStyle _label = TextStyle(
  fontSize: 8,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.6,
);
