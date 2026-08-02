---
id: non_exercise_vo2max
name: "Non-exercise VO₂max estimate (Jurca 2005)"
topic: Estimating VO2max without a maximal exercise test — Jurca 2005 model + HUNT3 update, and the nightly non-exercise estimate
category: activity
grade: Probable
summary: "The fallback VO₂max estimator: a validated non-exercise model (Jurca 2005 METs equation from age, sex, BMI, resting HR and a SELF-REPORTED activity category) that needs no treadmill test — R=0.81, SEE=1.45 METs ≈ 5.1 mL/kg/min in its development cohort, never a measurement; computed nightly when there is no usable workout segment for the submaximal method. The activity category is DUMMY-CODED (0 / 0.32 / 1.06 / 1.76 / 3.03 METs), not linear, and it is the OWNER'S OWN ANSWER — a device cannot supply it, and the estimate is withheld until they answer."
aliases: ["non-exercise vo2max", "jurca", "jurca 2005", "hunt3", "non-exercise-test", "cardiorespiratory fitness estimate", "vo2max_estimate_plan", "non_exercise_vo2max", "methodology"]
tags: ["non-exercise vo2max", "jurca", "jurca 2005", "hunt3", "non-exercise-test", "cardiorespiratory fitness estimate", "vo2max_estimate_plan", "non_exercise_vo2max", "methodology"]
applies_to_metrics: ["vo2max_estimate", "rhr_daily"]
applies_to_interventions: []
population: general
last_reviewed: 2026-08-02
related: ["vo2max", "submaximal_vo2max", "mvpa_minutes_mortality", "cadence_intensity", "recovery_readiness", "resting_hr_health_marker"]
---

# Non-exercise VO₂max estimate (Jurca 2005)

## Summary

Several validated **non-exercise** prediction models estimate VO₂max from demographic
and behavioural inputs that are routinely available without a treadmill / CPET. The
most-cited and best-replicated is **Jurca et al. 2005**, which predicts cardiorespiratory
fitness in METs from **age, sex, BMI (or waist), resting heart rate, and a self-reported
physical-activity category**. The equation we use is its **NASA model** (n=1,863 — 1,458
men and 405 women — Johnson Space Center, CRF measured by ventilatory gas analysis at
maximal exertion on a Bruce treadmill protocol): **R = 0.81, SEE = 1.45 METs ≈ 5.1
mL/kg/min**, cross-validating at R = 0.76 (ACLS) and 0.75 (ADNFS). Noisier than a
submaximal-exercise test. In Healthee this is the **fallback tier** of the
`vo2max_estimate` metric: it keeps an honest number on screen on sedentary days when the
more-accurate submaximal HR-vs-pace method ([[submaximal_vo2max]]) has no usable
steady-state workout segment. It is always an **estimate**, never a measurement, and its
error must not be laundered into the CPET-anchored mortality framing (see [[vo2max]]).

## What it is

A non-exercise VO₂max model maps easily-collected inputs to an estimated aerobic
capacity without any exertion:

- **Jurca 2005** — inputs: age, sex, BMI **or** waist circumference, resting heart rate,
  and a self-reported physical-activity (SR-PA) category. NASA model R = 0.81,
  cross-validating at 0.76 / 0.75 in the other two cohorts.
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

