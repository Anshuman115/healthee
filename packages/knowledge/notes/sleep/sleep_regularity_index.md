---
id: sleep_regularity_index
name: "Sleep Regularity Index (SRI)"
topic: Sleep Regularity Index (SRI) — single-number sleep metric with mortality validation
category: sleep
grade: Established
evidence_grade: 3
summary: "SRI (0–100; 0=random, 100=identical day-to-day sleep/wake) is the most rigorously validated single-number wearable sleep metric — lower regularity predicts higher all-cause mortality and cardiometabolic risk, often more strongly than duration; the actionable target is keeping sleep/wake within a ~1-hour band day to day."
aliases: ["SRI", "sleep regularity index", "sleep regularity", "regularity score", "Phillips SRI", "sleep-wake consistency", "how regular is my sleep", "sleep regularity metric"]
applies_to_metrics: ["sleep_regularity_index"]
applies_to_interventions: ["sleep_consistency"]
population: general
last_reviewed: 2026-07-15
related: ["sleep_consistency", "sleep_timing_chronotype", "sleep_health_score_multidim", "no_validated_sleep_score", "sleep_duration_mortality", "recovery_readiness"]
tags: [sleep, regularity, mortality, cardiometabolic, sri]
---

# Sleep Regularity Index (SRI)

## Summary

The Sleep Regularity Index (SRI) is the most rigorously validated single-number
sleep metric in the literature for wearable-derived data. Lower regularity (higher
day-to-day variability in sleep-wake timing) is associated with higher all-cause
mortality, cardiometabolic risk, and worse glycemic control — independent of and
frequently stronger than total sleep duration as a predictor. It requires only
timestamped sleep/wake state, so every wearable that classifies sleep can compute
it. The single most useful coaching output is not the score but its behavioural
target: **keep sleep and wake times inside about a 1-hour window, weekends
included.**

## What it is

A **0–100 score** (0 = random, 100 = identical sleep-wake pattern across days)
computed from time-stamped sleep/wake state over a multi-day window:

> SRI = -100 + (200 / (M × (N - 1))) × Σ δ(s_{i,j}, s_{i,j+1})

where M = epochs per day (1440 for 1-min epochs, 2880 for 30-s), N = number of
consecutive days, s_{i,j} = sleep/wake state at epoch i on day j, and δ = 1 if
states match across consecutive days at the same epoch, else 0. Equivalently:
compare every epoch with the epoch exactly 24 h later in a flat chronological
binary array; SRI = -100 + 200 × P(match). A match counts when BOTH days are
asleep OR both are awake at that clock-minute.

Requires only timestamped sleep/wake — every wearable that classifies sleep can
compute it. Open implementations exist (GGIR R package).

**Two ways to compute it.** (1) *Global* (original Phillips) — one SRI over the
whole window. (2) *Per-day-pair* (sleepreg / GGIR) — one SRI per consecutive 2-day
window, then averaged; this is the variant the UK Biobank mortality studies used.
The two "give very similar results when data is clean." **We use the global
method.**

**The actionable target.** In Windred 2024, the top-20% (most regular) sleepers
fell asleep and woke within roughly a **1-hour band** day to day; the bottom 20%
varied across roughly a **3-hour band**. So "improve your SRI" has a concrete
behavioural target: keep sleep and wake times inside about a 1-hour window,
weekends included. This is the line the coach should give, not the abstract score.

## Physiology / mechanism

SRI captures **circadian stability**: a high score means the sleep-wake state at
any clock-minute is reproduced 24 h later, i.e. a well-entrained, stable clock. Day-
to-day variability in timing chronically misaligns the central circadian clock from
peripheral clocks governing metabolism, glucose handling, and cardiovascular
rhythm — the same misalignment physiology behind social jetlag and shift-work risk
(see `sleep_consistency`, `sleep_timing_chronotype`). SRI is the reason regularity
carries information *distinct from* duration and quality: it measures consistency,
not amount.

## The evidence

- **[Established]** **Phillips et al. 2017** (Sci Rep 7:3216). Original method
  paper. Defined the index, demonstrated it captures distinct information from
  duration and quality.
- **[Probable]** **Lunsford-Avery et al. 2018** (Sci Rep 8:14158). n = 1978, MESA
  cohort. Lower SRI associated with worse cardiometabolic risk profile (BMI, blood
  pressure, fasting glucose, HDL) — independent of mean sleep duration.
