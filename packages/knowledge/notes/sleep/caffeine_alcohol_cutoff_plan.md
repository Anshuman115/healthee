---
id: caffeine_alcohol_cutoff_plan
name: "Personal caffeine/alcohol cutoff-time finder (plan)"
topic: Implementation plan — personal caffeine/alcohol cutoff-time finder using existing logs + correlation engine
category: sleep
grade: Probable
summary: "Implementation plan for a server-side per-user cutoff-time finder that mines existing intake logs + sleep outcomes to surface the personal time-of-day past which caffeine/alcohol measurably degrades that night's sleep — moderate confidence, since the intake→sleep effect is strong but per-user threshold detection adds n=1 uncertainty."
aliases: ["caffeine cutoff", "alcohol cutoff", "coffee cutoff time", "when to stop caffeine", "last coffee", "caffeine before bed", "alcohol before bed", "personal cutoff finder", "intake cutoff"]
applies_to_metrics: ["tst_min", "hrv_sleep_avg", "rhr_daily", "sleep_health_score_4dim"]
applies_to_interventions: ["caffeine", "alcohol"]
population: general
last_reviewed: 2026-07-15
related: ["caffeine_sleep", "alcohol_sleep", "sleep_regularity_index", "no_validated_sleep_score", "sleep_and_recovery"]
tags: [implementation, caffeine, alcohol, sleep, recommendations]
---

# Personal caffeine/alcohol cutoff-time finder (plan)

## Summary

Build a server-side **personal cutoff-time finder** for both caffeine and alcohol
that surfaces (1) the personal time-of-day threshold past which intake measurably
degrades next-night sleep, and (2) the quantified effect size. This is **★★
(moderate)** — the underlying intake-vs-sleep effect is ★★★ (see `caffeine_sleep`
and `alcohol_sleep`); the per-user threshold detection adds n=1 statistical
uncertainty. This note is the implementation plan; the physiological evidence lives
in the intake notes it cites.

## What it is

A per-user analytics feature that mines the user's *own* logged intake events
against their measured sleep outcomes to find where "later intake" starts to hurt
sleep — an **observed** personal threshold in their data, not a metabolic constant.
It reuses the existing manual-log store, the correlation engine, and the `finding`
table surface, so no new UI component is required.

## Physiology / mechanism

The mechanism is inherited from the intake notes: **caffeine** antagonises
adenosine receptors and has a long half-life (~5–6 h, genotype-dependent via
CYP1A2), so afternoon/evening doses still occupy receptors at bedtime, delaying
onset and reducing deep sleep (`caffeine_sleep`); **alcohol** sedates onset but
fragments the second half of the night and suppresses REM as it clears, and blunts
overnight HRV (`alcohol_sleep`). Because both effects are dose- and timing-
dependent, a *personal* cutoff hour is a meaningful, individual quantity — bounded
below by genotype (CYP1A2 / ADH1B) but expressed through the user's own data.

## The evidence

- **[Probable]** The **per-user threshold detection** adds n=1 statistical
  uncertainty on top of the population effect — hence ★★ (moderate) overall.
- **[Established]** The **underlying intake→sleep effects** are ★★★: caffeine
  (Drake 2013 direction) and alcohol (Ebrahim 2013 direction) degrade objective
  sleep — see `caffeine_sleep` and `alcohol_sleep`, whose citations gate the
  direction check in the algorithm below (a detected cutoff must match the
  literature direction to surface).

## How we compute it

### Data we have

- `manual_entry` rows with `kind ∈ {'caffeine', 'alcohol'}`, `at_iso`,
  `payload.mg` (caffeine) or `payload.units` (alcohol)
- `metric_sample` per-day: `sleep_efficiency`, `tst_min`, `hrv_sleep_avg_ms`,
  `rhr_daily`, `sri`, `sleep_health_score_4dim`
- `session(kind='sleep')` with `start_iso` / `end_iso`

### Algorithm

For each substance ∈ {caffeine, alcohol}:

1. **Bucket** each intake event by `hour(at_iso, local=IST)` and amount (mg for
   caffeine; units for alcohol).
2. **Pair** each event with the **same-night** sleep session (event_at <
   session.start_iso < event_at + 18h).
3. For each sleep outcome metric (`tst_min`, `efficiency_pct`, `hrv_sleep_avg_ms`,
   `rhr_daily`):
   - Compute Spearman ρ between event-hour-of-day and outcome, restricted to nights
     with ≥1 intake event.
   - Compute Mann-Whitney U comparing "intake before vs after H" for each cutoff
     H ∈ {12, 14, 16, 18, 20, 22}.
   - Identify the **earliest H** where the post-H group has median outcome that is
     significantly worse (p<0.05 AND |effect_size| matches the Drake-2013 /
     Ebrahim-2013 direction in `caffeine_sleep` and `alcohol_sleep`).
