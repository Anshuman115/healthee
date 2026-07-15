---
id: sleep_duration_mortality
name: "Sleep duration and all-cause mortality"
topic: Sleep duration and all-cause mortality (U-shaped curve)
category: sleep
grade: Established
evidence_grade: 3
summary: "Habitual sleep shows a U-shaped tie to mortality — both short (<6h) and long (>9h) carry higher risk than 7–8h — but it's observational, self-reported, and a population signal, never a single-night verdict."
aliases: ["sleep duration", "sleep and mortality", "sleep longevity", "u-shaped sleep mortality", "sleep_duration"]
applies_to_metrics: ["sleep_health_score_4dim"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
---

# Sleep duration and all-cause mortality

## Summary
Habitual sleep duration has a U-shaped association with all-cause mortality:
both short (<6h/night) and long (>9h/night) sleep carry higher risk than 7–8h.
It is background context for *chronic* patterns only — observational, self-
reported, and about the population, not a person's exact optimum or any single
night.

## What it is
The epidemiological relationship between how long a person habitually sleeps and
their risk of dying from any cause. The reference band is 7–8h; risk rises on
both tails of the curve.

## Physiology / mechanism
The mechanisms are only partly understood and differ by tail. Short sleep is
linked to sympathetic activation, impaired glucose regulation, inflammation, and
raised blood pressure. Long sleep is widely thought to be a *marker* of
underlying illness, depression, or low cardiorespiratory fitness rather than a
direct cause — which is why the long tail must be read cautiously.

## The evidence
- **[Established]** Habitual sleep duration shows a U-shaped association with
  all-cause mortality; both short (<6h) and long (>9h) sleep are associated with
  higher mortality than 7–8h (Cappuccio 2010, *Sleep*).
- **[Established]** Short sleep (<6h): pooled relative risk ≈ **1.12** (95% CI
  1.06–1.18) vs the 7–8h reference.
- **[Established]** Long sleep (>9h): pooled relative risk ≈ **1.30** (95% CI
  1.22–1.38) vs the 7–8h reference.

Evidence base: Cappuccio FP, D'Elia L, Strazzullo P, Miller MA. "Sleep duration
and all-cause mortality: a systematic review and meta-analysis of prospective
studies." *Sleep* 2010;33(5):585–92. PMID 20469800 — 16 prospective cohort
studies, n ≈ 1.38 million participants.

## How we compute it
Not a derived metric of its own — this note is the mortality-context evidence
behind the *duration* dimension of the sleep-health score and any multi-week
sleep-duration trend. Duration comes from the strap's sleep sessions (total
sleep time), read via `sleep_health_score_4dim` and the sleep history.

## How the coach uses it
- Background context only, and only for **chronic** patterns.
- **Never** flag a single short night as a health concern on this basis.
- A multi-week trend of <6h *average* sleep is worth surfacing as a personal
  pattern, citing this note — paired with the person's own baseline.
- The proximal signal is deviation from the user's own median, not the
  population mean.

## Safety bounds
This is a longevity-epidemiology note, not a diagnostic. Never present sleep
duration as a personal death-risk number, and never alarm someone over normal
night-to-night variation. Persistent extreme short sleep alongside distress is a
reason to suggest a clinician, not a statistic.

## Honesty & uncertainty
- All included studies are **observational**. Reverse causation is plausible:
  long sleep may reflect underlying illness rather than cause harm.
- Sleep duration in the source studies was **self-reported**, noisier than
  wearable measurement (self-report typically over-estimates by 30–60 min).
- The population association does **not** imply a single individual's optimum is
  exactly 7–8h — personal baseline matters more than the population mean.
- The association is for **habitual** sleep, not single nights.

## Bottom line
**Act on confidently:** protect a habitual 7–8h band; a sustained multi-week
average under ~6h is a real, citable personal pattern worth addressing.
**Hold loosely:** the exact personal optimum, the long-sleep tail (likely a
marker, not a cause), and anything inferred from single nights.

## Coach Directives
1. Use only for chronic (multi-week) sleep-duration patterns, never a single
   night. *(confidence: high)*
2. Cite deviation from the person's own median as the proximal signal; the
   population U-curve is context, not a verdict. *(high)*
3. Never present sleep duration as a personal death-risk number. *(high)*

## References
- Cappuccio FP, D'Elia L, Strazzullo P, Miller MA. 2010. Sleep duration and
  all-cause mortality: a systematic review and meta-analysis of prospective
  studies. *Sleep* 33(5):585–592. PMID 20469800.

## Healthee implementation & honesty policy
- Not a stored metric; it grounds the *duration* dimension of
  `sleep_health_score_4dim` and any long-run sleep-duration trend surfaced to the
  user.
- Honesty rules the coach must hold: never a death-risk number; never alarm on a
  single night; the long-sleep tail is presented as a possible marker of illness,
  not a cause; the person's own baseline is always the proximal signal.
- Relates to [[no_validated_sleep_score]] (no single validated sleep score),
  [[sleep_need_debt]] (age-based need), and [[sleep_regularity_index]]
  (regularity, a stronger mortality-linked signal than duration alone).
