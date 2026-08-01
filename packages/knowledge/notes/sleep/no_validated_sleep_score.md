---
id: no_validated_sleep_score
name: "No validated composite sleep score"
topic: No peer-reviewed composite "sleep score" exists for wearable data
category: sleep
grade: Established
summary: "No peer-reviewed composite formula turns wearable data into a single 'sleep score'; the components (duration, efficiency, WASO, SRI) are individually validated but combining them needs arbitrary weightings no study has settled — so Healthee shows the four wearable-computable RU-SATED dimensions separately, never a 0–100 black box."
aliases: ["sleep score", "no sleep score", "0-100 sleep score", "composite sleep score", "whoop sleep score", "oura sleep score", "sleep score validity", "why no sleep score", "RU-SATED"]
applies_to_metrics: ["sleep_health_score_4dim"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
related: ["sleep_health_score_multidim", "sleep_score_implementation_plan", "sleep_regularity_index", "sleep_duration_mortality", "sleep_consistency", "wearable_sleep_stage_validity", "recovery_readiness"]
tags: [sleep, scoring, no-evidence, decision-rationale]
---

# No validated composite sleep score

## Summary

We do **not** display a single "sleep score" on the dashboard. The literature does
not support any specific composite formula computed from wearable data. This is a
deliberate omission, parallel to our omission of a composite "readiness" score
(see `recovery_readiness`): the components are individually validated, but
combining them into one number requires arbitrary weightings that no peer-reviewed
work has settled. This is a **core product honesty stance**, not a feature gap —
the same bar that lets `recovery_score` ship (published per-component science +
transparent weighting + a visible breakdown) is the bar a "sleep score" fails, so
instead we surface the four wearable-computable RU-SATED dimensions individually,
each flaggable favorable / unfavorable / neutral against the user's own baseline.

## What it is

A "sleep score" is the single 0–100 number that Whoop, Oura, Garmin, Zepp, and
Fitbit each show for a night. It is an **editorial product composite**, not a
measured physiological quantity: a proprietary weighted blend of duration,
efficiency, timing, and stage estimates. This note is the decision record for why
Healthee refuses to render one, and what it renders instead.

## Physiology / mechanism

There is no "sleep quality organ" and no ground-truth referent for a composite
number — a sleep score has no unit and nothing to be validated *against*. Each
input it blends does track a real strand of sleep health (total sleep time,
continuity, circadian timing, regularity), but those strands are partly
independent and carry distinct information (see `sleep_regularity_index`,
`sleep_health_score_multidim`), so collapsing them into one figure is a modelling
choice about weighting, not a measurement. That is precisely why the weighting
cannot be "validated" the way TST or efficiency can.

## The evidence

### What the literature actually validates [Established]

| Metric | Validated as | Reference |
| --- | --- | --- |
| Total sleep time (TST) vs mortality | Strong U-shaped curve, 7–9 h optimal | `sleep_duration_mortality` (Cappuccio 2010) |
| Sleep efficiency (TST/TIB) | Long-standing AASM *clinical-consensus* reference point, not an outcome-validated cutoff: < 85 % is listed as a common insomnia complaint and > 80–85 % as a treatment goal | Schutte-Rodin 2008, J Clin Sleep Med 4(5):487–504, PMID 18853708 (AASM clinical guideline) |
| Wake After Sleep Onset (WASO) | Standard fragmentation marker; the guideline's complaint level is > 30 min | Schutte-Rodin 2008 (as above) |
| Sleep Regularity Index (SRI) | All-cause mortality, cardiometabolic risk | `sleep_regularity_index` (Phillips 2017; Windred 2024) |
| Wearable stage classification | Macro-F1 0.26–0.69 for 4-class stage assignment vs PSG; directional, not exact | Chinoy 2021; JMIR 2023 multicenter |

### The self-report questionnaires don't transfer [Established]

The Pittsburgh Sleep Quality Index (PSQI, Buysse 1989) is well-validated but is a
7-item self-report questionnaire over a 1-month recall window. Only 2 of its 7
components (duration, efficiency) can be derived from wearable data, and even then
it asks about subjective recall — not the night's measurements. Useful for
clinical surveys; not for daily wearable scoring.

### RU-SATED is a schema, not a computed score [Established]

The RU-SATED multidimensional sleep health framework (Buysse 2014) defines six
dimensions: **R**egularity, **S**atisfaction, **A**lertness, **T**iming,
**E**fficiency, **D**uration. Satisfaction and Alertness are subjective and cannot
be derived from wearables; the other four can. RU-SATED is the organizing *schema*
for our sleep dashboard, not a computed score. (A pre-specified, binary
sum-of-dimensions version — a *different* scientific object from the proprietary
continuous scores rejected here — is reviewed in `sleep_health_score_multidim` and
`sleep_score_implementation_plan`; the two are complementary, not contradictory,
and we still do not display a continuous 0–100 score.)

### Commercial sleep scores are unvalidated composites [Contested]

Whoop, Oura, Garmin, Zepp, and Fitbit all expose composite "sleep scores" on a
0–100 scale. None of their formulas are documented in peer-reviewed literature;
all are proprietary product features without independent validation. The
validation papers that exist for these brands' devices (Chinoy 2021, Robbins 2024,
etc.) validate *individual outputs* — TST, sleep efficiency, WASO, stage
classification — never the composite scores. This means: even when these brands'
devices accurately measure individual metrics, the score they compute from those
metrics is editorial, not scientific.

## How we compute it

