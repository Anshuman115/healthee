---
id: fasting_metrics
name: "Fasting (IF / TRE) and tracked metrics"
topic: Fasting and its effect on wearable-tracked physiology
category: intake
grade: Probable
summary: "Time-restricted eating gives no body-composition or metabolic advantage over plain calorie restriction and can cost lean mass; fasting shifts HRV/RHR in a direction that depends on fast length, so a wearable's 'better' overnight HRV during a fast can be meal-timing physiology, not recovery."
aliases: ["fasting", "intermittent fasting", "IF", "time-restricted eating", "TRE", "16:8", "time-restricted feeding", "TRF", "alternate-day fasting", "fasted training", "Ramadan fasting"]
applies_to_metrics: ["hrv_sleep_avg", "rhr_daily", "weight_kg", "recovery_score", "sleep_health_score_4dim", "vo2max_estimate", "skin_temp_c", "respiratory_rate_sleep"]
applies_to_interventions: ["fasting"]
population: general
last_reviewed: 2026-07-15
---

# Fasting (IF / TRE) and tracked metrics

## Summary

Intermittent fasting (IF) and time-restricted eating (TRE) are eating-*timing*
patterns, not diets. For **body weight, body composition, and metabolic markers,
the best RCT evidence shows no advantage over simple calorie restriction** — and
TRE can cost more lean mass than expected. For the **autonomic signals a wearable
reads (HRV, resting HR), fasting moves them, but the direction depends on how long
the fast is**, and the movement reflects meal-timing and fluid physiology as much
as "recovery." Sleep is usually not worsened by short-to-mid-term TRE but the
evidence is mixed. Athletic performance is largely preserved except anaerobic
sprint power. The honest headline: a fast that makes overnight HRV look better is
not necessarily making you fitter, and a person does not need to fast to improve
any metric Healthee tracks.

## What it is

- **Time-restricted eating (TRE / TRF):** all food inside a daily window
  (commonly 16:8 — an 8-hour window). "Early" TRE ends mid-afternoon; "late" TRE
  runs into the evening.
- **Alternate-day / intermittent fasting (IF / ADF):** whole fasting or very-low-
  calorie days interleaved with normal days.
- **Prolonged fasting:** multi-day near-total fasts (e.g. Buchinger ~250 kcal/day).
  Physiologically *different* from an overnight or 16h fast — its evidence must not
  be presented as if it describes daily TRE.

## Physiology / mechanism

A fast lowers circulating glucose and insulin, shifts fuel use toward fat/ketones,
and changes fluid and glycogen balance. It also alters autonomic tone: short fasts
tend to raise vagal (parasympathetic) activity, while prolonged total fasting
eventually reads as a stressor with sympathetic activation. Because HRV and resting
HR are downstream of exactly these autonomic, hydration, and meal-timing inputs, a
wearable's overnight reading on a fasting night is confounded — it moves for
reasons other than training recovery.

## The evidence

### Body weight & composition — no advantage over calorie restriction [Established]
- 16:8 TRE gave **no weight advantage** over unstructured eating: between-group
  −0.26 kg (P=.63) in the 12-week TREAT RCT, n=116 (Lowe 2020, JAMA Intern Med).
- Alternate-day fasting was **no better than daily calorie restriction** at 12
  months (−6.0% vs −5.3%; difference −0.7%, 95% CI −3.1 to 1.6) — IF's weight
  effect is driven by eating less, not by fasting itself (Trepanowski 2017, JAMA
  Intern Med).
- TRE (8am–4pm) plus calorie restriction was **not significantly better than
  calorie restriction alone** at 12 months (net −1.8 kg, P=0.11), with body fat,
  lean mass, waist, BMI, and blood pressure all no different (Liu 2022, NEJM).
- TRE alone yields only ~1–4% weight loss; >5% needs TRE **plus** calorie
  restriction (Charlot 2021 review, Int J Environ Res Public Health).

### Lean mass — a real cost [Probable]
- In TREAT, TRE lost significant lean mass: appendicular lean-mass-index
  between-group −0.16 kg/m² (P=.005), with **~65% of the weight lost being lean
  mass** versus a normal 20–30% (Lowe 2020). The most important practical caution:
  unstructured TRE without adequate protein and resistance training can erode
  muscle.

### Glucose / insulin [Probable]
- TRF may improve insulin sensitivity and daytime glycemic variability in
  overweight/obese people; early-TRF reduced HOMA-IR (Xie et al., n=82: −1.08 vs
  increases in controls; Charlot 2021 review). But 16:8 TRE showed **no** change in
  fasting glucose, insulin, or HbA1c versus control over 12 weeks (Lowe 2020).

