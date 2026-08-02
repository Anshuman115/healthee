---
id: submaximal_vo2max
name: "Submaximal HR-vs-pace VO₂max estimate"
topic: Submaximal HR-during-activity VO2max estimation — the wearable method, vs the Jurca non-exercise baseline
category: activity
grade: Probable
summary: "The primary VO₂max estimator for active users: fit the HR↔workload line over steady-state sub-maximal workout segments and extrapolate to HRmax — the same method Garmin/Firstbeat and Polar use. More accurate than the Jurca non-exercise baseline for active users (independent MAPE 6.85%, CCC 0.70 for running), but real-but-modest and not directly validated for free-living unknown-grade walking."
aliases: ["submaximal vo2max", "hr-vs-pace vo2max", "firstbeat vo2max", "wearable vo2max estimate", "submaximal-extrapolation", "vo2max_submax", "submaximal_vo2max", "methodology"]
tags: ["submaximal vo2max", "hr-vs-pace vo2max", "firstbeat vo2max", "wearable vo2max estimate", "submaximal-extrapolation", "vo2max_submax", "submaximal_vo2max", "methodology"]
applies_to_metrics: ["vo2max_estimate", "vo2max_submax", "hr", "steps_per_minute", "rhr_daily", "max_hr"]
applies_to_interventions: []
population: general
last_reviewed: 2026-08-02
related: ["vo2max", "non_exercise_vo2max", "mvpa_minutes_mortality", "cadence_intensity", "maximum-heart-rate", "distance_from_steps", "cadence_derived_speed", "hr_reserve_vo2max"]
---

# Submaximal HR-vs-pace VO₂max estimate

## Summary

For a user with **workout HR + pace data** (which we have for recorded outdoor sessions:
per-minute HR, GPS-measured speed, DEM grade, measured RHR, Tanaka HRmax), the most accurate
non-lab method is **submaximal HR-vs-pace extrapolation** — the same approach commercial
wearables (Garmin/Firstbeat, Polar) use. It builds the linear HR↔workload relationship
from steady-state sub-maximal segments and extrapolates it out to HRmax. It is **more
accurate than the Jurca non-exercise baseline for active users** ([[non_exercise_vo2max]]),
but the advantage is real-but-modest and comes with honest caveats — it is NOT a
step-change, and for *walking* it is not directly validated. It needs a **measured** speed:
cadence cannot stand in for one ([[cadence_derived_speed]]).
In Healthee this is the **primary tier** of the `vo2max_estimate` metric (with the
non-exercise model as the fallback), and can be surfaced as a distinct `vo2max_submax`
signal.

*(All accuracy figures below are primary-source-verified against the cited papers,
adversarially checked. Where a figure is vendor/secondary it is flagged.)*

## What it is

The method estimates VO₂max from a normal outdoor workout, without any maximal effort: it
reads the (heart-rate, workload) points during steady sub-maximal running or brisk
walking, fits a straight line through them, and extends that line to the person's maximal
heart rate — the VO₂ at that intercept is the estimated VO₂max. It is an **estimate, not a
measurement**, but it uses *actual exertion data* rather than resting proxies, which is
why it out-performs the non-exercise model for people who train.

## Physiology / mechanism

Below the lactate threshold, oxygen uptake (VO₂, i.e. workload) and heart rate rise
**approximately linearly** together — every extra unit of work needs proportionally more
cardiac output, delivered as a higher heart rate. Extrapolating that sub-maximal line to
maximal heart rate estimates the workload the cardiovascular system could sustain at its
ceiling — VO₂max. The method's error sources all trace to where this linearity breaks or
where an input is estimated: unknown grade (workload mis-estimated), cardiac drift
(HR rises without more work), and an estimated rather than measured HRmax.

## Methods compared (for THIS data profile)

| Method | r / SEE vs measured VO2max | Fits our data? |
|---|---|---|
| **Submaximal HR-vs-pace extrapolation** (Firstbeat / wearable) ⭐ | indep. peer-reviewed **MAPE 6.85%, Lin's CCC 0.70** (Garmin fenix 6, Carrier 2023) | **Yes** — designed for free-living HR+pace |
| **Uth 2004 ratio** `15.3 × HRmax/HRrest` | **SEE 2.7** ml/kg/min w/ *measured* HRmax; **SEE 4.7 (~7.8%)** w/ age-predicted HRmax (what we use) | Yes, but weak — cross-check only |
| ACSM submax + Karvonen %HRR | r≈0.65, SEE 4.2–4.4 | **No** — needs known speed AND grade |
| Ebbeling single-stage walk | R²=0.86, SEE 4.85 | **No** — assumes a fixed 5% treadmill grade |
| *Jurca 2005 (fallback baseline)* | r≈0.78, **SEE≈5.6** | — (resting-HR only; no workout data used) |

