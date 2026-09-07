/// `Sleep health · 4-dim` — four judgements, each against its own cutoff.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:1017` —
/// `_SleepHealthModule`. A 40 px score over `/ 4`, then one row per dimension:
/// a 26 px pass/fail circle, the dimension's name, and under it the owner's own
/// reading, the published cutoff, and the source in italic.
///
/// ```text
///   SLEEP HEALTH · 4-DIM                              ●
///   3 / 4
///   ✓  Duration
///      6h 20m · cutoff 7–9 h · AASM adult recommendation
///   ✓  Efficiency
///      84.4% · cutoff ≥ 85% · Clinical insomnia criterion
/// ```
///
/// ## The score is shown and the four rows are why that is allowed
///
/// Brief §5.3 forbids a bare `3/4`, and `sleep_health.dart` explains that the
/// server sends the four `point_*` fields separately **so the app can show four
/// judgements rather than a fake composite**. Legacy shows the sum *and* the four
/// rows, which satisfies the same rule the recovery score satisfies: the
/// breakdown is not a detail panel, it is the licence for the number above it.
///
/// ## Two things that come from the payload here and were hard-coded in legacy
///
/// Legacy writes the cutoffs (`'7–9 h'`, `'≥ 85%'`) and the citations
/// (`'Cappuccio 2010'`, `'Windred 2024'`) as string literals in the widget. Both
/// now come off the wire through `SleepHealth.dimensions`, which reads
/// `sleep_health.cutoffs`. Same slots, same order, same shape — but the cutoff on
/// screen is the cutoff the server actually scored against, rather than a copy in
/// the UI free to drift from it.
///
/// The **order** is legacy's and not the model's: Duration, Efficiency, Timing,
/// Regularity. `sleep_health.dart` builds them Duration, Efficiency, Regularity,
/// Timing, and reordering there would move them on the Sleep tab too.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/sleep_health.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:solar_icons/solar_icons.dart';

/// The four-dimension judgement, with each cutoff and each source.
class SleepHealthCard extends StatelessWidget {
  /// [health] is the whole `sleep_health` block.
  const SleepHealthCard({required this.health, super.key});

  /// The night's four judgements.
  final SleepHealth health;

  /// Legacy's row order (`today_screen.dart:1038`).
  static const List<String> rowOrder = <String>[
    'Duration',
    'Efficiency',
    'Timing',
    'Regularity',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ordered = <SleepDimension>[
      for (final name in rowOrder)
        for (final dimension in health.dimensions)
          if (dimension.name == name) dimension,
    ];
    return InstrumentModule(
      label: 'Sleep health · 4-dim',
      infoKey: 'sleep_health',
      tag: colors.accent,
      minHeight: 0,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${health.met}',
              style: HType.number(colors.ink, size: 40),
            ),
            const SizedBox(width: 6),
            Text(
              '/ ${health.dimensions.length}',
              style: HType.number(
                colors.ink3,
                size: 16,
                weight: FontWeight.w400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final dimension in ordered) _DimensionRow(dimension: dimension),
      ],
    );
  }
}

/// One dimension: whether it was met, and against what.
class _DimensionRow extends StatelessWidget {
  const _DimensionRow({required this.dimension});

  final SleepDimension dimension;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Legacy's `_d(sh['point_x']) == 1` is a two-state test, so an unscored
    // dimension renders exactly like a failed one. `SleepDimension.passed` is
    // nullable and that third state is kept: a circle nobody could score gets
    // the neutral mark, not the cross.
    final passed = dimension.passed ?? false;
    final scored = dimension.passed != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: passed
                  ? colors.accent.withValues(alpha: 0.14)
                  : colors.surface2,
              shape: BoxShape.circle,
            ),
            child: Icon(
              passed
                  ? SolarIconsBold.checkCircle
                  : scored
                  ? SolarIconsOutline.closeCircle
                  : SolarIconsOutline.minusCircle,
              size: 15,
              color: passed ? colors.accent : colors.ink3,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dimension.name,
                  style: HType.sans(
                    colors.ink,
                    size: 15,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    style: HType.sans(colors.ink3, size: 11.5, height: 1.3),
                    children: [
                      TextSpan(
                        text:
                            '${dimension.reading ?? '—'} · '
                            'cutoff ${dimension.cutoff} · ',
                      ),
                      TextSpan(
                        text: dimension.source,
                        // Legacy set the source in italic. The bundled family has no
                        // italic face (see `instrument_type.dart`), so this
                        // rendered upright and the emphasis was ink3 alone all
                        // along. The dead `copyWith` is gone; nothing moves.
                        style: HType.sans(colors.ink3, size: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
