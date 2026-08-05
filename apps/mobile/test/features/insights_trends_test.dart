/// Where `fav`/`unf` may appear on Insights, and — the part that matters —
/// where they may not.
///
/// The owner asked for improving and degrading to be visible in colour. It is a
/// good ask and it does not apply uniformly, so the screen splits it:
///
/// ```text
///   a trend, polarity known    coloured      the metric moved against the owner's own past
///   a trend, polarity neutral  NO COLOUR     burning more calories is not better
///   a trend, metric unknown    NO COLOUR     unknown is unknown, never a default verdict
///   a finding, any state       NO COLOUR     a correlation's sign is a direction, not a verdict
/// ```
///
/// **The colourless cases are what this file is really about.** A screen that
/// tinted everything would teach the owner that colour here is decoration, and
/// then the two rows where it is a claim would say nothing — so the neutral case
/// is mutation-tested rather than merely asserted, and the finding case is
/// enumerated over every kind of finding the payload can carry.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/finding.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/insights/insights_screen.dart';
import 'package:healthee/features/insights/widgets/findings_section.dart';
import 'package:healthee/features/insights/widgets/trends_section.dart';
import 'package:healthee/shared/format/metric_polarity.dart';
import 'package:healthee/shared/reveal_once.dart';

import '../_today_stubs.dart';
import '_today_host.dart';

/// A two-point series that moves by [delta].
List<TrendPoint> _series(double from, double delta) => <TrendPoint>[
  TrendPoint(date: '2026-08-01', value: from),
  TrendPoint(date: '2026-08-14', value: from + delta),
];

MetricTrend _trend(String metric, double delta) =>
    MetricTrend.from(metric, _series(50, delta))!;

/// Every colour the widget under [finder] actually paints text in.
Set<Color> _textColours(WidgetTester tester, Finder finder) {
  return tester
      .widgetList<Text>(find.descendant(of: finder, matching: find.byType(Text)))
      .map((text) => text.style?.color)
      .whereType<Color>()
      .toSet();
}

Widget _row(MetricTrend trend) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: TrendRow(trend: trend, reveals: RevealRegistry()),
  ),
);

