---
id: caffeine_alcohol_cutoff_plan
topic: Implementation plan — personal caffeine/alcohol cutoff-time finder using existing logs + correlation engine
evidence_grade: 2
applies_to_metrics: [asleep, hrv_rmssd_ms, rhr_daily]
applies_to_interventions: []
tags: [implementation, caffeine, alcohol, sleep, recommendations]
last_reviewed: 2026-05-15
---

## Recommendation

Build a server-side **personal cutoff-time finder** for both caffeine
and alcohol that surfaces (1) the personal time-of-day threshold past
which intake measurably degrades next-night sleep, and (2) the
quantified effect size.

This is **★★ (moderate)** — the underlying intake-vs-sleep effect is
★★★ (see [[caffeine_sleep]] and [[alcohol_sleep]]); the per-user
threshold detection adds n=1 statistical uncertainty.

## Data we have

- `manual_entry` rows with `kind ∈ {'caffeine', 'alcohol'}`,
  `at_iso`, `payload.mg` (caffeine) or `payload.units` (alcohol)
- `metric_sample` per-day: `sleep_efficiency`, `tst_min`, `hrv_sleep_avg_ms`,
  `rhr_daily`, `sri`, `sleep_health_score_4dim`
- `session(kind='sleep')` with `start_iso` / `end_iso`

## Algorithm

For each substance ∈ {caffeine, alcohol}:

1. **Bucket** each intake event by `hour(at_iso, local=IST)` and
   amount (mg for caffeine; units for alcohol).
2. **Pair** each event with the **same-night** sleep session
   (event_at < session.start_iso < event_at + 18h).
3. For each sleep outcome metric (`tst_min`, `efficiency_pct`,
   `hrv_sleep_avg_ms`, `rhr_daily`):
   - Compute Spearman ρ between event-hour-of-day and outcome,
     restricted to nights with ≥1 intake event.
   - Compute Mann-Whitney U comparing "intake before vs after H"
     for each cutoff H ∈ {12, 14, 16, 18, 20, 22}.
   - Identify the **earliest H** where the post-H group has
     median outcome that is significantly worse (p<0.05 AND
     |effect_size| matches the Drake-2013 / Ebrahim-2013 direction
     in [[caffeine_sleep]] and [[alcohol_sleep]]).
4. Persist as a `finding` row with new `kind='personal_cutoff'`,
   `metric_a=<substance>_after_<H>`, `metric_b=<outcome>`, plus
   regular `effect_size`, `q_value`, `n_samples`.

## Minimum n

- Don't surface if `n_intake_events < 10` (per substance).
- Don't surface if the **paired-sleep n** for the "after H"
  group is < 5 (statistical floor).
- Apply the same trivial-finding filter from `correlate.py`
  (small-n perfect-correlation rejection at |r|≥0.97, n<20).

## Backend

- New module `src/healthee/analytics/cutoff_finder.py`.
- Wired into `healthee correlate` so it runs as part of the weekly
  systemd job (no new schedule needed).
- Findings flow through the existing `finding` table → already on
  Sleep page; auto-surfaces.

### finding row shape

```python
finding(
    kind="personal_cutoff",
    metric_a="caffeine_after_14",  # or "alcohol_after_18"
    metric_b="tst_min",            # or "efficiency_pct" / "hrv_sleep_avg_ms"
    event_kind=None,
    lag_days=0,                    # same-night pairing
    effect_metric="mann_whitney_rb",
    effect_size=-0.42,              # rank-biserial; negative = worse
    q_value=0.01,
    n_samples=22,
    description_raw=(
        "Caffeine after 14:00 IST associated with TST median 6.4h "
        "vs 7.1h on non-after-14 nights (n=22, q=0.01)."
    ),
    research_note_ids=["caffeine_sleep"],
)
```

## Frontend

- No new component. Picked up by existing `SleepFindings` and the
  Today `FindingsCard`. `lib/finding-text.ts` gets one new branch
  for `kind='personal_cutoff'` that renders:
  - Hero: "Your caffeine cutoff is **14:00 IST**"
  - Body: "Caffeine logged after 14:00 → TST 6.4h vs 7.1h (n=22)"
  - Citation chip → `caffeine_sleep` or `alcohol_sleep`

## Caveats to bake into the UI

- Personal threshold can flip month-to-month if logging is sparse.
- The "real" cutoff is bounded by individual CYP1A2 / ADH1B
  genotype — see [[caffeine_sleep]]; this is the **observed**
  threshold in *your* data, not a metabolic floor.
- Two-or-three same-day caffeine doses confound the hour-of-day
  signal; we use the latest event per day.

## Out-of-scope

- Dose-response slope (mg → minutes) — wait for more data.
- Cross-substance interaction (caffeine × alcohol same day).
