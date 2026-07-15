---
id: wearable_hr_validity
topic: Optical wrist HR (PPG) accuracy vs ECG
evidence_grade: 3
applies_to_metrics: [hr, rhr_daily, max_hr_daily]
applies_to_interventions: []
tags: [methodology, hr, ppg, accuracy]
last_reviewed: 2026-05-11
---

## What it actually measures
Wrist / strap wearables estimate heart rate via **photoplethysmography (PPG)** —
green-light LEDs measure changes in capillary blood volume under the skin. The
device infers HR from periodic absorption changes. This is not the same as an
ECG, which measures the heart's electrical activity directly.

## What we can trust
- **At rest, low motion**: PPG HR matches ECG within ±2–3 bpm mean absolute error.
- **Trends and personal baselines**: the within-individual signal (today vs your own median) is reliable.
- **Daily resting HR** and **sleep HR** are reliable enough for personal trend analysis.

## What we can't trust
- **High-intensity exercise, especially with rapid HR changes or wrist movement**: errors can reach 10–30 bpm or more (lag, motion artifact).
- **Cold skin / poor perfusion**: PPG signal degrades.
- **Tattoos, dark skin pigmentation, hairy skin**: some devices show modestly worse accuracy in these populations; this is a known and documented bias.
- **Atrial fibrillation or arrhythmias**: optical HR can miss beats or smooth out irregularity; not a substitute for ECG screening.
- **Absolute HRV from PPG**: less accurate than ECG-derived HRV (see `hrv_recovery_marker`).

## Evidence strength
- Bent B, Goldstein BA, Kibbe WA, Dunn JP. **"Investigating sources of inaccuracy in wearable optical heart rate sensors."** *npj Digital Medicine* 2020;3:18. Compared 6 wrist wearables to ECG across n ≈ 53; documented accuracy at rest and during activity, plus skin-tone effects.
- Nelson BW, Allen NB. **"Accuracy of consumer wearable heart rate measurement during an ecologically valid 24-hour period: intraindividual validation study."** *JMIR mHealth and uHealth* 2019;7(3):e10828.
- Wang R et al. **"Accuracy of wrist-worn heart rate monitors."** *JAMA Cardiology* 2017;2(1):104–106. Compared Apple Watch / Fitbit / Mio to ECG.

## Caveats
- Helio Strap is a newer device with no published independent validation we're aware of. Estimates above are extrapolated from comparable wrist PPG devices.
- Validation studies are typically in younger, healthy, lighter-skinned populations; performance in other groups is less well characterized.

## Operational use
- Use HR for **personal trends** and **sleep/rest contexts**, where accuracy is high.
- Do **not** use peak HR during exercise as a precise measurement — treat it as approximate.
- Never use wearable HR to diagnose arrhythmia or recommend medication change.
- Cite this note when explaining what wearable HR can and can't tell us.
