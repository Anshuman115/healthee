/// The day's heart rate, drawn as a line over its own measured range.
///
/// The one chart in this package, and it earns its place the way brief §5 asks:
/// the number alone says "68 bpm now", the line says whether that is the
/// afternoon it has been having. Nothing is smoothed, interpolated or filled —
/// a gap in the samples is a gap in the line, because the strap genuinely did
/// not measure then and a continuous curve across it would draw minutes that
/// were never recorded.
///
/// ## What it deliberately does not draw
///
/// No baseline band, no shaded normal range, no population reference. Those are
/// comparisons, and the honest ones are the owner's own rolling baselines, which
/// the server derives. Drawing a band here would mean computing one on the
/// phone — the second-definition failure this whole package is arranged against.
/// The axis labels are the min and max **of the samples themselves**, which is a
/// statement about the data on screen and nothing more.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/device/device_day.dart';

/// A line over one day of samples, revealed left-to-right by [progress].
class DayLineChart extends StatelessWidget {
  /// [points] must be in time order; [progress] is 0–1 from `RevealOnce`.
  const DayLineChart({
    required this.points,
    required this.progress,
    required this.color,
    this.height = 96,
    this.showRange = true,
    super.key,
  });

  /// The samples, oldest first.
  final List<DevicePoint> points;

  /// How much of the line to draw, 0–1.
  final double progress;

  /// How tall to draw it.
  final double height;

  /// The line's colour and, at low alpha, the fill under it.
  ///
  /// A parameter rather than [HealtheeColors.accent] as it used to be: the Today
  /// grid ties every chart to its metric's identity tag, and a day of heart rate
  /// drawn in the accent while the module's dot is the heart tag would be the one
  /// chart on the screen that does not match its own card.
  final Color color;

  /// Whether to print `49–112 across 869 samples` beneath the line.
  ///
  /// Off when the caller has already put the range in its header, which is where
  /// the legacy 24 h module puts it — the same sentence twice on one card reads
  /// as a layout mistake.
  final bool showRange;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (points.length < 2) {
      // One point is not a line, and stretching it across the width would draw
      // a flat day the strap never measured.
      return const SizedBox.shrink();
    }
    final values = points.map((point) => point.value).toList();
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _DayLinePainter(
              points: points,
              low: low,
              high: high,
              progress: progress,
              line: color,
              fill: color.withValues(alpha: 0.14),
            ),
          ),
        ),
        if (showRange) ...[
          const SizedBox(height: Insets.sm),
          Text(
            '${low.round()}–${high.round()} across ${points.length} samples',
            style: text.labelSmall?.copyWith(color: colors.ink3),
          ),
        ],
      ],
    );
  }
}

class _DayLinePainter extends CustomPainter {
  const _DayLinePainter({
    required this.points,
    required this.low,
    required this.high,
    required this.progress,
    required this.line,
    required this.fill,
  });

  final List<DevicePoint> points;
  final double low;
  final double high;
  final double progress;
  final Color line;
  final Color fill;

  /// A gap wider than this ends the stroke rather than bridging it.
  ///
  /// The strap samples on its own schedule, and a stretch with nothing in it
  /// means it was off the wrist. Twenty minutes is comfortably wider than the
  /// densest cadence and narrower than any real removal.
  static const Duration _breakAfter = Duration(minutes: 20);

  @override
  void paint(Canvas canvas, Size size) {
    final first = points.first.at.millisecondsSinceEpoch.toDouble();
    final last = points.last.at.millisecondsSinceEpoch.toDouble();
    final span = (last - first).abs() < 1 ? 1.0 : last - first;
    final range = (high - low).abs() < 1e-9 ? 1.0 : high - low;
    final cutoff = size.width * progress.clamp(0.0, 1.0);

    Offset at(DevicePoint point) => Offset(
      (point.at.millisecondsSinceEpoch - first) / span * size.width,
      size.height - (point.value - low) / range * (size.height - 2) - 1,
    );

    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final area = Paint()..color = fill;

    var path = Path();
    var started = false;
    var runStart = Offset.zero;

    void closeRun(Offset end) {
      if (!started) {
        return;
      }
      canvas.drawPath(path, stroke);
      final underneath = Path.from(path)
        ..lineTo(end.dx, size.height)
        ..lineTo(runStart.dx, size.height)
        ..close();
      canvas.drawPath(underneath, area);
      path = Path();
      started = false;
    }

    var previous = points.first;
    for (final point in points) {
      final here = at(point);
      if (here.dx > cutoff) {
        break;
      }
      final broke = point.at.difference(previous.at) > _breakAfter;
      if (!started || broke) {
        closeRun(at(previous));
        path.moveTo(here.dx, here.dy);
        runStart = here;
        started = true;
      } else {
        path.lineTo(here.dx, here.dy);
      }
      previous = point;
    }
    closeRun(at(previous));
  }

  @override
  bool shouldRepaint(_DayLinePainter old) =>
      old.progress != progress ||
      old.points.length != points.length ||
      old.low != low ||
      old.high != high ||
      old.line != line;
}
