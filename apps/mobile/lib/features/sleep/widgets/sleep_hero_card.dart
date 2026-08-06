/// The page's hero — the strap's own score, and how long the owner slept.
///
/// **Legacy** `sleep_screen.dart:275–305`. A 116 px tick gauge on the left with
/// the figure at `num(ink, 32, w700)` and `SCORE` at `lbl(cSleep, 8, 0.16)`
/// inside it, 18 px, then Time asleep at `num(ink, 27, w700)` with its delta
/// badge, and IN BED · EFFICIENCY 22 px apart underneath.
///
/// ## Two honesty changes, both in the same place
///
/// **The gauge no longer reads zero for a night with no score.** Legacy passed
/// `value: (zepp ?? 0)`, which lights no ticks — visually identical to a real
/// score of 0 — while the centre said `—`. The dial keeps its footprint, the
/// centre carries a hole, and the foot says the score was not derived.
///
/// **A withheld efficiency is not coloured red.** See [HeroStat.colour].
///
/// The score is labelled **the strap's**, because that is what `zepp_score` is.
/// Healthee's own judgement of the night is the four checks further down, and one
/// screen showing two numbers called "score" is how a metric gets two definitions.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/features/sleep/widgets/hero_stat.dart';
import 'package:healthee/features/sleep/widgets/sleep_value.dart';
import 'package:healthee/shared/charts/h_tick_gauge.dart';
import 'package:healthee/shared/instrument/h_delta_badge.dart';
import 'package:healthee/shared/instrument_module.dart';

/// Legacy's hero module.
class SleepHeroCard extends StatelessWidget {
  /// [previous] is the night before, for the delta badge. Null when there is none.
  const SleepHeroCard({
    required this.night,
    required this.previous,
    required this.progress,
    super.key,
  });

  /// The latest night.
  final SleepNight night;

  /// The night before it, when the owner has one.
  final SleepNight? previous;

  /// How far the reveal has run.
  final double progress;

  /// Legacy's `size: 116`.
  static const double _gaugeSize = 116;

  /// Minutes of difference from the night before, or null when either is absent.
  ///
  /// Legacy's rule: both nights must carry a `tst_min`. A delta computed against
  /// a missing night would be a comparison with nothing.
  int? get delta {
    final tonight = night.tstMin.valueOrNull;
    final before = previous?.tstMin.valueOrNull;
    return tonight == null || before == null ? null : (tonight - before).round();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    final efficiency = night.efficiencyPct.valueOrNull;
    return InstrumentModule(
      tag: null,
      // **Legacy's `infoKey: 'sleep'` is deliberately NOT passed here, and that
      // is now a DECISION, not a deferral — owner-delegated, taken 2026-08-06.**
      //
      // It was passed once, and it was dead: `HModule` draws the header row only
      // when a `label` exists, this card passes none, so the ⓘ has never rendered
      // — in legacy either. Restoring it would mean giving this card a header row
      // it has never had, ~25 px above the gauge, for content that is **already
      // reachable twice over**: the `sleep` explainer opens from Today's Sleep
      // tile, which has a label, and the sleep-health card below carries its own
      // `CitationRow`. A new row for a second door to the same room is not worth
      // the hero's proportions.
      //
      // So: it stays removed. Do not re-add the argument — the assert in
      // `InstrumentModule` will reject it, and `test/features/reachability_test.dart`
      // is what proves the explainer is still reachable without it.
      minHeight: 0,
      children: <Widget>[
        Row(
          children: <Widget>[
            HTickGauge(
              value: night.deviceScore.valueOrNull ?? 0,
              progress: progress,
              size: _gaugeSize,
              color: hues.sleep,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SleepFigure(
                    reading: night.deviceScore.map((score) => score.round().toString()),
                    style: HType.number(colors.ink, size: 32),
                    holeWidth: 44,
                  ),
                  Text('SCORE', style: HType.label(hues.sleep, size: 8, tracking: 0.16)),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const ModuleLabel('Time asleep'),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      SleepFigure(
                        reading: night.tstMin.map(hoursMinutes),
                        style: HType.number(colors.ink, size: 27),
                        holeWidth: 84,
                      ),
                      if (delta case final int minutes) ...<Widget>[
                        const SizedBox(width: 8),
                        HDeltaBadge(minutes, good: minutes >= 0, size: 10),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: HeroStat(
                          label: 'IN BED',
                          reading: night.tibMin.map(hoursMinutes),
                        ),
                      ),
                      const SizedBox(width: 22),
                      Flexible(
                        child: HeroStat(
                          label: 'EFFICIENCY',
                          reading: night.efficiencyPct.map(
                            (value) => '${value.toStringAsFixed(0)}%',
                          ),
                          colour: efficiency == null
                              ? null
                              : efficiency >= _efficiencyCutoff
                              ? colors.fav
                              : hues.heart,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SleepGapNote(
          fields: <String, Reading<Object>>{
            "The strap's sleep score": night.deviceScore,
            'Time asleep': night.tstMin,
            'Time in bed': night.tibMin,
            'Efficiency': night.efficiencyPct,
          },
        ),
      ],
    );
  }

  /// ≥85% is the sleep-health efficiency cutoff the server also scores against
  /// (`read/sleep_common.py::SLEEP_CUTOFFS`). Legacy hard-coded the same 85.
  static const double _efficiencyCutoff = 85;
}
