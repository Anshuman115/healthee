/// `VO₂max · estimate` — the number, its error band, and its inputs.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:1224` —
/// `_Vo2Module`. Anatomy unchanged: age and sex in the header, a 40 px figure
/// with `± SEE ml/kg/min` beside it and a pill carrying the delta from the age
/// median, a 46 px filled 90-day trend, and four stat columns of inputs.
///
/// ```text
///   VO₂MAX · ESTIMATE                                  35 M
///   43.0  ± 3.0 ml/kg/min   ( +3.3 vs age median )
///   ╱‾‾╲___╱‾
///   BMI    RHR    MVPA/WK    PA SCORE
///    —      —        —          —
/// ```
///
/// ## The instrument is named, and legacy does not name it
///
/// [[hr_reserve_vo2max]] Directive 4 requires the method to be stated wherever
/// the number is, *"because an owner whose number comes from a run one week and a
/// questionnaire the next has to be able to see that, or a change of instrument
/// reads as a change in them"*. `Vo2max.method` and `methodCaveat` are non-null
/// by construction for exactly that reason.
///
/// Legacy's Today prints neither — it was written before the tiered estimate
/// existed. This card prints the method under the figure and the caveat under the
/// trend. That is honesty wording in existing slots rather than a new card, and it
/// is the one place on this screen where a line legacy does not have is added
/// rather than removed. It is reported as such.
///
/// The `± SEE` band and the median delta are both legacy's, and the delta pill's
/// hue is legacy's `cSteps` — an amber chip, deliberately not a verdict colour,
/// because being above or below a population median is a fact about the reference
/// group rather than a judgement of the owner.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/vo2max.dart';
import 'package:healthee/features/today/widgets/stat_columns.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/caveat_disclosure.dart';

/// The estimate, the instrument that read it, and what went into it.
class Vo2maxCard extends StatelessWidget {
  /// [vo2max] is the whole `vo2max` block.
  const Vo2maxCard({required this.vo2max, required this.reveals, super.key});

  /// The estimate and its provenance.
  final Vo2max vo2max;

  /// Where "this chart has already animated" is remembered.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = context.hues.fitness;
    final trend = <double>[for (final point in vo2max.trend90d) point.value];
    final sex = vo2max.sex == 'female' ? 'F' : 'M';
    return InstrumentModule(
      label: 'VO₂max · estimate',
      infoKey: 'vo2max',
      tag: tint,
      minHeight: 0,
      trailing: Text(
        vo2max.ageYears == null ? '' : '${vo2max.ageYears} $sex',
        style: HType.number(colors.ink3, size: 11, weight: FontWeight.w400),
      ),
      children: [
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              vo2max.estimate.toStringAsFixed(1),
              style: HType.number(colors.ink, size: 40),
            ),
            const SizedBox(width: 8),
            if (vo2max.standardErrorMlKgMin case final double see)
              Flexible(
                child: Text(
                  '± ${see.toStringAsFixed(1)} ml/kg/min',
                  style: HType.number(
                    colors.ink3,
                    size: 12,
                    weight: FontWeight.w400,
                  ),
                ),
              ),
            if (vo2max.deltaFromMedian case final double delta) ...[
              const SizedBox(width: 8),
              // `Flexible`, where legacy has none. Legacy's row is the figure,
              // a flexible `± SEE` and a fixed pill, and it overflows here by
              // ~29 px at a 420 px phone — Manrope sets this string wider than
              // Space Mono did, and the typeface is one of the three sanctioned
              // differences. The pill shrinks and wraps rather than clipping,
              // because "vs age median" truncated is a different claim.
              Flexible(child: _MedianPill(delta: delta)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        // Directive 4. See the library docstring.
        Text(
          'Read by ${methodLabel(vo2max.method)}'
          '${vo2max.standardErrorSource == null ? '' : ' · ${vo2max.standardErrorSource}'}',
          style: HType.label(colors.ink3, size: 9, tracking: 0.06),
        ),
        const SizedBox(height: 14),
        RevealOnce(
          id: 'today.vo2max',
          registry: reveals,
          builder: (context, t) => HArea(
            trend,
            color: tint,
            progress: t,
            height: 46,
            unit: 'ml/kg',
            digits: 1,
          ),
        ),
        const SizedBox(height: 8),
        // The instrument's limit — 568 characters on the live payload. It was
        // printed here in full and it is half of what the owner reported as
        // *"raw text ... below the fitness card"*. The method itself is still
        // named on the card, two slots up, which is what Directive 4 asks for;
        // this is the paragraph about that method, and it opens on a tap.
        CaveatNote(
          caveats: [vo2max.methodDisclosure],
          label: 'VO₂max · ${methodLabel(vo2max.method)}',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            StatColumn(label: 'BMI', value: statValue(vo2max.inputs.bmi)),
            StatColumn(
              label: 'RHR',
              value: statValue(vo2max.inputs.restingHrMedian7d),
            ),
            StatColumn(
              label: 'MVPA/WK',
              value: statValue(vo2max.inputs.weeklyMvpaMin),
            ),
            StatColumn(
              label: 'PA SCORE',
              value: statValue(vo2max.inputs.physicalActivityScore),
            ),
          ],
        ),
      ],
    );
  }
}

/// The amber chip carrying the delta from the age median.
class _MedianPill extends StatelessWidget {
  const _MedianPill({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final tint = context.hues.movement;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} vs age median',
        style: HType.number(tint, size: 11, weight: FontWeight.w700),
      ),
    );
  }
}

/// Legacy's `stat`: a whole number prints whole, anything else to one decimal,
/// and a missing input prints an em dash.
String statValue(double? value) {
  if (value == null) {
    return '—';
  }
  return value % 1 == 0 ? value.round().toString() : value.toStringAsFixed(1);
}

/// The owner-facing name for a VO₂max instrument.
///
/// The ids are `read/vo2max.py`'s three tiers. An unknown one keeps its id, so a
/// fourth instrument is visible rather than silently unnamed.
String methodLabel(String method) => switch (method) {
  'gps_graded' => 'a recorded session',
  'hr_reserve' => 'heart-rate reserve',
  'jurca_non_exercise' => 'the non-exercise model',
  _ => method,
};
