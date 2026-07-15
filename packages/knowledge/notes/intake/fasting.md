---
id: fasting_metrics
name: "Fasting (IF / TRE) and tracked metrics"
topic: Fasting and its effect on wearable-tracked physiology
category: intake
grade: Probable
evidence_grade: 2
summary: "Time-restricted eating gives no body-composition or metabolic advantage over plain calorie restriction and can cost lean mass; fasting shifts HRV/RHR in a direction that depends on fast length, so a wearable's 'better' overnight HRV during a fast can be meal-timing physiology, not recovery."
aliases: ["fasting", "intermittent fasting", "IF", "time-restricted eating", "TRE", "16:8", "time-restricted feeding", "TRF", "alternate-day fasting", "fasted training", "Ramadan fasting"]
applies_to_metrics: ["hrv_sleep_avg", "rhr_daily", "weight_kg", "recovery_score", "sleep_health_score_4dim", "vo2max_estimate", "skin_temp_c", "respiratory_rate_sleep"]
applies_to_interventions: ["fasting"]
population: general
last_reviewed: 2026-07-15
status: partial
---

# Fasting (IF / TRE) and tracked metrics

> **Note status: PARTIAL.** The autonomic (HRV/RHR) and body-composition/metabolic
> sections are backed by adversarially-verified primary sources. The sleep,
> temperature, respiratory-rate, VO₂max/performance, and safety sections are
> **not yet verification-complete** — their claims are flagged `[UNVERIFIED]`
> and must not be surfaced to the user as established until checked against
> primary sources. Source dossier: `docs/research/fasting_dossier.md`.

## Summary

Intermittent fasting (IF) and time-restricted eating (TRE) are eating-*timing*
patterns, not diets. For **body weight, body composition, and metabolic markers,
the best RCT evidence shows no advantage over simple calorie restriction** — and
TRE can cost more lean mass than expected. For the **autonomic signals a wearable
reads (HRV, resting HR), fasting moves them — but the direction depends on how
long the fast is**, and the movement reflects meal-timing/hydration physiology as
much as "recovery." The honest headline: a fast that makes overnight HRV look
better is not necessarily making you fitter, and a person doesn't need to fast to
improve any metric Healthee tracks.

## What it is

- **Time-restricted eating (TRE/TRF):** all food inside a daily window (commonly
  16:8 — an 8-hour window). "Early" TRE ends mid-afternoon; "late" TRE runs into
  the evening.
- **Alternate-day / intermittent fasting (IF/ADF):** whole fasting or very-low-
  calorie days interleaved with normal days.
- **Prolonged fasting:** multi-day near-total fasts (e.g. Buchinger ~250 kcal/day).
  Physiologically *different* from an overnight or 16h fast — evidence from
  prolonged fasts must not be presented as if it describes daily TRE.

## The evidence

### Body weight & composition — no advantage over calorie restriction [Established]
- 16:8 TRE gave **no weight advantage** over unstructured eating: between-group
  −0.26 kg (P=.63) in the 12-week TREAT RCT (n=116). [fasting_metrics: Lowe 2020, JAMA Intern Med, PMC7522780]
- Alternate-day fasting was **no better than daily calorie restriction** at 12
  months (−6.0% vs −5.3%; diff −0.7%, 95% CI −3.1 to 1.6) — IF's weight effect is
  driven by eating less, not by fasting per se. [fasting_metrics: Trepanowski 2017, JAMA Intern Med]
- TRE (8am–4pm) + calorie restriction was **not significantly better than calorie
  restriction alone** at 12 months (net −1.8 kg, P=0.11), with body fat, lean mass,
  waist, BMI, and BP all no different. [fasting_metrics: NEJM 2022, NEJMoa2114833]
- TRE alone yields only ~1–4% weight loss; >5% needs TRE **plus** calorie
  restriction. [fasting_metrics: TRF review, PMC9696013]

### Lean mass — a real cost [Probable]
- In TREAT, TRE lost significant lean mass: appendicular lean-mass-index
  between-group −0.16 kg/m² (P=.005), with **~65% of the weight lost being lean
  mass** vs a normal 20–30%. [fasting_metrics: Lowe 2020, PMC7522780] This is the
  single most important honest caution: unstructured TRE without adequate protein
  and resistance training can erode muscle.

### Glucose / insulin [Probable]
- TRF may improve insulin sensitivity and daytime glycemic variability in
  overweight/obese people; early-TRF reduced HOMA-IR (−1.08 vs increases in
  controls, n=82). [fasting_metrics: PMC9696013] But 16:8 TRE showed **no** change
  in fasting glucose/insulin/HbA1c vs control over 12 weeks. [fasting_metrics: Lowe 2020, PMC7522780]

### HRV & resting HR — direction depends on fast length [Probable, mixed]
This is the wearable-relevant core, and it is genuinely mixed:
- A short/acute fast **raised** vagally-mediated HRV (R-R 992→1,059 ms; normalized
  HF power 55%→62%) and **lowered** resting HR (69→65 bpm), with unchanged muscle
  sympathetic nerve activity — i.e. the shift was *more vagal tone*, not less
  sympathetic drive. [fasting_metrics: AJP-Regu 2022, ajpregu.00283.2021]
