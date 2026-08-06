/// The movement, fitness and composite explainers.
///
/// Legacy's copy, corrected against `packages/knowledge` and cited. Three of the
/// corrections here are the file's worst:
///
///   * **`energy` printed `~1,760/day` as "the calories your body burns at
///     rest".** `grep -rn "1760"` over the whole repo returns that string in one
///     place: the explainer itself. BMR is per-owner — Mifflin–St Jeor over the
///     profile and the last logged weight, upserted as `basal_calories` by
///     `derive/energy.py` — so every owner was shown a number belonging to
///     nobody, on the one card whose whole job is to say where the calories came
///     from.
///   * **`steps_total` claimed risk falls "up to ~7,500 steps/day".** That number
///     is in no note in the corpus. What Paluch 2022 reports, quoted in
///     `steps_mortality` and primary-source verified, is an **age-banded**
///     plateau: 8,000–10,000/day under 60, 6,000–8,000 at 60+. An owner under 60
///     was being under-targeted by up to 2,500 steps.
///   * **`biological_age` said the estimate was built from "sleep duration &
///     regularity".** The regularity term was **removed** on 2026-08-01 (#86) —
///     `compute_biological_age` reads no SRI row and a test fails the build if it
///     does — and the note's directive is *"never imply sleep regularity is in
///     this number"*. The explainer implied it, and named it a top lever.
///
/// `cardio_load` described the strain scale as anchored to "YOUR own min/max
/// days". `training_stress_score` names min/max as the design it rejected: the
/// anchor is the rolling 90-day **P95**, so a quiet day reads low instead of
/// zero and one freak day cannot peg the scale.
library;

import 'package:healthee/shared/metric_info/metric_info.dart';

