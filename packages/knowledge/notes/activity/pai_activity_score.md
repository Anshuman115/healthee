---
id: pai_activity_score
name: "Personalized Activity Intelligence (PAI)"
topic: Personalized Activity Intelligence (PAI) — composite weekly activity score with mortality validation
category: activity
grade: Established
evidence_grade: 3
summary: "PAI is a device-computed weekly activity score from HR-zone minutes, individualized to age + resting HR + max HR; unlike proprietary black-box scores it has direct mortality validation (HUNT3), where keeping PAI ≥ 100 per rolling 7 days is associated with ~17% lower all-cause and ~25% lower CV mortality."
aliases: ["pai", "personalized activity intelligence", "personal activity intelligence", "pai score", "hr-zone activity score", "pai_activity_score"]
tags: ["pai", "personalized activity intelligence", "personal activity intelligence", "pai score", "hr-zone activity score", "pai_activity_score"]
applies_to_metrics: ["pai_today", "pai_total", "minutes_low_zone", "minutes_moderate_zone", "minutes_high_zone"]
applies_to_interventions: ["aerobic_activity", "exercise_minutes"]
population: general
last_reviewed: 2026-07-15
related: ["mvpa_minutes_mortality", "vo2max", "non_exercise_vo2max"]
---

# Personalized Activity Intelligence (PAI)

## Summary

PAI is a single composite weekly activity score derived from heart-rate-zone minutes,
individualized to the user's age + resting HR + max HR. Unlike proprietary fitness scores,
PAI **has direct mortality validation** in a large cohort (HUNT3 study, n ≈ 40,000
Norwegian adults, ~26-year follow-up).

The headline finding: maintaining **PAI ≥ 100 per rolling 7 days** is associated with:
- **~17% lower all-cause mortality** vs PAI ≈ 0
- **~25% lower cardiovascular mortality** vs PAI ≈ 0
- **~5 years longer life expectancy** (women) / ~6 years (men)
- Effect persists after adjusting for total activity time — i.e. PAI captures
  intensity-weighted activity information that simple step count does not

## What it is

A 0–N continuous score updated daily based on the previous 7 days of HR-zone minutes:

> PAI accumulates faster when you spend time in higher HR zones (>~75% max HR) and decays
> as the trailing 7-day window slides forward.

Huami's exact formula is proprietary but the core methodology is published in Nes 2017.
Both the strap (Helio Strap) and Mi Band lines compute it **on-device** using your age +
max HR estimate. It is the **intensity-weighted** view of weekly activity, complementary to
the raw-time MVPA-minutes view ([[mvpa_minutes_mortality]]).

## Physiology / mechanism

PAI weights time by heart-rate zone, so higher-intensity minutes (which drive more
cardiorespiratory adaptation per minute) contribute disproportionately. Because it is
individualized to resting and maximum HR, a given absolute effort maps to the person's own
relative intensity — which is why it carries information beyond step volume and tracks the
fitness pathway ([[vo2max]]) that underlies the mortality benefit.

## The evidence

- **[Established]** **Maintaining PAI ≥ 100/week is associated with ~17% lower all-cause
  and ~25% lower cardiovascular mortality, and ~5–6 years' longer life expectancy**, with
  the effect **persisting after adjustment for total activity time** [Nes et al. 2017,
  HUNT3, n ≈ 40,000, ~26-yr follow-up].
- **[Established]** **Replicated in a US cohort** (Aerobics Center Longitudinal Study)
  [Kieffer et al. 2021].
- **[Established]** Estimated cardiorespiratory fitness (the mechanism PAI proxies)
  predicts CV mortality independent of traditional risk factors in the same HUNT cohort
  [Nauman et al. 2017].

## How we compute it

PAI is **device-computed, not Healthee-derived**: we read PAI_TODAY (today's accumulated
PAI), PAI_TOTAL (7-day rolling), and per-zone minutes (low / moderate / high) from
`HUAMI_PAI_SAMPLE`. Because it is a *validated, published* composite (Nes 2017) rather than
a Healthee-invented one, it is not subject to the no-composite-score rule — but it is
surfaced with its threshold and caveats, never as a bare proprietary number.

