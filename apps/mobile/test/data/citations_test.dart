/// The citation grammar, against the server's own edge cases.
///
/// `insights/answer_text.py::extract_citations` is the other implementation of
/// this grammar and the one the blocking validator uses. Two implementations of
/// one grammar is a thing the standards forbid and this one cannot avoid — one is
/// Python on a server and one is Dart on a phone — so the cases the server's
/// docstrings call out by name are the cases asserted here.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/honesty/citations.dart';

void main() {
  group('what is a citation', () {
    test('a plain note id is lifted out of the sentence', () {
      final parsed = parseGrounded(
        'Your recovery supports moderate movement [recovery_readiness].',
      );
      expect(parsed.prose, 'Your recovery supports moderate movement.');
      expect(parsed.noteIds, <String>['recovery_readiness']);
      expect(parsed.personalFindings, isEmpty);
      expect(parsed.unresolved, isEmpty);
    });

    test('A BRACKET MIXING KINDS YIELDS BOTH', () {
      // The exact bug `answer_text.py` records: a pair of whole-bracket regexes
      // parsed `[personal_finding:x, note_id]` partially, so a real citation was
      // silently lost and the finding name came back as garbage.
      final parsed = parseGrounded(
        'It moved with your sleep [personal_finding:hrv_sleep_avg, sleep_need_debt].',
      );
      expect(parsed.noteIds, <String>['sleep_need_debt']);
      expect(parsed.personalFindings, <String>['hrv_sleep_avg']);
      expect(parsed.prose, 'It moved with your sleep.');
    });

    test('either order parses the same', () {
      final parsed = parseGrounded('x [sleep_need_debt, personal_finding:hrv].');
      expect(parsed.noteIds, <String>['sleep_need_debt']);
      expect(parsed.personalFindings, <String>['hrv']);
    });

    test('the personal prefix is matched case-insensitively, as on the server', () {
      expect(
        parseGrounded('x [Personal_Finding:steps_total].').personalFindings,
        <String>['steps_total'],
      );
    });

    test('several markers keep their order and do not repeat', () {
      final parsed = parseGrounded(
        'One [a_note]. Two [b_note]. Three [a_note].',
      );
      expect(parsed.noteIds, <String>['a_note', 'b_note']);
    });

    test('text with no brackets comes back untouched', () {
      const plain = 'Debt here is what the last 14 nights owe you.';
      final parsed = parseGrounded(plain);
      expect(parsed.prose, plain);
      expect(parsed.isBare, isTrue);
    });
  });

  group('a bracket that grounds nothing', () {
    test('IS LEFT IN THE SENTENCE AND REPORTED', () {
      // The rule the whole design turns on: strip only what we resolved. A
      // bracket we cannot classify might be the model's prose or a truncation,
      // and deleting it would be the app editing a claim it does not understand.
      final parsed = parseGrounded('Your HRV [45 ms] is below your normal.');
      expect(parsed.prose, 'Your HRV [45 ms] is below your normal.');
      expect(parsed.unresolved, <String>['45 ms']);
      expect(parsed.noteIds, isEmpty);
    });

    test('an empty personal name is not a citation', () {
      final parsed = parseGrounded('x [personal_finding:].');
      expect(parsed.personalFindings, isEmpty);
      expect(parsed.unresolved, <String>['personal_finding:']);
    });

    test('an id with a capital or a space is not an id', () {
      expect(parseGrounded('x [Recovery Readiness].').noteIds, isEmpty);
      expect(parseGrounded('x [Recovery Readiness].').unresolved, hasLength(1));
    });

    test('a MIXED bracket is stripped whole, because it did ground something', () {
      final parsed = parseGrounded('x [see below, sleep_need_debt].');
      expect(parsed.noteIds, <String>['sleep_need_debt']);
      expect(parsed.prose, 'x.');
      expect(
        parsed.unresolved,
        isEmpty,
        reason: 'the bracket resolved; the prose part of it was never prose',
      );
    });
  });

  group('the sentence is left readable', () {
    test('no double space where a marker was', () {
      final parsed = parseGrounded('Walk today [a_note] and sleep early.');
      expect(parsed.prose, 'Walk today and sleep early.');
    });

    test('no space before the punctuation a marker sat in front of', () {
      expect(parseGrounded('Rest [a_note], then move.').prose, 'Rest, then move.');
      expect(parseGrounded('Rest [a_note].').prose, 'Rest.');
    });

    test('line breaks survive', () {
      final parsed = parseGrounded('One [a_note].\n\nTwo [b_note].');
      expect(parsed.prose, 'One.\n\nTwo.');
    });
  });
}
