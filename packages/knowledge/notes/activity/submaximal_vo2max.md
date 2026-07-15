---
id: submaximal_vo2max
topic: Submaximal HR-during-activity VO2max estimation — the wearable method, vs the Jurca non-exercise baseline
evidence_grade: 2
applies_to_metrics: [vo2max_estimate, hr, steps_per_minute, rhr_daily, max_hr]
applies_to_interventions: []
tags: [methodology, vo2max, submaximal, heart-rate, wearable]
last_reviewed: 2026-06-10
---

## Finding

For a user with **workout HR + pace data** (which we have: per-minute HR during
activity, cadence→speed from `steps_per_minute`, measured RHR, Tanaka HRmax), the
most accurate non-lab method is **submaximal HR-vs-pace extrapolation** — the same
approach commercial wearables (Garmin/Firstbeat, Polar) use. It builds the linear
HR↔workload relationship from steady-state sub-maximal segments and extrapolates it
out to HRmax. It is **more accurate than the Jurca non-exercise baseline for active
users**, but the advantage is real-but-modest and comes with honest caveats — it is
NOT a step-change, and for free-living *walking* on unknown grade it is not directly
validated.

*(All accuracy figures below are primary-source-verified against the cited papers,
adversarially checked. Where a figure is vendor/secondary it is flagged.)*

## Methods compared (for THIS data profile)

| Method | r / SEE vs measured VO2max | Fits our data? |
|---|---|---|
| **Submaximal HR-vs-pace extrapolation** (Firstbeat / wearable) ⭐ | indep. peer-reviewed **MAPE 6.85%, Lin's CCC 0.70** (Garmin fenix 6, Carrier 2023) | **Yes** — designed for free-living HR+pace |
| **Uth 2004 ratio** `15.3 × HRmax/HRrest` | **SEE 2.7** ml/kg/min w/ *measured* HRmax; **SEE 4.7 (~7.8%)** w/ age-predicted HRmax (what we use) | Yes, but weak — cross-check only |
| ACSM submax + Karvonen %HRR | r≈0.65, SEE 4.2–4.4 | **No** — needs known speed AND grade |
| Ebbeling single-stage walk | R²=0.86, SEE 4.85 | **No** — assumes a fixed 5% treadmill grade |
| *Jurca 2005 (current baseline)* | r≈0.78, **SEE≈5.6** | — (resting-HR only; no workout data used) |

> ⚠ Cross-study SEE comparisons are **NOT head-to-head** — each method was validated
> on a different population/protocol, so a lower SEE alone does not prove superiority
> in our free-living context. Jurca's 5.6 was a general population; Uth's 2.7 was
> well-trained young men.

## The recommended method (submaximal HR-vs-pace extrapolation)

**Mechanic** (demonstrated controlled in Lounana/PMC10747607, the basis of the wearable
algorithms): over steady-state sub-maximal segments of a workout, fit a per-session
linear regression of **VO2 (from the ACSM level speed→VO2 equation) against HR**, then
extrapolate that line to **Tanaka HRmax** → VO2max.

- ACSM level-walking VO2 (ml/kg/min) ≈ `3.5 + 0.1·speed_m_min + 1.8·speed_m_min·grade`
  (grade = 0 assumed; the unknown-grade term is the main error source).
- ACSM level-running VO2 ≈ `3.5 + 0.2·speed_m_min + 0.9·speed_m_min·grade`.
- Speed from cadence: `speed = steps_per_minute × stride_length`.
- Restrict the fit to **steady-state segments** (stable HR + stable cadence; drop the
  first ~3–5 min warm-up and any non-steady stretches).

**Accuracy (verified):**
- Vendor (Firstbeat white paper, **primary but non-peer-reviewed**): "MAPE ~5%, error
  <3.5 ml/kg/min in most cases" on 2690 freely-performed runs. The often-quoted
  **"correlation 0.95" is a relabel of 1−MAPE, NOT an independent Pearson r** — this
  inflated claim was adversarially **refuted (0-3)**; do not cite it.
- Independent peer-reviewed (Carrier et al. 2023, *Technologies* 11(3):71): the Garmin
  fenix 6 running the Firstbeat algorithm hit **MAPE 6.85%, Lin's CCC 0.70** vs lab CPET
  (n=21 athletes, structured *outdoor running*). CCC 0.70 is borderline-passing.

## How we'll use it (tiered — better than swapping outright)

Don't replace Jurca outright; **tier it**, because the submaximal method only works when
there's good steady-state workout data:

1. **Primary — submaximal HR-vs-pace extrapolation** when a recent workout has ≥~6 min of
   steady-state running/brisk-walking (stable HR+cadence). This is the accurate path for
   active users.
2. **Fallback — Jurca 2005 non-exercise** (current) when there's no usable workout segment
   (the resting-HR-only estimate keeps a number on screen for sedentary days).
3. **Cross-check — Uth ratio** `15.3 × HRmax/HRrest` as a cheap sanity bound, NOT the
   engine (see its failure below).
4. Keep reporting the **7-day median + trend**, not a single number — within-person change
   is the trustworthy signal regardless of method.

## Caveats to surface (UI + the estimate's flags)

- **Uth is a trap as a primary**: its low SEE% is deceptive. Independent validation in
  middle-aged/older adults (Eur J Appl Physiol 2021, n=20, age 62) found **POOR agreement
  (Lin's rc ≤ 0.40)** and **systematic underestimation of fitter people** — weak ranking
  ability. Use only as a bound.
- **Unknown grade**: with no GPS elevation we assume level ground. Hills inflate HR at a
  given flat-speed → **fitness underestimated** on hilly walks. This is the biggest
  unmodeled error for free-living walking and is **not directly validated** for walking
  (the rigorous figures are from *running*).
- **Non-steady pace / HR drift**: only steady-state segments are valid; cardiac drift over
  long efforts biases the HR↔workload line. Gate hard on steady-state.
- **Age-predicted HRmax error** propagates directly into every HR-based estimate (Uth's
  SEE went 2.7→4.7 just from swapping measured→predicted HRmax). Our short-sleeper user +
  anyone on **beta-blockers / with chronotropic issues** decouples HR from VO2 — flag it.
- **%HRR = %VO2R** (the Karvonen equivalence) is **contested**, not exact — treat any
  HR-reserve→VO2 mapping as approximate.

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

## Open questions (deferred)

- Peer-reviewed accuracy of the wearable method for **walking** (not running) on
  free-living **unknown-grade** data — not directly validated anywhere found.
- How much omitting grade actually biases free-living-walking extrapolation — unquantified.
- Whether a blended ensemble (HR-pace primary + Uth bound, gated to steady-state) beats any
  single method — untested.