/// The verdict colours, read from the same theme the widget is rendered in.
({Color fav, Color unf}) _verdicts() {
  final colors = AppTheme.light.extension<HealtheeColors>()!;
  return (fav: colors.fav, unf: colors.unf);
}

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  group('the polarity table', () {
    test('legacy\'s six polarities, ported verbatim', () {
      expect(polarityOf('hrv_sleep_avg'), MetricPolarity.higherIsBetter);
      expect(polarityOf('rhr_daily'), MetricPolarity.lowerIsBetter);
      expect(polarityOf('sleep_regularity_index'), MetricPolarity.higherIsBetter);
      expect(polarityOf('sleep_score'), MetricPolarity.higherIsBetter);
      expect(polarityOf('sleep_health_score_4dim'), MetricPolarity.higherIsBetter);
      expect(polarityOf('total_calories'), MetricPolarity.neutral);
    });

    test('an unknown metric has NO polarity, and null is not neutral', () {
      // Two different facts: one is a gap somebody should close, the other is a
      // decision. They agree on the answer and must not be conflated in the code.
      expect(polarityOf('vo2max_estimate'), isNull);
      expect(polarityOf('total_calories'), isNot(isNull));
    });

    test('a +1 metric is favourable UP and unfavourable DOWN', () {
      expect(verdictFor('hrv_sleep_avg', 3.2), TrendVerdict.favourable);
      expect(verdictFor('hrv_sleep_avg', -3.2), TrendVerdict.unfavourable);
    });

    test('a -1 metric is the reverse', () {
      // Resting heart rate falling is the good news, and this is the assertion
      // that a sign-only implementation would get exactly backwards.
      expect(verdictFor('rhr_daily', -4), TrendVerdict.favourable);
      expect(verdictFor('rhr_daily', 4), TrendVerdict.unfavourable);
    });

    test('a NEUTRAL metric has no verdict in either direction', () {
      expect(verdictFor('total_calories', 400), TrendVerdict.none);
      expect(verdictFor('total_calories', -400), TrendVerdict.none);
    });

    test('an unknown metric has no verdict in either direction', () {
      expect(verdictFor('weight_kg', 2), TrendVerdict.none);
      expect(verdictFor('weight_kg', -2), TrendVerdict.none);
    });

    test('a window that did not move is not an improvement', () {
      expect(verdictFor('hrv_sleep_avg', 0), TrendVerdict.none);
    });

    test('one point is a reading, not a trend', () {
      expect(MetricTrend.from('hrv_sleep_avg', const []), isNull);
      expect(
        MetricTrend.from('hrv_sleep_avg', [
          const TrendPoint(date: '2026-08-01', value: 47),
        ]),
        isNull,
      );
    });
  });

  group('a trend row spends colour only where it has a claim', () {
    testWidgets('a polarity -1 metric RISING renders unf', (tester) async {
      await tester.pumpWidget(_row(_trend('rhr_daily', 4)));
      await tester.pumpAndSettle();

      expect(_textColours(tester, find.byType(TrendRow)), contains(_verdicts().unf));
    });

    testWidgets('a polarity -1 metric FALLING renders fav', (tester) async {
      await tester.pumpWidget(_row(_trend('rhr_daily', -4)));
      await tester.pumpAndSettle();

      expect(_textColours(tester, find.byType(TrendRow)), contains(_verdicts().fav));
    });

    testWidgets('a polarity +1 metric rising renders fav, falling unf', (
      tester,
    ) async {
      await tester.pumpWidget(_row(_trend('hrv_sleep_avg', 4)));
      await tester.pumpAndSettle();
      expect(_textColours(tester, find.byType(TrendRow)), contains(_verdicts().fav));

      await tester.pumpWidget(_row(_trend('hrv_sleep_avg', -4)));
      await tester.pumpAndSettle();
      expect(_textColours(tester, find.byType(TrendRow)), contains(_verdicts().unf));
    });

    testWidgets('MUTATION: A POLARITY-0 METRIC RENDERS NO VERDICT COLOUR', (
      tester,
    ) async {
      // The load-bearing case. Calories are in the table at `neutral` on
      // purpose: burning more is not better and burning less is not worse.
      // Colouring this row would teach the owner that every colour on the screen
      // is a judgement, after which the ones that are stop meaning anything.
      //
      // Asserted in BOTH directions, because a sign-only implementation passes
      // one of them by accident.
      for (final delta in <double>[400, -400]) {
        await tester.pumpWidget(_row(_trend('total_calories', delta)));
        await tester.pumpAndSettle();

        final drawn = _textColours(tester, find.byType(TrendRow));
        expect(
          drawn,
          isNot(contains(_verdicts().fav)),
          reason: 'a $delta calorie change is not good news',
        );
        expect(
          drawn,
          isNot(contains(_verdicts().unf)),
          reason: 'and it is not bad news either',
        );
      }
    });

    testWidgets('a metric ABSENT from the table renders no verdict colour', (
      tester,
    ) async {
      // Unknown is unknown. Defaulting it to a neutral-looking green, or
      // inferring a direction from the sign, would be inventing a claim.
      await tester.pumpWidget(_row(_trend('weight_kg', 3)));
      await tester.pumpAndSettle();

      final drawn = _textColours(tester, find.byType(TrendRow));
      expect(drawn, isNot(contains(_verdicts().fav)));
      expect(drawn, isNot(contains(_verdicts().unf)));
    });
  });

  group('NO FINDING RENDERS A VERDICT COLOUR, IN ANY STATE', () {
    // Enumerated over every kind of finding the payload can carry, and over both
    // signs of the coefficient, because the sign is exactly what a well-meaning
    // change would reach for. `q`-corrected or not, 105 days of one person's
    // history cannot support "this is good for you".
    final kinds = <String, Finding>{
      'a positive pairwise correlation': Finding.fromJson(const {
        'kind': 'pairwise_lag',
        'metric_a': 'hrv_sleep_avg',
        'metric_b': 'recovery_score',
        'effect_size': 0.72,
        'effect_metric': 'spearman_r',
        'q_value': 0.0001,
        'n_samples': 105,
        'lag_days': 0,
      }),
      'a negative pairwise correlation': Finding.fromJson(const {
        'kind': 'pairwise_lag',
        'metric_a': 'caffeine',
        'metric_b': 'sleep_health_score_4dim',
        'effect_size': -0.42,
        'effect_metric': 'rho',
        'q_value': 0.03,
        'n_samples': 24,
        'lag_days': 0,
      }),
      'an event finding': Finding.fromJson(const {
        'kind': 'event_contrast',
        'metric_a': 'rhr_daily',
        'event_kind': 'alcohol',
        'effect_size': 0.51,
        'n_samples': 30,
      }),
      'a finding with no effect size at all': Finding.fromJson(const {
        'kind': 'pairwise_lag',
        'metric_a': 'steps_total',
        'metric_b': 'sleep_score',
        'n_samples': 40,
      }),
    };

    for (final entry in kinds.entries) {
      testWidgets('${entry.key} spends no fav and no unf', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: FindingsSection(findings: <Finding>[entry.value]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final drawn = _textColours(tester, find.byType(FindingsSection));
        expect(drawn, isNot(contains(_verdicts().fav)), reason: entry.key);
        expect(drawn, isNot(contains(_verdicts().unf)), reason: entry.key);
      });
    }
  });

  group('the screen', () {
    testWidgets('draws a trend for each tracked metric the payload carries', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store, home: const InsightsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Trends'.toUpperCase()), findsOneWidget);
      expect(find.text('Overnight HRV'), findsOneWidget);
      expect(find.text('Resting heart rate'), findsOneWidget);
      expect(find.text('Total calories'), findsOneWidget);
    });

    test('the screen reads ONE list, not a second copy of the table', () {
      // A metric the screen drew that the table cannot judge would be a
      // colourless row nobody chose, and the mismatch would be invisible.
      for (final metric in kTrendMetrics) {
        expect(
          polarityOf(metric),
          isNotNull,
          reason: '$metric is offered as a trend with no polarity behind it',
        );
      }
    });

    testWidgets('no trend windows at all is an honest empty state', (
      tester,
    ) async {
      await tester.pumpWidget(
        todayHost(
          store,
          home: const InsightsScreen(),
          server: todayView(
            mutate: (Map<String, Object?> json) {
              final stripped = Map<String, Object?>.from(json);
              stripped['sparklines'] = const <String, Object?>{};
              return stripped;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No trend windows yet'), findsOneWidget);
    });

    test('trendsOf drops a metric with fewer than two points', () {
      final trends = trendsOf(<String, List<TrendPoint>>{
        'hrv_sleep_avg': [const TrendPoint(date: '2026-08-01', value: 47)],
        'rhr_daily': _series(55, -2),
      });

      expect(trends.map((trend) => trend.metric), <String>['rhr_daily']);
    });
  });
}
