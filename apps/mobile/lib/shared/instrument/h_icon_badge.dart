/// An icon in a soft-tinted rounded square, and the round initial beside a name.
///
/// **Ported verbatim** from `healthee-legacy/app/lib/ui/ui.dart` — `HIconBadge`
/// and `HAvatar`. Two very small widgets in one file because they are the same
/// idea at two shapes and neither has a reason to change without the other.
///
/// [HIconBadge]: a 40 px square at radius 13, filled with its colour at **18%**,
/// icon at half the box. [HAvatar]: a 38 px accent circle with the initial at
/// **42%** of the diameter in [HealtheeColors.onAccent].
///
/// The `onAccent` on that circle is legacy's `onGreen`, one value in both themes,
/// and it measures 2.14:1 against the dark theme's green. Ported as legacy has
/// it and flagged in `palette.dart` rather than silently corrected here.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/shapes.dart';
import 'package:healthee/core/theme/tokens.dart';

/// An icon on a wash of its own colour.
class HIconBadge extends StatelessWidget {
  /// [color] is both the icon and, at 18%, its fill.
  const HIconBadge(
    this.icon, {
    required this.color,
    this.size = 40,
    this.radius = 13,
    super.key,
  });

  /// The glyph.
  final IconData icon;

  /// The icon colour; its fill is this at [_fillAlpha].
  final Color color;

  /// The box's side. Legacy's default.
  final double size;

  /// Its corner radius. Legacy's default.
  final double radius;

  /// Legacy's `withValues(alpha: 0.18)`.
  static const double _fillAlpha = 0.18;

  /// Legacy draws the glyph at half the box.
  static const double _glyphFraction = 0.5;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: ShapeDecoration(
      color: color.withValues(alpha: _fillAlpha),
      shape: hSquircle(radius),
    ),
    // Decorative: whatever this badge sits beside already names it.
    child: ExcludeSemantics(
      child: Icon(icon, size: size * _glyphFraction, color: color),
    ),
  );
}

/// The owner's initial, on the accent.
class HAvatar extends StatelessWidget {
  /// [initial] is one character; this widget does not truncate for you.
  const HAvatar(this.initial, {this.size = 38, super.key});

  /// The letter to draw.
  final String initial;

  /// The circle's diameter. Legacy's default.
  final double size;

  /// Legacy sets the letter at 42% of the diameter, weight 700.
  static const double _letterFraction = 0.42;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: ExcludeSemantics(
        child: Text(
          initial,
          style: HType.sans(
            colors.onAccent,
            size: size * _letterFraction,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
