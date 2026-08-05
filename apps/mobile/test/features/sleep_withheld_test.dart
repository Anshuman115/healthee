/// A field the server did not send renders as **withheld**, on every card.
///
/// This is the one place the Sleep port is deliberately not 1:1. Legacy drew
/// `'—'` for every null on this screen, so "the strap was off your wrist", "the
/// server has not derived this yet" and "we have a bug" all looked identical —
/// a value-shaped mark that says nothing.
///
/// Two things are asserted for each card, and the second is why this file
/// exists:
///
///   1. the number's slot becomes a [ValueHole] — the card keeps its footprint;
///   2. **the card SAYS which value is missing and why.** A hole on its own is a
///      blank with a dashed border. `test/mutations.sh` deletes each
///      `SleepGapNote` in turn and requires this suite to notice, because a card
///      silently blanking is exactly the failure that would otherwise pass.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/honesty/sleep_gap.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/features/sleep/widgets/overnight_vitals_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_health_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_hero_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_performance_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_trends_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_value.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/states/value_hole.dart';
import 'package:solar_icons/solar_icons.dart';

import '../_sleep_stubs.dart';

/// The newest night of the fixture, with [fields] blanked on the wire.
SleepNight nightWithout(List<String> fields) =>
    sleepPageWithout(fields).nights.first;

/// Every gap sentence a card is currently showing.
Iterable<String> gapSentences(WidgetTester tester) => tester
    .widgetList<SleepGapNote>(find.byType(SleepGapNote))
    .expand((note) => groupGaps(note.fields).values)
    .map((group) => '${group.names.join(", ")} — ${group.message}');

