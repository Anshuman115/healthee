/// Today's stress, hour by hour — the shape a single number cannot carry.
///
/// The strap emits a stress figure continuously and a "current stress: 32" says
/// almost nothing: what matters is whether the day has been flat, or has spiked
/// twice and settled. The hourly bars answer that; the number alone does not,
/// which is brief §5's admission test for a chart.
///
/// The hours are the SERVER's aggregation (`today_stress_series`), not the
/// phone's. The phone holds the raw samples and could average them itself —
/// which is exactly why it must not: an hourly mean computed two ways is two
/// definitions of one number, and the server's is the canonical one.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/metric_hues.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/today_series.dart';
import 'package:healthee/shared/charts/h_bars.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Today's stress by hour.
class StressCard extends StatelessWidget {
  /// [hours] is `today_stress_series`, earliest first.
  const StressCard({required this.hours, required this.reveals, super.key});

  /// The hourly summaries.
  final List<HourPoint> hours;

  /// The screen's reveal registry.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (hours.length < 2) {
      return const SizedBox.shrink();
    }
    // The card is about ONE metric, so it wears that metric's identity tag —
    // `metric_hues.dart` for why that is not a verdict. The tag comes from the
    // same `tagFor` table the grid asks, so the stress cell and this card cannot
    // end up different colours.
    final tag = context.hues.tagFor('stress');
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stress today', style: text.labelSmall?.copyWith(color: tag)),
          const SizedBox(height: Insets.md),
          RevealOnce(
            id: 'stress-hourly',
            registry: reveals,
            builder: (context, t) => HBars(
              [for (final hour in hours) hour.average],
              color: tag,
              progress: t,
              height: 56,
              allHighlighted: true,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            '${hours.first.label} to ${hours.last.label} · '
            'hourly averages from your strap, as the server grouped them',
            style: text.labelSmall?.copyWith(color: colors.ink3),
          ),
        ],
      ),
    );
  }
}
