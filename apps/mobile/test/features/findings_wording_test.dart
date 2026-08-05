/// The insight rewrite, tested where the honesty actually lives: the wording.
///
/// The old surface printed the server's `description_raw` — a debug string built
/// by `analytics/correlations.py` as `Spearman(a, b) = +0.72 over 105 days
/// (p=0.000)` — as the headline of the owner's home screen. The rewrite composes
/// a sentence from the structured fields the server ships beside it and puts the
/// arithmetic behind a disclosure.
///
/// **Two things must be true at once**, and only one of them is about readability:
///
///   1. the surface is a sentence, and
///   2. **it never becomes causal.** A rewrite that traded "moved together" for
///      "improves" would read better and be a lie about an n-of-1 observational
///      correlation. That is the one failure that would make this change worse
///      than what it replaced, so the causal-verb list is asserted against every
///      string the surface can produce rather than against one example.
///
/// Pure functions, tested directly. Pumping a widget to read the wording back
/// would be testing the layout — and the layout is not what could be wrong here.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/finding.dart';
import 'package:healthee/features/insights/widgets/findings_section.dart';
import 'package:healthee/shared/format/metric_names.dart';

/// The live production finding the owner saw as a log line.
const Finding _live = Finding(
  kind: 'pairwise_lag',
  metricA: 'hrv_sleep_avg',
  metricB: 'recovery_score',
  eventKind: null,
  description: 'Spearman(hrv_sleep_avg, recovery_score) = +0.72 over 105 days (p=0.000)',
  effectSize: 0.72,
  effectMetric: 'rho',
  qValue: 0.0004,
  nSamples: 105,
  lagDays: 0,
  researchNoteIds: <String>['hrv_recovery_marker'],
);

/// Verbs and connectives that assert a cause. None may appear on the surface.
const List<String> _causal = <String>[
  'caused',
  'causes',
  'because',
  'improves',
  'improved',
  'helps',
  'hurts',
  'makes',
  'leads to',
  'thanks to',
  'due to',
  'drives',
];

void main() {
  group('the headline is a sentence in the owner\'s language', () {
    test('THE RAW SPEARMAN STRING NEVER REACHES THE SURFACE', () {
      final surface = '${findingHeadline(_live)} ${findingWindow(_live)}';
      expect(surface, isNot(contains('Spearman')));
      expect(surface, isNot(contains('hrv_sleep_avg')));
      expect(surface, isNot(contains('p=')));
      expect(surface, isNot(contains('rho')));
    });

    test('it names both metrics and the direction', () {
      expect(
        findingHeadline(_live),
        'Your overnight HRV moved with your recovery',
      );
    });

    test('a negative effect moves the other way, and still not causally', () {
      const negative = Finding(
        kind: 'pairwise_lag',
        metricA: 'caffeine',
        metricB: 'sleep_health_score_4dim',
        eventKind: null,
        description: 'Caffeine ↔ sleep',
        effectSize: -0.42,
        effectMetric: 'rho',
        qValue: 0.03,
        nSamples: 24,
        lagDays: 0,
        researchNoteIds: <String>['caffeine_sleep'],
      );
      expect(
        findingHeadline(negative),
        'Your caffeine moved opposite to your sleep health',
      );
    });

    test('the window line carries the strength, the days and the lag', () {
      expect(
        findingWindow(_live),
        'Closely, across 105 days of your own history.',
      );
      const lagged = Finding(
        kind: 'pairwise_lag',
        metricA: 'mvpa_min',
        metricB: 'hrv_sleep_avg',
        eventKind: null,
        description: 'x',
        effectSize: 0.45,
        effectMetric: 'rho',
        qValue: 0.02,
        nSamples: 61,
        lagDays: 1,
        researchNoteIds: <String>[],
      );
      expect(
        findingWindow(lagged),
        'Moderately, across 61 days of your own history, strongest 1 day apart.',
      );
    });

    test('an unnamed metric keeps its id rather than being invented into prose', () {
      const unknown = Finding(
        kind: 'pairwise_lag',
        metricA: 'some_new_metric',
        metricB: 'rhr_daily',
        eventKind: null,
        description: 'x',
        effectSize: 0.5,
        effectMetric: 'rho',
        qValue: 0.01,
        nSamples: 40,
        lagDays: 0,
        researchNoteIds: <String>[],
      );
      expect(findingHeadline(unknown), contains('some_new_metric'));
      expect(hasMetricName('some_new_metric'), isFalse);
      expect(metricName('rhr_daily'), 'resting heart rate');
    });
  });

  group('NO FINDING MAY ACQUIRE CAUSAL LANGUAGE', () {
    test('not the headline, not the window line, not the disclosure', () {
      final strings = <String>[
        findingHeadline(_live),
        findingWindow(_live),
        findingStatistics(_live),
      ];
      for (final surface in strings) {
        for (final verb in _causal) {
          // The disclosure's closing sentence is allowed to USE the word in a
          // denial — "not that either one caused the other" — and that is the
          // one exception, checked by its own assertion below.
          final withoutDenial =
              surface.replaceAll('not that either one caused the other', '');
          expect(
            withoutDenial.toLowerCase(),
            isNot(contains(verb)),
            reason: '"$verb" asserts a cause; this is an observational n-of-1',
          );
        }
      }
    });

    test('THE CAVEAT SURVIVES INTO THE DISCLOSURE, not just above it', () {
      // Losing the framing to gain readability is the failure that would make
      // this worse. A reader who opens the arithmetic gets it with the numbers.
      expect(
        findingStatistics(_live),
        contains('not that either one caused the other'),
      );
      expect(findingStatistics(_live), contains('One person, one stretch of time'));
    });
  });

  group('the statistic is complete behind the disclosure', () {
    test('nothing the old surface said was dropped', () {
      final answer = findingStatistics(_live);
      expect(answer, contains('rho = 0.72'));
      expect(answer, contains('105 days'));
      expect(answer, contains('Same day'));
      expect(answer, contains('q = 0.000'));
      expect(
        answer,
        contains('correcting for the size of the search'),
        reason: 'the multiple-comparison correction is part of the claim',
      );
    });

    test('a lagged finding says which way the lag runs', () {
      const lagged = Finding(
        kind: 'pairwise_lag',
        metricA: 'steps_total',
        metricB: 'hrv_sleep_avg',
        eventKind: null,
        description: 'x',
        effectSize: 0.31,
        effectMetric: 'rho',
        qValue: 0.04,
        nSamples: 45,
        lagDays: 2,
        researchNoteIds: <String>[],
      );
      expect(
        findingStatistics(lagged),
        contains('the second value is taken 2 days after the first'),
      );
    });
  });
}
