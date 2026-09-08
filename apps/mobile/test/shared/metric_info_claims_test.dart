/// The claims themselves — each defect named so it cannot come back.
///
/// Split out of `metric_info_grounding_test.dart` at the 400-line gate when the
/// 2026-09-08 knowledge audit added seven more. The split is by responsibility,
/// not by size: that file tests the **structure** of the grounding (every
/// explainer cites a real note, every id resolves, every grade resolves, the
/// `uncited` field means what it says), and this one tests the **sentences**.
///
/// They are asserted individually rather than by one regex sweep, because the
/// failure message is the point: a reviewer who trips one of these should read
/// WHY, not just that a string matched. The two sweeps that ARE derived — the
/// death-risk shape and the grade floor — say so where they sit.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/shared/metric_info/metric_info.dart';

/// Every field of an explainer that is shown to an owner, as one string.
String _prose(MetricInfo info) =>
    '${info.title}\n${info.what}\n${info.target}\n${info.why}\n${info.uncited}';

void main() {
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

    test('biological age names sleep regularity only as a lever it does NOT price', () {
      // #86 removed the term on 2026-08-01. `compute_biological_age` reads no SRI
      // row and a server test fails the build if it does; the note's directive is
      // "never imply sleep regularity is in this number". The explainer said it
      // was one of the two biggest levers.
      //
      // The exclusion now sits in `why` rather than in `uncited`, and that is the
      // point of the change: `biological_age_estimate.md:64-68,117-120` states it
      // twice, so "Not covered by those sources" was printing over a claim the
      // sources make in as many words (audit A9). The two blocks where the OLD
      // defect lived stay clean; the `why` must carry the exclusion out loud.
      final bio = kMetricInfo['biological_age']!;
      expect(bio.what.toLowerCase(), isNot(contains('regularity')));
      expect(bio.target.toLowerCase(), isNot(contains('regularity')));
      expect(bio.why.toLowerCase(), contains('regularity'));
      expect(bio.why.toLowerCase(), contains('not priced'));
      // And it must not have drifted back into the disclaimer it was moved out of.
      expect(bio.uncited, isEmpty);
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

    test('NO EXPLAINER PRINTS A DEATH-RISK PERCENTAGE', () {
      // The audit's first finding, and the sharpest: two cards printed a mortality
      // percentage that three and two of their own cited notes forbid outright —
      // `mvpa_minutes_mortality` D4 and its Safety bounds, `exercise_mortality` D1
      // ("never quantify mortality to the user"), `mvpa_weekly_plan`'s Safety
      // bounds, `non_exercise_vo2max` D4, and `vo2max.md`'s Safety bounds.
      //
      // `insights/output_guard.py`'s `personal_death_risk_number` blocks the MODEL
      // from writing exactly this, citing those same notes. The Dart strings were
      // the unguarded channel into the same screen.
      //
      // Derived, not a list of the two known strings: any "<n>% lower/higher
      // mortality/risk of death" shape, in any explainer, present or future.
      final deathRisk = RegExp(
        r'\d+\s*(?:[-–]\s*\d+\s*)?%[^.]{0,40}\b(?:mortality|risk of (?:death|dying)|'
        r'all-cause)',
        caseSensitive: false,
      );
      final alsoInverted = RegExp(
        r'\b(?:mortality|all-cause)[^.]{0,40}\d+\s*(?:[-–]\s*\d+\s*)?%',
        caseSensitive: false,
      );
      for (final entry in kMetricInfo.entries) {
        final prose = _prose(entry.value);
        expect(
          deathRisk.hasMatch(prose),
          isFalse,
          reason:
              '${entry.key} prints a death-risk number; its notes forbid it and '
              'output_guard blocks the model from writing the same sentence',
        );
        expect(alsoInverted.hasMatch(prose), isFalse, reason: entry.key);
      }
    });

    test('MVPA states the association without the number, as the steps card does', () {
      // The directive honoured to the letter is two entries above, on `steps_total`:
      // "more daily steps track with better long-term health … (Paluch 2022)". The
      // MVPA card broke the identical rule, which is what made it a lapse rather
      // than a house style.
      final mvpa = kMetricInfo['mvpa']!;
      expect(mvpa.why, isNot(contains('22–31%')));
      expect(mvpa.why.toLowerCase(), contains('lower all-cause mortality'));
      expect(mvpa.why, contains('196 prospective studies'));
      // And the upgrade from mortality to DISEASE INCIDENCE goes with it: the words
      // "cardiovascular disease and cancer" appear in the cited notes only inside a
      // bibliography entry — Garcia 2023's title — never in a graded body claim.
      expect(mvpa.why.toLowerCase(), isNot(contains('cancer')));
      expect(mvpa.why.toLowerCase(), isNot(contains('cardiovascular disease')));
    });

    test('VO₂max attributes to Mandsager 2018 only what that paper models', () {
      // `vo2max.md:209-210`: the hazard of LOW CRF "exceeded that of current
      // smoking, diabetes and end-stage renal disease modelled in the same
      // population [Mandsager et al. 2018]". Hypertension appears only in the
      // SEPARATE, general claim at :202-204. The card had spliced the two, swapped
      // ESRD for hypertension, and attributed the swap to the named cohort — a
      // citation that exists and does not support the claim.
      final vo2 = kMetricInfo['vo2max']!;
      final sentence = vo2.why.substring(
        vo2.why.indexOf('122,007'),
        vo2.why.indexOf('Mandsager 2018)') + 'Mandsager 2018)'.length,
      );
      expect(sentence.toLowerCase(), contains('end-stage renal disease'));
      expect(sentence.toLowerCase(), isNot(contains('blood pressure')));
      expect(sentence.toLowerCase(), isNot(contains('hypertension')));
      // The general comparison survives, unattributed to the cohort model.
      expect(vo2.why.toLowerCase(), contains('hypertension'));
      expect(vo2.why.indexOf('hypertension'), lessThan(vo2.why.indexOf('122,007')));
    });

    test('the sleep-health card owns the timing band it is actually sourced for', () {
      // The inverse of the usual defect: the card claimed LESS grounding than it
      // has. `sleep_score_implementation_plan.md:157-162` sources the [02:00,
      // 04:00) midpoint band to Buysse 2014's definitional cutoff, replicated in
      // Wallace 2017 and Lee 2022. Only SRI ≥ 70 is ours.
      final health = kMetricInfo['sleep_health']!;
      expect(health.uncited, isNot(contains('timing band and')));
      expect(health.uncited.toLowerCase(), contains('buysse'));
      expect(health.uncited.toLowerCase(), contains('sri ≥ 70 is ours'));
    });

    test('the sleep-health card says midpoint, not bedtime', () {
      // Read as a BEDTIME, 2–4 am is the window `sleep_timing_chronotype.md:54-57`
      // scores worst — so the ⓘ was telling the owner the app wants him in bed
      // between 2 and 4 in the morning. The dimension is the sleep MIDPOINT
      // (`read/sleep_common.py:24`, `timing_hour_band` over `midpoint_local`).
      final health = kMetricInfo['sleep_health']!;
      expect(health.what.toLowerCase(), contains('midpoint'));
      // The old copy listed "a healthy bedtime" as one of the four qualities. The
      // word may appear — saying "not on your bedtime" is the correction — but it
      // may never name the dimension.
      expect(health.what.toLowerCase(), isNot(contains('a healthy bedtime')));
      expect(health.what.toLowerCase(), contains('not on your bedtime'));
    });

    test('sleep consistency converts no SRI into a risk figure', () {
      // `sleep_regularity_index` D6, verbatim: "Never convert an SRI into risk,
      // years, or a biological-age contribution. The published hazard figures
      // belong to the software that scored the SRI; ours is a third pipeline."
      //
      // NOT in the audit — the corpus-wide sweep above found it. The card printed
      // "the steadiest sleepers sat around 30% lower all-cause risk", three lines
      // above its own `uncited` saying "none of its risk figures can be converted
      // into a number about you". It contradicted its own disclaimer.
      final consistency = kMetricInfo['sleep_consistency']!;
      expect(consistency.why, isNot(contains('30%')));
      expect(consistency.why.toLowerCase(), contains('predicted mortality more'));
      expect(consistency.uncited.toLowerCase(), contains('risk figures'));
    });

    test('the sleep-health card does not deny the count three lines above it', () {
      // It said the four checks "are never summed into a score" and then "Aim for
      // 4 / 4". The shipped composite IS the 0-4 count (`sleep_score.py:217`
      // writes `sleep_health_score_4dim`). The true statement, which
      // `no_validated_sleep_score.md:107-108` makes, is that it is never a 0-100
      // composite and the count always rides with its four dimensions.
      final health = kMetricInfo['sleep_health']!;
      expect(health.what.toLowerCase(), isNot(contains('never summed')));
      expect(health.what.toLowerCase(), contains('0–100'));
      expect(health.target, contains('4 / 4'));
    });

    test('the sleep-debt card prescribes no catch-up dose', () {
      // "Even an extra 30 min a night" is a sleep-extension dose that exists
      // nowhere in `notes/`; `sleep_need_debt.md:107-108` permits recommending —
      // not prescribing — catch-up, and nothing more specific.
      final debt = kMetricInfo['sleep_debt']!;
      expect(debt.target, isNot(contains('30 min')));
      expect(debt.target.toLowerCase(), contains('recommend'));
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
