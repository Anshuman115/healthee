/// Active minutes — this week against the WHO floor, which comes off the wire.
///
/// `mvpa.week_target` is 150 min/week and it is **not written in this file**.
/// That number is a public-health recommendation with a citation behind it; a
/// copy in a widget is a copy that is wrong on the day the recommendation moves,
/// and nobody would notice because it would still look like a number.
///
/// The bar stops at the floor rather than overfilling. Past 150 the interesting
/// fact is the count, and the count is right there as a number — a bar running
/// off the end says nothing extra and makes the floor unreadable.
///
/// Nothing congratulates. Meeting the floor draws a met line, not a well done.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/activity_today.dart';
import 'package:healthee/features/today/widgets/measured_card.dart';
import 'package:healthee/shared/charts/h_bars.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Today's and this week's moderate-to-vigorous minutes.
class MvpaCard extends StatelessWidget {
  /// Renders [mvpa].
  const MvpaCard({required this.mvpa, required this.reveals, super.key});

  /// The MVPA payload.
  final Mvpa mvpa;

  /// The screen's reveal registry.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Active minutes', style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          HeroValue(value: '${mvpa.todayMin}', unit: 'min today'),
          const SizedBox(height: Insets.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: (mvpa.weekProgress * 1000).round(),
                    child: ColoredBox(
                      color: mvpa.weekMin >= mvpa.weekTarget
                          ? colors.fav
                          : colors.accent,
                    ),
                  ),
                  Expanded(
                    flex: ((1 - mvpa.weekProgress) * 1000).round(),
                    child: ColoredBox(color: colors.line2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            '${mvpa.weekMin} of ${mvpa.weekTarget} min this week · '
            '${mvpa.weekModerateMin} moderate, ${mvpa.weekVigorousMin} vigorous',
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          if (mvpa.daily.length >= 2) ...[
            const SizedBox(height: Insets.lg),
            RevealOnce(
              id: 'mvpa-daily',
              registry: reveals,
              builder: (context, t) => HBars(
                [for (final day in mvpa.daily) day.mvpaMin.toDouble()],
                color: colors.accent,
                progress: t,
                height: 48,
                unit: 'min',
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'The last ${mvpa.daily.length} days.',
              style: text.labelSmall?.copyWith(color: colors.ink3),
            ),
          ],
          const SizedBox(height: Insets.md),
          CitationRow(
            noteIds: mvpa.researchNotes,
            source: 'The ${mvpa.weekTarget} min/week floor comes from the '
                'server, not from this app.',
          ),
        ],
      ),
    );
  }
}
