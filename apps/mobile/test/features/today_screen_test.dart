/// Today, rendered from real stored strap rows AND the real contract snapshot.
///
/// Two sources, exercised the same way they run: the store is a genuine
/// in-memory SQLite database seeded through the writer a sync uses, and the
/// server payload is `packages/contracts/snapshots/today.json` read from the
/// repo. `now` is injected, because a suite that reads the wall clock fails once
/// a day at midnight and passes on the retry.
///
/// This half is about **what the screen draws when it has data**. The refusals,
/// the unreachable server and the never-synced phone are `today_refusals_test.dart`
/// — split when this file crossed the 400-line gate, along the seam the standards
/// doc asks for: one file per reason to change. The cards that moved off Today
/// are asserted on their new screens in `tab_screens_test.dart`; asserting them
/// here would have been asserting the screen this change exists to undo.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';

import '_today_host.dart';

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() async => store.close());

  group('measurements the strap made', () {
    setUp(() => seedDevice(store));

    testWidgets('the daily counter opens the screen, in the grid', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('9,264'));

      expect(find.text('9,264'), findsWidgets);
      // The grid cell is an index entry, so it says which of the strap's TWO
      // step numbers this is in its foot — uppercased for the legacy eyebrow
      // look, with the written case kept on the semantics label.
      expect(
        find.textContaining('SINCE-MIDNIGHT COUNTER'),
        findsOneWidget,
        reason: '#121 — the counter, never the frozen per-minute sum',
      );
    });
  });

  group('what the server made of it', () {
    setUp(() => seedDevice(store));

    testWidgets('recovery ships its per-factor breakdown, never alone', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('72'));

      expect(find.text('72'), findsOneWidget);
      // Module eyebrows render uppercase; `ModuleLabel` keeps the written case
      // on the semantics label so a screen reader does not spell them out.
      expect(find.text('WHAT IT IS MADE OF'), findsOneWidget);
      // `feedback_no_composite_score`: the components are the licence, and they
      // are beside the number rather than behind a tap.
      expect(find.text('HRV'), findsWidgets);
      expect(find.text('RESTING HR'), findsWidgets);
      // Each factor's own sub-score, from the contract snapshot.
      expect(find.text('80'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);
    });

    testWidgets('the illness flag renders its calibrated sentence verbatim', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      expect(find.text('POSSIBLE EARLY SIGNAL'), findsOneWidget);
      expect(find.textContaining('Possible early signal'), findsOneWidget);
      expect(find.textContaining('breathing rate +2.4 bpm vs your baseline'), findsOneWidget);
    });

    testWidgets('the suggested action closes the screen, as legacy does', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Suggested today'));

      expect(find.text('Suggested today'), findsOneWidget);
    });
  });

  group('what Today no longer carries', () {
    setUp(() => seedDevice(store));

    testWidgets('THE PROSE THAT BELONGS TO A CARD MOVED WITH THE CARD', (
      tester,
    ) async {
      // Roughly 500 words of reference writing used to sit on the home screen:
      // the FRIEND registry, the questionnaire's sleep translation, and why the
      // Sleep Regularity Index cannot be converted into years. Every sentence is
      // still in the app — Activity and Sleep render the cards that carry them —
      // and none of it is on the daily read.
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      // Scroll to the bottom so nothing is merely un-built.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
      await tester.pumpAndSettle();

      for (final relocated in <String>[
        'FRIEND registry',
        'Sleep regularity is not one of the levers',
        'Fitted from a recorded session',
        'Single-subject and observational',
        'Against your own baseline',
      ]) {
        expect(
          find.textContaining(relocated),
          findsNothing,
          reason: '"$relocated" is reference material, not a daily read',
        );
      }
    });
  });
}
