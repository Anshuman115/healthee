---
id: vo2max_estimate_plan
topic: Implementation plan — nightly Jurca non-exercise VO2max estimate + Today trend card
evidence_grade: 2
applies_to_metrics: [vo2max_estimate, rhr_daily, moderate_min, vigorous_min, mvpa_min]
applies_to_interventions: []
tags: [implementation, vo2max, dashboard]
last_reviewed: 2026-05-15
---

## Recommendation

Compute the **Jurca 2005 non-exercise VO2max estimate** nightly from
existing data (age + sex + BMI from `profile.py`, today's RHR,
trailing-7-day MVPA-derived activity score). Persist to
`metric_sample(metric='vo2max_estimate', source='derived')`. Render
a card on Today + future `/activity` page with 90-day trend, age-
percentile, and explicit "estimate" framing.

This is **★★ (moderate)** — see [[non_exercise_vo2max]] for the
estimator's r=0.78 vs measured and its limitations.

## Dependencies

- Phase 1b (MVPA derivation) **must ship first** — Jurca needs the
  weekly MVPA total to map to its activity score (0–7).
- `profile.py` must have `age`, `sex`, and either `bmi` or
  (height + weight) for the user.

## Formula (Jurca 2005, sex-stratified)

```python
def jurca_vo2max(*, sex: str, age: int, bmi: float, rhr: float,
                 pa_score: int) -> float:
    """
    sex      : 'M' or 'F'
    age      : years (model validated 20–70)
    bmi      : kg/m²
    rhr      : resting heart rate, bpm (use 7-day median)
    pa_score : 0–7, mapped from weekly MVPA minutes
    """
    if sex == "M":
        return (56.363
                + 1.921 * pa_score
                - 0.381 * age
                - 0.754 * bmi
                - 0.084 * rhr)
    return (50.513
            + 1.589 * pa_score
            - 0.289 * age
            - 0.552 * bmi
            - 0.085 * rhr)
```

## Activity-score mapping (MVPA → 0–7)

```python
def mvpa_to_pa_score(weekly_mvpa_min: int) -> int:
    bands = [(0, 0), (60, 1), (120, 2), (180, 3),
             (300, 4), (450, 5), (600, 6)]
    for lo, score in reversed(bands):
        if weekly_mvpa_min >= lo:
            return score + 1 if score >= 5 and weekly_mvpa_min >= 600 else score
    return 7 if weekly_mvpa_min > 600 else 0
```

(Stops at 7; matches the ACLS recoding in [[non_exercise_vo2max]].)

## Backend

- New function `_derive_vo2max(day, conn)` in
  `src/healthee/analytics/derived.py`.
- Inputs:
  - `age` = today − DOB (from `profile.py`)
  - `bmi` = latest weight / height² (from latest `manual_entry`
    `weight_kg` + profile height)
  - `rhr` = 7-day rolling median of `metric_sample.rhr_daily`
  - `pa_score` = mapped from trailing 7-day `mvpa_min` sum
- Persist:
  - `metric_sample(metric='vo2max_estimate', value=<float>,
    source='derived', at_iso=23:59 IST of `day`)`
- Skip if any input is missing — don't write a wrong value.

## /api/today extension

```json
"vo2max": {
  "estimate": 41.2,
  "see_ml_kg_min": 5.6,            // ± SEE from Jurca
  "trend_90d": [{date, value}, ...],
  "age_percentile": 62,             // vs Mandsager 2018 age/sex norms
  "research_notes": ["vo2max_fitness_mortality",
                     "non_exercise_vo2max"],
  "as_of_date": "2026-05-15"
}
```

## Frontend

- New `web/src/components/today/vo2max-card.tsx`:
  - Hero: `41.2 ml/kg/min` (with `± 5.6` SEE shown small)
  - Subtext: "62nd percentile, age 32 M"
  - Mini sparkline: 90-day trend
  - Label: "estimate, non-exercise model"
  - Cite-chip: opens [[vo2max_fitness_mortality]] + [[non_exercise_vo2max]]

## Age-percentile reference

Hard-code a lookup table from Mandsager 2018 (Table 2 age/sex
quintiles) — small constant under
`src/healthee/analytics/vo2max_norms.py`. Approximate, not
clinical-grade; that's OK for trend visualization.

## Caveats baked into UI

- "Estimate" label always visible.
- Show **±SEE band** in the sparkline tooltip — don't hide
  uncertainty.
- "Trend matters more than absolute number" footer (BCT 13.2
  framing).
- If `RHR` is 7-day MAD > 8 bpm or `weight_kg` is missing,
  skip the derivation and show "Insufficient data".

## Out-of-scope

- Submaximal-test VO2max (cycling at a known wattage etc.) — not
  feasible from strap.
- HRmax estimation refinement (220−age vs Tanaka 208−0.7×age) — the
  Jurca model doesn't use HRmax, so doesn't matter for this metric.

## Sequencing within Phase 2

1. Hard-code Mandsager percentile table.
2. Derivation function + tests.
3. Wire into nightly `derive`.
4. /api/today field.
5. Today card.
