---
id: wearable_stress_validity
name: "Wearable stress scores — validity & limits"
topic: Consumer wearable "stress" 0–100 scores — what they index and what they don't
category: metrics
grade: Probable
summary: "Consumer 'stress' 0–100 scores index physiological AROUSAL vs a personal HRV baseline (and are heart-rate-dominated in practice), NOT psychological or emotional stress — the label is misleading; autonomic signals cannot separate mental stress from exertion, and no such score is validated on our Huami/Zepp hardware."
aliases: ["wearable_stress_scores", "stress score", "stress", "zepp stress", "body battery", "firstbeat stress", "hrv stress"]
tags: ["wearable_stress_scores", "stress score", "stress", "zepp stress", "body battery", "firstbeat stress", "hrv stress"]
applies_to_metrics: ["stress"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-16
---

# Wearable stress scores — validity & limits

## Summary
Consumer wearables surface a **"stress" 0–100** number derived from heart rate and time-domain HRV (RMSSD) compared against the wearer's own baseline. It indexes **physiological arousal**, not psychological or emotional stress — and in practice it is **heart-rate-dominated**, tracking HR far more strongly than HRV. Autonomic signals alone (HR, RMSSD) **cannot distinguish mental stress from physical exertion, caffeine, illness, or posture**: a high number is non-specific. The strong lab HRV–stress link **does not replicate in free-living**, where wearable HRV explains only ~1% of perceived-stress variance. Crucially, **no consumer stress score has been validated on our Huami/Zepp/Amazfit hardware** — Healthee ingests the strap's proprietary `stress` value but does **not** compute its own and does **not** treat it as a measured psychological state.

## What it is
A "stress score" (Garmin Stress Score, Firstbeat-derived scores, Body Battery, and our strap's `stress`) is a **vendor-computed 0–100 index** produced on the device from continuous HR and PPG-derived RMSSD, referenced against the wearer's personal resting-HRV baseline, with an activity mask so that exercise-driven HR is (nominally) not read as stress. The exact weighting is **proprietary and unpublished** for essentially all consumer devices, including ours. Typical framing on the watch: higher = more "stress", lower = more "rest" — but the number is an **arousal proxy**, not a psychological measurement.

## Physiology / mechanism
Each metric feeding the score reflects **autonomic arousal**: heart rate rises with sympathetic activation, and time-domain HRV (RMSSD) falls with vagal (parasympathetic) withdrawal. The problem is **non-specificity in two directions**: (1) reduced HRV can reflect *raised sympathetic activity, lowered parasympathetic activity, or both*, and the wearable cannot tell which; (2) the *same* arousal signature is produced by exercise, standing up, caffeine, a fever, a poor-signal artifact, or genuine psychological stress. Cardiac signals index **arousal intensity, not emotional valence** — they cannot tell "stressed" from "excited". Separating psychological stress from physical load requires an **HPA-axis marker (e.g. salivary cortisol)** that autonomic wearables do not capture.

## The evidence
- **[Established] Consumer stress scores are heart-rate-dominated, not HRV-driven.** For the Garmin Vivosmart 4 Stress Score, the strongest correlate was HR (within-condition r≈0.84–0.85; within-subject r=0.74), far exceeding RMSSD (within-condition r≈−0.59 to −0.63; within-subject r≈−0.41) [Rosenbach et al. 2025, *Stress and Health*]. Mainstream PPG wearables expose HRV only as time-domain **RMSSD** (never LF/HF frequency-domain), and most (Garmin included) do not expose raw inter-beat intervals at all (*practitioner consensus; Garmin non-exposure noted in Rosenbach et al. 2025*).
- **[Established] The score indexes arousal, not psychological stress.** In 95 adults over 28 days (~6,850 EMAs), a higher Garmin Stress Score was associated with **high/moderate-intensity POSITIVE mood** but **not** with negative or high-arousal-negative mood (stressed/anxious/worried); the authors argue the "Stress Score" label misrepresents what the number captures [van der Mee, Koyuncu & Lemmers-Jansen 2025, *Journal of Affective Disorders Reports* — "Are you stressed or just excited?"].
- **[Established] Autonomic signals alone cannot separate psychological stress from physical exertion.** Low HRV is physiologically non-specific — raised sympathetic OR lowered parasympathetic drive, indistinguishable from the cardiac signal alone; cardiac signals index arousal **intensity, not valence** [Banerjee 2026, *Frontiers in Physiology*]. Consistent with this, a wearable-only 5-class classifier reached only ~50% recall for psychological stress (misclassified as rest ~half the time); adding **salivary cortisol** — an HPA-axis marker unavailable from autonomic wearables — raised overall accuracy from 77.8% to 94.4% and psych-stress recall to 83.3% [Kaya et al. 2026, arXiv preprint — **small sample (n=6), preprint, treat as indicative**].
- **[Probable] Wearable HRV is a poor proxy for perceived stress in free-living.** Across 657 workers (14,695 EMAs), tracker HRV explained on average ~1% (best window 2.2%) of perceived-stress variance; the authors conclude it "should not be considered a proxy for perceived stress" [Martinez et al. 2022, *JMIR Human Factors*].
- **[Probable] The lab HRV–stress association does not replicate in the wild.** The strong laboratory HRV–stress relationship weakens sharply in free-living wearable use, and HR tends to be at least as closely tied to perceived stress as the HRV index [Seipäjärvi et al. 2022, *Physiological Measurement*; de Vries et al. 2023, *Applied Psychophysiology and Biofeedback* — resting HRV "a more sensitive but not specific marker of stress"].
- **[Probable] RMSSD is the HRV metric most consistently linked to stress, and it falls under stress.** In a scoping review, RMSSD was the most-reported HRV metric significantly associated with psychological stress, decreasing under stress (vagal withdrawal) — supporting the *direction* of an RMSSD-suppression signal, though the free-living effect is weak [Immanuel et al. 2023, *Neuropsychobiology*].
- **[Probable] RMSSD IS recoverable from PPG and can agree with ECG — but only in nocturnal/low-motion windows.** Nocturnal PPG RMSSD tracked ECG well (CCC 0.82–0.99 across devices; WHOOP RMSSD ICC 0.98–0.99 in slow-wave sleep with strict artifact filtering); accuracy degrades with motion [Dial et al. 2025, *Physiological Reports*; Bellenger et al. 2021, *Sensors* — note lnRMSSD showed only trivial bias but limits of agreement near the smallest worthwhile change]. **[Emerging]** PPG signal quality can also degrade with darker skin pigmentation.
- **[Emerging] Device-specificity gap.** NONE of the validated devices above is a Huami/Zepp/Amazfit. Our own `stress` 0–100 has **zero published validation on our hardware**; the PPG-RMSSD-vs-ECG results show nocturnal PPG RMSSD *can* track ECG on *those* devices, not that ours does.
- **[Emerging] Feasibility of a Healthee-derived stress metric.** The only defensible own-signal is a **nocturnal RMSSD-suppression index vs personal baseline** — but that is essentially what Healthee already computes as **recovery** (`recovery_readiness`), so a separate "stress" metric would violate one-definition-per-metric. A daytime multi-signal composite (HR↑ − HRV↓ + respiratory-rate↑) has **no validated weights** and no primary source for the respiratory limb. We therefore do **not** compute our own stress score today.

## How we compute it
**We don't.** Healthee ingests the strap's proprietary `stress` 0–100 as a raw `sample` metric — the **device computes it on-watch from an unpublished algorithm** (from the encrypted live-stress channel; see the stress/0x13 reference). The Today "stress" card displays **hourly averages** of that raw signal (`today_stress_series` from `read/today_series.py`). There is **no Healthee derivation, no re-computation, and no validation** on our part.

## How the coach uses it
- **Stage 1 (default):** treat the number as **physiological arousal vs the person's own baseline**, nothing more. Describe *trends* ("your arousal has been running higher than your typical this week"), never an absolute stress level.
- **Stage 2:** if it is elevated, name the **non-specific confounders first** (recent exercise, caffeine, standing, illness, poor sensor contact) before any psychological read; ask, don't assert.
- **Stage 3:** for genuine recovery/readiness questions, defer to `recovery_readiness` (nocturnal HRV vs baseline), which is the validated overnight signal — not the daytime `stress` card.
- **Always:** never convert the number into a mood or an emotion, and never alarm on a single high or low value.

## Safety bounds
- The `stress` number is **not** a clinical stress level, a mental-health indicator, or a diagnosis — never present it as one.
- A high value is **non-specific** and must **never trigger alarm** ("your body is under dangerous stress") — it may simply be exertion, caffeine, posture, illness, or a bad signal.
- It is **unvalidated on our hardware**; any use is a heavily-caveated personal trend, never an absolute or comparative-to-others figure.

## Honesty & uncertainty
- The device algorithm is **proprietary and unpublished** — we cannot state what it weights or how it masks activity.
- Every validation figure above comes from **other manufacturers' devices** (Garmin, WHOOP, Oura, Polar); **none** transfers to our Huami/Zepp strap.
- Even the best-validated version of this signal (nocturnal RMSSD vs baseline) is an **arousal/recovery** read, not a psychological-stress measurement — that limit is intrinsic to autonomic sensing, not a hardware flaw.
- The strongest own-metric we could build would duplicate `recovery_readiness`; a real daytime psychological-stress metric needs **beat-to-beat RR-interval capture over BLE plus endocrine (cortisol) context we cannot obtain** — so it stays a future item, not a current claim.

## Bottom line
**Act on confidently:** the number is **arousal vs the wearer's own baseline**, heart-rate-dominated, non-specific, and unvalidated on our hardware; recovery questions belong to `recovery_readiness`.

**Hold loosely:** any single value's meaning; day-to-day daytime movements; and any interpretation approaching mood, emotion, or a clinical stress level — those it cannot support.

## Coach Directives
1. **SAFETY-CRITICAL:** NEVER present the `stress` number as the user's psychological, emotional, or mental state — it is **physiological arousal vs their own baseline**. *(confidence: high; **not enforced in code** — see the note below these four.)*
2. **SAFETY-CRITICAL:** NEVER infer mood or emotional valence from it — arousal ≠ valence; "stressed" and "excited" look identical to the sensor. *(high; **not enforced in code**.)*
3. **SAFETY-CRITICAL:** A high or low value is **non-specific** (exertion, posture, caffeine, illness, poor signal all move it) — never alarm on it. *(high; **not enforced in code**.)*
4. **SAFETY-CRITICAL:** It is **unvalidated on our hardware** — present only heavily-caveated trends vs the person's own baseline, never an absolute or clinical stress level. *(high; **not enforced in code**.)*

> **What enforces D1–D4: nothing, as of #100.** No output rule in
> `insights/output_guard.py` or `insights/guard_directives.py` recognises a mood or
> emotional claim attached to the `stress` number, and `insights/refusals.py` classifies
> the *question* — it fires on an owner asking "am I anxious?", not on the coach
> volunteering "your stress score says you were anxious". These four are rules for the
> coach, carried by the note's prose and the system prompt.
> They keep the SAFETY-CRITICAL marking because the harm they guard is real — a wearable
> telling someone what they feel is the failure mode this whole note exists to document —
> but the marking is a statement of *severity*, not of enforcement, and until #100 a
> reader of the directives block could not tell the difference. This note is the
> strongest remaining candidate for a compiled rule: unlike most safety directives in the
> corpus, its forbidden move (arousal → emotion) is a text pattern rather than a plan
> shape.
5. For recovery/readiness reads, defer to `recovery_readiness` (validated nocturnal HRV-vs-baseline), not the daytime `stress` card. *(high)*

## References
- Rosenbach H, Itzkovitch A, Gidron Y, Schonberg T. (2025). *Assessing Stress Level Scores Against Wearables-Driven Physiological Measurements.* Stress and Health. https://pmc.ncbi.nlm.nih.gov/articles/PMC12647429/
- van der Mee DJ, Koyuncu Z, Lemmers-Jansen ILJ. (2025). *Are you stressed or just excited? What the Garmin Stress Score can say about your mood.* Journal of Affective Disorders Reports 21. https://www.sciencedirect.com/science/article/pii/S2666915325001040
- Martinez GJ, Grover T, Mattingly SM, Mark G, D'Mello S, Aledavood T, Akbar F, Robles-Granda P, Striegel A. (2022). *Alignment Between Heart Rate Variability From Fitness Trackers and Perceived Stress: Perspectives From a Large-Scale In Situ Longitudinal Study of Information Workers.* JMIR Human Factors 9(3):e33754. https://humanfactors.jmir.org/2022/3/e33754
- Seipäjärvi SM, et al. (2022). *Measuring psychosocial stress with heart rate variability-based methods in different health and age groups.* Physiological Measurement. https://doi.org/10.1088/1361-6579/ac6b7c
- de Vries H, Oldenhuis H, van der Schans C, Sanderman R, Kamphuis W. (2023). *Does Wearable-Measured Heart Rate Variability During Sleep Predict Perceived Morning Mental and Physical Fitness?* Applied Psychophysiology and Biofeedback. https://pmc.ncbi.nlm.nih.gov/articles/PMC10195711/
- Banerjee A. (2026). *Understanding the shortcomings of heart rate variability as a tool for autonomic analysis.* Frontiers in Physiology. https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2026.1760160/full
- Kaya O, Athanassopoulou N, Malliaras GG, Alban-Paccha MV. (2026). *Differentiating Physical and Psychological Stress Using Wearable Physiological Signals and Salivary Cortisol.* arXiv preprint 2604.12671 (**small sample, n=6; preprint — indicative only**). https://arxiv.org/pdf/2604.12671
- Immanuel S, Teferra MN, Baumert M, Bidargaddi N. (2023). *Heart Rate Variability for Evaluating Psychological Stress Changes in Healthy Adults: A Scoping Review.* Neuropsychobiology 82(4):187. https://karger.com/nps/article/82/4/187/845046
- Dial MB, Hollander ME, Vatne EA, Emerson AM, Edwards NA, Hagen JA. (2025). *Validation of nocturnal resting heart rate and heart rate variability in consumer wearables.* Physiological Reports 13(16). https://pmc.ncbi.nlm.nih.gov/articles/PMC12367097/
- Bellenger CR, et al. (2021). *Wrist-Based Photoplethysmography Assessment of Heart Rate and Heart Rate Variability: Validation of WHOOP.* Sensors (Basel). https://pmc.ncbi.nlm.nih.gov/articles/PMC8160717/

## Healthee implementation & honesty policy
- **Raw metric: `stress`** (0–100), device-provided and ingested as a raw `sample` (from the strap's encrypted live-stress channel). It is **NOT** a `derived_daily` row, **NOT** Healthee-computed, and **NOT** validated on Huami/Zepp/Amazfit hardware. The Today card shows hourly averages via `today_stress_series` (`read/today_series.py`); there is no `derive/` provenance because we do not derive it.
- **We deliberately do NOT compute our own stress score.** A nocturnal RMSSD-suppression index would duplicate `recovery_readiness` (one-definition-per-metric); an RMSSD-only + sparse-daytime-HRV daytime composite has no validated weights and no primary source for its respiratory limb. A genuinely validated own-metric is a **future item gated on beat-to-beat RR-interval capture over BLE** plus endocrine (cortisol) context we cannot obtain.
- `applies_to_metrics` is `["stress"]` — this note frames the **raw ingested signal**, correcting a live honesty-contract gap (the app surfaces the `stress` card with no backing note today).
- **Honesty rules (carry into UI + LLM):** label it arousal-vs-baseline, never a psychological/emotional/mental state; never infer mood/valence; always name the non-specific confounders (exercise, caffeine, posture, illness, poor signal) before any interpretation; never alarm on a value; present only caveated personal trends, never an absolute or comparative stress level; route recovery/readiness questions to `recovery_readiness`.