### HRV & resting HR — direction depends on fast length [Probable, mixed]
The wearable-relevant core, and it is genuinely mixed:
- A short/acute fast **raised** vagally-mediated HRV (R-R 992→1,059 ms; normalized
  HF power 55%→62%) and **lowered** resting HR (69→65 bpm), with unchanged muscle
  sympathetic nerve activity — the shift was *more vagal tone*, not less sympathetic
  drive (Am J Physiol Regul 2022).
- But a **48-hour total fast LOWERED** HRV (SDNN and RMSSD fell, P<0.001) —
  parasympathetic *withdrawal* with sympathetic activation, i.e. a stress response
  (Chan 2013, healthy female subjects).
- A supervised **12-day prolonged fast raised** RMSSD (27.2→32.9 ms, p=0.01) but the
  design was weak (n=16, single-arm, no control) and it is prolonged fasting, not
  daily TRE (GENESIS/Buchinger, Int J Obes 2025).

Net: an overnight/16h fast tends to *raise* overnight HRV and *lower* RHR;
multi-day total fasting eventually *depresses* HRV as a stress signal. The wearable
cannot tell "recovered" from "fasted."

### Sleep — usually not worsened, but mixed [Probable]
- Systematic review of 6 RCTs (548 enrolled, 430 completed): "short to mid-term
  TRE does not typically worsen sleep parameters," but results were mixed — some
  groups had fewer sleep disturbances, others a small drop in sleep efficiency
  (Bohlman 2024, Front Nutr). Notably one early-TRE arm (7am–3pm) *reduced* sleep
  duration (~0.5h) and efficiency (~2%). Meal timing matters, and not always in the
  intuitive direction.

### Performance / VO₂max — largely preserved [Probable]
- Meta-analysis of 11 Ramadan-fasting studies: aerobic/endurance performance was
  **not affected**; strength, jump height, and total work were **not affected**;
  only anaerobic **mean and peak power** (Wingate/repeated-sprint), especially
  morning sprints, were impaired. "Athletes appear able to participate in
  competition in a fasted state with little impact on physical performance,"
  provided sleep and nutrition are optimized (Abaïdia 2020, Sports Medicine).

### Temperature & respiratory rate [Emerging / thin]
- Direct evidence for skin/core temperature and respiratory rate during everyday
  IF/TRE (as opposed to prolonged fasting or starvation) is **thin to absent** in
  the wearable-relevant literature. Mechanistically both track metabolic rate and
  thermoregulation, so small shifts are plausible, but Healthee should not assert a
  direction or magnitude here until primary evidence exists. Treat any change as
  unexplained rather than fasting-attributed.

## How we compute it

Fasting is a **logged intervention** (`fast_start` / `fast_end`), not a derived
metric. It enters analysis as an event to correlate against `hrv_sleep_avg`,
`rhr_daily`, `sleep_health_score_4dim`, `weight_kg`, and `recovery_score`, and as
context the coach must weigh when interpreting an HRV/recovery change on a fasting
day.

## How the coach uses it

- If overnight HRV rises / RHR drops **on a logged fasting night**, attribute it to
  the fast, not to improved recovery or fitness — the signal is confounded.
- If a user fasts to lose weight, be honest that timing alone is not superior to
  eating less, and flag the lean-mass risk → pair with protein and resistance work.
- Reassure athletes that endurance and strength are largely preserved fasted; only
  flag anaerobic sprint sessions (especially morning) as the likely weak spot.
- Never prescribe fasting to "improve" a tracked metric — no metric Healthee tracks
  requires fasting to improve.

## Safety bounds

- **Never encourage IF for anyone with a current or past eating disorder or
  disordered eating** (Blumberg 2023, Clin Diabetes Endocrinol).
- **Extreme caution** for adolescents/young adults, especially women and
  gender-diverse people (elevated disordered-eating risk); and insufficient safety
  evidence for children, the elderly, and pregnant/lactating people.
- **Type-1 diabetes** and **underweight / low energy availability** are further
  hard-stops handled by the medical-refusal guardrails.
- High-training-load or chronically short-sleeping users should treat a fast as an
  added stressor, not a recovery aid.
