---
id: biological_age_estimate
name: "Biological Age (estimate)"
topic: A motivational "biological age" from wearable metrics via the Gompertz hazard→years conversion (the WHOOP-Age method) — a DOCUMENTED EXCEPTION to the no-composite rule
category: metrics
grade: Probable
summary: "A motivational biological-age estimate converts meta-analytic all-cause-mortality hazard ratios into years via the Gompertz law (MRDT ≈ 7.7y); a DOCUMENTED exception to the no-composite rule, admissible only because the conversion is published actuarial math, every input HR is meta-analytic, and the per-term year contributions are always shown — an estimate, never a clinical readout."
aliases: ["biological_age", "bio age", "biological age", "whoop age", "gompertz age", "mortality age", "longevity", "composite", "motivational"]
applies_to_metrics: ["biological_age", "vo2max_estimate", "sleep_regularity_index", "sleep_health_score_4dim"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
---

# Biological Age (estimate)

## Summary
A single "biological age" is estimated by converting all-cause-mortality hazard ratios into years using the Gompertz law of mortality (death hazard doubles every ~7.7–8 years). It is a **deliberate, documented exception to the no-composite rule**, admissible only because (a) the conversion is published actuarial math, (b) every input hazard ratio is meta-analytic, and (c) it is framed as a **motivational estimate, never a clinical readout** — with the per-term year contributions always shown alongside the number. VO₂max (fitness) dominates and is the least certain input, so each term's contribution is capped at ±10 years. Evidence is **★★ moderate**: sound conversion and meta-analytic inputs, but a novel wearable assembly, not a validated clock.

## What it is
Biological age = chronological age + ΔAge, where ΔAge is derived from the product of each tracked input's mortality hazard ratio relative to a "meeting the recommendations" reference. Hitting every target lands the estimate near the person's real age; carrying risk (low fitness, short/irregular sleep) adds years. The number is surfaced **only with its per-term breakdown** ("fitness +X · short sleep +Y · regularity +Z"), which is the honest part.

## Physiology / mechanism
The Gompertz law describes how all-cause mortality hazard rises roughly exponentially with age, doubling over a fixed mortality-rate-doubling-time (MRDT). Because a fixed proportional change in hazard maps to a fixed number of years, a meta-analytic hazard ratio for a risk factor (e.g. lower cardiorespiratory fitness) can be expressed as an equivalent age shift. This is the same hazard→age machinery that validated epigenetic/phenotypic clocks use — the estimate borrows their actuarial conversion, not a new biological measurement.

## Finding

A single "biological age" can be estimated by converting all-cause-mortality
hazard ratios into years, using the **Gompertz law of mortality** (death hazard
rises exponentially, doubling every **MRDT ≈ 7.7–8 years** — Libert et al. 2025
measured **7.7 y, "for both males and females"**, in UK Biobank; the classical
Gompertz figure is ~8 y). The conversion:

```
b        = ln(2) / MRDT                 ≈ 0.693 / 7.7 ≈ 0.090 per year
ΔAge     = ln(HR_total) / b             ≈ 11.1 × ln(HR_total)   (≈11.55 at MRDT 8)
bio_age  = chronological_age + ΔAge
```

This is the SAME hazard→age machinery validated clocks use (Levine PhenoAge 2018;
Hao "GOLD BioAge" 2025). HR_total is the product of each input's hazard ratio
relative to a "meeting the recommendations" reference, so hitting every target
lands you near your real age.

**⚠ This is a composite — a deliberate, documented exception to
[[feedback-no-composite-score]].** It is admissible ONLY because (a) the conversion
is published actuarial math, (b) every input HR is meta-analytic, and (c) it is
framed as a *motivational estimate, never a clinical readout*. The per-metric YEAR
CONTRIBUTIONS are shown alongside the number — the breakdown is the honest part.

## Inputs we use (and the correlation fix)

Naive multiplication of all metrics double-counts cardio-fitness (VO₂max, steps,
MVPA, RHR are heavily correlated). So we collapse them into **ONE fitness term**
and keep the independent sleep axes separate:

| term | HR | reference | source |
|---|---|---|---|
| **Fitness** (VO₂max-anchored, subsumes steps/MVPA/RHR) | **0.85 per +1 MET** (1 MET = 3.5 ml/kg/min) | age/sex-median VO₂max | CRF meta-analyses, 20.9M obs (HR 0.83–0.86/MET) |
| **Sleep duration** (U-shaped) | 1.06 per h **below** 7h; 1.13 per h **above** 7h | 7h | Yin 2017 JAHA |
| **Sleep regularity (SRI)** | log-interpolate 1.53 @SRI 41 → 1.00 @median → 0.90 @SRI 75 | SRI 75 | Cribb 2023 eLife (UK Biobank) |

We deliberately **omit grip/strength** (no sensor) rather than fake a proxy.
HR_total = HR_fitness × HR_sleepdur × HR_SRI.

## Effect size / sanity checks

- HR_total = 1.10 → ΔAge = +1.05 y (the "10% ≈ 1 year" rule). ✓
- VO₂max is the dominant term (strongest HR per MET) AND the least certain input
  (Jurca non-exercise estimate, ±5.6 ml/kg/min SEE) — so bio_age is sensitive to
  it. We **cap each term's contribution to ±10 years** to stop a single noisy
  input producing an absurd/alarming age.

## Evidence strength

- **Gompertz / MRDT 7.7y**: Libert, Chekholko & Kenyon 2025 (*eLife* 13:RP92092,
  PMID 40497443), whose UK Biobank mortality analysis states verbatim: *"The
  distribution of these deaths among UKBB participants has a typical 'Gompertzian'
  shape, with mortality rates exponentially doubling every 7.7 years for both males
  and females."* Their own framing of the classical value: *"mortality rates increase
  exponentially with time, doubling roughly every 8 years."* **★★★** for the
  conversion math (Gompertz is not in dispute); **★★** for 7.7 as *our* MRDT
  parameter — it is one cohort's empirical estimate, from 8,883 male and 5,668 female
  deaths within 5 years of enrolment in a healthy-volunteer cohort recruited at ages
  40–70, not a universal constant. The estimate is insensitive to the choice within
  the plausible range: ΔAge = 11.1 × ln(HR) at MRDT 7.7 vs 11.55 at MRDT 8 — a ~4 %
  difference, well inside the "±a few years is noise" caveat below.
- **PhenoAge** (Levine et al. 2018, *Aging*) + **GOLD BioAge** (Hao et al. 2025,
  *Nature Aging*) — methodological templates: hazard-score → years. **★★**.
- **CRF/VO₂max**: dose-response meta-analyses, HR 0.83–0.86 per MET, 20.9M obs
  (Kokkinos JACC 2022; Atherosclerosis 2021; ScienceDirect 2024). **★★★**.
- **Sleep duration**: Yin et al. 2017 *JAHA* dose-response (also Cappuccio 2010).
  **★★**. **SRI**: Cribb et al. 2023 *eLife* — verified verbatim against the
  published abstract: *"Hazard ratios, relative to the median SRI, were 1.53 (95% CI:
  1.41, 1.66) for participants with SRI at the 5th percentile (SRI = 41) and 0.90
  (95% CI: 0.81, 1.00) for those with SRI at the 95th percentile (SRI = 75)"*,
  n = 88,975. **★★**.
