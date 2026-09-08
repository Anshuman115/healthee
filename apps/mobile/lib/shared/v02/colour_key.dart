/// `.colour-key` — the legend that says which colour is which.
///
/// ```css
/// .colour-key       { display: flex; align-items: center; flex-wrap: wrap;
///                     gap: 8px 12px; font-size: 10px; color: var(--muted); }
/// .colour-key > span{ display: flex; align-items: center; gap: 5px; }
/// .colour-key i     { width: 6px; height: 6px; border-radius: 50%;
///                     background: var(--family); }
/// ```
///
/// `gap: 8px 12px` is row-gap then column-gap, so entries sit 12 apart across and
/// their rows 8 apart down — `Wrap`'s `spacing` and `runSpacing` in that order.
///
/// An entry's swatch defaults to the resolved family, which is what the CSS does.
/// A **sleep-stage** legend passes its colours explicitly, because those four are
/// their own mapping and do not follow the card's tone; `InstrumentHues.sleepStage`
/// is the only place they come from.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';

/// One legend entry.
@immutable
class ColourKeyEntry {
  /// [colour] of null takes [tone]'s family, and a null [tone] the enclosing
  /// scope's.
  const ColourKeyEntry(this.label, {this.colour, this.tone}) : dot = true;

  /// An entry with **no swatch** — a fact standing beside the coded ones.
  ///
  /// `screens-sleep.js` writes exactly one of these:
  /// `<span>${H.duration(night.tib_min)} in bed</span>`, with no `<i>` child, so
  /// the CSS draws no dot. It sits in the same key because it belongs to the
  /// same reading; it carries no colour because time in bed is not a series on
  /// any chart, and a dot would promise a line that is not there.
  const ColourKeyEntry.plain(this.label)
    : colour = null,
      tone = null,
      dot = false;

  /// What the swatch means.
  final String label;

  /// Whether this entry draws a swatch at all.
  final bool dot;

  /// The swatch's colour, or null for the family.
  ///
  /// Only the **sleep stages** pass one. Those four are their own mapping and
  /// do not follow any card's tone; everything else names a [tone] instead, so
  /// the hue is still resolved rather than handed over.
  final Color? colour;

  /// Which family this entry's swatch takes. Null inherits the card's.
  ///
  /// A recovery legend is four entries in four different families inside one
  /// card that already has a family of its own — the same shape `meters.dart`
  /// solves with a per-segment `Tone`, and solved the same way here.
  final Tone? tone;
}

/// A wrapping row of labelled dots.
class ColourKey extends StatelessWidget {
  /// Builds a legend from [entries].
  const ColourKey(this.entries, {super.key});

  /// `.colour-key i { width: 6px; height: 6px }`.
  static const double dotSize = 6;

  /// `.colour-key > span { gap: 5px }`.
  static const double dotGap = 5;

  /// The column half of `gap: 8px 12px`.
  static const double entryGap = 12;

  /// The row half of `gap: 8px 12px`.
  static const double runGap = 8;

  /// The keys, in the order they are drawn.
  final List<ColourKeyEntry> entries;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = Theme.of(context).extension<InstrumentHues>()!;
    final family = context.family;
    return Wrap(
      spacing: entryGap,
      runSpacing: runGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final entry in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (entry.dot) ...<Widget>[
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: entry.colour ?? entry.tone?.family(hues) ?? family,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: dotGap),
              ],
              Text(
                entry.label,
                style: TypeScale.colourKey.copyWith(color: colors.ink2),
              ),
            ],
          ),
      ],
    );
  }
}
