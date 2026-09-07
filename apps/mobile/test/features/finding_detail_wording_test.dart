/// The finding-detail screen says what the statistic says, and no more.
///
/// This screen exists to hold the one claim the product is most likely to
/// over-state: a correlation found by searching many metric pairs across one
/// person's history. The wording is the deliverable, so it is asserted here
/// directly rather than through a pumped widget, which would test the layout.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/finding.dart';
import 'package:healthee/features/insights/v02/finding_detail_parts.dart';
import 'package:healthee/features/insights/v02/finding_detail_screen.dart';

/// The owner's live payload, as it came off `/api/today`.
const Finding _live = Finding(
  kind: 'pairwise_lag',
  metricA: 'hrv_sleep_avg',
  metricB: 'recovery_score',
  eventKind: null,
  description: 'Spearman(hrv_sleep_avg, recovery_score) = +0.78',
  effectSize: 0.7794,
  effectMetric: 'spearman_r',
  // The real one. Three decimals would render this as an exact zero.
  qValue: 3.15e-27,
  nSamples: 138,
  lagDays: 0,
  researchNoteIds: <String>['alcohol_sleep', 'slow_breathing_hrv_acute'],
);

const Finding _negative = Finding(
  kind: 'pairwise_lag',
  metricA: 'caffeine_mg',
  metricB: 'sleep_efficiency',
  eventKind: null,
  description: '',
  effectSize: -0.42,
  effectMetric: 'spearman_r',
  qValue: 0.03,
  nSamples: 24,
  lagDays: 2,
  researchNoteIds: <String>['caffeine_sleep'],
);

/// Verbs that assert a cause. None may appear anywhere on this screen.
const List<String> _causal = <String>[
  'caused',
  'causes',
  'because',
  'improves',
  'improved',
  'helps',
  'helped',
  'hurts',
  'leads to',
  'results in',
  'due to',
  'thanks to',
  'drives',
];

void main() {
  group('the observation', () {
    test('NEVER DROPS THE SECOND LINE, whichever way the pair moved', () {
      for (final finding in <Finding>[_live, _negative]) {
        expect(observationHeadline(finding), contains('That doesn’t tell us why.'));
      }
    });

    test('agrees with the card that led here about the direction', () {
      // The relationship card says "moved with" / "moved opposite to". A detail
      // screen that contradicted its own entry point would be worse than either
      // wording on its own.
      expect(observationHeadline(_live), startsWith('They moved together.'));
      expect(
        observationHeadline(_negative),
        startsWith('They moved in opposite directions.'),
      );
    });

    test('names the association without naming a mechanism', () {
      final body = observationBody(_negative);
      expect(body, contains('negatively'));
      expect(body, contains('associated with'));
      expect(body, contains('could be part of the picture'));
    });

    test('NO CAUSAL VERB APPEARS ANYWHERE ON THE SCREEN', () {
      for (final finding in <Finding>[_live, _negative]) {
        final surface = <String>[
          findingTitle(finding),
          observationalBadge(finding),
          observationHeadline(finding),
          observationBody(finding),
          effectLabel(finding),
          correctionLine(finding),
          kPairedValuesAbsent,
        ].join(' ').toLowerCase();
        for (final verb in _causal) {
          expect(
            surface,
            isNot(contains(verb)),
            reason: '"$verb" claims a cause this screen cannot support',
          );
        }
      }
    });
  });

  group('the arithmetic', () {
    test('A VANISHINGLY SMALL Q IS AN INEQUALITY, NEVER A ROUNDED ZERO', () {
      // The live q is 3.15e-27. `toStringAsFixed(3)` makes that "0.000", which
      // reads as an exact zero — the one number on the card that would be false.
      expect(qValueLabel(_live.qValue), 'Adjusted q-value < 0.001');
      expect(qValueLabel(_live.qValue), isNot(contains('0.000')));
    });

    test('a q it can show, it shows', () {
      expect(qValueLabel(0.03), 'Adjusted q-value 0.030');
    });

    test('the coefficient carries a real minus sign, not a hyphen', () {
      expect(effectValue(_negative), '−0.42');
      expect(effectValue(_negative), isNot(contains('-')));
      expect(effectValue(_live), '+0.78');
    });

    test('the lag is spelled out, and zero is named as same-day', () {
      expect(lagLabel(0), 'same-day association');
      expect(lagLabel(null), 'same-day association');
      expect(lagLabel(1), 'strongest 1 day apart');
      expect(lagLabel(2), 'strongest 2 days apart');
    });

    test('rho keeps its symbol; an unknown effect metric does not borrow it', () {
      expect(effectLabel(_live), 'Correlation · ρ');
      expect(
        effectLabel(
          const Finding(
            kind: 'x',
            metricA: 'a',
            metricB: 'b',
            eventKind: null,
            description: '',
            effectSize: 0.1,
            effectMetric: 'cliffs_delta',
            qValue: null,
            nSamples: null,
            lagDays: null,
            researchNoteIds: <String>[],
          ),
        ),
        'Effect · cliffs_delta',
      );
    });

    test('the missing scatter plot is stated, not faked', () {
      expect(kPairedValuesAbsent, contains('not the underlying paired values'));
    });
  });

  group('the route key', () {
    test('round-trips the pair and the lag', () {
      expect(findingKey(_negative), 'caffeine_mg~sleep_efficiency~2');
      expect(findingKey(_live), 'hrv_sleep_avg~recovery_score~0');
    });

    test('DISTINGUISHES TWO LAGS OF THE SAME PAIR', () {
      // The server can report the same two metrics at more than one lag. A key
      // that collapsed them would open the wrong finding.
      expect(findingKey(_negative), isNot(findingKey(_live)));
      const sameLagZero = Finding(
        kind: 'pairwise_lag',
        metricA: 'caffeine_mg',
        metricB: 'sleep_efficiency',
        eventKind: null,
        description: '',
        effectSize: -0.2,
        effectMetric: 'spearman_r',
        qValue: 0.04,
        nSamples: 20,
        lagDays: 0,
        researchNoteIds: <String>[],
      );
      expect(findingKey(sameLagZero), isNot(findingKey(_negative)));
    });
  });
}
