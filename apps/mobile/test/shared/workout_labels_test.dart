/// The two workout formats, and the day grouping the session list is built on.
///
/// Small functions, and every one of them has a way of being wrong that a
/// rendered suite would not catch: a pace that reads `7:60`, a drift whose sign
/// is a hyphen, a session filed under the wrong calendar day because the key was
/// taken in UTC. That last one is the defect this repo has already paid for
/// once, so it is asserted from both sides of midnight.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/workouts/workout_summary.dart';
import 'package:healthee/features/workouts/v02/session_rows.dart';
import 'package:healthee/shared/format/workout_labels.dart';

WorkoutSummary _at(DateTime start, {String sport = 'Outdoor run'}) =>
    WorkoutSummary(start: start, sportName: sport);

void main() {
  group('paceLabel', () {
    test('minutes and seconds, from the server’s own rounding', () {
      expect(paceLabel(7.14), '7:08');
      expect(paceLabel(5), '5:00');
      expect(paceLabel(4.5), '4:30');
    });

    test('a rounding that reaches sixty carries into the minute', () {
      expect(paceLabel(7.999), '8:00');
    });

    test('nothing to format is nothing, never a placeholder', () {
      expect(paceLabel(null), isNull);
      expect(paceLabel(double.nan), isNull);
      expect(paceLabel(-1), isNull);
    });
  });

  group('driftLabel', () {
    test('a rise is signed, a fall carries the minus glyph', () {
      expect(driftLabel(10), '+10');
      // U+2212, not a hyphen: at 22 px beside a tabular figure a hyphen reads
      // as a dash rather than a sign.
      expect(driftLabel(-10), '−10');
      expect(driftLabel(0), '0');
    });

    test('no reading formats to nothing', () {
      expect(driftLabel(null), isNull);
      expect(driftLabel(double.infinity), isNull);
    });
  });

  group('byDay', () {
    test('newest session first, inside a newest-day-first list', () {
      final days = byDay(<WorkoutSummary>[
        _at(DateTime(2026, 7, 30, 8)),
        _at(DateTime(2026, 7, 31, 7)),
        _at(DateTime(2026, 7, 31, 18)),
      ]);
      expect(days.map((day) => day.date).toList(), <String>[
        '2026-07-31',
        '2026-07-30',
      ]);
      expect(days.first.sessions.first.start.hour, 18);
      expect(days.first.sessions.last.start.hour, 7);
    });

    test('the key is the LOCAL day, so a late session keeps its own date', () {
      // Built as a local instant, which is what the row is captioned with. A
      // UTC key would file this under tomorrow anywhere east of Greenwich.
      final late = DateTime(2026, 7, 31, 23, 30);
      expect(byDay(<WorkoutSummary>[_at(late)]).single.date, '2026-07-31');
    });

    test('an empty list is an empty list, not a day with nothing in it', () {
      expect(byDay(const <WorkoutSummary>[]), isEmpty);
    });
  });
}