We do not compute a single continuous sleep score. Instead the dashboard's sleep
area shows the four wearable-computable RU-SATED dimensions individually (per
`feedback_no_composite_score`):

1. **Duration**   — TST vs 7–9 h band, cite `sleep_duration_mortality`
2. **Efficiency** — TST / TIB, target > 85 %, cite Schutte-Rodin 2008 (AASM guideline)
3. **Regularity** — SRI on 7-day rolling window, cite `sleep_regularity_index`
4. **Timing**     — sleep midpoint vs personal baseline, cite `sleep_consistency`

Each can flag favorable / unfavorable / neutral against the user's personal
baseline, exactly like the Recovery card already does for HR / HRV. The one
composite we *do* ship — the 0–4 binary `sleep_health_score_4dim` — is always
rendered with its four contributing dimensions and their citations, never as a
standalone validated number (see `sleep_score_implementation_plan`).

## How the coach uses it

- **Never** report or endorse a device's 0–100 "sleep score" as if it were a
  measurement; if a user cites their Oura/Whoop/Zepp score, explain it is an
  editorial composite and redirect to the individual dimensions.
- Discuss sleep through the **four dimensions** (duration, efficiency, regularity,
  timing), each against the user's own baseline, with its citation available.
- When asked "what's my sleep score", answer with the dimension breakdown and the
  4-dim count if shown — not a fabricated single number.

## Safety bounds

No physiological guardrail attaches to this note directly. The relevant hard rule
is a **product-integrity** one: never surface an unvalidated composite as a
measured quantity. Sleep-loss safety bounds live in `sleep_and_recovery` and
`sleep_need_debt`.

## Honesty & uncertainty

- The refusal is itself a confidence statement: we are certain the *components* are
  valid and equally certain the *composite weighting* is unsettled.
- Even accurate per-metric measurement does not license a composite — accuracy of
  inputs and validity of a blend are different questions.
- Wearable stage classification is noisy (macro-F1 0.26–0.69 vs PSG; Chinoy 2021),
  so any score leaning on stage percentages inherits that noise.
- This note rejects **proprietary continuous** scores; it does not reject the
  pre-specified **binary** RU-SATED-style sum (`sleep_health_score_multidim`),
  which is a distinct object with its own cutoff literature.

## Bottom line

**Act on confidently:** the individual sleep metrics (TST vs 7–9 h, efficiency
>85 %, WASO, SRI) are validated and should be shown separately, each against the
user's baseline. No peer-reviewed composite 0–100 sleep score exists — refusing to
display one is the honest choice.

**Hold loosely:** nothing here is uncertain in the science; what is "held loosely"
is any future composite — it may only ship if it clears the transparency bar
(published components + visible breakdown), never as a black box.

## Coach Directives

1. Never present or endorse a 0–100 composite "sleep score" (Whoop/Oura/Garmin/
   Zepp/Fitbit or our own) as a measured or validated number. *(confidence: high)*
2. Discuss sleep via the four wearable-computable RU-SATED dimensions, each vs the
   user's own baseline, with citations. *(high)*
3. If a user quotes a device sleep score, explain it is proprietary/editorial and
   redirect to the individual metrics. *(high)*
4. The only composite we may show — `sleep_health_score_4dim` — always rides with
   its four dimensions and their sources, never alone. *(high)*

## References

- Buysse DJ, Reynolds CF 3rd, Monk TH, Berman SR, Kupfer DJ. *The Pittsburgh
  Sleep Quality Index: a new instrument for psychiatric practice and
  research.* Psychiatry Res 28(2):193-213 (1989). PMID 2748771.
- Mollayeva T, Thurairajah P, Burton K, et al. *The Pittsburgh sleep
  quality index as a screening tool for sleep dysfunction in clinical
  and non-clinical samples: a systematic review and meta-analysis.*
  Sleep Med Rev 25:52-73 (2016).
  https://pubmed.ncbi.nlm.nih.gov/26163057/
- Chinoy ED, Cuellar JA, Huwa KE, et al. *Performance of seven consumer
  sleep-tracking devices compared with polysomnography.* Sleep
  44(5):zsaa291 (2021).
  https://academic.oup.com/sleep/article/44/5/zsaa291/6055610
- Buysse DJ. *Sleep health: can we define it? Does it matter?* Sleep
  37(1):9-17 (2014). RU-SATED framework.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC7289662/
- Schutte-Rodin S, Broch L, Buysse D, Dorsey C, Sateia M. *Clinical guideline for
  the evaluation and management of chronic insomnia in adults.* J Clin Sleep Med
  4(5):487-504 (2008). PMID 18853708. The AASM document behind the 85 % sleep-
  efficiency and 30 min WASO reference points, which this note previously cited
  only as "AASM clinical practice" *(sourced 2026-08-01)*.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC2576317/

## Healthee implementation & honesty policy

- **No `sleep_score` composite field is derived** — the legacy `sleep_score` name
  is deprecated; the dashboard reads the four dimension rows and the transparent
  binary `sleep_health_score_4dim` (0–4) instead (`derive/sleep_score.py`, see
  `sleep_score_implementation_plan`).
- **Honesty rule (mirrored in UI + LLM):** never render or repeat a 0–100 composite
  sleep score as a measurement; the only shipped composite is the 0–4 binary sum,
  and it is **always** shown with its four contributing dimensions and per-dimension
  citations — the same "no bare composite number" contract used for
  `recovery_score` (see `recovery_readiness`) and biological age.
- This is a **documented, deliberate product omission**, not an unimplemented
  feature: parity with the no-composite-readiness stance.
