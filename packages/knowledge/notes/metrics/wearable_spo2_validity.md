---
id: wearable_spo2_validity
name: "Wearable SpO2 — validity & limits"
topic: Wrist optical SpO2 accuracy and limits
category: metrics
grade: Established
summary: "Wrist optical SpO2 is trustworthy as a multi-night personal trend and for spotting clearly abnormal (<90%) values, but not for absolute precision (the true error is unquantified and at least ±3.5% — see #98), single low readings, sleep-apnea diagnosis, or across dark skin pigmentation (documented bias)."
aliases: ["spo2", "SpO2", "blood oxygen", "oxygen saturation", "pulse oximetry", "wrist oximetry", "ppg spo2", "methodology", "accuracy"]
applies_to_metrics: ["spo2_overnight", "spo2_overnight_min"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
---

# Wearable SpO2 — validity & limits

## Summary
Wrist SpO2 estimates blood-oxygen saturation optically at the skin. It can be **trusted as a personal trend across multiple nights**, for flagging **clearly abnormal** values (sustained <90%), and for **relative** comparisons against the user's own median — but **not** for absolute precision (the Helio Strap's error against an arterial reference is **unquantified and at least ±3.5%** — it is not a cleared oximeter and has no published validation; see *The evidence* for why the familiar "±2–3% RMSE" was withdrawn in #98), single low readings, sleep-apnea diagnosis, or fairly across dark skin pigmentation, where a documented overestimation bias exists. Surface it as a multi-night trend that can prompt a clinical evaluation, never as a diagnosis.

## What it actually measures
Wrist SpO2 uses **two-wavelength optical sensing** (red + infrared LEDs) at the skin to estimate the ratio of oxygenated to deoxygenated haemoglobin in capillary blood. Clinical pulse oximeters use the same principle but typically at the **fingertip**, where perfusion is higher and motion is lower — which is why finger devices are more accurate than a wrist sensor.

## Physiology / mechanism
Oxygenated and deoxygenated haemoglobin absorb red and infrared light differently; the device infers the saturation ratio from the pulsatile (arterial) component of that absorption. Accuracy therefore depends on good perfusion and a clean pulsatile signal — anything that reduces peripheral blood flow or corrupts the optical path (cold extremities, motion, loose fit, skin pigmentation) degrades the estimate. Skin pigmentation is not neutral: melanin absorbs light and biases the red/infrared ratio, which is the mechanism behind the documented overestimation of SpO2 in darker skin.

## The evidence
- **[Established] Optical SpO2 overestimates saturation in darker skin pigmentation.** Documented in the clinical pulse-oximeter literature and broadly applicable to optical SpO2 devices — occult hypoxaemia (arterial <88% despite a device reading ≥92%) occurred far more often in patients with darker skin [Sjoding 2020].
- **[Probable] Consumer wrist SpO2 shows only modest agreement with clinical oximetry, degrading at lower saturations.** A comparison of Apple Watch vs conventional commercial oximeters in lung-disease patients found modest agreement in the healthy range that **degrades at lower SpO2** [Pipek 2021].
- **[Established, methodology] Absolute precision is limited — but the "±2–3% RMSE" figure was mis-attributed, corrected 2026-08-01 (#98).** This bullet used to read "FDA accuracy claims for consumer wrist SpO2 are commonly ±2–3% root-mean-square error". That is wrong in the part that matters: **the FDA accuracy bar applies to *cleared medical pulse oximeters*, not to consumer wellness wearables** like the Helio Strap, which are not cleared as oximeters and are subject to no accuracy requirement at all. The actual FDA figure is an accuracy root-mean-square (A_rms) of **≤3.0% for transmittance and ≤3.5% for reflectance** devices over SpO2 70–100%; a wrist sensor is reflectance, the looser of the two. The January 2025 draft guidance tightened the *validation study* (cohort 10 → 150 participants, ≥25% with dark skin, 200 → 3,000 data points) precisely because the old bar was not delivering equitable accuracy [FDA 2025 draft guidance]. **So: ±2–3% is not a claim anyone has made about this device; ≥±3.5% is the floor a device would have to beat merely to be a cleared reflectance oximeter, and no independent validation of the Helio Strap exists.** Treat the true error as unknown and at least that large.

## How we compute it
Healthee derives **`spo2_overnight`** (a bounded window mean of the overnight SpO2 samples) and **`spo2_overnight_min`** (the overnight minimum), both over the sleep window (`derive/hrv_spo2_resp.py`; provenance below). The interpretive layer compares each night against the user's own multi-night median rather than an absolute cutoff.

## How the coach uses it
- **Stage 1 (no baseline):** treat SpO2 as informational; do not alarm on single readings. Explain that wrist SpO2 is a trend tool, not a medical oximeter.
- **Stage 2 (baseline established):** watch the multi-night trend. If **nightly SpO2 minimum drops below ~92% across several nights**, surface it and recommend a **clinical evaluation** — explicitly not a diagnosis.
- **Stage 3:** a persistent downward trend in average nightly SpO2 is worth investigating with a clinician; the app may surface a *suspicion* worth a formal sleep study, nothing more.
- **Always:** never call out individual low-reading minutes (most are sensor artefacts); interpret only sustained, multi-night patterns.

## Safety bounds
- **Wrist SpO2 cannot diagnose or grade obstructive sleep apnea** — it may surface a *suspicion* worth a clinical sleep study, nothing more.
- A sustained low trend routes to "consider a clinical evaluation"; the app never diagnoses, prescribes, or reassures away a genuinely low sustained reading.

## Honesty & uncertainty
- **Absolute values cannot be trusted, and we do not know by how much.** The "±2–3% RMSE" this note used to quote was the *cleared-medical-oximeter* bar mis-attributed to a consumer wearable (#98); the applicable FDA figure for a reflectance device is ≤3.5% A_rms, and the Helio Strap is not a cleared oximeter and has no published validation, so its error is unquantified and at least that large.
- **The ~92% routing threshold is a clinical convention, not a wearable-validated cutoff (#98).** ~90% SpO2 is the long-standing clinical hypoxaemia line because it sits at the shoulder of the oxyhaemoglobin dissociation curve (≈PaO2 60 mmHg), below which small saturation drops mean large PaO2 drops; ~92% is the usual caution margin above it. **We could source no wearable-specific threshold at all.** Given the unquantified device error above, a *displayed* 92% could correspond to a genuinely normal or a genuinely low arterial value — which is exactly why the directive routes to a clinician and never reassures, diagnoses, or acts on the number itself.
- **Single low readings are unreliable** — motion, cold, dark skin pigmentation, poor sensor contact, and low perfusion all generate spurious low readings.
- **Dark-skin bias is real** and shared by consumer wrist devices [Sjoding 2020].
- **The Helio Strap has no published independent validation** we are aware of; inferences here come from the PPG-SpO2 literature on similar devices. Older consumer wrist SpO2 implementations (pre-2020) were less accurate; newer firmware does not always carry independent validation.
- Most validation studies are in **healthy populations at normal-range SpO2 (95–100%)**; accuracy at the clinically interesting range (**<92%**) is less well characterised for consumer devices.

## Bottom line
**Act on confidently:** SpO2 as a **multi-night personal trend**; flagging **clearly abnormal** sustained values (<90–92%) for clinical follow-up; relative comparison vs the user's own median.

**Hold loosely:** any absolute value; any single reading; **any night-to-night difference smaller than the device's own error, which is unquantified and at least ±3.5%** (#98 — the "sub-2%" this line used to give was the withdrawn figure restated as a resolution); anything approaching a sleep-apnea diagnosis; accuracy across dark skin or below 92%.

## Coach Directives
1. Surface SpO2 as a **trend over multiple nights**, never a single-reading alarm. *(confidence: high)*
2. Flag a **sustained nightly-minimum drop below ~92% across several nights** and recommend a **clinical evaluation — not a diagnosis**. The ~92% figure is a **clinical convention** (the ~90% hypoxaemia line plus a caution margin), **not a wearable-validated cutoff** — none is sourced (#98). Present it as a reason to get checked, never as a measurement of the owner's oxygenation. *(high)*
3. Never call out individual low-reading minutes (most are sensor artefacts). *(high)*
4. Never present wrist SpO2 as a sleep-apnea diagnosis; at most surface a suspicion worth a clinical sleep study. *(high)*
5. Acknowledge reduced reliability for single readings and for darker skin pigmentation, and say that the device's absolute error is **unquantified and at least ±3.5%** rather than quoting a precision figure. **Never state "±2–3%" or "sub-2%"** — that was the cleared-medical-oximeter bar mis-attributed to this wearable, withdrawn in #98, and it makes the strap sound more precise than the evidence allows. *(high)*

## References
- Sjoding MW, Dickson RP, Iwashyna TJ, Gay SE, Valley TS. (2020). *Racial bias in pulse oximetry measurement.* New England Journal of Medicine 383(25):2477–2478. https://doi.org/10.1056/NEJMc2029240
- Pipek LZ, Nascimento RFV, Acencio MMP, Teixeira LR. (2021). *Comparison of SpO2 and heart rate values on Apple Watch and conventional commercial oximeters devices in patients with lung disease.* Scientific Reports 11:18901. https://doi.org/10.1038/s41598-021-98453-3
- U.S. Food and Drug Administration. *Pulse Oximeters for Medical Purposes — Non-Clinical and Clinical Performance Testing, Labeling, and Premarket Submission Recommendations.* Draft guidance, January 2025. Source of the A_rms ≤3.0% (transmittance) / ≤3.5% (reflectance) accuracy bar and the enlarged validation-cohort recommendations. **Applies to oximeters cleared for medical purposes — explicitly not to general-wellness wearables** (#98). https://www.fda.gov/regulatory-information/search-fda-guidance-documents

## Healthee implementation & honesty policy
- **Derived fields: `spo2_overnight` and `spo2_overnight_min`** (%) in `derived_daily`. Provenance: `derive/hrv_spo2_resp.py::derive_night_vitals` computes a **bounded window mean** of the `spo2` samples over the sleep window via `_window_stat` bounded to a physiological **70–100%**, and additionally the window **MIN** as `spo2_overnight_min`. Out-of-range/sentinel samples are dropped and no row is written when the window has no valid SpO2 (so "no data" stays distinct from a real value). Ported **verbatim** from the legacy v2 `derive_night` blocks — science code, not to be "simplified" on refactor.
- **Raw source:** the per-sample metric is `spo2` (in `ALLOWED_METRICS`), sampled across the night.
- **Honesty rules (carry into UI + LLM):** report SpO2 as a multi-night personal trend and only flag sustained sub-~92% minimums for *clinical follow-up*; never diagnose sleep apnea; never alarm on a single minute; acknowledge the dark-skin bias and say that the absolute error is **unquantified and at least ±3.5%** (#98). This rule used to instruct the coach to state "±2–3%" — the withdrawn figure, in the one place that told the model to repeat it.
