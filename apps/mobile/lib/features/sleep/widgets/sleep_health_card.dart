/// Sleep health — **four independent judgements against published cutoffs, and
/// deliberately not summed into anything.**
///
/// **Legacy** `sleep_screen.dart:631` (`_SleepHealthCard`). The headline is the
/// count at `num(ink, 34, w700)` with `/ 4` beside it at `num(ink3, 15)`, then
/// four rows: a 24 px circle carrying a tick or a cross, the dimension's name at
/// `sans(ink, 14, w600)`, the measured value at `num(ink2, 13)` and its cutoff at
/// `num(ink3, 10)`.
///
/// ## The framing is the product, and it is preserved exactly
///
/// `metric_info.dart`'s own entry says it: *"These four together track health
/// better than any single 0–100 'sleep score' — no such score is scientifically
/// validated."* CLAUDE.md forbids composite scores without a documented
/// methodology and a research note, and there is no validated one here.
///
/// So **`n / 4` is a count of checks passed, never a score**. It is not scaled to
/// 100, not averaged, not weighted, and the four rows are never collapsed into a
/// verdict word. `test/features/sleep_honesty_test.dart` asserts that the four
/// dimensions reach the screen as four rows and that nothing on the card renders
/// a percentage, so a future "sleep score 75%" cannot land quietly.
///
/// ## The honesty change
///
/// Legacy computed each row as `_d(n['point_duration']) == 1`, so a dimension the
/// server never scored rendered as a **failed check** — a grey cross beside a
/// dash. That is a judgement about the owner's night made out of missing data,
/// and it is the exact failure `Reading` exists to make impossible. Each point is
/// a `Reading<bool>` here: pass, fail, or **not assessed**, which draws neither
/// mark and says so.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/features/sleep/widgets/sleep_value.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/states/value_hole.dart';
import 'package:solar_icons/solar_icons.dart';

/// One of the four checks: whether it passed, what was measured, the cutoff.
///
/// [measured] is already formatted and is **null when there is nothing to
/// show** — the row draws a hole rather than a dash. It is a string rather than
/// a number because the four dimensions are measured in four units, one of
/// which (timing) is a clock the server formatted and this app must not reround.
typedef SleepDimension = ({
  String name,
  Reading<bool> passed,
  String? measured,
  String cutoff,
});

/// Legacy's "Sleep health · 4-dim" module.
class SleepHealthCard extends StatelessWidget {
  /// [night] carries all four checks and the count.
  const SleepHealthCard({required this.night, super.key});

  /// The night being judged.
  final SleepNight night;

  /// The four dimensions, in legacy's order, with legacy's cutoff strings.
  List<SleepDimension> get dimensions => <SleepDimension>[
    (
      name: 'Duration',
      passed: night.pointDuration,
      measured: _formatted(night.tstMin, hoursMinutes),
      cutoff: '7–9 h',
    ),
    (
      name: 'Efficiency',
      passed: night.pointEfficiency,
      measured: _formatted(
        night.efficiencyPct,
        (value) => '${value.toStringAsFixed(0)}%',
      ),
      cutoff: '≥ 85%',
    ),
    (
      name: 'Timing',
      passed: night.pointTiming,
      measured: night.midpointLocal.valueOrNull,
      cutoff: '2–4 am mid',
    ),
    (
      name: 'Regularity',
      passed: night.pointRegularity,
      measured: _formatted(night.sri, (value) => value.toStringAsFixed(0)),
      cutoff: 'SRI ≥ 70',
    ),
  ];

  static String? _formatted(
    Reading<double> reading,
    String Function(double value) format,
  ) {
    final value = reading.valueOrNull;
    return value == null ? null : format(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InstrumentModule(
      label: 'Sleep health · 4-dim',
      tag: colors.accent,
      infoKey: 'sleep_health',
      minHeight: 0,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            SleepFigure(
              reading: night.healthScore.map((count) => count.round().toString()),
              style: HType.number(colors.ink, size: 34),
              holeWidth: 40,
            ),
            const SizedBox(width: 6),
            // `/ 4` and never `%`. See the library docstring.
            Text(
              '/ 4',
              style: HType.number(colors.ink3, size: 15, weight: FontWeight.w400),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final dimension in dimensions) _DimensionRow(dimension: dimension),
        SleepGapNote(
          fields: <String, Reading<Object>>{
            'The count of checks passed': night.healthScore,
            'Duration': night.pointDuration,
            'Efficiency': night.pointEfficiency,
            'Timing': night.pointTiming,
            'Regularity': night.pointRegularity,
          },
        ),
      ],
    );
  }

}

/// One check. Legacy's row, plus a third state legacy did not have.
class _DimensionRow extends StatelessWidget {
  const _DimensionRow({required this.dimension});

  final SleepDimension dimension;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          _Mark(passed: dimension.passed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              dimension.name,
              style: HType.sans(colors.ink, weight: FontWeight.w600),
            ),
          ),
          if (dimension.measured case final String measured)
            Flexible(
              child: Text(
                measured,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HType.number(colors.ink2, size: 13, weight: FontWeight.w400),
              ),
            )
          else
            const ValueHole(width: 40, height: 12, radius: Radii.inlineHole),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              dimension.cutoff,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HType.number(colors.ink3, size: 10, weight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 24 px circle. Tick, cross, or **neither**.
class _Mark extends StatelessWidget {
  const _Mark({required this.passed});

  final Reading<bool> passed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final result = passed.valueOrNull;
    if (result == null) {
      // Not assessed. A cross here would be legacy's bug: a failed check drawn
      // out of an absent measurement.
      return const SizedBox(
        width: 24,
        height: 24,
        child: Center(child: ValueHole(width: 16, height: 16, radius: Radii.inlineHole)),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        // Legacy: `c.green.withValues(alpha: 0.14)` for a pass, `c.sunken` for a
        // fail. Both to the value.
        color: result ? colors.fav.withValues(alpha: 0.14) : colors.surface2,
        shape: BoxShape.circle,
      ),
      child: Icon(
        result ? SolarIconsBold.checkCircle : SolarIconsOutline.closeCircle,
        size: 14,
        color: result ? colors.fav : colors.ink3,
      ),
    );
  }
}
