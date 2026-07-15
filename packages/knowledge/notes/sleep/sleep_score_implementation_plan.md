---
id: sleep_score_implementation_plan
topic: How healthee should display a multi-dimensional sleep score given the evidence in sleep_health_score_multidim
evidence_grade: 2
applies_to_metrics: [asleep, sleep_score, sleep_regularity_index, sleep_light_min, sleep_deep_min]
applies_to_interventions: []
tags: [sleep, scoring, dashboard, implementation, decision-rationale]
last_reviewed: 2026-05-13
---

## Recommendation

Build a **4-dimension binary sleep-health score, range 0–4, displayed
alongside (not in place of) the individual dimension cards.** Each dimension
sums 1 if that night meets a peer-reviewed cutoff, else 0. The composite is
labelled "Sleep health (4-dim)" and the UI always shows which dimensions
contributed.

This is **moderate-confidence (`★★`)**. The four-dimension wearable-only sum
is *not* directly validated against mortality in any single paper — it is
the closest research-backed thing we can build by combining individually
validated cutoffs (Cappuccio 2010 duration, AASM efficiency, Windred 2024
SRI, Wallace 2017 / Lee 2022 timing). See [[sleep_health_score_multidim]]
for the evidence walk-through.

We do **not** create a 0–100 continuous score. That decision in
[[no_validated_sleep_score]] still holds.

## The formula

```
SleepHealth4(night) =
    point_duration   (1 if 7.0 ≤ TST_hours ≤ 9.0           else 0)
  + point_efficiency (1 if TST / TIB ≥ 0.85                else 0)
  + point_timing     (1 if 02:00 ≤ sleep_midpoint < 04:00  else 0)
  + point_regularity (1 if SRI_7day ≥ 70                   else 0)
```

Range 0–4. Higher is better. The score is computed per-night for the first
three points; regularity is a 7-day rolling property attached to each night.

### Dimension 1 — Duration

- **Cutoff**: TST in `[7.0, 9.0]` hours.
- **Citation**: Cappuccio FP et al., *Sleep duration and all-cause mortality:
  meta-analysis*, Sleep 2010;33(5):585-92. See [[sleep_duration_mortality]].
  The 7–9 h band is the reference range with lowest mortality in 1.38 M
  participants across 16 prospective cohorts.
- **Why not Brindle 2019's 5h20–7h06**: that range is empirically derived in
  a 432-person derivation cohort against cardiometabolic morbidity, not
  validated against mortality. Cappuccio's 7–9 h has orders of magnitude
  more evidence weight. The cost is that we will award 0 points to nights
  in the 6–7 h zone that Brindle would have called "good."
- **SQL definition** (sketch, against a `session` row with `kind='sleep'`):

  ```sql
  CASE
    WHEN tst_minutes BETWEEN 420 AND 540 THEN 1
    ELSE 0
  END AS point_duration
  ```

### Dimension 2 — Efficiency

- **Cutoff**: TST / TIB ≥ 0.85 (i.e. 85 %).
- **Citation**: AASM clinical practice. Reproduced as the actigraphy
  efficiency cutoff in Lee 2022 ([[sleep_health_score_multidim]]) and
  consistently in Brindle 2019 (their empirical cutoff was 83 %, very close).
- **TIB** = `session.ended_at - session.started_at` for the in-bed window.
  **TST** = sum of light + deep + REM minutes (from stage classification),
  or equivalently `TIB - WASO - latency`.
- **Caveat**: TIB from a wrist wearable is *time-in-bed-detected*, not
  necessarily time the user was actually in bed. Sleep onset/offset detection
  via accelerometry has minor edge errors (~10 min). Acceptable for daily
  display, not for clinical grading.
- **SQL**:

  ```sql
  CASE
    WHEN (light_min + deep_min + rem_min) * 1.0
         / EXTRACT(EPOCH FROM (ended_at - started_at)) * 60 >= 0.85
    THEN 1 ELSE 0
  END AS point_efficiency
  ```

### Dimension 3 — Timing

- **Cutoff**: sleep midpoint in `[02:00, 04:00)` local time.
- **Citation**: Buysse 2014 RU-SATED definitional cutoff
  ([[sleep_health_score_multidim]]); replicated as the timing dimension in
  Wallace 2017 (≤ 2 AM or > 4 AM = "extreme") and Lee 2022 actigraphy
  composite. Saint-Maurice 2024 in UK Biobank (n = 88,282) reports HR 1.29
  for mortality at L5 midpoint < 02:30 vs reference 03:00–03:29.
- **Computation**: midpoint = `started_at + (ended_at − started_at) / 2`,
  taken in the user's local time zone.
- **Caveat**: this cutoff is shift-worker-hostile and may flag legitimate
  delayed-sleep-phase individuals as "bad" every night. The UI must offer a
  per-user override (chronotype) and a "neutral" rendering for that case.
- **SQL**:

  ```sql
  CASE
    WHEN EXTRACT(HOUR FROM (started_at + (ended_at - started_at) / 2)
                  AT TIME ZONE user_tz) IN (2, 3)
    THEN 1 ELSE 0
  END AS point_timing
  ```

