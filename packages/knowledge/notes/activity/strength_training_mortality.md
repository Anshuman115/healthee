---
id: strength_training_mortality
name: "Strength training and mortality"
topic: Muscle-strengthening (resistance) training and all-cause mortality
category: activity
grade: Established
summary: "Muscle-strengthening activity independently lowers all-cause mortality, separate from and additive to aerobic activity, with a J-shaped dose-response whose maximum risk reduction sits at ~30–60 min/week; above that the evidence is explicitly unclear, not a known harm. WHO recommends ≥2 days/week, and meeting both aerobic + strength targets carries the largest benefit."
aliases: ["strength training", "resistance training", "muscle strengthening", "weight training mortality", "strength_training_mortality"]
tags: ["strength training", "resistance training", "muscle strengthening", "weight training mortality", "strength_training_mortality"]
applies_to_metrics: ["strength_min_weekly"]
applies_to_interventions: ["exercise"]
population: general
last_reviewed: 2026-07-15
related: ["strength_training_for_runners", "strength_adherence_plan", "mvpa_minutes_mortality", "exercise_mortality"]
---

# Strength training and mortality

> **Scope / cross-link.** This note is the **health / longevity dose** of strength training
> (mortality). The sports-science note [[strength_training_for_runners]] covers the
> **performance dose** for runners (economy, durability). They differ (health-dose vs
> economy-dose) and are kept **separate** — merging blurs the advice.

## Summary

Muscle-strengthening activity (resistance training, calisthenics, weight-bearing yoga,
climbing) is independently associated with lower all-cause mortality, **separate from and
additive to** aerobic activity. The effect is non-monotone with a clear J-shape: benefit
appears early and the **maximum risk reduction sits at ~30–60 min/week**. Above that,
the meta-analysis says the influence of a higher volume "is unclear" — it does not name
a threshold at which benefit reverses, and neither should we.

WHO 2020 guidelines recommend muscle-strengthening activities on **≥2 days/week**, in
addition to aerobic MVPA. Most population-level cohort studies replicate the additive
benefit of meeting both targets vs only the aerobic one.

## What it is

Muscle-strengthening (resistance) activity is any exercise loading muscle against
resistance — free weights, machines, bodyweight/calisthenics, climbing, and
resistance-focused yoga. Tracked here as weekly minutes (`strength_min_weekly`), the
"under-tracked half" of the activity guidelines.

## Physiology / mechanism

The mortality benefit is **plural-pathway**: preserving muscle mass and preventing
sarcopenia, improving glycemic control and insulin sensitivity, raising bone density, and
reducing falls in older adults. Because these pathways differ from the cardiorespiratory
adaptations of aerobic work, strength benefit is **additive** to aerobic benefit rather
than redundant with it.

## The evidence

- **[Established]** **Any vs no muscle-strengthening activity**: all-cause mortality
  **HR 0.85 (95% CI 0.80–0.90) — 15% lower**; CVD HR 0.83 (0.73–0.93); cancer HR 0.86
  (0.78–0.95); diabetes incidence HR 0.83 (0.73–0.95) [Momma et al. 2022, 16 cohorts,
  n = 1.5M+ pooled person-years].
- **[Established]** **Dose-response peaks at 30–60 min/week** — "J-shaped associations
  with the maximum risk reduction (approximately 10-20%) at approximately 30-60 min/week
  of muscle-strengthening activities were found for all-cause mortality, CVD and total
  cancer" [Momma et al. 2022]. Above that the paper's own conclusion is that "the
  influence of a higher volume of muscle-strengthening activities on all-cause mortality,
  CVD and total cancer is **unclear** when considering the observed J-shaped
  associations". *[primary-source verified 2026-08-01 — this note previously put the
  attenuation at "~140 min/week" here and "~150 min/week" in the Summary, Bottom line and
  Coach Directive 3. Neither number is in Momma 2022; the paper names no attenuation
  threshold. Both removed rather than reconciled.]*
- **[Established]** **~15% reduction (HR ≈ 0.85)** for any vs no resistance training
  [Saeidifard et al. 2019, 11 studies].
- **[Established]** **Meeting both aerobic AND strength guidelines → ~40% lower all-cause
  mortality vs neither**; aerobic-only ~29%; strength-only ~11% [Liu et al. 2019,
  n = 479,856 NHIS].
