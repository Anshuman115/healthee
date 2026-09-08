/// The client half of `docs/BACKEND_AUDIT.md` section A.
///
/// Three of the thirteen findings were defects on THIS side of the wire, and each is the
/// same shape: the server did the honest work and the app undid it.
///
/// A3  `out_of_range_inputs` was filed under a key the honesty envelope does not read, so
///     a VO₂max computed outside its model's validated range resolved to `Present` at full
///     confidence. The server ships it as `caveats` now; this asserts the envelope turns a
///     non-empty list into a `Caveated` reading rather than a footnote.
/// A4  `measured_as_of` was on the wire and unparsed, so a card could read "as of today"
///     over a session recorded a fortnight earlier.
/// A5  the client replaced a correct withhold of `tst_min` with `night.stages.total`,
///     which for an unstaged night is zero, and the chart painted it.
/// A13 the app defaulted the weekly MVPA target to 150 and drew a confident ring against a
///     number the server never sent.
///
/// The paired mutations live in `test/mutations.sh`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/honesty/envelope.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/activity_today.dart';
import 'package:healthee/data/models/sleep_history.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/data/models/vo2max.dart';
import 'package:healthee/shared/charts/h_stacked_sleep.dart';

import '../shared/_chart_probe.dart';

/// A VO₂max block as `/api/today` sends it, with whatever the test needs changed.
Map<String, Object?> _vo2maxBlock({
  List<Object?> caveats = const <Object?>[],
  String asOfDate = '2026-07-31',
  String? measuredAsOf,
}) => <String, Object?>{
  'estimate': 43.0,
  'data_confidence': 'ok',
  'withheld': null,
  'method': 'gps_graded',
  'method_caveat': 'Measured from a recorded session.',
  'measured_as_of': measuredAsOf,
  'n_sessions': 1,
  'see_source': null,
  'see_ml_kg_min': null,
  'as_of_date': asOfDate,
  'age_years': 35,
  'sex': 'male',
  'median_for_age': 39.7,
  'delta_from_median': 3.3,
  'trend_90d': const <Object?>[],
  'inputs': const <String, Object?>{},
  'caveats': caveats,
  'research_notes': const <String>['vo2max'],
};

const Map<String, Object?> _outOfRangeFlag = <String, Object?>{
  'reason': 'vo2max_age_years_out_of_validated_range',
  'input': 'age_years',
  'value': 80,
  'validated_low': 20,
  'validated_high': 70,
  'message':
      'Jurca 2005 was validated on ages 20-70; at 80 the model is outside the range '
      'it was tested on.',
};

SleepNightSummary _night({required String date, required bool staged}) =>
    SleepNightSummary(
      date: date,
      durationMin: staged ? 420 : null,
      deepMin: staged ? 120 : null,
      lightMin: staged ? 240 : null,
      remMin: staged ? 60 : null,
      awakeMin: staged ? 20 : null,
      deviceScore: null,
    );

