/// **Every claim on a metric explainer is grounded, or is visibly not.**
///
/// This is the file that would have caught the defect it was written for. The
/// explainers cited literature in prose — "Cappuccio 2010", "Paluch 2022",
/// "Windred 2024" — with no note id, so nothing in the product could check them,
/// and the audit that finally did found three citations the corpus refutes
/// outright and six sentences a model would have been blocked from writing.
///
/// Prose citations are exactly what cannot be tested. Ids can, so the ids are
/// what the code carries and the prose stops carrying the weight alone.
///
/// The tests are written so that **removing the grounding fails them**, not so
/// that the current shape passes: an explainer with no notes fails; a note id
/// the corpus does not have fails; and a claim of grounding with nothing behind
/// it fails.
///
/// This file holds the **structural** half. The individual sentences — each
/// refuted number named so it cannot come back by a copy-paste from legacy —
/// moved to `metric_info_claims_test.dart` at the 400-line gate when the
/// 2026-09-08 knowledge audit added seven more. The split is by responsibility:
/// here, whether the grounding EXISTS and means what it says; there, whether
/// each claim is the one the corpus makes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/shared/format/note_grades.dart';
import 'package:healthee/shared/format/note_names.dart';
import 'package:healthee/shared/metric_info/metric_info.dart';

void main() {
  test('EVERY EXPLAINER CITES AT LEAST ONE REAL CORPUS NOTE', () {
    // The whole defect in one assertion. Seventeen screenfuls of interpretive
    // claims shipped with zero note ids; this fails if any of them regresses to
    // that, and it fails loudly for a new explainer added without doing the
    // reading.
    expect(kMetricInfo, isNotEmpty);
    for (final entry in kMetricInfo.entries) {
      expect(
        entry.value.notes,
        isNotEmpty,
        reason: '${entry.key} makes interpretive claims and cites nothing',
      );
    }
  });

  test('NO EXPLAINER CITES A NOTE THE CORPUS DOES NOT HAVE', () {
    // An id that looks plausible and resolves to nothing is worse than no id:
    // the chip renders the raw snake_case, and a reader sees a source where
    // there is none. `note_names_test.dart` proves these tables ARE the corpus.
    for (final entry in kMetricInfo.entries) {
      for (final id in entry.value.notes) {
        expect(
          kNoteNames,
          contains(canonicalNoteId(id)),
          reason: '${entry.key} cites "$id", which is not a note',
        );
        expect(
          noteName(id),
          isNotNull,
          reason: '${entry.key}: "$id" would render as a raw id',
        );
      }
    }
  });

  test('EVERY EXPLAINER RESOLVES TO A GRADE, so none renders ungraded', () {
    // A grade is not decoration here — it is what tells the reader how hard to
    // lean on the sentence above it. `weakestGrade` returns null for any id it
    // cannot resolve, so this is also a second, independent check on the ids.
    for (final entry in kMetricInfo.entries) {
      final grade = weakestGrade(entry.value.notes);
      expect(grade, isNotNull, reason: '${entry.key} would render no grade');
      expect(kGradeRank, contains(grade), reason: '${entry.key}: $grade');
    }
  });

  test('NOTHING BELOW “Probable” REACHES A CARD unhedged', () {
    // A Contested note does not get to prescribe (conventions.md: present as
    // debated). The sleep-consistency explainer used to tell the owner to "skip
    // long catch-up naps" — habitual napping is graded Contested, genuinely
    // disputed with reverse causation unresolved. The advice is gone; if a
    // Contested or Myth note is ever cited here, this stops it silently.
    for (final entry in kMetricInfo.entries) {
      final grade = weakestGrade(entry.value.notes)!;
      expect(
        kGradeRank[grade],
        greaterThanOrEqualTo(2),
        reason: '${entry.key} rests on $grade evidence and speaks plainly',
      );
    }
  });

  test('`uncited` names only what the sources really do NOT cover', () {
    // Audit A9: the field was used backwards in four places, so the sheet printed
    // "Not covered by those sources: …" over sentences quoted verbatim FROM those
    // sources — the 0.6%-per-kilogram figure is `energy_expenditure_derivation`
    // :132-133 word for word, the intraday decay is `recovery_readiness` :198-205
    // and :409-410, the regularity exclusion and the questionnaire conversion are
    // `biological_age_estimate` :64-68/:117-120/:244-252, and the SR-PA step cost
    // is `non_exercise_vo2max` D6/D7.
    //
    // A disclaimer that fires on the wrong claims is worse than none: it teaches
    // the reader that the label carries no information. Each of those four moved
    // into the prose, where a sourced claim belongs.
    for (final key in const <String>[
      'energy',
      'recovery_score',
      'vo2max',
      'biological_age',
    ]) {
      expect(
        kMetricInfo[key]!.uncited,
        isEmpty,
        reason: '$key claims a gap its own cited notes fill',
      );
    }
    // And the claims themselves survive the move — they were not tidied away.
    expect(kMetricInfo['energy']!.what, contains('0.6%'));
    expect(kMetricInfo['recovery_score']!.target.toLowerCase(), contains('battery'));
    expect(kMetricInfo['vo2max']!.what.toLowerCase(), contains('questionnaire'));
    expect(kMetricInfo['biological_age']!.why.toLowerCase(), contains('questionnaire'));
  });

  test('the VO₂max card does not flatten the uneven SR-PA steps', () {
    // `non_exercise_vo2max` D7: "use the published steps (0.32 / 0.74 / 0.70 /
    // 1.27 METs ≈ 0.6 / 1.3 / 1.3 / 2.3 years). Do NOT say the model is robust to
    // a one-category error — the steps are uneven and the largest is four times
    // the smallest." The card said "a couple of years", flatly, which is the
    // averaging the directive forbids.
    final what = kMetricInfo['vo2max']!.what.toLowerCase();
    expect(what, isNot(contains('a couple of years')));
    expect(what, contains('uneven'));
    expect(what, contains('half a year'));
    expect(what, contains('two and a half years'));
  });

  test('MUTATION — a claim with no corpus note must not render as though cited', () {
    // The rule the brief names: real-or-absent. This proves the two states are
    // actually distinguishable — that `uncited` is a real field carrying real
    // sentences and not an unused parameter that would let an unsourced claim
    // sit silently under a row of four sources.
    final withGaps = <String>[
      for (final entry in kMetricInfo.entries)
        if (entry.value.uncited.isNotEmpty) entry.key,
    ];
    expect(
      withGaps,
      isNotEmpty,
      reason: 'Not one explainer admits a gap — the audit found several',
    );
    // The specific gaps, named. Each is a threshold or a constant WE chose, and
    // each is the kind of thing a citation row would otherwise appear to cover.
    expect(withGaps, contains('sleep_health')); // ≥85% and SRI ≥ 70 are ours
    expect(withGaps, contains('sleep_debt')); // 0.5× credit, 14-night window
    expect(withGaps, contains('sleep_consistency')); // SRI does not transport
    expect(withGaps, contains('hrv')); // the ±1 SD band is unsourced
    for (final key in withGaps) {
      expect(
        kMetricInfo[key]!.uncited.length,
        greaterThan(30),
        reason: '$key admits a gap in too few words to be an admission',
      );
    }
  });
}
