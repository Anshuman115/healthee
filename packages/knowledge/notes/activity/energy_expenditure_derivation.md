---
id: energy_expenditure_derivation
name: "Deriving daily energy expenditure (calories)"
topic: Deriving daily energy expenditure (calories) — free-living, anchored
category: activity
grade: Probable
evidence_grade: 2
summary: "Total energy expenditure is derived as RMR (Mifflin–St Jeor) + a MET-by-state activity model anchored to the person's BMR + device-measured workout calories — deliberately NOT raw Keytel or HR→EE, which overcount free-living days 2–3× because heart rate cannot separate passive HR elevation from movement without accelerometry the strap doesn't expose."
aliases: ["energy expenditure", "calories derivation", "TEE", "total energy expenditure", "active calories", "MET-by-state", "energy_expenditure_derivation"]
tags: ["energy expenditure", "calories derivation", "TEE", "total energy expenditure", "active calories", "MET-by-state", "energy_expenditure_derivation"]
applies_to_metrics: ["total_calories", "active_calories", "basal_calories"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
related: ["non_exercise_vo2max", "distance_from_steps", "resting_hr_health_marker"]
---

# Deriving daily energy expenditure (calories)

## Summary

The strap reports no daily calories (the per-minute record is only kind / intensity /
steps / HR). Derive **TEE = RMR + PAEE + workouts**, free-living. The load-bearing design
choice: use a **MET-by-state model anchored to the person's BMR**, and **not** a raw
HR→energy regression (Keytel), which overcounts a real free-living day 2–3× because heart
rate cannot separate passive HR elevation (sitting, stress, heat) from movement without
accelerometry the strap does not expose.

## What it is

Three derived daily metrics: `basal_calories` (RMR), `active_calories` (activity +
workouts above basal), and `total_calories` (RMR + active). All are estimates anchored to
the user's own profile and resting physiology.

## Physiology / mechanism

Total energy expenditure has three parts: resting metabolic rate (RMR, the largest),
physical-activity energy expenditure (PAEE), and the thermic effect of food (small,
folded into the model's constants). PAEE is proportional to the metabolic rate (METs) of
what the body is doing each minute. Anchoring each minute's MET to the person's own BMR
(1 MET ≡ BMR/min) makes the day sum to BMR × physical-activity-level (PAL), which is the
physiologically correct free-living structure — unlike a population HR→EE regression that
has no individual anchor.

## The evidence

- **[Established]** **RMR from Mifflin–St Jeor (1990)** is the best-validated resting
  prediction equation [Mifflin et al. 1990; Frankenfield et al. 2005 comparison].
- **[Established]** Against doubly-labelled water (the gold standard), **TEE bias < 5%** for
  movement, HR, and combined methods; correlations movement-alone r = 0.71, HR-alone
  r = 0.66–0.76, **combined movement+HR r = 0.76–0.83** — *"improved precision if combined
  and if HR is individually calibrated"* [Brage et al. 2015; branched model Brage et al.
  2004]. HR is fine **only if anchored to the individual** and combined with movement.
- **[Contested → rejected] Raw Keytel HR→EE overcounts free-living 2–3×** (verified failure,
  2026-06-04): on a real day it gave **total 5308 / active 3599 kcal**, even with a flex-HR
  gate — because Keytel is a population equation with no individual anchoring, validated on
  *graded exercise*, so every minute of mildly-elevated daily HR is scored as exercise.
  Rejected.
- **[Contested → rejected] Anchored %HRR→%VO₂R (Swain 1997) still overcounts** (4268 kcal):
  a real sedentary day had **1,075 minutes at HR > 70 but only 118 with steps** — ~950
  minutes of awake passive HR elevation. HR cannot separate sitting-at-82 from
  walking-at-82 **without continuous accelerometry**, which the strap does not expose (we
  get *steps*, not raw accel counts). So **HR is not used for free-living EE**.

## How we compute it

### 1. RMR — Mifflin–St Jeor (1990) ★★★
```
RMR (kcal/day) = 10·kg + 6.25·height_cm − 5·age + (5 male | −161 female)
RMR_per_min = RMR / 1440
```

### 2. PAEE — MET-by-state, anchored to BMR (NOT heart rate) ★★
We also tested the anchored %HRR→%VO₂R method (Swain 1997) — it STILL overcounts on real
data (4268 kcal): a real sedentary day had **1075 minutes at HR>70 but only 118 with
steps**, so ~950 minutes are *awake passive HR elevation* (sitting/stress/heat), not
activity. HR cannot separate sitting-at-82 from walking-at-82 without **continuous
accelerometry**, which the strap does not expose (we get *steps*, not raw accel counts).
Brage's combined model needs that accelerometry; with only steps, HR adds overcount, not
signal. So **HR is not used for free-living EE** (it IS used implicitly inside the device's
measured workout calories).

Instead, assign each minute a MET by **state**, anchored to the person's BMR (1 MET ≡
BMR/min, so the day sums to BMR×PAL):
```
walking/running  → ACSM:  VO₂ = 0.1·speed+3.5 (or 0.2·speed+3.5 ≥134 m/min); MET = VO₂/3.5
asleep           → 0.95 MET            (sleep_session windows)
awake, no steps  → 1.4 MET  (light NEAT; Compendium sitting 1.3 / standing 1.8) ← tunable
workout window   → excluded; use device-measured calories
EE_minute = MET · (BMR/1440)
total_calories = Σ EE_minute + Σ workout.calories ; active = total − BMR
```
Verified on the real day: total 2470, PAL 1.40 — sane for sedentary-light.