- **[Established]** **Windred et al. 2024** (Sleep 47(1):zsad253). n = 60,977, UK
  Biobank, median SRI = 81.0 [73.8–86.3], 6.3 y follow-up. **Most-regular vs
  least-regular quintile, fully adjusted (minimally adjusted in parens):** all-cause
  mortality **HR 0.70 [0.59–0.83]** (0.52), cancer **0.76 [0.61–0.94]** (0.61),
  cardiometabolic **0.62 [0.42–0.91]** (0.43); risk falls monotonically as
  regularity rises. Adding sleep *duration* to an SRI model did **not** improve fit
  (likelihood-ratio χ²(4) = 5.94, p = 0.20) — regularity was the stronger
  predictor. (Caveats: observational; single week of data; older, mostly-white
  cohort; two senior authors co-founded a circadian-health company.)
  *[figures primary-source verified 2026-06-09 vs the published article]*
- **[Established]** **Cribb et al. 2023** (eLife 12:RP88359, PMID 37995126).
  Replicates the mortality finding in UK Biobank (n = 88,975) with different
  exclusions/adjustments. Verbatim: *"Hazard ratios, relative to the median SRI, were
  1.53 (95% CI: 1.41, 1.66) for participants with SRI at the 5th percentile (SRI = 41)
  and 0.90 (95% CI: 0.81, 1.00) for those with SRI at the 95th percentile (SRI = 75)"*;
  *"the median SRI was 60 (SD, 10)"*. These are the two anchors
  [[biological_age_estimate]]'s regularity term interpolates between.
  *[citation corrected 2026-08-01 — this note previously attributed this paper to
  "Zheng et al." with n ≈ 72,000; there is no Zheng SRI paper in eLife. The n and title
  belonged to Chaput 2025 below, the journal/year/URL to Cribb.]*
- **[Probable]** **Chaput et al. 2025** (J Epidemiol Community Health 79(4):257–264,
  PMID 39603689). Device-based, 72,269 UK Biobank adults, 8 y follow-up: *"Irregular
  (HR 1.26, 95% CI 1.16 to 1.37) and moderately irregular sleepers (HR 1.08, 95% CI
  1.01 to 1.70) were at higher risk of MACE compared with regular sleepers"*, with
  irregular defined as SRI < 71.6 and regular as SRI > 87.3.

## How we compute it

- `_compute_sri` (`derive/sleep_score.py`, ex-v2 `derive.py`) computes the
  **global** SRI on a **7-day rolling window**, with **1-min epochs (M = 1440)**,
  reading `sleep_session.stages` directly (asleep = any non-awake stage). Verified:
  it reproduces the canonical **66.67** on the standard worked example (7 h sleep
  drifting 2 h between two days) and 100.0 for a perfectly regular sleeper. Written
  to `derived_daily` as `sleep_regularity_index`; also gates the Regularity
  dimension of `sleep_health_score_4dim` (SRI ≥ 70 → 1 point).
- Surface on the Sleep page as a single number with the **behavioural target**, not
  just the score: "SRI 78 — to lift it, keep sleep/wake within a ~1 h band."
- Flag a drop > 10 points vs the user's 30-day baseline as an anomaly (high
  regularity is protective; sudden drops suggest a disrupted schedule).

### Deliberate deviation: we compute NIGHT SLEEP ONLY (`kind='main'`)

The textbook SRI includes **all** sleep — naps too (it is explicitly meant to
capture irregularity from fragmented sleep and napping). **We exclude naps on
purpose**, for two reasons specific to our setup:

1. **Data completeness.** Canonical SRI assumes a complete, continuous 24-h
   sleep/wake state. Our strap only records naps **≥ ~20 min** (shorter naps and
   off-wrist gaps are missed). Feeding partial nap data in would count a missed nap
   as "awake" → false mismatches → *more* error, not more honesty. Night sleep we
   capture reliably and completely, so the night-only score is the trustworthy one.
2. **Actionability + dominance.** Night timing is the circadian anchor and the
   lever the user can actually move (naps are opportunistic). And night sleep is
   ~7–8 h of the 24-h state vs a nap's <1 h, so it dominates the score anyway — the
   canonical thresholds (median 81, the ~1 h-window target, the mortality
   quintiles) remain reasonable guidance, with this caveat.