void main() {
  group('A3 — an out-of-range estimate reaches the envelope', () {
    test('a flagged input makes the reading Caveated, not Present', () {
      final reading = readingFrom<Vo2max>(
        _vo2maxBlock(caveats: <Object?>[_outOfRangeFlag]),
        Vo2max.maybe,
      );

      // `Present` was the shipped behaviour and it is the whole defect: the server had
      // already decided this number sits outside its model's validated range.
      expect(reading, isA<Caveated<Vo2max>>());
      final caveated = reading as Caveated<Vo2max>;
      expect(caveated.value.estimate, 43.0);
      expect(caveated.caveats, hasLength(1));
      expect(
        caveated.caveats.first.reason,
        'vo2max_age_years_out_of_validated_range',
      );
      expect(caveated.caveats.first.message, contains('Jurca 2005'));
    });

    test('an in-range estimate is still Present, so the caveat means something', () {
      expect(
        readingFrom<Vo2max>(_vo2maxBlock(), Vo2max.maybe),
        isA<Present<Vo2max>>(),
      );
    });
  });

  group('A4 — the day the estimate was MEASURED', () {
    test('a measurement older than the day it speaks for is surfaced', () {
      final vo2max = Vo2max.maybe(
        _vo2maxBlock(asOfDate: '2026-07-31', measuredAsOf: '2026-07-17'),
      );

      expect(vo2max, isNotNull);
      expect(vo2max!.measuredAsOf, '2026-07-17');
      // The panels draw `measuredEarlier`, so this getter IS the guard: it was null
      // everywhere before, because nothing parsed the field at all.
      expect(vo2max.measuredEarlier, '2026-07-17');
    });

    test('a same-day measurement adds no second date', () {
      final vo2max = Vo2max.maybe(
        _vo2maxBlock(asOfDate: '2026-07-31', measuredAsOf: '2026-07-31'),
      );

      expect(vo2max, isNotNull);
      // Printing the same date twice would be noise, and noise is how a line that
      // matters stops being read.
      expect(vo2max!.measuredEarlier, isNull);
    });

    test('a wire with no measurement date claims none', () {
      expect(Vo2max.maybe(_vo2maxBlock())!.measuredEarlier, isNull);
    });
  });

  group('A5 — an unstaged night is not a night of zero sleep', () {
    test('a night with no breakdown parses to no stage object at all', () {
      expect(StageMinutes.maybe(null), isNull);
      expect(StageMinutes.maybe(const <String, Object?>{'light': 240}), isNotNull);
    });

    test('a summary with no breakdown says so rather than summing to zero', () {
      final unstaged = _night(date: '2026-07-30', staged: false);
      expect(unstaged.hasBreakdown, isFalse);
      expect(unstaged.durationMin, isNull);

      final staged = _night(date: '2026-07-31', staged: true);
      expect(staged.hasBreakdown, isTrue);
      expect(staged.durationMin, 420);
    });

    testWidgets('the chart marks the unmeasured night instead of stacking zeros', (
      tester,
    ) async {
      final nights = <SleepNightSummary>[
        _night(date: '2026-07-30', staged: false),
        _night(date: '2026-07-31', staged: true),
      ];
      await tester.pumpWidget(
        chartHost(HStackedSleep(nights, progress: 1)),
      );
      await tester.pumpAndSettle();

      final painted = paintedBy(tester, find.byType(HStackedSleep));
      final bars = rectsOf(painted).where((rect) => rect.height > 0).toList();
      expect(bars, isNotEmpty, reason: 'a chart that painted nothing');

      // The measured night's stack is tall; the unmeasured one is the short stub, and
      // crucially it is NOT four zero-height segments — those are pixel-identical to a
      // night of literal zero sleep, which is what this used to draw.
      final tallest = bars.map((r) => r.height).reduce((a, b) => a > b ? a : b);
      final shortest = bars.map((r) => r.height).reduce((a, b) => a < b ? a : b);
      expect(shortest, lessThan(tallest));
      expect(shortest, greaterThan(0));

      // The stub is drawn in the structural grid tone, never in a stage hue: a stage
      // colour would say a stage was measured.
      final stubs = bars.where((r) => r.height == shortest);
      expect(stubs, hasLength(1));
    });

    testWidgets('a week with no measured night at all still draws its slots', (
      tester,
    ) async {
      final nights = <SleepNightSummary>[
        _night(date: '2026-07-30', staged: false),
        _night(date: '2026-07-31', staged: false),
      ];
      await tester.pumpWidget(
        chartHost(HStackedSleep(nights, progress: 1)),
      );
      await tester.pumpAndSettle();

      final painted = paintedBy(tester, find.byType(HStackedSleep));
      final bars = rectsOf(painted).where((rect) => rect.height > 0).toList();
      // Two stubs and no stack. The axis must not collapse: an unmeasured night has no
      // height to fit, so it contributes nothing to the maximum rather than a zero.
      expect(bars, hasLength(2));
    });
  });

  group('A13 — the weekly MVPA target comes from the wire or not at all', () {
    Map<String, Object?> block({Object? weekTarget = 150}) => <String, Object?>{
      'today_min': 20,
      'week_min': 75,
      'week_target': weekTarget,
      'week_moderate_min': 60,
      'week_vigorous_min': 7,
      'daily': const <Object?>[],
      'research_notes': const <String>['mvpa_minutes_mortality'],
    };

    test('no target on the wire means no ring, not a ring against 150', () {
      final mvpa = Mvpa.maybe(block(weekTarget: null));

      expect(mvpa, isNotNull);
      expect(mvpa!.weekTarget, isNull);
      // `?? 150` produced 0.5 here — a confident half-full ring against a number the
      // server never sent, with no `Reading` wrapper and no withheld path.
      expect(mvpa.weekProgress, isNull);
    });

    test('a target on the wire is used, and the ring is drawn against it', () {
      final mvpa = Mvpa.maybe(block())!;
      expect(mvpa.weekTarget, 150);
      expect(mvpa.weekProgress, closeTo(0.5, 1e-9));
    });

    test('a week missing one intensity breakdown reports no split', () {
      final mvpa = Mvpa.maybe(<String, Object?>{
        ...block(),
        'week_moderate_min': null,
        'week_vigorous_min': null,
      })!;

      expect(mvpa.weekMin, 75, reason: 'the stored total is unaffected');
      expect(mvpa.hasSplit, isFalse);
      expect(mvpa.weekModerateMin, isNull);
    });

    test('a fully measured week does report its split', () {
      final mvpa = Mvpa.maybe(block())!;
      expect(mvpa.hasSplit, isTrue);
      expect(mvpa.weekModerateMin, 60);
    });
  });
}
