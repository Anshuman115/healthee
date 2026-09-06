/// The two numbers these charts are NOT allowed to invent: 92%, and a baseline.
///
///   * `wearable_spo2_validity` D1–D3 — SpO₂ is a trend over multiple nights and
///     never a single-reading alarm; individual low readings are mostly sensor
///     artefacts and must not be called out; and the ~92% line is a **clinical
///     convention**, not a cutoff validated on this strap (#98 could source no
///     wearable-specific threshold at all, and the device is not a cleared
///     oximeter, so its true error is unquantified).
///   * `CLAUDE.md`'s one-definition-per-metric — a baseline the server did not
///     send is not one the client may make up. A median of the fourteen points
///     on screen would render beautifully, and would be a different number from
///     the one every other surface in the app quotes.
///
/// Both failures are silent and both look like care: a card that flags one 91%
/// night looks vigilant, and a fabricated baseline looks like data. So both are
/// mutated in `test/mutations.sh` as well as asserted here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/today/v02/mini_trend_panel.dart';
import 'package:healthee/features/today/widgets/blood_oxygen_card.dart';
import 'package:healthee/features/today/widgets/hrv_trend_card.dart';
import 'package:healthee/features/today/widgets/metric_note.dart';
import 'package:healthee/shared/charts/h_deviation.dart';
import 'package:healthee/shared/charts/h_night_line.dart';
import 'package:healthee/shared/reveal_once.dart';

import '../shared/_chart_probe.dart';
import '_today_host.dart';
import '_vitals_probe.dart';

