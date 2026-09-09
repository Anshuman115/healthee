/// Openers name the owner's figures, and must never say what they mean.
///
/// This is the surface where a question can smuggle in a claim. "Why did my
/// sleep regularity FALL to 65.7?" asserts a fall, puts that assertion in the
/// owner's mouth, and leaves the coach answering a premise it was handed rather
/// than one it checked. Neutral by construction is the rule; these are the
/// assertions that it holds.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/features/coach/v02/coach_openers.dart';

/// Every word that would turn a question into a claim about a direction, a
/// cause, or a verdict.
const List<String> _banned = <String>[
  'fall',
  'fell',
  'dropped',
  'drop',
  'rose',
  'rising',
  'improved',
  'worse',
  'better',
  'bad',
  'good',
  'poor',
  'because',
  'caused',
  'why did',
];

void main() {
  group('with no snapshot at all', () {
    test('falls back to the generic questions, never to nothing', () {
      // A screen with no openers is a worse answer than three general ones.
      expect(coachOpeners(null), kGenericOpeners.take(3));
    });
  });

  group('the wording rule', () {
    test('no opener asserts a direction, a cause or a verdict', () {
      for (final opener in <String>[
        ...kGenericOpeners,
        ...coachOpeners(null),
      ]) {
        final lower = opener.toLowerCase();
        for (final word in _banned) {
          expect(
            lower.contains(word),
            isFalse,
            reason: '"$opener" contains "$word", which makes it a claim',
          );
        }
      }
    });

    test('every opener is a question', () {
      for (final opener in coachOpeners(null)) {
        expect(opener.endsWith('?'), isTrue, reason: opener);
      }
    });
  });

  group('never more than asked for, never a duplicate', () {
    test('at most three, whatever is available', () {
      expect(coachOpeners(null).length, lessThanOrEqualTo(3));
    });

    test('the generic list itself holds no duplicate', () {
      expect(kGenericOpeners.toSet().length, kGenericOpeners.length);
    });
  });
}
