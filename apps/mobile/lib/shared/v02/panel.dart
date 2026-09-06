/// `.panel` — the v02 container everything else sits in.
///
/// ```css
/// .panel { padding: 18px; background: var(--surface); color: var(--ink);
///          border: 1px solid var(--line); border-radius: 22px;
///          margin-top: 12px; overflow: clip; }
/// ```
///
/// The margin is the caller's, because a widget that reserves space above itself
/// cannot be the first thing in a column without a hole over it.
///
/// **The corner is a circular arc, not legacy's squircle.** `shapes.dart` exists
/// because legacy drew every module with a continuous superellipse, and the
/// screens that have not been redesigned still do. v02 specifies plain
/// `border-radius`, so a v02 panel draws plain `border-radius`; matching the
/// prototype is the brief.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';

/// A v02 panel, optionally declaring the [Tone] its contents resolve.
class Panel extends StatelessWidget {
  /// Builds a panel around [child], with an optional [head] above it.
  const Panel({required this.child, this.head, this.tone, super.key});

  /// `padding: 18px`. `Container` adds the 1px border on top of this, which is
  /// what `box-sizing: border-box` does in the prototype.
  static const double padding = 18;

  /// `border-radius: 22px`.
  static const double radius = 22;

  /// `.panel-head { margin-bottom: 12px }` — owned here so a head cannot be
  /// placed without its gap.
  static const double headGap = 12;

  /// The panel's body.
  final Widget child;

  /// Usually a `PanelHead`. Separated from [child] only so [headGap] is applied.
  final Widget? head;

  /// The family every descendant resolves. Null inherits the enclosing scope,
  /// which is `Tone.fitness` at the root — `richer.css` `:root`.
  final Tone? tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Widget panel = Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line, width: hairline),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (head != null) ...<Widget>[head!, const SizedBox(height: headGap)],
          child,
        ],
      ),
    );
    final tone = this.tone;
    return tone == null ? panel : ToneScope(tone: tone, child: panel);
  }
}
