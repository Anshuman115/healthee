import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/history/history_marker.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/shared/charts/chart_reference.dart';
import 'package:healthee/shared/format/number_labels.dart';

/// Calendar-positioned observations, joined only across consecutive days.
class HistoryChart extends StatefulWidget {
  const HistoryChart({
    required this.points,
    this.markers = const [],
    super.key,
  });
  final List<TrendPoint> points;
  final List<HistoryMarker> markers;
  @override
  State<HistoryChart> createState() => _HistoryChartState();
}

class _HistoryChartState extends State<HistoryChart> {
  int? _selected;
  List<TrendPoint> get points => widget.points;
  @override
  void didUpdateWidget(covariant HistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final scale = ChartScale.of(TrendPoint.valuesOf(points), pad: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chart scale: ${decimalLabel(scale.low)}–${decimalLabel(scale.high)}'),
        if (_selected != null)
          Text('${points[_selected!].date}: ${points[_selected!].value}'),
        RepaintBoundary(
          child: SizedBox(
            height: 160,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onTapDown: (event) =>
                    _pick(event.localPosition.dx, constraints.maxWidth),
                onHorizontalDragUpdate: (event) =>
                    _pick(event.localPosition.dx, constraints.maxWidth),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _HistoryPainter(
                    points,
                    context.colors.accent,
                    scale,
                    markers: widget.markers,
                    selected: _selected,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _pick(double x, double width) {
    if (points.isEmpty) return;
    final first = DateTime.parse('${points.first.date}T00:00:00Z');
    final span = DateTime.parse('${points.last.date}T00:00:00Z').difference(first).inDays;
    final day = ((x - 6) / (width - 12)).clamp(0.0, 1.0) * span;
    var best = 0;
    for (var i = 1; i < points.length; i++) {
      if ((DateTime.parse('${points[i].date}T00:00:00Z').difference(first).inDays - day)
              .abs() <
          (DateTime.parse('${points[best].date}T00:00:00Z').difference(first).inDays - day)
              .abs()) {
        best = i;
      }
    }
    setState(() => _selected = best);
  }
}

class _HistoryPainter extends CustomPainter {
  _HistoryPainter(
    this.points,
    this.color,
    this.scale, {
    this.markers = const [],
    this.selected,
  });
  final List<HistoryMarker> markers;
  final int? selected;
  final List<TrendPoint> points;
  final Color color;
  final ChartScale scale;
  static const _inset = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final days = points
        .map((p) => DateTime.parse('${p.date}T00:00:00Z'))
        .toList();
    final low = scale.low;
    final high = scale.high;
    final span = days.last.difference(days.first).inDays;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    Offset? previous;
    for (var i = 0; i < points.length; i++) {
      final x = span == 0 ? 0.5 : days[i].difference(days.first).inDays / span;
      final y = high == low ? 0.5 : (points[i].value - low) / (high - low);
      final point = Offset(
        _inset + x * (size.width - 2 * _inset),
        size.height - _inset - y * (size.height - 2 * _inset),
      );
      if (previous != null && days[i].difference(days[i - 1]).inDays == 1) {
        canvas.drawLine(previous, point, paint);
      }
      canvas.drawCircle(point, selected == i ? 5 : 2.5, paint);
      previous = point;
    }
    for (final marker in markers) {
      final day = DateTime.parse('${marker.day}T00:00:00Z');
      if (day.isBefore(days.first) || day.isAfter(days.last)) continue;
      final x = span == 0 ? 0.5 : day.difference(days.first).inDays / span;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(
            _inset + x * (size.width - 2 * _inset),
            size.height - 3,
          ),
          width: 4,
          height: 6,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HistoryPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.markers != markers ||
      oldDelegate.selected != selected;
}