> ⚠ Cross-study SEE comparisons are **NOT head-to-head** — each method was validated
> on a different population/protocol, so a lower SEE alone does not prove superiority
> in our free-living context. Jurca's 5.6 was a general population; Uth's 2.7 was
> well-trained young men.

## The evidence

- **[Probable]** **The submaximal HR-vs-pace method is independently validated for
  running**: the Garmin fenix 6 running the Firstbeat algorithm hit **MAPE 6.85%, Lin's
  CCC 0.70** vs lab CPET (n=21 athletes, structured *outdoor running*) [Carrier et al.
  2023]. CCC 0.70 is borderline-passing.
- **[Emerging / vendor]** The Firstbeat white paper (primary but **non-peer-reviewed**)
  reports "MAPE ~5%, error <3.5 mL/kg/min in most cases" on 2,690 freely-performed runs.
  The often-quoted **"correlation 0.95" is a relabel of 1−MAPE, NOT an independent Pearson
  r** — this inflated claim was adversarially **refuted (0–3); do not cite it**.
- **[Established] (mechanic)** The sub-maximal HR↔VO₂ linear-extrapolation mechanic is
  demonstrated in controlled work [Lounana et al., PMC10747607] and is the basis of the
  wearable algorithms.
- **[Contested]** **Uth's HRmax/HRrest ratio is a trap as a primary estimator.** Its low
  SEE% is deceptive: independent validation in middle-aged/older adults (n=20, age 62)
  found **poor agreement (Lin's rc ≤ 0.40)** and **systematic underestimation of fitter
  people** — weak ranking ability [Eur J Appl Physiol 2021]. Use only as a sanity bound.
- **[Contested]** **%HRR = %VO₂R** (the Karvonen equivalence) is contested, not exact —
  treat any HR-reserve→VO₂ mapping as approximate.

## How we compute it

**Mechanic** (Lounana/PMC10747607, the basis of the wearable algorithms): over
steady-state sub-maximal segments of a workout, fit a per-session linear regression of
**VO₂ (from the ACSM level speed→VO₂ equation) against HR**, then extrapolate that line to
**Tanaka HRmax** → VO₂max.

- ACSM **level** VO₂ (mL/kg/min) ≈ `3.5 + 0.1·speed_m_min` walking, `3.5 + 0.2·speed_m_min`
  running. The gradient effect is applied as the **Minetti 2002 energy-cost ratio**, not
  the plain ACSM linear grade term — the linear term goes negative on descents, the
  Minetti polynomial is U-shaped and handles downhill correctly.
- **Speed is measured, never inferred from cadence.** It comes from the GPS track
  (per-fix distance ÷ time, smoothed), and grade from an SRTM terrain DEM.
  `speed = cadence × step length` is a true kinematic identity, but a *fixed* step length
  is not a property of a person: the within-person invariant during free walking is the
  **walk ratio** (step length ÷ step rate) [Sekiya & Nagasaki 1998], so step length rises
  with cadence — and that invariance itself breaks below ~62 m/min (~98 steps/min)
  [Murakami & Otaka 2017], which is where much free-living walking sits. Substituting a
  constant stride therefore **rotates** the fitted line rather than shifting it, and the
  extrapolation to HRmax multiplies that slope error. See [[cadence_derived_speed]] for
  the measurement and for why no VO₂max is derived from cadence-derived speed.
- Restrict the fit to **steady-state segments** (stable HR + stable smoothed speed; drop
  the first ~3 min warm-up and any non-steady stretches).

**Accuracy (verified):**
- Vendor (Firstbeat white paper, **primary but non-peer-reviewed**): "MAPE ~5%, error
  <3.5 mL/kg/min in most cases" on 2690 freely-performed runs. The often-quoted
  **"correlation 0.95" is a relabel of 1−MAPE, NOT an independent Pearson r** — this
  inflated claim was adversarially **refuted (0-3)**; do not cite it.
- Independent peer-reviewed (Carrier et al. 2023, *Technologies* 11(3):71): the Garmin
  fenix 6 running the Firstbeat algorithm hit **MAPE 6.85%, Lin's CCC 0.70** vs lab CPET
  (n=21 athletes, structured *outdoor running*). CCC 0.70 is borderline-passing.

## How the coach uses it (tiered — better than swapping outright)

Don't replace Jurca outright; **tier it**, because the submaximal method only works when
there's good steady-state workout data:

1. **Primary — submaximal HR-vs-pace extrapolation** when a recorded GPS session supplies
   ≥~6 steady windows of running/brisk-walking (stable HR + stable measured speed). This is
   the accurate path for active users.
2. **Fallback — Jurca 2005 non-exercise** ([[non_exercise_vo2max]]) when there's no usable
   workout segment (the resting-HR-only estimate keeps a number on screen for sedentary
   days).
3. **Cross-check — Uth ratio** `15.3 × HRmax/HRrest` as a cheap sanity bound, NOT the
   engine (see its failure above/below).
4. Keep reporting the **7-day median + trend**, not a single number — within-person change
   is the trustworthy signal regardless of method.

## Safety bounds

- This is a wellness estimate, **not a clinical or precise measure** — never use it to
  clear anyone for hard training or to set race pace.
- Only trust it from **genuine steady-state sub-maximal effort**; do not derive a value
  from a maximal or erratic effort, and gate hard on steadiness so cardiac drift does not
  bias the line.

## Honesty & uncertainty (caveats to surface — UI + the estimate's flags)

- **Uth is a trap as a primary**: its low SEE% is deceptive. Independent validation in
  middle-aged/older adults (Eur J Appl Physiol 2021, n=20, age 62) found **POOR agreement
  (Lin's rc ≤ 0.40)** and **systematic underestimation of fitter people** — weak ranking
  ability. Use only as a bound.
- **Grade is modelled, not assumed away — but it is looked up, not measured.** Grade comes
  from an SRTM DEM keyed on the GPS track, so hills are priced (Minetti) rather than
  ignored; the residual error is the DEM's own resolution and any mismatch between the
  track and the ground actually walked. A session with **no GPS track has no measured
  speed and no grade, and produces no estimate at all** — it is not filled in from
  cadence ([[cadence_derived_speed]]).
- **Walking is not directly validated** for this method: the rigorous accuracy figures
  (MAPE 6.85%, CCC 0.70) come from structured *running*. Present walking-derived values
  with lower confidence than running-derived ones.
- **Non-steady pace / HR drift**: only steady-state segments are valid; cardiac drift over
  long efforts biases the HR↔workload line. Gate hard on steady-state.
- **Age-predicted HRmax error** propagates directly into every HR-based estimate (Uth's
  SEE went 2.7→4.7 just from swapping measured→predicted HRmax). Our short-sleeper user +
  anyone on **beta-blockers / with chronotropic issues** decouples HR from VO2 — flag it.
- **%HRR = %VO2R** (the Karvonen equivalence) is **contested**, not exact — treat any
  HR-reserve→VO2 mapping as approximate.

## Bottom line

**Act on confidently:** for an active user with a good steady-state outdoor *running*
segment, submaximal HR-vs-pace extrapolation is the most accurate non-lab estimate we can
make (MAPE ~6.85%, CCC 0.70), and it beats the resting-HR-only Jurca baseline. Report the
7-day median + trend, not a single value.

**Hold loosely:** the method's accuracy for **walking** (not directly validated), any
value derived without genuine steady-state effort, the Uth ratio
as anything beyond a sanity bound, and every HR-based estimate's sensitivity to
age-predicted HRmax error and HR-decoupling conditions.

## Coach Directives

1. Use the submaximal estimate as the **primary** `vo2max_estimate` path when a recorded
   GPS session supplies ≥~6 steady windows of running/brisk-walking; otherwise fall back to
   [[non_exercise_vo2max]]. *(confidence: high)*
2. **Gate hard on steady-state** (stable HR + stable measured speed; drop warm-up and
   drift); never extrapolate from non-steady or maximal effort. *(high)*
3. Treat the **Uth ratio only as a sanity bound**, never the engine — it under-ranks fitter
   people. *(high)*
4. **Never substitute a cadence-derived speed for a measured one** — a fixed step length is
   wrong by construction (the walk ratio, not the stride, is the within-person invariant),
   and the error lands on the slope the extrapolation multiplies; withhold instead
   ([[cadence_derived_speed]]). Flag HR-decoupling conditions (beta-blockers, chronotropic
   issues); do not cite the "0.95 correlation" vendor claim. *(high)*
5. Report the **7-day median + trend**, never a single number; label it an estimate.
   *(high)*

## References (primary, verified 2026-06-10)

- Firstbeat. *Automated Fitness Level (VO2max) Estimation with Heart Rate and Speed Data*
  (white paper, 2017). Vendor / non-peer-reviewed.
  https://assets.firstbeat.com/firstbeat/uploads/2017/06/white_paper_VO2max_30.6.2017.pdf
- Carrier B, et al. *Validation of Garmin Fenix 6 VO2max…* Technologies 2023;11(3):71.
  MAPE 6.85%, CCC 0.70. https://www.mdpi.com/2227-7080/11/3/71
- Lounana J, et al. (submaximal HR-VO2 linear extrapolation mechanic).
  https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10747607/
- Uth N, Sørensen H, Overgaard K, Pedersen PK. *Estimation of VO2max from the ratio
  between HRmax and HRrest.* Eur J Appl Physiol 2004;91:111–115. Factor 15.3 (SD 0.7);
  SEE 2.7 (measured HRmax) / 4.7 (age-predicted). https://pubmed.ncbi.nlm.nih.gov/14624296/
- (independent Uth validation, older adults, poor rc) Eur J Appl Physiol 2021, PMID 34495410.
  https://link.springer.com/article/10.1007/s00421-021-04808-z
- Vehrs PR, et al. ACSM submax extrapolation, r≈0.65/SEE 4.2–4.4. PMID 22262016.
- Ebbeling CB, et al. *Development of a single-stage submaximal treadmill walking test.*
  Med Sci Sports Exerc 1991. R²=0.86, SEE 4.85 (fixed 5% grade). PMID 1956273.
- Sekiya N, Nagasaki H. *Reproducibility of the walking patterns of normal young adults:
  test-retest reliability of the walk ratio (step-length/step-rate).* Gait Posture
  1998;7(3):225–227. PMID 10200388. doi:10.1016/s0966-6362(98)00009-5. "The walk ratio,
  step-length divided by step-rate, is a speed-independent index of walking patterns"
  (n=25, five speeds; ICC 0.6–0.8 except at extreme speeds) — i.e. step length is not
  independent of cadence. *(Verified 2026-08-02, #112.)*
- Murakami R, Otaka Y. *Estimated lower speed boundary at which the walk ratio constancy is
  broken in healthy adults.* J Phys Ther Sci 2017;29(4):722–725. PMID 28533617.
  doi:10.1589/jpts.29.722. n=21; "The initial break in the walk ratio constancy was at
  approximately 62 m/min… the boundary of cadence was approximately 98 [steps]/min."
  *(Verified 2026-08-02, #112.)*
- Minetti AE, et al. *Energy cost of walking and running at extreme uphill and downhill
  slopes.* J Appl Physiol 2002;93(3):1039–1046. PMID 12183501.
  doi:10.1152/japplphysiol.01177.2001. Measured over −0.45 to +0.45 (n=10), cost minimum
  at ≈−0.10 — the gradient-cost polynomial the shipped code scales the ACSM level value by,
  and the source of the ±0.45 validity clamp. *(Verified 2026-08-02, #112.)*

## Open questions (deferred)

- Peer-reviewed accuracy of the wearable method for **walking** (not running) on
  free-living data — not directly validated anywhere found.
- Whether a blended ensemble (HR-pace primary + Uth bound, gated to steady-state) beats any
  single method — untested.

## Healthee implementation & honesty policy

- **Derived field: `vo2max_estimate`** — this method is the **primary tier**;
  `vo2max_submax` carries the session-measured value, written by `derive/vo2max_submax.py`
  via `derive/gps.py` and tagged `flags.method = gps_graded`. Computed from per-minute
  workout HR, **GPS-measured speed** (per-fix distance ÷ time, smoothed), **SRTM DEM
  grade** (`derive/dem.py`, which replaces the phone's noisy GPS elevation), measured
  `rhr_daily`, and **Tanaka** HRmax — fitting VO₂ (ACSM level value × Minetti gradient-cost
  ratio) against HR over steady windows and extrapolating to HRmax.
- **No cadence→speed conversion exists in this path, and none may be added.** A fixed step
  length is not a person-level constant (the walk ratio is the within-person invariant, and
  its constancy breaks below ~62 m/min), so the substitution rotates the regression slope
  the extrapolation multiplies. Where no measured speed exists the value is **withheld**,
  never estimated from cadence — the measurement and the refusal live in
  [[cadence_derived_speed]]; the single canonical step-length constant lives in
  [[distance_from_steps]] and is used for daily distance only. **This note introduces no
  step-length constant.**
- **Tiering contract**: submaximal is used when a recorded GPS session supplies ≥~6 steady
  windows of running/brisk-walking; otherwise the derive pass falls back to the Jurca
  non-exercise model ([[non_exercise_vo2max]]). When the graded fit declines, the
  heart-rate-reserve inversion ([[hr_reserve_vo2max]]) may run as a *running-only*
  fallback and records `flags.graded_why_not`; the two are never blended. The Uth ratio is
  only a sanity bound, never the engine.
- **Honesty rules (carry into UI + LLM)**: label "estimate"; report the **7-day median +
  trend**, never a single number; flag HR-decoupling conditions (beta-blockers,
  chronotropic issues, the short-sleeper's autonomic state); **never** cite the refuted
  vendor "0.95 correlation"; never present a cadence-derived speed as a measured pace.
  **Walking is explicitly *not* directly validated** for this method — present
  walking-derived values with lower confidence than running-derived ones.
