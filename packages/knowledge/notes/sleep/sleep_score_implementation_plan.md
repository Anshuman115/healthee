---
id: sleep_score_implementation_plan
name: "4-dimension sleep-health score (implementation plan)"
topic: How healthee should display a multi-dimensional sleep score given the evidence in sleep_health_score_multidim
category: sleep
grade: Probable
evidence_grade: 2
summary: "Build a 0–4 binary sleep-health score (duration, efficiency, timing, regularity), each dimension 1 if it meets its documented cutoff, always shown alongside its four dimensions and citations — never a 0–100 continuous score; a moderate-confidence extrapolation whose cutoffs are separately sourced and unequally strong (duration mortality-validated; efficiency clinical consensus; regularity derived from a quintile boundary), not a directly-validated composite."
aliases: ["sleep health score", "4-dim sleep score", "sleep score implementation", "RU-SATED score", "sleep dimensions", "duration efficiency timing regularity", "sleep dashboard score"]
applies_to_metrics: ["sleep_health_score_4dim", "sleep_regularity_index", "tst_min"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
related: ["sleep_health_score_multidim", "no_validated_sleep_score", "sleep_duration_mortality", "sleep_regularity_index", "sleep_consistency", "wearable_sleep_stage_validity"]
tags: [sleep, scoring, dashboard, implementation, decision-rationale]
---

# 4-dimension sleep-health score (implementation plan)

## Summary

Build a **4-dimension binary sleep-health score, range 0–4, displayed alongside
(not in place of) the individual dimension cards.** Each dimension sums 1 if that
night meets a peer-reviewed cutoff, else 0. The composite is labelled "Sleep health
(4-dim)" and the UI always shows which dimensions contributed. This is
**moderate-confidence (★★)**: the four-dimension wearable-only sum is *not* directly
validated against mortality in any single paper — it is the closest research-backed
thing we can build by combining separately-sourced cutoffs (Cappuccio 2010 duration,
Schutte-Rodin 2008/AASM efficiency, Wallace 2017 / Lee 2022 timing, and a regularity
cutoff **derived** from Windred 2024's quintile boundary — see Dimension 4; only
Duration is validated against mortality *as a cutoff*). See
`sleep_health_score_multidim` for the evidence walk-through. We do **not** create a
0–100 continuous score — that decision in `no_validated_sleep_score` still holds.

## What it is

The shipped composite is a **0–4 integer** = the count of RU-SATED dimensions
(Duration, Efficiency, Timing, Regularity) meeting their peer-reviewed cutoffs on a
given night. It is a *summary* of the four wearable-computable dimensions, never a
replacement for them, and deliberately not transformed to a 0–100 scale (that
resolution isn't real). This note is the build/display plan; the evidence review is
`sleep_health_score_multidim`; the refusal of proprietary continuous scores is
`no_validated_sleep_score`.

## Physiology / mechanism

Each dimension indexes a distinct, physiologically-grounded strand of sleep health:
Duration (total restorative sleep, U-shaped with mortality), Efficiency (continuity/
fragmentation), Timing (circadian alignment), and Regularity (circadian stability;
see `sleep_regularity_index`). Because these strands are partly independent and
carry distinct outcome information, a sum-of-binaries treats them as co-equal, first-
pass flags rather than asserting a validated weighting — which is exactly why it is
shown *with* its parts and held at moderate confidence.

## The evidence

### The formula

```
SleepHealth4(night) =
    point_duration   (1 if 7.0 ≤ TST_hours ≤ 9.0           else 0)
  + point_efficiency (1 if TST / TIB ≥ 0.85                else 0)
  + point_timing     (1 if 02:00 ≤ sleep_midpoint < 04:00  else 0)
  + point_regularity (1 if SRI_7day ≥ 70                   else 0)
```

Range 0–4. Higher is better. The score is computed per-night for the first three
points; regularity is a 7-day rolling property attached to each night.

### Dimension 1 — Duration [Established cutoff]

- **Cutoff**: TST in `[7.0, 9.0]` hours.
- **Citation**: Cappuccio FP et al., *Sleep duration and all-cause mortality:
  meta-analysis*, Sleep 2010;33(5):585-92. See `sleep_duration_mortality`. The
  7–9 h band is the reference range with lowest mortality in 1.38 M participants
  across 16 prospective cohorts.
- **Why not Brindle 2019's 5h20–7h06**: that range is empirically derived in a
  432-person derivation cohort against cardiometabolic morbidity, not validated
  against mortality. Cappuccio's 7–9 h has orders of magnitude more evidence weight.
  The cost is that we will award 0 points to nights in the 6–7 h zone that Brindle
  would have called "good."
- **SQL definition** (sketch, against a `session` row with `kind='sleep'`):

  ```sql
  CASE
    WHEN tst_minutes BETWEEN 420 AND 540 THEN 1
    ELSE 0
  END AS point_duration
  ```

### Dimension 2 — Efficiency [Probable cutoff — clinical consensus, not outcome-validated]

- **Cutoff**: TST / TIB ≥ 0.85 (i.e. 85 %).
- **Citation**: Schutte-Rodin S, Broch L, Buysse D, Dorsey C, Sateia M. *Clinical
  guideline for the evaluation and management of chronic insomnia in adults.* J Clin
  Sleep Med 2008;4(5):487–504. PMID 18853708 — an **AASM clinical guideline** (this is
  the document behind what the corpus previously called, without author or year, "AASM
  clinical practice"; the AASM *Scoring Manual* defines how to compute sleep efficiency
  but sets no normal cutoff). Verified verbatim 2026-08-01: *"Common complaints for
  insomnia patients are an average sleep latency >30 minutes, wake after sleep onset
  >30 minutes, sleep efficiency <85%, and/or total sleep time <6.5 hours"*, and, as a
  treatment goal, *"Set bedtime and wake-up times to approximate the mean TST to
  achieve a >85% sleep efficiency (TST/TIB × 100%) over 7 days"* / *"TST >6 hours
  and/or sleep efficiency >80% to 85%."*
- **What that citation does and does not support.** It supports 85 % as the
  long-standing AASM clinical reference point for adult sleep efficiency. It does
  **not** make 85 % an outcome-validated threshold: the guideline is
  consensus/practice-parameter based, the figure is stated as an insomnia-complaint and
  treatment-target level rather than derived against a health outcome, and the same
  guideline elsewhere gives the goal as a **range, ">80 % to 85 %"** — so the specific
  choice of 0.85 over 0.80 is ours. Grade it **Probable**, not Established.
- **Independent reproduction**: Lee 2022 (`sleep_health_score_multidim`) scores the
  actigraphy Efficiency dimension at *"1: < 85%"* (Table 3) — checked in the paper's
  full text 2026-08-01; Lee attaches no citation of their own to the number. Brindle
  2019's *empirically derived* cutoff in its own cohort was 83 %, close but independent.
- **TIB** = `session.ended_at - session.started_at` for the in-bed window. **TST** =
  sum of light + deep + REM minutes (from stage classification), or equivalently
  `TIB - WASO - latency`.
- **Caveat**: TIB from a wrist wearable is *time-in-bed-detected*, not necessarily
  time the user was actually in bed. Sleep onset/offset detection via accelerometry
  has minor edge errors (~10 min). Acceptable for daily display, not for clinical
  grading.
- **SQL**:

  ```sql
  CASE
    WHEN (light_min + deep_min + rem_min) * 1.0
         / EXTRACT(EPOCH FROM (ended_at - started_at)) * 60 >= 0.85
    THEN 1 ELSE 0
  END AS point_efficiency
  ```

### Dimension 3 — Timing [Probable cutoff]

- **Cutoff**: sleep midpoint in `[02:00, 04:00)` local time.
- **Citation**: Buysse 2014 RU-SATED definitional cutoff
  (`sleep_health_score_multidim`); replicated as the timing dimension in Wallace
  2017 (≤ 2 AM or > 4 AM = "extreme") and Lee 2022 actigraphy composite.
  Saint-Maurice 2024 in UK Biobank (n = 88,282) reports HR 1.29 for mortality at L5
  midpoint < 02:30 vs reference 03:00–03:29.
- **Computation**: midpoint = `started_at + (ended_at − started_at) / 2`, taken in
  the user's local time zone.
- **Caveat**: this cutoff is shift-worker-hostile and may flag legitimate
  delayed-sleep-phase individuals as "bad" every night. The UI must offer a per-user
  override (chronotype) and a "neutral" rendering for that case.
- **SQL**:

  ```sql
  CASE
    WHEN EXTRACT(HOUR FROM (started_at + (ended_at - started_at) / 2)
                  AT TIME ZONE user_tz) IN (2, 3)
    THEN 1 ELSE 0
  END AS point_timing
  ```

### Dimension 4 — Regularity (SRI) [DERIVED cutoff — no published threshold of 70 exists]

- **Cutoff**: SRI (7-day rolling) ≥ 70.
- **What Windred 2024 actually says** (`sleep_regularity_index`) — UK Biobank
  n = 60,977, median [IQR] SRI 81.0 [73.8–86.3], verified verbatim 2026-08-01:
  *"Higher sleep regularity was associated with a 20%–48% lower risk of all-cause
  mortality … across the top four SRI quintiles compared to the least regular
  quintile"*, where the least-regular quintile is *"SRI < 71.6"* and *"the top four
  quintiles (SRI 71.6–98.5)"*. **The paper never states a threshold of 70.**
- **Correction (2026-08-01).** This note previously justified 70 as *"the cutoff
  between Q4 and Q3 in that cohort"*. That is false and arithmetically impossible: with
  a median of 81.0 the Q3/Q4 boundary is ≈ 83, and 70 sits **below the 25th percentile
  (73.8)**. The real boundary near 70 is the opposite one — Q1/Q2 at **SRI 71.6**, the
  line separating the highest-mortality quintile from the rest.
- **So 70 is DERIVED, not cited**: it is Windred's least-regular-quintile boundary
  (71.6) rounded down to a round number, i.e. an operational stand-in for "not in the
  worst quintile". Honest consequences of the rounding, both of which must be stated
  rather than hidden:
  1. Because 70 < 71.6, a night at SRI 70–71.5 earns the Regularity point while
     Windred's cohort would place that person in the **highest-mortality** quintile.
     Whether to move the constant to 71.6 is a science-code change and therefore its own
     PR with known-value tests; it is **not** made here.
  2. SRI values are **not comparable across pipelines**. Windred computed SRI with
     `sleepreg`, which *"uses sustained inactivity data to account for naps, fragmented
     sleep, and large periods of wake during sleep"*; Cribb 2023's UK Biobank cohort —
     the same biobank — reports a **median SRI of 60** against Windred's 81. Ours is
     night-only global Phillips SRI. A boundary borrowed from one distribution is
     therefore approximate on ours by an unmeasured amount.
- Independent corroboration that a threshold in this region is defensible, though
  neither derives 70: Chaput et al. 2025 (J Epidemiol Community Health 79(4):257–264,
  PMID 39603689) classify **irregular as SRI < 71.6** in 72,269 UK Biobank adults
  (MACE HR 1.26); Li et al. 2025 (Psychol Med 55:e239) classify **regular as SRI ≥ 71**
  — but by their own cohort's 75th percentile, not by an outcome.
- This is a 7-day property, not a single-night one. We attach it to each night by
  computing the SRI over the trailing 7 days including that night.
- See `sleep_regularity_index` for the full formula, computation window rules, and
  the existing implementation note (we already compute this).
- **SQL**: already exists; the implementation uses minute-level `metric_sample` rows
  of `asleep`.

## How we compute it

The shipped derivation (`derive/sleep_score.py::derive_sleep_score`) implements the
formula above and writes both the composite `sleep_health_score_4dim` (0–4) and the
four per-dimension 0/1 rows (`sleep_dim_duration/efficiency/timing/regularity`), with
raw measurements (`tst_min`, `tib_min`, `efficiency_pct`, `midpoint_local`,
`midpoint_hr`, `sri`) carried in `flags`. See the implementation section below for
the shipped constants and the one deviation from these SQL sketches (efficiency is
computed asleep/(asleep+wake), clamped ≤1, not raw TST/wall-clock TIB).

## How the coach uses it

How it should display on the dashboard:

```
┌─ Sleep health (4-dim) ─────────────────────────────────┐
│                                                         │
│    3 / 4                                                │
│                                                         │
│    Duration    7h 42m    Cappuccio 2010                │
│    Efficiency  91 %      AASM (Schutte-Rodin 2008)     │
│    Timing      02:48     Buysse 2014; UK Biobank 2024  │
│    Regularity  62 (-)    below 70 (from Windred 2024)  │
│                                                         │
│    Why this number? sleep_health_score_multidim         │
└─────────────────────────────────────────────────────────┘
```

UI rules:

1. **Always show the four dimension breakdown.** The composite is never shown
   without its parts; users must be able to see *why* they scored what they did.
   This is the key difference from a Whoop/Oura "85" black box.
2. **No colours.** Numbers and a check / cross per dimension. No "red / amber /
   green" zones — those imply clinical thresholds we have not earned.
3. **Per-dimension citation** is one click away (anchored to the relevant research
   note).
4. **Personal baseline panel** sits next to the composite, showing the user's 30-day
   median score. Acute single-night reads are noisy; the chronic pattern is the
   signal.
5. **No 0–100 transformation.** A 4-point integer is honest about the resolution we
   have.

## Safety bounds

No physiological guardrail attaches to the score. The binding constraint is
product-integrity: never render it as a validated continuous number and never apply
clinical red/amber/green zones. Sleep-loss safety bounds live in
`sleep_and_recovery` and `sleep_need_debt`.

## Honesty & uncertainty

Honest limitations to surface in the UI (linked from a "Why this number?" panel that
opens `sleep_health_score_multidim`):

- **Two dimensions of RU-SATED (Satisfaction, Alertness) are not included** because
  they require self-report we don't collect. Composites that include them perform
  somewhat better in heart-disease validation (Lee 2022: aRR 2.41 with all 6 vs aRR
  1.54 with self-report-only 5).
- **The 4-dim wearable-only sum is not directly validated against mortality** in any
  single paper. It is assembled from four cutoffs each validated separately. By
  analogy with Wallace 2017 (5 of 7 actigraphy dimensions, HR 1.10 per extreme), we
  expect a modest predictive effect.
- **Binary cutoffs lose information.** 7h 1m and 9h 0m both score 1; so do 6h 59m and
  9h 1m score 0. A continuous version would be more informative but harder to
  communicate honestly.
- **Equal weighting is arbitrary.** Wallace 2017 showed dimensions contribute
  unequally to mortality. The Lee 2022 paper specifically tested weighted versions
  and the gain was modest; we keep equal weighting for interpretability.
- **Wearable stage classification is noisy.** Consumer-wrist macro-F1 vs PSG is
  0.26–0.69 (Chinoy 2021). TST and efficiency inherit that noise.
- **Timing cutoff is chronotype-blind.** A consistent 23:00–07:00 sleeper with
  midpoint 03:00 scores 1; a consistent 01:00–09:00 night-shift worker with midpoint
  05:00 scores 0 every night despite being healthily regular. Per-user override
  needed.

**What this does NOT replace:**

- `no_validated_sleep_score` remains the policy on commercial 0–100 scores. We do not
  display Zepp's, Whoop's, Oura's, or any other proprietary continuous score.
- The four individual dimension cards (Duration / Efficiency / Regularity / Timing)
  remain primary. The composite is a *summary*, not a replacement.

**Pending decisions:**

- Whether to show `point_timing` at all for users whose self-reported chronotype
  falls outside the 22:00–08:00 sleep window. Default: hide / mark "N/A" with a
  one-line explanation.
- Whether to display the score on the daily card or only on the weekly / monthly
  view. Given the evidence-size of single-night composites, the weekly view is more
  defensible. Lean weekly-default, daily-on-tap.

## Bottom line

**Act on confidently:** show a transparent 0–4 count with all four dimensions and
their citations; each *cutoff* is individually validated; never a 0–100 black box.

**Hold loosely:** the 4-dim sum as a *composite* (not directly validated together —
moderate confidence, an extrapolation); equal weighting; the chronotype-blind timing
point; single-night reads (prefer the chronic/weekly pattern).

## Coach Directives

1. Show the composite as a 0–4 integer **always with its four dimensions and
   per-dimension citations**; never a 0–100 score, never colour-coded clinical
   zones. *(confidence: high)*
2. Describe the 4-dim sum as a moderate-confidence extrapolation from individually-
   validated cutoffs, not a directly-validated composite. *(confidence: high)*
3. Prefer the chronic/weekly pattern (30-day median) over single-night reads.
   *(confidence: high)*
4. Offer a per-user chronotype override / neutral rendering for the timing point.
   *(confidence: moderate)*

## References

- `sleep_health_score_multidim` — the evidence review this plan derives from.
- `no_validated_sleep_score` — the still-binding policy against proprietary
  continuous composites.
- `sleep_duration_mortality` — Cappuccio 2010, source of the 7–9 h cutoff.
- `sleep_regularity_index` — Phillips 2017 / Windred 2024, source of the SRI cutoff.
- `sleep_consistency` — companion note on day-to-day variability.
- Buysse DJ, *Sleep health: can we define it? Does it matter?* Sleep 37(1):9-17
  (2014). Source of the timing 02:00–04:00 cutoff.
- Schutte-Rodin S, Broch L, Buysse D, Dorsey C, Sateia M. *Clinical guideline for the
  evaluation and management of chronic insomnia in adults.* J Clin Sleep Med
  4(5):487–504 (2008). PMID 18853708. The AASM document behind the ≥ 85 % efficiency
  cutoff (previously cited in this corpus only as "AASM clinical practice"); reproduced
  as `< 85 %` in Lee 2022's actigraphy composite.
- Windred DP, Burns AC, Lane JM, Saxena R, Rutter MK, Cain SW, Phillips AJK. *Sleep
  regularity is a stronger predictor of mortality risk than sleep duration: a
  prospective cohort study.* Sleep 47(1):zsad253 (2024). DOI 10.1093/sleep/zsad253.
  PMID 37738616. (n = 60,977; median [IQR] SRI 81.0 [73.8–86.3]; least-regular quintile
  SRI < 71.6 — the boundary our 70 is rounded down from. It states no cutoff of 70.)
- Chaput J-P, Biswas RK, Ahmadi M, Cistulli PA, Rajaratnam SMW, Bian W, St-Onge M-P,
  Stamatakis E. *Sleep regularity and major adverse cardiovascular events: a
  device-based prospective study in 72 269 UK adults.* J Epidemiol Community Health
  79(4):257–264 (2025). DOI 10.1136/jech-2024-222795. PMID 39603689. (Irregular =
  SRI < 71.6.)
- Li DR, Li ZX, Li MH, et al. *Regular sleep patterns, not just duration, critical for
  mental health.* Psychological Medicine 55:e239 (2025). DOI 10.1017/S0033291725101281.
  (Regular = SRI ≥ 71, by that cohort's 75th percentile.)
- Saint-Maurice PF, Freeman JR, Russ D, et al. *Associations between
  actigraphy-measured sleep duration, continuity, and timing with mortality in the
  UK Biobank.* Sleep 47(3):zsad312 (2024). PMID 38066693. (Timing HR 1.29.)

## Healthee implementation & honesty policy

- **Derived fields:** `sleep_health_score_4dim` (0–4) plus the four per-dimension
  rows `sleep_dim_duration`, `sleep_dim_efficiency`, `sleep_dim_timing`,
  `sleep_dim_regularity` (each 0/1) in `derived_daily`. Provenance:
  `derive/sleep_score.py::derive_sleep_score`, ported verbatim from legacy v2.
  Cutoff constants: `SLEEP_DURATION_MIN_H=7.0`, `SLEEP_DURATION_MAX_H=9.0`
  (Cappuccio 2010); `SLEEP_EFFICIENCY_MIN=0.85` (Schutte-Rodin 2008, an AASM clinical
  guideline — clinical consensus, and the guideline's own goal is the range
  ">80 % to 85 %"); `SLEEP_TIMING_RANGE=(2,4)` midpoint hour (Buysse 2014);
  `SRI_GOOD=70.0` (**derived**: Windred 2024's least-regular-quintile boundary
  SRI < 71.6, rounded down — no paper states 70; see Dimension 4).
- **Shipped deviation from the SQL sketches (documented):** efficiency is computed
  as `tst/(tst+wake)`, **clamped ≤1** (`_sleep_efficiency`), not the legacy raw
  TST/wall-clock-TIB which could exceed 100 %. Raw `tst_min`, `tib_min`,
  `efficiency_pct`, `midpoint_local`, `midpoint_hr`, `sri` ride in `flags`.
- **Composite-score exception:** this is a **documented, user-approved** exception
  to the no-composite rule — allowed only because it is a transparent count with a
  mandatory per-dimension breakdown + citations, never a 0–100 black box (parity
  with `recovery_score`, see `recovery_readiness`; policy in
  `no_validated_sleep_score`).
- **Honesty policy:** always render the four dimensions and their sources; no colour
  zones; label as moderate-confidence extrapolation; prefer the 30-day median;
  provide a chronotype override for the timing point.
