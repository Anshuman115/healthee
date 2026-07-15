---
id: biological_age_estimate
name: "Biological Age (estimate)"
topic: A motivational "biological age" from wearable metrics via the Gompertz hazard→years conversion (the WHOOP-Age method) — a DOCUMENTED EXCEPTION to the no-composite rule
category: metrics
grade: Probable
evidence_grade: 2
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
rises exponentially, doubling every **MRDT ≈ 7.7–8 years** — UK Biobank put it at
7.7 for both sexes). The conversion:

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

- **Gompertz / MRDT 7.7y**: UK Biobank actuarial analysis; classical Gompertz
  doubling ~8y. **★★★** for the conversion math.
- **PhenoAge** (Levine et al. 2018, *Aging*) + **GOLD BioAge** (Hao et al. 2025,
  *Nature Aging*) — methodological templates: hazard-score → years. **★★**.
- **CRF/VO₂max**: dose-response meta-analyses, HR 0.83–0.86 per MET, 20.9M obs
  (Kokkinos JACC 2022; Atherosclerosis 2021; ScienceDirect 2024). **★★★**.
- **Sleep duration**: Yin et al. 2017 *JAHA* dose-response (also Cappuccio 2010).
  **★★**. **SRI**: Cribb et al. 2023 *eLife* (n=88,975; HR 1.53/0.90). **★★**.
- RHR (Aune 2017 ★★★), steps (del Pozo Cruz 2022 ★★), MVPA (Woodcock 2011 ★★),
  grip (Wu 2017 ★★) — all in the per-metric notes; folded into / informing the
  fitness term, not multiplied separately.

## Caveats (must surface)

- **Not causal, not clinical.** Population associations → a *motivational trend*,
  never a diagnosis. Label every surface as "estimate."
- **Independence is approximated.** Even with one fitness term, residual
  correlation remains; treat ±a few years as noise.
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
- Cribb L, et al. (2023). *Sleep regularity and mortality (Sleep Regularity Index).* eLife (n=88,975; HR 1.53 @SRI 41 → 0.90 @SRI 75, UK Biobank).
- Aune D, et al. (2017). *Resting heart rate and the risk of CVD, cancer, and all-cause mortality.* Nutr Metab Cardiovasc Dis 27(6):504–517.
- del Pozo Cruz B, et al. (2022). *Daily step count and mortality.* (Steps dose-response.)
- Woodcock J, et al. (2011). *Non-vigorous physical activity and all-cause mortality: meta-analysis.* Int J Epidemiol 40(1):121–138.
- Wu Y, et al. (2017). *Grip strength and all-cause mortality: meta-analysis.* (Folded into/informing the fitness term, not multiplied separately.)

## Healthee implementation & honesty policy
- **Computed on read, not stored as a daily metric.** `analytics/biological_age.py::compute_biological_age` produces the estimate from `derived_daily` reads; `read/health_metrics.py::biological_age_payload` is a thin wrapper. It returns `chronological_age`, `biological_age`, `delta_years`, the signed per-term `contributions`, a `disclaimer` ("Motivational estimate from population data — not a clinical or diagnostic age."), and `research_notes: ["biological_age_estimate"]`; returns **None** without a profile (`dob`/`sex`) or inputs.
- **Constants (ported verbatim from legacy `biological_age.py`):** `GOMPERTZ_MRDT_YEARS = 7.7`, `TERM_CAP_YEARS = 10.0`, and the age/sex population-median VO₂max tables (`_VO2MAX_MEDIAN_MALE/FEMALE`, 20–70 buckets). `b = ln(2)/7.7`; each term `d = clamp(±10, ln(hr)/b)`.
- **The three terms (v2 field names):**
  - **Fitness** — latest `vo2max_estimate` vs age/sex median, `0.85 ** ((vo2 − ref)/3.5)`.
  - **Sleep duration** — 14-night average TST read from `sleep_health_score_4dim` flags (`tst_min`), U-shaped about 7h (`1.06**(7−h)` if h<7 else `1.13**(h−7)`).
  - **Regularity** — latest `sleep_regularity_index`, log-linear through the Cribb 2023 anchors (SRI 41 → 1.53, 75 → 0.90).
  `applies_to_metrics` names `biological_age` (the estimate; the v1 note wrote `biological_age_delta`) plus its real inputs `vo2max_estimate`, `sleep_regularity_index`, and `sleep_health_score_4dim` (the TST source; the v1 `asleep` name is retired).
- **Composite exception:** this is the one documented composite; the per-term breakdown is required by both the note and the code (contributions are always returned). See [[feedback-no-composite-score]].
- **Honesty rules (carry into UI + LLM):** always show the per-term breakdown; label "estimate / motivational, not clinical"; never a mortality/risk/real-age number; ±a few years is noise; if VO₂max looks off, the estimate inherits that error.