So **our SRI ≠ literal textbook SRI**: read it as *night-sleep* regularity. This is
a justified, documented exception (cf. `feedback_canonical_metric_definitions`). If
strap nap coverage ever becomes complete, revisit including naps to match the
canonical definition. SRI is computed from `kind='main'` sessions only; naps
(`kind='nap'`) are tracked separately and never enter the night-sleep aggregates —
see `reference_nap_byte_format`.

## How the coach uses it

- Give the **behavioural target** ("keep sleep/wake within ~1 h day to day,
  weekends included"), not the abstract number.
- Treat SRI as a **chronic** signal; a >10-point drop vs the 30-day baseline is an
  anomaly worth surfacing (disrupted schedule), not a daily alarm.
- Read it as *night-sleep* regularity (the documented night-only deviation).
- Use it to anchor sleep-timing coaching (`sleep_timing_chronotype`,
  `sleep_consistency`) and as one input the recovery discussion can reference.

## Safety bounds

No physiological guardrail. SRI is a chronic-pattern circadian metric, never an
acute clinical signal; do not medicalise a single low week.

## Honesty & uncertainty

- All validation is **observational**; Windred 2024 uses a single week of data in
  an older, mostly-white cohort, and two senior authors co-founded a
  circadian-health company (declared COI).
- Our SRI is **night-only** and therefore not the literal textbook SRI — read as
  night-sleep regularity; nap coverage is incomplete on the strap.
- **SRI values are not comparable across studies, so borrowed thresholds are
  approximate.** Windred 2024 and Cribb 2023 both analyse UK Biobank accelerometry and
  report medians of **81.0** and **60** respectively — the score depends on the
  sleep-detection pipeline (Windred used `sleepreg`, which *"uses sustained inactivity
  data to account for naps, fragmented sleep, and large periods of wake during sleep"*;
  ours is night-only). Every cutoff we import from this literature — `SRI_GOOD = 70`,
  and [[biological_age_estimate]]'s SRI 41/75 hazard anchors — therefore lands on our
  distribution at an **unmeasured** offset. We have never measured where our own SRI
  distribution sits; until we do, treat SRI comparisons across *people* and against
  published cutoffs more loosely than SRI changes *within* one person.
- SRI requires ≥7 days; with fewer consecutive-day pairs its variance is too high.
- **What NOT to do:**
  - Do NOT combine SRI with a "sleep score" formula. The literature explicitly
    positions SRI as its own dimension — it captures consistency, not quality or
    duration. Combining loses interpretability.
  - Do NOT compute SRI from < 7 days of data; the formula's variance is too high
    with fewer pairs of consecutive days.

## Bottom line

**Act on confidently:** SRI is the best-validated single-number wearable sleep
metric; higher regularity predicts lower mortality and cardiometabolic risk,
independent of and often stronger than duration (Windred 2024). Coach the ~1-hour-
band behavioural target.

**Hold loosely:** exact HRs (observational, single-week, COI); the night-only
deviation vs the canonical all-sleep definition; SRI computed on <7 days.

## Coach Directives

1. Report SRI with its behavioural target (sleep/wake within ~1 h band, weekends
   included), not as a bare score. *(confidence: high)*
2. Treat SRI as a chronic signal; flag a >10-point drop vs the 30-day baseline as
   a schedule-disruption anomaly, not a daily concern. *(confidence: high)*
3. Never fold SRI into a composite "sleep score"; keep it as its own dimension.
   *(confidence: high)*
4. Do not compute or report SRI from <7 days of data. *(confidence: high)*
5. State it is night-sleep regularity (naps excluded by design). *(confidence: high)*

## References

- Phillips AJK, Clerx WM, O'Brien CS, et al. *Irregular sleep/wake patterns are
  associated with poorer academic performance and delayed circadian and sleep/wake
  timing.* Sci Rep 7, 3216 (2017).
  https://www.nature.com/articles/s41598-017-03171-4
- Lunsford-Avery JR, Engelhard MM, Navar AM, Kollins SH. *Validation of the Sleep
  Regularity Index in Older Adults and Associations With Cardiometabolic Risk.* Sci
  Rep 8, 14158 (2018). https://www.nature.com/articles/s41598-018-32402-5
- Windred DP, Burns AC, Lane JM, Saxena R, Rutter MK, Cain SW, Phillips AJK. *Sleep
  regularity is a stronger predictor of mortality risk than sleep duration: A
  prospective cohort study.* Sleep 47(1), zsad253 (2024).
  https://academic.oup.com/sleep/article/47/1/zsad253/7280269
- Cribb L, Sha R, Yiallourou S, Grima NA, Cavuoto M, Baril A-A, Pase MP. *Sleep
  regularity and mortality: a prospective analysis in the UK Biobank.* eLife 12,
  RP88359 (2023). DOI 10.7554/eLife.88359. PMID 37995126.
  https://elifesciences.org/articles/88359
- Chaput J-P, Biswas RK, Ahmadi M, Cistulli PA, Rajaratnam SMW, Bian W, St-Onge M-P,
  Stamatakis E. *Sleep regularity and major adverse cardiovascular events: a
  device-based prospective study in 72 269 UK adults.* J Epidemiol Community Health
  79(4), 257–264 (2025). DOI 10.1136/jech-2024-222795. PMID 39603689.

## Healthee implementation & honesty policy

- **Derived field: `sleep_regularity_index`** (0–100) in `derived_daily`.
  Provenance: `derive/sleep_score.py::_compute_sri`, ported verbatim from legacy v2
  (science code — known-value tested against the canonical 66.67 example and 100.0
  for a perfect sleeper). Constants: `SRI_DAYS = 7` (minimum/rolling window),
  1-min epochs (M = 1440), `SRI_GOOD = 70.0` (gates the 4-dim Regularity point, and is
  the challenge system's evidence target for `sri`). **`SRI_GOOD` is DERIVED, not
  cited** *(corrected 2026-08-01)*: Windred 2024 states no threshold of 70 — its
  least-regular quintile is **SRI < 71.6** and 70 is that boundary rounded down, so a
  night at SRI 70–71.5 scores the point although Windred's cohort would put it in the
  highest-mortality quintile. Rationale and the two independent cohorts that also cut
  near 71 are in [[sleep_score_implementation_plan]] §Dimension 4; the earlier
  justification ("the cutoff between Q4 and Q3 ≈ 70") was false — 70 is below that
  cohort's 25th percentile of 73.8.
- **Method choice:** we use the **global** Phillips SRI (one score over the 7-day
  window), not the per-day-pair GGIR average — documented; the two agree on clean
  data.
- **Night-only deviation (documented, canonical-definition exception):** computed
  from `kind='main'` sessions only (asleep = any non-awake stage), excluding naps,
  because strap nap capture is incomplete (≥~20 min only). Read as *night-sleep*
  regularity; revisit if nap coverage becomes complete.
- **Honesty policy:** always paired with the ~1-hour-band behavioural target;
  surfaced as a chronic signal; never combined into a composite sleep score
  (`no_validated_sleep_score`); never computed on <7 days.
- **Directive 4's REPORT half is enforced too, not just its compute half.** "Do not
  compute **or report** SRI from <7 days" was half-enforced: `_compute_sri` writes no
  row on a short grid, but every consumer then read "the newest
  `sleep_regularity_index` row" and presented it as the owner's *current* regularity.
  A 90-day-old row is a perfectly valid SRI **of a week 90 days ago**, so the compute
  gate cannot catch that — and an SRI has no visible age. Since 2026-07-31 the SRI is
  reported only when its row is the owner's own **today**:
  `derive/sleep_score.py::sri_unavailable_reason` (bound to the one shared freshness
  rule in `derive/freshness.py`) is what every consumer asks, and
  `sri_withhold_reason_for_day` recomputes the <7-night gate from the sleep sessions
  still in the database — no new schema, and it covers rows written before this
  existed. On `/api/sleep/consistency` (and the coach's `sleep_consistency` tool) the
  `sri` field is then `null`, paired with `sri_as_of_date`, and the value survives only
  inside `sri_withheld` with its own date and age; in
  [[biological_age_estimate]] the regularity term is required, so a stale SRI withholds
  the whole composite rather than silently asserting a median-regularity sleeper. The
  two reasons stay distinct because they ask different things of the owner:
  `sri_window_under_7_nights` ("wear the strap for the rest of the week") vs
  `not_derived_yet` ("sync").
