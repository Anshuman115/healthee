/// **What `/api/sleep` sends against what the Sleep tab reads.**
///
/// The port parsed two of the endpoint's five top-level fields. `cutoffs`,
/// `findings` and `research_notes` were dropped at the parse boundary — right
/// for a verbatim port, wrong once surfacing the new API was opened — and one of
/// the two it did parse was rendered wrong.
///
/// Each test below is one of those, and each is written so that **reverting the
/// fix fails it**, not so that today's shape passes:
///
///   * the cutoffs are asserted to come from the PAYLOAD, by moving them;
///   * the midpoint is asserted not to be the raw ISO string it was;
///   * the citations are asserted to be the payload's ids and to vanish when the
///     payload has none;
///   * and `naps[].stages` is asserted to be the always-empty field it is, so
///     nobody builds a section on it believing it can have content.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/sleep_page.dart';
import 'package:healthee/features/sleep/sleep_sections.dart';
import 'package:healthee/features/sleep/widgets/sleep_health_card.dart';

import '../_sleep_stubs.dart';

/// The four cutoff strings the card renders, in its own order.
List<String> _cutoffStrings(SleepHealthCard card) =>
    <String>[for (final dimension in card.dimensions) dimension.cutoff];

void main() {
  group('cutoffs come off the wire, not out of the widget', () {
    test('the snapshot values render as legacy’s own strings', () {
      // Character-identical to the four literals this replaced. The point is
      // not that the strings changed — it is that they are now DERIVED, so they
      // move when the server moves.
      final page = sleepPageFixture();
      final card = SleepHealthCard(night: page.nights.first, cutoffs: page.cutoffs);
      expect(_cutoffStrings(card), <String>[
        '7–9 h',
        '≥ 85%',
        '2–4 am mid',
        'SRI ≥ 70',
      ]);
    });

    test('MUTATION — MOVE THE SERVER’S CUTOFFS AND ALL FOUR STRINGS MOVE', () {
      // The assertion that makes the one above mean something. With the four
      // literals back in the widget this passes for nobody: the card would keep
      // printing 7–9 h beside a check scored against 6–8, and nothing would
      // fail. That is the second-definition-of-science failure CLAUDE.md names.
      final page = sleepPageFixture();
      final card = SleepHealthCard(
        night: page.nights.first,
        cutoffs: SleepCutoffs.maybe(const <String, Object?>{
          'duration_hours': <double>[6, 8],
          'efficiency_min': 0.9,
          'timing_hour_band': <int>[1, 3],
          'sri_min': 75.0,
        }),
      );
      expect(_cutoffStrings(card), <String>[
        '6–8 h',
        '≥ 90%',
        '1–3 am mid',
        'SRI ≥ 75',
      ]);
    });

    test('a payload with no cutoffs falls back to words, never to a crash', () {
      // `SLEEP_CUTOFFS` is a module constant server-side, so this has never
      // happened. A card that asserts a shape it does not control is a crash
      // waiting on a deployment.
      final card = SleepHealthCard(night: sleepPageFixture().nights.first);
      expect(_cutoffStrings(card), hasLength(4));
      for (final cutoff in _cutoffStrings(card)) {
        expect(cutoff, isNotEmpty);
      }
    });

    test('efficiency is a FRACTION on the wire and a percentage on screen', () {
      // The one unit conversion in the set, and the reason this is a formatter
      // rather than four strings: the reading beside it is already a percentage.
      final card = SleepHealthCard(
        night: sleepPageFixture().nights.first,
        cutoffs: SleepCutoffs.maybe(const <String, Object?>{'efficiency_min': 0.8}),
      );
      expect(_cutoffStrings(card)[1], '≥ 80%');
      expect(_cutoffStrings(card)[1], isNot(contains('0.8')));
    });

    test('a whole-number threshold does not print a decimal point', () {
      // The wire sends `7.0`. `7.0–9.0 h` reads as a precision an expert
      // consensus band does not have.
      final card = SleepHealthCard(
        night: sleepPageFixture().nights.first,
        cutoffs: sleepPageFixture().cutoffs,
      );
      expect(_cutoffStrings(card).first, isNot(contains('.0')));
      // …and a real fraction survives.
      final half = SleepHealthCard(
        night: sleepPageFixture().nights.first,
        cutoffs: SleepCutoffs.maybe(const <String, Object?>{
          'duration_hours': <double>[7.5, 9],
        }),
      );
      expect(_cutoffStrings(half).first, '7.5–9 h');
    });

    test('a malformed band is dropped whole rather than half-read', () {
      // Half a pair would render a band with one end invented.
      expect(
        SleepCutoffs.maybe(const <String, Object?>{
          'duration_hours': <Object?>[7, null],
        })!.durationHours,
        isNull,
      );
      expect(SleepCutoffs.maybe('not a map'), isNull);
    });
  });

  group('the timing row shows a clock, not a timestamp', () {
    test('MUTATION — the raw ISO instant does not reach the cell', () {
      // `midpoint_local` arrives as `2026-07-31T02:45:00+05:30` and the row
      // printed it verbatim into a 13 px cell: a timestamp ellipsized to
      // nothing where a clock time belongs.
      final page = sleepPageFixture();
      expect(
        page.nights.first.midpointLocal.valueOrNull,
        contains('T'),
        reason: 'the wire really does send a full instant',
      );
      final timing = SleepHealthCard(
        night: page.nights.first,
        cutoffs: page.cutoffs,
      ).dimensions[2];
      expect(timing.name, 'Timing');
      expect(timing.measured, '02:45');
      expect(timing.measured, isNot(contains('T')));
      expect(timing.measured, isNot(contains('+')));
    });

    test('the OWNER’s clock face survives, not the device’s', () {
      // The string is sliced rather than parsed. `DateTime.parse` would return
      // the same instant in the test host's zone, which is a different clock
      // face — and on a phone set to UTC a 02:45 midpoint would read 21:15 the
      // evening before.
      final parsed = DateTime.parse('2026-07-31T02:45:00+05:30');
      expect(
        '${parsed.hour}'.padLeft(2, '0'),
        isNot('02'),
        reason: 'the test host is not on +05:30, so parsing WOULD change it',
      );
      final timing = SleepHealthCard(
        night: sleepPageFixture().nights.first,
      ).dimensions[2];
      expect(timing.measured, '02:45');
    });

    test('an unreadable midpoint draws the hole rather than echoing itself', () {
      final night = sleepPageWithout(<String>['midpoint_local']).nights.first;
      expect(SleepHealthCard(night: night).dimensions[2].measured, isNull);
    });
  });

  group('the sleep tab finally carries a citation', () {
    testWidgets('the payload’s four notes render as named sources', (tester) async {
      final page = sleepPageFixture();
      expect(page.researchNotes, hasLength(4));
      await tester.pumpWidget(
        sleepCardHost(
          SleepHealthCard(
            night: page.nights.first,
            cutoffs: page.cutoffs,
            notes: page.researchNotes,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The corpus's own names, not the ids — `note_names.dart`'s whole job.
      expect(find.text('Sleep duration and all-cause mortality'), findsOneWidget);
      expect(find.text('Sleep Regularity Index (SRI)'), findsOneWidget);
      expect(find.text('sleep_duration_mortality'), findsNothing);
    });

    testWidgets('AN EMPTY NOTE LIST RENDERS NOTHING AT ALL', (tester) async {
      // The governing rule. `CitationRow` shrinks itself, and the spacer above
      // it is behind the same condition, so an empty list leaves no gap either.
      await tester.pumpWidget(
        sleepCardHost(SleepHealthCard(night: sleepPageFixture().nights.first)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sleep duration and all-cause mortality'), findsNothing);
    });
  });

  test('naps[].stages is ALWAYS EMPTY, and that is a server-side bug', () {
    // Recorded rather than worked around. `read/sleep_page.py:244` ships the raw
    // JSONB hypnogram for a nap — `[[startMs, endMs, typeCode]]` — where
    // `nights` ships `stage_timeline()`'s objects, so `NapStage.fromJson` never
    // sees a map and every nap bar is blank. A client-side fix would mean
    // re-implementing the strap's stage-code mapping in the UI layer, i.e. a
    // second definition of what a stage is.
    //
    // Neither side's tests catch it: the contract fixture's nap has `stages: []`
    // and the server's shape check exempts empty lists.
    final raw = loadJson(kSleepSnapshotPath);
    final naps = raw['naps']! as List<Object?>;
    expect(naps, isNotEmpty);
    for (final nap in naps.cast<Map<String, Object?>>()) {
      for (final span in nap['stages']! as List<Object?>) {
        expect(
          span,
          isNot(isA<Map<String, Object?>>()),
          reason: 'if this passes maps now, the server was fixed — drop this test',
        );
      }
    }
    for (final nap in sleepPageFixture().naps) {
      expect(nap.stages, isEmpty);
    }
  });

  group('findings — the section that must not exist when it is empty', () {
    test('AN EMPTY FINDINGS ARRAY DRAWS NOTHING — no heading, no zero-state', () {
      // The governing rule for everything surfaced off the new API. Sleep
      // findings are empty for most owners most of the time (`read/findings.py`
      // returns `[]` whenever the analytics layer has nothing), so a section that
      // always existed would usually exist to say it was empty.
      final page = sleepPageFixture();
      final ids = sleepSections(
        page: SleepPage(
          nights: page.nights,
          naps: page.naps,
          cutoffs: page.cutoffs,
          findings: const [],
          researchNotes: page.researchNotes,
        ),
        consistency: consistencyFixture(),
        now: kSleepNow,
      ).map((section) => section.id).toList();
      expect(ids, isNot(contains('findings')));
      // MUTATION — and the same payload WITH a finding does draw one, so this is
      // not passing because the section was never wired.
      expect(
        sleepSections(page: page, consistency: consistencyFixture(), now: kSleepNow)
            .map((section) => section.id),
        contains('findings'),
      );
    });
  });
}
