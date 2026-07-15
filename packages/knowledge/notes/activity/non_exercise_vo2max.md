---
id: non_exercise_vo2max
topic: Estimating VO2max without a maximal exercise test — Jurca model + HUNT3 update
evidence_grade: 2
applies_to_metrics: [vo2max_estimate, rhr_daily]
applies_to_interventions: []
tags: [methodology, vo2max, non-exercise-test]
last_reviewed: 2026-05-15
---

## Finding

Several validated non-exercise prediction models estimate VO2max from
demographic and behavioral inputs that are routinely available without
a treadmill / CPET. The most-cited and best-replicated is **Jurca et al.
2005** (n=2,801 healthy adults in the Aerobics Center Longitudinal
Study, ACLS, validated against measured VO2max). Inputs: age, sex,
BMI **or** waist circumference, resting heart rate, and a self-reported
physical-activity (SRPA) category. Cross-validation r ≈ 0.78.

The **HUNT3 model** (Nes 2011, Norway, n=4,637) updated the approach
with the same input shape but a population-calibrated equation. Both
models are widely used in research and clinical screening contexts
because they require no exercise testing.

**Evidence grade is ★★ (not ★★★)** — these are validated estimators,
not direct measurements. The mortality-effect-size literature in
[[vo2max_fitness_mortality]] is anchored on direct CPET measurement;
extending it to non-exercise estimates carries error.

## Effect size (accuracy of the estimator itself)

- **Jurca 2005**: r=0.78 (men), r=0.72 (women); SEE ≈ 5.6 ml/kg/min.
- **Nes 2011 (HUNT3)**: r=0.74; SEE ≈ 5.7 ml/kg/min.
- For comparison, direct CPET test-retest SEE is ~2–3 ml/kg/min, and
  a submaximal-exercise prediction (e.g., 1-mile walk test) is ~4
  ml/kg/min. So non-exercise estimates are noisier than submaximal
  but adequate for **tracking change within a person over time**.

## The Jurca 2005 equation (BMI-based, single model)

Jurca's model predicts **cardiorespiratory fitness in METs** from a single
equation in which sex is a *term* (not two sex-stratified equations). Convert
to VO2max with the standard 1 MET = 3.5 ml O₂ / kg / min:

```
CRF_METs = 18.07
          + 2.77  × sex          # sex = 1 if male, 0 if female
          - 0.10  × age          # years
          - 0.17  × BMI          # kg/m²  (waist-girth variant exists too)
          - 0.03  × RHR          # resting HR, bpm
          +         SRPA          # self-reported PA category, 0–4

VO2max_ml_kg_min = CRF_METs × 3.5     # floored at 20 in code
```

`SRPA` is Jurca's five-level self-reported physical-activity category (0–4):
- 0: inactive (essentially no regular activity)
- 1: very light activity
- 2: light-to-moderate activity
- 3: moderate weekly exercise (~1–3 h)
- 4: vigorous / high-volume weekly exercise (≥3 h)

In practice this project derives SRPA from observed data by mapping the
**weekly MVPA-equivalent** minutes to a 0–4 category. Weekly MVPA-equivalent
applies the WHO rule that one vigorous minute counts as two moderate
(`moderate + 2 × vigorous`; see [[cadence_intensity]] +
[[mvpa_minutes_mortality]]):
  - < 10 min/week → 0
  - 10–19 → 1
  - 20–59 → 2
  - 60–179 (1–3 h) → 3
  - ≥ 180 (>3 h) → 4
- this is a heuristic mapping; the model is robust to ±1 category noise.

A worked check: a median 40-year-old male, BMI 24, RHR 55, SRPA 0 →
CRF = 18.07 + 2.77 − 4.0 − 4.08 − 1.65 = 11.11 METs → **≈ 38.9 ml/kg/min**,
consistent with population medians for that age and sex.

## Evidence strength

- **Jurca R, Jackson AS, LaMonte MJ, et al.** *Assessing
  cardiorespiratory fitness without performing exercise testing.*
  Am J Prev Med 2005;29(3):185–193. Original validation, n=2,801,
  measured VO2max via maximal treadmill test.
- **Nes BM, Janszky I, Vatten LJ, Nilsen TI, Aspenes ST, Wisløff U.*
  *Estimating V̇O₂peak from a non-exercise prediction model: the
  HUNT Study, Norway.* Med Sci Sports Exerc 2011;43(11):2024–2030.
- **Wier LT, Jackson AS, Ayers GW, Arenare B.** *Nonexercise models
  for estimating VO2max with waist girth, percent fat, or BMI.*
  Med Sci Sports Exerc 2006;38(3):555–561. Independent replication.

## Caveats

- **★★ moderate** evidence: estimator-not-measurement, so error
  propagates into the mortality-framing claim. Display as "estimated"
  with uncertainty in the UI; do not present a single number to two
  decimal places.
- **Trend > level**: within-person change is the trustworthy signal
  (because individual error stays roughly constant). Cross-person
  comparisons or absolute-number interpretations are weaker.
- **Out-of-range inputs**: model was validated for ages 20–70, BMI
  16–45, RHR 40–100. Outside that, errors grow.
- **SRPA derivation**: mapping observed weekly MVPA-equivalent minutes to a
  0–4 category adds another small error layer. The model is robust but not
  immune.
- **Beta-blockers, atropine, conditioning extremes** can decouple RHR
  from VO2max; flag if known.

## Operational use

- Compute nightly (after midnight) using the previous 7-day MVPA-
  derived SRPA category, today's RHR, and `profile.py` age/sex/BMI.
- Write to `metric_sample` with `metric = vo2max_estimate`,
  `source = 'derived'`, anchored at 23:59 IST.
- On the dashboard show:
  - Latest 7-day median estimate with ±1 SEE range (~6 ml/kg/min)
  - 90-day trend sparkline
  - Age- and sex-percentile vs Mandsager 2018 table
- Flag as **estimate** in the UI label; cite this note + the
  underlying mortality note ([[vo2max_fitness_mortality]]).
- Use the trend (not the value) in the recommendations engine: e.g.,
  "Your VO2max estimate trended -2 ml/kg/min over the last 12 weeks
  while MVPA averaged below the 150-min target — adding even 30 min/
  week of vigorous activity historically reverses this in cohort
  studies."
