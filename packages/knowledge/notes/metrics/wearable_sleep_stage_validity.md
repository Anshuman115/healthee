---
id: wearable_sleep_stage_validity
name: "Wearable sleep-stage scoring — validity & limits"
topic: Wrist/strap sleep stage scoring vs polysomnography
category: metrics
grade: Established
evidence_grade: 3
summary: "Wearables score sleep from accelerometry + PPG + HRV, not EEG; trust total sleep time, bedtime/wake, and asleep-vs-awake (agree well with PSG) and directional stage trends, but not single-night exact stage values (κ ≈ 0.3–0.6), over-estimated deep sleep, error-prone REM, or the proprietary sleep score's absolute number."
aliases: ["sleep_stage", "sleep staging", "sleep stages", "deep sleep", "rem sleep", "light sleep", "sleep score", "polysomnography", "psg", "methodology", "accuracy"]
applies_to_metrics: ["sleep_health_score_4dim"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
---

# Wearable sleep-stage scoring — validity & limits

## Summary
Consumer wearables estimate sleep stages from accelerometry + optical HR (PPG) + HRV, running proprietary algorithms that approximate polysomnography (PSG). **Total sleep time, bedtime/wake time, and asleep-vs-awake classification agree well with PSG**, as do **directional** stage trends over time. But **single-night exact stage values are unreliable** (~60–70% epoch-level agreement, Cohen's κ ≈ 0.3–0.6), **deep sleep is over-estimated**, **REM is the most error-prone stage**, and the **sleep score is a proprietary composite** whose absolute value carries less information than its components. Trust the coarse structure and personal trends; surface stage detail directionally, not as exact minutes.

## What it actually measures
Consumer wearables (including Huami / Zepp OS devices) estimate sleep stages from **accelerometry + optical HR (PPG) + HRV**. They run proprietary algorithms that approximate polysomnography (PSG) — the clinical gold standard, which uses EEG, EOG, EMG, and respiratory signals.

This is a **fundamentally different measurement** than PSG. The proxies are real (HRV does shift across stages, movement does drop), but they cannot directly observe brain state.

## Physiology / mechanism
Sleep stages are defined electrophysiologically (EEG/EOG/EMG), but they have autonomic and motor correlates a wrist device can sense: movement falls in deeper sleep, heart rate and HRV shift across NREM/REM, and breathing regularity changes. Wearable algorithms infer stages from these proxies. The inference is genuine but indirect — it captures the *direction* and *coarse structure* of sleep well, while the fine, epoch-by-epoch stage boundaries (especially REM vs light, and the amount of deep sleep) are where the proxy diverges from EEG truth.

## The evidence
- **[Established] Asleep-vs-awake and total sleep time agree well with PSG.** Across seven consumer devices vs PSG, wearables detect sleep vs wake and total sleep time most reliably [Chinoy 2021].
- **[Established] Bedtime and wake time are usually within minutes of PSG-determined values** [Chinoy 2021; Berryhill 2020].
- **[Probable] Single-night exact stage values are only fair-to-moderate.** Studies report ~60–70% epoch-level agreement with PSG for sleep stages, with **Cohen's κ often 0.3–0.6** [Chinoy 2021].
- **[Established] Deep sleep duration is over-estimated by wrist wearables** (consistent across multiple device families), and **REM duration is the most error-prone individual stage**.
- **[Probable] The sleep score is a proprietary composite** — its specific value carries less information than the underlying components.
- **[Established] Directional changes do show up** (e.g. alcohol → less deep, illness → more wake), and **within-individual trends** in stage proportions over weeks/months are usable [Chinoy 2021; Berryhill 2020].

## How we compute it
Healthee reads bedtime/wake, total sleep time, and asleep-vs-awake from the strap's session data (PPG's reliable regime) and derives the composite **`sleep_health_score_4dim`** from those (see the sleep-score note). Per-stage minutes (deep/REM/light/awake) come from the **strap's own staging** surfaced at read time — used directionally and as personal-baseline deviations, never as exact clinical values. v2 does not re-derive per-stage daily metrics.

## How the coach uses it
- **Stage 1:** trust and use **total sleep time, bedtime, wake time, and asleep-vs-awake**; explain that per-stage minutes are estimates.
- **Stage 2:** use **stage breakdowns directionally** ("your deep sleep dropped ~30% on alcohol nights" is fine; "you got exactly 44 minutes of deep sleep" is over-stated); surface deep/REM as **personal-baseline deviations**, not absolute health claims.
- **Stage 3:** track stage proportions as personal trends over weeks/months; watch firmware version when comparing across long periods (an algorithm update can change values without any physiological change).
- **Always:** treat the sleep score as a personal trend, not an absolute number with clinical meaning.

## Safety bounds
- **Wearable sleep staging is not a clinical measurement** and must never be used to diagnose a sleep disorder; a persistent concern routes to a clinical sleep study.
- Never present an exact stage duration or the sleep score as a clinical/health verdict.

## Honesty & uncertainty
- **Single-night exact stage values cannot be trusted** (κ ≈ 0.3–0.6; ~60–70% epoch agreement); **deep sleep is over-estimated** and **REM is the most error-prone stage**.
- **The sleep score is a proprietary composite** — surface it as a personal trend, not an absolute number.
- **The Helio Strap specifically has no published independent validation** we are aware of; estimates are from devices with broadly similar sensor stacks.
- **Cohen's κ varies considerably by population** (poorer in older adults and people with sleep disorders).
- **Algorithmic/firmware updates can change measured values without any change in physiology** — watch the firmware version when comparing across long periods.

## Bottom line
**Act on confidently:** total sleep time, bedtime, wake time, asleep-vs-awake, and **directional** stage/score trends over time.

**Hold loosely:** single-night exact stage minutes (fair-to-moderate agreement); deep-sleep amount (over-estimated); REM duration (error-prone); the sleep score's absolute value; cross-firmware comparisons.

## Coach Directives
1. Trust **total sleep time, bedtime, wake time, and asleep-vs-awake** classification. *(confidence: high)*
2. Use **stage breakdowns directionally** and as personal-baseline deviations, never as exact minutes or absolute health claims. *(high)*
3. Treat the **sleep score as a personal trend**, not an absolute number with clinical meaning. *(high)*
4. Watch firmware version across long comparisons (algorithm updates shift values without physiology change); note the strap lacks independent validation. *(high)*
5. **SAFETY:** never diagnose a sleep disorder from wearable staging; route persistent concerns to a clinical sleep study. *(high)*

## References
- Chinoy ED, Cuellar JA, Huwa KE, et al. (2021). *Performance of seven consumer sleep-tracking devices compared with polysomnography.* Sleep 44(5):zsaa291. https://doi.org/10.1093/sleep/zsaa291
- Berryhill S, Morton CJ, Dean A, et al. (2020). *Effect of wearables on sleep in healthy individuals: a randomized cross-over trial and validation study.* Journal of Clinical Sleep Medicine 16(5):775–783. https://doi.org/10.5664/jcsm.8356
- Robbins R, Affouf M, Weaver MD, et al. (2020). *Estimated sleep duration before and during the COVID-19 pandemic in major metropolitan areas on different continents: observational study of smartphone app data.* Journal of Medical Internet Research 22(2):e20546. https://doi.org/10.2196/20546

## Healthee implementation & honesty policy
- **Derived field: `sleep_health_score_4dim`** in `derived_daily` (`derive/sleep_score.py`) — Healthee's own composite over the strap's reliable measurements (total sleep time, timing, asleep-vs-awake); its methodology lives in the sleep-score research note. Per-stage minutes (deep/REM/light/awake) are surfaced from the **strap's own staging** at read time (e.g. `read/sleep_page.py`), used directionally only. v2 deliberately does **not** re-derive per-stage daily metrics (the v1 `sleep_light_min` / `sleep_deep_min` / `sleep_awake_min` / raw `sleep_score` names are retired; see `analytics/metrics.py`).
- **Honesty rules (carry into UI + LLM):** trust total sleep time, bedtime, wake, and asleep-vs-awake; present stage detail directionally and as personal-baseline deviations, never exact minutes or clinical values; the score is a personal trend; note the strap lacks independent validation and that firmware updates can move values without any physiological change.
