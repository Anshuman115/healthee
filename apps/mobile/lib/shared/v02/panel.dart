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
import 'package:healthee/core/theme/shapes.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/shared/states/caveat_disclosure.dart';
import 'package:healthee/shared/states/caveat_scope.dart';
import 'package:healthee/shared/v02/panel_density.dart';

/// A v02 panel, optionally declaring the [Tone] its contents resolve.
class Panel extends StatelessWidget {
  /// Builds a panel around [child], with an optional [head] above it.
  const Panel({
    required this.child,
    this.head,
    this.tone,
    this.label,
    this.caveats = const <Disclosure>[],
    super.key,
  });

  /// `padding: 18px`. `Container` adds the 1px border on top of this, which is
  /// what `box-sizing: border-box` does in the prototype.
  static const double padding = 18;

  /// `.twin-panels .panel { padding: 14px }`.
  static const double compactPadding = 14;

  /// `.twin-panels .panel-head { margin-bottom: 8px }`.
  static const double compactHeadGap = 8;

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

  /// The metric's owner-facing name, for the disclosure sheet's subtitle.
  final String? label;

  /// What tilts this panel's number, disclosed **inside this panel**.
  ///
  /// A panel also picks up whatever an enclosing [CaveatScope] hands it, which
  /// is how a `ReadingView` wrapping a whole panel gets its disclosures into it
  /// without every panel growing a parameter. `states/caveat_scope.dart` records
  /// why a signpost drawn in the gutter *between* two cards is a misattributed
  /// disclosure rather than an ugly one — and `Panel` is v02's carrier for the
  /// same reason `InstrumentModule` is the pre-v02 one.
  final List<Disclosure> caveats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final compact = context.compactPanel;
    final scope = CaveatScope.of(context);
    final disclosed = <Disclosure>[...caveats, ...?scope?.caveats];
    final named = label ?? scope?.label;
    final Widget panel = Container(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(compact ? compactPadding : padding),
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: hSquircle(
          radius,
          side: BorderSide(color: colors.line, width: hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (head != null) ...<Widget>[
            head!,
            SizedBox(height: compact ? compactHeadGap : headGap),
          ],
          child,
          // Inside the panel's own padding, under the number it is about.
          if (disclosed.isNotEmpty)
            CaveatNote(caveats: disclosed, label: named),
        ],
      ),
    );
    final tone = this.tone;
    final toned = tone == null ? panel : ToneScope(tone: tone, child: panel);
    // Shadowed with an empty scope, so a panel nested inside another cannot
    // render the same disclosure a second time.
    return CaveatScope(caveats: const <Disclosure>[], child: toned);
  }
}
