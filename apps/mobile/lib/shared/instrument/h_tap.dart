/// The app's press feedback: a scale, not a ripple.
///
/// **Ported verbatim** from `healthee-legacy/app/lib/ui/ui.dart`'s `HTap` — the
/// design's `.tap:active { scale(0.975) }`, plus the 0.9 opacity dip legacy pairs
/// it with, both over 160 ms on [HMotion.curve].
///
/// It is the reason legacy's cards feel like physical keys rather than Material
/// surfaces, and it is why the ported [HModule] does not use `InkWell`: a ripple
/// spreading from the touch point is Material's language, not this app's.
///
/// A null [onTap] returns the child untouched — no gesture detector, no rebuild
/// on press — so a non-interactive card costs nothing.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/motion.dart';

/// Scales [child] to 97.5% while it is held down.
class HTap extends StatefulWidget {
  /// A null [onTap] makes this a pass-through.
  const HTap({required this.child, this.onTap, this.semanticLabel, super.key});

  /// What is pressed.
  final Widget child;

  /// What the press does. Null means the child is not interactive.
  final VoidCallback? onTap;

  /// What a screen reader announces. Null leaves the child's own semantics.
  final String? semanticLabel;

  @override
  State<HTap> createState() => _HTapState();
}

class _HTapState extends State<HTap> {
  bool _down = false;

  /// Legacy's `scale(0.975)` and its 160 ms.
  static const double _pressedScale = 0.975;
  static const double _pressedOpacity = 0.9;
  static const Duration _press = Duration(milliseconds: 160);

  void _setDown(bool down) {
    if (_down != down) {
      setState(() => _down = down);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    if (onTap == null) {
      return widget.child;
    }
    final gesture = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      child: AnimatedScale(
        scale: _down ? _pressedScale : 1,
        duration: _press,
        curve: HMotion.curve,
        child: AnimatedOpacity(
          opacity: _down ? _pressedOpacity : 1,
          duration: _press,
          child: widget.child,
        ),
      ),
    );
    return switch (widget.semanticLabel) {
      final String label => Semantics(button: true, label: label, child: gesture),
      _ => gesture,
    };
  }
}
