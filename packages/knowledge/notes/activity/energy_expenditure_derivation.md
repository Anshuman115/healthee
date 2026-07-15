---
id: energy_expenditure_derivation
title: Deriving daily energy expenditure (calories) — free-living, anchored
evidence_grade: 2
applies_to_metrics: [total_calories, active_calories, basal_calories]
citations:
  - "Mifflin MD, St Jeor ST, et al. A new predictive equation for resting energy expenditure. Am J Clin Nutr. 1990;51(2):241-247."
  - "Brage S, et al. Estimation of Free-Living Energy Expenditure by Heart Rate and Movement Sensing: A Doubly-Labelled Water Study. PLOS One. 2015;10(9):e0137206."
  - "Brage S, et al. Branched equation modeling of simultaneous accelerometry and heart rate monitoring improves estimate of PAEE. J Appl Physiol. 2004;96(1):343-351."
  - "Swain DP, Leutholtz BC. Heart rate reserve is equivalent to %VO2 reserve, not %VO2max. Med Sci Sports Exerc. 1997;29(3):410-414."
  - "Ainsworth BE, et al. 2011 Compendium of Physical Activities. Med Sci Sports Exerc. 2011;43(8):1575-1581."
  - "Frankenfield D, et al. Comparison of predictive equations for RMR. J Am Diet Assoc. 2005;105(5):775-789."
---

# Goal

The strap reports no daily calories (per-minute record is only
kind/intensity/steps/HR). Derive TEE = RMR + PAEE + workouts, free-living.

# Why NOT raw Keytel HR-EE (verified failure, 2026-06-04)

We first used Keytel 2005 (a fixed HR→EE regression). On a real free-living day
it gave **total 5308 / active 3599 kcal** — 2–3× too high, even with a flex-HR
gate. Cause: Keytel is a **population equation with no individual anchoring**, so
every minute of mildly-elevated daily HR (standing, stress, heat) is scored as
exercise. It was validated on *graded exercise*, not free-living. Rejected.

# What the DLW literature says (Brage 2015)

Validated against doubly-labelled water (the gold standard), **TEE bias < 5%**
for movement, HR, and combined methods; correlations: movement-alone r = 0.71,
HR-alone r = 0.66–0.76, **combined movement+HR r = 0.76–0.83** — *"improved
precision if combined and if HR is individually calibrated"* (Brage 2004's
branched model / Actiheart). Conclusion: HR is fine **if anchored to the
individual**; combine with movement; cover exercise with measured values.

# Method — RMR + branched[ anchored-HR , movement ] + workouts

## 1. RMR — Mifflin–St Jeor (1990) ★★★
```
RMR (kcal/day) = 10·kg + 6.25·height_cm − 5·age + (5 male | −161 female)
RMR_per_min = RMR / 1440
```

## 2. PAEE — MET-by-state, anchored to BMR (NOT heart rate) ★★
We also tested the anchored %HRR→%VO₂R method (Swain 1997) — it STILL overcounts
on real data (4268 kcal): a real sedentary day had **1075 minutes at HR>70 but
only 118 with steps**, so ~950 minutes are *awake passive HR elevation*
(sitting/stress/heat), not activity. HR cannot separate sitting-at-82 from
walking-at-82 without **continuous accelerometry**, which the strap does not
expose (we get *steps*, not raw accel counts). Brage's combined model needs that
accelerometry; with only steps, HR adds overcount, not signal. So **HR is not
used for free-living EE** (it IS used implicitly inside the device's measured
workout calories).

Instead, assign each minute a MET by **state**, anchored to the person's BMR
(1 MET ≡ BMR/min, so the day sums to BMR×PAL):
```
walking/running  → ACSM:  VO₂ = 0.1·speed+3.5 (or 0.2·speed+3.5 ≥134 m/min); MET = VO₂/3.5
asleep           → 0.95 MET            (sleep_session windows)
awake, no steps  → 1.4 MET  (light NEAT; Compendium sitting 1.3 / standing 1.8) ← tunable
workout window   → excluded; use device-measured calories
EE_minute = MET · (BMR/1440)
total_calories = Σ EE_minute + Σ workout.calories ; active = total − BMR
```
Verified on the real day: total 2470, PAL 1.40 — sane for sedentary-light.

## 3. Workouts — device-measured ★★★
For workout windows use the device's measured `calories` (fetch 0x05) — real,
not derived — in place of the per-minute estimate.

```
active_calories = Σ_minute active_kcal_minute (non-workout) + Σ workout.calories
total_calories  = RMR + active_calories
basal_calories  = RMR
```

# Accuracy & honest caveats
- Anchored to the user's RMR, rhr, VO₂max → no Keytel-style overcount.
- Without **individual** HR–VO₂ calibration (a step/treadmill test), expect TEE
  bias < 5% on average but individual error ≈ ±15–20% (Brage). Label "estimate".
- HR elevation from stress/heat with no movement can still over-attribute a
  little; the movement branch + %HRR anchoring bound it. Raw wrist accelerometer
  counts (not exposed by the strap) would let us implement the full Brage
  branched model — a future upgrade if we surface them.
- Needs profile (height/sex/dob) + weight, entered in the app. Never fabricate.

# Where it runs
Backend v2 derived metric (`healthee/v2/derive.py`), single-source. Depends on
`rhr_daily` + `vo2max_estimate` being derived first (ordering in the derive
pass). The app renders the value; it computes nothing.

Related: non_exercise_vo2max.md (Jurca VO₂max), distance_from_steps.md,
research/protocol/v2_backend_rebuild.md.
