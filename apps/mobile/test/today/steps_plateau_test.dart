/// The step band, checked against the note it was transcribed from.
///
/// **This is the guard the last wrong step target did not have.** Legacy put
/// `~7,500/day` in a `metric_info` explainer, where `insights/validator.py`
/// calibrates against a cited note's grade and cannot see a Dart string — so a
/// number in no note at all served for months and under-targeted this owner by
/// about 2,500 steps a day.
///
/// `steps_plateau.dart` is Dart too. What makes it different is this file: the
/// numbers are read out of `packages/knowledge/notes/activity/steps_mortality.md`
/// at test time, so the transcription cannot drift from its source without the
/// suite saying so. A deterministic surface is guarded by a test, not by the
/// citation validator.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/features/today/steps_plateau.dart';

/// The note this band is transcribed from, found from the test's own directory
/// so it does not depend on where the runner was started.
File get _note {
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    final candidate = File(
      '${dir.path}/packages/knowledge/notes/activity/steps_mortality.md',
    );
    if (candidate.existsSync()) {
      return candidate;
    }
    dir = dir.parent;
  }
  throw StateError('steps_mortality.md not found above ${Directory.current}');
}

void main() {
  group('the band is the note’s, not ours', () {
    late String note;

    setUpAll(() => note = _note.readAsStringSync());

    test('THE NOTE IS THE ONE THIS FILE CLAIMS TO CITE', () {
      expect(note, contains(kStepsPlateauNoteId));
    });

    test('THE TWO BANDS AND THE AGE THEY SPLIT AT ARE THE NOTE’S', () {
      // `- For adults **<60 years**: benefit plateau ≈ 8,000–10,000 steps/day.`
      // `- For adults **≥60 years**: benefit plateau ≈ 6,000–8,000 steps/day.`
      expect(note, contains('$kStepsPlateauAgeSplit'));
      expect(
        note,
        contains('8,000–${_grouped(kStepsPlateauTopUnder60)}'),
        reason: 'the under-60 plateau tops out where this file says it does',
      );
      expect(
        note,
        contains('6,000–${_grouped(kStepsPlateauTopFrom60)}'),
        reason: 'and the 60-plus one',
      );
    });

    test('THE NOTE FORBIDS THE FLAT 10,000, AND THIS DERIVES IT INSTEAD', () {
      // The directive, verbatim: *"Do not present "10,000 steps" as a target."*
      // Honouring it is not refusing the number — it is refusing to TYPE it.
      // Under 60 the band's own top IS 10,000, so an owner of 32 sees exactly
      // that figure, and turns 60 into 8,000 without anyone editing a constant.
      expect(note, contains('marketing artifact'));
      expect(stepsPlateauTop(32), 10000);
      expect(stepsPlateauTop(59.9), 10000);
      expect(stepsPlateauTop(60), 8000);
      expect(stepsPlateauTop(74), 8000);
    });

    test('AN AGE NOTHING HAS READ IS NOT AN AGE UNDER 60', () {
      // Null rather than a default. A tile with no denominator draws no meter,
      // which is what it did before this file existed and remains the honest
      // answer — a guessed band is the failure this whole file exists to avoid.
      expect(stepsPlateauTop(null), isNull);
      expect(stepsPlateauTop(double.nan), isNull);
      expect(stepsPlateauTop(double.infinity), isNull);
    });
  });
}

/// `10000` → `10,000`, the way the note writes its figures.
String _grouped(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
