/// The honesty fold, tested case by case.
///
/// This is the one function that decides which [Reading] a payload becomes, so
/// its precedence rules are worth pinning individually rather than only through
/// the golden test. Each test below names the rule it protects.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/honesty/envelope.dart';
import 'package:healthee/data/honesty/reading.dart';

Map<String, Object?> _disclosure(String reason) => <String, Object?>{
  'reason': reason,
  'message': 'Something to say about $reason.',
};

void main() {
  group('readingFrom', () {
    test('a plain value with nothing attached is Present', () {
      final reading = numericReadingFrom(<String, Object?>{'value': 55.0}, 'value');
      expect(reading, const Present<double>(55));
    });

    test('a withheld block wins over everything else in the payload', () {
      // Rule 1. The server's contract is that the current-looking field is null
      // alongside the block; if a value somehow arrives anyway, the refusal is
      // still the answer. Otherwise a stale number could outrank the gate.
      final reading = numericReadingFrom(<String, Object?>{
        'value': 43.0,
        'caveats': [_disclosure('some_tilt')],
        'withheld': _disclosure('logged_weight_stale'),
      }, 'value');

      expect(reading, isA<Withheld<double>>());
      expect(reading.valueOrNull, isNull);
      expect((reading as Withheld<double>).disclosure.reason, 'logged_weight_stale');
    });

    test('no value and no explanation still becomes a Withheld, never a drop', () {
      // Rule 2. An absence the UI never hears about is the silence this design
      // exists against — so it is named, honestly, including that we do not know.
      final reading = numericReadingFrom(const <String, Object?>{'value': null}, 'value');

      expect(reading, isA<Withheld<double>>());
      final disclosure = (reading as Withheld<double>).disclosure;
      expect(disclosure.reason, unexplainedAbsenceReason);
      expect(disclosure.message, unexplainedAbsenceMessage);
    });

    test('no value plus exclusions is Excluded — permanent, not retryable', () {
      // Rule 3. "Nobody can price this, ever" is a different answer from "here
      // is what would bring it back", and the UI must not offer an action.
      final reading = numericReadingFrom(<String, Object?>{
        'value': null,
        'excluded': [_disclosure('sri_hazard_not_transportable')],
      }, 'value');

      expect(reading, isA<Excluded<double>>());
      expect((reading as Excluded<double>).exclusions.single.reason,
          'sri_hazard_not_transportable');
    });

    test('a value plus exclusions is Caveated — the exclusion narrows it', () {
      // The case worth stating plainly: `excluded` alongside a real number
      // describes levers left OUT of that number, not a refusal to report it.
      final reading = numericReadingFrom(<String, Object?>{
        'value': 34.3,
        'excluded': [_disclosure('sri_hazard_not_transportable')],
      }, 'value');

      expect(reading, isA<Caveated<double>>());
      expect(reading.valueOrNull, 34.3);
    });

    test('caveats and exclusions on a value are both carried, in that order', () {
      final reading = numericReadingFrom(<String, Object?>{
        'value': 34.3,
        'caveats': [_disclosure('a'), _disclosure('b')],
        'excluded': [_disclosure('c')],
      }, 'value');

      expect(
        (reading as Caveated<double>).caveats.map((d) => d.reason),
        <String>['a', 'b', 'c'],
      );
    });

    test('a disclosure missing its message is treated as absent, never invented', () {
      // A sentence we made up is worse than one we admit we did not receive.
      final reading = numericReadingFrom(const <String, Object?>{
        'value': null,
        'withheld': <String, Object?>{'reason': 'logged_weight_stale'},
      }, 'value');

      expect(reading, isA<Withheld<double>>());
      expect((reading as Withheld<double>).disclosure.reason, unexplainedAbsenceReason);
    });

    test('an entirely missing block is a Withheld, not a crash', () {
      expect(
        numericReadingFrom(const <String, Object?>{}, 'value'),
        isA<Withheld<double>>(),
      );
    });
  });

  group('Reading', () {
    test('map carries the honesty state through a value transform', () {
      // The step where a caveat would otherwise get dropped.
      final caveated = numericReadingFrom(<String, Object?>{
        'value': 43.0,
        'caveats': [_disclosure('a')],
      }, 'value');

      final mapped = caveated.map((value) => value.toStringAsFixed(1));

      expect(mapped, isA<Caveated<String>>());
      expect(mapped.valueOrNull, '43.0');
      expect((mapped as Caveated<String>).caveats.single.reason, 'a');
    });

    test('map on a refusal keeps the refusal and its reason', () {
      final withheld = numericReadingFrom(const <String, Object?>{'value': null}, 'value');
      final mapped = withheld.map((value) => value.toString());

      expect(mapped, isA<Withheld<String>>());
      expect((mapped as Withheld<String>).disclosure.reason, unexplainedAbsenceReason);
    });

    test('hasValue is true only for the two cases that carry one', () {
      expect(const Present<double>(1).hasValue, isTrue);
      expect(numericReadingFrom(const <String, Object?>{}, 'value').hasValue, isFalse);
    });
  });
}