void main() {
  group('the hero', () {
    testWidgets('A NIGHT WITH NO TOTAL DRAWS A HOLE AND SAYS WHY', (tester) async {
      final night = nightWithout(<String>['tst_min', 'duration_min', 'zepp_score']);
      await tester.pumpWidget(
        sleepCardHost(SleepHeroCard(night: night, previous: null, progress: 1)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ValueHole), findsWidgets, reason: 'the slot keeps its shape');
      expect(
        gapSentences(tester).join(' '),
        allOf(
          contains('Time asleep'),
          contains("The strap's sleep score"),
          contains('derived'),
        ),
        reason: 'a hole nobody explains is a blank with a dashed border',
      );
      // And no dash anywhere — the mark this whole file exists to remove.
      expect(find.text('—'), findsNothing);
    });

    testWidgets('a withheld efficiency spends NO verdict colour', (tester) async {
      // Legacy: `(eff ?? 0) >= 85 ? green : cHeart`, so a night with no
      // efficiency was painted the same red as a bad one — a judgement about
      // the owner made out of a measurement that does not exist.
      final night = nightWithout(<String>['efficiency_pct']);
      await tester.pumpWidget(
        sleepCardHost(SleepHeroCard(night: night, previous: null, progress: 1)),
      );
      await tester.pumpAndSettle();

      final painted = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.style?.color)
          .toSet();
      const hues = InstrumentHues.light();
      expect(painted, isNot(contains(hues.heart)));
    });
  });

  group('the sleep-health checks', () {
    testWidgets('AN UNSCORED DIMENSION IS NOT A FAILED ONE', (tester) async {
      // Legacy read `_d(n['point_timing']) == 1`, so a dimension the server
      // never scored drew a CROSS. That is a failed check invented out of a
      // missing one.
      final night = nightWithout(<String>['point_timing', 'midpoint_local']);
      await tester.pumpWidget(sleepCardHost(SleepHealthCard(night: night)));
      await tester.pumpAndSettle();

      final timing = night.pointTiming;
      expect(timing, isA<Withheld<bool>>());
      expect(
        gapSentences(tester).join(' '),
        contains('Timing'),
        reason: 'the card must name the check it could not make',
      );
      // No cross anywhere: the fixture's three scored checks all PASS, and the
      // fourth is unscored. A cross here is the legacy defect exactly.
      expect(
        find.byIcon(SolarIconsOutline.closeCircle),
        findsNothing,
        reason: 'an unscored check drawn as a failed one',
      );
      expect(find.byIcon(SolarIconsBold.checkCircle), findsNWidgets(3));
    });

    testWidgets('the four checks are four rows and are never summed', (
      tester,
    ) async {
      await tester.pumpWidget(
        sleepCardHost(SleepHealthCard(night: sleepPageFixture().nights.first)),
      );
      await tester.pumpAndSettle();

      for (final name in <String>['Duration', 'Efficiency', 'Timing', 'Regularity']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('/ 4'), findsOneWidget);
      // Nothing that reads as one number standing for the four.
      expect(find.textContaining('%'), findsWidgets); // efficiency's own row
      expect(find.text('75%'), findsNothing);
      expect(find.text('3/4'), findsNothing);
    });
  });

  group('the overnight vitals', () {
    testWidgets('SIX MISSING CELLS ARE ONE SENTENCE, NOT SIX', (tester) async {
      final night = nightWithout(<String>[
        'rhr',
        'hrv_sleep_avg',
        'respiratory_rate',
        'spo2_avg',
        'spo2_min',
        'skin_temp_c',
      ]);
      await tester.pumpWidget(sleepCardHost(OvernightVitalsCard(night: night)));
      await tester.pumpAndSettle();

      // Read off what was RENDERED, not off a card built beside it: a note that
      // stopped iterating its own slots would still leave the getter correct.
      final rendered = tester
          .widgetList<SleepGapNote>(find.byType(SleepGapNote))
          .single;
      final grouped = groupGaps(rendered.fields);
      // Two reasons, because the payload really does have two: the derived pair
      // (resting HR, HRV) and the sampled four.
      expect(grouped.keys, hasLength(2));
      expect(
        grouped[SleepGap.notSampled.reason]!.names,
        containsAll(<String>['SpO₂', 'Lowest SpO₂', 'Skin temperature']),
      );
      expect(
        grouped[SleepGap.notDerived.reason]!.names,
        containsAll(<String>['Resting HR', 'HRV']),
      );
      expect(gapSentences(tester).join(' '), contains('Skin temperature'));
      expect(find.byType(ValueHole), findsNWidgets(6));
      expect(find.text('—'), findsNothing);
    });
  });

  group('sleep performance', () {
    testWidgets('AN EMPTY FORTNIGHT IS WITHHELD, NEVER 0/0', (tester) async {
      // A ratio out of nothing is a number-shaped statement that no nights were
      // short, which is not what an empty fortnight means.
      final page = sleepPageWithoutSession();
      final blank = SleepNight.fromJson(const <String, Object?>{'date': '2026-07-31'});
      final card = SleepPerformanceCard(
        night: blank,
        recent: <SleepNight>[blank],
        progress: 1,
      );
      await tester.pumpWidget(sleepCardHost(card));
      await tester.pumpAndSettle();

      expect(card.nightsShort, isA<Withheld<String>>());
      expect(card.average, isA<Withheld<double>>());
      expect(find.text('0/0'), findsNothing);
      expect(
        gapSentences(tester).join(' '),
        contains('The count of short nights'),
      );
      // The fixture itself still computes a real one, so the assertion above is
      // about the empty case and not about the card being permanently silent.
      expect(
        SleepPerformanceCard(
          night: page.nights.first,
          recent: page.nights.take(14).toList(),
          progress: 1,
        ).nightsShort,
        isA<Present<String>>(),
      );
    });
  });

  group('the fortnight trends', () {
    testWidgets('A ONE-NIGHT SERIES IS NOT DRAWN AS A FLAT ZERO', (tester) async {
      // Legacy: `HArea(data.length >= 2 ? data : [0, 0], …)`. A metric with one
      // night of history — or none — was plotted as two invented points at zero,
      // in the metric's own colour, indistinguishable from a real fortnight of
      // zeroes. There is no reading of that which is honest.
      final one = <SleepNight>[sleepPageFixture().nights.first];
      await tester.pumpWidget(
        sleepCardHost(SleepTrendsCard(recent: one, progress: 1)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(HArea),
        findsNothing,
        reason: 'a line needs two real points, and there is one',
      );
      expect(find.textContaining('A line needs at least 2'), findsWidgets);
      // The row keeps its footprint and its latest value, which is a real
      // measurement and stays on screen.
      for (final label in const <String>['Efficiency', 'Regularity (SRI)', 'HRV']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('a full fortnight IS plotted', (tester) async {
      await tester.pumpWidget(
        sleepCardHost(
          SleepTrendsCard(
            recent: sleepPageFixture().nights.take(14).toList(),
            progress: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HArea), findsNWidgets(3));
    });
  });
}