4. Persist as a `finding` row with new `kind='personal_cutoff'`,
   `metric_a=<substance>_after_<H>`, `metric_b=<outcome>`, plus regular
   `effect_size`, `q_value`, `n_samples`.

### Minimum n

- Don't surface if `n_intake_events < 10` (per substance).
- Don't surface if the **paired-sleep n** for the "after H" group is < 5
  (statistical floor).
- Apply the same trivial-finding filter from `correlate.py` (small-n
  perfect-correlation rejection at |r|≥0.97, n<20).

### Backend

- New module `src/healthee/analytics/cutoff_finder.py`.
- Wired into `healthee correlate` so it runs as part of the weekly systemd job (no
  new schedule needed).
- Findings flow through the existing `finding` table → already on Sleep page;
  auto-surfaces.

#### finding row shape

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

### Frontend

- No new component. Picked up by existing `SleepFindings` and the Today
  `FindingsCard`. `lib/finding-text.ts` gets one new branch for
  `kind='personal_cutoff'` that renders:
  - Hero: "Your caffeine cutoff is **14:00 IST**"
  - Body: "Caffeine logged after 14:00 → TST 6.4h vs 7.1h (n=22)"
  - Citation chip → `caffeine_sleep` or `alcohol_sleep`

## How the coach uses it

- Only surface a cutoff once the minimum-n and direction checks pass; present it as
  *your observed* cutoff, with n and the effect, plus the citation chip.
- Frame it as an actionable behaviour ("last coffee by ~14:00"), and keep the
  citation to the intake note visible.
- If logging is sparse or the threshold flips month-to-month, say so — do not
  present a noisy n=1 threshold as fixed.

## Safety bounds

No physiological guardrail. This is descriptive analytics over the user's own data;
never presented as a metabolic floor or medical instruction, only an observed
association with its n and effect size.

## Honesty & uncertainty

Caveats to bake into the UI:

- Personal threshold can flip month-to-month if logging is sparse.
- The "real" cutoff is bounded by individual CYP1A2 / ADH1B genotype — see
  `caffeine_sleep`; this is the **observed** threshold in *your* data, not a
  metabolic floor.
- Two-or-three same-day caffeine doses confound the hour-of-day signal; we use the
  latest event per day.

**Out-of-scope:**
- Dose-response slope (mg → minutes) — wait for more data.
- Cross-substance interaction (caffeine × alcohol same day).

## Bottom line

**Act on confidently:** the intake→sleep effects are strong and well-cited
(caffeine, alcohol); mining a user's own logs for an *observed* cutoff hour, gated
by a minimum-n and a literature-direction check, is a sound, honest feature.

**Hold loosely:** the exact personal cutoff hour (n=1, can flip with sparse
logging); it is an observed threshold, not a metabolic floor; dose-response slope
and cross-substance interactions are out of scope until more data.

## Coach Directives

1. Surface a personal cutoff only when n≥10 intake events, paired-sleep n≥5 in the
   post-H group, and the effect matches the literature direction. *(confidence: moderate)*
2. Present it as the user's *observed* cutoff with n + effect size + intake-note
   citation — never as a metabolic floor or medical rule. *(confidence: high)*
3. Flag instability when logging is sparse (threshold can flip month-to-month).
   *(confidence: high)*
4. Use the latest same-day dose to avoid multi-dose hour-of-day confounding.
   *(confidence: moderate)*

## References

- `caffeine_sleep` — caffeine→sleep effect and CYP1A2 genotype bound (Drake 2013).
- `alcohol_sleep` — alcohol→sleep/HRV effect (Ebrahim 2013).
- (This is an implementation plan; the primary-source citations live in the two
  intake notes above, which the finding's `research_note_ids` point to.)

## Healthee implementation & honesty policy

- **No new derived metric.** The feature persists `finding` rows
  (`kind='personal_cutoff'`) computed by a planned
  `analytics/cutoff_finder.py`, run inside the weekly `correlate` job, and surfaced
  through the existing Sleep findings UI. Inputs: `manual_entry` (caffeine/alcohol)
  paired same-night with sleep outcomes (`tst_min`, `efficiency_pct`,
  `hrv_sleep_avg`, `rhr_daily`, `sleep_health_score_4dim`, `sri`).
- **Honesty policy:** a cutoff is an **observed** per-user association (with n,
  effect size, q-value, and an intake-note citation), gated by minimum-n and a
  literature-direction match — never a metabolic floor, never a medical directive;
  instability under sparse logging must be surfaced. Reuses the trivial-finding
  rejection from `correlate.py` (|r|≥0.97, n<20).
- **Status:** this note is a *plan* (methodology of record), not yet shipped; the
  `applies_to_metrics` use v2 names (`hrv_sleep_avg`, `tst_min`,
  `sleep_health_score_4dim`, `rhr_daily`).