- But a **48-hour total fast LOWERED** HRV (SDNN and RMSSD fell, P<0.001) —
  parasympathetic *withdrawal* with sympathetic activation, i.e. a stress response.
  [fasting_metrics: Chan 2013, PMID 23403876]
- A 12-day prolonged fast **raised** RMSSD (27.2→32.9 ms, p=0.01) but the design
  was weak (n=16, single-arm, no control) and it is prolonged fasting, not daily
  TRE. [fasting_metrics: GENESIS, Int J Obes 2025, s41366-025-01843-0]

Net: an overnight/16h fast tends to *raise* overnight HRV and *lower* RHR;
multi-day total fasting eventually *depresses* HRV as a stress signal. The
wearable cannot tell "recovered" from "fasted."

## How we compute it

Fasting is a **logged intervention** (`fast_start` / `fast_end`), not a derived
metric. It enters analysis as an event to correlate against `hrv_sleep_avg`,
`rhr_daily`, `sleep_health_score_4dim`, `weight_kg`, and `recovery_score` — and
as context the coach must weigh when interpreting an HRV/recovery change on a
fasting day.

## How the coach uses it

- If a user's overnight HRV rises / RHR drops **on a fasting night**, say the fast
  itself likely moved the autonomic signal — do **not** report it as improved
  recovery or fitness. (The signal is confounded; see Honesty.)
- If a user fasts to lose weight, be honest that timing alone is not superior to
  eating less, and flag the lean-mass risk → pair with protein + resistance work.
- Never prescribe fasting to "improve" a tracked metric — no metric Healthee
  tracks requires fasting to improve.

## Safety bounds [UNVERIFIED — verify before surfacing]

Candidate hard-stops (from `PMC10589984`, disordered-eating risk, and standard
guidance) pending verification: history of or risk for eating disorders,
pregnancy/lactation, type-1 diabetes, underweight/low energy availability, and
high-training-load or chronically-short-sleeping individuals (added stressor).
Until verified, the coach treats fasting questions from these groups with the
existing medical-refusal guardrails.

## Honesty & uncertainty

- **The wearable confound is the headline:** fasting alters HRV/RHR through
  meal-timing, hydration, and glycogen/fluid shifts — not necessarily recovery.
  A "green" recovery score on a fasting morning can be an artefact.
- **Fast length matters:** short-fast and multi-day-fast HRV point in opposite
  directions; never generalize one to the other.
- **Populations:** the strongest weight/composition RCTs are in adults with
  overweight/obesity — effects in lean, athletic, or already-short-sleeping users
  are less certain.
- **Refuted claim (do not use):** a pooled "IF −3.73 kg vs control" figure failed
  verification (0-3). [fasting_metrics: PMC12309044]
- **Pending [UNVERIFIED]:** sleep architecture (early- vs late-TRE, hunger effects),
  overnight/skin temperature, respiratory rate, VO₂max / Ramadan performance, and
  the safety list above — extracted but not through the verification gate.

## Bottom line

**Act on confidently:** TRE is not magic for weight/metabolism — it works only
insofar as it makes you eat less, and it can cost lean mass. Don't read a fasting
day's HRV/RHR as recovery.

**Hold loosely:** the exact autonomic direction for a given user and fast length;
sleep, temperature, respiratory, and performance effects (pending verification).

## Coach Directives

1. On a logged fasting day, attribute HRV↑/RHR↓ to the fast, not to recovery, and
   say so plainly. *(confidence: high — direction verified for short fasts)*
2. For weight goals, state that meal-timing ≠ calorie deficit and surface the
   lean-mass risk; recommend protein + resistance training. *(high)*
3. Never recommend fasting to improve a tracked metric. *(high)*
4. Route fasting questions from at-risk groups (see Safety) to medical-refusal
   guardrails until the safety section is verified. *(high — provisional)*

## References
- Lowe DA et al. 2020, *JAMA Internal Medicine* — TREAT RCT. PMC7522780.
- Trepanowski JF et al. 2017, *JAMA Internal Medicine* — ADF vs CR, 12mo. jamanetwork/2623528.
- 2022, *NEJM* — TRE-timing RCT. NEJMoa2114833.
- TRF review, *PMC9696013*.
- GENESIS / Buchinger 12-day fast, *Int J Obes* 2025 — s41366-025-01843-0 / PMC12532600 (weak design).
- Chan 2013 — 48h fast HRV, female subjects. PMID 23403876.
- Acute fast vagal HRV, *AJP-Regulatory* 2022 — ajpregu.00283.2021.
- IF meta-analysis (refuted figure), *PMC12309044*.
- [UNVERIFIED] TRE sleep systematic review PMC11322763; Ramadan performance meta Springer s40279-020-01257-0 (PMID 31960369); disordered-eating risk PMC10589984.
