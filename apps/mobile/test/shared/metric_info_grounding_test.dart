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
/// the corpus does not have fails; a claim of grounding with nothing behind it
/// fails; and the refuted numbers are named individually so they cannot come
/// back by a copy-paste from legacy.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/shared/format/note_grades.dart';
import 'package:healthee/shared/format/note_names.dart';
import 'package:healthee/shared/metric_info/metric_info.dart';

/// Every field of an explainer that is shown to an owner, as one string.
String _prose(MetricInfo info) =>
    '${info.title}\n${info.what}\n${info.target}\n${info.why}\n${info.uncited}';

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
    expect(withGaps, contains('biological_age')); // regularity is NOT priced
    expect(withGaps, contains('recovery_score')); // the intraday decay model
    for (final key in withGaps) {
      expect(
        kMetricInfo[key]!.uncited.length,
        greaterThan(30),
        reason: '$key admits a gap in too few words to be an admission',
      );
    }
  });

  group('the refuted claims, named so they cannot come back', () {
    // Each of these was on screen. They are asserted individually rather than by
    // one regex sweep, because the failure message is the point: a reviewer who
    // trips one of these should read WHY, not just that a string matched.

    test('steps does not claim a ~7,500/day plateau', () {
      // The number appears nowhere in the corpus. `steps_mortality` reports an
      // AGE-BANDED plateau, primary-source verified: 8,000–10,000 under 60,
      // 6,000–8,000 at 60+.
      final steps = _prose(kMetricInfo['steps_total']!);
      expect(steps, isNot(contains('7,500')));
      expect(steps, isNot(contains('7500')));
      expect(steps, contains('8,000–10,000'));
      expect(steps, contains('6,000–8,000'));
    });

    test('resting HR carries no personal death-risk number', () {
      // `resting_heart_rate` D13 forbids the sentence shape, and is the declared
      // source of the live `personal_death_risk_number` output rule. The old
      // copy also had the wrong number: 16%, where Aune is 17% and Zhang is 9%.
      final rhr = _prose(kMetricInfo['rhr_daily']!);
      expect(rhr, isNot(contains('16%')));
      expect(rhr.toLowerCase(), isNot(contains('risk of early death')));
      // And the band is the general-adult one, not the trained-runner row.
      expect(rhr, contains('60–100'));
    });

    test('steps and MVPA carry no death-risk number either', () {
      // Same directive, two more notes: `steps_mortality` D4 and
      // `mvpa_minutes_mortality` D4 — "never show a death-risk number".
      for (final key in const <String>['steps_total', 'mvpa']) {
        expect(
          _prose(kMetricInfo[key]!).toLowerCase(),
          isNot(contains('risk of early death')),
          reason: key,
        );
      }
    });

    test('biological age does not claim sleep regularity is a term', () {
      // #86 removed it on 2026-08-01. `compute_biological_age` reads no SRI row
      // and a server test fails the build if it does; the note's directive is
      // "never imply sleep regularity is in this number". The explainer said it
      // was one of the two biggest levers.
      final bio = kMetricInfo['biological_age']!;
      expect(bio.what.toLowerCase(), isNot(contains('regularity')));
      expect(bio.target.toLowerCase(), isNot(contains('regularity')));
      expect(bio.why.toLowerCase(), isNot(contains('regularity')));
      // It is named in `uncited` instead — as a lever this number does NOT price.
      expect(bio.uncited.toLowerCase(), contains('regularity'));
      expect(bio.uncited.toLowerCase(), contains('not priced'));
    });

    test('stress claims neither an HRV derivation nor an emotion', () {
      // `wearable_stress_validity`: heart-rate-dominated, not HRV-driven
      // [Established]; and D2 is SAFETY-CRITICAL — never infer mood or valence.
      // "fight-or-flight" is precisely the valence attribution it forbids.
      final stress = _prose(kMetricInfo['stress']!).toLowerCase();
      expect(stress, isNot(contains('fight-or-flight')));
      expect(stress, isNot(contains('derives from heart-rate variability')));
      expect(stress, contains('arousal'));
      // And it says the thing the note's D4 requires and the old copy omitted.
      expect(stress, contains('validated on our huami/zepp hardware'));
    });

    test('SpO₂ routes at ~92% and names the dark-skin bias', () {
      // The old copy said 95–100% is normal and below 90% is worth a doctor.
      // The note routes at ~92%, calls that a clinical convention rather than a
      // validated cutoff, and grades the pigmentation bias [Established].
      final spo2 = _prose(kMetricInfo['spo2']!);
      expect(spo2, contains('92%'));
      expect(spo2, isNot(contains('95–100%')));
      expect(spo2.toLowerCase(), contains('darker skin'));
      expect(spo2.toLowerCase(), isNot(contains('below 90%')));
    });

    test('energy shows no hardcoded BMR', () {
      // `~1,760/day` existed in exactly one place in the whole repo: this map.
      // BMR is per-owner (Mifflin–St Jeor over profile + last logged weight) and
      // already ships as `basal_calories`.
      final energy = _prose(kMetricInfo['energy']!);
      expect(energy, isNot(contains('1,760')));
      expect(energy, isNot(contains('1760')));
      expect(energy.toLowerCase(), contains('last logged'));
    });

    test('sleep attributes the 7–9 h band to the consensus, not the meta-analysis', () {
      // `sleep_duration_mortality` carries a standing warning: "Do not quote a
      // reference band from this note. Cappuccio 2010 states none." The band is
      // NSF 2015. The U-shape is Cappuccio's and stays with him.
      final sleep = kMetricInfo['sleep']!;
      expect(sleep.target, contains('7–9'));
      expect(sleep.target, isNot(contains('Cappuccio')));
      expect(sleep.target.toLowerCase(), contains('sleep foundation'));
      expect(sleep.why, contains('Cappuccio 2010'));
      expect(sleep.why.toLowerCase(), contains('u-shape'));
    });

    test('sleep health does not claim to beat a sleep score', () {
      // That comparison has never been run, and the corpus reports the composite
      // losing to its own best component. What IS Established is that no
      // validated composite exists — which is the part worth saying.
      final health = _prose(kMetricInfo['sleep_health']!);
      expect(health, isNot(contains('track health better')));
      expect(health.toLowerCase(), contains('no peer-reviewed composite'));
      expect(kMetricInfo['sleep_health']!.notes, contains('no_validated_sleep_score'));
    });

    test('sleep debt claims alertness, not mood', () {
      // Van Dongen's endpoints are cognitive/alertness. `sleep_need_debt` says
      // so three times, including in its safety bounds.
      final debt = kMetricInfo['sleep_debt']!;
      expect(debt.why.toLowerCase(), isNot(contains('mood')));
      expect(debt.why.toLowerCase(), contains('cognitive'));
      expect(debt.uncited.toLowerCase(), contains('not for mood'));
    });

    test('cardio load anchors the scale to a percentile, not to min/max', () {
      // `training_stress_score` names min/max as the design it REJECTED: the
      // anchor is the rolling 90-day P95, so a quiet day reads low rather than
      // zero and one freak day cannot peg the scale.
      final load = _prose(kMetricInfo['cardio_load']!);
      expect(load.toLowerCase(), isNot(contains('min/max')));
      expect(load, contains('95th percentile'));
    });

    test('the two recovery explainers agree about whether a score ships', () {
      // They contradicted each other on the same screen: `recovery` said we
      // "never" invent a readiness number, while `recovery_score` — three
      // entries up — described exactly that number. One of them was lying.
      final signals = _prose(kMetricInfo['recovery']!);
      expect(signals.toLowerCase(), isNot(contains('never an invented')));
      expect(signals.toLowerCase(), isNot(contains('not blended into one score')));
      expect(kMetricInfo['recovery_score']!.why.toLowerCase(), contains('estimate'));
      // Both must rest on the note that documents the exception.
      expect(kMetricInfo['recovery']!.notes, contains('recovery_readiness'));
      expect(kMetricInfo['recovery_score']!.notes, contains('recovery_readiness'));
    });
  });
}
