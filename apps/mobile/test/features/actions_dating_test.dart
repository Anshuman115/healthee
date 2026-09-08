/// A3 · a recommendation names the day it was written for, or it is drawn as today's.
///
/// `read/today.py::_recommendations_for` serves the newest recommendation set
/// dated at or before the day being viewed, reaching back **two days**. That
/// reach is deliberate — a rec row is already written and already dated, so
/// serving it is a record rather than a new claim — and the server has always
/// put `date` on every row.
///
/// The client dropped it. `Recommendation.fromJson` parsed nine fields and not
/// that one, on a class whose own doc comment says *"One dated, cited action"*,
/// and `actions_section.dart` then drew a Monday action on Wednesday under
/// *"Suggested actions / N ways to improve today"* with nothing on screen able
/// to say otherwise. That is the stale-as-current lie (`docs/HOW_WE_VERIFY.md`
/// section 3) in prose instead of in a number, on the one LLM-authored block
/// served for a past day.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/models/recommendation.dart';
import 'package:healthee/features/today/widgets/actions_section.dart';

Recommendation _rec({String? date, String action = 'Walk 30 minutes.'}) =>
    Recommendation.fromJson(<String, Object?>{
      'id': 1,
      'date': ?date,
      'action': action,
      'rationale': null,
      'expected_effect': null,
      'category': 'activity',
      'evidence_grade': 3,
      'research_note_ids': const <String>['steps_mortality'],
      'signal_source': 'mvpa_gap',
      'adopted': false,
    });

Widget _section(List<Recommendation> items, {String? viewedDay}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: SingleChildScrollView(
      child: ActionsSection(recommendations: items, viewedDay: viewedDay),
    ),
  ),
);

void main() {
  test('THE ROW CARRIES ITS OWN DAY OFF THE WIRE', () {
    // The server has always sent it. The parser dropped it.
    expect(_rec(date: '2026-09-06').date, '2026-09-06');
    expect(
      _rec().date,
      isNull,
      reason: 'an undated row is one whose day we do not know — never today',
    );
  });

  group('otherDay — one definition of "these are from another day"', () {
    test('a two-day-old set is named as one', () {
      expect(
        ActionsSection.otherDay([_rec(date: '2026-09-06')], '2026-09-08'),
        '2026-09-06',
      );
    });

    test("the day's own set is not", () {
      expect(
        ActionsSection.otherDay([_rec(date: '2026-09-08')], '2026-09-08'),
        isNull,
      );
    });

    test('nothing is claimed when either day is unknown', () {
      // Null `as_of` is an older server, and a null row date is a row we cannot
      // date. Guessing either would put this app's assumption where a fact goes.
      expect(ActionsSection.otherDay([_rec(date: '2026-09-06')], null), isNull);
      expect(ActionsSection.otherDay([_rec()], '2026-09-08'), isNull);
      expect(ActionsSection.otherDay(const <Recommendation>[], '2026-09-08'), isNull);
    });
  });

  testWidgets('A TWO-DAY-OLD ACTION SAYS WHICH DAY IT IS FOR', (tester) async {
    await tester.pumpWidget(
      _section([_rec(date: '2026-09-06')], viewedDay: '2026-09-08'),
    );
    await tester.pumpAndSettle();

    expect(find.text(actionsFromDay('2026-09-06')), findsOneWidget);
    expect(find.textContaining('6 Sep'), findsOneWidget);
  });

  testWidgets("today's own actions say nothing extra", (tester) async {
    // The line must not appear on the normal day, or it stops carrying meaning.
    await tester.pumpWidget(
      _section([_rec(date: '2026-09-08')], viewedDay: '2026-09-08'),
    );
    await tester.pumpAndSettle();

    expect(find.text(actionsFromDay('2026-09-08')), findsNothing);
    expect(find.textContaining('1 way to improve today'), findsOneWidget);
  });

  testWidgets('the sentence says nothing was written for the day on screen', (
    tester,
  ) async {
    // Not just "from Monday" — the reader needs to know the absence is why.
    await tester.pumpWidget(
      _section([_rec(date: '2026-09-06')], viewedDay: '2026-09-08'),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('nothing was written for this day'),
      findsOneWidget,
    );
  });
}
