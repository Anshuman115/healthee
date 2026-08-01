---
id: sleep_consistency
name: "Sleep timing consistency (day-to-day variability)"
topic: Day-to-day sleep timing variability is independently linked to cardiometabolic risk
category: sleep
grade: Established
summary: "Higher day-to-day variability in bedtime and sleep duration raises cardiometabolic and mortality risk independently of mean sleep duration; it is a chronic-pattern signal (track SD of bedtime over ~2 weeks, surface weekly), the behavioural sibling of the Sleep Regularity Index."
aliases: ["sleep consistency", "bedtime consistency", "sleep timing variability", "irregular sleep", "sleep variability", "consistent bedtime", "social jetlag", "bedtime SD", "weekend catch-up sleep"]
applies_to_metrics: ["sleep_regularity_index", "sleep_health_score_4dim"]
applies_to_interventions: ["sleep_consistency", "bedtime_consistency"]
population: general
last_reviewed: 2026-07-15
related: ["sleep_regularity_index", "sleep_timing_chronotype", "sleep_duration_mortality", "morning_light_circadian", "no_validated_sleep_score"]
tags: [sleep, circadian, metabolism, cv_risk, consistency]
---

# Sleep timing consistency (day-to-day variability)

## Summary

Higher day-to-day variability in bedtime and sleep duration (often called "sleep
regularity") is associated with worse cardiometabolic health **independently** of
mean sleep duration. Larger variability predicts higher risk of obesity, metabolic
syndrome, hypertension, and all-cause mortality in several large cohorts. It is a
**chronic-pattern** signal, not an acute one — the actionable form is the Sleep
Regularity Index (see `sleep_regularity_index`) and its concrete behavioural target
of keeping sleep/wake within a ~1-hour band day to day, weekends included.

## What it is

Sleep consistency is the *stability* of when you sleep — quantified as day-to-day
variability in bedtime, wake time, sleep midpoint, and duration. It is distinct
from how *much* or how *well* you sleep: a person can average 8 h yet swing their
bedtime by 3 hours across the week. Common operationalisations are the SD of
bedtime over a multi-week window and the Sleep Regularity Index (SRI). This note is
the health-outcome evidence for *why timing stability matters*; `sleep_regularity_
index` is the computed metric and its formula.

## Physiology / mechanism

Irregular sleep-wake timing chronically misaligns the central circadian clock (the
suprachiasmatic nucleus) from the sleep-wake schedule and from peripheral clocks
that govern glucose handling, blood pressure rhythm, and metabolism. This
"circadian misalignment" — the same physiology behind social jetlag and shift-work
risk — is the plausible route by which timing variability, independent of total
duration, raises cardiometabolic and mortality risk. Morning bright light is the
dominant zeitgeber that re-anchors the clock (see `morning_light_circadian`).

## The evidence

- **[Established]** **Sleep Regularity Index (SRI) and mortality** — Windred DP et
  al., *Sleep* 2024;47(1):zsad253, UK Biobank, n = 60,977: "higher sleep regularity
  was associated with a 20%–48% lower risk of all-cause mortality". Most-regular vs
  least-regular (SRI 80–100th vs 0–20th percentile), all-cause mortality
  **HR 0.70 [0.59–0.83]** fully adjusted (0.52 [0.45–0.60] minimally adjusted), and
  regularity outpredicted mean duration. *[primary-source verified 2026-08-01 — an
  earlier version of this bullet stated "HR ≈ 1.46 (95% CI ~1.39–1.54)" for the
  lowest vs highest quintile. That figure is not in the paper; it appears to be a
  mangling of the abstract's "20%–48% lower risk", and its CI is far too narrow to
  be the reciprocal of the published one. Corrected to the paper's own direction and
  numbers.]*
- **[Probable]** **Bedtime variability and cardiometabolic outcomes** — SDs of
  bedtime ≥1 hour vs <30 min carry small-to-moderate elevations in risk (typically
  **RR 1.1–1.3**) for blood pressure, fasting glucose, and BMI outcomes.
- **[Established]** **Systematic review** — Bei B, Wiley JF, Trinder J, Manber R.
  *"Beyond the mean: A systematic review on the correlates of daily
  intraindividual variability of sleep/wake patterns."* Sleep Medicine Reviews
  2016;28:108–124. Systematic review across **53 studies**.
- **[Probable]** **Cardiovascular events (MESA)** — Huang T, Mariani S, Redline S.
  *"Sleep irregularity and risk of cardiovascular events."* J Am Coll Cardiol
  2020;75(9):991–999. MESA cohort, n ≈ 1,992.

## How we compute it

- Compute the personal **SD of bedtime over a rolling 14-day window**; flag when it
  exceeds the user's historical baseline.
- The rigorous companion metric is the SRI (0–100), computed on a 7-day rolling
  window — see `sleep_regularity_index` for the formula and implementation.
- Timing consistency also feeds the **Timing** dimension of the 4-dim sleep score
  (sleep midpoint vs personal baseline; `no_validated_sleep_score`,
  `sleep_score_implementation_plan`).

## How the coach uses it

- Do **not** present regularity as an acute concern; it is a **chronic-pattern
  signal worth surfacing weekly, not daily**.
- Cite this note when explaining *why* bedtime consistency matters, and pair it
  with the concrete SRI target (~1-hour band day to day, weekends included).
- Anchor the advice on a **consistent bedtime/wake time first** (regularity beats
  exact clock time), reinforced by morning light (`morning_light_circadian`,
  `sleep_timing_chronotype`).

## Safety bounds

No physiological guardrail. Do not medicalise a single irregular week; the signal
is multi-week. Never present regularity variability as an acute health threat.

## Honesty & uncertainty

- All major findings are **observational**. Reverse causation is possible (illness
  → irregular sleep).
- "Regularity" is defined differently across studies (SD of bedtime, SRI, etc.);
  effect sizes don't perfectly compare.
- Within-individual short-term variation (e.g., one weekend) is unlikely
  meaningful — the studies look at **multi-week** patterns.

## Bottom line

**Act on confidently:** day-to-day timing consistency matters for cardiometabolic
health and mortality independently of duration; the lever is keeping sleep/wake
within a ~1-hour band across the week. Surface it as a chronic, weekly signal.

**Hold loosely:** exact effect sizes (observational, definition-dependent);
attributing any single irregular week to health risk; causal direction.

## Coach Directives

1. Surface sleep-timing consistency as a **chronic/weekly** signal (SD of bedtime
   vs baseline; SRI trend), never as an acute daily alarm. *(confidence: high)*
2. Give the concrete target — sleep/wake within a ~1-hour band day to day,
   weekends included — not the abstract score. *(confidence: high)*
3. Frame findings as observational associations; don't imply a single irregular
   week causes harm. *(confidence: high)*

## References

- Bei B, Wiley JF, Trinder J, Manber R. *Beyond the mean: A systematic review on
  the correlates of daily intraindividual variability of sleep/wake patterns.*
  Sleep Medicine Reviews 2016;28:108–124.
- Windred DP, Burns AC, Lane JM, Saxena R, Rutter MK, Cain SW, Phillips AJK. *Sleep
  regularity is a stronger predictor of mortality than sleep duration.* Sleep
  2024;47(1):zsad253. UK Biobank, n ≈ 60,977.
- Huang T, Mariani S, Redline S. *Sleep irregularity and risk of cardiovascular
  events.* J Am Coll Cardiol 2020;75(9):991–999. MESA cohort, n ≈ 1,992.

## Healthee implementation & honesty policy

- No dedicated `sleep_consistency` derived field; the concept is carried by
  `sleep_regularity_index` (0–100, `derive/sleep_score.py::_compute_sri`) and the
  Timing dimension of `sleep_health_score_4dim`. A rolling SD-of-bedtime view is
  the descriptive companion.
- **Honesty policy:** present as a chronic, weekly signal against the user's own
  baseline; label associations observational; never as an acute daily concern or a
  composite score. Cite this note when explaining why bedtime consistency matters.
