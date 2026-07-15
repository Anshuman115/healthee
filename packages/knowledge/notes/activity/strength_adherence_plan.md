---
id: strength_adherence_plan
name: "Weekly strength-minutes tally plan"
topic: Implementation plan — weekly strength-training minutes tally vs 30–60 min/week sweet spot
category: activity
grade: Probable
evidence_grade: 2
summary: "Tally weekly muscle-strengthening minutes from logged exercise (a strength-type classifier, with generic yoga counting half-credit only at ≥30 min) and show them against the 30–60 min/week sweet spot — a tiny card, no new derivation pipeline, framed as progress not deficit."
aliases: ["strength minutes", "strength tally", "strength card", "weekly strength plan", "strength_adherence_plan"]
tags: ["strength minutes", "strength tally", "strength card", "weekly strength plan", "strength_adherence_plan"]
applies_to_metrics: ["strength_min_weekly"]
applies_to_interventions: ["exercise"]
population: general
last_reviewed: 2026-07-15
related: ["strength_training_mortality", "strength_training_for_runners", "mvpa_minutes_mortality"]
---

# Weekly strength-minutes tally plan

## Summary

Tally weekly minutes of muscle-strengthening activity from `manual_entry` exercise logs and
display against the 30–60 min/week sweet spot from [[strength_training_mortality]]. A tiny
card; no new derivation pipeline needed. This note is the implementation; the science and
dose-response are in the related mortality note.

## What it is

A weekly aggregate (`strength_min_weekly`) computed by classifying logged exercise entries
as strength-eligible and summing their minutes, shown against the evidence-based 30–60
min/week band.

## Physiology / mechanism

The 30–60 min/week band and ≥2 days/week target trace to the J-shaped strength↔mortality
dose-response (muscle/sarcopenia, glycemic, bone, falls pathways) — see
[[strength_training_mortality]]. The classifier's job is to attribute logged activity to
that band without over-counting mixed-modality sessions (e.g. generic yoga).

## The evidence

- **[Established]** The **30–60 min/week sweet spot** and the additive aerobic+strength
  benefit come from [[strength_training_mortality]] (Momma 2022; Liu 2019).
- **[Probable]** Yoga/pilates are **mixed-modality**; the Saeidifard 2019 / Momma 2022
  cohorts grouped some in, justifying a conservative **half-credit** for generic yoga
  ≥30 min rather than full or zero credit.

## How we compute it

### Data we have
- `manual_entry(kind='exercise')` rows with `payload.exercise_type` (free-text or enum),
  `payload.duration_min`, `payload.intensity` (`low|moderate|high`), and `at_iso`. (Same
  shape that produces `session(kind='exercise')`.)

### Classifier
Strength-eligible exercise types (case-insensitive):

```python
STRENGTH_TYPES = {
    "strength", "weights", "weightlifting", "lifting",
    "gym", "resistance", "calisthenics", "climbing",
    "bouldering", "powerlifting", "crossfit",
}
STRENGTH_YOGA_THRESHOLD_MIN = 30   # generic yoga only counts if ≥30 min
```

For each `manual_entry(kind='exercise')`:
- If `type ∈ STRENGTH_TYPES` → count full `duration_min`.
- If `type == 'yoga'` AND `duration_min ≥ 30` → count `duration_min × 0.5` (conservative
  half-credit; yoga isn't pure strength but contributes per the Saeidifard 2019 / Momma
  2022 mixed cohorts that grouped it in).
- Else → 0.

## How the coach uses it

Frame as **progress, not deficit** (see behaviour-change guidance):
- 0–29: "Add a session this week — even 30 min/week is the research threshold"
- 30–60: "On target (literature sweet spot)"
- 60–140: "Above target — diminishing returns"
- 140+: gentle "plateau" line, no negative framing

Cite [[strength_training_mortality]] on the card.

## Safety bounds

- Informational card; no clinical prescription. No death-risk number.

## Honesty & uncertainty

- The **yoga half-credit is a heuristic** — easy to overfit; defer changes until data drives.
- **If the user does strength training but doesn't log it, the card is wrong** — the only
  fix is encouraging the logging habit, which is itself a self-monitoring behaviour-change
  technique (BCT 2.3).

## Bottom line

**Act on confidently:** a simple weekly tally of logged strength minutes vs 30–60 min/week
is enough to surface the under-tracked half of activity, framed as progress.

**Hold loosely:** the yoga half-credit, and any total when strength goes unlogged.

## Coach Directives

1. Tally `strength_min_weekly` from logged strength-type exercise (generic yoga half-credit
   at ≥30 min); show vs the **30–60 min/week** band. *(confidence: high)*
2. Frame **progress, not deficit**; no negative framing above the band. *(high)*
3. When strength may be unlogged, encourage the **logging habit** rather than asserting a
   deficit. *(moderate)*

## References

- Momma H, Kawakami R, Honda T, Sawada SS. *Muscle-strengthening activities are associated
  with lower risk and mortality in major non-communicable diseases: a systematic review and
  meta-analysis of cohort studies.* Br J Sports Med 2022;56(13):755–763. (Dose-response and
  sweet spot; see [[strength_training_mortality]].)
- Saeidifard F, Medina-Inojosa JR, West CP, et al. *The association of resistance training
  with mortality: A systematic review and meta-analysis.* Eur J Prev Cardiol
  2019;26(15):1647–1665. (Mixed-modality grouping behind the yoga half-credit.)

## Healthee implementation & honesty policy

- **Metric: `strength_min_weekly`** via `weekly_strength_minutes(end_date)` returning
  `{minutes, target_low: 30, target_high: 60, sessions, types}`. Surfaced on `/api/today`
  next to `mvpa` as a `strength` object (`week_min`, `target_low`, `target_high`, `sessions`,
  `types`, `research_note`). Compact card: "Strength · this week", `{n} / 30–60 min` (band
  shaded green when in), session count, cite-chip → [[strength_training_mortality]].
- **Honesty rules**: yoga half-credit is a heuristic; the card is only as good as logging
  (encourage the habit, don't assert a deficit); progress-not-deficit framing; no death-risk
  number.
- **Out of scope**: per-exercise volume tracking (sets × reps × weight — a separate
  feature); auto-classification from HC workouts (most users log strength manually).
