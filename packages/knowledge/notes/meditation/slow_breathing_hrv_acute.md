---
id: slow_breathing_hrv_acute
name: "Slow-paced breathing and acute HRV"
topic: Slow-paced breathing (~6 breaths/min) acutely increases HRV
category: meditation
grade: Established
summary: "Breathing at ~6 breaths/min acutely raises HRV — RMSSD commonly +30–80% and HF power 2–5× during a 10–20 min session — via baroreflex resonance and maximised respiratory sinus arrhythmia; the effect is largely within-session, so an elevated overnight HRV after breathwork is expected, not a surprise, and chronic-baseline gains are smaller and less certain."
aliases: ["breathwork", "slow breathing", "paced breathing", "resonance breathing", "coherent breathing", "vagal_tone", "6 breaths per minute"]
applies_to_metrics: ["hrv_sleep_avg", "respiratory_rate_sleep"]
applies_to_interventions: ["meditation"]
population: general
last_reviewed: 2026-07-15
related: ["heart_rate_variability", "mindfulness_anxiety_depression"]
tags: [breathwork, hrv, autonomic, vagal_tone]
---

# Slow-paced breathing and acute HRV

## Summary

Slow-paced breathing at approximately **6 breaths per minute** (5.5–6 breaths/min,
a 10-second cycle) **acutely** increases multiple HRV indices during and shortly
after the practice, mediated by resonance with baroreflex oscillations and
reproducible in healthy adults across many studies. Typical magnitude: RMSSD
**+30–80%** and HF power **2–5×** during a session. The effect is largely
within-session, so a breathwork session **followed by elevated overnight HRV is
expected physiology** — the coach should report it as consistent, not surprising —
while chronic baseline-HRV gains from short-term practice are smaller and less
certain.

## What it is

Slow-paced (resonance / coherent) breathing is deliberate breathing at roughly
**6 breaths per minute** (individual optimum ~4.5–7). In Healthee it is logged as
part of a meditation/breathwork intervention; its signature effect is an **acute**
rise in HRV during and just after the practice.

## Physiology / mechanism

The mechanism is well-characterized: slow breathing **maximizes respiratory sinus
arrhythmia** and engages **parasympathetic ("vagal") tone**. Breathing near ~6/min
resonates with the baroreflex's intrinsic ~0.1 Hz oscillation, amplifying
beat-to-beat heart-rate oscillations and thus HRV. Because the driver is the
breathing itself, the effect is strongest in-session and decays once normal
breathing resumes.

## The evidence

### Acute HRV increase during practice [Established]
- Acute increase in **RMSSD: commonly +30–80%** during a 10–20 minute
  slow-breathing session vs spontaneous-breathing baseline (Laborde et al. 2022).
- Acute increase in **HF power: typically 2–5×** vs baseline.
- Effects **largely return to baseline within minutes** of stopping, **though
  sub-acute effects** (next 30–60 min) and **chronic effects** (with daily
  practice) are documented but smaller and less consistent.

The acute HRV increase is confirmed by meta-analysis (Laborde et al. 2022); the
physiological mechanism (baroreflex resonance, maximised RSA, vagal engagement) is
detailed by Russo et al. 2017; the methodological framing for HRV as a cardiac
vagal-tone index is set out in Laborde et al. 2017 [all Established].

## How we compute it

Breathwork is a **logged intervention** (`manual_entry`, meditation/breathwork),
not a derived metric. The relevant objective signals it touches are overnight HRV
(`hrv_sleep_avg`) and respiratory rate (`respiratory_rate_sleep`). The expected
in-session and near-term response is increased RMSSD; a following night's elevated
`hrv_sleep_avg` is consistent with (though not proof of) the practice.

## How the coach uses it

- When the user logs a meditation/breathwork session, the **expected** HRV response
  in the following minutes/hours is **increased RMSSD** — say so.
- A breathwork session **followed by elevated overnight HRV** is consistent with
  this evidence; report it honestly as **expected, not as a surprise**.
- Do **not** promise chronic baseline HRV shifts from short-term practice.

## Safety bounds

- People with **cardiopulmonary disease should not interpret HRV changes as
  health-grade**; the coach must not turn a breathwork HRV bump into a medical
  claim.
- No prescriptive breathing protocol as therapy; this is a wellness aid, not
  treatment.

## Honesty & uncertainty

- **Most evidence is acute** (within-session). Chronic-baseline HRV improvement
  from regular slow-breathing practice is plausible and supported by some RCTs, but
  the effect size at the baseline level is smaller.
- **The optimal pace varies slightly between individuals** (4.5–7 breaths/min);
  ~6 is a population average.
- **People with cardiopulmonary disease** should not interpret HRV changes as
  health-grade.
- An elevated overnight HRV after breathwork is consistent with the practice but is
  not exclusive proof it caused the change.

## Bottom line

**Act on confidently:** ~6 breaths/min acutely raises HRV (RMSSD +30–80%, HF 2–5×)
via baroreflex resonance. An elevated overnight HRV after a logged breathwork
session is expected, not surprising.

**Hold loosely:** chronic baseline-HRV gains from short-term practice (smaller,
less certain); the exact individual optimal pace; attributing any single night's
HRV rise solely to the session.

## Coach Directives

1. When a breathwork/meditation session is logged, describe the expected acute HRV
   rise (increased RMSSD) and cite this note. *(confidence: high)*
2. Report an elevated overnight HRV after breathwork as expected/consistent, not as
   a surprising anomaly. *(high)*
3. Do not promise chronic baseline-HRV shifts from short-term practice. *(high)*
4. Do not interpret breathwork HRV changes as health-grade for users with
   cardiopulmonary disease. *(moderate)*

## References
- Laborde S, Allen MS, Borges U, et al. **"Effects of voluntary slow breathing on
  heart rate and heart rate variability: A systematic review and a meta-analysis."**
  *Neuroscience & Biobehavioral Reviews* 2022;138:104711. Meta-analysis confirming
  acute HRV increase.
- Russo MA, Santarelli DM, O'Rourke D. **"The physiological effects of slow
  breathing in the healthy human."** *Breathe* 2017;13(4):298–309. Mechanistic
  review.
- Laborde S, Mosley E, Thayer JF. **"Heart rate variability and cardiac vagal tone
  in psychophysiological research."** *Frontiers in Public Health* 2017;5:258.
  Methodological framework + summary.

## Healthee implementation & honesty policy

- Breathwork is a logged intervention, not a derived metric — no `derived_daily`
  row. It relates to `hrv_sleep_avg` and `respiratory_rate_sleep`.
- **Confound / honesty rule**: when overnight `hrv_sleep_avg` rises after a logged
  breathwork session, the coach reports it as **expected and consistent with the
  practice**, never as an unexplained improvement or a fitness gain, and never
  promises a chronic baseline shift from short-term practice.
- Cross-links to the HRV metric note (`heart_rate_variability`) for the
  baseline-vs-acute distinction the coach must respect.
