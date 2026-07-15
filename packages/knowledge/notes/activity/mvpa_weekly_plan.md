---
id: mvpa_weekly_plan
name: "MVPA derivation & weekly-target plan"
topic: Implementation plan — derive moderate/vigorous minutes from per-minute steps + workouts; weekly progress card vs 150-min target
category: activity
grade: Probable
evidence_grade: 2
summary: "The implementation of MVPA: classify each per-minute step count into moderate/vigorous by cadence (debounced), add non-walking logged workouts, aggregate to daily moderate_min/vigorous_min and weekly mvpa_min (moderate + 2×vigorous), and show it against the WHO 150-min target."
aliases: ["mvpa derivation", "mvpa card", "weekly mvpa plan", "cadence mvpa derivation", "mvpa_weekly_plan"]
tags: ["mvpa derivation", "mvpa card", "weekly mvpa plan", "cadence mvpa derivation", "mvpa_weekly_plan"]
applies_to_metrics: ["steps_per_minute", "moderate_min", "vigorous_min", "mvpa_min"]
applies_to_interventions: ["exercise"]
population: general
last_reviewed: 2026-07-15
related: ["mvpa_minutes_mortality", "cadence_intensity", "pai_activity_score"]
---

# MVPA derivation & weekly-target plan

## Summary

Derive nightly `moderate_min` / `vigorous_min` daily metrics (cadence-based, per
[[cadence_intensity]]), plus a weekly aggregate card comparing weekly MVPA against the WHO
150-min target ([[mvpa_minutes_mortality]]). This note is the implementation plan: the
per-minute cadence classifier, the workout add-on, the daily/weekly aggregation, and the
UI. The science is in the two related notes; this is the "how we compute and show it".

## What it is

A derivation recipe turning per-minute step counts (and logged workouts) into the MVPA
metrics the mortality target is scored against. Its output metrics are `moderate_min`,
`vigorous_min` (daily) and `mvpa_min` (the MET-weighted total).

## Physiology / mechanism

Cadence (steps/min) is a validated proxy for ambulatory MET level: ~100 spm ≈ 3 METs
(moderate), ~130 spm ≈ 6 METs (vigorous) — the mechanistic basis and calibration are in
[[cadence_intensity]]. Non-ambulatory MVPA (cycling, weights, swimming) is zero-cadence
and must be added from logged workouts, or it is invisible to step counting.

## The evidence

- **[Established]** The cadence→intensity thresholds (100 spm ≈ moderate, 130 spm ≈
  vigorous) come from the Tudor-Locke CADENCE-Adults calibration program — see
  [[cadence_intensity]].
- **[Established]** The **1-minute minimum-dwell / debounce** convention (a minute counts
  only if the preceding minute is also elevated) matches the Stamatakis 2022 bout
  definition and avoids scoring spurious single-minute spikes ([[mvpa_minutes_mortality]]).
- **[Probable]** The overall derivation is a **validated-proxy estimate**, not a measured
  MET value — adequate for personal trending against the 150-min target.

## How we compute it

### Data we have
- `metric_sample(metric='steps_per_minute', source='gadgetbridge')` — per-minute step
  counts from `HUAMI_EXTENDED_ACTIVITY_SAMPLE`.
- `session(kind='workout')` — workout records with start/end and exercise type.
- The `derive` pipeline runs nightly.

### Derivation algorithm (per day, anchored 23:59 IST)

1. **Cadence-based minutes** — for minute `i`, classify:
   - **vigorous** if `steps[i] ≥ 130` AND `steps[i-1] ≥ 110`.
   - **moderate** if `steps[i] ≥ 100` AND `steps[i-1] ≥ 80` AND not already vigorous.
   - **light/sedentary** otherwise.
   - **Debounce** with the preceding-minute floor (avoids spurious single-minute spikes;
     Stamatakis 2022 bout convention). Sum `moderate_min_cadence` and
     `vigorous_min_cadence`.

