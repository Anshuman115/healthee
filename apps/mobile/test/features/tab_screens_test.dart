/// The screens Today's cards moved to — and the proof nothing was lost.
///
/// Cutting Today from twenty sections to six modules is only honest if every
/// removed card **landed somewhere the owner can reach**. This suite is the other
/// half of `today_grid_test.dart`'s door tests: that one asserts each module opens
/// the right tab, this one asserts the card is on it, saying what it always said.
///
/// The assertions are deliberately the SAME strings the Today suite used to make.
/// A card that quietly lost its provenance sentence in the move would otherwise
/// pass a "does the screen render" test and fail nobody.
///
/// It also holds the two rules the move could have broken:
///
///   * **A WITHHELD VALUE IS STILL WITHHELD, WITH ITS REASON AND ITS REMEDY.**
///     The grid is allowed a bare hole because the screen behind it carries both.
///     If a refusal lost its reason in the move, the grid's bargain would be
///     broken on both sides at once and nothing anywhere would say why.
///
/// **Sleep moved out of this file** when it was rebuilt to v02: its order, its
/// checks, its charts and its refusals are four suites of their own under
/// `sleep_*_test.dart`, because one screen's worth of them no longer fitted here.
///
/// **Activity and Insights moved out of this file** when they were rebuilt to
/// v02 and it crossed the 400-line gate (Standards §1). Their half lives in
/// `activity_insights_screens_test.dart`, which is the same suite split by
/// screen rather than a weaker one.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/activity/activity_screen.dart';
import 'package:healthee/features/diagnostics/diagnostics_screen.dart';
import 'package:healthee/features/insights/insights_screen.dart';
import 'package:healthee/features/sleep/sleep_screen.dart';
import 'package:healthee/shared/v02/section_head.dart';

import '_today_host.dart';

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  group('Diagnostics', () {
    testWidgets('BOTH RESTING HEART RATES ARE HERE AND EACH NAMES ITS INSTRUMENT', (
      tester,
    ) async {
      // The failure the owner caught: 56.2 bpm under Baselines and 63 bpm under
      // From-the-strap, both labelled "resting heart rate", on one screen. They
      // are two instruments. Moving them apart would have hidden that; naming
      // them is what resolves it.
      await tester.pumpWidget(todayHost(store, home: DiagnosticsScreen(now: now)));
      await tester.pumpAndSettle();

      await reveal(tester, find.text('How this one is measured'));
      await tester.tap(find.text('How this one is measured').first);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('lowest 5-minute average heart rate inside your sleep'),
        findsOneWidget,
      );

      await reveal(tester, find.text('Why this differs from your resting heart rate above'));
      await tester.tap(find.text('Why this differs from your resting heart rate above'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('usually taken awake'),
        findsOneWidget,
        reason: 'the strap row must say which instrument it is',
      );
    });

    testWidgets('the baselines and the strap streams are both reachable', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store, home: DiagnosticsScreen(now: now)));
      await tester.pumpAndSettle();

      expect(find.text('Against your own baseline'), findsOneWidget);
      // The section heading and each metric strip both say 'From the strap'
      // now that headings render in sentence case, so the scroll target names
      // the widget as well as the words — v02's `SectionHead`, which is what
      // this screen's headings are drawn with now.
      await reveal(
        tester,
        find.widgetWithText(SectionHead, 'From the strap'),
      );
      expect(find.text('From the strap'), findsWidgets);
    });

    testWidgets('A WITHHELD STREAM STILL REFUSES IN ITS OWN WORDS', (tester) async {
      // The grid's bargain: a cell shows a bare hole because the screen behind
      // it carries the reason. If the reason vanished in the move, both halves
      // would be broken at once and nothing would say so.
      await tester.pumpWidget(todayHost(store, home: DiagnosticsScreen(now: now)));
      await tester.pumpAndSettle();
      // The section heading and each metric strip both say 'From the strap'
      // now that headings render in sentence case, so the scroll target names
      // the widget as well as the words — v02's `SectionHead`, which is what
      // this screen's headings are drawn with now.
      await reveal(
        tester,
        find.widgetWithText(SectionHead, 'From the strap'),
      );

      expect(find.textContaining('The strap recorded no'), findsWidgets);
    });
  });

  group('a server that cannot be reached', () {
    testWidgets('every tab collapses the derived half into ONE retryable card', (
      tester,
    ) async {
      for (final screen in <Widget>[
        const SleepScreen(),
        const ActivityScreen(),
        const InsightsScreen(),
      ]) {
        await tester.pumpWidget(
          todayHost(store, serverUnreachable: true, home: screen),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining("Couldn't reach your server"),
          findsOneWidget,
          reason: '$screen must say which half failed, once',
        );
        expect(find.text('Try again'), findsOneWidget);
      }
    });
  });
}
