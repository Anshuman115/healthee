---
id: recovery_readiness
title: Daily recovery / readiness from wearable autonomic + sleep markers
evidence_grade: 2
applies_to_metrics: [recovery_score, hrv_sleep_avg, rhr_daily, respiratory_rate_sleep, tst_min, cardio_load]
applies_to_interventions: []
last_verified: 2026-06-20
---

# Daily recovery / readiness — evidence base

**Bottom line for healthee:** there is **NO peer-reviewed, validated formula** that
combines HRV + RHR + sleep into a single "recovery" number. Whoop / Oura / Garmin /
Polar scores are **proprietary** and largely vendor-validated only. The individual
*markers* are well-evidenced; combining them is an informed estimate, not a clinical
truth. So `recovery_score` is shipped as a **0–100 estimate ALWAYS shown with its
per-factor breakdown** — honest about what's pulling it up/down — not a black box.
This is the documented, user-approved exception to [[no_validated_sleep_score]] /
the no-composite rule: published per-marker science + transparent weighting + a
visible breakdown (same bar we cleared for biological-age).

## What the window is
Overnight / first hours of sleep is the correct measurement window: parasympathetic
(vagal) reactivation dominates at-rest cardiac control during sleep, so overnight
HRV/RHR index recovery state better than daytime spot readings (Stanley 2013 review
of parasympathetic reactivation; Michael 2017 — early HR recovery is parasympathetic).
Recovery is therefore **set at wake**; it does not rise during the day.

## Factors, by evidence strength
| Factor | Direction | Evidence | Grade | Weight |
|---|---|---|---|---|
| **Overnight HRV** (lnRMSSD) vs personal baseline | higher = better | Manresa-Rocamora 2021 meta: HRV-guided training improved vagal markers (SMD ≈ 0.50, sig); **VO₂max effect NS (0.13)** → HRV reflects autonomic *state*, not performance. Plews 2013; Buchheit 2014. | ★★★ marker / ★★ as readiness | **0.42** |
| **Resting HR** vs personal baseline | lower = better | Aune 2017 meta (n≈1.2M): +10 bpm RHR → RR 1.17 all-cause mortality; acute RHR elevation tracks fatigue/illness. | ★★★ | **0.28** |
| **Sleep** (TST vs physiological NEED) | more = better | Cappuccio 2010 meta — short sleep ↑ mortality; sleep is restorative. Scored vs **absolute need**, not personal median (you can't out-baseline the need — critical for a chronic short sleeper, who IS genuinely under-recovered). | ★★★ marker | **0.20** |
| **Respiratory rate** vs baseline | lower = better | Elevated overnight RR is an early illness/strain signal (Smarr 2020; Quer 2021). | ★★ | **0.10** |
| Skin-temp deviation | elevation = worse | Illness/luteal signal; noisy on wrist. | ★★ | (excluded for now — not in daily derived store) |
| Prior-day strain (TRIMP) | feeds intraday decay | Banister TRIMP; ACWR Gabbett 2016. | ★★ | (intraday only) |

Weights are assigned **by evidence strength, not fitted** — and renormalized over
whatever factors exist for the night.

## Normalization (the key methodological point)
Use the **personal smoothed baseline + smallest-worthwhile-change**, NOT population
norms (Plews 2013; Buchheit 2014 methodological review). HRV/RHR/RR are scored as a
robust z vs the person's own trailing ~6-week median (MAD-based SD) — so the
reference adapts to the individual. This is what makes it valid for our chronic
~4 h sleeper: their autonomic baseline is their own, while **sleep is held to the
absolute need** so the score stays physiologically honest about under-recovery.

## Live readiness (intraday decay)
Recovery is the morning value; what changes through the day is **strain consuming
capacity**. There is **no validated intraday "battery" formula** (Garmin Body
Battery / Firstbeat is proprietary). We model it transparently and conservatively:
`readiness(t) = recovery × (1 − 0.5 · min(1, strain_today / typical_daily_strain))`,
where strain = Banister TRIMP cardio-load accrued so far and typical = personal
30-day median. A full typical day's strain trims readiness by ≤50%; always shown as
"recovery 72 → 58 (−14 today's load)". Framed as an estimate, not validated.

## Honesty constraints (carry into UI + LLM)
- Label it an **estimate**; trend matters more than any single day.
- Always render the **per-factor breakdown** + these citations; never a bare number.
- Do not claim it predicts performance (the meta-analytic VO₂max effect was NS).
- Never medical-grade; elevated RR+temp → "possible early signal", not a diagnosis.

## Primary sources (verified 2026-06-20)
- Manresa-Rocamora 2021, *J Sci Med Sport* — HRV-guided training meta-analysis.
- Aune 2017 — resting HR & mortality meta-analysis (n≈1.2M).
- Cappuccio 2010 — sleep duration & mortality meta-analysis.
- Stanley 2013 — parasympathetic reactivation after exercise (review).
- Plews 2013 / Buchheit 2014 — HRV baseline + SWC normalization methodology.
- Gabbett 2016 — acute:chronic workload ratio.
