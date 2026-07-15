---
id: skin_temp_signals
name: "Skin Temperature (overnight)"
topic: Wrist skin temperature — what it does and doesn't track
category: metrics
grade: Probable
evidence_grade: 2
summary: "Wrist sensors measure skin (not core) temperature; the trustworthy signal is a personal-baseline overnight deviation (a sustained ~0.3–0.5°C / 2σ rise over 2–3 nights can flag illness or cycle phase), never an absolute thermometer reading — moderate evidence (★★)."
aliases: ["skin_temp_c", "skin temperature", "wrist temperature", "temperature", "temp", "overnight temperature", "methodology", "accuracy"]
applies_to_metrics: ["skin_temp_c"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
---

# Skin Temperature (overnight)

## Summary
Wrist sensors measure **skin temperature, not core body temperature**. The only trustworthy use is a **personal-baseline deviation during sleep**: a sustained ~0.3–0.5°C (or ≥2σ) rise over 2–3 consecutive nights can correlate with infection or hormonal (cycle) changes, and is strongest as one limb of a multi-signal illness flag. It is **not** a thermometer — absolute values, single nights, and any daytime reading are too noisy to act on. This is **moderate evidence (★★)**, and must be labelled as such.

## What it actually measures
Wrist sensors measure **skin temperature**, which is influenced by ambient temperature, peripheral vasoconstriction/dilation, posture, sleep position, clothing, and bedding — **sometimes more than by core temperature**. It is a peripheral proxy, not a core-temperature readout.

## Physiology / mechanism
Skin temperature reflects the balance between core heat delivery (via skin blood flow) and heat loss to the environment. Overnight, when the person is still, consistently positioned, and the environment is relatively stable, skin temperature tracks the vasomotor and thermoregulatory state more faithfully — which is why illness (fever/inflammatory vasodilation) and the luteal-phase progesterone rise both show up as an **overnight delta from the personal median**. During the day, environmental and postural noise swamps this signal.

## The evidence
- **[Probable] Overnight wrist temperature improves illness detection when combined with HRV.** The first TemPredict study demonstrated that wrist temperature combined with HRV **improves illness detection over either alone** [Mason 2022].
- **[Probable] Overnight skin-temperature shifts track ovulation in healthy menstrual cycles.** Multiple replication studies confirm that overnight skin temperature tracks ovulation [Goodale 2019; Maijala 2019]. Evidence is **moderate (★★)** for this specific use.
- **[Probable] A sustained ~0.3–0.5°C elevation over several nights** may correlate with infection or hormonal changes — as a personal-baseline delta, not an absolute value.

## How we compute it
Skin temperature is read as **`skin_temp_c`** — averaged over the sleep window at read time from the raw overnight samples (`read/sleep_extras.py` / `read/sleep_page.py`; provenance below). The illness/recovery logic uses a **personal-baseline overnight deviation** (median ± MAD over a 14-day window), never an absolute threshold.

## How the coach uses it
- **Stage 1 (no baseline):** informational only. Explain it is a skin (not core) reading and needs ~2 weeks of nights before a baseline is meaningful; never report an absolute value as a health indicator.
- **Stage 2 (baseline established):** watch the overnight deviation. A **sustained ≥2σ elevation over 2–3 consecutive nights** warrants the user checking other signs (subjective illness, RHR rise, HRV drop, congestion) — as the weaker limb of the illness flag, with respiratory rate the stronger lever.
- **Stage 3:** fold temperature into the illness early-warning flag; a concordant temp + RR + HRV shift is a stronger recovery prompt than temperature alone.
- **Always:** label the signal as **moderate evidence (★★)** when surfacing it, and never report individual temperature values as health indicators.

## Safety bounds
- **Wrist temperature is not a substitute for an oral or tympanic thermometer** and must never be presented as a fever measurement.
- A sustained elevation is a *prompt to check other signs / consider recovery*, never a diagnosis or a medication cue.

## Honesty & uncertainty
- **Evidence grade is ★★ (moderate), not ★★★.** The strongest evidence is for **delta-from-baseline** detection of illness or cycle phase, not absolute measurement.
- **Absolute values cannot be trusted** as a thermometer; **single-night readings** are not fever indicators; **daytime readings** are useless for fever/illness detection (too much environmental noise).
- **Many factors confound the reading** — room temperature, blankets, sleep posture — so **large day-to-day variation is expected even in a healthy state**.
- **Cycle-tracking confound:** in menstruating users, skin temperature rises ~0.3–0.5°C in the luteal phase, so skin temp alone is not a strong illness signal mid-cycle (respiratory rate is the stronger lever); this is not solvable without cycle tracking.
- **The Helio Strap is not specifically validated;** inferences are from the broader wrist-temperature literature.

## Bottom line
**Act on confidently:** skin temperature as a **personal-baseline overnight deviation** (sustained 2σ / ~0.3–0.5°C over 2–3 nights) as a *supporting* illness/cycle signal, labelled moderate evidence.

**Hold loosely:** absolute values; single nights; daytime readings; skin temp as a standalone illness signal (weaker than RR); anything resembling a fever measurement.

## Coach Directives
1. Use skin temperature only as a **personal-baseline deviation over sleep windows**, never as an absolute value. *(confidence: moderate)*
2. Surface a **sustained ≥2σ (or ~0.3–0.5°C) elevation over 2–3 consecutive nights** as a supporting recovery/illness prompt (with RR/HRV/RHR), not a diagnosis. *(moderate)*
3. Never report individual temperature values as health indicators, and never present wrist temperature as a fever/thermometer reading. *(high)*
4. Label this signal as **moderate evidence (★★)** when surfacing it, and name the cycle/ambient confounds. *(high)*

## References
- Mason AE, Hecht FM, Davis SK, et al. (2022). *Detection of COVID-19 using multimodal data from a wearable device: results from the first TemPredict study.* Scientific Reports 12:3463. https://doi.org/10.1038/s41598-022-07314-0
- Goodale BM, Shilaih M, Falco L, Dammeier F, Hamvas G, Leeners B. (2019). *Wearable sensors reveal menstrual-cycle phase and pregnancy through modulation of core body temperature.* (Cycle-tracking skin-temperature validation.)
- Maijala A, Kinnunen H, Koskimäki H, Jämsä T, Kangas M. (2019). *Nocturnal finger skin temperature in menstrual cycle tracking.* BMC Women's Health 19:150.

## Healthee implementation & honesty policy
- **Metric: `skin_temp_c`** (°C) — a raw per-sample metric (in `ingest/models.py::ALLOWED_METRICS`) surfaced by averaging over the sleep window at **read time** (`read/sleep_extras.py`, `read/sleep_page.py` — `AVG(skin_temp_c)` over the night, filtered to plausible values, e.g. `value>25`). It is not a `derive/` `_upsert_daily` daily metric; the analysis uses the overnight average and its personal-baseline delta.
- **Downstream:** `skin_temp_c` is the weaker limb of the **illness early-warning flag** (`illness_flag` table + `read/health_metrics.py::illness_flag_payload`; see `illness_flag_plan`), where a sustained ≥0.5°C rise over the 14-day median contributes to the flag — with respiratory rate the stronger, primary limb.
- **Honesty rules (carry into UI + LLM):** always label as **moderate evidence (★★)**; report only personal-baseline overnight deltas, never absolute values; never present as a fever/thermometer reading; name the luteal-phase and ambient-temperature confounds.
