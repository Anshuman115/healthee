/// Today's training load, against the owner's own thirty days.
///
/// The comparison is the content. A load of 55 means nothing on its own; 55
/// against a personal baseline of 55 means "an ordinary day", and 55 against a
/// baseline of 20 means something else entirely. Brief §5.2 makes the general
/// case — population norms are irrelevant here and must not appear — and this
/// card holds to it: the only reference drawn is [CardioLoad.baseline30d].
///
/// [CardioLoad.hrMinutes] is shown because it is the confidence behind the
/// number. A load computed from four minutes of heart rate and one computed from
/// four hundred are not the same claim, and the strap decides which you get.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/metric_hues.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/activity_today.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/shared/charts/h_bars.dart';
import 'package:healthee/shared/measured_card.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Today's load, its baseline, and thirty days of it.
class CardioLoadCard extends StatelessWidget {
  /// Renders [load].
  const CardioLoadCard({
    required this.load,
    required this.reveals,
    super.key,
  });

  /// The cardio-load payload.
  final CardioLoad load;

  /// The screen's reveal registry.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    // The card is about ONE metric, so it wears that metric's identity tag —
    // `metric_hues.dart` for why that is not a verdict. It comes from the same
    // `tagFor` table the grid asks, so a cell and the card it opens cannot end
    // up different colours.
    final tag = context.hues.tagFor('cardio_load');
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cardio load', style: text.labelSmall?.copyWith(color: tag)),
          const SizedBox(height: Insets.sm),
          HeroValue(value: load.load.round().toString()),
          const SizedBox(height: Insets.xs),
          Text(
            _comparison(load),
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          if (load.trend30d.length >= 2) ...[
            const SizedBox(height: Insets.lg),
            RevealOnce(
              id: 'cardio-load-30d',
              registry: reveals,
              builder: (context, t) => HBars(
                TrendPoint.valuesOf(load.trend30d),
                color: tag,
                progress: t,
                height: 56,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'The last ${load.trend30d.length} days. Today is the last bar.',
              style: text.labelSmall?.copyWith(color: colors.ink3),
            ),
          ],
          const SizedBox(height: Insets.md),
          CitationRow(noteIds: load.researchNotes),
        ],
      ),
    );
  }

  /// Today against the owner's own normal, plus the confidence behind it.
  static String _comparison(CardioLoad load) {
    final parts = <String>[];
    final baseline = load.baseline30d;
    final ratio = load.versusBaseline;
    if (baseline == null || ratio == null) {
      parts.add('No 30-day baseline for this yet');
    } else if ((ratio - 1).abs() < 0.1) {
      parts.add('About your usual ${baseline.round()}');
    } else {
      final percent = ((ratio - 1) * 100).abs().round();
      parts.add(
        '$percent% ${ratio > 1 ? 'above' : 'below'} your usual '
        '${baseline.round()}',
      );
    }
    if (load.hrMinutes case final int minutes) {
      parts.add('from $minutes min of heart-rate data');
    }
    return parts.join(' · ');
  }
}
