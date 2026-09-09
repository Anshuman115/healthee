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
import 'package:healthee/features/sleep/v02/stage_shares.dart';
import 'package:healthee/features/sleep/v02/week_panel.dart';
import 'package:healthee/shared/charts/h_debt_bars.dart';
import 'package:healthee/shared/charts/h_stacked_sleep.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/panel.dart';

import '../_sleep_stubs.dart';
import '../shared/_chart_probe.dart';
import '../shared/_decoration.dart';
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

  group('the stage shares', () {
    testWidgets('ONE BAR PER STAGE, EACH IN ITS OWN HUE', (tester) async {
      await tester.pumpWidget(
        sleepPanelHost(
          StageTablePanel(night: night, reveals: RevealRegistry()),
        ),
      );
      await tester.pumpAndSettle();

      // **The stacked strip is gone**, and the table under it with it: the
      // panel drew the same four proportions twice, once as a strip nobody
      // could read a number off. Each stage is one bar now, as long as its
      // share, with its percentage set inside the fill.
      expect(tester.getSize(find.byType(StageShares)).width, _panelInnerWidth);

      // The fixture stages all four, so all four are drawn. A stage that
      // rounded away would have vanished from the picture without vanishing
      // from the readings beside it.
      final boxes = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(StageShares),
              matching: find.byType(DecoratedBox),
            ),
          )
          .toList();
      expect(boxes, hasLength(4));
      final drawn = <int>{
        for (final box in boxes) (groundOf(box.decoration)!).toARGB32(),
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

    testWidgets('a night with no stage totals draws no bars at all', (
      tester,
    ) async {
      final page = sleepPageWithout(<String>['stages']);
      await tester.pumpWidget(
        sleepPanelHost(
          StageTablePanel(night: page.nights.first, reveals: RevealRegistry()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StageShares), findsNothing);
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

  group('the shares, asked directly', () {
    testWidgets('A STAGE WITH NO MINUTES IS SAID TO BE ZERO, NOT OMITTED', (
      tester,
    ) async {
      // **This is the reverse of what the stacked strip did**, and deliberately
      // so. A strip drew a segment per stage, so a stage with no minutes had to
      // be filtered out — a one-pixel sliver was a picture of sleep that did
      // not happen. These are rows, and a row that says `REM · 0%` is a reading
      // rather than a mark: the stage the owner never entered is now stated
      // instead of silently missing from a picture of four.
      await tester.pumpWidget(
        sleepPanelHost(
          const StageShares(
            minutes: <String, double>{
              'deep': 60,
              'light': 200,
              'rem': 0,
              'awake': 20,
            },
            total: 280,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final stage in const <String>['Deep', 'Light', 'REM', 'Awake']) {
        expect(find.text(stage), findsOneWidget, reason: stage);
      }
      expect(find.text('0%'), findsOneWidget, reason: 'REM ran for no minutes');

      // And its bar is the shortest on the panel: the fill encodes the share,
      // so the stage with none of the night must not be as long as one with
      // most of it.
      double barWidth(String stage) => tester
          .getSize(
            find
                .descendant(
                  of: find.byType(StageShares),
                  matching: find.byType(DecoratedBox),
                )
                .at(kShareOrder.indexOf(stage)),
          )
          .width;
      expect(barWidth('rem'), lessThan(barWidth('awake')));
      expect(barWidth('awake'), lessThan(barWidth('light')));
    });

    testWidgets('a night with nothing staged never reaches the bars', (
      tester,
    ) async {
      // `StageShares` takes its shares against a total its callers guarantee is
      // above zero, and this is the guarantee: the panel draws the note instead
      // of dividing a night by nothing.
      await tester.pumpWidget(
        sleepPanelHost(
          StageTablePanel(
            night: sleepPageWithout(<String>['stages']).nights.first,
            reveals: RevealRegistry(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StageShares), findsNothing);
      expect(find.text(kNoStagesNote), findsOneWidget);
    });
  });
}
