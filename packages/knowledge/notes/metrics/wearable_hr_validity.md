---
id: wearable_hr_validity
name: "Wearable HR (PPG) — validity & limits"
topic: Optical wrist HR (PPG) accuracy vs ECG
category: metrics
grade: Established
summary: "Optical wrist/strap HR (PPG) matches ECG within ±2–3 bpm at rest and is reliable for daily resting/sleep HR and personal trends, but degrades badly (10–30 bpm+) in high-intensity/rapid-change exercise, with cold skin/poor perfusion, and across tattoos/dark/hairy skin — and it is never an arrhythmia screen."
aliases: ["hr", "heart rate", "ppg", "optical hr", "wrist hr", "photoplethysmography", "methodology", "accuracy"]
applies_to_metrics: ["rhr_daily", "hr"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
---

# Wearable HR (PPG) — validity & limits

## Summary
Wrist/strap wearables estimate heart rate via photoplethysmography (PPG), not ECG. **At rest and during sleep, PPG HR matches ECG within ±2–3 bpm** and is reliable for daily resting HR, sleep HR, and personal trends. It degrades sharply during **high-intensity exercise with rapid HR changes or wrist movement** (errors of 10–30 bpm or more), with **cold skin / poor perfusion**, and modestly across **tattoos, dark skin pigmentation, and hairy skin** (a documented bias). It is **never a substitute for ECG** and must not be used to screen for arrhythmia.

## What it actually measures
Wrist / strap wearables estimate heart rate via **photoplethysmography (PPG)** — green-light LEDs measure changes in capillary blood volume under the skin. The device infers HR from periodic absorption changes. This is not the same as an ECG, which measures the heart's electrical activity directly.

## Physiology / mechanism
Each heartbeat sends a pulse wave into the capillary bed, transiently increasing blood volume and light absorption; the LED/photodiode pair tracks that pulsatile signal and the algorithm extracts beat timing. Accuracy therefore depends on a clean pulsatile optical signal: good perfusion, minimal motion, and an unobstructed optical path. Rapid HR changes, wrist motion, cold-induced vasoconstriction, and light-absorbing skin features (tattoos, melanin, hair) all corrupt that signal — which is exactly where PPG error is largest, and why the best case is a still wrist at rest or during sleep.

## The evidence
- **[Established] At rest / low motion, PPG HR matches ECG within ~±2–3 bpm mean absolute error** [Bent 2020; Nelson 2019; Wang 2017].
- **[Established] Accuracy degrades during high-intensity exercise, especially with rapid HR changes or wrist movement** — errors can reach **10–30 bpm or more** (lag, motion artefact) [Wang 2017; Bent 2020].
- **[Established] Skin-tone / tattoo / hair effects are real but modest.** Some devices show modestly worse accuracy across tattoos, dark skin pigmentation, and hairy skin — a known and documented bias [Bent 2020].
- **[Established] Cold skin / poor perfusion degrades the PPG signal.**
- **[Established] PPG is not an arrhythmia screen.** In atrial fibrillation or other arrhythmias, optical HR can miss beats or smooth out irregularity; it is not a substitute for ECG. **Absolute HRV from PPG** is also less accurate than ECG-derived HRV (see `hrv_recovery_marker`).

## How we compute it
Healthee uses the raw `hr` samples to derive **`rhr_daily`** (sleeping resting HR; see `resting_heart_rate`) and to anchor HR-based zone/effort calculations (`max_hr_daily` — currently the inline Tanaka ceiling; see `maximum_heart_rate`). All of these live in PPG's **best-case** regime (rest, sleep) or use HR only as a personal trend, which is where the sensor is trustworthy.

## How the coach uses it
- **Stage 1:** trust HR for **personal trends** and **sleep/rest contexts**; explain that exercise peak HR from the wrist is approximate, and lean on RPE for intensity.
- **Stage 2:** use resting/sleep HR and its personal baseline for recovery reads; treat any single hard-session peak HR as approximate, not a precise measurement.
- **Stage 3:** prefer a chest strap when a precise exercise or peak HR matters (e.g. ratcheting HRmax); down-weight wrist peaks recorded under motion, cold, or poor fit.
- **Always:** never use wearable HR to diagnose arrhythmia or recommend a medication change.

## Safety bounds
- **Never use wearable HR to diagnose arrhythmia or recommend a medication change** — it is not an ECG and can miss or smooth irregular beats.
- Peak HR during exercise is **approximate**; never present it as a precise measurement or a basis for a clinical decision.

## Honesty & uncertainty
- **The Helio Strap is a newer device with no published independent validation** we are aware of; the estimates above are extrapolated from comparable wrist PPG devices.
- **Validation studies are typically in younger, healthy, lighter-skinned populations;** performance in other groups is less well characterised.
- Absolute HRV from PPG is less accurate than ECG-derived HRV; use it as a trend, not an absolute (see `hrv_recovery_marker`).

## Bottom line
**Act on confidently:** PPG HR at rest/sleep (±2–3 bpm) and as a personal trend; using it for `rhr_daily` and recovery reads.

**Hold loosely:** exercise peak HR (approximate, 10–30 bpm+ error under motion); accuracy across tattoos/dark/hairy skin and cold extremities; anything approaching arrhythmia detection or absolute PPG HRV.

## Coach Directives
1. Use wearable HR for **personal trends and sleep/rest contexts**, where accuracy is high. *(confidence: high)*
2. Treat exercise/peak HR as **approximate**, not a precise measurement; prefer a chest strap when precision matters. *(high)*
3. **SAFETY:** never use wearable HR to diagnose arrhythmia or recommend a medication change. *(high)*
4. Acknowledge reduced reliability under motion, cold/poor perfusion, and across tattoos/dark/hairy skin; note the strap lacks independent validation. *(high)*

## References
- Bent B, Goldstein BA, Kibbe WA, Dunn JP. (2020). *Investigating sources of inaccuracy in wearable optical heart rate sensors.* npj Digital Medicine 3:18. https://doi.org/10.1038/s41746-020-0226-6
- Nelson BW, Allen NB. (2019). *Accuracy of consumer wearable heart rate measurement during an ecologically valid 24-hour period: intraindividual validation study.* JMIR mHealth and uHealth 7(3):e10828. https://doi.org/10.2196/10828
- Wang R, Blackburn G, Desai M, et al. (2017). *Accuracy of wrist-worn heart rate monitors.* JAMA Cardiology 2(1):104–106. https://doi.org/10.1001/jamacardio.2016.3340

## Healthee implementation & honesty policy
- **Raw metric: `hr`** (bpm) in `ingest/models.py::ALLOWED_METRICS`, sampled continuously. It is not itself a `derived_daily` row; it feeds `rhr_daily` (`derive/rhr.py`, sleeping 5-min-rolling minimum) and the inline Tanaka `max_hr_daily` ceiling used by `derive/cardio_load.py` / `derive/gps.py`. HR is consumed in PPG's reliable regime (rest/sleep) or only as a personal trend.
- **Honesty rules (carry into UI + LLM):** surface HR as a rest/sleep value or a personal trend; never present a wrist exercise/peak HR as precise; never diagnose arrhythmia or suggest a medication change; acknowledge the strap has no independent validation and that accuracy drops under motion, cold, and across tattoos/dark/hairy skin.
