/// A track and a fill that grows into it once.
///
/// **Ported from** `healthee-legacy/app/lib/ui/ui.dart`'s `HProgressBar`: the
/// track is [HealtheeColors.line] (legacy's `line2` by role), the fill defaults
/// to the accent, both are fully pilled, and the fill animates 0 → value over
/// 1000 ms on [HMotion.curve].
///
/// ## The one change, and it is the repo's standing rule
///
/// Legacy started the animation from a post-frame callback in its own `State`.
/// Under `ListView.builder` that replays every time the row scrolls back —
/// `CLAUDE.md` names it as a hard rule and `shared/reveal_once.dart` carries the
/// whole argument. So [progress] is a **parameter**, supplied by `RevealOnce`,
/// and this widget owns no ticker. Geometry is untouched.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';

/// A horizontal meter filled to [value] / [max].
class HProgressBar extends StatelessWidget {
  /// [progress] is 0–1 from `RevealOnce`; 1 paints the finished bar.
  const HProgressBar({
    required this.value,
    required this.progress,
    this.max = 100,
    this.height = 5,
    this.color,
    this.semanticLabel,
    super.key,
  });

  /// Where the fill reaches, in the same units as [max].
  final double value;

  /// The top of the scale. Legacy's default.
  final double max;

  /// How much of the fill has grown, 0–1.
  final double progress;

  /// How thick the bar is. Legacy's default is 5.
  final double height;

  /// The fill colour. Null takes [HealtheeColors.accent], as legacy does.
  final Color? color;

  /// What a screen reader says instead of "57 percent".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final drawn = fraction * progress.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(fraction * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, box) => DecoratedBox(
              decoration: BoxDecoration(
                color: colors.line,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: box.maxWidth * drawn,
                  height: height,
                  decoration: BoxDecoration(
                    color: color ?? colors.accent,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