### Dimension 4 — Regularity (SRI)

- **Cutoff**: SRI (7-day rolling) ≥ 70.
- **Citation**: Windred DP et al. 2024 ([[sleep_regularity_index]]) — UK
  Biobank n = 60,977. Mortality HR by SRI quintile: the 4th and 5th
  quintiles (highest regularity) had ~ 20–48 % lower all-cause mortality
  than Q1. The cutoff between Q4 and Q3 in that cohort is approximately
  SRI = 70.
- This is a 7-day property, not a single-night one. We attach it to each
  night by computing the SRI over the trailing 7 days including that night.
- See [[sleep_regularity_index]] for the full formula, computation window
  rules, and the existing implementation note (we already compute this).
- **SQL**: already exists; the implementation uses minute-level
  `metric_sample` rows of `asleep`.

## How it should display on the dashboard

```
┌─ Sleep health (4-dim) ─────────────────────────────────┐
│                                                         │
│    3 / 4                                                │
│                                                         │
│    Duration    7h 42m    Cappuccio 2010                │
│    Efficiency  91 %      AASM standard                 │
│    Timing      02:48     Buysse 2014; UK Biobank 2024  │
│    Regularity  62 (-)    Windred 2024 — below 70      │
│                                                         │
│    Why this number? sleep_health_score_multidim         │
└─────────────────────────────────────────────────────────┘
```

UI rules:

1. **Always show the four dimension breakdown.** The composite is never
   shown without its parts; users must be able to see *why* they scored what
   they did. This is the key difference from a Whoop/Oura "85" black box.
2. **No colours.** Numbers and a check / cross per dimension. No "red /
   amber / green" zones — those imply clinical thresholds we have not
   earned.
3. **Per-dimension citation** is one click away (anchored to the relevant
   research note).
4. **Personal baseline panel** sits next to the composite, showing the
   user's 30-day median score. Acute single-night reads are noisy; the
   chronic pattern is the signal.
5. **No 0–100 transformation.** A 4-point integer is honest about the
   resolution we have.

## Honest limitations to surface in the UI

Linked from a "Why this number?" panel that opens
[[sleep_health_score_multidim]]:

- **Two dimensions of RU-SATED (Satisfaction, Alertness) are not included**
  because they require self-report we don't collect. Composites that
  include them perform somewhat better in heart-disease validation (Lee
  2022: aRR 2.41 with all 6 vs aRR 1.54 with self-report-only 5).
- **The 4-dim wearable-only sum is not directly validated against
  mortality** in any single paper. It is assembled from four cutoffs each
  validated separately. By analogy with Wallace 2017 (5 of 7 actigraphy
  dimensions, HR 1.10 per extreme), we expect a modest predictive effect.
- **Binary cutoffs lose information.** 7h 1m and 9h 0m both score 1; so do
  6h 59m and 9h 1m score 0. A continuous version would be more
  informative but harder to communicate honestly.
- **Equal weighting is arbitrary.** Wallace 2017 showed dimensions
  contribute unequally to mortality. The Lee 2022 paper specifically tested
  weighted versions and the gain was modest; we keep equal weighting for
  interpretability.
- **Wearable stage classification is noisy.** Consumer-wrist macro-F1 vs
  PSG is 0.26–0.69 (Chinoy 2021). TST and efficiency inherit that noise.
- **Timing cutoff is chronotype-blind.** A consistent 23:00–07:00 sleeper
  with midpoint 03:00 scores 1; a consistent 01:00–09:00 night-shift worker
  with midpoint 05:00 scores 0 every night despite being healthily
  regular. Per-user override needed.

## What this does NOT replace

- [[no_validated_sleep_score]] remains the policy on commercial 0–100
  scores. We do not display Zepp's, Whoop's, Oura's, or any other
  proprietary continuous score.
- The four individual dimension cards (Duration / Efficiency / Regularity /
  Timing) remain primary. The composite is a *summary*, not a replacement.

## Pending decisions

- Whether to show `point_timing` at all for users whose self-reported
  chronotype falls outside the 22:00–08:00 sleep window. Default: hide /
  mark "N/A" with a one-line explanation.
- Whether to display the score on the daily card or only on the weekly /
  monthly view. Given the evidence-size of single-night composites, the
  weekly view is more defensible. Lean weekly-default, daily-on-tap.

## References

- [[sleep_health_score_multidim]] — the evidence review this plan
  derives from.
- [[no_validated_sleep_score]] — the still-binding policy against
  proprietary continuous composites.
- [[sleep_duration_mortality]] — Cappuccio 2010, source of the 7–9 h
  cutoff.
- [[sleep_regularity_index]] — Phillips 2017 / Windred 2024, source of the
  SRI cutoff.
- [[sleep_consistency]] — companion note on day-to-day variability.
- Buysse DJ, *Sleep health: can we define it? Does it matter?* Sleep
  37(1):9-17 (2014). Source of the timing 02:00–04:00 cutoff.
- AASM clinical practice — source of the ≥ 85 % efficiency cutoff,
  reproduced in Lee 2022.
