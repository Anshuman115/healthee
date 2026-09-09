/// The stage charts PAINT, at the size the panels really lay them out at.
///
/// Split out of `sleep_charts_test.dart` at the 400-line gate (Standards
/// section 1): that file keeps the timeline and the timing chart, this one the
/// three charts that are about how much was slept rather than when.
///
/// The claim throughout is the recorded canvas at the laid-out size, never
/// `findsOneWidget` — two charts on this screen once shipped at zero height
/// because a suite only checked the widget existed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/features/sleep/sleep_windows.dart';
import 'package:healthee/features/sleep/v02/need_panel.dart';
import 'package:healthee/features/sleep/v02/night_panels.dart';
import 'package:healthee/features/sleep/v02/week_panel.dart';
import 'package:healthee/shared/charts/h_debt_bars.dart';
import 'package:healthee/shared/charts/h_stacked_sleep.dart';
import 'package:healthee/shared/charts/v02/chart_void.dart';
import 'package:healthee/shared/charts/v02/v02_stage_strip.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/panel.dart';

import '../_sleep_stubs.dart';
import '../shared/_chart_probe.dart';
import '_sleep_host.dart';

/// A 390 px panel, less 18 px of `Panel` padding and one hairline either side.
const double _panelInnerWidth = 390 - 2 * Panel.padding - 2 * hairline;

const InstrumentHues _hues = InstrumentHues.light();

void main() {
  late SleepNight night;
  late SleepWindows windows;

  setUpAll(loadSleepFont);
  setUp(() {
    final page = sleepPageFixture();
    night = page.nights.first;
    windows = SleepWindows(page, kSleepNow);
  });

  group('the stage proportion strip', () {
    testWidgets('ONE SEGMENT PER STAGE, EACH IN ITS OWN HUE', (tester) async {
      await tester.pumpWidget(
        sleepPanelHost(
          StageTablePanel(night: night, reveals: RevealRegistry()),
        ),
      );
      await tester.pumpAndSettle();

      final strip = tester.getSize(find.byType(V02StageStrip));
      expect(strip.height, 24);
      expect(strip.width, _panelInnerWidth);

      // The fixture stages all four, so all four are on the strip. A stage that
      // rounded away would have vanished from the picture without vanishing
      // from the rows beneath it.
      final boxes = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(V02StageStrip),
              matching: find.byType(DecoratedBox),
            ),
          )
          .toList();
      expect(boxes, hasLength(4));
      final drawn = <int>{
        for (final box in boxes)
          ((box.decoration as BoxDecoration).color!).toARGB32(),
      };
      for (final stage in const <String>['deep', 'light', 'rem', 'awake']) {
        expect(
          drawn,
          contains(_hues.sleepStage(stage).toARGB32()),
          reason: stage,
        );
      }
      expect(drawn, hasLength(4), reason: 'two stages sharing a hue');
    });

    testWidgets('a night with no stage totals draws no strip at all', (
      tester,
    ) async {
      final page = sleepPageWithout(<String>['stages']);
      await tester.pumpWidget(
        sleepPanelHost(
          StageTablePanel(night: page.nights.first, reveals: RevealRegistry()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(V02StageStrip), findsNothing);
      expect(find.text(kNoStagesNote), findsOneWidget);
    });
  });

  group('the stacked week', () {
    testWidgets('it fills the panel, in the four stage hues', (tester) async {
      await tester.pumpWidget(
        sleepPanelHost(
          StageWeekPanel(
            nights: windows.week,
            span: windows.weekSpan,
            reveals: RevealRegistry(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(HStackedSleep));
      expect(size.height, StageWeekPanel.chartHeight);
      expect(size.width, _panelInnerWidth);

      final painted = paintedBy(tester, find.byType(HStackedSleep));
      final bars = rectsOf(painted).where((rect) => rect.height > 0).toList();
      expect(bars, isNotEmpty, reason: 'a chart that painted nothing');
      final drawn = coloursOf(painted);
      for (final stage in const <String>['deep', 'light', 'rem', 'awake']) {
        expect(
          drawn,
          contains(_hues.sleepStage(stage).toARGB32()),
          reason: stage,
        );
      }
    });
  });

  group('the need-versus-actual chart', () {
    testWidgets('IT FILLS THE PANEL AND DRAWS A BAR PER MEASURED NIGHT', (
      tester,
    ) async {
      await tester.pumpWidget(
        sleepPanelHost(
          SleepNeedPanel(
            night: night,
            nights: windows.debt,
            needMin: kSleepNeedFixture,
            reveals: RevealRegistry(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(HDebtBars));
      expect(size.height, SleepNeedPanel.chartHeight);
      expect(size.width, _panelInnerWidth);

      final painted = paintedBy(tester, find.byType(HDebtBars));
      final bars = rectsOf(painted).where((rect) => rect.height > 1).toList();
      expect(bars.length, greaterThanOrEqualTo(windows.debt.length));
    });

    testWidgets('one night draws no chart and keeps its slot', (tester) async {
      await tester.pumpWidget(
        sleepPanelHost(
          SleepNeedPanel(
            night: night,
            nights: <DebtNight>[windows.debt.first],
            needMin: kSleepNeedFixture,
            reveals: RevealRegistry(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HDebtBars), findsNothing);
      expect(find.textContaining('1 measured night'), findsOneWidget);
    });
  });

  group('the strip itself, asked directly', () {
    testWidgets('A STAGE WITH NO MINUTES IS ABSENT, NOT A SLIVER', (
      tester,
    ) async {
      // The panel above never reaches this: it draws a note instead of a strip
      // when NOTHING was staged, so the strip's own filter is only exercised
      // when SOME stage is zero. A one-pixel segment for a stage the owner
      // never entered is a picture of sleep that did not happen.
      await tester.pumpWidget(
        sleepPanelHost(
          const V02StageStrip(<String, double>{
            'deep': 60,
            'light': 200,
            'rem': 0,
            'awake': 20,
          }, progress: 1),
        ),
      );
      await tester.pumpAndSettle();

      final boxes = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(V02StageStrip),
              matching: find.byType(DecoratedBox),
            ),
          )
          .toList();
      expect(boxes, hasLength(3), reason: 'REM has no minutes on this night');
      final drawn = <int>{
        for (final box in boxes)
          ((box.decoration as BoxDecoration).color!).toARGB32(),
      };
      expect(drawn, isNot(contains(_hues.sleepStage('rem').toARGB32())));
    });

    testWidgets('a night with nothing staged draws no segment at all', (
      tester,
    ) async {
      await tester.pumpWidget(
        sleepPanelHost(
          const V02StageStrip(<String, double>{
            'deep': 0,
            'light': 0,
            'rem': 0,
            'awake': 0,
          }, progress: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(V02StageStrip),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
      // And the slot is kept, so a staged night and an unstaged one lay out at
      // the same height.
      expect(tester.getSize(find.byType(ChartVoid)).height, 24);
    });
  });
}
