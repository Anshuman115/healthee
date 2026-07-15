---
id: sleep_regularity_index
topic: Sleep Regularity Index (SRI) — single-number sleep metric with mortality validation
evidence_grade: 3
applies_to_metrics: [asleep, sleep_regularity_index]
applies_to_interventions: [sleep_consistency]
tags: [sleep, regularity, mortality, cardiometabolic]
last_reviewed: 2026-06-09
---

## Finding

The Sleep Regularity Index (SRI) is the most rigorously validated single-number
sleep metric in the literature for wearable-derived data. Lower regularity
(higher day-to-day variability in sleep-wake timing) is associated with higher
all-cause mortality, cardiometabolic risk, and worse glycemic control —
independent of and frequently stronger than total sleep duration as a predictor.

## What SRI is

A 0–100 score (0 = random, 100 = identical sleep-wake pattern across days)
computed from time-stamped sleep/wake state over a multi-day window:

> SRI = -100 + (200 / (M × (N - 1))) × Σ δ(s_{i,j}, s_{i,j+1})

where M = epochs per day (1440 for 1-min epochs, 2880 for 30-s), N = number
of consecutive days, s_{i,j} = sleep/wake state at epoch i on day j, and
δ = 1 if states match across consecutive days at the same epoch, else 0.
Equivalently: compare every epoch with the epoch exactly 24 h later in a flat
chronological binary array; SRI = -100 + 200 × P(match). A match counts when
BOTH days are asleep OR both are awake at that clock-minute.

Requires only timestamped sleep/wake — every wearable that classifies sleep
can compute it. Open implementations exist (GGIR R package).

**Two ways to compute it.** (1) *Global* (original Phillips) — one SRI over the
whole window. (2) *Per-day-pair* (sleepreg / GGIR) — one SRI per consecutive
2-day window, then averaged; this is the variant the UK Biobank mortality
studies used. Your research notes the two "give very similar results when data
is clean." **We use the global method.**

**The actionable target.** In Windred 2024, the top-20% (most regular) sleepers
fell asleep and woke within roughly a **1-hour band** day to day; the bottom 20%
varied across roughly a **3-hour band**. So "improve your SRI" has a concrete
behavioural target: keep sleep and wake times inside about a 1-hour window,
weekends included. This is the line the coach should give, not the abstract score.

## Validation

- **Phillips et al. 2017** (Sci Rep 7:3216). Original method paper.
  Defined the index, demonstrated it captures distinct information from
  duration and quality.
- **Lunsford-Avery et al. 2018** (Sci Rep 8:14158). n = 1978, MESA cohort.
  Lower SRI associated with worse cardiometabolic risk profile (BMI, blood
  pressure, fasting glucose, HDL) — independent of mean sleep duration.
- **Windred et al. 2024** (Sleep 47(1):zsad253). n = 60,977, UK Biobank, median
  SRI = 81.0 [73.8–86.3], 6.3 y follow-up. **Most-regular vs least-regular
  quintile, fully adjusted (minimally adjusted in parens):** all-cause mortality
  **HR 0.70 [0.59–0.83]** (0.52), cancer **0.76 [0.61–0.94]** (0.61),
  cardiometabolic **0.62 [0.42–0.91]** (0.43); risk falls monotonically as
  regularity rises. Adding sleep *duration* to an SRI model did **not** improve
  fit (likelihood-ratio χ²(4) = 5.94, p = 0.20) — regularity was the stronger
  predictor. (Caveats: observational; single week of data; older, mostly-white
  cohort; two senior authors co-founded a circadian-health company.)
  *[figures primary-source verified 2026-06-09 vs the published article]*
- **Zheng et al. 2023** (eLife). Replicates the mortality finding in
  UK Biobank with somewhat different exclusions/adjustments.

## How we use it

- `_compute_sri` (v2 `derive.py`) computes the **global** SRI on a **7-day
  rolling window**, with **1-min epochs (M = 1440)**, reading
  `sleep_session.stages` directly (asleep = any non-awake stage). Verified: it
  reproduces the canonical **66.67** on the standard worked example (7 h sleep
  drifting 2 h between two days) and 100.0 for a perfectly regular sleeper.
- Surface on the Sleep page as a single number with the **behavioural target**,
  not just the score: "SRI 78 — to lift it, keep sleep/wake within a ~1 h band."
- Flag a drop > 10 points vs the user's 30-day baseline as an anomaly (high
  regularity is protective; sudden drops suggest a disrupted schedule).

### Deliberate deviation: we compute NIGHT SLEEP ONLY (`kind='main'`)

The textbook SRI includes **all** sleep — naps too (it is explicitly meant to
capture irregularity from fragmented sleep and napping). **We exclude naps on
purpose**, for two reasons specific to our setup:

1. **Data completeness.** Canonical SRI assumes a complete, continuous 24-h
   sleep/wake state. Our strap only records naps **≥ ~20 min** (shorter naps and
   off-wrist gaps are missed). Feeding partial nap data in would count a missed
   nap as "awake" → false mismatches → *more* error, not more honesty. Night
   sleep we capture reliably and completely, so the night-only score is the
   trustworthy one.
2. **Actionability + dominance.** Night timing is the circadian anchor and the
   lever the user can actually move (naps are opportunistic). And night sleep is
   ~7–8 h of the 24-h state vs a nap's <1 h, so it dominates the score anyway —
   the canonical thresholds (median 81, the ~1 h-window target, the mortality
   quintiles) remain reasonable guidance, with this caveat.

So **our SRI ≠ literal textbook SRI**: read it as *night-sleep* regularity. This
is a justified, documented exception (cf. [[feedback_canonical_metric_definitions]]).
If strap nap coverage ever becomes complete, revisit including naps to match the
canonical definition. SRI is computed from `kind='main'` sessions only; naps
(`kind='nap'`) are tracked separately and never enter the night-sleep
aggregates — see [[reference_nap_byte_format]].

## What NOT to do

- Do NOT combine SRI with a "sleep score" formula. The literature explicitly
  positions SRI as its own dimension — it captures consistency, not quality
  or duration. Combining loses interpretability.
- Do NOT compute SRI from < 7 days of data; the formula's variance is too
  high with fewer pairs of consecutive days.

## References

- Phillips AJK, Clerx WM, O'Brien CS, et al. *Irregular sleep/wake patterns
  are associated with poorer academic performance and delayed circadian and
  sleep/wake timing.* Sci Rep 7, 3216 (2017).
  https://www.nature.com/articles/s41598-017-03171-4
- Lunsford-Avery JR, Engelhard MM, Navar AM, Kollins SH. *Validation of the
  Sleep Regularity Index in Older Adults and Associations With
  Cardiometabolic Risk.* Sci Rep 8, 14158 (2018).
  https://www.nature.com/articles/s41598-018-32402-5
- Windred DP, Burns AC, Lane JM, Saxena R, Rutter MK, Cain SW, Phillips AJK.
  *Sleep regularity is a stronger predictor of mortality risk than sleep
  duration: A prospective cohort study.* Sleep 47(1), zsad253 (2024).
  https://academic.oup.com/sleep/article/47/1/zsad253/7280269
- Zheng Y et al. *Sleep regularity and major adverse cardiovascular events:
  A device-based prospective study in 72 000 UK adults.* eLife (2023).
  https://elifesciences.org/articles/88359
