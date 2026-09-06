/// **The age scale** — a 28-to-44 ruler carrying two marks: the estimate, and
/// the age the owner actually is.
///
/// Ported from `charts-detail.js`'s `H.charts.ageScale`: 33 ticks across the
/// span, every fourth one taller; the estimate a full-height 2 px rule; the
/// chronological age a 3 px dot at mid-height; five numbers under it.
///
/// ```js
/// const x = value => 16 + (value - 28) / 16 * 308;
/// // ticks   M{16 + i*9.625} {i%4 ? 15 : 8} v{i%4 ? 12 : 19}
/// // estimate  M{x(bio)} 0 V31   stroke-width 2   var(--bio-ink)
/// // actual    circle cx={x(chrono)} cy=18 r=3    var(--bio-ink)
/// ```
///
/// ## Why the ruler is fixed and the marks are not
///
/// The span is the instrument. An auto-scaled ruler would place the same
/// estimate at a different pixel depending on how far the two marks happen to be
/// apart that day, so "further left than last month" would stop meaning
/// anything. It is fixed at 28-44 because that is the range the estimate is
/// defined over.
///
/// The consequence is that a value can fall **off** the ruler, and then it draws
/// nothing rather than being clamped to the end — a mark pinned at 44 says the
/// owner reads 44, which would be a fabrication. The tick strip and the numbers
/// stay, so the slot keeps its height and the reader can see the scale a value
/// missed.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';
import 'package:healthee/shared/v02/instruments/instrument_geometry.dart';

/// The ruler's low end, in years.
const double kAgeScaleLow = 28;

/// Its high end.
const double kAgeScaleHigh = 44;

/// The numbers written under it.
const List<double> kAgeScaleLabels = <double>[28, 32, 36, 40, 44];

/// How many ticks span the ruler. Every fourth is a tall one.
const int kAgeScaleTicks = 33;

/// The 28-44 ruler with the estimate and the chronological age on it.
class AgeScale extends StatelessWidget {
  /// Builds the ruler. [chronologicalAge] of null draws no dot.
  const AgeScale({
    required this.estimate,
    required this.chronologicalAge,
    this.progress = 1,
    super.key,
  });

  /// Identifies the plot for tests.
  static const Key plotKey = ValueKey<String>('age-scale-plot');

  /// The whole instrument's height: the 31 px strip, then the numbers.
  static const double height = 52;

  /// The estimate, in years. Off the ruler draws no marker.
  final double estimate;

  /// The owner's actual age. Null, or off the ruler, draws no dot.
  final double? chronologicalAge;

  /// Reveal progress, 0-1. The ruler is structure and never animates; only the
  /// two marks fade in.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: height,
      child: CustomPaint(
        key: plotKey,
        painter: _AgeScalePainter(
          estimate: estimate,
          chronologicalAge: chronologicalAge,
          progress: progress.clamp(0.0, 1.0),
          ink: colors.bioInk,
          line: colors.bioLine,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AgeScalePainter extends CustomPainter {
  const _AgeScalePainter({
    required this.estimate,
    required this.chronologicalAge,
    required this.progress,
    required this.ink,
    required this.line,
  });

  final double estimate;
  final double? chronologicalAge;
  final double progress;
  final Color ink;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final scale = size.width / 340;
    final left = 16 * scale;
    final right = size.width - 16 * scale;
    double x(double value) => railX(
      value,
      low: kAgeScaleLow,
      high: kAgeScaleHigh,
      left: left,
      right: right,
    );

    final pitch = (right - left) / (kAgeScaleTicks - 1);
    final tick = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var i = 0; i < kAgeScaleTicks; i++) {
      final tall = i % 4 == 0;
      canvas.drawLine(
        Offset(left + i * pitch, tall ? 8 : 15),
        Offset(left + i * pitch, 27),
        tick,
      );
    }

    if (onScale(estimate, low: kAgeScaleLow, high: kAgeScaleHigh)) {
      canvas.drawLine(
        Offset(x(estimate), 0),
        Offset(x(estimate), 31),
        Paint()
          ..color = revealed(ink, progress)
          ..strokeWidth = 2,
      );
    }
    final actual = chronologicalAge;
    if (actual != null &&
        onScale(actual, low: kAgeScaleLow, high: kAgeScaleHigh)) {
      canvas.drawCircle(
        Offset(x(actual), 18),
        3,
        Paint()..color = revealed(ink, progress),
      );
    }

    final style = TypeScale.colourKey.copyWith(
      color: ink.withValues(alpha: ink.a * 0.85),
    );
    for (final value in kAgeScaleLabels) {
      paintLabel(
        canvas,
        chartLabel(formatYears(value), style),
        Offset(x(value), 36),
        anchor: LabelAnchor.middle,
      );
    }
  }

  @override
  bool shouldRepaint(_AgeScalePainter old) =>
      old.estimate != estimate ||
      old.chronologicalAge != chronologicalAge ||
      old.progress != progress ||
      old.ink != ink ||
      old.line != line;
}
