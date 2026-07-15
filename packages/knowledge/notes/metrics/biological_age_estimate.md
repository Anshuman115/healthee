---
id: biological_age_estimate
topic: A motivational "biological age" from wearable metrics via the Gompertz hazard→years conversion (the WHOOP-Age method) — a DOCUMENTED EXCEPTION to the no-composite rule
evidence_grade: 2
applies_to_metrics: [biological_age_delta, vo2max_estimate, asleep, sleep_regularity_index]
applies_to_interventions: []
tags: [longevity, fitness, sleep, composite, motivational]
last_reviewed: 2026-06-06
---

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
