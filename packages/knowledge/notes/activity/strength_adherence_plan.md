---
id: strength_adherence_plan
topic: Implementation plan — weekly strength-training minutes tally vs 30–60 min/week sweet spot
evidence_grade: 2
applies_to_metrics: [strength_min_weekly]
applies_to_interventions: [exercise]
tags: [implementation, strength, activity, dashboard]
last_reviewed: 2026-05-15
---

## Recommendation

Tally weekly minutes of muscle-strengthening activity from
`manual_entry` exercise logs, display against the 30–60 min/week
sweet spot from [[strength_training_mortality]]. Tiny card; no new
derivation pipeline needed.

## Data we have

- `manual_entry(kind='exercise')` rows with:
  - `payload.exercise_type` — free-text or one of an enum
    (`yoga`, `weights`, `gym`, `strength`, `pilates`, …)
  - `payload.duration_min`
  - `payload.intensity` — `'low'|'moderate'|'high'`
  - `at_iso`

(Same shape that produces `session(kind='exercise')`.)

## Classifier

Strength-eligible exercise types (case-insensitive):

```python
STRENGTH_TYPES = {
    "strength", "weights", "weightlifting", "lifting",
    "gym", "resistance", "calisthenics", "climbing",
    "bouldering", "powerlifting", "crossfit",
}
STRENGTH_YOGA_THRESHOLD_MIN = 30   # generic yoga only counts if ≥30 min
```

For each `manual_entry(kind='exercise')`:
- If `type ∈ STRENGTH_TYPES` → count full `duration_min`.
- If `type == 'yoga'` AND `duration_min ≥ 30` → count
  `duration_min × 0.5` (conservative half-credit; yoga isn't pure
  strength but contributes per Saeidifard 2019 / Momma 2022 mixed
  cohorts that grouped it in).
- Else → 0.

## Backend

- New analytics function `weekly_strength_minutes(end_date)` in
  `src/healthee/analytics/derived.py` that returns:
  ```python
  {
      "minutes": int,
      "target_low": 30,
      "target_high": 60,
      "sessions": int,
      "types": ["strength", "calisthenics"],  # unique types this week
  }
  ```
- Surface via `/api/today` next to `mvpa`:
  ```json
  "strength": {
    "week_min": 25,
    "target_low": 30,
    "target_high": 60,
    "sessions": 1,
    "types": ["strength"],
    "research_note": "strength_training_mortality"
  }
  ```

## Frontend

- New `web/src/components/today/strength-card.tsx`. Compact layout:
  - "Strength · this week"
  - `25 / 30–60 min` (with the band shaded green when in)
  - "1 session"
  - Cite-chip → [[strength_training_mortality]]

## Frame

- **Progress, not deficit** ([[behavior_change_and_personalization]]):
  - 0–29: "Add a session this week — even 30 min/week is the
    research threshold"
  - 30–60: "On target (literature sweet spot)"
  - 60–140: "Above target — diminishing returns"
  - 140+: gentle "plateau" line, no negative framing

## Caveats

- Yoga half-credit is a heuristic. Easy to overfit; defer changes
  until data drives.
- If the user is doing strength training but **not logging it**,
  this card is wrong — the only fix is encouraging the logging
  habit, which is itself BCT 2.3 (self-monitoring).

## Out-of-scope

- Per-exercise volume tracking (sets × reps × weight). Useful but a
  separate feature; keep this card simple.
- Auto-classification from HC workouts. HC's `exercise_type`
  enumeration includes `STRENGTH_TRAINING`, but most users don't
  log strength through HC; manual logging is the realistic path.
