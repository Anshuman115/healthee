---
id: pai_activity_score
topic: Personalized Activity Intelligence (PAI) — composite weekly activity score with mortality validation
evidence_grade: 3
applies_to_metrics: [pai_today, pai_total, minutes_low_zone, minutes_moderate_zone, minutes_high_zone]
applies_to_interventions: [aerobic_activity, exercise_minutes]
tags: [activity, mortality, cardiometabolic, hr-zones, hunt3]
last_reviewed: 2026-05-13
---

## Finding

PAI is a single composite weekly activity score derived from heart-rate-zone
minutes, individualized to the user's age + resting HR + max HR. Unlike
proprietary fitness scores, PAI **has direct mortality validation** in a
large cohort (HUNT3 study, n ≈ 40,000 Norwegian adults, ~26-year follow-up).

The headline finding: maintaining **PAI ≥ 100 per rolling 7 days** is
associated with:
- **~17% lower all-cause mortality** vs PAI ≈ 0
- **~25% lower cardiovascular mortality** vs PAI ≈ 0
- **~5 years longer life expectancy** (women) / ~6 years (men)
- Effect persists after adjusting for total activity time — i.e. PAI captures
  intensity-weighted activity information that simple step count does not

## What PAI is

A 0–N continuous score updated daily based on the previous 7 days of
HR-zone minutes:

> PAI accumulates faster when you spend time in higher HR zones (>~75% max HR)
> and decays as the trailing 7-day window slides forward.

Huami's exact formula is proprietary but the core methodology is published in
Nes 2017. Both the strap (Helio Strap) and Mi Band lines compute it
on-device using your age + max HR estimate.

## Validation

- **Nes BM, Gutvik CR, Lavie CJ, Nauman J, Wisløff U.** *Personalized
  Activity Intelligence (PAI) for Prevention of Cardiovascular Disease and
  Promotion of Physical Activity.* Am J Med 130(3):328-336 (2017).
  https://pubmed.ncbi.nlm.nih.gov/27884383/
- **Kieffer SK, Zisko N, Coombes JS, Nauman J, Wisløff U.** *Personal
  Activity Intelligence and Mortality — Data from the Aerobics Center
  Longitudinal Study.* Prog Cardiovasc Dis 64:121-126 (2021). Replicates the
  HUNT3 finding in a US cohort.
  https://www.sciencedirect.com/science/article/pii/S0033062021000293
- **Nauman J et al.** *Prediction of Cardiovascular Mortality by Estimated
  Cardiorespiratory Fitness Independent of Traditional Risk Factors: The
  HUNT Study.* Mayo Clin Proc 92(2):218-227 (2017).

## How we use it

- Pull PAI_TODAY (today's accumulated PAI), PAI_TOTAL (7-day rolling), and
  per-zone minutes (low / moderate / high) from `HUAMI_PAI_SAMPLE` in the
  Gadgetbridge .db.
- Surface PAI_TOTAL as a card on the dashboard with cutoff 100 (Nes 2017
  threshold for the mortality benefit).
- Feed `pai_today`, `pai_total`, `minutes_moderate_zone`,
  `minutes_high_zone` into the correlation engine — they should associate
  positively with HRV, RHR improvement, and overall recovery markers.

## Caveats

- PAI depends on the user's max HR estimate. The strap uses the 220 − age
  formula by default, which under-estimates max HR by 5–10 bpm in many
  individuals (Tanaka 2001). If your real max HR is higher, PAI accumulates
  slower than it should.
- HUNT3 was a Norwegian-ancestry cohort. Generalizability to other
  populations is supported by the ACLS replication (Kieffer 2021) but the
  effect size may differ.
- 100/week is a population-level threshold, not a clinical one. Higher PAI
  is associated with further benefit up to ~150–200 in the studies, then
  plateaus.
