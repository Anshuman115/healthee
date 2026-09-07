/// The three v02 summary tiles on Today: their labels, their night, both themes.
///
/// ## What this file used to be
///
/// It was the suite for `metric_tile.dart` — legacy's `_MetricModule`, the
/// fixed-height cell of the pre-v02 six-metric grid. It measured the bargain
/// that widget struck: a withheld cell drew a hole AND its reason, because
/// legacy gave those six metrics no detail screen to point at; a caveated cell
/// disclosed in its foot and cost no height doing it.
///
/// The v02 redesign replaced the grid with `screens-overview.js`'s three tiles,
/// `metric_tile.dart` became unreachable from `main.dart`, and it and its
/// suite are gone. The reason-and-remedy claim did not go with them: it lives
/// on `ReadingView` and `WithheldCard`, which carry their own mutations and
/// their own suites (`today_withheld_test.dart`, `caveat_carriers_test.dart`).
///
/// What is left here is what the v02 screen itself has to be true about.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/shared/v02/summary_tile.dart';

import '_today_host.dart';

void main() {
  group('the summary tiles on the real screen', () {
    late LocalStore store;

    setUp(() async {
      store = LocalStore.memory();
      await seedDevice(store);
    });
    tearDown(() async => store.close());

    testWidgets("CARRIES THE PROTOTYPE'S THREE TILES, BY ITS OWN LABELS", (
      tester,
    ) async {
      // v02 replaces legacy's six-cell grid with `screens-overview.js`'s
      // `summaryTiles()`: recovery, sleep and movement, three across, each a
      // way into the chapter that explains it. The `expect(MetricTile,
      // findsNothing)` that used to close this test is gone because the widget
      // is — the grid cannot come back by accident when its type does not
      // exist, which is a stronger guarantee than the assertion was.
      tester.view
        ..physicalSize = const Size(420, 14000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      Finder inTile(String label) => find.descendant(
        of: find.byType(SummaryTile),
        matching: find.text(label),
      );
      for (final label in <String>['Recovery', 'Sleep', 'Movement']) {
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
      // not computed from.
      expect(
        find.descendant(
          of: find.byType(SummaryTile),
          matching: find.text('6h 20m'),
        ),
        findsOneWidget,
      );
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
            of: find.byType(SummaryTile),
            matching: find.text('Movement'),
          ),
          findsOneWidget,
        );
      }
    });
  });
}