### 3. Workouts — device-measured ★★★
For workout windows use the device's measured `calories` (fetch 0x05) — real, not derived —
in place of the per-minute estimate.

```
active_calories = Σ_minute active_kcal_minute (non-workout) + Σ workout.calories
total_calories  = RMR + active_calories
basal_calories  = RMR
```

## How the coach uses it

- Present calories as an **anchored estimate** (RMR + activity + measured workouts), never a
  precise measurement.
- Use `active_calories` / `total_calories` for trend and context; don't over-read a single
  day.
- Never fabricate a value when profile/weight is missing — show insufficient data instead.

## Safety bounds

- Informational only; never used for clinical or weight-prescription decisions on its own.
- Requires profile (height/sex/DOB) + weight, entered in the app — **never fabricate** the
  inputs.

## Honesty & uncertainty

- Anchored to the user's RMR, RHR, VO₂max → **no Keytel-style overcount**.
- Without **individual** HR–VO₂ calibration (a step/treadmill test), expect TEE bias < 5%
  on average but **individual error ≈ ±15–20%** [Brage 2015]. Label "estimate".
- HR elevation from stress/heat with no movement can still over-attribute a little; the
  movement branch + %HRR anchoring bound it.
- Raw wrist accelerometer counts (not exposed by the strap) would let us implement the full
  Brage branched model — a future upgrade if we surface them.

## Bottom line

**Act on confidently:** RMR (Mifflin–St Jeor) + MET-by-state anchored to BMR + device
workout calories gives a sane, un-inflated free-living TEE estimate (verified 2470 kcal /
PAL 1.40 on a real sedentary-light day).

**Hold loosely:** the individual daily figure (±15–20%); anything derived from HR alone for
free-living minutes (rejected — overcounts).

## Coach Directives

1. Derive TEE as **RMR (Mifflin–St Jeor) + MET-by-state PAEE anchored to BMR + device
   workout calories**; **never** raw Keytel/HR→EE for free-living minutes. *(confidence:
   high)*
2. Use the device's **measured workout calories** for workout windows, not the per-minute
   estimate. *(high)*
3. Label calories an **estimate** (individual ±15–20%); never fabricate when
   profile/weight is missing. *(high)*

## References

- Mifflin MD, St Jeor ST, et al. *A new predictive equation for resting energy
  expenditure.* Am J Clin Nutr 1990;51(2):241–247.
- Brage S, et al. *Estimation of Free-Living Energy Expenditure by Heart Rate and Movement
  Sensing: A Doubly-Labelled Water Study.* PLOS One 2015;10(9):e0137206.
- Brage S, et al. *Branched equation modeling of simultaneous accelerometry and heart rate
  monitoring improves estimate of PAEE.* J Appl Physiol 2004;96(1):343–351.
- Swain DP, Leutholtz BC. *Heart rate reserve is equivalent to %VO2 reserve, not %VO2max.*
  Med Sci Sports Exerc 1997;29(3):410–414.
- Ainsworth BE, et al. *2011 Compendium of Physical Activities.* Med Sci Sports Exerc
  2011;43(8):1575–1581.
- Frankenfield D, et al. *Comparison of predictive equations for RMR.* J Am Diet Assoc
  2005;105(5):775–789.

## Healthee implementation & honesty policy

- **Metrics: `total_calories`, `active_calories`, `basal_calories`** — backend v2 derived
  metrics (`healthee/v2/derive.py`, single-source). The app renders the value; it computes
  nothing.
- **Ordering**: depends on `rhr_daily` + `vo2max_estimate` being derived first (they feed
  the anchoring); see [[non_exercise_vo2max]].
- **Honesty rules**: anchored MET-by-state, never Keytel/HR→EE for free-living (the
  documented rejected approaches above); label calories an estimate (±15–20% individual);
  never fabricate inputs. Related: [[distance_from_steps]].
