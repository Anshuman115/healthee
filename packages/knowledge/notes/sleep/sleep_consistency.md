---
id: sleep_consistency
topic: Day-to-day sleep timing variability is independently linked to cardiometabolic risk
evidence_grade: 3
applies_to_metrics: [asleep, sleep_score, sleep_light_min, sleep_deep_min]
applies_to_interventions: []
tags: [sleep, circadian, metabolism, cv_risk]
last_reviewed: 2026-05-11
---

## Finding
Higher day-to-day variability in bedtime and sleep duration (often called
"sleep regularity") is associated with worse cardiometabolic health
**independently** of mean sleep duration. Larger variability predicts higher
risk of obesity, metabolic syndrome, hypertension, and all-cause mortality in
several large cohorts.

## Effect size
- Sleep Regularity Index (SRI) studies in UK Biobank (Windred 2024, *Sleep*):
  the lowest-quintile-regularity group has hazard ratio for all-cause mortality
  ≈ 1.46 (95% CI ~1.39–1.54) vs the highest-quintile, independent of mean
  duration.
- Effect size for cardiometabolic outcomes (BP, fasting glucose, BMI) in
  bedtime-variability studies: SDs of bedtime ≥1 hour vs <30 min carry small-
  to-moderate elevations in risk (typically RR 1.1–1.3).

## Evidence strength
- Bei B, Wiley JF, Trinder J, Manber R. **"Beyond the mean: A systematic review on the correlates of daily intraindividual variability of sleep/wake patterns."** *Sleep Medicine Reviews* 2016;28:108–124. Systematic review across 53 studies.
- Windred DP et al. **"Sleep regularity is a stronger predictor of mortality than sleep duration."** *Sleep* 2024;47(1):zsad253. UK Biobank, n ≈ 60,977.
- Huang T, Mariani S, Redline S. **"Sleep irregularity and risk of cardiovascular events."** *J Am Coll Cardiol* 2020;75(9):991–999. MESA cohort, n ≈ 1,992.

## Caveats
- All major findings are observational. Reverse causation possible (illness → irregular sleep).
- "Regularity" is defined differently across studies (SD of bedtime, SRI, etc.); effect sizes don't perfectly compare.
- Within-individual short-term variation (e.g., one weekend) is unlikely meaningful — the studies look at multi-week patterns.

## Operational use
- Compute personal SD of bedtime over rolling 14-day window. Flag when it
  exceeds the user's historical baseline.
- Do **not** present regularity as an acute concern; it is a chronic-pattern
  signal worth surfacing weekly, not daily.
- Cite this note when explaining why bedtime consistency matters.
