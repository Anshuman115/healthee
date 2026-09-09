/// A4 · an illness flag names the day it was raised, or it is read as today's.
///
/// `read/health_metrics.py` selects the newest flag in `[anchor − 2 days, anchor]`
/// (`_ILLNESS_ACTIVE_DAYS = 2`) and ships `date` precisely so a reader can tell which day
/// it is about. The client parsed it and the only consumer drew framing, sustained and
/// deltas — never the day. Meanwhile the framing sentence the banner prints verbatim is
/// present-tense: *"Possible early signal — consider lighter activity today."*
///
/// So a flag raised on Monday rendered on Wednesday as advice about Wednesday. That is
/// stale-as-current — the lie `docs/HOW_WE_VERIFY.md` section 3 records as swept three
/// times — on the one **safety-critical** block on the Today screen, and the repo had
/// already fixed the identical bug on the block beside it (`actions_dating_test.dart`).
///
/// ## C4 is here too, because it is the same widget's other half
///
/// The banner printed the server's calibrated sentence — which names the baseline WINDOW,
/// as `[[respiratory_rate_normal]]` Coach Directive 1 requires because that note ships
/// three of them — and then printed the same two numbers again, client-side, with the
/// window dropped. A second copy of a number can only ever agree less. It is gone, and
/// the assertion that it stays gone lives beside the one that put the date on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/models/illness_flag.dart';
import 'package:healthee/features/today/widgets/illness_banner.dart';
import 'package:healthee/shared/format/other_day.dart';

const String _framing =
    'Possible early signal — consider lighter activity today. Breathing rate '
    '+2.4 bpm vs your 14-day baseline; skin temperature +0.35°C. Not a diagnosis.';

IllnessFlag _flag({String? date}) => IllnessFlag.maybe(<String, Object?>{
  'date': ?date,
  'severity': 'moderate',
  'sustained': false,
  'framing': _framing,
  'rr_delta_bpm': 2.4,
  'temp_delta_c': 0.35,
  'research_note_ids': const <String>['respiratory_rate_normal'],
})!;

Widget _banner(IllnessFlag flag, {String? viewedDay}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: SingleChildScrollView(
      child: IllnessBanner(flag: flag, viewedDay: viewedDay),
    ),
  ),
);

void main() {
  group('THE DAY THE SIGNAL WAS RAISED', () {
    testWidgets('a flag from two days ago says so on its face', (tester) async {
      await tester.pumpWidget(
        _banner(_flag(date: '2026-09-06'), viewedDay: '2026-09-08'),
      );

      expect(find.text(raisedOnDay('2026-09-06')), findsOneWidget);
    });

    testWidgets('a flag raised on the day being viewed says nothing extra', (
      tester,
    ) async {
      // The banner must not caption every flag with a date. The sentence exists to
      // contradict the present tense above it, and on today's flag there is nothing to
      // contradict.
      await tester.pumpWidget(
        _banner(_flag(date: '2026-09-08'), viewedDay: '2026-09-08'),
      );

      expect(find.textContaining('Raised on'), findsNothing);
    });

    testWidgets('an undated flag claims nothing about which day it is for', (
      tester,
    ) async {
      // Null is not filled in from the day on screen. An undated flag is one whose day
      // we do not know, which is a different statement from "it is this day's" — the
      // same rule `recommendation.dart` states about its own date.
      await tester.pumpWidget(_banner(_flag(), viewedDay: '2026-09-08'));

      expect(find.textContaining('Raised on'), findsNothing);
    });

    testWidgets('a payload with no as_of claims nothing either', (
      tester,
    ) async {
      // An older server sends no `as_of`, so there is no day to compare against. The
      // banner must not reach for a device clock — `as_of.dart` makes that argument
      // about `isToday` and it holds here.
      await tester.pumpWidget(_banner(_flag(date: '2026-09-06')));

      expect(find.textContaining('Raised on'), findsNothing);
    });

    testWidgets('the calibrated sentence is still rendered verbatim', (
      tester,
    ) async {
      // The date is added BESIDE the safety sentence, never woven into it. Re-wording a
      // calibrated safety statement in the UI layer is how a hedge becomes a diagnosis.
      await tester.pumpWidget(
        _banner(_flag(date: '2026-09-06'), viewedDay: '2026-09-08'),
      );

      expect(find.text(_framing), findsOneWidget);
    });
  });

  group('C4 · THE DELTAS ARE THE SERVER SENTENCE AND NOTHING ELSE', () {
    testWidgets('the banner prints the numbers once, with their window', (
      tester,
    ) async {
      await tester.pumpWidget(
        _banner(_flag(date: '2026-09-08'), viewedDay: '2026-09-08'),
      );

      // Once, inside the server's sentence, with "14-day" attached.
      expect(
        find.textContaining('Breathing rate +2.4 bpm vs your 14-day baseline'),
        findsOneWidget,
      );
      // And not again without it. This is the directive: never quote a delta against a
      // baseline without saying which baseline.
      expect(
        find.textContaining('breathing rate +2.4 bpm vs your baseline'),
        findsNothing,
        reason: 'the unqualified client-side restatement is back',
      );
      expect(
        find.textContaining('skin temperature +0.35 °C vs your baseline'),
        findsNothing,
      );
    });

    testWidgets('a flag whose sentence carries no numbers gets none from us', (
      tester,
    ) async {
      // The deltas stay on the model for the log and the ⓘ. If the server's sentence
      // did not quote them, neither does the screen — inventing the line back would
      // reintroduce exactly the unqualified copy that was removed.
      final quiet = IllnessFlag.maybe(<String, Object?>{
        'date': '2026-09-08',
        'severity': 'high',
        'sustained': true,
        'framing': 'Possible early signal — consider lighter activity today.',
        'rr_delta_bpm': 2.4,
        'temp_delta_c': 0.35,
        'research_note_ids': const <String>[],
      })!;

      await tester.pumpWidget(_banner(quiet, viewedDay: '2026-09-08'));

      expect(find.textContaining('2.4'), findsNothing);
      expect(find.textContaining('0.35'), findsNothing);
      expect(quiet.respiratoryRateDeltaBpm, 2.4);
    });
  });
}
