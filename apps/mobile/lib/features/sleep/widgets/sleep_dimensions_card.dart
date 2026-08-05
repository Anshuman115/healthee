/// Four judgements against four published cutoffs. **Never summed.**
///
/// Brief §5.3, and the payload agrees with it: the server sends `point_duration`
/// / `point_efficiency` / `point_regularity` / `point_timing` as separate 0-or-1
/// fields *precisely so the app can show four judgements rather than a fake
/// composite*. This card renders those four and does not draw the `score` /
/// `max_score` pair anywhere.
///
/// The reason is not stylistic. Summing them asserts a trade — that a long,
/// badly-timed night is worth the same as a short, well-timed one — and nothing
/// in the evidence supports it. `docs/APP_DESIGN.md` §1 admits five composites
/// and this is not one of them.
///
/// Each row carries **its own cutoff and where the cutoff comes from**, taken
/// from the payload. Duration is AASM's, efficiency is the clinical insomnia
/// criterion, regularity is SRI over 14 nights, timing is chronotype work. A
/// judgement whose threshold is invisible is a judgement the owner cannot argue
/// with.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/metric_hues.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/sleep_health.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/states/value_hole.dart';

/// The four sleep dimensions, each against its own published cutoff.
class SleepDimensionsCard extends StatelessWidget {
  /// Renders [health]'s four judgements.
  const SleepDimensionsCard({required this.health, super.key});

  /// The night's four-dimension payload.
  final SleepHealth health;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The title takes the tag; the four verdict marks below keep `fav` /
          // `unf`, which is what they are for. A tag on the title and a verdict
          // on the row is the split `metric_hues.dart` describes.
          Text(
            'Sleep health',
            style: text.labelSmall?.copyWith(
              color: context.hues.tagFor('sleep_health_score_4dim'),
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            'Four independent judgements, each against its own published '
            'cutoff. They are deliberately not added up: no validated single '
            'number combines them.',
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          for (final dimension in health.dimensions) ...[
            Divider(color: colors.line2, height: Insets.lg, thickness: hairline),
            _DimensionRow(dimension: dimension),
          ],
          const SizedBox(height: Insets.md),
          CitationRow(noteIds: health.researchNotes),
        ],
      ),
    );
  }
}

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({required this.dimension});

  final SleepDimension dimension;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final passed = dimension.passed;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A thin left mark carries the verdict — brief §2 puts state accents on
        // a border, never on a fill, and an unscored dimension gets no colour
        // at all because "we could not score it" is not a verdict.
        Container(
          width: 2,
          height: 34,
          color: switch (passed) {
            true => colors.fav,
            false => colors.unf,
            null => colors.line,
          },
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dimension.name, style: text.titleSmall),
              const SizedBox(height: Insets.xs),
              Text(
                'Cutoff ${dimension.cutoff} · ${dimension.source}',
                style: text.labelSmall?.copyWith(color: colors.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(width: Insets.md),
        if (dimension.reading case final String reading)
          Text(reading, style: text.headlineSmall)
        else
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: ValueHole.inline(),
          ),
      ],
    );
  }
}
