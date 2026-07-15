---
id: mvpa_weekly_plan
topic: Implementation plan — derive moderate/vigorous minutes from per-minute steps + HC workouts; weekly progress card vs 150-min target
evidence_grade: 2
applies_to_metrics: [steps_per_minute, moderate_min, vigorous_min, mvpa_min_weekly]
applies_to_interventions: [exercise]
tags: [implementation, mvpa, cadence, activity, dashboard]
last_reviewed: 2026-05-15
---

## Recommendation

Add nightly-derived `moderate_min` / `vigorous_min` daily metrics
(cadence-based, per [[cadence_intensity]]), plus a weekly aggregate
card on Today + the future `/activity` page comparing weekly MVPA
against the WHO 150-min target ([[mvpa_minutes_mortality]]).

## Data we have

- `metric_sample(metric='steps_per_minute', source='gadgetbridge')` —
  per-minute step counts from `HUAMI_EXTENDED_ACTIVITY_SAMPLE`
- `session(kind='workout', source='tasker_hc')` — HC ExerciseSession
  records with start/end and exercise type (`payload.exercise_type`)
- `derive` pipeline runs nightly at 23:55 IST

## Derivation algorithm

Per day (anchored at 23:59 IST of the calendar date):

1. **Cadence-based minutes**:
   - Pull per-minute `steps_per_minute` for the day.
   - For minute `i`: classify
     - **vigorous** if `steps[i] ≥ 130` AND `steps[i-1] ≥ 110`
     - **moderate** if `steps[i] ≥ 100` AND `steps[i-1] ≥ 80` AND
       not already vigorous
     - **light/sedentary** otherwise
   - Require **debouncing**: the preceding-minute floor avoids
     spurious single-minute spikes (Stamatakis 2022 bout convention).
   - Sum `moderate_min_cadence` and `vigorous_min_cadence` for day.

2. **Workout-based minutes** (non-walking MVPA):
   - For each `session(kind='workout')` ending today, with
     `exercise_type ∉ {walking, walk, hiking}`:
     - If `payload.intensity` is `'moderate'` → add session duration to
       `moderate_min_workout`.
     - If `'vigorous'` or `'high'` → add to `vigorous_min_workout`.
     - Default fallback: if `exercise_type` ∈ {running, cycling,
       swimming, strength, weights, gym, hiit, yoga (>30min)} →
       moderate.
   - Skip sessions with duration < 10 min (HC ingest already filters this).
   - Subtract any minutes overlapping walking-cadence buckets (to
     avoid double-counting a "walking workout").

3. **Daily aggregates** → `metric_sample` rows (source='derived'):
   - `moderate_min = moderate_min_cadence + moderate_min_workout`
   - `vigorous_min = vigorous_min_cadence + vigorous_min_workout`
   - `mvpa_min = moderate_min + 2 × vigorous_min` (WHO MET-equivalent)

## Backend

- Extend `src/healthee/analytics/derived.py`:
  - New function `_derive_mvpa_minutes(day, conn)`.
  - Add metric names to `DEFAULT_DAILY_METRICS` so they show in
    correlations.
  - Add `mvpa_min` to `METRICS_HIGH_IS_GOOD`.
- New API endpoint or extension to `/api/today`:
  - `pai` already exists; add a sibling object:
    ```json
    "mvpa": {
      "today_min": 47,           // moderate + 2*vig today
      "week_min": 87,            // current ISO week so far
      "week_target": 150,
      "moderate_min_week": 67,
      "vigorous_min_week": 10,
      "research_note": "mvpa_minutes_mortality"
    }
    ```
- Could also surface daily breakdown on a new `/api/activity` later
  (out of scope for this plan).

## Frontend

- New `web/src/components/today/mvpa-card.tsx`:
  - Hero number: `87 / 150 min` (this week)
  - Bar showing progress (coral accent at <150, green at ≥150)
  - Subline: "moderate 67 + vigorous 10×2"
  - Cite-chip: tap → opens [[mvpa_minutes_mortality]]
- Slot into Today next to PAI card (PAI = intensity-weighted weekly;
  MVPA = raw-time view — complementary).
- Optional small note: "Day 4/7 of the week".

## Caveats baked into the UI

- "Cadence-based estimate" footer.
- The 150-min target is a *lower bound*; show benefits continuing past
  150 in the chart tooltip.
- Non-walking activity (cycling, weights, yoga) counts from manual
  workout logs; if user doesn't log workouts, MVPA is under-counted.

## Sequencing

1. Derivation logic + DB rows
2. /api/today extension
3. Today card
4. /activity page (future, separate task)

## Out-of-scope

- HR-zone-based MVPA (PAI already does that).
- Intensity adjustment for older/younger users vs the 100-spm
  threshold (Tudor-Locke calibrations vary ±10 spm by age cohort;
  acceptable error for personal trending).
