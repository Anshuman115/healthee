/// [HNightDots] — one mark per night, unconnected, against a reference line.
///
/// ## Why the nights are not joined up
///
/// A smooth line between Tuesday's overnight minimum and Wednesday's asserts
/// values in between that were never measured — there is no oxygen saturation
/// "at 3 p.m. on the way from one night to the next". For fourteen discrete
/// nightly readings, fourteen discrete marks is the honest shape, and it is also
/// what makes this chart legible as a different question from the three around
/// it: the reader counts nights instead of following a trend.
///
/// `wearable_spo2_validity` D1/D3 are the binding reason this stays a
/// multi-night chart at all: *"surface SpO2 as a trend over multiple nights,
/// never a single-reading alarm"*, and *"never call out individual low-reading
/// minutes (most are sensor artefacts)"*. So:
///
///   * every dot is drawn the same. No night is emphasised, coloured, enlarged
///     or ringed for being low — that is precisely the single-reading callout
///     the note forbids, and the sensor's error is unquantified (#98).
///   * the only thing allowed to *say* anything is a sustained multi-night run,
///     and it says it in prose beside the chart, not in ink on it.
///
/// The ~92% line is drawn as a [ChartReferenceKind.convention] — dashed, and
/// labelled as a convention — because it is one. See `chart_reference.dart`.
///
/// Owner-directed departure from the verbatim-legacy rule, 2026-08-06.
///
/// ## No scrub
///
/// Same call as [HDeviation], same reason, and the caption under this chart
/// already prints the two numbers that matter (last night's low, the fortnight's
/// lowest).
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/charts/chart_reference.dart';

/// One dot per night over [data], revealed left to right.
class HNightDots extends StatelessWidget {
  /// [data] is oldest first and is never padded.
  const HNightDots(
    this.data, {
    required this.color,
    required this.progress,
    this.reference,
    this.height = 52,
    this.radius = 3,
    super.key,
  });

  /// The nightly values, oldest first.
  final List<double> data;

  /// The metric's hue. Every dot takes it — see the library docstring.
  final Color color;

  /// How much of the series has appeared, 0–1.
  final double progress;

  /// The line the nights are read against, or null.
  final ChartReference? reference;

  /// How tall to draw it.
  final double height;

  /// Dot radius at full reveal.
  final double radius;

  /// Two nights is the floor: one dot is a reading, not a fortnight.
  static const int minimumNights = 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _NightDotsPainter(
          data: data,
          color: color,
          ink3: colors.ink3,
          progress: progress,
          radius: radius,
          reference: reference,
        ),
      ),
    );
  }
}

class _NightDotsPainter extends CustomPainter {
  const _NightDotsPainter({
    required this.data,
    required this.color,
    required this.ink3,
    required this.progress,
    required this.radius,
    required this.reference,
  });

  final List<double> data;
  final Color color;
  final Color ink3;
  final double progress;
  final double radius;
  final ChartReference? reference;

  /// The same x-padding the line charts use, so a dot and a curve in the same
  /// column begin at the same pixel.
  static const double _padX = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < HNightDots.minimumNights) {
      return;
    }
    final line = reference;
    final scale = ChartScale.of(
      data,
      include: <double>[if (line != null) line.value],
    );
    if (line != null) {
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
    // Each dot grows in as the reveal reaches it, so the fortnight fills left to
    // right like the line charts do rather than all appearing at once.
    final arrived = progress * data.length;
    final paint = Paint()..color = color;
    for (var i = 0; i < data.length; i++) {
      final grown = (arrived - i).clamp(0.0, 1.0);
      if (grown == 0) {
        continue;
      }
      final x = _padX + (i / (data.length - 1)) * (size.width - _padX * 2);
      canvas.drawCircle(
        Offset(x, scale.y(data[i], size.height)),
        radius * grown,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_NightDotsPainter old) =>
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
