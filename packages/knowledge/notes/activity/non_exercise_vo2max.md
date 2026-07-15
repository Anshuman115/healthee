---
id: non_exercise_vo2max
name: "Non-exercise VO₂max estimate (Jurca 2005)"
topic: Estimating VO2max without a maximal exercise test — Jurca 2005 model + HUNT3 update, and the nightly non-exercise estimate
category: activity
grade: Probable
evidence_grade: 2
summary: "The fallback VO₂max estimator: a validated non-exercise model (Jurca 2005 METs equation from age, sex, BMI, resting HR and an activity category) that needs no treadmill test — r≈0.78, SEE≈5.6 mL/kg/min, good for within-person trend, never a measurement; computed nightly when there is no usable workout segment for the submaximal method."
aliases: ["non-exercise vo2max", "jurca", "jurca 2005", "hunt3", "non-exercise-test", "cardiorespiratory fitness estimate", "vo2max_estimate_plan", "non_exercise_vo2max", "methodology"]
tags: ["non-exercise vo2max", "jurca", "jurca 2005", "hunt3", "non-exercise-test", "cardiorespiratory fitness estimate", "vo2max_estimate_plan", "non_exercise_vo2max", "methodology"]
applies_to_metrics: ["vo2max_estimate", "rhr_daily"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
related: ["vo2max", "submaximal_vo2max", "mvpa_minutes_mortality", "cadence_intensity", "recovery_readiness", "resting_hr_health_marker"]
---

# Non-exercise VO₂max estimate (Jurca 2005)

## Summary

Several validated **non-exercise** prediction models estimate VO₂max from demographic
and behavioural inputs that are routinely available without a treadmill / CPET. The
most-cited and best-replicated is **Jurca et al. 2005** (n=2,801 healthy adults,
Aerobics Center Longitudinal Study, validated against measured VO₂max), which predicts
cardiorespiratory fitness in METs from **age, sex, BMI (or waist), resting heart rate,
and a self-reported physical-activity category**. Cross-validation **r ≈ 0.78, SEE ≈ 5.6
mL/kg/min** — noisier than a submaximal-exercise test but adequate for **tracking change
within a person over time**. In Healthee this is the **fallback tier** of the
`vo2max_estimate` metric: it keeps an honest number on screen on sedentary days when the
more-accurate submaximal HR-vs-pace method ([[submaximal_vo2max]]) has no usable
steady-state workout segment. It is always an **estimate**, never a measurement, and its
error must not be laundered into the CPET-anchored mortality framing (see [[vo2max]]).

## What it is

A non-exercise VO₂max model maps easily-collected inputs to an estimated aerobic
capacity without any exertion:

- **Jurca 2005** — inputs: age, sex, BMI **or** waist circumference, resting heart rate,
  and a self-reported physical-activity (SRPA) category. Cross-validation r ≈ 0.78.
- **HUNT3 model** (Nes 2011, Norway, n=4,637) — the same input shape with a
  population-calibrated equation; r ≈ 0.74.

Both are widely used in research and clinical screening because they require no exercise
testing. Both are **estimators, not measurements** — the mortality effect-size literature
([[vo2max]]) is anchored on directly-measured CPET fitness, and extending it to a
non-exercise estimate carries the estimator's error.

## Physiology / mechanism

The inputs are proxies for the physiological determinants of VO₂max. **Resting heart
rate** is an inverse marker of cardiac stroke volume and autonomic/aerobic conditioning
(a fitter heart pumps more per beat, so beats slower at rest). **BMI/waist** proxies the
fat mass a person must transport (relative VO₂max is per-kg). **Age** captures the ~1%/yr
decline in untrained adults. The **activity category** captures training dose. None of
these measures oxygen uptake directly — the model is a statistical composite calibrated
against measured VO₂max, which is why its error is larger than an exercise-based estimate.

## The evidence

- **[Probable]** **Jurca 2005 is a validated non-exercise VO₂max estimator** — original
  validation n=2,801, measured VO₂max via maximal treadmill test, cross-validation
  **r = 0.78 (men), r = 0.72 (women), SEE ≈ 5.6 mL/kg/min** [Jurca et al. 2005].
- **[Probable]** **HUNT3 replicates the approach** with a population-calibrated equation:
  **r = 0.74, SEE ≈ 5.7 mL/kg/min** [Nes et al. 2011].
- **[Probable]** **Independent replication** of non-exercise models with waist girth,
  percent fat, or BMI [Wier et al. 2006].
- **[Established] (context)** For comparison, **direct CPET test-retest SEE is ~2–3
  mL/kg/min**, and a submaximal-exercise prediction (e.g. 1-mile walk test) is ~4
  mL/kg/min. So non-exercise estimates are **noisier than submaximal but adequate for
  within-person change** — the trend, not the level, is the trustworthy signal.

**Evidence grade is ★★ (Probable), not ★★★** — these are validated estimators, not direct
measurements. The mortality-effect-size literature in [[vo2max]] is anchored on direct
CPET measurement; extending it to a non-exercise estimate carries error.

## How we compute it

### The Jurca 2005 equation (BMI-based, single model)

Jurca's model predicts **cardiorespiratory fitness in METs** from a single equation in
which sex is a *term* (not two sex-stratified equations). Convert to VO₂max with the
standard 1 MET = 3.5 mL O₂ / kg / min:

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
**weekly MVPA-equivalent** minutes to a 0–4 category. Weekly MVPA-equivalent applies the
WHO rule that one vigorous minute counts as two moderate (`moderate + 2 × vigorous`; see
[[cadence_intensity]] + [[mvpa_minutes_mortality]]):
  - < 10 min/week → 0
  - 10–19 → 1
  - 20–59 → 2
  - 60–179 (1–3 h) → 3
  - ≥ 180 (>3 h) → 4
- this is a heuristic mapping; the model is robust to ±1 category noise.

A worked check: a median 40-year-old male, BMI 24, RHR 55, SRPA 0 →
CRF = 18.07 + 2.77 − 4.0 − 4.08 − 1.65 = 11.11 METs → **≈ 38.9 mL/kg/min**,
consistent with population medians for that age and sex.

> **Note — a superseded variant.** An earlier implementation plan used a *sex-stratified*
> Jurca form (two equations: `56.363 + 1.921·pa − 0.381·age − 0.754·bmi − 0.084·rhr` for
> men, `50.513 + 1.589·pa − 0.289·age − 0.552·bmi − 0.085·rhr` for women) with a 0–7
> activity score. That variant was **corrected** to the genuine single-model METs equation
> above (the published Jurca 2005 form), which is now canonical; the sex-stratified
> variant and its 0–7 mapping are retained here only as a record of what was superseded.
> Do not reintroduce the sex-stratified formula.

### The nightly derivation (fallback tier of `vo2max_estimate`)

- **When**: computed nightly (after midnight), anchored to 23:59 IST of the calendar day,
  in the v2 `derive.py` pass. It runs as the **fallback** when the submaximal HR-vs-pace
  method ([[submaximal_vo2max]]) has no usable steady-state workout segment.
- **Inputs**:
  - `age` = today − DOB (from the profile).
  - `bmi` = latest weight / height² (latest logged `weight_kg` + profile height).
  - `rhr` = **7-day rolling median** of `rhr_daily`.
  - `SRPA` = mapped from the trailing 7-day MVPA-equivalent (`moderate_min + 2 ×
    vigorous_min`) to the 0–4 category above.
- **Dependencies**: MVPA derivation must be available first (SRPA needs the weekly
  MVPA-equivalent); the profile must carry `age`, `sex`, and either `bmi` or height+weight.
- **Output**: the `vo2max_estimate` metric (source `derived`), **floored at 20** in code.
- **Skip if any input is missing** — never write a wrong value. Also skip (show
  "Insufficient data") if the 7-day RHR **MAD > 8 bpm** or `weight_kg` is missing, since a
  noisy RHR or absent mass makes the estimate untrustworthy.

## How the coach uses it

- Report the **latest 7-day median estimate with a ±1 SEE band (~6 mL/kg/min)** plus a
  **90-day trend sparkline** and the **age/sex percentile** (vs the Mandsager 2018 norm
  table). Always label it an **estimate** and cite this note plus the fitness↔mortality
  evidence in [[vo2max]].
- Use the **trend, not the value**, in recommendations. Example: "Your VO₂max estimate
  trended −2 mL/kg/min over the last 12 weeks while MVPA averaged below the 150-min target
  — adding even 30 min/week of vigorous activity historically reverses this in cohort
  studies."
- Prefer the **submaximal estimate** ([[submaximal_vo2max]]) whenever a recent workout
  supplies a good steady-state HR+pace segment; this non-exercise model is the fallback
  that keeps a number on screen on sedentary days.

## Safety bounds

- This is a wellness estimate, **not a clinical measure** — never use it to clear anyone
  for hard training, to set race pace, or as a screening/diagnostic figure.
- Out-of-range inputs make it unreliable: the model was validated for **ages 20–70, BMI
  16–45, RHR 40–100**; outside those bounds error grows and the estimate should be flagged
  or withheld.

## Honesty & uncertainty

- **★★ moderate evidence: estimator, not measurement.** Error propagates into any
  fitness-framing claim. Display as "estimated" with uncertainty; do not present a single
  number to two decimal places.
- **Trend > level.** Within-person change is the trustworthy signal (individual error
  stays roughly constant); cross-person comparisons and absolute-number interpretations are
  weaker.
- **Out-of-range inputs** (ages, BMI, RHR outside the validated ranges) grow the error.
- **SRPA derivation** adds another small error layer (observed weekly MVPA-equivalent →
  0–4 category); the model is robust to ±1 category but not immune.
- **RHR confounders**: beta-blockers, atropine, and conditioning extremes decouple resting
  HR from VO₂max — flag if known.
- **Do not launder the estimate into a death-risk number.** The CRF↔mortality effect sizes
  in [[vo2max]] are CPET-anchored; this estimate carries ~5.6 mL/kg/min SEE on top.

## Bottom line

**Act on confidently:** Jurca 2005 is a validated, treadmill-free VO₂max estimator
(r≈0.78, SEE≈5.6) — good enough to track a person's own trend and a reasonable fallback
when no workout data exists. Trend over months, not the absolute number.

**Hold loosely:** the exact value for any individual (±~6 mL/kg/min), cross-person
comparisons, and the estimate for anyone outside the validated input ranges or on
HR-altering medication.

## Coach Directives

1. Compute the non-exercise estimate only as the **fallback** to the submaximal method;
   prefer [[submaximal_vo2max]] when a good steady-state workout segment exists.
   *(confidence: high)*
2. Always label the number an **estimate** with a ±SEE band; surface the **trend**, never
   the bare value. *(high)*
3. **Skip the derivation** (show "Insufficient data") when any input is missing, RHR 7-day
   MAD > 8 bpm, or weight is absent — never write a wrong value. *(high)*
4. Never present the estimate as a death-risk figure or use it to clear hard training; it
   is a wellness trend, not a clinical measure. *(high)*
5. Flag decoupling confounders (beta-blockers, atropine, out-of-range inputs) when known.
   *(moderate)*

## References

- **Jurca R, Jackson AS, LaMonte MJ, et al.** *Assessing cardiorespiratory fitness without
  performing exercise testing.* Am J Prev Med 2005;29(3):185–193. Original validation,
  n=2,801, measured VO₂max via maximal treadmill test.
- **Nes BM, Janszky I, Vatten LJ, Nilsen TI, Aspenes ST, Wisløff U.** *Estimating V̇O₂peak
  from a non-exercise prediction model: the HUNT Study, Norway.* Med Sci Sports Exerc
  2011;43(11):2024–2030.
- **Wier LT, Jackson AS, Ayers GW, Arenare B.** *Nonexercise models for estimating VO2max
  with waist girth, percent fat, or BMI.* Med Sci Sports Exerc 2006;38(3):555–561.
  Independent replication.

## Healthee implementation & honesty policy

- **Derived field: `vo2max_estimate`** (mL/kg/min), the **non-exercise fallback tier**.
  Computed nightly in the v2 `derive.py` pass, anchored 23:59 IST, `source = 'derived'`,
  **floored at 20** in code. Inputs: profile age/sex, BMI from latest `weight_kg` +
  height, 7-day rolling median of `rhr_daily`, and SRPA mapped from the trailing 7-day
  MVPA-equivalent (`moderate_min + 2 × vigorous_min`).
- **Ordering**: depends on the MVPA derivation (for SRPA) and on `rhr_daily`; the energy
  derivation depends in turn on `vo2max_estimate` (see [[energy_expenditure_derivation]]),
  so this runs before it in the derive pass.
- **The canonical formula is the corrected single-model Jurca METs equation** above. The
  older sex-stratified variant (and its 0–7 activity score) is **superseded** and must not
  be reintroduced.
- **`/api/today` payload** carries the estimate, `see_ml_kg_min` (± SEE), a 90-day trend,
  `age_percentile` (vs Mandsager 2018 age/sex quintiles, a small hard-coded norm table —
  approximate, not clinical), the citing research notes, and the as-of date. The UI shows
  the hero value with the ±SEE band always visible, the percentile subtext, the 90-day
  sparkline (±SEE in the tooltip), an "estimate, non-exercise model" label, and a
  "trend matters more than the absolute number" footer.
- **Honesty rules (carry into UI + LLM)**: always "estimate"; never a two-decimal number;
  trend over months is the signal; never a death-risk figure; never a cross-person
  comparison; withhold when inputs are missing/out-of-range or RHR is too noisy.
- **Out of scope**: a true submaximal-*test* VO₂max (cycling at a known wattage, etc.) is
  not feasible from the strap; the accurate active-user path is the free-living submaximal
  HR-vs-pace estimator ([[submaximal_vo2max]]). HRmax-formula refinement (220−age vs
  Tanaka) does **not** affect this metric — the Jurca model does not use HRmax.
