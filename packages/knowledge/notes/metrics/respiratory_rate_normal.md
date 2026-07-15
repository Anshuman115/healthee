---
id: respiratory_rate_normal
name: "Respiratory Rate (overnight)"
topic: Respiratory rate during sleep — normal ranges and what shifts mean
category: metrics
grade: Established
evidence_grade: 3
summary: "Overnight respiratory rate is 12–20 br/min (most 12–16 in deep sleep) and personally very stable (<1 br/min night-to-night); a sustained ≥2 br/min rise over the personal baseline is a validated early illness signal, not a diagnosis."
aliases: ["respiratory_rate", "respiration rate", "breathing rate", "RR", "overnight respiratory rate", "sleep respiratory rate", "respiration", "autonomic"]
applies_to_metrics: ["respiratory_rate_sleep"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
---

# Respiratory Rate (overnight)

## Summary
Resting and sleep respiratory rate in healthy adults is consistently **12–20 breaths per minute**, with most healthy adults sitting **12–16** during deep sleep. Its coaching value comes from its **stability**: a healthy individual's own nightly average varies by typically **<1 breath/min** night-to-night, so a sustained shift above the personal baseline is a clean, low-noise signal. A **≥2 br/min rise sustained over two nights** — especially paired with an HRV drop or RHR rise — is a validated early signal of respiratory infection, often preceding symptoms by 1–2 days. It is an early-warning prompt, never a diagnosis.

## What it is
Respiratory rate is the number of breaths per minute. Healthee reads it **only during sleep**, where the body is still and the wearable's derivation is reliable. Typical ranges:
- **Healthy nocturnal baseline:** 12–16 br/min (mean ~14).
- **General adult resting band:** 12–20 br/min.
- **Athletes / very fit individuals:** may sit lower, ~10–12 br/min.

What matters for coaching is the individual's **own nightly baseline and its deviation**, not the absolute number.

## Physiology / mechanism
Breathing rate at rest is set by the brainstem respiratory centres under autonomic and chemoreceptor control (CO₂/O₂ and pH). It rises when metabolic demand, sympathetic drive, or immune/inflammatory activity increases — which is why an infection, fever, stress/anxiety, or cardiac decompensation nudges the overnight rate up before a person notices symptoms. Because the wearable derives RR from the respiratory modulation of the heart-rate/PPG signal during sleep, the number reflects the same autonomic state that HRV and RHR report, and the three tend to move together under illness stress.

## The evidence
- **[Established] Healthy resting/sleep respiratory rate is 12–20 br/min**, with clinical norms long established; RR is a sensitive but "neglected" vital sign whose derangements precede clinical deterioration [Cretikos 2008].
- **[Established] Personal night-to-night stability is high** — a healthy individual's own nightly average varies typically <1 br/min, which is what makes a personal-baseline deviation informative.
- **[Established] A sustained rise above personal baseline is a replicated early signal of acute respiratory infection** (cold, flu, COVID-19): an increase of ~1–3 br/min over baseline often **precedes symptoms**. Pre-symptomatic elevation was typically **~1.5–3 br/min above personal baseline for 1–2 nights before symptom onset** [Mishra 2020; Quer 2021].
- **[Probable] Overnight RR also rises with cardiac decompensation** in patients with heart failure, and with **stress, anxiety, and fever** generally — so the signal is sensitive but non-specific about cause.

## How we compute it
Healthee derives the daily metric **`respiratory_rate_sleep`** — a **bounded window mean** of the overnight respiratory-rate samples across the sleep window (`derive/hrv_spo2_resp.py`; provenance in the implementation section). The interpretive layer computes a **personal nightly baseline** (rolling ~30-day median) and today's deviation from it. Wearable RR is **derived, not directly measured** (typically from HRV/PPG modulation during sleep), so only sleep values are used.

## How the coach uses it
- **Stage 1 (new user / no baseline):** treat RR as informational; explain the healthy 12–16 range and that we need ~2–4 weeks of nights before a personal baseline is trustworthy. Do not act on single nights.
- **Stage 2 (baseline established):** watch the personal-baseline deviation. Surface a **≥2 br/min sustained rise over ≥2 nights** as a possible early illness/recovery signal, especially when it co-occurs with an HRV drop or RHR rise, and suggest lighter activity — framed as "possible early signal," never a diagnosis.
- **Stage 3 (monitoring under load/illness watch):** fold RR into the illness early-warning flag alongside skin temperature; a concordant RR + temp + HRV shift is a stronger prompt to back off than any one alone.
- **Always:** do not interpret a single high-rate night in isolation; name benign confounders (a hot room, a late alcohol/heavy meal, poor sleep) before attributing a rise to illness.

## Safety bounds
- RR is an **early-warning prompt, not a diagnosis**. Never name a specific illness, and never suggest medication, supplements, or a diagnosis.
- A large sustained elevation with fever, breathlessness, chest symptoms, or systemic illness → advise the user to consider a clinician; do not "train through" a suspected infection.

## Honesty & uncertainty
- **Wearable RR is derived, not directly measured** — typically from HRV/PPG modulation during sleep. Accuracy versus capnography is reasonable (**within ~1–2 br/min**) in still adults, but the number is an estimate.
- **Awake / active respiratory rate from wrist sensors is unreliable** — only sleep values are used.
- **Baselines shift by population:** athletes / very fit individuals may have lower baselines (10–12 br/min); **pregnancy and obesity shift baselines upward**.
- The signal is **sensitive but non-specific** — a rise says "something autonomic/metabolic changed," not what.

## Bottom line
**Act on confidently:** the 12–16 (up to 20) br/min normal band; the high personal stability; and a **sustained ≥2 br/min over-baseline rise across two nights (especially with HRV↓/RHR↑) as an early illness signal**.

**Hold loosely:** the exact magnitude/lead-time for a given person; attributing any single elevated night to a specific cause; absolute values (derived, ±1–2 br/min).

## Coach Directives
1. Compute a personal nightly baseline (rolling 30-day median of `respiratory_rate_sleep`); interpret only deviations from it, never absolute values against another person. *(confidence: high)*
2. Surface a **≥2 br/min elevation sustained over 2 nights** — ideally corroborated by an HRV drop or RHR rise — as a *possible early illness/recovery signal*, framed as "consider lighter activity," not a diagnosis. *(high)*
3. Never interpret a single high-rate night in isolation; name benign confounders first. *(high)*
4. **SAFETY:** never name a specific illness or suggest medication/diagnosis; route fever/breathlessness/chest symptoms to "consider a clinician." *(high)*
5. Use sleep values only — never surface awake/active wrist RR. *(high)*

## References
- Mishra T, Wang M, Metwally AA, et al. (2020). *Pre-symptomatic detection of COVID-19 from smartwatch data.* Nature Biomedical Engineering 4:1208–1220. https://doi.org/10.1038/s41551-020-00640-6
- Quer G, Radin JM, Gadaleta M, et al. (2021). *Wearable sensor data and self-reported symptoms for COVID-19 detection.* Nature Medicine 27:73–77. https://doi.org/10.1038/s41591-020-1123-x
- Cretikos MA, Bellomo R, Hillman K, Chen J, Finfer S, Flabouris A. (2008). *Respiratory rate: the neglected vital sign.* Medical Journal of Australia 188(11):657–659. https://doi.org/10.5694/j.1326-5377.2008.tb01825.x

## Healthee implementation & honesty policy
- **Derived field: `respiratory_rate_sleep`** (br/min) in `derived_daily`. Provenance: `derive/hrv_spo2_resp.py::derive_night_vitals` computes a **bounded window mean** of the `respiratory_rate` samples over the sleep window via `_window_stat` with a physiological validity range of **4–40 br/min** (out-of-range/sentinel samples dropped; no row written when the window has no valid RR, so "no data" stays distinct from a real value). Ported **verbatim** from the legacy v2 `derive_night` window-stat blocks — science code, not to be "simplified" on refactor.
- **Raw source:** the per-sample metric is `respiratory_rate`, in `ALLOWED_METRICS`, sampled across the night (awake/active values are never surfaced).
- **Downstream:** `respiratory_rate_sleep` is the lowest-weighted input (**0.10**) to `recovery_score` (`derive/recovery.py`, `RECOVERY_WEIGHTS`), and is one of the two limbs of the **illness early-warning flag** (`illness_flag` table + `read/health_metrics.py::illness_flag_payload`; see `illness_flag_plan`), where a ≥2 br/min sustained rise over the 14-day baseline is the primary trigger.
- **Honesty rules (carry into UI + LLM):** surface RR as a personal-baseline trend, not an absolute value; a rise is a *possible early signal*, never a diagnosis or a named illness; sleep values only.
