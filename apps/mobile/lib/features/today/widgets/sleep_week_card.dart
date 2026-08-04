/// The week's nights, stacked by stage — legacy's `HStackedSleep`, ported.
///
/// The comparison the number alone cannot make: seven nights side by side on one
/// hour axis, so a short night reads as short *against the owner's own week*
/// rather than against an idea of what a night should be.
///
/// The bars are stacked by stage because that is what changed, not just how much
/// — two six-hour nights with very different deep-sleep shares are two different
/// nights, and a plain total would draw them identically.
///
/// Seven nights, labelled seven nights. `/api/today` sends `sleep_history_7d`;
/// the longer windows live on `/api/sleep`.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/sleep_history.dart';
import 'package:healthee/shared/charts/h_stacked_sleep.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Seven nights of stage totals.
class SleepWeekCard extends StatelessWidget {
  /// [nights] is oldest first. An empty list renders nothing.
  const SleepWeekCard({
    required this.nights,
    required this.reveals,
    super.key,
  });

  /// The week's nights.
  final List<SleepNightSummary> nights;

  /// The screen's reveal registry.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (nights.isEmpty) {
      return const SizedBox.shrink();
    }
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your last ${nights.length} nights', style: text.labelSmall),
          const SizedBox(height: Insets.md),
          RevealOnce(
            id: 'sleep-week-stack',
            registry: reveals,
            builder: (context, t) => HStackedSleep(nights, progress: t),
          ),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.md,
            runSpacing: Insets.xs,
            children: [
              for (final stage in kSleepStages)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: Insets.xs),
                      decoration: BoxDecoration(
                        color: sleepStageColor(colors, stage),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                    Text(
                      sleepStageLabel(stage),
                      style: text.labelSmall?.copyWith(color: colors.ink3),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
