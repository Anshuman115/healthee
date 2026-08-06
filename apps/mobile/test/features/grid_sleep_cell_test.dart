/// The stage bar: its stages stay apart, and its widths are the real minutes.
///
/// Today's Sleep cell drew the full four-lane hypnogram at 30 px — ~7 px a lane,
/// with a 62% band inside that — so a fragmented night rendered as scattered
/// dots. The drawing was never wrong: the same chart is legible at full width on
/// Sleep, and stays there. The SIZE was wrong for it. Owner-delegated decision,
/// 2026-08-06; the argument and its provenance live at `today_tiles.dart`.
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
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/stage_colors.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/sleep/sleep_screen.dart';
import 'package:healthee/features/sleep/widgets/sleep_hero_card.dart';
import 'package:healthee/features/today/widgets/metric_tile.dart';
import 'package:healthee/shared/charts/h_hypnogram.dart';
import 'package:healthee/shared/charts/h_stage_bar.dart';
import 'package:healthee/shared/metric_info/metric_info.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';

import '_today_host.dart';

const InstrumentHues _hues = InstrumentHues.light();
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
          contains(sleepStageColor(_hues, stage)),
          reason: '$stage must be visible as itself',
        );
      }
      expect(
        fills.where((fill) => fill != _colors.line2).toSet(),
        hasLength(4),
        reason: 'four stages sharing a colour is a swatch, not a chart',
      );
    });

    testWidgets('COLOUR IS NOT THE ONLY CARRIER — the ramp, and the words', (
      tester,
    ) async {
      // This is the one stage surface with no legend beside it: 10 px in a grid
      // cell with no room for a row of keys. So two carriers do the work colour
      // cannot, and neither one moved a pixel.
      await tester.pumpWidget(_bar(_night));
      await tester.pumpAndSettle();

      // 1. The ramp. Segment order is `kSleepStages` and the stage colours are
      //    luminance-ordered, so the bar darkens left to right even in
      //    greyscale — and for a reader with red-green colour deficiency.
      final fills = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(FractionallySizedBox),
              matching: find.byType(ColoredBox),
            ),
          )
          .map((box) => box.color.computeLuminance())
          .toList();
      for (var i = 1; i < fills.length; i++) {
        expect(
          fills[i],
          lessThan(fills[i - 1]),
          reason: '${kSleepStages[i]} does not continue the ramp',
        );
      }

      // 2. The words. Each segment names its own stage, from the ONE label
      //    source every legend uses, so a screen reader gets the key the cell
      //    has no room to draw.
      final handle = tester.ensureSemantics();
      for (final stage in kSleepStages) {
        expect(
          find.bySemanticsLabel(sleepStageLabel(stage)),
          findsOneWidget,
          reason: '$stage is unnamed',
        );
      }
      handle.dispose();
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

    testWidgets("TODAY'S SLEEP TILE DRAWS THE PROPORTION BAR, NOT THE HYPNOGRAM", (
      tester,
    ) async {
      // **This assertion has now been reversed twice, and this is the settled
      // one.** The rebuild put an `HStageBar` here; the verbatim port put
      // legacy's `HHypnogram(..., height: 30)` back (`today_screen.dart:177`),
      // on the rule that a faithful port of something imperfect beats an
      // unrequested fix; and on 2026-08-06 the owner delegated the call and it
      // was decided: the bar. Four lanes in 30 px is ~7 px a lane with a 62%
      // band inside it, and on this owner's fragmented nights that reads as
      // scattered dots. A chart that reads as noise is not showing data.
      //
      // The departure is deliberate and is recorded at the site
      // (`today_tiles.dart`) so the next reader does not "restore" it.
      tester.view
        ..physicalSize = const Size(420, 2600)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.byType(HStageBar));

      expect(find.byType(HStageBar), findsOneWidget);
      expect(
        find.byType(HHypnogram),
        findsNothing,
        reason: 'the grid cell is the ONE place the hypnogram was too small',
      );
    });

    testWidgets('THE HYPNOGRAM IS STILL ON SLEEP, AT FULL WIDTH', (tester) async {
      // The timeline is what that screen is for, and this change must not have
      // cost it: proportion answers "how did the night divide", never "when".
      await tester.pumpWidget(todayHost(store, home: const SleepScreen()));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('SLEEP STAGES'));

      expect(find.byType(HHypnogram), findsOneWidget);
    });

    testWidgets('THE SLEEP HERO HAS NO ⓘ, AND THE EXPLAINER IS REACHABLE ANYWAY', (
      tester,
    ) async {
      // Owner-delegated decision, 2026-08-06: it stays removed. Legacy passed
      // `infoKey: 'sleep'` to this card and it has NEVER rendered — `HModule`
      // draws the header row only when a `label` exists and this card passes
      // none — so drawing it now would mean adding a header row the hero has
      // never had, for a door that already exists.
      //
      // The second half is what makes that honest, and it is the half a comment
      // cannot keep true: the `sleep` explainer opens from Today's Sleep tile.
      await tester.pumpWidget(todayHost(store, home: const SleepScreen()));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(SleepHeroCard),
          matching: find.byType(MetricInfoDot),
        ),
        findsNothing,
      );

      tester.view
        ..physicalSize = const Size(420, 2600)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      // By the tile's own label, not by `find.text('SLEEP')` — the readiness
      // block above it renders that exact string and is not a tile, so a text
      // finder resolves to whichever of the two the ListView has built.
      final tile = find.byWidgetPredicate(
        (widget) => widget is MetricTile && widget.label == 'Sleep',
      );
      await reveal(tester, tile);
      // `warnIfMissed: false` is this repo's convention for the ⓘ — see
      // `sheet_layering_test.dart::openInfoSheet`. The dot is a 16 px target
      // inside a card that is itself a gesture detector.
      await tester.tap(
        find.descendant(of: tile, matching: find.byType(MetricInfoDot)),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // Scoped to the sheet, for the reason this file already gives about
      // `find.text('SLEEP')` a few lines up: the explainer's title is "Sleep
      // duration" and so is a marker on the recovery ladder, so a bare text
      // finder resolves to whichever of the two the `ListView` has built — i.e.
      // to the scroll offset, which is not what this test is about.
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(kMetricInfo['sleep']!.title),
        ),
        findsOneWidget,
      );
    });
  });
}
