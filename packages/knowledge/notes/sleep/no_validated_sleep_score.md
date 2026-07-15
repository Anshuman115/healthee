---
id: no_validated_sleep_score
topic: No peer-reviewed composite "sleep score" exists for wearable data
evidence_grade: 3
applies_to_metrics: [sleep_score]
applies_to_interventions: []
tags: [sleep, scoring, no-evidence, decision-rationale]
last_reviewed: 2026-05-12
---

## Decision

We do not display a single "sleep score" on the dashboard. The literature
does not support any specific composite formula computed from wearable data.

This is a deliberate omission, parallel to our omission of a composite
"readiness" score: the components are individually validated, but combining
them into one number requires arbitrary weightings that no peer-reviewed
work has settled.

## What the literature actually validates

| Metric | Validated as | Reference |
| --- | --- | --- |
| Total sleep time (TST) vs mortality | Strong U-shaped curve, 7–9 h optimal | [[sleep_duration_mortality]] (Cappuccio 2010) |
| Sleep efficiency (TST/TIB) | Standard AASM clinical metric; > 85 % is good | AASM clinical practice |
| Wake After Sleep Onset (WASO) | Standard fragmentation marker | AASM clinical practice |
| Sleep Regularity Index (SRI) | All-cause mortality, cardiometabolic risk | [[sleep_regularity_index]] (Phillips 2017; Windred 2024) |
| Wearable stage classification | Macro-F1 0.26–0.69 for 4-class stage assignment vs PSG; directional, not exact | Chinoy 2021; JMIR 2023 multicenter |

The Pittsburgh Sleep Quality Index (PSQI, Buysse 1989) is well-validated but
is a 7-item self-report questionnaire over a 1-month recall window. Only
2 of its 7 components (duration, efficiency) can be derived from wearable
data, and even then it asks about subjective recall — not the night's
measurements. Useful for clinical surveys; not for daily wearable scoring.

The RU-SATED multidimensional sleep health framework (Buysse 2014) defines
six dimensions: **R**egularity, **S**atisfaction, **A**lertness, **T**iming,
**E**fficiency, **D**uration. Satisfaction and Alertness are subjective and
cannot be derived from wearables; the other four can. RU-SATED is the
organizing *schema* for our sleep dashboard, not a computed score.

## What about commercial sleep scores?

Whoop, Oura, Garmin, Zepp, and Fitbit all expose composite "sleep scores"
on a 0–100 scale. None of their formulas are documented in peer-reviewed
literature; all are proprietary product features without independent
validation. The validation papers that exist for these brands' devices
(Chinoy 2021, Robbins 2024, etc.) validate *individual outputs* — TST,
sleep efficiency, WASO, stage classification — never the composite scores.

This means: even when these brands' devices accurately measure individual
metrics, the score they compute from those metrics is editorial, not
scientific.

## What we surface instead

Per [[feedback_no_composite_score]], the dashboard's sleep area shows the
four wearable-computable RU-SATED dimensions individually:

1. **Duration**   — TST vs 7–9 h band, cite [[sleep_duration_mortality]]
2. **Efficiency** — TST / TIB, target > 85 %, cite AASM
3. **Regularity** — SRI on 7-day rolling window, cite [[sleep_regularity_index]]
4. **Timing**     — sleep midpoint vs personal baseline, cite [[sleep_consistency]]

Each can flag favorable / unfavorable / neutral against the user's personal
baseline, exactly like the Recovery card already does for HR / HRV.

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
