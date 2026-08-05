/// VO₂max — **and the instrument that produced it**, which is not optional.
///
/// [[hr_reserve_vo2max]] Directive 4 requires the method to be stated wherever
/// the number is, and `vo2max.dart` already makes that structural: you cannot
/// construct a `Vo2max` without `method` and `method_caveat`. This card is the
/// last hop, and it holds the other half of the rule.
///
/// | method | means | error |
/// |---|---|---|
/// | `gps_graded` | fitted from a recorded session — the best we have | MAPE 6.85% |
/// | `hr_reserve` | inverted from heart-rate reserve; **reads low** | modelled ±3.2 |
/// | `jurca_non_exercise` | a questionnaire model; measures no exertion | SEE 5.075 |
///
/// **Never averaged, never shown interchangeably.** The uncertainty band is
/// drawn from `see_ml_kg_min` and labelled with `see_source`, so a MAPE cannot
/// be read as a standard error of estimate — those are different quantities and
/// a bare ± would flatten them.
///
/// The population median is drawn as a **reference line, not a target**. It is a
/// fact about a reference group (the FRIEND registry's 16,278 treadmill tests),
/// and `delta_from_median` says where the owner sits against it without
/// suggesting they should be somewhere else.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/metric_hue.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/data/models/vo2max.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/measured_card.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/states/reasoning_note.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The fitness estimate, its instrument, its error and its reference.
class Vo2maxCard extends StatelessWidget {
  /// Renders [vo2max].
  const Vo2maxCard({required this.vo2max, required this.reveals, super.key});

  /// The estimate and everything the server said about it.
  final Vo2max vo2max;

  /// The screen's reveal registry.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    // The card is about ONE metric, so it wears that metric's identity tag —
    // `instrument_hues.dart` for why that is not a verdict, and for why VO₂max sits
    // in the movement family rather than defaulting to rest.
    final tag = hueFor(context.hues, 'vo2max_estimate');
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VO₂max', style: text.labelSmall?.copyWith(color: tag)),
          const SizedBox(height: Insets.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              HeroValue(
                value: vo2max.estimate.toStringAsFixed(1),
                unit: 'ml/kg/min',
                tag: tag,
              ),
              const Spacer(),
              if (_band(vo2max) case final String band)
                Text(band, style: text.labelMedium?.copyWith(color: colors.ink2)),
            ],
          ),
          const SizedBox(height: Insets.md),
          // The instrument, named, in the position the design gives it.
          Text(instrumentLabel(vo2max.method), style: text.titleSmall),
          const SizedBox(height: Insets.xs),
          Text(
            vo2max.methodCaveat,
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          if (_reference(vo2max) case final String reference) ...[
            const SizedBox(height: Insets.md),
            Text(reference, style: text.bodySmall?.copyWith(color: colors.ink2)),
          ],
          if (vo2max.trend90d.length >= 2) ...[
            const SizedBox(height: Insets.lg),
            RevealOnce(
              id: 'vo2max-trend',
              registry: reveals,
              builder: (context, t) => HArea(
                TrendPoint.valuesOf(vo2max.trend90d),
                color: tag,
                progress: t,
                height: 56,
                digits: 1,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'The last ${vo2max.trend90d.length} days the server holds. Points '
              'may come from different instruments; they are never averaged '
              'together.',
              style: text.labelSmall?.copyWith(color: colors.ink3),
            ),
          ],
          const SizedBox(height: Insets.md),
          ReasoningNote(
            question: 'Why this instrument, and not another',
            answer: _instrumentReasoning(vo2max),
          ),
          const SizedBox(height: Insets.sm),
          CitationRow(
            noteIds: vo2max.researchNotes,
            source: vo2max.standardErrorSource,
          ),
        ],
      ),
    );
  }

  /// The instrument in the owner's own words.
  static String instrumentLabel(String method) => switch (method) {
    'gps_graded' => 'Fitted from a recorded session',
    'hr_reserve' => 'Inverted from heart-rate reserve',
    'jurca_non_exercise' => 'Non-exercise questionnaire model',
    // Unrecognised is stated, not smoothed over. A method we cannot name is a
    // method whose error we also cannot describe.
    _ => 'Instrument: $method',
  };

  /// The ± band, with WHICH kind of error it is. Never a bare number.
  static String? _band(Vo2max vo2max) {
    final error = vo2max.standardErrorMlKgMin;
    if (error == null) {
      return null;
    }
    return '± ${error.toStringAsFixed(2)}';
  }

  /// Where the owner sits against the reference group — a fact, not a target.
  static String? _reference(Vo2max vo2max) {
    final median = vo2max.medianForAge;
    if (median == null) {
      return null;
    }
    final delta = vo2max.deltaFromMedian;
    final side = delta == null
        ? ''
        : ' — ${delta.abs().toStringAsFixed(1)} '
              '${delta >= 0 ? 'above' : 'below'} it';
    return 'The median for your age and sex is '
        '${median.toStringAsFixed(1)}$side.';
  }

  static String _instrumentReasoning(Vo2max vo2max) {
    final sessions = vo2max.sessionCount;
    return 'Three instruments can produce this number and they have genuinely '
        'different error, so the best available one is used and named rather '
        'than blended with the others. A blend would land within a tenth of a '
        'single instrument and be impossible to check by looking, which is why '
        'it is forbidden structurally rather than left to care.'
        '${sessions == null ? '' : ' This estimate rests on $sessions '
              '${sessions == 1 ? 'recorded session' : 'recorded sessions'}.'}'
        '${vo2max.asOfDate == null ? '' : ' It is a claim about '
              '${vo2max.asOfDate}.'}';
  }
}
