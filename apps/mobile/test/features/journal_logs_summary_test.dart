/// C6 · the Daily journal panel follows the wire, including `logs_summary`.
///
/// `read/routine.py` has always shipped `logs_summary` — the per-kind `{count, total}`
/// roll-up of the day's manual entries — and `grep logs_summary apps/mobile/lib` returned
/// nothing. The consequence was visible rather than merely dead: `Routine.isEmpty` was
/// `workouts.isEmpty && meditationCount == 0 && openFast == null`, and
/// `today_day_sections.dart` draws the panel only when `!isEmpty`. So a day whose only
/// entry was **caffeine** — or water, or mood, or any kind but meditation — rendered no
/// journal panel at all, while the payload was explicitly reporting that entry.
///
/// Nothing was fabricated: the panel was silent, not wrong. It is the payload saying less
/// than it knows, and a key nothing reads invites the next reader to assume it is drawn.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/models/routine.dart';
import 'package:healthee/features/today/v02/longer_panels.dart';

Routine _routine(Map<String, Object?> logs, {Map<String, Object?>? extra}) =>
    Routine.fromJson(<String, Object?>{
      'workouts': const <Object?>[],
      'meditation_today': const <String, Object?>{'count': 0, 'minutes': 0},
      'open_fast': null,
      'logs_summary': logs,
      ...?extra,
    });

Widget _panel(Routine routine) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: SingleChildScrollView(child: JournalPanel(routine: routine)),
  ),
);

void main() {
  group('A CAFFEINE-ONLY DAY IS NOT AN EMPTY DAY', () {
    test('isEmpty follows the wire', () {
      final routine = _routine(<String, Object?>{
        'caffeine': <String, Object?>{'count': 1, 'total': 80.0},
      });

      expect(routine.isEmpty, isFalse, reason: 'the wire reported an entry');
      expect(routine.logs.single.kind, 'caffeine');
    });

    test('a day with genuinely nothing is still empty', () {
      // The other half, and the one that must not regress: the panel exists to draw
      // what happened, and a heading over nothing reads as breakage.
      expect(_routine(const <String, Object?>{}).isEmpty, isTrue);
    });

    test('a zero count is dropped rather than kept as a row', () {
      // The roll-up is a GROUP BY, so a zero cannot arrive — but carrying one would put
      // a row on screen for something the owner did not log.
      final routine = _routine(<String, Object?>{
        'caffeine': <String, Object?>{'count': 0, 'total': 0.0},
      });

      expect(routine.logs, isEmpty);
      expect(routine.isEmpty, isTrue);
    });
  });

  group('EACH ENTRY IS DRAWN ONCE', () {
    test('meditation and fasting are excluded — they have blocks of their own', () {
      // `logs_summary` counts every manual-entry kind, so both are in it while both are
      // already drawn from their own keys. Two renderings of one entry disagree the
      // moment the shapes diverge: the fast's block is about an OPEN fast, the tally
      // counts every fast of the day.
      final routine = _routine(<String, Object?>{
        'meditation': <String, Object?>{'count': 1, 'total': 10.0},
        'fasting': <String, Object?>{'count': 1, 'total': 0.0},
        'caffeine': <String, Object?>{'count': 2, 'total': 160.0},
      });

      expect(routine.logs.length, 3);
      expect(routine.otherLogs.map((tally) => tally.kind).toList(), <String>[
        'caffeine',
      ]);
    });

    test('a meditation-only day is still empty of OTHER logs', () {
      // And `isEmpty` must not be rescued by the tally for a kind whose own field says
      // zero — that would draw a panel with a row for something already drawn above.
      final routine = _routine(<String, Object?>{
        'meditation': <String, Object?>{'count': 1, 'total': 10.0},
      });

      expect(routine.otherLogs, isEmpty);
    });
  });

  group('the panel names the kind and the amount', () {
    testWidgets('a caffeine day draws its own row', (tester) async {
      await tester.pumpWidget(
        _panel(
          _routine(<String, Object?>{
            'caffeine': <String, Object?>{'count': 2, 'total': 160.0},
          }),
        ),
      );

      expect(find.text('Caffeine'), findsOneWidget);
      expect(find.text('160 mg · 2 entries'), findsOneWidget);
    });

    testWidgets('a kind with no unit shows its count alone', (tester) async {
      // `mood`, `symptom` and `habit` carry no unit by design and their totals are
      // meaningless. A bare number under no unit is a number we cannot name.
      await tester.pumpWidget(
        _panel(
          _routine(<String, Object?>{
            'mood': <String, Object?>{'count': 1, 'total': 0.0},
          }),
        ),
      );

      expect(find.text('Mood'), findsOneWidget);
      expect(find.text('1 entry'), findsOneWidget);
    });

    testWidgets('AN UNKNOWN KIND KEEPS THE SERVER ID rather than being invented', (
      tester,
    ) async {
      // The same rule `metric_names.dart` states: an id is honest about being one, an
      // invented name is not — and a unit guessed for a kind the app does not know would
      // put a number under the wrong quantity.
      await tester.pumpWidget(
        _panel(
          _routine(<String, Object?>{
            'sauna_session': <String, Object?>{'count': 1, 'total': 20.0},
          }),
        ),
      );

      expect(find.text('sauna_session'), findsOneWidget);
      expect(find.text('1 entry'), findsOneWidget);
      expect(find.textContaining('20'), findsNothing);
    });
  });
}
