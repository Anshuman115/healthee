---
id: caffeine_sleep
name: "Caffeine timing and sleep"
topic: Caffeine taken up to 6 hours before bed measurably disrupts sleep
category: intake
grade: Established
evidence_grade: 3
summary: "Caffeine taken at bedtime, 3 h, or even 6 h before bed measurably cuts total sleep time and raises wake-after-sleep-onset versus placebo — significant at 6 h out and detected by both self-report and polysomnography; a 400 mg dose 6 h before bed costs ~1 h of sleep."
aliases: ["caffeine", "coffee", "coffee before bed", "caffeine cutoff", "caffeine and sleep", "late caffeine"]
applies_to_metrics: ["tst_min", "sleep_health_score_4dim"]
applies_to_interventions: ["caffeine"]
population: general
last_reviewed: 2026-07-15
related: ["caffeine_alcohol_cutoff_plan", "alcohol_sleep"]
tags: [caffeine, sleep]
---

# Caffeine timing and sleep

## Summary

Caffeine consumed at **bedtime, 3 hours before bed, or 6 hours before bed** all
measurably reduce total sleep time and increase wake time after sleep onset,
compared with placebo. The effect is significant even at **6 hours** before bed
and is detected both subjectively and by polysomnography. The single most useful
number: **400 mg of caffeine 6 hours before bed costs roughly 1 hour of total
sleep time**. For Healthee this makes an evening caffeine log a strong, defensible
explanation when that night's sleep dips — and it is why a personal cutoff window
is worth learning per user.

## What it is

Caffeine is an adenosine-receptor antagonist with a population elimination
half-life of roughly **3–7 hours** (CYP1A2-genotype dependent). Because a dose
taken in the afternoon or evening is still substantially present at bedtime, its
sleep-disrupting action is a function of **dose and time-before-bed**, not just
whether it was consumed that day.

## Physiology / mechanism

Caffeine blocks adenosine A1/A2A receptors, which are the substrate of homeostatic
sleep pressure. Antagonising them delays sleep onset, lightens sleep, and
fragments the night (more wake after sleep onset). With a multi-hour half-life, a
meaningful fraction of an afternoon dose remains at lights-out, so the drug is
still occupying receptors when sleep pressure should be dominating — which is why
a 6-hour lead time is not "safe."

## The evidence

### Timing — bedtime, 3 h, and 6 h before bed all disrupt sleep [Established]
Caffeine consumed at **bedtime, 3 hours before bed, or 6 hours before bed** all
measurably reduce total sleep time and increase wake time after sleep onset versus
placebo. The effect is significant even at **6 hours** before bed and is detected
both subjectively and by polysomnography (Drake et al. 2013). Design: double-blind,
placebo-controlled, within-subject.

### Effect size — ~1 h of lost sleep at 6 h out [Established]
- 400 mg caffeine 6 hours before bed: **~1 hour total sleep time reduction** vs
  placebo, measured by both polysomnography and home sleep recordings
  (Drake et al. 2013).

Corroboration: Clark & Landolt 2017, a systematic review of epidemiological
studies and RCTs, supports caffeine's disruptive effect on sleep across the
literature [Established].

## How we compute it

Caffeine is a **logged intervention** (`manual_entry`, kind `caffeine`), not a
derived metric. It enters analysis as an event correlated against that night's
`tst_min` and `sleep_health_score_4dim` (the efficiency dimension captures the
extra wake-after-sleep-onset). The personal cutoff-time finder that mines these
logs is specified in `caffeine_alcohol_cutoff_plan`.

## How the coach uses it

- Flag caffeine entries logged within **~6 hours of typical bedtime** as a likely
  contributor when sleep quality dips, citing this note.
- Do **not** flag morning-only caffeine as a sleep risk under normal circumstances.
- Help the user identify their **personal cutoff window** across multiple nights
  (see `caffeine_alcohol_cutoff_plan`), rather than asserting a one-size threshold.
- When flagging, prefer the quantified frame ("400 mg ~6 h before bed is worth
  about an hour of sleep") over a bare "caffeine is bad."

## Safety bounds

- No acute safety guardrail — this is a sleep-quality note, not a medical one. Do
  not extrapolate an evening coffee into a clinical warning.
- Do not present the personal cutoff as medical advice; it is an
  n=1 correlation aid.

## Honesty & uncertainty

- **Individual variability in caffeine metabolism is large** — CYP1A2 genotype
  affects half-life, with a population range of ~3–7 hours. One user's safe cutoff
  is not another's.
- **Habitual heavy users develop partial tolerance** to the sleep effects, but not
  full tolerance — the effect shrinks, it does not vanish.
- **Dose matters**: smaller doses (≤100 mg) have smaller effects but are **not
  negligible** 3–6 hours before bed.
- The ~1 h figure is for a 400 mg dose; lighter evening intake will cost less.

## Bottom line

**Act on confidently:** evening caffeine measurably shortens and fragments sleep,
and the window extends to at least 6 hours before bed. An evening caffeine log is a
strong explanation for a poor night.

**Hold loosely:** the exact per-user cutoff hour and the magnitude for a given
dose — these are individual (genotype, tolerance) and best learned from the user's
own logs.

## Coach Directives

1. When sleep dips on a night with a caffeine log within ~6 h of bedtime, surface
   the connection and cite this note. *(confidence: high)*
2. Do not flag morning-only caffeine as a sleep risk absent user-specific evidence.
   *(high)*
3. Prefer a quantified, personal-cutoff frame over generic "avoid caffeine"
   advice; defer the threshold to the user's own logs. *(moderate)*
4. Never present caffeine timing guidance as medical advice. *(high)*

## References
- Drake C, Roehrs T, Shambroom J, Roth T. **"Caffeine effects on sleep taken 0, 3,
  or 6 hours before going to bed."** *Journal of Clinical Sleep Medicine*
  2013;9(11):1195–1200. Double-blind, placebo-controlled, within-subject design.
- Clark I, Landolt HP. **"Coffee, caffeine, and sleep: A systematic review of
  epidemiological studies and randomized controlled trials."** *Sleep Medicine
  Reviews* 2017;31:70–78.

## Healthee implementation & honesty policy

- Caffeine is a logged intervention, not a derived metric — no `derived_daily`
  row. It is a `manual_entry` (kind `caffeine`) correlated against `tst_min` and
  `sleep_health_score_4dim` for the affected night.
- The coach must attribute a sleep dip to caffeine only when a caffeine log falls
  within the plausible ~6 h window of that night's bedtime, and must say so as a
  likely contributor, not a certainty.
- No composite "caffeine score" is derived; caffeine only contextualises existing
  sleep metrics and feeds the personal cutoff finder (`caffeine_alcohol_cutoff_plan`).
- Honesty rule: surface the metabolic-variability confound (CYP1A2 half-life
  3–7 h) rather than asserting a universal cutoff hour.
