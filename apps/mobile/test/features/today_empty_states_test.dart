/// What each section does when it has nothing to say.
///
/// Brief §1: *"'no number' is a first-class screen state with as much care as
/// the happy path. If you design 20 beautiful cards and one sad empty state, you
/// have designed the wrong app."*
///
/// There are two right answers and the difference matters:
///
/// ```text
///   silence    a section with nothing to REPORT draws nothing at all
///   a refusal  a metric that could have had a value draws the hole and the why
/// ```
///
/// Data health, findings, the action card and the charts take the first: an
/// empty "Insights" heading over a blank card reads as breakage, and the honest
/// state is to not be there. Every metric block takes the second, because for
/// those the absence IS the news.
///
/// Each case below removes exactly one thing from the real contract snapshot, so
/// the test is against a payload the server could actually send.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/data/models/sleep_page.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/features/activity/activity_screen.dart';
import 'package:healthee/features/sleep/sleep_sections.dart';
import 'package:healthee/features/today/widgets/actions_section.dart';
import 'package:healthee/shared/connection/sync_ring.dart';
import 'package:healthee/shared/v02/withheld_panel.dart';

import '../_sleep_stubs.dart';
import '../_today_stubs.dart';
import '_today_host.dart';

/// The snapshot with [key] emptied to [value].
Map<String, Object?> Function(Map<String, Object?>) without(
  String key,
  Object? value,
) => (json) => <String, Object?>{...json, key: value};

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  group('sections that fall silent', () {
    testWidgets('data health says nothing when every feed is fresh', (
      tester,
    ) async {
      // Everything the strap wrote has reached the server, which is the OTHER
      // half of "all is well" — a card that only watched the server's feeds
      // would look healthy on a phone whose push has been failing for a week.
      final pending = await store.pushReader.pending();
      await store.pushReader.markPushed(pending, now);
      // The LINK has to be healthy too, and that is a fact about the pinned
      // connection rather than about the store. A bare `Disconnected()` means
      // "this phone has never finished a sync", which is one of the two radio
      // faults the card prints since the top strip was deleted — a real state,
      // and not the one this test is about.
      await tester.pumpWidget(
        todayHost(store, connection: Disconnected(lastCompleteSync: now)),
      );
      await tester.pumpAndSettle();

      // The fixture's feeds are all `ok`, nothing is pending, and the payload
      // came off the network — so the trust card has no claim to make.
      expect(
        find.text('Data health'),
        findsNothing,
        reason: 'silence when all is well is what makes it worth reading when '
            'it speaks',
      );
    });

    testWidgets('findings do not render an empty Insights heading', (
      tester,
    ) async {
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(mutate: without('top_findings', const [])),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insights'), findsNothing);
      expect(find.text('In your own data'), findsNothing);
    });

    testWidgets('the action card is absent, not a spinner and not a refusal', (
      tester,
    ) async {
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(
            mutate: (json) => <String, Object?>{
              ...json,
              // Null action = the nightly job has not warmed it. That is a
              // premium surface with nothing to say, NOT a withheld number.
              'action': null,
              'recommendations': const [],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // By type, not by text: `Today` is the screen's own h1 since the v02
      // redesign, so the old text finder would now be asking about the title
      // rather than about the card that is meant to be absent.
      expect(find.byType(ActionsSection), findsNothing,
          reason: 'no action card at all');
      // Scoped OUT of the header: the connection ring is a
      // `CircularProgressIndicator` in every state now, and it is chrome rather
      // than a section waiting for data. An unscoped finder would be asserting
      // the ring away instead of the spinner.
      expect(
        find.descendant(
          of: find.byType(SyncRing),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'the ring, and nothing else — no section is still loading',
      );
    });

    testWidgets('the stress chart is absent when the day has no hours', (
      tester,
    ) async {
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(mutate: without('today_stress_series', const [])),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stress today'), findsNothing);
    });

    test('SLEEP’S CONDITIONAL CARDS ARE ABSENT ON A ONE-NIGHT HISTORY', () {
      // Legacy draws the debt chart, the week chart and the timing chart only
      // at two nights or more, and the naps card only when there are naps
      // (`sleep_screen.dart:387, 411, 425, 443`). One night must therefore draw
      // none of the four — a chart of one point is a claim about a pattern
      // there is no pattern in.
      //
      // Asked of the section builder rather than of a rendered scroll: this is
      // a decision about what to draw, and `sleepSections` is where it is made.
      final page = sleepPageFixture();
      final ids = sleepSections(
        page: SleepPage(
          nights: <SleepNight>[page.nights.first],
          naps: const [],
          cutoffs: page.cutoffs,
          findings: const [],
          researchNotes: page.researchNotes,
        ),
        consistency: consistencyFixture(),
        now: kSleepNow,
      ).map((section) => section.id).toSet();

      for (final conditional in <String>['debt', 'week', 'consistency', 'naps']) {
        expect(
          ids,
          isNot(contains(conditional)),
          reason: '$conditional needs more than one night to mean anything',
        );
      }
      // And the unconditional half is still all there, so this is a section
      // falling silent rather than the screen failing.
      expect(ids, containsAll(<String>['hero', 'hypnogram', 'health', 'trends']));
    });
  });

  group('sections that refuse instead', () {
    testWidgets('a block the server omitted refuses, and admits it cannot say why', (
      tester,
    ) async {
      await tester.pumpWidget(
        todayHost(
          store,
          home: const ActivityScreen(),
          server: todayView(mutate: without('cardio_load', null)),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Strain · cardio load'));

      // An absence we cannot explain is worse than one we can, and the copy
      // does not hide that — it does not claim the owner did anything wrong.
      expect(
        find.textContaining('the server did not say why'),
        findsOneWidget,
      );
      // v02's carrier for a refusal: the metric's name, a dashed hole and the
      // reason, in the slot the panel would have taken (`withheld_panel.dart`).
      expect(find.byType(WithheldPanel), findsWidgets);
    });

    testWidgets('a refused block keeps its title and its footprint', (
      tester,
    ) async {
      await tester.pumpWidget(
        todayHost(
          store,
          home: const ActivityScreen(),
          server: todayView(mutate: without('mvpa', null)),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Active minutes · MVPA'));

      // Same name, same position. It reads as the app being careful, not as a
      // card that failed to load — and the panel that would have been there is
      // not silently missing from the list.
      expect(find.text('Active minutes · MVPA'), findsOneWidget);
      expect(find.byType(WithheldPanel), findsWidgets);
    });
  });
}
