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
import 'package:healthee/shared/instrument/h_tap.dart';
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
    this.onOpen,
    super.key,
  });

  /// Where the WHOLE card leads, or null for a panel that leads nowhere.
  ///
  /// **The card is the target, not an arrow in its corner.** `SummaryTile` has
  /// worked this way since v02 and the three tiles at the top of Today have no
  /// arrow at all; the panels under them carried a `Details →`, so one screen
  /// asked for the same gesture in two ways. This is the tiles' way.
  ///
  /// The ⓘ keeps its own tap: `MetricInfoDot` is an opaque `GestureDetector`,
  /// so it wins the hit test against this and explains the card instead of
  /// leaving it. Anything else interactive inside [child] does the same — which
  /// is why a panel that carries its own controls should NOT be given an
  /// `onOpen` rather than being given one and hoping.
  final VoidCallback? onOpen;

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
    // Announced to the head BEFORE the card is built, so the mark and the tap
    // come from one field. See [PanelOpens].
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
            PanelOpens(
              opens: onOpen != null,
              caveats: disclosed,
              caveatsLabel: named,
              child: head!,
            ),
            SizedBox(height: compact ? compactHeadGap : headGap),
          ],
          child,
          // **No `CaveatNote` here any more.** It printed a second block of
          // small grey prose under every caveated card — on the half-width
          // ones it was taller than the reading it qualified. The head's ⓘ
          // carries it now, and carries it BECAUSE this published it above:
          // one field, so a card cannot show the sentence twice or lose it.
          //
          // Losing it is not expressible either. `MetricDetail.isEmpty` counts
          // disclosures, so a head with no explainer at all still draws its ⓘ
          // when there is a caveat to reach.
        ],
      ),
    );
    final open = onOpen;
    final tappable = open == null
        ? panel
        : HTap(onTap: open, semanticLabel: named ?? label, child: panel);
    final tone = this.tone;
    final toned = tone == null
        ? tappable
        : ToneScope(tone: tone, child: tappable);
    // Shadowed with an empty scope, so a panel nested inside another cannot
    // render the same disclosure a second time.
    return CaveatScope(caveats: const <Disclosure>[], child: toned);
  }
}

/// Whether the card around this head leads somewhere.
///
/// **The mark and the tap come from one field**, which is the whole point of an
/// inherited flag rather than a second parameter on the head. A card that is
/// tappable with nothing to say so makes the reader find it by accident; a
/// chevron on a card that goes nowhere is a lie. Neither is expressible: the
/// head reads this, and only `Panel.onOpen` sets it.
class PanelOpens extends InheritedWidget {
  /// Wraps [child] with the answers.
  const PanelOpens({
    required this.opens,
    required super.child,
    this.caveats = const <Disclosure>[],
    this.caveatsLabel,
    super.key,
  });

  /// Whether the enclosing card is a tap target.
  final bool opens;

  /// What tilts the reading this card is about, for its ⓘ to carry.
  final List<Disclosure> caveats;

  /// What that reading is called.
  final String? caveatsLabel;

  /// The nearest card, or null outside one.
  static PanelOpens? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PanelOpens>();

  /// Whether the nearest card leads somewhere, or false outside one.
  static bool opensOf(BuildContext context) => of(context)?.opens ?? false;

  @override
  bool updateShouldNotify(PanelOpens old) =>
      old.opens != opens || old.caveats != caveats;
}
