/// Sleep performance — last night against the 8 h reference, and the fortnight.
///
/// **Legacy** `sleep_screen.dart:366–383`. The percentage at `num(…, 34, w700)`
/// with "of your 8h need last night" beside it at `num(ink3, 12)`, a 6 px
/// progress bar in `cSleep`, then AVG / NIGHT and NIGHTS SHORT 22 px apart.
///
/// ## `need` is a constant, and the card's own words oversell it
///
/// Legacy writes `const need = 480.0` and then labels it **"your 8h need"**. It
/// is not the owner's need — nothing here is personalised, and 8 h is not even
/// the cutoff the sleep-health check uses (7–9 h,
/// `read/sleep_common.py::SLEEP_CUTOFFS`). Ported verbatim, wording included, and
/// reported: changing a displayed target is a product decision, not a port.
///
/// ## The honesty changes
///
/// A withheld percentage is **not painted red**. Legacy's
/// `(perf ?? 0) >= 85 ? green : cHeart` gave a night with no measured sleep the
/// same colour as a bad one.
///
/// `NIGHTS SHORT` is withheld rather than rendered `0/0`. A ratio out of nothing
/// is a number-shaped statement that no nights were short, which is not what an
/// empty fortnight means.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/honesty/sleep_gap.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/features/sleep/widgets/hero_stat.dart';
import 'package:healthee/features/sleep/widgets/sleep_value.dart';
import 'package:healthee/shared/instrument/h_progress_bar.dart';
import 'package:healthee/shared/instrument_module.dart';

/// The 8 h reference every figure on this card is measured against.
///
/// **Legacy's `const need = 480.0`.** One definition, used by the percentage,
/// the bar and the "nights short" count, so the three cannot disagree
/// (CLAUDE.md: one canonical definition per metric).
const double kSleepNeedMin = 480;

/// Legacy's "Sleep performance" module.
class SleepPerformanceCard extends StatelessWidget {
  /// [recent] is the last fourteen nights, newest first — legacy's `recent`.
  const SleepPerformanceCard({
    required this.night,
    required this.recent,
    required this.progress,
    super.key,
  });

  /// The latest night.
  final SleepNight night;

  /// The fortnight behind it.
  final List<SleepNight> recent;

  /// How far the reveal has run.
  final double progress;

  /// Every measured total in [recent], newest first. Legacy's `tsts`.
  List<double> get totals => <double>[
    for (final entry in recent)
      if (entry.tstMin.valueOrNull case final double minutes) minutes,
  ];

  /// Last night as a share of [kSleepNeedMin], 0–100. Legacy's `perf`.
  Reading<double> get performance =>
      night.tstMin.map((minutes) => (100 * minutes / kSleepNeedMin).clamp(0, 100));

  /// The fortnight's mean. Withheld when the fortnight is empty.
  Reading<double> get average {
    final measured = totals;
    if (measured.isEmpty) {
      return Withheld<double>(SleepGap.noSession.disclosure);
    }
    return Present<double>(
      measured.reduce((a, b) => a + b) / measured.length,
    );
  }

  /// `3/14`. Withheld when there is no fortnight to count.
  Reading<String> get nightsShort {
    final measured = totals;
    if (measured.isEmpty) {
      return Withheld<String>(SleepGap.noSession.disclosure);
    }
    final short = measured.where((minutes) => minutes < kSleepNeedMin).length;
    return Present<String>('$short/${measured.length}');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    final percent = performance.valueOrNull;
    return InstrumentModule(
      label: 'Sleep performance',
      tag: hues.sleep,
      infoKey: 'sleep_debt',
      minHeight: 0,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            SleepFigure(
              reading: performance.map((value) => '${value.round()}%'),
              style: HType.number(
                percent == null
                    ? colors.ink
                    : percent >= _goodEnough
                    ? colors.fav
                    : hues.heart,
                size: 34,
              ),
              holeWidth: 62,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'of your 8h need last night',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HType.number(colors.ink3, size: 12, weight: FontWeight.w400),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        HProgressBar(
          value: night.tstMin.valueOrNull ?? 0,
          max: kSleepNeedMin,
          progress: progress,
          height: 6,
          color: hues.sleep,
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Flexible(
              child: HeroStat(
                label: 'AVG / NIGHT',
                reading: average.map((minutes) => hoursMinutes(minutes.round())),
              ),
            ),
            const SizedBox(width: 22),
            Flexible(
              child: HeroStat(label: 'NIGHTS SHORT', reading: nightsShort),
            ),
          ],
        ),
        SleepGapNote(
          fields: <String, Reading<Object>>{
            'Last night as a share of 8 h': performance,
            'Your fortnightly average': average,
            'The count of short nights': nightsShort,
          },
        ),
      ],
    );
  }

  /// Legacy's 85% threshold for painting the figure green.
  static const double _goodEnough = 85;
}
