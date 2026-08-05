/// The six grid tiles: what one draws, and what it draws instead of a number.
///
/// `metric_tile.dart` is legacy's `_MetricModule` and it strikes a bargain the
/// rebuild's grid did not: legacy gives these six metrics **no detail screen to
/// point at**, so a cell that said only WITHHELD would be a refusal with no
/// explanation anywhere on the device. The cell therefore carries the reason
/// itself, in the slot the chart would have used.
///
/// The three assertions that matter:
///
///   * **A WITHHELD TILE DRAWS A HOLE, ITS REASON, AND NO CHART.** A trend drawn
///     where today's reading is missing invites the eye to read the last point
///     as today — which is the number the tile just declined to show.
///   * **A zero z-score draws the tag dot, not a `+0.0` badge.** Legacy rounds
///     to one decimal before testing, so a movement it has rounded away is not
///     claimed as a movement.
///   * **A caveated value is still a value** and is shown, with its disclosure.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/today/widgets/metric_tile.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/instrument/h_delta_badge.dart';
import 'package:healthee/shared/states/value_hole.dart';

import '_today_host.dart';

const Disclosure _refused = Disclosure(
  reason: 'insufficient_nights',
  message: 'Wear the strap overnight for a few more nights.',
);

/// One tile, on its own, in the light theme.
Widget tileHost(
  Reading<double> reading, {
  double? delta,
  bool? favorable,
  List<double> spark = const [55, 57, 54],
}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Builder(
      builder: (context) => MetricTile(
        label: 'Resting HR',
        tag: context.colors.accent,
        reading: reading,
        format: (value) => value.round().toString(),
        unit: 'bpm',
        foot: 'MED 55',
        delta: delta,
        deltaFavorable: favorable,
        chart: HArea(
          spark,
          color: context.colors.accent,
          progress: 1,
          height: MetricTile.chartHeight,
        ),
      ),
    ),
  ),
);

void main() {
  group('a tile with a value', () {
    testWidgets('shows the figure, its unit, its chart and its own median', (
      tester,
    ) async {
      await tester.pumpWidget(tileHost(const Present<double>(54)));
      await tester.pumpAndSettle();

      expect(find.text('RESTING HR'), findsOneWidget);
      expect(find.text('54'), findsOneWidget);
      expect(find.text('bpm'), findsOneWidget);
      // The owner's own 30-day median, never a population figure.
      expect(find.text('MED 55'), findsOneWidget);
      expect(find.byType(HArea), findsOneWidget);
      expect(find.byType(ValueHole), findsNothing);
    });

    testWidgets('the body is legacy\'s fixed 92 px', (tester) async {
      await tester.pumpWidget(tileHost(const Present<double>(54)));
      await tester.pumpAndSettle();

      final body = find.descendant(
        of: find.byType(MetricTile),
        matching: find.byType(SizedBox),
      );
      final heights = tester
          .widgetList<SizedBox>(body)
          .map((box) => box.height)
          .toList();
      expect(heights, contains(MetricTile.bodyHeight));
      expect(heights, contains(MetricTile.chartHeight));
    });

    testWidgets('a caveated value is still a value, and its tilt is stated', (
      tester,
    ) async {
      await tester.pumpWidget(
        tileHost(const Caveated<double>(54, [_refused])),
      );
      await tester.pumpAndSettle();

      expect(find.text('54'), findsOneWidget);
      expect(find.byType(ValueHole), findsNothing);
      expect(find.textContaining('Wear the strap overnight'), findsOneWidget);
    });
  });

  group('the delta badge', () {
    testWidgets('appears for a real movement', (tester) async {
      await tester.pumpWidget(
        tileHost(const Present<double>(54), delta: -1.4, favorable: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HDeltaBadge), findsOneWidget);
      expect(find.text('-1.4'), findsOneWidget);
    });

    testWidgets('A Z THAT ROUNDS TO ZERO CLAIMS NOTHING', (tester) async {
      // Legacy's `dz != 0` after `toStringAsFixed(1)`. A reading sitting on its
      // own median has no direction, and a badge is a claim about one.
      await tester.pumpWidget(
        tileHost(const Present<double>(54), delta: 0.04),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HDeltaBadge), findsNothing);
    });
  });

  group('a tile with no value', () {
    testWidgets('A WITHHELD TILE DRAWS A HOLE AND NO CHART', (tester) async {
      await tester.pumpWidget(tileHost(const Withheld<double>(_refused)));
      await tester.pumpAndSettle();

      expect(find.byType(ValueHole), findsOneWidget);
      expect(
        find.byType(HArea),
        findsNothing,
        reason:
            'a trend under a missing value invites the last point to be read '
            'as today',
      );
      expect(find.text('54'), findsNothing);
    });

    testWidgets('IT CARRIES THE REMEDY, because nothing else on Today does', (
      tester,
    ) async {
      await tester.pumpWidget(tileHost(const Withheld<double>(_refused)));
      await tester.pumpAndSettle();

      // Same title, same position — it reads as the app being careful, not as a
      // tile that failed to load.
      expect(find.text('RESTING HR'), findsOneWidget);
      expect(find.textContaining('Wear the strap overnight'), findsOneWidget);
      // The median is still a real measurement and keeps its slot.
      expect(find.text('MED 55'), findsOneWidget);
    });

    testWidgets('an excluded value reads as a fact, not as a task', (
      tester,
    ) async {
      await tester.pumpWidget(
        tileHost(
          const Excluded<double>([
            Disclosure(
              reason: 'sri_hazard_not_transportable',
              message: 'This cannot honestly be converted into a reading.',
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ValueHole), findsOneWidget);
      expect(find.textContaining('cannot honestly be converted'), findsOneWidget);
    });
  });

  group('the six tiles on the real screen', () {
    late LocalStore store;

    setUp(() async {
      store = LocalStore.memory();
      await seedDevice(store);
    });
    tearDown(() async => store.close());

    testWidgets("carries all six of legacy's tiles, by their legacy labels", (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(420, 14000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      // Scoped to the tiles: several of these words also appear as a recovery
      // factor row or a gauge caption, which is the grid and the instruments
      // above it agreeing rather than a duplicate.
      Finder inTile(String label) => find.descendant(
        of: find.byType(MetricTile),
        matching: find.text(label),
      );
      for (final label in <String>[
        'RESTING HR',
        'HRV',
        'SLEEP',
        'RESPIRATORY RATE',
        'STEPS',
        'ENERGY · ACTIVE',
      ]) {
        expect(inTile(label), findsOneWidget, reason: '$label is a tile');
      }
    });

    testWidgets('the sleep tile reads the SERVER night the judgements came from', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(420, 14000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      // `last_sleep.duration_min` is 380 in the contract snapshot; the strap row
      // the store was seeded with is a different night. Showing the server's is
      // what keeps its sleep-health judgement from sitting beside a night it was
      // not computed from. The foot is legacy's stage split, of time ASLEEP.
      expect(find.text('6:20'), findsOneWidget);
      expect(find.text('DEEP 24% · REM 24%'), findsOneWidget);
    });

    testWidgets('renders in BOTH themes, not just the one it was built in', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(420, 14000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(todayHost(store, themeOverride: theme));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byType(MetricTile),
            matching: find.text('STEPS'),
          ),
          findsOneWidget,
        );
      }
    });
  });
}
