/// [HBars] — bars that grow on reveal, with the last one emphasised.
///
/// **Ported from** `instrument_charts.dart`'s `HBars`, geometry unchanged: the
/// same 1.12 headroom above the maximum, the same 2 px gap above fourteen bars
/// and 4 px below, the same radius clamp at half the bar width.
///
/// `progress` is a parameter rather than a controller (see
/// `chart_primitives.dart`), and the un-emphasised bars use
/// [HealtheeColors.line2] — the role the legacy `c.line2` became.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';

/// A bar chart over [data], grown by [progress].
class HBars extends StatefulWidget {
  /// [allHighlighted] colours every bar; otherwise only the last and the
  /// touched one carry the accent.
  const HBars(
    this.data, {
    required this.color,
    required this.progress,
    this.height = 30,
    this.radius = 2,
    this.allHighlighted = false,
    this.unit = '',
    this.digits = 0,
    super.key,
  });

  /// The values, oldest first.
  final List<double> data;

  /// The emphasis colour.
  final Color color;

  /// How far the bars have grown, 0–1.
  final double progress;

  /// How tall to draw them.
  final double height;

  /// Bar corner radius.
  final double radius;

  /// Whether every bar is emphasised.
  final bool allHighlighted;

  /// Unit shown in the scrub bubble.
  final String unit;

  /// Decimal places in the scrub bubble.
  final int digits;

  @override
  State<HBars> createState() => _HBarsState();
}

class _HBarsState extends State<HBars> {
  int? _touch;
  double _width = 1;

  /// Legacy holds a tapped value on screen for 1200 ms after the finger
  /// leaves (`instrument_charts.dart:77`), so a tap is readable. A drag still
  /// clears the moment it ends.
  static const Duration _linger = Duration(milliseconds: 1200);

  void _clearAfterLinger() {
    Future<void>.delayed(_linger, () {
      if (mounted) {
        setState(() => _touch = null);
      }
    });
  }

  void _scrub(double dx) {
    if (widget.data.isEmpty) {
      return;
    }
    final fraction = (dx / _width).clamp(0.0, 0.999);
    setState(() => _touch = (fraction * widget.data.length).floor());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _scrub(details.localPosition.dx),
      onTapUp: (_) => _clearAfterLinger(),
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
              painter: _BarsPainter(
                data: widget.data,
                color: widget.color,
                idle: colors.line2,
                bubbleInk: colors.surface,
                progress: widget.progress,
                radius: widget.radius,
                allHighlighted: widget.allHighlighted,
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

class _BarsPainter extends CustomPainter {
  const _BarsPainter({
    required this.data,
    required this.color,
    required this.idle,
    required this.bubbleInk,
    required this.progress,
    required this.radius,
    required this.allHighlighted,
    required this.touch,
    required this.unit,
    required this.digits,
  });

  final List<double> data;
  final Color color;
  final Color idle;
  final Color bubbleInk;
  final double progress;
  final double radius;
  final bool allHighlighted;
  final int? touch;
  final String unit;
  final int digits;

  /// Legacy's headroom above the tallest bar, so it does not touch the top.
  static const double _headroom = 1.12;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }
    final max = data.reduce((a, b) => a > b ? a : b) * _headroom;
    final count = data.length;
    final gap = count > 14 ? 2.0 : 4.0;
    final barWidth = (size.width - gap * (count - 1)) / count;

    for (var i = 0; i < count; i++) {
      final barHeight = (max == 0 ? 0 : data[i] / max) * size.height * progress;
      final emphasised = allHighlighted || i == count - 1 || i == touch;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * (barWidth + gap),
            size.height - barHeight,
            barWidth,
            barHeight,
          ),
          Radius.circular(radius.clamp(0, barWidth / 2)),
        ),
        Paint()..color = emphasised ? color : idle,
      );
    }
    _paintBubble(canvas, size, barWidth, gap, count);
  }

  void _paintBubble(
    Canvas canvas,
    Size size,
    double barWidth,
    double gap,
    int count,
  ) {
    final index = touch;
    if (index == null || index < 0 || index >= count) {
      return;
    }
    final centre = index * (barWidth + gap) + barWidth / 2;
    final text =
        '${data[index].toStringAsFixed(digits)}'
        '${unit.isNotEmpty ? ' $unit' : ''}';
    final painter = chartLabel(
      text,
      TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: bubbleInk),
    );
    final width = painter.width + 12;
    final height = painter.height + 6;
    final left = (centre - width / 2).clamp(0.0, size.width - width);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, -height - 4, width, height),
        const Radius.circular(6),
      ),
      Paint()..color = color,
    );
    painter.paint(canvas, Offset(left + 6, -height - 1));
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.progress != progress || old.data != data || old.touch != touch;
}
