/// A1 — the effect on the Today card wears the name of the statistic it IS.
///
/// The foot line hard-coded the letter `r`, ported from legacy and never revisited:
///
/// ```dart
/// ModuleFoot('r ${effect.toStringAsFixed(2)} · $samples days of your data')
/// ```
///
/// `effect_metric` has been on the wire since `read/findings.py` was written and is
/// parsed by `Finding.effectMetric`. The server sends `rho` for a Spearman correlation
/// and the Mann-Whitney rank-biserial statistic for an event finding — so a rank
/// correlation was drawn under the symbol for Pearson's *r*, and an event effect got the
/// same letter for a different statistic again. A number between −1 and +1 under a
/// borrowed name is a different claim from the one the analytics layer made.
///
/// `finding.dart` states the rule on the field itself: *"WHICH statistic [effectSize] is
/// — `rho`, `d`, … Without it a number between −1 and 1 could be read as three different
/// things."*
///
/// The withholding half matters as much as the labelling half, and is the same move
/// `estimate`/`method` make on the VO₂max card: when the server sends no metric name,
/// the number ships bare rather than under a guess.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/finding.dart';
import 'package:healthee/features/today/widgets/insights_section.dart';

Finding _finding({
  String? effectMetric,
  double effect = 0.72,
  int samples = 105,
}) => Finding(
  kind: 'pairwise_lag',
  metricA: 'hrv_sleep_avg',
  metricB: 'recovery_score',
  eventKind: null,
  description: 'Spearman(hrv_sleep_avg, recovery_score) = +0.72 over 105 days',
  effectSize: effect,
  effectMetric: effectMetric,
  qValue: 0.0004,
  nSamples: samples,
  lagDays: 0,
  researchNoteIds: const <String>[],
);

void main() {
  group('the effect is named by the server, never by this file', () {
    test('a Spearman rho is drawn as rho, not as r', () {
      expect(
        findingFoot(_finding(effectMetric: 'rho')),
        'rho 0.72 · 105 days of your data',
      );
    });

    test('a rank-biserial effect keeps its own name', () {
      // The event-finding statistic. It is not a correlation coefficient at all, and it
      // used to reach the screen under the same letter as one.
      expect(
        findingFoot(
          _finding(effectMetric: 'rank_biserial', effect: -0.42, samples: 57),
        ),
        'rank_biserial 0.42 · 57 days of your data',
      );
    });

    test('THE LETTER r IS NEVER SUPPLIED BY THE CLIENT', () {
      // Asserted over every metric name the analytics layer can send, plus the absent
      // case, because a hard-coded letter would satisfy any single example.
      for (final metric in <String?>['rho', 'rank_biserial', 'd', null]) {
        final foot = findingFoot(_finding(effectMetric: metric));
        expect(
          foot.startsWith('r '),
          isFalse,
          reason: 'a $metric effect is being drawn under Pearson\'s r',
        );
      }
    });

    test('an unnamed effect ships bare rather than under a guess', () {
      // Withheld, not defaulted. An older server that sends no `effect_metric` gets a
      // number with no instrument name, which is honest; the alternative is inventing
      // one, which is the defect this test exists for in the first place.
      expect(findingFoot(_finding()), '0.72 · 105 days of your data');
    });

    test('the magnitude and the window are unchanged from legacy', () {
      // The only thing that moved is the label. Two decimals, the absolute value, and
      // the day count in the same order legacy printed them.
      final foot = findingFoot(
        _finding(effectMetric: 'rho', effect: -0.618, samples: 61),
      );
      expect(foot, 'rho 0.62 · 61 days of your data');
    });

    test('a finding with no effect at all still says how many days', () {
      const bare = Finding(
        kind: 'pairwise_lag',
        metricA: 'steps_total',
        metricB: 'hrv_sleep_avg',
        eventKind: null,
        description: 'x',
        effectSize: null,
        effectMetric: null,
        qValue: null,
        nSamples: 12,
        lagDays: 0,
        researchNoteIds: <String>[],
      );

      expect(findingFoot(bare), '0.00 · 12 days of your data');
    });
  });
}
