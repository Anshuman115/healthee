/// [HTimingChart] — bedtime and wake time on one "hours from 18:00" scale.
///
/// **Ported from** `instrument_charts.dart`'s `HTimingChart`. Unchanged: the
/// 18:00 origin, the ±0.5 h axis padding rounded outward, five gridlines with
/// wall-clock labels, the Catmull-Rom lines, and the two-dot crosshair with a
/// `bed … wake …` bubble.
///
/// **The 18:00 origin is the whole idea and it is worth stating.** A bedtime of
/// 23:40 and one of 00:20 are forty minutes apart, but on a midnight-origin
/// clock they are 23.7 and 0.3 — a nearly full-height jump that reads as wild
/// irregularity. Shifting the origin to 18:00 puts a normal night's whole range
/// inside one continuous run, so what the line shows is drift rather than an
/// artefact of where the day is cut.
///
/// Changed: `progress` is a parameter (see `chart_primitives.dart`), and the two
/// series are drawn in [HealtheeColors.accent] and its softer pair rather than
/// in two unrelated hues — brief §2 spends colour on judgement, and neither of
/// these lines is one.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';

/// Where the timing scale starts, in hours. See the library docstring.
const double kTimingOriginHour = 18;

/// Two smooth lines: when sleep began, and when it ended.
class HTimingChart extends StatefulWidget {
  /// [bedtime] and [wake] are hours from 18:00, oldest first and the same length.
  const HTimingChart({
    required this.bedtime,
    required this.wake,
    required this.progress,
    this.height = 130,
    super.key,
  });

  /// Sleep onset, in hours from 18:00.
  final List<double> bedtime;

  /// Wake, in the same units.
  final List<double> wake;

  /// How much of each line to draw, 0–1.
  final double progress;

  /// How tall to draw it.
  final double height;

  @override
  State<HTimingChart> createState() => _HTimingChartState();
}

class _HTimingChartState extends State<HTimingChart> {
  int? _selected;

  void _pick(Offset position, Size size) {
    final count = widget.bedtime.length;
    if (count < 2) {
      return;
    }
    const leftPad = 38.0;
    final index =
        (((position.dx - leftPad) / (size.width - leftPad)) * (count - 1))
            .round();
    setState(() => _selected = (index >= 0 && index < count) ? index : null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _pick(details.localPosition, size),
            onPanStart: (details) => _pick(details.localPosition, size),
            onPanUpdate: (details) => _pick(details.localPosition, size),
            onPanEnd: (_) => setState(() => _selected = null),
            child: CustomPaint(
              size: size,
              painter: _TimingPainter(
                bedtime: widget.bedtime,
                wake: widget.wake,
                colors: colors,
                selected: _selected,
                progress: widget.progress,
                labelStyle: TextStyle(fontSize: 9, color: colors.ink3),
                bubbleStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimingPainter extends CustomPainter {
  const _TimingPainter({
    required this.bedtime,
    required this.wake,
    required this.colors,
    required this.selected,
    required this.progress,
    required this.labelStyle,
    required this.bubbleStyle,
  });

  final List<double> bedtime;
  final List<double> wake;
  final HealtheeColors colors;
  final int? selected;
  final double progress;
  final TextStyle labelStyle;
  final TextStyle bubbleStyle;

  static const double _leftPad = 38;
  static const double _topPad = 6;
  static const double _bottomPad = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...bedtime, ...wake];
    if (all.length < 2) {
      return;
    }
    final low = all.reduce((a, b) => a < b ? a : b);
    final high = all.reduce((a, b) => a > b ? a : b);
    final yMin = (low - 0.5).floorToDouble();
    final yMax = (high + 0.5).ceilToDouble();
    if (yMax <= yMin) {
      return;
    }
    final plotWidth = size.width - _leftPad;
    final plotHeight = size.height - _topPad - _bottomPad;
    double xAt(int i, int count) =>
        _leftPad + (count <= 1 ? 0.0 : i / (count - 1) * plotWidth);
    double yAt(double value) =>
        _topPad + (1 - (value - yMin) / (yMax - yMin)) * plotHeight;

    _paintGrid(canvas, size, yMin, yMax, yAt);
    _paintLine(canvas, bedtime, colors.accent, xAt, yAt);
    _paintLine(
      canvas,
      wake,
      colors.accent.withValues(alpha: 0.45),
      xAt,
      yAt,
    );
    _paintCrosshair(canvas, size, xAt, yAt);
  }

  void _paintGrid(
    Canvas canvas,
    Size size,
    double yMin,
    double yMax,
    double Function(double) yAt,
  ) {
    final grid = Paint()
      ..color = colors.line.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var step = 0; step <= 4; step++) {
      final value = yMin + (yMax - yMin) * step / 4;
      final y = yAt(value);
      canvas.drawLine(Offset(_leftPad, y), Offset(size.width, y), grid);
      final label = chartLabel(clockAt(value), labelStyle);
      label.paint(canvas, Offset(_leftPad - label.width - 5, y - label.height / 2));
    }
  }

  void _paintLine(
    Canvas canvas,
    List<double> data,
    Color color,
    double Function(int, int) xAt,
    double Function(double) yAt,
  ) {
    final points = [
      for (var i = 0; i < data.length; i++) Offset(xAt(i, data.length), yAt(data[i])),
    ];
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in smoothPath(points).computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  void _paintCrosshair(
    Canvas canvas,
    Size size,
    double Function(int, int) xAt,
    double Function(double) yAt,
  ) {
    final index = selected;
    if (index == null || index < 0 || index >= bedtime.length) {
      return;
    }
    final x = xAt(index, bedtime.length);
    canvas.drawLine(
      Offset(x, _topPad),
      Offset(x, size.height - _bottomPad),
      Paint()
        ..color = colors.ink3.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(Offset(x, yAt(bedtime[index])), 3, Paint()..color = colors.accent);
    canvas.drawCircle(
      Offset(x, yAt(wake[index])),
      3,
      Paint()..color = colors.accent.withValues(alpha: 0.45),
    );
    drawChartTooltip(
      canvas,
      size,
      'bed ${clockAt(bedtime[index])}  ·  wake ${clockAt(wake[index])}',
      anchorX: x,
      background: colors.surface,
      border: colors.line2,
      style: bubbleStyle,
    );
  }

  /// Hours-from-18:00 back to a wall clock.
  static String clockAt(double hoursFromOrigin) {
    final wall = (hoursFromOrigin + kTimingOriginHour) % 24;
    final hour = wall.floor();
    final minute = ((wall - hour) * 60).round();
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(_TimingPainter old) =>
      old.progress != progress ||
      old.bedtime != bedtime ||
      old.selected != selected;
}