/// Movement, fitness, and the two composites.
const Map<String, MetricInfo> kBodyExplainers = <String, MetricInfo>{
  'energy': MetricInfo(
    title: 'Energy — active calories',
    what:
        'Calories you burned through movement, on top of what your body burns at '
        'rest just to stay alive (BMR). Your BMR is estimated from your height, age '
        'and the weight you last logged — it is not a fixed number and not '
        'everyone’s.',
    target:
        'No fixed target — it simply reflects how active your day was. The weekly '
        'trend matters more than any single day, and the figure is an estimate: '
        'individual error runs around ±15–20%.',
    why:
        'Estimated from what you were doing (the MET method anchored to your BMR), '
        'not from heart rate. A heart-rate model cannot separate movement from '
        'sitting, stress or heat, and on a real free-living day it overcounts by '
        'two to three times.',
    notes: <String>['energy_expenditure_derivation', 'weight_bmi_body_composition'],
    uncited:
        'If your logged weight is old, the BMR under this number is old too — '
        'about 0.6% per kilogram out of date.',
  ),
  'steps_total': MetricInfo(
    title: 'Steps',
    what:
        'Total steps today — the simplest measure of daily movement. Wrist counting '
        'is noisier than a hip-worn counter, so treat the daily total as an '
        'estimate.',
    target:
        'The benefit plateau is age-banded: about 8,000–10,000 a day under 60, and '
        '6,000–8,000 from 60. The 10,000 target is a marketing artefact, not a '
        'clinical threshold.',
    why:
        'Across 15 international cohorts, more daily steps track with better '
        'long-term health, roughly log-linear until that plateau and then flat '
        '(Paluch 2022). Pace adds nothing beyond total volume — the intensity '
        'picture is the active-minutes card, not this one.',
    notes: <String>['steps_mortality', 'sedentary_mortality', 'mvpa_minutes_mortality'],
  ),
  'mvpa': MetricInfo(
    title: 'Active minutes (MVPA)',
    what:
        'Minutes spent moving briskly enough to raise your heart rate. We infer the '
        'intensity from your step cadence — roughly 100 steps/min for moderate and '
        '130 for vigorous — so these are estimated minutes, not measured ones.',
    target:
        'At least 150 min/week is a floor, not a ceiling; the benefit keeps growing '
        'to about 300. Vigorous minutes count double, which is the guideline’s '
        'practical simplification rather than a precise biological trade.',
    why:
        'The 150-minute target is WHO 2020. Pooled across 196 prospective studies, '
        'reaching it tracks with roughly 22–31% lower all-cause mortality versus '
        'none, and with less cardiovascular disease and cancer. Even short bursts '
        'count — a few vigorous minutes a day, in one- and two-minute bouts, is a '
        'real signal on its own.',
    notes: <String>[
      'mvpa_minutes_mortality',
      'mvpa_weekly_plan',
      'cadence_intensity',
      'exercise_mortality',
    ],
  ),
  'cardio_load': MetricInfo(
    title: 'Strain · cardio load',
    what:
        'How much cardiovascular work your heart did today. The 0–21 "strain" puts '
        'that load on a personal scale where 21 is the 95th percentile of your own '
        'last 90 days — so about one day in twenty goes past it, and 0 is a rest '
        'day.',
    target:
        'No single "right" number — aim for consistency and gradual build-up. A '
        'strain well above your usual is a hard day; balance it with recovery and '
        'sleep.',
    why:
        'Built from Banister’s training-impulse method (1991) — minutes weighted by '
        'heart-rate reserve, with HR-max from Tanaka 2001. Your HR-max is estimated '
        'and an individual can sit 10–20 bpm either side of it, so the direction '
        'and the day-to-day change are the trustworthy parts, not the absolute '
        'number. It measures cardiovascular load only: lifting, isometrics and very '
        'short maximal efforts are under-credited.',
    notes: <String>[
      'training_stress_score',
      'maximum_heart_rate',
      'load_currency',
      'heart_rate_zones',
    ],
  ),
  'vo2max': MetricInfo(
    title: 'VO₂max — cardio fitness',
    what:
        'How well your body uses oxygen during hard effort — the strongest '
        'modifiable predictor of long-term mortality we know of. This is an '
        'ESTIMATE, not a lab test: individual error runs to several ml/kg/min, and '
        'the card names which method produced it.',
    target:
        'Higher is better. The line on the card is the 50th percentile of a '
        'published clinical treadmill reference (Kaminsky 2022) for your age and '
        'sex — a reference standard, which is not the same thing as the middle of '
        'the population.',
    why:
        'In 122,007 adults given treadmill tests, the fittest had about 80% lower '
        'all-cause mortality than the least fit, and low fitness carried more risk '
        'than smoking, diabetes or high blood pressure did in that same population '
        '(Mandsager 2018). It is one of three determinants of race performance and '
        'usually the least discriminating of them among trained runners — this is a '
        'health number more than a performance one.',
    notes: <String>[
      'vo2max',
      'non_exercise_vo2max',
      'submaximal_vo2max',
      'biological_age_estimate',
    ],
    uncited:
        'When no measured session is fresh, the estimate falls back to a '
        'questionnaire model whose inputs include an activity level you told us. '
        'One step on that scale is worth a couple of years of biological age.',
  ),
  'biological_age': MetricInfo(
    title: 'Biological age (estimate)',
    what:
        'A motivational estimate of how old your body "acts", built from TWO levers '
        '— your fitness and your sleep duration. Each one’s mortality hazard is '
        'converted into years using the Gompertz law (death hazard doubles about '
        'every 7.7 years), the same actuarial maths behind research clocks like '
        'PhenoAge.',
    target:
        'Lower than your real age is the goal, and the breakdown shows which of the '
        'two levers is adding or removing years. Treat a few years either way as '
        'noise; each term is capped at ±10 years because the fitness input is the '
        'least certain one.',
    why:
        'The conversion is published actuarial maths and every hazard ratio going '
        'into it is meta-analytic. It is still a novel assembly rather than a '
        'validated clock, it leans on the VO₂max ESTIMATE, and it is a population '
        'trend — never a clinical or diagnostic age.',
    notes: <String>[
      'biological_age_estimate',
      'vo2max',
      'sleep_duration_mortality',
    ],
    uncited:
        'Sleep REGULARITY is deliberately not priced in here — no regularity score '
        'converts to a hazard across scoring pipelines — so a change in it will not '
        'move this number. The sleep hours are also converted to their '
        'questionnaire equivalent first, which shifts the low-risk point below '
        'seven hours; do not read that as a recommendation.',
  ),
};
