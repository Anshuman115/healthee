/// `.motion-toggle` — the control that stops the hero's field by hand.
///
/// ```css
/// .bio-controls .motion-toggle {
///   width:32px; height:32px; border-radius:50%; color:var(--bio-ink);
///   border:1px solid color-mix(in oklch, var(--bio-line) 40%, transparent); }
/// .motion-symbol   { width:12px; height:12px; fill:currentColor }
/// .motion-play     { display:none }
/// [data-motion='off'] .motion-play  { display:block }
/// [data-motion='off'] .motion-pause { display:none }
/// ```
///
/// `design/mobile-preview/README.md`: *"The hero pause button and Explore
/// control stop animation"*. The prototype's control is a real stop — it sets
/// `data-motion='off'` and the field's `requestAnimationFrame` loop is not
/// rescheduled — and so is this one: [onChanged] is wired to `BioHalo.paused`,
/// which stops the **ticker** rather than telling the painter to keep painting
/// the same thing.
///
/// It is a fourth reason to stop, beside the three the field already applies for
/// itself (offscreen, backgrounded, reduced motion). Those keep working while
/// this one is off; this one wins while it is on.
///
/// **It takes no `Color`.** The hero card carries its own dark surface in both
/// themes, so the control reads `bioInk` and `bioLine` from the theme's bio
/// roles the same way every other part of the hero does.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';

/// A 32 px round button that pauses and resumes the hero's field.
class MotionToggle extends StatelessWidget {
  /// [paused] is the state it reports and inverts; [onChanged] receives the new
  /// value.
  const MotionToggle({required this.paused, required this.onChanged, super.key});

  /// `.motion-toggle { width: 32px; height: 32px }`.
  static const double size = 32;

  /// `.motion-symbol { width: 12px; height: 12px }`.
  static const double symbolSize = 12;

  /// The share of `bioLine` in the ring — `color-mix … 40%, transparent`.
  static const double lineMix = 0.4;

  /// What a screen reader is told the control does.
  static const String label = 'Pause animations';

  /// Whether the field is stopped right now.
  final bool paused;

  /// Called with the state the owner asked for.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = colors.bioInk;
    return Semantics(
      button: true,
      toggled: paused,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onChanged(!paused),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.bioLine.withValues(alpha: colors.bioLine.a * lineMix),
              width: hairline,
            ),
          ),
          child: Icon(
            paused ? Icons.play_arrow : Icons.pause,
            size: symbolSize,
            color: ink,
          ),
        ),
      ),
    );
  }
}
