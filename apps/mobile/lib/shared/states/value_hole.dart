/// The number-shaped absence — the visual signature of a withheld value.
///
/// `docs/APP_DESIGN_BRIEF.md` §3: *"Design that as a **card with a number-shaped
/// hole**, not a card that failed to load. Same footprint, same title, same
/// position — the value slot carries the reason and the remedy. The user should
/// read it as the app being careful, not broken."*
///
/// So this is a box exactly where the number would have been, drawn with a dashed
/// [HealtheeColors.line] border over a [HealtheeColors.hole] fill. Two properties
/// carry the whole idea:
///
///   * **It occupies space rather than collapsing.** A card that shrinks when a
///     value is missing reads as a layout bug; one that holds the number's
///     footprint reads as a deliberate blank.
///   * **It spends no colour.** Brief §2 rations colour to judgement, so a
///     refusal must not be tinted — see the note in `tokens.dart`.
///
/// The dash is hand-painted because Flutter has no dashed border, and it is worth
/// the ~40 lines: solid would read as an empty input field, and the dash is what
/// says "intentionally not filled in".
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';

/// A box the size a value would have been, dashed and empty.
class ValueHole extends StatelessWidget {
  /// A hole of an explicit size.
  const ValueHole({
    required this.width,
    required this.height,
    this.radius = Radii.button,
    super.key,
  });

  /// The footprint of a hero figure — a recovery score, a VO₂max estimate.
  const ValueHole.hero({Key? key}) : this(width: 78, height: 52, key: key);

  /// The footprint of a value on a single metric row.
  const ValueHole.inline({Key? key})
    : this(width: 56, height: 20, radius: Radii.inlineHole, key: key);

  /// How wide the missing value would have been.
  final double width;

  /// How tall the missing value would have been.
  final double height;

  /// Corner radius of the hole.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CustomPaint(
      painter: _DashedHolePainter(
        border: colors.line,
        fill: colors.hole,
        radius: radius,
      ),
      // Excluded from the semantics tree as decoration: the meaning lives in the
      // reason and remedy beside it, and a screen reader announcing "box" would
      // add nothing. The card supplies the label.
      child: ExcludeSemantics(child: SizedBox(width: width, height: height)),
    );
  }
}

class _DashedHolePainter extends CustomPainter {
  const _DashedHolePainter({
    required this.border,
    required this.fill,
    required this.radius,
  });

  final Color border;
  final Color fill;
  final double radius;

  static const double _dash = 4;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(rect, Paint()..color = fill);

    final stroke = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = hairline;

    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), stroke);
        distance = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedHolePainter oldDelegate) =>
      oldDelegate.border != border || oldDelegate.fill != fill || oldDelegate.radius != radius;
}
