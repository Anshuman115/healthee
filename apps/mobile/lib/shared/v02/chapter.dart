/// The three pieces that turn a long screen into chapters you can find.
///
/// ```css
/// .chapter-nav          { display:flex; gap:6px; margin-block:20px 8px;
///                         position:sticky; top:0; padding-block:8px; }
/// .chapter-nav button   { padding:9px 12px; border:1px solid var(--line);
///                         border-radius:20px; color:var(--muted);
///                         font-size:10px; }
/// .chapter-nav button:first-child { color:var(--fitness);
///                                   border-color:var(--fitness); }
/// .chapter-heading      { display:flex; align-items:center; gap:8px;
///                         margin-top:28px; margin-bottom:4px; }
/// .chapter-heading .icon{ width:18px; height:18px; color:var(--family); }
/// .chapter-heading h2   { font-size:20px; }
/// .chapter-heading .grow{ height:1px; background:var(--line); margin-left:8px; }
/// .twin-panels          { display:grid; grid-template-columns:repeat(2,1fr);
///                         gap:10px; }
/// ```
///
/// **The nav's `position: sticky` is not reproduced, and this is the honest
/// trade.** The screen is a `ListView.builder` whose items are destroyed off
/// screen (`shared/reveal_once.dart` says why that must stay), and a sticky
/// header inside one is a `SliverPersistentHeader` — a different scroll
/// structure for the whole screen. The rendered result differs in one way: the
/// control scrolls away with the content instead of pinning to the top. It is
/// still where the prototype puts it and still jumps to the same three places.
///
/// The prototype colours the FIRST button and no other, which reads as "you are
/// here" and is wrong the moment you scroll. [ChapterNav] colours [selected]
/// instead, which is the same pixels for the same default and correct after a
/// jump.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/v02/panel_density.dart';

/// One entry in a [ChapterNav].
@immutable
class ChapterTarget {
  /// [onJump] of null draws the button disabled rather than dead — see
  /// `today_chapters.dart` for the jump itself.
  const ChapterTarget(this.label, this.onJump);

  /// The button's words.
  final String label;

  /// What tapping it does.
  final VoidCallback? onJump;
}

/// `.chapter-nav` — the three jump buttons above the chapters.
class ChapterNav extends StatelessWidget {
  /// Builds the row; [selected] is drawn in the family colour.
  const ChapterNav(this.targets, {this.selected = 0, super.key});

  /// `.chapter-nav { gap: 6px }`.
  static const double gap = 6;

  /// `.chapter-nav { margin-block: 20px 8px }`.
  static const EdgeInsets margin = EdgeInsets.only(top: 20, bottom: 8);

  /// `.chapter-nav button { padding: 9px 12px }`.
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 9,
  );

  /// `.chapter-nav button { border-radius: 20px }`.
  static const double radius = 20;

  /// Where each button goes.
  final List<ChapterTarget> targets;

  /// Which one is drawn as current.
  final int selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final family = context.family;
    return Padding(
      padding: margin,
      // Horizontally scrollable, because the row is three variable-width pills
      // and a narrow phone (or a large text scale) makes them wider than the
      // page. The prototype's flex row simply overflows there; a `Wrap` would
      // move the third button onto its own line and change the control's shape,
      // so the row keeps its shape and the overflow becomes a scroll.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < targets.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: gap),
              _NavButton(
                target: targets[i],
                tint: i == selected ? family : colors.ink2,
                edge: i == selected ? family : colors.line,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.target,
    required this.tint,
    required this.edge,
  });

  final ChapterTarget target;
  final Color tint;
  final Color edge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: target.onJump,
        child: Container(
          padding: ChapterNav.buttonPadding,
          decoration: BoxDecoration(
            border: Border.all(color: edge, width: hairline),
            borderRadius: BorderRadius.circular(ChapterNav.radius),
          ),
          child: Text(
            target.label,
            style: TypeScale.chapterNav.copyWith(color: tint),
          ),
        ),
      ),
    );
  }
}

/// `.chapter-heading` — an icon, a name, and a rule running to the edge.
class ChapterHeading extends StatelessWidget {
  /// Builds the heading. [tone] declares the family for the icon and the rule.
  const ChapterHeading({
    required this.title,
    required this.icon,
    this.tone,
    super.key,
  });

  /// `.chapter-heading { margin-top: 28px; margin-bottom: 4px }`.
  static const EdgeInsets margin = EdgeInsets.only(top: 28, bottom: 4);

  /// `.chapter-heading .icon { width: 18px }`, and its `gap: 8px`.
  static const double iconSize = 18;

  /// `.chapter-heading { gap: 8px }` and the rule's own `margin-left: 8px`.
  static const double gap = 8;

  /// The chapter's name.
  final String title;

  /// Drawn before it, in the family colour.
  final IconData icon;

  /// The family for this heading. Null inherits.
  final Tone? tone;

  @override
  Widget build(BuildContext context) {
    final tone = this.tone;
    return tone == null
        ? _body(context)
        : ToneScope(tone: tone, child: Builder(builder: _body));
  }

  Widget _body(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: margin,
      child: Row(
        children: <Widget>[
          Icon(icon, size: iconSize, color: context.family),
          const SizedBox(width: gap),
          Flexible(
            child: Text(
              title,
              style: TypeScale.chapterTitle.copyWith(color: colors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: gap * 2),
          Expanded(
            child: SizedBox(
              height: hairline,
              child: ColoredBox(color: colors.line),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.twin-panels` — two panels sharing a row, each at half width.
///
/// Declares [PanelDensityLevel.compact] for both, which is the whole reason the
/// two halves come out at the CSS's smaller type instead of a full-width panel's
/// squeezed into half the space.
class TwinPanels extends StatelessWidget {
  /// Builds the pair. Both children stretch to the taller one.
  const TwinPanels({required this.left, required this.right, super.key});

  /// `.twin-panels { gap: 10px }`.
  static const double gap = 10;

  /// The left panel.
  final Widget left;

  /// The right panel.
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return PanelDensity(
      level: PanelDensityLevel.compact,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: left),
            const SizedBox(width: gap),
            Expanded(child: right),
          ],
        ),
      ),
    );
  }
}