- **[Probable]** **Jurca 2005 is a validated non-exercise VO₂max estimator** — the NASA
  model (the one we implement) was fitted on n=1,863 with VO₂max measured by ventilatory
  gas analysis at maximal exertion: **R = 0.81, R² = 0.65, SEE = 1.45 METs ≈ 5.1
  mL/kg/min**, cross-validating at r = 0.76 (ACLS, n=46,190) and 0.75 (ADNFS, n=1,706)
  [Jurca et al. 2005, Tables 5–6].
  > **[Corrected 2026-08-02, #108.]** This note previously read "original validation
  > n=2,801, Aerobics Center Longitudinal Study … r = 0.78 (men), r = 0.72 (women),
  > SEE ≈ 5.6 mL/kg/min". None of those five figures is in the paper. The cohort is NASA,
  > not ACLS (ACLS has its own, different equation: intercept 18.81, sex 2.49, age −0.08,
  > RHR −0.05); n=2,801 appears nowhere; the paper reports one R per cohort, not
  > sex-stratified r; and 5.6 mL/kg/min is nobody's SEE — it sat just under the HUNT3
  > model's published 5.7 immediately below it, which is the likeliest way it got here.
  > The whole paper was read in full before this correction.
- **[Probable]** **The SEE is a WITHIN-cohort figure and understates the real error.**
  The same paper's Table 6 applies the NASA equation to the other two cohorts and finds
  **systematic residuals** — it underestimates CRF by 0.67 METs in ACLS and 1.37 METs in
  ADNFS. That is bias, not noise, and it does not shrink with more days of data. Reading
  1.45 METs as "the error" is the same mistake as reading a within-lab test-retest SD as
  a between-lab agreement.
- **[Probable]** **The estimate tracks a person's LEVEL better than their CHANGE.**
  Peterman et al. 2020 (*JAHA* 9(11):e015117) put 27 non-exercise equations against two
  real CPETs ≥3 months apart in 987 adults: for 16 of the 27 the estimated change
  differed significantly from the measured change, and the median share of people
  correctly classified as having increased / decreased / not changed was **56% (range
  39–61%)** — barely above the 33% a coin would manage on three categories. Their
  conclusion: estimated CRF "may have limited clinical utility" for detecting change.
  **This contradicts the "trend, not level" framing this note carries below**, which is
  inherited practice rather than a sourced claim; the trend is still the *less bad* of
  the two readings for a single person, but it is not the trustworthy one, and no
  movement smaller than the SEE should be spoken about at all.
- **[Probable]** **HUNT3 replicates the approach** with a population-calibrated equation:
  **r = 0.74, SEE ≈ 5.7 mL/kg/min** [Nes et al. 2011].
- **[Probable]** **Independent replication** of non-exercise models with waist girth,
  percent fat, or BMI [Wier et al. 2006].
- **[Established] (context)** For comparison, **direct CPET test-retest SEE is ~2–3
  mL/kg/min**, and a submaximal-exercise prediction (e.g. 1-mile walk test) is ~4
  mL/kg/min. Non-exercise estimates are the noisiest of the three.
  > *(Corrected 2026-08-02, #108.)* This bullet used to end "…but adequate for
  > within-person change — the trend, not the level, is the trustworthy signal", which
  > cited nothing and is contradicted by the one study that tested it directly (Peterman
  > 2020, above: ~56% of directions called correctly). The comparison of SEEs is sound;
  > the inference drawn from it was not.

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
          + SRPA_METS[srpa]      # DUMMY-CODED, see below — NOT the category number

VO2max_ml_kg_min = CRF_METs × 3.5     # floored at 20 in code
```

### SR-PA is dummy-coded, and the coefficients are uneven

Jurca's Methods say the model uses "**the dummy-coded five-category SR-PA scale according
to the Pedhauzur method**". SR-PA-0 is the reference level and is absorbed into the
intercept; the other four carry their own published weights (Table 5, NASA column):

| level | Jurca's own description (NASA arm, Table 1) | METs added |
|---|---|---|
| 0 | Little activity other than walking **for pleasure** | **0.00** (reference) |
| 1 | Some regular participation in modest physical activities involving sports, recreational activities | **0.32** |
| 2 | Aerobic exercise such as run/walk for **20 to 60 minutes per week** | **1.06** |
| 3 | Aerobic exercise such as run/walk for **1 to 3 hours per week** | **1.76** |
| 4 | Aerobic exercise such as run/walk for **>3 hours per week** | **3.03** |

> **[Corrected 2026-08-02, #108.]** This note used to print `+ SRPA` and the code added
> the **category number** — 0/1/2/3/4 METs. Every level above the reference was therefore
> over-credited: **+0.68 METs at level 1, +0.94 at 2, +1.24 at 3, +0.97 at 4**, i.e. up to
> **4.3 mL/kg/min of fitness nobody earned**, and about **2.2 years** of
> [[biological_age_estimate]] at level 3. The reference level was unaffected, which is why
> the worked check below did not catch it.

The steps between levels are **0.32 / 0.74 / 0.70 / 1.27 METs** — the largest is four
times the smallest. Any claim that "a category either way is worth one MET" is therefore
false for three of the four steps; see *Honesty & uncertainty*.

### The category is the OWNER'S ANSWER — a device cannot supply it

Jurca's fifth input is a **self-report about deliberate exercise**. Read the level
descriptions above: three of the five name a weekly duration of "aerobic exercise such as
run/walk", and the reference level explicitly *includes* walking for pleasure. So the
scale's zero point is "a person who walks", not "a person who does not move".

**Until 2026-08-02 this project synthesised the category from step cadence** — banding the
trailing 7 days of MVPA-equivalent minutes (`moderate + 2 × vigorous`, [[cadence_intensity]])
at 10 / 20 / 60 / 180 min per week. **That crosswalk was fabricated: nobody has published
one, and the two instruments do not measure the same thing.**

- **No validated mapping exists, and this was searched for directly.** Jurca and his
  co-authors published no device-input variant; no successor substitutes accelerometer or
  step-derived activity into the SR-PA slot. What the literature does report is how badly
  the two instruments agree: Prince et al. 2008's systematic review of 187 comparisons
  found self-report-vs-device correlations spanning **−0.71 to 0.96 with a mean of 0.37**,
  and self-report landing **both above and below** the device — "which poses a problem for
  both reliance on self-report measures and for attempts to correct for self-report–direct
  measure differences". At the level Jurca actually uses — a five-way **category** —
  agreement is worse still, on the order of a few per cent.
- **The reason is a construct difference, not measurement noise.** A questionnaire asks
  what exercise you did, and people answer with sessions they remember; an accelerometer
  counts every qualifying minute, most of which is incidental locomotion nobody would call
  exercise. Each instrument is valid for its own construct.
- **Measured on the real owner** (2026-08-02): 159 min/week of MVPA-equivalent, **every
  minute of it moderate — zero vigorous minutes all week** — and 107 of the 159 on a single
  day. From a person who states plainly that he does not exercise. The crosswalk scored him
  **SR-PA-3**, "1 to 3 hours per week of aerobic exercise". Combined with the linear-coding
  defect above, walking to and from the shops was worth **5.5 years** of biological age.

**So the input is asked, not inferred**, and the estimate is **withheld** until the owner
answers (`profile.srpa`, migration 0014). Withheld and not excluded: one honest answer
restores the whole metric. Defaulting to the reference level instead was rejected for the
reason [[biological_age_estimate]] gives for refusing to drop an absent term — level 0 is
not "unknown", it is the claim *you do no deliberate exercise*, which is just as invented
one direction over.

A worked check, unchanged by the correction because it sits at the reference level: a
median 40-year-old male, BMI 24, RHR 55, SR-PA 0 →
CRF = 18.07 + 2.77 − 4.0 − 4.08 − 1.65 = 11.11 METs → **≈ 38.9 mL/kg/min**,
consistent with population medians for that age and sex. The real owner (32, male, BMI
25.2, RHR 58.4, SR-PA 0) lands at **40.6** against FRIEND's published 39.7 for a 30–39
male — a sedentary person reading near the reference median, which is the sanity check the
fabricated category failed.

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
  - `SR-PA` = **`profile.srpa`, the owner's own answer** (0–4). Never derived.
- **Dependencies**: the profile must carry `age`, `sex`, `srpa`, and either `bmi` or
  height+weight. It does **not** depend on the MVPA derivation any more (#108).
- **Output**: the `vo2max_estimate` metric (source `derived`), **floored at 20** in code.
- **Skip if any input is missing** — never write a wrong value. Also skip (show
  "Insufficient data") if the 7-day RHR **MAD > 8 bpm**, `weight_kg` is missing or stale,
  or **`srpa` has never been answered** — a noisy RHR, an absent mass or an invented
  activity category each make the estimate untrustworthy.

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
- **Trend > level, but only barely, and this is weaker than it used to read here.**
  Within-person change is the *less bad* of the two readings, not a trustworthy one:
  Peterman 2020 found non-exercise equations classify the DIRECTION of a real fitness
  change correctly about **56%** of the time. Never speak about a movement smaller than
  the SEE.
- **Out-of-range inputs** (ages, BMI, RHR outside the validated ranges) grow the error.
- **The SR-PA answer is worth years, and it is the owner's answer.** *(Rewritten
  2026-08-02, #108.)* This bullet used to read "SRPA derivation adds another small error
  layer … the model is robust to ±1 category but not immune", and **that sentence is why
  nobody questioned the mapping for a year.** Neither half of it survives:
  - Not "small": one category is **0.58 to 2.29 years** of [[biological_age_estimate]]
    (the published steps are 0.32 / 0.74 / 0.70 / 1.27 METs and ΔAge is 1.81 y per MET),
    and the full scale is **5.5 years** — larger than the SEE, larger than every anchor
    effect in the composite, and the dominant uncertainty in the metric.
  - Not "±1 category noise": a cadence-derived category was not noisy around the truth,
    it was **systematically wrong for anyone whose steps are incidental**, which is most
    people. It is no longer derived at all.
  - What remains is ordinary self-report error: people report their best week rather than
    their typical one, which tilts this **towards flattery**. The direction is reasoned
    from how the question is answered, not measured here.
- **RHR confounders**: beta-blockers, atropine, and conditioning extremes decouple resting
  HR from VO₂max — flag if known.
- **Do not launder the estimate into a death-risk number.** The CRF↔mortality effect sizes
  in [[vo2max]] are CPET-anchored; this estimate carries ~5.1 mL/kg/min SEE on top, plus
  Jurca's own cross-cohort bias of up to 1.37 METs, plus the SR-PA answer.

## Bottom line

**Act on confidently:** Jurca 2005 is a validated, treadmill-free VO₂max estimator
(NASA model R = 0.81, SEE = 1.45 METs) — a reasonable fallback when no workout data exists,
provided its self-reported activity input is genuinely self-reported.

**Hold loosely:** the exact value for any individual (±~5 mL/kg/min before the SR-PA answer
is priced); the *direction* of small movements over time (Peterman 2020: ~56% correctly
classified); cross-person comparisons; and the estimate for anyone outside the validated
input ranges or on HR-altering medication.

**Do not do at all:** infer the activity category from device activity. There is no
published crosswalk, and the constructs differ — see *The category is the OWNER'S ANSWER*.

## Coach Directives

1. Compute the non-exercise estimate only as the **fallback** to the submaximal method;
   prefer [[submaximal_vo2max]] when a good steady-state workout segment exists.
   *(confidence: high)*
2. Always label the number an **estimate** with a ±SEE band; surface the **trend**, never
   the bare value. *(high)*
3. **Skip the derivation** (show "Insufficient data") when any input is missing, RHR 7-day
   MAD > 8 bpm, weight is absent or stale, or the owner has never answered the activity
   question — never write a wrong value. *(high)*
4. Never present the estimate as a death-risk figure or use it to clear hard training; it
   is a wellness trend, not a clinical measure. *(high)*
5. Flag decoupling confounders (beta-blockers, atropine, out-of-range inputs) when known.
   *(moderate)*
6. **Never infer the activity category from steps, MVPA minutes, workouts or any other
   device signal, and never fill it with a default.** It is a self-report about deliberate
   exercise; no published crosswalk from device activity exists, and the two constructs
   differ. If asked why we ask instead of measuring, say plainly that a step counter
   cannot tell a training session from getting around, that the model's own bottom
   category already includes walking, and that the answer is worth up to about two and a
   half years per category. *(high)*
7. When quoting the answer's cost, use the published steps (0.32 / 0.74 / 0.70 / 1.27
   METs ≈ 0.6 / 1.3 / 1.3 / 2.3 years). Do **not** say the model is robust to a
   one-category error — the steps are uneven and the largest is four times the smallest.
   *(high)*

## References

- **Jurca R, Jackson AS, LaMonte MJ, Morrow JR Jr, Blair SN, Wareham NJ, Haskell WL, van
  Mechelen W, Church TS, Jakicic JM, Laukkanen R.** *Assessing cardiorespiratory fitness
  without performing exercise testing.* Am J Prev Med 2005;29(3):185–193. PMID 16168867.
  **The source of every coefficient we use** — Table 5, NASA column (intercept 18.07 ·
  gender 2.77 · age −0.10 · BMI −0.17 · resting HR −0.03 · SR-PA-1 0.32 / -2 1.06 / -3
  1.76 / -4 3.03; R = 0.81, R² = 0.65, SEE = 1.45 METs). Three cohorts: NASA n=1,863
  (measured VO₂max, ventilatory gas analysis, Bruce protocol — the model we implement),
  ACLS n=46,190 and ADNFS n=1,706 (both estimated CRF, and both fitted their own
  different equations). Table 1 gives the five SR-PA level descriptions verbatim; Table 6
  gives the cross-cohort residuals. Methods state SR-PA is "dummy-coded … according to
  the Pedhauzur method". *Full text read 2026-08-02 (#108), which is when the previously
  recorded cohort, n, r and SEE were all found to be wrong.*
- **Prince SA, Adamo KB, Hamel ME, Hardt J, Connor Gorber S, Tremblay M.** *A comparison
  of direct versus self-report measures for assessing physical activity in adults: a
  systematic review.* Int J Behav Nutr Phys Act 2008;5:56. (187 comparisons; self-report
  vs direct correlations −0.71 to 0.96, mean **0.37**, SD 0.25; self-report runs both
  higher and lower than the device, "which poses a problem for … attempts to correct for
  self-report–direct measure differences". **The evidence that there is no crosswalk to
  find** between our activity data and Jurca's SR-PA slot.)
- **Peterman JE, Harber MP, Imboden MT, Whaley MH, Fleenor BS, Myers J, Arena R, Kaminsky
  LA.** *Accuracy of nonexercise prediction equations for assessing longitudinal changes
  to cardiorespiratory fitness in apparently healthy adults: BALL ST cohort.* J Am Heart
  Assoc 2020;9(11):e015117. PMID 32458761. (987 adults, two CPETs ≥3 months apart, 27
  equations. For 16 of 27 the estimated change differed significantly from the measured
  change; median correctly classified as increased/decreased/unchanged **56%, range
  39–61%**; concludes estimated CRF "may have limited clinical utility". **The source of
  the weakened trend claim.**)
- **Nes BM, Janszky I, Vatten LJ, Nilsen TI, Aspenes ST, Wisløff U.** *Estimating V̇O₂peak
  from a non-exercise prediction model: the HUNT Study, Norway.* Med Sci Sports Exerc
  2011;43(11):2024–2030.
- **Wier LT, Jackson AS, Ayers GW, Arenare B.** *Nonexercise models for estimating VO2max
  with waist girth, percent fat, or BMI.* Med Sci Sports Exerc 2006;38(3):555–561.
  Independent replication.

## Healthee implementation & honesty policy

- **Derived field: `vo2max_estimate`** (mL/kg/min), the **non-exercise fallback tier**.
  Computed nightly in the v2 `derive.py` pass, anchored 23:59 IST, `source = 'derived'`,
  **floored at 20** in code. Inputs: profile age/sex/**`srpa`**, BMI from latest
  `weight_kg` + height, and the 7-day rolling median of `rhr_daily`.
- **Ordering**: depends on `rhr_daily` only. *(Corrected 2026-08-02, #108: it no longer
  depends on the MVPA derivation, because SR-PA is no longer derived from it. And the
  claim that "the energy derivation depends in turn on `vo2max_estimate`" was **already
  false in this repo** — `derive/energy.py` reads no VO₂max, and the orchestrator runs
  activity/calories BEFORE this. So the SR-PA error never reached calories or BMR; it
  reached [[biological_age_estimate]], and only there.)*
- **The canonical formula is the corrected single-model Jurca METs equation** above, with
  SR-PA **dummy-coded** from Table 5. The older sex-stratified variant (and its 0–7
  activity score) is **superseded** and must not be reintroduced; neither may the linear
  `+ SRPA` coding that replaced it, nor any cadence-derived category.
- **`profile.srpa`** (migration 0014) holds the answer, nullable, CHECK 0–4. NULL means
  "never asked" and withholds the estimate with reason `srpa_not_reported` — a `withheld`
  state, not an `excluded` one, because one answer fixes it. There is no default and no
  backfill: every existing owner starts unanswered.
- **`/api/today` payload** carries the estimate, `see_ml_kg_min` (± SEE), a 90-day trend,
  `age_percentile` (vs Mandsager 2018 age/sex quintiles, a small hard-coded norm table —
  approximate, not clinical), the citing research notes, and the as-of date. The UI shows
  the hero value with the ±SEE band always visible, the percentile subtext, the 90-day
  sparkline (±SEE in the tooltip), an "estimate, non-exercise model" label, and a
  "trend matters more than the absolute number" footer.
- **Honesty rules (carry into UI + LLM)**: always "estimate"; never a two-decimal number;
  trend over months is the *less bad* reading, not a reliable one (~56% of directions
  called correctly); never a death-risk figure; never a cross-person comparison; withhold
  when inputs are missing/out-of-range, RHR is too noisy, or the activity question is
  unanswered; and never present the activity category as something we measured.
- **Out of scope**: a true submaximal-*test* VO₂max (cycling at a known wattage, etc.) is
  not feasible from the strap; the accurate active-user path is the free-living submaximal
  HR-vs-pace estimator ([[submaximal_vo2max]]). HRmax-formula refinement (220−age vs
  Tanaka) does **not** affect this metric — the Jurca model does not use HRmax.
