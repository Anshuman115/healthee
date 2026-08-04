/// [HHypnogram] — one night across four lanes: awake · REM · light · deep.
///
/// **Ported from** `instrument_charts.dart`'s `HHypnogram`. Unchanged: four
/// lanes, the band at 62% of a lane's height, the guide line down the middle of
/// each lane, the 1.5 px inter-block trim, and the 3 px corner radius.
///
/// The lane order is the sleep-science convention (awake at the top, deep at the
/// bottom) and the lane an unrecognised stage lands in is `light`'s — a decision
/// inherited from the legacy `levels` map. It is worth naming rather than
/// leaving implicit: an unrecognised code is drawn where light sleep is drawn,
/// but in `stage_colors.dart`'s unrecognised grey, so it is visibly not a
/// staged span.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/last_sleep.dart';

/// One night's stage timeline.
class HHypnogram extends StatelessWidget {
  /// [spans] is in order; [progress] is 0–1 from `RevealOnce`.
  const HHypnogram(
    this.spans, {
    required this.progress,
    this.height = 84,
    super.key,
  });

  /// The staged spans, in order.
  final List<SleepStageSpan> spans;

  /// How far the bands have grown, 0–1.
  final double progress;

  /// How tall to draw the four lanes.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (spans.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _HypnogramPainter(
          spans: spans,
          colors: context.colors,
          progress: progress,
        ),
      ),
    );
  }
}

class _HypnogramPainter extends CustomPainter {
  const _HypnogramPainter({
    required this.spans,
    required this.colors,
    required this.progress,
  });

  final List<SleepStageSpan> spans;
  final HealtheeColors colors;
  final double progress;

  /// Lane index per stage — awake highest, deep lowest. Legacy's `levels`.
  static const Map<String, int> _lanes = <String, int>{
    'awake': 0,
    'rem': 1,
    'core': 2,
    'light': 2,
    'deep': 3,
  };

  static const int _laneCount = 4;
  static const double _bandFraction = 0.62;

  @override
  void paint(Canvas canvas, Size size) {
    final total = spans.fold<double>(0, (sum, span) => sum + span.durationMin);
    if (total == 0) {
      return;
    }
    final laneHeight = size.height / _laneCount;
    final bandHeight = laneHeight * _bandFraction;

    final guide = Paint()
      ..color = colors.line
      ..strokeWidth = 1;
    for (var lane = 0; lane < _laneCount; lane++) {
      final y = lane * laneHeight + laneHeight / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }

    var elapsed = 0.0;
    for (final span in spans) {
      final x = (elapsed / total) * size.width;
      final width = (span.durationMin / total) * size.width;
      elapsed += span.durationMin;
      final lane = _lanes[span.stage] ?? 2;
      final y = lane * laneHeight + (laneHeight - bandHeight) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          // The 1.5 px trim is what separates two adjacent spans of the same
          // stage without drawing a divider between them.
          Rect.fromLTWH(
            x,
            y,
            (width - 1.5).clamp(1, double.infinity),
            bandHeight * progress,
          ),
          const Radius.circular(3),
        ),
        Paint()
          ..color = sleepStageColor(
            colors,
            span.stage,
          ).withValues(alpha: progress),
      );
    }
  }

  @override
  bool shouldRepaint(_HypnogramPainter old) =>
      old.progress != progress || old.spans != spans;
}
