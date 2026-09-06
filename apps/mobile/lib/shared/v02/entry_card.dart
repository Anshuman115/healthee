/// `.relationship-card` — the way out of a screen, on its family's soft ground.
///
/// ```css
/// .relationship-grid { display:grid; grid-template-columns:repeat(2,1fr);
///                      gap:10px; }
/// .relationship-card { padding:18px; border-radius:20px;
///                      background:var(--family-soft); color:var(--ink);
///                      border:1px solid
///                        color-mix(in oklch,var(--family) 25%,var(--line)); }
/// .relationship-card .icon  { color:var(--family); margin-bottom:12px; }
/// .relationship-card h3     { font-size:15px; }
/// .relationship-card p      { font-size:11px; margin-top:8px; }
/// .relationship-card .text-button { color:var(--family); }
/// ```
///
/// `color-mix(in oklch, var(--family) 25%, var(--line))` interpolates in OKLab
/// and `Color.lerp` in sRGB; on a 1 px edge between two colours this close the
/// two are indistinguishable, so the border is `Color.lerp(line, family, 0.25)`
/// — the same argument `bio_hero.dart` records for its own hairline.
///
/// A card with no [onOpen] draws **no action line at all** rather than a dead
/// one. An entry point that leads nowhere is worse than an absent entry point:
/// it spends a tap to teach the reader that the screen lies about what it can
/// do.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';

/// One way out of the screen: an icon, a name, a sentence and an action.
class EntryCard extends StatelessWidget {
  /// Builds the card. [tone] declares its family; null inherits.
  const EntryCard({
    required this.title,
    required this.icon,
    this.body,
    this.actionLabel,
    this.onOpen,
    this.tone,
    super.key,
  });

  /// `padding: 18px`.
  static const double padding = 18;

  /// `border-radius: 20px`.
  static const double radius = 20;

  /// `.relationship-card .icon { margin-bottom: 12px }`.
  static const double iconGap = 12;

  /// The prototype's `.icon` default width.
  static const double iconSize = 22;

  /// `p { margin-top: 8px }`.
  static const double bodyGap = 8;

  /// The share of the family in the border — `color-mix … 25%`.
  static const double edgeMix = 0.25;

  /// What is on the other side of the tap.
  final String title;

  /// Drawn above it, in the family colour.
  final IconData icon;

  /// The sentence under the title.
  final String? body;

  /// The action's words. Null, or a null [onOpen], draws no action.
  final String? actionLabel;

  /// What opening it does.
  final VoidCallback? onOpen;

  /// The family for this card. Null inherits the enclosing scope.
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
    final family = context.family;
    final label = actionLabel;
    final open = onOpen;
    final card = Container(
      padding: const EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: context.familySoft,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Color.lerp(colors.line, family, edgeMix)!,
          width: hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: iconSize, color: family),
          const SizedBox(height: iconGap),
          Text(
            title,
            style: TypeScale.entryTitle.copyWith(color: colors.ink),
          ),
          if (body case final String sentence) ...<Widget>[
            const SizedBox(height: bodyGap),
            Text(
              sentence,
              style: TypeScale.entryBody.copyWith(color: colors.ink2),
            ),
          ],
          if (label != null && open != null) ...<Widget>[
            const SizedBox(height: bodyGap),
            Text(
              label,
              style: TypeScale.textButton.copyWith(color: family),
            ),
          ],
        ],
      ),
    );
    return open == null
        ? card
        : Semantics(
            button: true,
            child: GestureDetector(onTap: open, child: card),
          );
  }
}

/// `.relationship-grid` — two [EntryCard]s across.
class EntryGrid extends StatelessWidget {
  /// Builds the pair.
  const EntryGrid({required this.left, required this.right, super.key});

  /// `.relationship-grid { gap: 10px }`.
  static const double gap = 10;

  /// The left card.
  final Widget left;

  /// The right card.
  final Widget right;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: left),
        const SizedBox(width: gap),
        Expanded(child: right),
      ],
    ),
  );
}