void main() {
  group('blood oxygen — wearable_spo2_validity D1–D3', () {
    Future<Finder> pumpNights(WidgetTester tester, List<double> minima) async {
      await tester.pumpWidget(
        chartHost(
          BloodOxygenCard(
            minima: minima,
            reading: const Present<double>(96),
            reveals: RevealRegistry(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return find.byType(BloodOxygenCard);
    }

    testWidgets('ONE NIGHT UNDER THE CONVENTION IS NOT A FLAG', (tester) async {
      // D1/D3. The single low night here is 88% — LOWER than any night in the
      // sustained run below — and it still says nothing, because one night on an
      // unvalidated reflectance sensor is most likely a cold hand or a loose
      // strap. This is the assertion the previous, ported note failed: legacy
      // fired on `lowest < 90` and again on `lastMinimum < 92`, both of them
      // single nights.
      final card = await pumpNights(
        tester,
        const <double>[96, 95, 97, 88, 96, 95, 97, 96, 95, 96],
      );
      final note = noteOf(tester, card);

      expect(note, contains('no sustained run'));
      expect(note, isNot(contains('clinician')));
      expect(note, isNot(contains('nights in a row')));
      expect(
        note,
        isNot(contains('88')),
        reason: 'D3: the note must not make a claim about the one low night',
      );
    });

    testWidgets('SCATTERED LOW NIGHTS ARE NOT A RUN', (tester) async {
      // Four nights under the line, none of them consecutive. D3 puts scattered
      // lows down to artefacts; a run is the pattern D2 actually describes.
      final card = await pumpNights(
        tester,
        const <double>[91, 96, 90, 97, 89, 96, 91, 95],
      );
      expect(noteOf(tester, card), contains('no sustained run'));
    });

    testWidgets('A SUSTAINED RUN ROUTES TO A CLINICIAN, AND DIAGNOSES NOTHING', (
      tester,
    ) async {
      final card = await pumpNights(
        tester,
        const <double>[96, 95, 91, 90, 91, 96, 95],
      );
      final rendered = noteOf(tester, card);

      expect(rendered, contains('3 nights in a row'));
      expect(rendered, contains('clinician'));
      // D2's exact shape: a reason to get checked, never a finding.
      expect(rendered, contains('not a diagnosis'));
      expect(
        rendered,
        contains('convention'),
        reason: 'the sentence must name 92% as a convention every time it uses it',
      );
      // D4 of the same note: never a sleep-apnea diagnosis, at most a suspicion
      // worth a study. The word must not appear at all in a line this card
      // renders without being asked.
      for (final word in const <String>['apnea', 'apnoea', 'hypoxaemia']) {
        expect(rendered, isNot(contains(word)));
      }
    });

    testWidgets('THE 92% LINE IS LABELLED A CONVENTION', (tester) async {
      final card = await pumpNights(
        tester,
        const <double>[96, 95, 97, 94, 96, 95, 97],
      );
      final chart = tester.widget<HNightLine>(
        find.descendant(of: card, matching: find.byType(HNightLine)),
      );

      expect(chart.reference, isNotNull);
      expect(chart.reference!.value, spo2ConventionPercent);
      expect(chart.reference!.label.toLowerCase(), contains('convention'));
      expect(
        chart.reference!.isDashed,
        isTrue,
        reason: 'a borrowed line must not be drawn like the owner’s own number',
      );
      // And it is painted, not merely configured.
      expect(
        countOf(paintedBy(tester, find.byType(HNightLine)), #drawLine),
        greaterThan(1),
        reason: 'a dashed line is many segments',
      );
    });

    testWidgets('NO NIGHT IS DRAWN DIFFERENTLY FROM ANY OTHER', (tester) async {
      // D3, in ink. Colouring the low nights would be the single-reading
      // callout the note forbids, and it is the first thing anyone would add.
      await pumpNights(tester, const <double>[96, 91, 89, 90, 96, 95, 97]);
      final dots = <int>{
        for (final call in paintedBy(tester, find.byType(HNightLine)))
          if (call.invocation.memberName == #drawCircle)
            for (final argument in call.invocation.positionalArguments)
              if (argument is Paint) argument.color.toARGB32(),
      };
      expect(dots, hasLength(1));
    });

    test('the run counter counts CONSECUTIVE nights only', () {
      expect(longestLowNightRun(const <double>[96, 95, 97]), 0);
      expect(longestLowNightRun(const <double>[96, 88, 97]), 1);
      expect(longestLowNightRun(const <double>[91, 96, 90, 97, 89]), 1);
      expect(longestLowNightRun(const <double>[96, 91, 90, 91, 96]), 3);
      expect(longestLowNightRun(const <double>[91, 90, 89, 88]), 4);
      // The boundary: 92 IS the convention and is not under it.
      expect(longestLowNightRun(const <double>[92, 92, 92]), 0);
      expect(
        sustainedLowNights,
        greaterThan(1),
        reason: 'a run of one is a single-reading alarm, which is D1',
      );
    });
  });

  group('a baseline the server did not send', () {
    testWidgets('DRAWS NO REFERENCE, AND THE CARD SAYS SO', (tester) async {
      await tester.pumpWidget(
        chartHost(
          HrvTrendCard(
            series: const <double>[41, 47, 39, 52, 44, 48, 43],
            reading: const Present<double>(43),
            baseline: null,
            reveals: RevealRegistry(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final painted = paintedBy(tester, find.byType(HDeviation));
      // No line, no label, no fill — only the series itself. A fabricated
      // baseline would add all three and look entirely convincing.
      expect(countOf(painted, #drawLine), 0);
      expect(countOf(painted, #drawParagraph), 0);
      expect(
        countOf(painted, #drawPath),
        1,
        reason: 'with nothing to depart FROM there is no departure to fill',
      );
      expect(
        textOf(tester, find.byType(HrvTrendCard)).join(' ').toLowerCase(),
        contains('no 30-day baseline'),
      );
    });

    testWidgets('AND DRAWS ONE WHEN THE SERVER DOES SEND IT', (tester) async {
      await tester.pumpWidget(
        chartHost(
          HrvTrendCard(
            series: const <double>[41, 47, 39, 52, 44, 48, 43],
            reading: const Present<double>(43),
            baseline: 45,
            reveals: RevealRegistry(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final painted = paintedBy(tester, find.byType(HDeviation));
      expect(countOf(painted, #drawLine), 1);
      expect(countOf(painted, #drawPath), 2);
      expect(
        textOf(tester, find.byType(HrvTrendCard)).join(' ').toLowerCase(),
        isNot(contains('no 30-day baseline')),
      );
    });

    testWidgets('ON THE REAL PAYLOAD, HRV HAS NONE AND NAMES NONE', (
      tester,
    ) async {
      // Not a hypothetical: the committed contract snapshot carries no HRV
      // recovery signal, and `hrv_sleep_avg` has no metric card on any payload,
      // so this is what the owner's phone renders today.
      //
      // The v02 panel says how many nights are on the line and stops there. It
      // does NOT compute a median of those nights and call it a baseline —
      // `today_facts.dart` records why that would be a second definition of the
      // owner's normal, arriving as a helpful-looking last resort.
      final store = LocalStore.memory();
      addTearDown(store.close);
      await seedDevice(store);
      tester.view
        ..physicalSize = const Size(420, 14000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      final panel = find.byWidgetPredicate(
        (widget) => widget is MiniTrendPanel && widget.title == 'Overnight HRV',
      );
      await reveal(tester, panel);

      final words = textOf(tester, panel).join(' ').toLowerCase();
      // On this payload the FIGURE is withheld too — `hrv_sleep_avg` has no
      // metric card and the ladder carries no HRV marker — so the panel shows
      // the server's own reason where the number goes. That is the contract:
      // a hole that says why it is a hole, never a blank.
      expect(words, contains('the server did not say why'));
      expect(
        words,
        isNot(contains('baseline')),
        reason: 'a baseline the server did not send may not be named',
      );
    });
  });
}
