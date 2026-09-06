/// The four things that sit inside a `.panel`, in the CSS's own proportions.
///
/// ```css
/// .panel-summary   { display:flex; justify-content:space-between;
///                    align-items:end; gap:12px; margin-bottom:8px; }
/// .panel-value     { font-size:36px; font-weight:600; letter-spacing:-1.8px;
///                    line-height:1.2; }
/// .panel-value>small { color:var(--muted); font-size:12px; font-weight:400;
///                      letter-spacing:0; margin-left:4px; }
/// .panel-summary p { font-size:11px; text-align:right; }
/// .panel-note      { font-size:11px; line-height:1.7; color:var(--muted);
///                    margin-top:12px; }
/// .three           { display:grid; grid-template-columns:repeat(3,1fr);
///                    gap:8px; }
/// .stat-label      { font-size:10px; color:var(--muted); }   /* in a panel */
/// .stat-number     { font-size:22px; font-weight:600; letter-spacing:-1px;
///                    line-height:1.4; }
/// .stat-number>span{ font-size:11px; margin-left:4px; color:var(--muted); }
/// .progress-track  { height:7px; background:var(--surface-soft);
///                    border-radius:8px; overflow:clip; }
/// .progress-track>i{ background:var(--family); }
/// ```
///
/// **None of these takes a `Color`.** The number is ink, the qualifier is ink2,
/// and the one coloured thing — the progress fill — resolves `context.family`
/// from the enclosing `ToneScope`. That is the whole reason a track can be
/// dropped into any panel and come out the right colour.
///
/// The vertical margins in the CSS are **owned here**, not left to the caller,
/// because `.panel-summary`'s 8 and `.panel-note`'s 12 are what make a panel's
/// interior a rhythm rather than a stack. A call site that wrote its own numbers
/// would be a second opinion about the same gap.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/v02/panel_density.dart';

/// `.panel-summary` — the number a panel exists to show, and its context.
class PanelValue extends StatelessWidget {
  /// [context_] is the right-hand qualifier; null draws none.
  const PanelValue(this.value, {this.unit, this.context_, super.key});

  /// `.panel-summary { gap: 12px }`.
  static const double gap = 12;

  /// `.panel-summary { margin-bottom: 8px }`.
  static const double bottomGap = 8;

  /// `.panel-value > small { margin-left: 4px }`.
  static const double unitGap = 4;

  /// The figure.
  final String value;

  /// Its unit, small and beside it.
  final String? unit;

  /// The right-hand sentence — a date, a reference, a second reading.
  final String? context_;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final compact = context.compactPanel;
    final unit = this.unit;
    final side = context_;
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Flexible(
                  child: Text(
                    value,
                    style:
                        (compact
                                ? TypeScale.panelValueCompact
                                : TypeScale.panelValue)
                            .copyWith(color: colors.ink),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                  ),
                ),
                if (unit != null) ...<Widget>[
                  const SizedBox(width: unitGap),
                  Text(
                    unit,
                    style:
                        (compact
                                ? TypeScale.panelUnitCompact
                                : TypeScale.panelUnit)
                            .copyWith(color: colors.ink2),
                  ),
                ],
              ],
            ),
          ),
          if (side != null) ...<Widget>[
            const SizedBox(width: gap),
            Flexible(
              child: Text(
                side,
                textAlign: TextAlign.right,
                style: TypeScale.panelContext.copyWith(color: colors.ink2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `.panel-note` — the sentence a panel discloses in, inside its own bounds.
class PanelNote extends StatelessWidget {
  /// Builds the note. [text] is drawn verbatim.
  const PanelNote(this.text, {super.key});

  /// `.panel-note { margin-top: 12px }`, or 8 in a twin panel.
  static const double topGap = 12;

  /// `.twin-panels .panel-note { margin-top: 8px }`.
  static const double compactTopGap = 8;

  /// What the panel has to say about its own number.
  final String text;

  @override
  Widget build(BuildContext context) {
    final compact = context.compactPanel;
    return Padding(
      padding: EdgeInsets.only(top: compact ? compactTopGap : topGap),
      child: Text(
        text,
        style:
            (compact ? TypeScale.panelNoteCompact : TypeScale.panelNote)
                .copyWith(color: context.colors.ink2),
      ),
    );
  }
}

/// One cell of a [StatRow]: a label over a number with an optional unit.
@immutable
class Stat {
  /// Builds a statistic.
  const Stat(this.label, this.value, {this.unit});

  /// `.stat-label` — what the number is.
  final String label;

  /// `.stat-number` — the number.
  final String value;

  /// `.stat-number > span` — its unit.
  final String? unit;
}

/// `.three` — up to three [Stat]s across a panel's width.
class StatRow extends StatelessWidget {
  /// Builds the row. An empty [stats] draws nothing at all.
  const StatRow(this.stats, {super.key});

  /// `.three { gap: 8px }`.
  static const double gap = 8;

  /// `.stat-number > span { margin-left: 4px }`.
  static const double unitGap = 4;

  /// The statistics, left to right.
  final List<Stat> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < stats.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  stats[i].label,
                  style: TypeScale.statLabel.copyWith(color: colors.ink2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        stats[i].value,
                        style: TypeScale.statValue.copyWith(color: colors.ink),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                    if (stats[i].unit case final String unit) ...<Widget>[
                      const SizedBox(width: unitGap),
                      Text(
                        unit,
                        style: TypeScale.statUnit.copyWith(color: colors.ink2),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// `.progress-track` — one continuous fill, in the enclosing family.
///
/// [fraction] is clamped to 0–1 rather than allowed to overflow: a bar longer
/// than its track is a reading drawn outside the scale it is read against, and
/// the panel's own words are where "over the reference" belongs.
class ProgressTrack extends StatelessWidget {
  /// Builds a track filled to [fraction] of its width.
  const ProgressTrack({required this.fraction, super.key});

  /// `.progress-track { height: 7px }`.
  static const double height = 7;

  /// `.progress-track { border-radius: 8px }`.
  static const double radius = 8;

  /// How much of the track is filled, 0–1.
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final filled = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: context.colors.surface2,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: filled,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.family,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