- **[Established]** In older adults (≥65), **HR 0.81 (0.74–0.88)** [Kraschnewski et al.
  2016, n = 30,162 NHIS].

## How we compute it

`strength_min_weekly` is tallied from logged exercise entries classified as
strength-eligible (see [[strength_adherence_plan]] for the classifier and card). No
mortality number is derived; the evidence sets the 30–60 min/week reference band.

## How the coach uses it

- Surface weekly strength minutes vs the **30–60 min/week sweet spot**, citing this note.
- Frame strength as **"the under-tracked half of activity guidelines"** — most users hit
  MVPA targets but miss strength.
- Emphasise that **meeting both aerobic + strength** targets is where the Liu 2019 ~40%
  reduction lives (cite with [[mvpa_minutes_mortality]]).
- Do **not** push volume upward past the ~30–60 min/week sweet spot as though more were
  better — the marginal benefit above it is not established either way.

## Safety bounds

- No death-risk number is shown to the user.
- Do not issue clinical prescriptions; keep to the guideline reference band and general
  encouragement.

## Honesty & uncertainty

- **All cohort studies; no large RCT** directly testing strength training on mortality
  endpoints (would require decades of follow-up).
- **Self-report of strength training is noisier than aerobic**; effect sizes are likely
  under-estimated in cohorts asking only "resistance training, yes/no".
- **Mechanism is plural** — muscle/sarcopenia, glycemic control, bone density, falls — so
  attribution is not a single pathway.
- **The high-dose end of the J-curve rests on few cohorts** and may reflect over-training
  or reverse causation (injured athletes). Momma 2022 calls it "unclear" and names no
  threshold; **do not over-interpret as "strength training above N min/week is harmful."**

## Bottom line

**Act on confidently:** any strength training lowers mortality (~15%), additive to aerobic;
the sweet spot is ~30–60 min/week and ≥2 days/week; meeting both aerobic + strength is best.

**Hold loosely:** the shape of the curve above the ~30–60 min/week peak — the
meta-analysis calls it unclear and names no cut-point — and causality (all observational,
self-report noisy).

## Coach Directives

1. Surface strength minutes vs the **30–60 min/week sweet spot** (≥2 days/week); frame as
   the under-tracked half of the guidelines. *(confidence: high)*
2. Emphasise **both aerobic + strength** for the largest benefit (~40% vs neither). *(high)*
3. Frame ~30–60 min/week as where the measured benefit peaks; do **not** name a
   min/week ceiling — Momma 2022 calls the higher-volume evidence "unclear" and gives no
   threshold — and **don't imply high-dose strength is harmful**. *(moderate)*
4. Never show a death-risk number. *(high)*

## References

- Momma H, Kawakami R, Honda T, Sawada SS. *Muscle-strengthening activities are associated
  with lower risk and mortality in major non-communicable diseases: a systematic review and
  meta-analysis of cohort studies.* Br J Sports Med 2022;56(13):755–763.
- Saeidifard F, Medina-Inojosa JR, West CP, et al. *The association of resistance training
  with mortality: A systematic review and meta-analysis.* Eur J Prev Cardiol
  2019;26(15):1647–1665.
- Liu Y, Lee D, Li Y, et al. *Associations of resistance exercise with cardiovascular
  disease morbidity and mortality.* Med Sci Sports Exerc 2019;51(3):499–508.
- Kraschnewski JL, Sciamanna CN, Poger JM, et al. *Is strength training associated with
  mortality benefits? A 15-year cohort study of US older adults.* Prev Med 2016;87:121–127.
  n = 30,162 NHIS adults ≥65; HR 0.81 (0.74–0.88).

## Healthee implementation & honesty policy

- **Metric: `strength_min_weekly`** — tallied from logged exercise entries (classifier and
  card in [[strength_adherence_plan]]).
- **Honesty rules**: 30–60 min/week is the sweet spot, ≥2 days/week; frame as the
  under-tracked half; never a death-risk number; don't imply high-dose strength is harmful.
  This is the **health-dose** note; the runner **performance-dose** is
  [[strength_training_for_runners]] and the two are not merged.
