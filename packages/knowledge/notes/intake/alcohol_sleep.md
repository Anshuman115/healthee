---
id: alcohol_sleep
name: "Alcohol, sleep architecture, and overnight autonomics"
topic: Alcohol disrupts second-half sleep architecture and acutely lowers HRV
category: intake
grade: Established
evidence_grade: 3
summary: "Even 1–2 drinks before bed front-loads slow-wave sleep then fragments the second half (more wake, less REM), acutely drops overnight HRV (RMSSD/HF) 15–30%, and raises resting HR ~5–10 bpm — dose-dependent from ~0.5 g/kg; a morning-after HRV dip after a logged drink is expected, not an anomaly."
aliases: ["alcohol", "drinking", "alcohol before bed", "nightcap", "alcohol and sleep", "alcohol and hrv"]
applies_to_metrics: ["tst_min", "sleep_health_score_4dim", "hrv_sleep_avg", "rhr_daily"]
applies_to_interventions: ["alcohol"]
population: general
last_reviewed: 2026-07-15
related: ["caffeine_alcohol_cutoff_plan", "caffeine_sleep", "heart_rate_variability"]
tags: [alcohol, sleep, hrv, autonomic]
---

# Alcohol, sleep architecture, and overnight autonomics

## Summary

Even moderate alcohol (1–2 standard drinks) **before bed** predictably alters
sleep architecture and autonomic markers overnight: it increases slow-wave sleep
in the **first half** then **fragments the second half** (more wake, less REM),
acutely **reduces HRV** (RMSSD and HF power) for the night and into the next
morning, and elevates **resting heart rate** for several hours. The effect is
dose-dependent and detectable down to ~0.5 g alcohol/kg body weight (~1 drink in a
70 kg adult). The Healthee-critical consequence: a **drop in HRV the morning after
a logged drink is expected physiology, not a health-concerning anomaly**.

## What it is

Alcohol is a CNS depressant and diuretic that, taken near bedtime, produces a
characteristic two-phase night. It is logged as an intervention and evaluated
against that night's sleep and the next morning's autonomic metrics. "Moderate"
here means roughly 1–2 standard drinks; effects are graded by dose and by how long
before bed the last drink was.

## Physiology / mechanism

As blood alcohol falls through the night, its early sedative/GABAergic effect
(which deepens slow-wave sleep early) gives way to a **rebound** in the second
half: sympathetic reactivation, REM suppression then rebound, and arousals. The
same sympathetic shift and the metabolic/diuretic load depress vagally-mediated
HRV and raise heart rate overnight — so the autonomic signals move for
alcohol-clearance reasons, independent of training recovery.

## The evidence

### Sleep architecture — front-loaded SWS, fragmented second half [Established]
Alcohol increases slow-wave sleep in the **first half** of the night, then
**fragments** the second half (more wake, less REM). Reduction in REM in the
second half is **~10–25%** vs an alcohol-free night (varies by dose)
(Ebrahim et al. 2013; Park et al. 2015).

### Overnight HRV — acute reduction [Established]
Alcohol acutely **reduces HRV** (RMSSD and HF power) for the night and into the
next morning. The acute drop in nocturnal RMSSD is **commonly 15–30%** on drinking
nights vs non-drinking nights, replicated in consumer-wearable data (Pietilä et al.
2018, n ≈ 4,098).

### Resting heart rate — elevated overnight [Established]
Alcohol elevates **resting heart rate ~5–10 bpm above personal baseline**
overnight, persisting until late morning.

### Dose-response and threshold [Established]
The effect is **dose-dependent and detectable down to ~0.5 g alcohol/kg body
weight** (roughly 1 standard drink in a 70 kg adult).

## How we compute it

Alcohol is a **logged intervention** (`manual_entry`, kind `alcohol`), not a
derived metric. It is correlated against that night's `tst_min` and
`sleep_health_score_4dim` and the next morning's `hrv_sleep_avg` and `rhr_daily`.
The personal cutoff-time finder that mines these logs lives in
`caffeine_alcohol_cutoff_plan`.

## How the coach uses it

- A drop in nightly HRV the morning after an alcohol entry is **expected**, not a
  health-concerning anomaly — say so plainly.
- Surface the connection when the user has logged alcohol and we observe an
  HRV/RHR shift the next morning, citing this note as the basis.
- Do **not** extrapolate to long-term health claims from a single drinking event.
- When relevant, note that timing helps: alcohol >4 h before bed has smaller
  second-half effects.

## Safety bounds

- No acute safety guardrail — this is a sleep/autonomic note. Do not turn a single
  logged drink into a medical warning or a long-term risk claim.
- Never present morning-after HRV/RHR shifts as a diagnosis.

## Honesty & uncertainty

- **Tolerance / individual variation is real** — some people show smaller effects,
  but the **direction** of effect is consistent.
- **Light drinkers experience a relatively larger HRV impact than heavy drinkers**
  (paradoxical, but replicated).
- **Time-of-consumption matters**: alcohol >4 hours before bed has smaller
  second-half effects.
- Single-night effects say nothing about long-term health; do not extrapolate.

## Bottom line

**Act on confidently:** a nightcap fragments second-half sleep, cuts REM, drops
overnight HRV 15–30%, and lifts RHR 5–10 bpm. A morning-after HRV dip following a
logged drink is expected, not an anomaly.

**Hold loosely:** the exact magnitude for a given user and dose, and the personal
cutoff hour — individual and best learned from the user's own logs.

## Coach Directives

1. Treat a next-morning HRV drop / RHR rise after a logged alcohol entry as
   expected physiology; report it as such, not as an anomaly, and cite this note.
   *(confidence: high)*
2. Do not extrapolate a single drinking event to long-term health claims. *(high)*
3. When surfacing the effect, prefer dose/timing framing (>4 h before bed is
   milder) over blanket avoidance. *(moderate)*
4. Never present overnight autonomic shifts from alcohol as a diagnosis. *(high)*

## References
- Ebrahim IO, Shapiro CM, Williams AJ, Fenwick PB. **"Alcohol and sleep I: effects
  on normal sleep."** *Alcoholism: Clinical and Experimental Research*
  2013;37(4):539–549. Systematic review across multiple controlled-dose studies.
- Pietilä J, Helander E, Korhonen I, et al. **"Acute effect of alcohol intake on
  cardiovascular autonomic regulation during the first hours of sleep in a large
  real-world sample of Finnish employees: observational study."** *JMIR Mental
  Health* 2018;5(1):e23. n ≈ 4,098, consumer-wearable HRV data.
- Park SY et al. **"The effects of alcohol on quality of sleep."** *Korean Journal
  of Family Medicine* 2015;36(6):294–299. Review with focus on architecture changes.

## Healthee implementation & honesty policy

- Alcohol is a logged intervention, not a derived metric — no `derived_daily` row.
  It is a `manual_entry` (kind `alcohol`) correlated against `tst_min`,
  `sleep_health_score_4dim`, `hrv_sleep_avg`, and `rhr_daily`.
- **The confound rule is mandatory**: when the morning `hrv_sleep_avg` drops or
  `rhr_daily` rises on a day following a logged drink, the coach MUST name the
  alcohol as the expected cause and MUST NOT report the change as a health anomaly
  or an overreaching signal. This is the "never shows a wrong metric as an alarm"
  contract applied to alcohol.
- No composite "alcohol score" is derived; alcohol only contextualises existing
  metrics and feeds the personal cutoff finder (`caffeine_alcohol_cutoff_plan`).
- Honesty rule: single-event only — never launder one night's autonomic shift into
  a long-term health claim.
