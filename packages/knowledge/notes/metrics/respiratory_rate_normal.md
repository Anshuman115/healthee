---
id: respiratory_rate_normal
topic: Respiratory rate during sleep — normal ranges and what shifts mean
evidence_grade: 3
applies_to_metrics: [respiratory_rate_sleep]
applies_to_interventions: []
tags: [respiratory_rate, sleep, autonomic]
last_reviewed: 2026-05-11
---

## Finding
Resting (and sleep) respiratory rate in healthy adults is consistently **12–20
breaths per minute**, with most healthy adults sitting in the **12–16** range
during deep sleep. Personal stability is high: a healthy individual's own
nightly average varies by typically <1 breath/min night-to-night.

Shifts above personal baseline have been replicated as early signals of:
1. **Acute respiratory infection** (cold, flu, COVID-19) — increase of 1–3 br/min over baseline often precedes symptoms.
2. **Cardiac decompensation** in patients with heart failure.
3. **Stress, anxiety, fever** in general.

## Effect size
- Healthy nocturnal baseline: 12–16 br/min (mean ~14).
- Pre-symptomatic infection: typically ~1.5–3 br/min above personal baseline for 1–2 nights before symptom onset (Mishra et al. 2020, Quer et al. 2021).

## Evidence strength
- Mishra T, Wang M, Metwally AA, et al. **"Pre-symptomatic detection of COVID-19 from smartwatch data."** *Nature Biomedical Engineering* 2020;4:1208–1220. Documented respiratory rate elevation pre-symptom.
- Quer G, Radin JM, Gadaleta M, et al. **"Wearable sensor data and self-reported symptoms for COVID-19 detection."** *Nature Medicine* 2021;27:73–77.
- Cretikos MA, Bellomo R, Hillman K, Chen J, Finfer S, Flabouris A. **"Respiratory rate: the neglected vital sign."** *Medical Journal of Australia* 2008;188(11):657–659. Established clinical norms.

## Caveats
- Wearable respiratory rate is **derived**, not directly measured — typically from HRV / PPG modulation during sleep. Accuracy versus capnography is reasonable (within ~1–2 br/min) in still adults.
- Awake / active respiratory rate from wrist sensors is unreliable; we only use sleep values.
- Athletes / very fit individuals may have lower baselines (10–12 br/min).
- Pregnancy and obesity shift baselines upward.

## Operational use
- Compute personal nightly baseline (rolling 30-day median).
- A 2-night sustained elevation of ≥2 br/min over personal baseline, especially paired with HRV drop or RHR rise, is worth surfacing as a possible early illness signal.
- Do **not** interpret single high-rate nights in isolation.
- Cite this note when discussing respiratory rate.
