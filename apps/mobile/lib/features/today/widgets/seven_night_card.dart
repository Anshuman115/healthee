/// `Sleep · 7 nights` — the stacked week, with its stage legend.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:1087` —
/// `_SevenNightModule`. A 108 px [HStackedSleep], 10 px, then four legend chips
/// (a 7 px rounded swatch, 5 px, an 8 px label at 0.08 em, 14 px apart).
///
/// The swatch colours come from `InstrumentHues.sleepStage`, which is the ONE
/// mapping every sleep chart in the app draws from — the legend and the bars
/// above it cannot disagree, because they read the same function.
///
/// Legacy draws this only when the history has at least two nights
/// (`history.length >= 2`); one bar is not a week. `today_sections.dart` keeps
/// that gate.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/sleep_history.dart';
import 'package:healthee/shared/charts/h_stacked_sleep.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';

/// A week of nights, stacked by stage.
class SevenNightCard extends StatelessWidget {
  /// [nights] is oldest first.
  const SevenNightCard({required this.nights, required this.reveals, super.key});

  /// The week's nights.
  final List<SleepNightSummary> nights;

  /// Where "this chart has already animated" is remembered.
  final RevealRegistry reveals;

  /// Legacy's `HStackedSleep(week, height: 108)`.
  static const double chartHeight = 108;

  /// The legend, in legacy's order — [kSleepStages] itself, so a stage cannot be
  /// listed here and missing from the chart.
  ///
  /// The fifth "Unrecognised" key `legendStages()` can add is deliberately not
  /// used: this chart is drawn from [SleepNightSummary], which carries four
  /// named minute totals and has no slot an unreadable code could arrive in.

  @override
  Widget build(BuildContext context) {
    final tint = context.hues.sleep;
    return InstrumentModule(
      label: 'Sleep · 7 nights',
      tag: tint,
      minHeight: 0,
      children: [
        RevealOnce(
          id: 'today.seven-nights',
          registry: reveals,
          builder: (context, t) =>
              HStackedSleep(nights, progress: t, height: chartHeight),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final stage in kSleepStages) _LegendChip(stage: stage),
          ],
        ),
      ],
    );
  }
}

/// A swatch and its stage name.
class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: sleepStageColor(context.hues, stage),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            // Legacy printed the raw key — DEEP · CORE · REM · AWAKE — while the
            // Sleep tab's naps legend printed `light` for the same stage. The
            // word comes from `sleepStageLabel` now, so the app says LIGHT
            // everywhere or CORE nowhere.
            sleepStageLabel(stage).toUpperCase(),
            style: HType.label(colors.ink3, size: 8, tracking: 0.08),
          ),
        ],
      ),
    );
  }
}
