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
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';

/// One legend entry.
@immutable
class ColourKeyEntry {
  /// [colour] of null takes the resolved family.
  const ColourKeyEntry(this.label, {this.colour});

  /// What the swatch means.
  final String label;

  /// The swatch's colour, or null for the family.
  final Color? colour;
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
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: entry.colour ?? family,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: dotGap),
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