**What is actually enforced (#87, corrected 2026-08-01).** These two lines read
"Safety-critical directives below are mirrored as code guardrails and are never
overridable by the LLM." That was a claim this note could not back: **this note declares
no `safety_critical` directive in its frontmatter**, and only a declared marker compiles
into `insights/guard_directives.py`. Two adjacent code paths do real work and neither is
this note's:

- `insights/refusals.py` refuses a **question** containing "eating disorder", "anorexi"
  or "bulimi" to a static mental-health response before the model is ever called. That
  covers the incoming half of Directive 4, not the outgoing half.
- `insights/guard_directives.py` compiles [[late_eating_sleep]] D5 and blocks any
  **answer** that prescribes an eating window, a fasting schedule, an eating cutoff or an
  intake restriction — for every owner, not only at-risk ones. That covers much of
  Directive 3 and the prescription half of Directive 4 in effect.

Everything else in this section — the adolescent caution, the type-1 diabetes and
low-energy-availability stops, the training-load caveat — is a rule for the coach to
follow, not a guarantee. Directive 4 is a strong candidate for a `safety_critical`
marker of its own.

## Honesty & uncertainty

- **The wearable confound is the headline:** fasting alters HRV/RHR through
  meal-timing, hydration, and glycogen/fluid shifts, not necessarily recovery. A
  "green" recovery score on a fasting morning can be an artefact.
- **Fast length matters:** short-fast and multi-day-fast HRV point in opposite
  directions; never generalize one to the other.
- **Populations:** the strongest weight/composition RCTs are in adults with
  overweight/obesity — effects in lean, athletic, or short-sleeping users are less
  certain.
- **Refuted claim (do not use):** a pooled "IF −3.73 kg vs control" figure failed
  adversarial verification and is not supported as stated.
- **Thin areas:** temperature and respiratory rate during everyday TRE.

## Bottom line

**Act on confidently:** TRE is not magic for weight or metabolism — it works only
insofar as it makes you eat less, and it can cost lean mass. Don't read a fasting
day's HRV/RHR as recovery. Sleep is usually fine; endurance and strength are
preserved.

**Hold loosely:** the exact autonomic direction for a given user and fast length;
anaerobic-power decrements; temperature and respiratory effects (thin evidence).

## Coach Directives

1. On a logged fasting day, attribute HRV↑/RHR↓ to the fast, not to recovery, and
   say so plainly. *(confidence: high)*
2. For weight goals, state that meal-timing ≠ calorie deficit and surface the
   lean-mass risk; recommend protein plus resistance training. *(high)*
3. Never recommend fasting to improve a tracked metric. *(high)*
4. **SAFETY-CRITICAL:** never encourage fasting for anyone with eating-disorder
   history/risk; route such questions to the medical-refusal guardrails. *(high;
   **partly enforced**. A question naming an eating disorder, anorexia or bulimia is
   refused before the model runs by `insights/refusals.py`'s mental-health domain, and
   `[[late_eating_sleep]]` D5's compiled rule blocks a prescribed fasting window in any
   answer. Neither knows a *history* the owner has not just typed — nothing in the tree
   stores one. #100)*
5. Tell athletes endurance/strength are preserved fasted; flag only morning
   anaerobic/sprint sessions. *(moderate)*

## References
- Lowe DA et al. 2020. Effects of time-restricted eating on weight loss and other
  metabolic parameters (TREAT RCT). *JAMA Internal Medicine* 180(11):1491–1499.
- Trepanowski JF et al. 2017. Alternate-day fasting vs daily calorie restriction.
  *JAMA Internal Medicine* 177(7):930–938.
- Liu D et al. 2022. Calorie restriction with or without time-restricted eating.
  *NEJM* 386:1495–1504.
- Charlot A et al. 2021. Beneficial effects of early time-restricted feeding.
  *Int J Environ Res Public Health* (TRF review, PMC9696013).
- Am J Physiol Regul Integr Comp Physiol 2022 — acute fast, vagal HRV
  (ajpregu.00283.2021).
- Chan JL et al. 2013. Effects of a 48-h fast on HRV and cortisol in healthy female
  subjects. PMID 23403876.
- Ganesan K et al. 2025. Long-term-fasting autonomic modulation, GENESIS subgroup.
  *Int J Obesity* (weak design; s41366-025-01843-0).
- Bohlman C, McLaren C, Ezzati A et al. 2024. Effects of time-restricted eating on
  sleep in adults: a systematic review of RCTs. *Frontiers in Nutrition* 11:1419811.
- Abaïdia AE, Daab W, Bouzid MA. 2020. Effects of Ramadan fasting on physical
  performance: a systematic review with meta-analysis. *Sports Medicine*
  50(5):1009–1026. PMID 31960369.
- Blumberg J, Hahn SL, Bakke J. 2023. Intermittent fasting: consider the risks of
  disordered eating for your patient. *Clinical Diabetes and Endocrinology* 9:4.

## Healthee implementation & honesty policy

- Fasting is a logged intervention, not a derived metric — no `derived_daily` row;
  it is an event correlated against the metrics in `applies_to_metrics`.
- The confound rule is mandatory: any HRV/RHR/recovery interpretation on a day with
  a logged fast MUST name the fast as a likely cause and MUST NOT report the change
  as improved recovery or fitness. This is the "never shows you a wrong metric as a
  win" contract applied to fasting.
- No composite "fasting score" is derived; fasting only contextualizes existing
  metrics.
- Directive 4 (eating-disorder safety) is **not compiled from this note** — this note
  declares no `safety_critical` marker. Its incoming half is covered by
  `insights/refusals.py` and its prescription half by [[late_eating_sleep]] D5 in
  `insights/guard_directives.py`; see *Safety bounds*, #87.
