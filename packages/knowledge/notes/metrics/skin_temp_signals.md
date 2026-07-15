---
id: skin_temp_signals
topic: Wrist skin temperature — what it does and doesn't track
evidence_grade: 2
applies_to_metrics: [skin_temp_c]
applies_to_interventions: []
tags: [methodology, temperature, accuracy]
last_reviewed: 2026-05-11
---

## What it actually measures
Wrist sensors measure **skin temperature**, not **core body temperature**.
Skin temperature is influenced by ambient temperature, peripheral
vasoconstriction/dilation, posture, sleep position, clothing, and bedding —
sometimes more than by core temperature.

## What we can trust
- **Personal-baseline deviations during sleep** (when the user is relatively still and consistently positioned). Many cycle-tracking, illness-prediction, and ovulation-detection wearable validations use the **overnight delta** from personal median.
- **Multi-day directional shifts**: a ~0.3–0.5 °C sustained elevation over several nights may correlate with infection or hormonal changes.

## What we can't trust
- **Absolute values** as a thermometer.
- **Single-night readings** as fever indicators.
- **Day-time readings** for any kind of fever or illness detection — too much environmental noise.

## Evidence strength
- Mason AE, Hecht FM, Davis SK, et al. **"Detection of COVID-19 using multimodal data from a wearable device: results from the first TemPredict study."** *Scientific Reports* 2022;12:3463. Demonstrated that wrist temperature combined with HRV improves illness detection over either alone.
- Cycle-tracking literature using wearable skin temperature: multiple replication studies (Goodale et al. 2019, Maijala et al. 2019) confirm overnight skin temperature shifts track ovulation in healthy menstrual cycles. **Evidence is moderate ★★** for this specific use.
- Note: Helio Strap is not specifically validated; inferences are from broader wrist-temperature literature.

## Caveats
- **Evidence grade is ★★ (moderate), not ★★★.** The strongest evidence is for delta-from-baseline detection of illness or cycle phase, not absolute measurement.
- Wrist temperature is **not** a substitute for an oral or tympanic thermometer.
- Many factors (room temperature, blankets, sleep posture) confound the reading; large day-to-day variation is expected even in healthy state.

## Operational use
- Use as a **personal-baseline deviation** signal, computed over sleep windows only.
- A sustained 2σ+ elevation over 2–3 consecutive nights warrants the user checking other signs (subjective illness, RHR, HRV drop, congestion).
- Do **not** report individual temperature values as health indicators.
- Honestly label this as moderate-evidence (★★) when surfacing to user.
