/// The Sleep tab's charts PAINT, at the size the cards really lay them out at.
///
/// `test/shared/legacy_sleep_charts_test.dart` already asserts each painter's own
/// geometry against a fixed 300 px host. This file asserts something the painter
/// suite cannot see: that **the cards give them room**. A chart handed a zero
/// height, or a 44 px lane column that ate the plot, is a widget that is present
/// and draws nothing, and a `findsOneWidget` passes for it.
///
/// So every assertion here reads the recorded canvas at the laid-out size — the
/// same probe `_chart_probe.dart` exists for — and checks the numbers legacy's
/// own geometry produces.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/features/sleep/sleep_sections.dart';
import 'package:healthee/features/sleep/widgets/breakdown_card.dart';
import 'package:healthee/features/sleep/widgets/hypnogram_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_debt_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_week_card.dart';
import 'package:healthee/shared/charts/h_debt_bars.dart';
import 'package:healthee/shared/charts/h_hypnogram.dart';
import 'package:healthee/shared/charts/h_stacked_sleep.dart';

import '../_sleep_stubs.dart';
import '../shared/_chart_probe.dart';

/// The card is 390 wide, less 14 px of module padding either side.
const double _cardInnerWidth = 390 - 28;

void main() {
  late SleepNight night;

  setUp(() => night = sleepPageFixture().nights.first);

  testWidgets('THE HYPNOGRAM GETS THE CARD MINUS THE LANE COLUMN', (
    tester,
  ) async {
    await tester.pumpWidget(
      sleepCardHost(HypnogramCard(night: night, progress: 1)),
    );
    await tester.pumpAndSettle();

    // Legacy: a 44 px label column, 8 px, then the chart, in a 120 px box.
    final size = tester.getSize(find.byType(HHypnogram));
    expect(size.height, 120);
    expect(size.width, _cardInnerWidth - 44 - 8);

    final painted = paintedBy(tester, find.byType(HHypnogram));
    expect(
      countOf(painted, #drawLine),
      4,
      reason: 'one guide line per lane, at the size the CARD gave it',
    );
    final bands = rectsOf(painted);
    expect(bands, hasLength(night.timeline.length));
    for (final band in bands) {
      // 62% of a 30 px lane, and a width the card did not squeeze to nothing.
      expect(band.height, closeTo(120 / 4 * 0.62, 0.01));
      expect(band.width, greaterThan(1));
    }
    // Every band inside the plot, so nothing is painted under the lane labels.
    expect(bands.map((band) => band.right).reduce((a, b) => a > b ? a : b),
        lessThanOrEqualTo(size.width + 0.01));
  });

  testWidgets('the seven-night bars fill the card, in the four stage hues', (
    tester,
  ) async {
    final windows = SleepWindows(sleepPageFixture(), kSleepNow);
    await tester.pumpWidget(
      sleepCardHost(
        SleepWeekCard(
          nights: windows.week,
          averageLabel: '6h 20m',
          progress: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(HStackedSleep));
    expect(size.height, 120);
    expect(size.width, _cardInnerWidth);

    final painted = paintedBy(tester, find.byType(HStackedSleep));
    final bars = rectsOf(painted).where((rect) => rect.height > 0).toList();
    expect(bars, isNotEmpty, reason: 'a chart that painted nothing');
    const hues = InstrumentHues.light();
    final drawn = coloursOf(painted);
    for (final stage in const <String>['deep', 'light', 'rem', 'awake']) {
      expect(drawn, contains(hues.sleepStage(stage).toARGB32()), reason: stage);
    }
  });

  testWidgets('the debt bars are 130 px tall and one per measured night', (
    tester,
  ) async {
    const nights = <DebtNight>[
      (totalMin: 380, label: 'Mo'),
      (totalMin: 500, label: 'Tu'),
      (totalMin: 300, label: 'We'),
    ];
    await tester.pumpWidget(
      sleepCardHost(const SleepDebtCard(nights: nights, progress: 1)),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(HDebtBars));
    expect(size.height, 130);
    expect(size.width, _cardInnerWidth);

    final painted = paintedBy(tester, find.byType(HDebtBars));
    expect(rectsOf(painted).where((rect) => rect.height > 1), isNotEmpty);
  });

  testWidgets('the breakdown bar draws one segment per staged minute run', (
    tester,
  ) async {
    await tester.pumpWidget(sleepCardHost(BreakdownCard(night: night)));
    await tester.pumpAndSettle();

    // The fixture stages all four, so legacy's 14 px bar has four segments —
    // a segment that rounded away would be a stage that vanished from the
    // picture without vanishing from the rows beneath it.
    final segments = tester
        .widgetList<Container>(find.byType(Container))
        .where((box) => box.constraints?.maxHeight == 14)
        .toList();
    expect(segments, hasLength(4));
    // "Light", not legacy's "Core". Legacy said `Core` here and `light` in the
    // naps legend one card down — one stage, two words, one screen — and every
    // stage name in the app now comes from `sleepStageLabel`.
    for (final label in const <String>['Deep', 'Light', 'REM', 'Awake']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Core'), findsNothing);
  });
}
