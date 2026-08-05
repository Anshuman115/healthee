/// A small labelled figure — **legacy's `_heroStat`**.
///
/// `sleep_screen.dart:526`: an eyebrow, 3 px, then the value at
/// `num(color ?? ink, 15, w700)`. Four of them on the screen (IN BED,
/// EFFICIENCY, AVG / NIGHT, NIGHTS SHORT), which is why it is a widget rather
/// than a method on one card.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/features/sleep/widgets/sleep_value.dart';
import 'package:healthee/shared/instrument_module.dart';

/// One labelled figure in a hero row.
class HeroStat extends StatelessWidget {
  /// [reading] is the value, already written exactly as legacy wrote it.
  const HeroStat({
    required this.label,
    required this.reading,
    this.colour,
    super.key,
  });

  /// The eyebrow above the figure.
  final String label;

  /// The formatted value and its honesty state.
  final Reading<String> reading;

  /// Overrides the ink on the figure.
  ///
  /// **A withheld value never takes it.** Legacy coloured efficiency by
  /// `(eff ?? 0) >= 85 ? green : cHeart`, so a night with no efficiency at all
  /// rendered its dash in the "below target" red — a verdict passed on a
  /// measurement that does not exist. The hole spends no colour, which is the
  /// rule `tokens.dart` states for every refusal.
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ModuleLabel(label),
        const SizedBox(height: 3),
        SleepFigure(
          reading: reading,
          style: HType.number(colour ?? colors.ink, size: 15),
          holeWidth: 46,
        ),
      ],
    );
  }
}
