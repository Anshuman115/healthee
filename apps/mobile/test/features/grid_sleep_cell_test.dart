/// The grid's sleep cell draws a proportion bar, and its stages stay apart.
///
/// It drew the full four-lane hypnogram at 28 px — ~7 px a lane, with a 62% band
/// inside that — so a fragmented night rendered as scattered dots. The drawing
/// was never wrong: the same chart is legible at full width on Sleep, and stays
/// there. The SIZE was wrong for it.
///
/// What a 30 px bar can carry is proportion, and the two things that make it a
/// reading rather than a swatch are asserted here: the stages are **told apart**
/// (four colours, from the one `stage_colors.dart` table the hypnogram uses), and
/// the widths are **in proportion to the measured minutes**. A bar whose segments
/// were equal, or whose stages shared a colour, would pass a "does it render"
/// test and say nothing true about the night.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/metric_hues.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/sleep/sleep_screen.dart';
import 'package:healthee/features/today/widgets/metric_grid.dart';
import 'package:healthee/shared/charts/h_hypnogram.dart';
import 'package:healthee/shared/charts/h_stage_bar.dart';

import '_today_host.dart';

const MetricHues _hues = MetricHues.light();
const HealtheeColors _colors = HealtheeColors.light();

/// One night, deliberately lopsided, so equal widths cannot pass as proportional.
const Map<String, int> _night = <String, int>{
  'deep': 60,
  'light': 240,
  'rem': 80,
  'awake': 20,
};

Widget _bar(Map<String, int> minutes, {double progress = 1}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 160,
        child: HStageBar(minutes, progress: progress),
      ),
    ),
  ),
);

List<Expanded> _segments(WidgetTester tester) => tester
    .widgetList<Expanded>(
      find.descendant(of: find.byType(HStageBar), matching: find.byType(Expanded)),
    )
    .toList();

void main() {
  group('the bar itself', () {
    testWidgets('THE FOUR STAGES ARE FOUR DISTINGUISHABLE COLOURS', (tester) async {
      await tester.pumpWidget(_bar(_night));
      await tester.pumpAndSettle();

      final fills = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(HStageBar),
              matching: find.byType(ColoredBox),
            ),
          )
          .map((box) => box.color)
          .toSet();
      for (final stage in kSleepStages) {
        expect(
          fills,
          contains(sleepStageColor(_colors, _hues, stage)),
          reason: '$stage must be visible as itself',
        );
      }
      expect(
        fills.where((fill) => fill != _colors.line2).toSet(),
        hasLength(4),
        reason: 'four stages sharing a colour is a swatch, not a chart',
      );
    });

    testWidgets('WIDTHS ARE IN PROPORTION TO THE MEASURED MINUTES', (tester) async {
      await tester.pumpWidget(_bar(_night));
      await tester.pumpAndSettle();

      expect(
        _segments(tester).map((segment) => segment.flex),
        <int>[60, 240, 80, 20],
        reason: 'deep → light → REM → awake, at their measured minutes',
      );
    });

    testWidgets('AND THEY ARE ACTUALLY PAINTED, AT THE BAR’S FULL HEIGHT', (
      tester,
    ) async {
      // The check the flex assertion above cannot make, and the one a real
      // render caught: every segment was in the tree with the right flex and
      // ZERO HEIGHT, because a childless `ColoredBox` under a loose `Stack`
      // takes `constraints.smallest`. The bar drew as an empty grey track.
      await tester.pumpWidget(_bar(_night));
      await tester.pumpAndSettle();

      final painted = find.descendant(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(ColoredBox),
      );
      expect(painted, findsNWidgets(4));
      var widest = 0.0;
      for (var i = 0; i < 4; i++) {
        final size = tester.getSize(painted.at(i));
        expect(size.height, 10, reason: 'segment $i collapsed');
        expect(size.width, greaterThan(0), reason: 'segment $i has no width');
        widest = size.width > widest ? size.width : widest;
      }
      // Light sleep is 240 of 400 minutes, so it must be the widest by far.
      expect(tester.getSize(painted.at(1)).width, widest);
    });

    testWidgets('a stage with no minutes takes no width, and none is invented', (
      tester,
    ) async {
      await tester.pumpWidget(_bar(const <String, int>{'deep': 30, 'light': 90}));
      await tester.pumpAndSettle();

      expect(_segments(tester).map((segment) => segment.flex), <int>[30, 90]);
    });

    testWidgets('the reveal fills the bar without moving the proportions', (
      tester,
    ) async {
      await tester.pumpWidget(_bar(_night, progress: 0.5));
      await tester.pumpAndSettle();

      expect(_segments(tester).map((segment) => segment.flex), <int>[60, 240, 80, 20]);
      expect(
        tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor,
        0.5,
      );
    });

    testWidgets('a night with no staged minutes draws nothing at all', (
      tester,
    ) async {
      await tester.pumpWidget(_bar(const <String, int>{}));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(HStageBar),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
        reason: 'not even an empty track — a bar of nothing is not a reading',
      );
    });
  });

  group('on the screens', () {
    late LocalStore store;

    setUp(() async {
      store = LocalStore.memory();
      await seedDevice(store);
    });
    tearDown(() async => store.close());

    testWidgets('the GRID cell draws the bar and not the hypnogram', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(420, 1400)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(MetricGrid),
          matching: find.byType(HStageBar),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(MetricGrid),
          matching: find.byType(HHypnogram),
        ),
        findsNothing,
        reason: 'four lanes in 28 px read as scattered dots on real data',
      );
    });

    testWidgets('THE HYPNOGRAM IS STILL ON SLEEP, AT FULL WIDTH', (tester) async {
      // The timeline is what that screen is for, and this change must not have
      // cost it: proportion answers "how did the night divide", never "when".
      await tester.pumpWidget(todayHost(store, home: const SleepScreen()));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Last night'));

      expect(find.byType(HHypnogram), findsOneWidget);
    });
  });
}
