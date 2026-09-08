/// Today's picture of the night, and Sleep's — the two are deliberately unalike.
///
/// ## What this file used to be
///
/// It was the suite for `HStageBar`, the 30 px proportion bar the rebuild put
/// in Today's sleep grid cell after the full four-lane hypnogram rendered there
/// as scattered dots. Owner-delegated decision, 2026-08-06.
///
/// The v02 redesign removed the grid entirely, and with it the site that
/// problem existed at: `h_stage_bar.dart` is unreachable from `main.dart` now,
/// so the bar and its mutations are gone. Today's picture of the night is
/// `screens-overview.js`'s seven-night stack instead — `HStackedSleep` at
/// 108 px, whose own guard ("no minutes, no bar") is mutated against this file
/// and `today_charts_test.dart`.
///
/// The claim that survives every one of those moves is the one this file now
/// carries: **no stage timeline is drawn on Today at a size nobody can read**,
/// the stages are still shown there, and the timeline itself is still on Sleep
/// at full width — because proportion answers "how did the night divide" and
/// never "when".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/sleep/sleep_screen.dart';
import 'package:healthee/features/sleep/v02/night_panels.dart';
import 'package:healthee/features/sleep/v02/sleep_reading.dart';
import 'package:healthee/features/today/v02/night_panels.dart';
import 'package:healthee/shared/charts/h_stacked_sleep.dart';
import 'package:healthee/shared/charts/v02/v02_hypnogram.dart';
import 'package:healthee/shared/metric_info/metric_info.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';

import '_today_host.dart';

void main() {
  group('on the screens', () {
    late LocalStore store;

    setUp(() async {
      store = LocalStore.memory();
      await seedDevice(store);
    });
    tearDown(() async => store.close());

    testWidgets('TODAY DRAWS NO HYPNOGRAM AT ALL, AND STILL SHOWS STAGES', (
      tester,
    ) async {
      // **This assertion has now been reversed three times, and the reason has
      // changed under it.** The rebuild put an `HStageBar` in Today's sleep grid
      // cell; the verbatim port put legacy's 30 px `HHypnogram` back; the owner
      // delegated the call on 2026-08-06 and the bar won, because four lanes in
      // 30 px reads as scattered dots.
      //
      // The v02 redesign removed the grid entirely. Today's picture of the
      // night is `screens-overview.js`'s seven-night stack — a stage chart at
      // 108 px with a legend — so the small-chart problem has no site left. The
      // claim that survives is the one that always mattered: **no stage
      // timeline is drawn on Today at a size nobody can read**, and the stages
      // are still shown.
      tester.view
        ..physicalSize = const Size(420, 14000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      expect(
        find.byType(V02Hypnogram),
        findsNothing,
        reason: 'the timeline belongs to Sleep, at full width',
      );
      await reveal(tester, find.byType(HStackedSleep));
      expect(tester.getSize(find.byType(HStackedSleep)).height, 108);
    });

    testWidgets('THE HYPNOGRAM IS STILL ON SLEEP, AT FULL WIDTH', (tester) async {
      // The timeline is what that screen is for, and this change must not have
      // cost it: proportion answers "how did the night divide", never "when".
      await tester.pumpWidget(todayHost(store, home: const SleepScreen()));
      await tester.pumpAndSettle();
      await reveal(tester, find.text(NightTimelinePanel.title));

      expect(find.byType(V02Hypnogram), findsOneWidget);
    });

    testWidgets('THE SLEEP HERO HAS NO ⓘ, AND THE EXPLAINER IS REACHABLE ANYWAY', (
      tester,
    ) async {
      // Owner-delegated decision, 2026-08-06, and v02 keeps it: the reading at
      // the top of Sleep is a naked block with no head, so there is nowhere for
      // a ⓘ to sit that would not be a head the block has never had.
      //
      // The second half is what makes that honest, and it is the half a comment
      // cannot keep true: the `sleep` explainer opens from Today's Sleep tile.
      await tester.pumpWidget(todayHost(store, home: const SleepScreen()));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(SleepReading),
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

      // By the panel's own type, not by `find.text('Sleep')` — several things
      // on Today carry that word (a summary tile, a recovery factor row) and a
      // text finder resolves to whichever of them the ListView has built.
      final tile = find.byType(SleepWeekPanel);
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