2. **Workout-based minutes** (non-walking MVPA) — for each `session(kind='workout')` ending
   today with `exercise_type ∉ {walking, walk, hiking}`:
   - `intensity == 'moderate'` → add duration to `moderate_min_workout`.
   - `'vigorous'` or `'high'` → add to `vigorous_min_workout`.
   - Default fallback: `exercise_type ∈ {running, cycling, swimming, strength, weights,
     gym, hiit, yoga (>30min)}` → moderate.
   - Skip sessions < 10 min (ingest already filters this). **Subtract any minutes
     overlapping walking-cadence buckets** to avoid double-counting a walking workout.

3. **Daily aggregates** → derived rows:
   - `moderate_min = moderate_min_cadence + moderate_min_workout`
   - `vigorous_min = vigorous_min_cadence + vigorous_min_workout`
   - `mvpa_min = moderate_min + 2 × vigorous_min` (WHO MET-equivalent)

## How the coach uses it

- Show the weekly card: hero `{week_min} / 150 min`, a progress bar (accent below 150,
  green at ≥150), subline "moderate {m} + vigorous {v}×2", and a "Day n/7 of the week"
  hint.
- Frame the 150-min target as a **lower bound** — benefits continue past 150 (show in the
  chart tooltip).
- Flag when MVPA is likely **under-counted** because non-walking activity wasn't logged.
- Cite [[mvpa_minutes_mortality]] on the card.

## Safety bounds

- No death-risk number; the card is a progress/encouragement surface only.
- Do not issue clinical exercise prescriptions.

## Honesty & uncertainty

- **"Cadence-based estimate"** footer — the per-minute classification is a proxy, not a
  measured MET value.
- The **150-min target is a lower bound**; show benefits continuing past 150.
- **Non-walking activity** (cycling, weights, yoga) counts only from logged workouts; if
  the user doesn't log workouts, **MVPA is under-counted**.
- Cadence thresholds are population-average and drift ±10 spm by age cohort
  ([[cadence_intensity]]); acceptable for personal trending.

## Bottom line

**Act on confidently:** cadence-classified per-minute steps + logged workouts give a
usable weekly MVPA estimate to trend against the 150-min lower bound.

**Hold loosely:** exact per-minute MET classification (proxy), and totals when workouts go
unlogged (under-count).

## Coach Directives

1. Derive `moderate_min`/`vigorous_min` from **debounced** per-minute cadence + add
   non-walking logged workouts (no double-counting walking). *(confidence: high)*
2. Compute `mvpa_min = moderate_min + 2 × vigorous_min`; show weekly vs a **150-min lower
   bound**. *(high)*
3. Label it a **cadence-based estimate** and flag likely under-count when workouts aren't
   logged. *(high)*

## References

- Tudor-Locke C, Han H, Aguiar EJ, et al. *How fast is fast enough? Walking cadence
  (steps/min) as a practical estimate of intensity in adults: a narrative review.* Br J
  Sports Med 2018;52(12):776–788. (Cadence→MET basis; see [[cadence_intensity]].)
- Stamatakis E, Ahmadi MN, Gill JMR, et al. *Association of wearable device-measured
  vigorous intermittent lifestyle physical activity with mortality.* Nat Med
  2022;28:2521–2529. (Bout/dwell convention and the 150-min-target evidence in
  [[mvpa_minutes_mortality]].)

## Healthee implementation & honesty policy

- **Metrics: `moderate_min`, `vigorous_min`, `mvpa_min`** (daily, `source='derived'`),
  added to `DEFAULT_DAILY_METRICS` (so they appear in correlations) and `mvpa_min` to
  `METRICS_HIGH_IS_GOOD`. Derived in the nightly `derive` pass from per-minute
  `steps_per_minute` + `session(kind='workout')`.
- **`/api/today` payload** carries an `mvpa` object: `today_min`, `week_min` (current ISO
  week so far), `week_target` (150), `moderate_min_week`, `vigorous_min_week`, and the
  citing research note. Sits next to the PAI card (PAI = intensity-weighted weekly; MVPA =
  raw-time view — complementary; see [[pai_activity_score]]).
- **Honesty rules**: cadence-based estimate footer; 150 is a lower bound; surface likely
  under-count when workouts are unlogged.
- **Out of scope**: HR-zone-based MVPA (PAI already does that); per-age recalibration of
  the 100-spm threshold (±10 spm by cohort — acceptable error for personal trending).