## How the coach uses it

- Surface **PAI_TOTAL** as a card with the **cutoff 100** (Nes 2017 threshold for the
  mortality benefit).
- Feed `pai_today`, `pai_total`, `minutes_moderate_zone`, `minutes_high_zone` into the
  correlation engine — they should associate positively with HRV, RHR improvement, and
  overall recovery markers.
- Present PAI alongside MVPA minutes ([[mvpa_minutes_mortality]]) as the intensity-weighted
  complement to raw activity time.

## Safety bounds

- PAI ≥ 100 is a **population-level** threshold, not a clinical target; never present it as
  a medical or death-risk figure.
- Do not issue clinical exercise prescriptions from PAI.

## Honesty & uncertainty

- **PAI depends on the user's max HR estimate.** The strap uses **220 − age** by default,
  which **under-estimates max HR by 5–10 bpm in many individuals** [Tanaka 2001]. If your
  real max HR is higher, PAI accumulates slower than it should.
- **HUNT3 was a Norwegian-ancestry cohort.** Generalizability is supported by the ACLS
  replication [Kieffer 2021], but the effect size may differ across populations.
- **100/week is a population threshold, not a clinical one.** Higher PAI is associated with
  further benefit up to ~150–200 in the studies, then plateaus.
- The exact Huami formula is proprietary — we consume the device output, not a transparent
  computation.

## Bottom line

**Act on confidently:** PAI is one of the few consumer activity scores with direct
mortality validation; PAI ≥ 100/week is the evidence-based aim, and it carries
intensity-weighted information beyond steps.

**Hold loosely:** the exact value given the 220−age max-HR under-estimate, cross-population
generalizability, and the proprietary formula details.

## Coach Directives

1. Surface **PAI_TOTAL vs the 100/week** threshold; treat 100 as an evidence-based aim, not
   a clinical target. *(confidence: high)*
2. Caveat that **220−age under-estimates max HR (5–10 bpm)** so PAI may accumulate slower
   than reality for some users. *(high)*
3. Present PAI as the **intensity-weighted complement** to MVPA minutes; never as a bare
   proprietary or death-risk number. *(high)*

## References

- Nes BM, Gutvik CR, Lavie CJ, Nauman J, Wisløff U. *Personalized Activity Intelligence
  (PAI) for Prevention of Cardiovascular Disease and Promotion of Physical Activity.* Am J
  Med 2017;130(3):328–336. https://pubmed.ncbi.nlm.nih.gov/27884383/
- Kieffer SK, Zisko N, Coombes JS, Nauman J, Wisløff U. *Personal Activity Intelligence and
  Mortality — Data from the Aerobics Center Longitudinal Study.* Prog Cardiovasc Dis
  2021;64:121–126. https://www.sciencedirect.com/science/article/pii/S0033062021000293
- Nauman J, Nes BM, Lavie CJ, et al. *Prediction of Cardiovascular Mortality by Estimated
  Cardiorespiratory Fitness Independent of Traditional Risk Factors: The HUNT Study.* Mayo
  Clin Proc 2017;92(2):218–227.
- Tanaka H, Monahan KD, Seals DR. *Age-predicted maximal heart rate revisited.* J Am Coll
  Cardiol 2001;37(1):153–156. (The 220−age under-estimate.)

## Healthee implementation & honesty policy

- **Device-provided, not derived**: `pai_today`, `pai_total`, and per-zone minutes
  (`minutes_low_zone` / `minutes_moderate_zone` / `minutes_high_zone`) are read from
  `HUAMI_PAI_SAMPLE`. Being a *published, validated* composite (Nes 2017), PAI is the
  documented exception to the no-composite rule — surfaced with its 100/week threshold and
  the max-HR caveat, never as a bare number.
- **Honesty rules**: 100/week is a population aim, not clinical; flag the 220−age max-HR
  under-estimate; present as the intensity-weighted complement to MVPA minutes; never a
  death-risk figure. (If PAI is not actively surfaced in the current app build, the science
  and validation still stand and it remains the intensity-weighted reference.)
