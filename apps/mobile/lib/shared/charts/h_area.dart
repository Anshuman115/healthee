/// [HArea] — a smooth area + line with a draw-on reveal, scrubbable by touch.
///
/// **Ported from** `instrument_charts.dart`'s `HArea`. The painter's geometry is
/// unchanged: the same 0.18 y-padding, the same 4 px x-padding, the same
/// gradient from 32% alpha to nothing, the same crosshair-dot-bubble on touch.
///
/// Two changes, both required by this repo's rules:
///
///   * **`progress` is a parameter, not a controller.** See
///     `chart_primitives.dart` for the whole argument; the short version is that
///     an `AnimationController` in a `ListView.builder` item replays on every
///     scroll-back, which `CLAUDE.md` names as a hard rule.
///   * **Colours are roles.** `HColors.paper`/`paper2` became
///     [HealtheeColors.surface]/[HealtheeColors.ink]; the caller passes the line
///     colour, which is `accent` for the owner's own data everywhere it is used.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';

/// A smooth area chart over [data], revealed left-to-right by [progress].
class HArea extends StatefulWidget {
  /// [data] is in series order; [progress] is 0–1 from `RevealOnce`.
  const HArea(
    this.data, {
    required this.color,
    required this.progress,
    this.height = 30,
    this.strokeWidth = 2.2,
    this.fill = true,
    this.unit = '',
    this.digits = 0,
    super.key,
  });

  /// The values, oldest first.
  final List<double> data;

  /// The line colour. `accent` for the owner's own data.
  final Color color;

  /// How much of the line to draw, 0–1.
  final double progress;

  /// How tall to draw it.
  final double height;

  /// Line weight.
  final double strokeWidth;

  /// Whether to fill under the line.
  final bool fill;

  /// Unit shown in the scrub bubble.
  final String unit;

  /// Decimal places in the scrub bubble.
  final int digits;

  @override
  State<HArea> createState() => _HAreaState();
}

class _HAreaState extends State<HArea> {
  int? _touch;
  double _width = 1;

  /// Touch state is per-instance and ephemeral, so it stays in `State`. Losing
  /// it when the item scrolls away is correct — nobody is still holding a finger
  /// on a chart that is off screen.
  void _scrub(double dx) {
    if (widget.data.length < 2) {
      return;
    }
    const padX = 4.0;
    final fraction = ((dx - padX) / (_width - padX * 2)).clamp(0.0, 1.0);
    setState(() => _touch = (fraction * (widget.data.length - 1)).round());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _scrub(details.localPosition.dx),
      onTapUp: (_) => setState(() => _touch = null),
      onHorizontalDragStart: (details) => _scrub(details.localPosition.dx),
      onHorizontalDragUpdate: (details) => _scrub(details.localPosition.dx),
      onHorizontalDragEnd: (_) => setState(() => _touch = null),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, box) {
            _width = box.maxWidth;
            return CustomPaint(
              painter: _AreaPainter(
                data: widget.data,
                color: widget.color,
                ink3: colors.ink3,
                bubbleInk: colors.surface,
                progress: widget.progress,
                strokeWidth: widget.strokeWidth,
                fill: widget.fill,
                touch: _touch,
                unit: widget.unit,
                digits: widget.digits,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AreaPainter extends CustomPainter {
  const _AreaPainter({
    required this.data,
    required this.color,
    required this.ink3,
    required this.bubbleInk,
    required this.progress,
    required this.strokeWidth,
    required this.fill,
    required this.touch,
    required this.unit,
    required this.digits,
  });

  final List<double> data;
  final Color color;
  final Color ink3;
  final Color bubbleInk;
  final double progress;
  final double strokeWidth;
  final bool fill;
  final int? touch;
  final String unit;
  final int digits;

  /// Legacy's `yPad` and `padX`, unchanged.
  static const double _yPad = 0.18;
  static const double _padX = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) {
      return;
    }
    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final span = (max - min) == 0 ? 1.0 : (max - min);
    final low = min - span * _yPad;
    final high = max + span * _yPad;
    double x(int i) => _padX + (i / (data.length - 1)) * (size.width - _padX * 2);
    double y(double v) =>
        size.height - 3 - ((v - low) / (high - low)) * (size.height - 6);

    final points = [
      for (var i = 0; i < data.length; i++) Offset(x(i), y(data[i])),
    ];
    final line = smoothPath(points);

    if (fill) {
      final area = Path.from(line)
        ..lineTo(x(data.length - 1), size.height)
        ..lineTo(x(0), size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.32 * progress),
              color.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    final metric = line.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _paintScrub(canvas, size, x, y);
  }

  void _paintScrub(
    Canvas canvas,
    Size size,
    double Function(int) x,
    double Function(double) y,
  ) {
    final index = touch;
    if (index == null || index < 0 || index >= data.length) {
      return;
    }
    final px = x(index);
    final py = y(data[index]);
    canvas.drawLine(
      Offset(px, 0),
      Offset(px, size.height),
      Paint()
        ..color = ink3.withValues(alpha: 0.45)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(Offset(px, py), 4, Paint()..color = color);
    canvas.drawCircle(
      Offset(px, py),
      4,
      Paint()
        ..color = bubbleInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final text =
        '${data[index].toStringAsFixed(digits)}'
        '${unit.isNotEmpty ? ' $unit' : ''}';
    final painter = chartLabel(
      text,
      TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: bubbleInk),
    );
    final width = painter.width + 12;
    final height = painter.height + 6;
    final left = (px - width / 2).clamp(0.0, size.width - width);
    // Floats ABOVE the plot, which is why the caller must not clip: these are
    // often 30 px minis and a bubble inside them would cover the line.
    final top = -height - 4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, height),
        const Radius.circular(6),
      ),
      Paint()..color = color,
    );
    painter.paint(canvas, Offset(left + 6, top + 3));
  }

  @override
  bool shouldRepaint(_AreaPainter old) =>
      old.progress != progress ||
      old.data != data ||
      old.color != color ||
      old.touch != touch;
}