- RHR (Aune 2017 ★★★), steps (del Pozo Cruz 2022 ★★), MVPA (Woodcock 2011 ★★),
  grip (Wu 2017 ★★) — all in the per-metric notes; folded into / informing the
  fitness term, not multiplied separately.

## Caveats (must surface)

- **Not causal, not clinical.** Population associations → a *motivational trend*,
  never a diagnosis. Label every surface as "estimate."
- **Independence is approximated.** Even with one fitness term, residual
  correlation remains; treat ±a few years as noise.
- 🔴 **The regularity term's anchors are on Cribb's SRI scale and ours is not — this
  is a KNOWN WRONG NUMBER, measured 2026-08-01 (#83c), not yet fixed.**
  Cribb's UK Biobank cohort had a **median SRI of 60 (SD 10)**; Windred 2024's UK
  Biobank cohort — the same biobank, the same accelerometry — had a **median of 81.0
  [IQR 73.8–86.3]**. Neither is wrong; the SRI a study reports depends on its
  sleep-detection pipeline (Windred ran GGIR then `sleepreg`, which counts naps and
  subtracts WASO episodes ≥30 min; Cribb ran GGIR 2.7-1 alone, which detects no naps;
  ours is night-only from the strap's hypnogram). A 21-point spread on one cohort is
  the measurement that SRI is **not** a portable absolute.

  The previous version of this caveat said "nobody has measured where our SRI
  distribution actually sits". That has now been done — not from owner data, but
  from the estimator itself, which is exact:

  - `derive/sleep_score.py::_compute_sri` reduces, for a sleeper whose bed and wake
    times shift by *d* minutes between consecutive days, to
    **SRI = 100 − (200/1440) × 2d**. Cross-check: the note's own known-value example
    (7 h sleep drifting 2 h, so *d* = 120) gives 100 − 0.1389 × 240 = **66.67**, the
    documented canonical value. ✓
  - Push Windred's *own behavioural description* of its quintiles through that
    formula: its most-regular quintile ("within roughly a 1-hour band", *d* ≈ 30) maps
    to **91.67** against Windred's published Q4/Q5 boundary of 87.32; its least-regular
    quintile ("roughly a 3-hour band", *d* ≈ 90) maps to **75.00** against Windred's
    published Q1/Q2 boundary of 71.65. High by **4.35 and 3.35 points** — same sign,
    similar size, across a 16-point span, and inside the slack in Windred's own hedged
    wording. **Our SRI is on Windred's scale, a few points high — it is not on
    Cribb's.**
  - Read Cribb's anchors back through our formula and they describe behaviour no
    ordinary person has: SRI 60 (Cribb's *median*) is a 2.4-hour shift at each end
    every night, and SRI 41 (Cribb's 5th percentile, the HR 1.53 anchor) is a
    7.1-hour shift — near-total non-overlap.

  **The consequence, which needs no scale assumption at all:** the log-linear crosses
  HR = 1.0 at **SRI 68.24**, and on our formula 68.24 *is* a 1.9-hour shift at each end
  — worse than Windred's least-regular quintile. So on our scale the term's penalty
  half is unreachable: **every realistic sleeper, including a genuinely irregular one,
  receives an age-reducing contribution**, and everyone at SRI ≥ 75 (a 3-hour band)
  is clamped to the maximum credit of −1.17 y. Illustrative magnitude, using a crude
  median re-scale (ours − 21) purely to show size: a median sleeper is credited
  −1.17 y where Cribb's own model would put them near **+1.4 y** (≈ 2.6 years of
  flattery); an irregular sleeper ≈ **3.6 years**. Those corrected figures are an
  *illustration of magnitude, not a constant to adopt* — the two distributions differ
  in spread as well as centre, and no re-scale should be shipped without measuring our
  own SRI distribution on real owner data.
  **This is the exact failure the product exists to avoid: it errs in the flattering
  direction.** Fixing it is a science change and therefore its own PR with known-value
  tests (CLAUDE.md); this note records the defect precisely so nobody re-derives it.
- **VO₂max-dominated + uncertain** — see the cap above. If the VO₂max estimate
  looks off, the bio_age inherits that error.
- Reference = "meeting recommendations," so the number is *relative to healthy
  targets*, not a measured age.

## Operational use

- Surface `biological_age` = chronological + ΔAge, with the **per-term year
  contributions** (e.g. "fitness +X · short sleep +Y · regularity +Z") — the
  breakdown is mandatory, not optional.
- UI label: **"Biological age · estimate"** + a one-line "motivational, not
  clinical" note; full method in the ⓘ sheet.
- Evidence label: **★★ moderate** (sound conversion + meta-analytic inputs; novel
  wearable assembly, not a validated clock).

## How the coach uses it
- **Stage 1 (thin data):** hold the number back or heavily caveat it until the VO₂max estimate and ≥14 nights of sleep exist; without inputs there is no estimate (returns nothing).
- **Stage 2 (estimate available):** present it motivationally with the **per-term breakdown** always visible; point the user at whichever term contributes the most years (usually fitness) as the highest-leverage lever.
- **Stage 3 (tracking over time):** frame movement as a motivational trend, treating ±a few years as noise; never imply a measured or clinical age change.
- **Always:** never present it as a diagnosis, a real age, or a mortality/risk number; the breakdown is mandatory.

## Safety bounds
- **Never present biological age as a clinical, diagnostic, or mortality figure** — it is a motivational estimate from population associations only.
- The per-term breakdown is **mandatory**, not optional; the composite number must never be shown alone.
- Each term's contribution is hard-capped at **±10 years** so a single noisy input cannot produce an alarming age.

## Honesty & uncertainty
See **Caveats (must surface)** above — all mandatory. In brief: not causal or clinical (label "estimate"); independence only approximated (±a few years is noise); VO₂max-dominated and uncertain (the ±10y cap exists for this); the reference is "meeting recommendations," so the number is relative to healthy targets, not a measured age. It is a **novel wearable assembly, not a validated clock (★★ moderate)**.

## Bottom line
**Act on confidently:** the Gompertz hazard→years conversion math (★★★); the single-fitness-term correlation fix; showing the mandatory per-term breakdown; the ±10y-per-term cap; framing as a motivational estimate.

**Hold loosely:** the exact biological-age number for an individual (VO₂max-dominated and uncertain); small movements over time (noise); anything resembling a clinical or mortality readout.

## Coach Directives
1. Always surface the **per-term year contributions** with the number — never the composite alone. *(confidence: high)*
2. Label every surface **"Biological age · estimate"** and "motivational, not clinical." *(high)*
3. **SAFETY:** never present it as a clinical/diagnostic age or a mortality/risk figure. *(high)*
4. Treat ±a few years as noise; point the user at the largest-contributing term (usually fitness) as the highest-leverage lever. *(moderate)*
5. Keep the **±10-years-per-term cap**; if the VO₂max estimate looks off, say the bio-age inherits that error. *(high)*

## References
- Levine ME, et al. (2018). *An epigenetic biomarker of aging for lifespan and healthspan (PhenoAge).* Aging 10(4):573–591.
- Hao et al. (2025). *GOLD BioAge.* Nature Aging (hazard-score → years methodological template).
- Kokkinos P, et al. (2022). *Cardiorespiratory fitness and mortality risk.* JACC (CRF dose-response, HR 0.83–0.86 per MET, 20.9M obs); with corroborating Atherosclerosis 2021 and ScienceDirect 2024 meta-analyses.
- Yin J, et al. (2017). *Relationship of sleep duration with all-cause mortality: a dose-response meta-analysis.* JAHA 6(9):e005947. (Also Cappuccio FP, et al. 2010.)
- Cribb L, Sha R, Yiallourou S, Grima NA, Cavuoto M, Baril A-A, Pase MP (2023). *Sleep regularity and mortality: a prospective analysis in the UK Biobank.* eLife 12:RP88359. DOI 10.7554/eLife.88359. PMID 37995126. (n=88,975; median SRI 60; HR 1.53 @SRI 41 [5th pct] → 0.90 @SRI 75 [95th pct].)
- Libert S, Chekholko A, Kenyon C (2025). *A mathematical model that predicts human biological age from physiological traits identifies environmental and genetic factors that influence aging.* eLife 13:RP92092. DOI 10.7554/eLife.92092. PMID 40497443. (Source of MRDT = 7.7 y, UK Biobank, both sexes.)
- Gavrilov LA, Gavrilova NS (2024). *Exploring patterns of human mortality and aging: a reliability theory viewpoint.* Biochemistry (Moscow) 89(2):341–355. DOI 10.1134/S0006297924020123. PMID 38622100. (Review; "human mortality rates double approximately every 8 years of adult age" — the classical ~8 y comparator.)
- Aune D, et al. (2017). *Resting heart rate and the risk of CVD, cancer, and all-cause mortality.* Nutr Metab Cardiovasc Dis 27(6):504–517.
- del Pozo Cruz B, et al. (2022). *Daily step count and mortality.* (Steps dose-response.)
- Woodcock J, et al. (2011). *Non-vigorous physical activity and all-cause mortality: meta-analysis.* Int J Epidemiol 40(1):121–138.
- Wu Y, et al. (2017). *Grip strength and all-cause mortality: meta-analysis.* (Folded into/informing the fitness term, not multiplied separately.)

## Healthee implementation & honesty policy
- **Computed on read, not stored as a daily metric.** `analytics/biological_age.py::compute_biological_age` produces the estimate from `derived_daily` reads; `read/health_metrics.py::biological_age_payload` is a thin wrapper. It returns `chronological_age`, `biological_age`, `delta_years`, `data_confidence`, a `withheld` block, the signed per-term `contributions`, a `disclaimer` ("Motivational estimate from population data — not a clinical or diagnostic age."), and `research_notes: ["biological_age_estimate"]`; returns **None** without a profile (`dob`/`sex`) or inputs.
- **EVERY term is REQUIRED — no current input for any of the three, no number.** The Stage-1 directive above ("hold the number back … until the VO₂max estimate and ≥14 nights of sleep exist") is enforced structurally, not by caveat. A term simply left out of `chrono + ΣΔAge` is not an omission: it is the assertion `HR_term = 1.0`, i.e. *this person is exactly at the reference for that lever* — silently invented. So when the owner has no `vo2max_estimate` for their **own today** (withheld by [[non_exercise_vo2max]]'s gate, or not derived yet), no `sleep_regularity_index` for their own today (withheld by this note's Directive-4 gate on a <7-night window, or not derived yet), or no recorded night in the trailing 14, `biological_age` and `delta_years` are `null`, `data_confidence` is `insufficient_data`, and `withheld.terms` lists EVERY absent term with the input metric's own reason and message verbatim (`derive/vo2max.py::WITHHOLD_MESSAGES`, `derive/sleep_score.py::SRI_MESSAGES`) alongside one `consequence` explaining what the absence costs. The contributions that ARE current still ship: each is a standalone hazard→years fact, and hiding them would withhold something we do know.
  - **Why regularity and duration, not only the dominant term.** Dominance is why the composite is *sensitive* to fitness; it is not why omitting a term is a lie — the omission is a claim at any size. Regularity's is not small: the Cribb anchors span −1.2 y (SRI 75) to +4.7 y (SRI 41), and dropping the term asserts SRI ≈ 68 (the neutral point of the log-linear), which for an irregular sleeper silently subtracts nearly five years. One rule over all terms, rather than a per-term policy, is deliberate: "which terms matter enough" is the question that produced an uncited constant elsewhere in this codebase.
  - The freshness rules are `derive/vo2max.py::estimate_unavailable_reason` and `derive/sleep_score.py::sri_unavailable_reason`, both bound to the one shared rule in `derive/freshness.py` and shared with `read/vo2max.py` and `read/sleep_extras.py` — so the VO₂max card, the regularity card and this estimate can never disagree about whether today has a number.
- **Constants (ported verbatim from legacy `biological_age.py`):** `GOMPERTZ_MRDT_YEARS = 7.7` (Libert et al. 2025, eLife 13:RP92092 — UK Biobank, both sexes; verified against the paper 2026-08-01, replacing an unattributed "UK Biobank actuarial analysis"), `TERM_CAP_YEARS = 10.0`, and the age/sex population-median VO₂max tables (`_VO2MAX_MEDIAN_MALE/FEMALE`, 20–70 buckets). `b = ln(2)/7.7`; each term `d = clamp(±10, ln(hr)/b)`.
- **The three terms (v2 field names):**
  - **Fitness** — latest `vo2max_estimate` vs age/sex median, `0.85 ** ((vo2 − ref)/3.5)`.
  - **Sleep duration** — 14-night average TST read from `sleep_health_score_4dim` flags (`tst_min`), U-shaped about 7h (`1.06**(7−h)` if h<7 else `1.13**(h−7)`).
  - **Regularity** — latest `sleep_regularity_index`, log-linear through the Cribb 2023 anchors (SRI 41 → 1.53, 75 → 0.90).
  `applies_to_metrics` names `biological_age` (the estimate; the v1 note wrote `biological_age_delta`) plus its real inputs `vo2max_estimate`, `sleep_regularity_index`, and `sleep_health_score_4dim` (the TST source; the v1 `asleep` name is retired).
- **Composite exception:** this is the one documented composite; the per-term breakdown is required by both the note and the code (contributions are always returned). See [[feedback-no-composite-score]].
- **Honesty rules (carry into UI + LLM):** always show the per-term breakdown; label "estimate / motivational, not clinical"; never a mortality/risk/real-age number; ±a few years is noise; if VO₂max looks off, the estimate inherits that error.
