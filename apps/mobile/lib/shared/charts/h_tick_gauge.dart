/// [HTickGauge] — the segmented radial arc the legacy readiness card is built on.
///
/// **Ported from** `design_reference/project/hh/ui.jsx`'s `TickGauge`, geometry
/// unchanged to the constant: **44 ticks**, start angle **135°**, sweep **270°**,
/// radius `size/2 - 6`, every fifth tick drawn 13 px long at 2.2 px wide and the
/// rest 8 px long at 1.5 px, all round-capped. Ticks up to and including the lit
/// index take the caller's colour; the remainder take [HealtheeColors.line2].
///
/// Two changes, both required by this repo's rules:
///
///   * **`progress` is a parameter, not a controller.** The legacy component ran
///     its own `requestAnimationFrame` loop from `useEffect`; under
///     `ListView.builder` that is the replay-on-scroll bug `CLAUDE.md` names as a
///     hard rule. See `chart_primitives.dart` for the whole argument.
///   * **Colours are roles.** `var(--green)` became whatever tag the caller
///     passes, and `var(--line-2)` became [HealtheeColors.line2].
///
/// ## Why a tick gauge rather than a ring
///
/// It is what the legacy screen draws, and it happens to be the more honest
/// shape: a ring reads as a continuous quantity filled to a point, while 44
/// discrete marks read as an instrument with a resolution — which is what a
/// 0–100 score computed from four weighted factors actually is. The unlit ticks
/// stay visible, so the scale is legible without the number.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';

/// A 270° arc of tick marks, lit up to [value].
class HTickGauge extends StatelessWidget {
  /// [value] is on 0–[max]; [progress] is 0–1 from `RevealOnce`.
  const HTickGauge({
    required this.value,
    required this.color,
    required this.progress,
    this.max = 100,
    this.size = 116,
    this.child,
    super.key,
  });

  /// Where the needle would be, if this had one.
  final double value;

  /// The top of the scale. Legacy's default, and every caller's.
  final double max;

  /// The lit ticks' colour. An identity tag, never a judgement colour — the
  /// gauge is a picture of a score, and tinting it by how good the score is
  /// would be the app grading the owner in colour.
  final Color color;

  /// How much of the sweep has lit, 0–1.
  final double progress;

  /// The diameter.
  final double size;

  /// Drawn centred inside the arc — the figure and its band.
  final Widget? child;

  /// Legacy's `ticks`.
  static const int ticks = 44;

  /// Legacy's `startA`, in degrees. 135° puts the gap at the bottom.
  static const double startAngle = 135;

  /// Legacy's `sweep`, in degrees.
  static const double sweep = 270;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _TickGaugePainter(
              // Clamped before it reaches the painter: a server that sent 140
              // would otherwise light ticks that do not exist and throw.
              lit: ((value / (max == 0 ? 1 : max)).clamp(0.0, 1.0) *
                      ticks *
                      progress.clamp(0.0, 1.0))
                  .round(),
              color: color,
              track: colors.line2,
            ),
          ),
          if (child case final Widget centre) centre,
        ],
      ),
    );
  }
}

class _TickGaugePainter extends CustomPainter {
  const _TickGaugePainter({
    required this.lit,
    required this.color,
    required this.track,
  });

  final int lit;
  final Color color;
  final Color track;

  /// Legacy's `R = size / 2 - 6`.
  static const double _inset = 6;

  /// Legacy's `r2` offsets: every fifth mark is longer.
  static const double _majorLength = 13;
  static const double _minorLength = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - _inset;
    for (var i = 0; i <= HTickGauge.ticks; i++) {
      final angle =
          (HTickGauge.startAngle + (i / HTickGauge.ticks) * HTickGauge.sweep) *
          math.pi /
          180;
      final major = i % 5 == 0;
      final inner = radius - (major ? _majorLength : _minorLength);
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        centre + direction * radius,
        centre + direction * inner,
        Paint()
          ..color = i <= lit ? color : track
          ..strokeWidth = major ? 2.2 : 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TickGaugePainter old) =>
      old.lit != lit || old.color != color || old.track != track;
}
