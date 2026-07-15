---
id: resting_hr_health_marker
topic: Resting heart rate is an independent predictor of cardiovascular and all-cause mortality
evidence_grade: 3
applies_to_metrics: [hr, rhr_daily]
applies_to_interventions: [exercise, meditation]
tags: [rhr, autonomic, mortality, cv_risk]
last_reviewed: 2026-05-11
---

## Finding
Higher **resting heart rate (RHR)** is associated with higher all-cause and
cardiovascular mortality, independent of traditional risk factors (BP,
cholesterol, BMI, smoking, diabetes). The relationship is approximately
log-linear: each ~10 bpm increase in RHR is associated with a meaningful
increase in mortality risk. Lower RHR (within physiologically normal range)
generally reflects cardiorespiratory fitness.

The association holds across diverse populations and is one of the most
replicated findings in cardiovascular epidemiology.

## Effect size
- **Per 10 bpm higher RHR**, all-cause mortality risk increases ~9% (95% CI 6–12%) and CV mortality ~8% (95% CI 4–12%) — pooled meta-analysis estimate.
- Subjects with RHR >80 bpm have ~45% higher all-cause mortality vs RHR <60 bpm in some large cohorts.

## Evidence strength
- Aune D, Sen A, ó'Hartaigh B, et al. **"Resting heart rate and the risk of cardiovascular disease, total cancer, and all-cause mortality — A systematic review and dose–response meta-analysis of prospective studies."** *Nutrition, Metabolism and Cardiovascular Diseases* 2017;27(6):504–517. Meta-analysis of 87 cohorts, n ≈ 1.2 million.
- Cooney MT, Vartiainen E, Laatikainen T, et al. **"Elevated resting heart rate is an independent risk factor for cardiovascular disease in healthy men and women."** *American Heart Journal* 2010;159(4):612–619.e3. Prospective cohort.
- Zhang D, Wang W, Li F. **"Association between resting heart rate and coronary artery disease, stroke, sudden death and noncardiovascular diseases: a meta-analysis."** *CMAJ* 2016;188(15):E384–E392.

## Caveats
- Observational; reverse causation possible (underlying disease elevates RHR).
- Within an individual, RHR varies day-to-day due to sleep, stress, hydration, caffeine, alcohol, illness — single-day values carry noise.
- Population-level effect sizes are not a personal prognosis; n=1 risk projection is not appropriate.
- **Beta-blockers and similar medications** suppress RHR independently of fitness.
- An athletic individual can have RHR in the 40s; that is normal, not concerning.

## Operational use
- Compute the user's rolling RHR baseline (median + IQR over 30–90 days).
- Surface **sustained shifts** (multi-week trends), not single days.
- A 10 bpm sustained increase relative to personal baseline warrants attention (consider sleep, alcohol, illness, training load); cite this note.
- Never present RHR as a "death risk" number to the user; frame as autonomic / fitness marker with context.
