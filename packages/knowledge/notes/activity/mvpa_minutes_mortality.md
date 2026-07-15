---
id: mvpa_minutes_mortality
topic: Moderate-to-vigorous physical activity minutes (MVPA) and the 150 min/week target
evidence_grade: 3
applies_to_metrics: [moderate_min, vigorous_min, mvpa_min, steps_per_minute]
applies_to_interventions: [exercise]
tags: [mvpa, activity, mortality, who-guidelines]
last_reviewed: 2026-05-15
---

## Finding

Weekly minutes of moderate-to-vigorous physical activity (MVPA) is one of
the most robust modifiable predictors of all-cause and cardiovascular
mortality, with a clear dose-response curve. The WHO 2020 guidelines
recommend **≥150–300 min/week of moderate** OR **≥75–150 min/week of
vigorous** activity (or any combination). The lower end of that band is
where most of the mortality benefit is realized; benefit continues to
accrue at higher doses with diminishing returns.

Distinct from total steps in two ways:
1. MVPA is **intensity-anchored** (≥3 METs for moderate, ≥6 METs for
   vigorous), not volume-anchored.
2. **Vigorous bouts as short as 1–2 minutes** independently track lower
   mortality even outside structured exercise (Stamatakis 2022).

## Effect size

- **Garcia 2023 meta-analysis** (BJSM, pooled prospective cohorts):
  - 150 min/week moderate vs none: ~22–31% lower all-cause mortality
  - 300 min/week moderate vs none: ~26–35% lower (plateau begins)
  - Benefit curve is steepest in the **0 → 150 min/week** range
- **Stamatakis 2022** (Nat Med, n=71,893 UK Biobank wearables):
  - Median 4.4 min/day of "vigorous intermittent lifestyle physical
    activity" (VILPA) — non-exercise vigorous bouts — associated with
    HR 0.62 (95% CI 0.55–0.71) for all-cause mortality vs no VILPA.
  - **Even 1–2 minute vigorous bouts count**; doesn't have to be a
    structured workout.
- **Saint-Maurice 2020** (JAMA, n=4,840 NHANES with accelerometers):
  - 8,000 vs 4,000 steps/day → 51% lower mortality
  - **Step intensity (cadence) added no independent benefit beyond total
    MVPA volume** — see [[steps_mortality]]. So MVPA captures the
    intensity signal that raw steps miss.

## Evidence strength

- **Garcia L, Pearce M, Abbas A, et al.** *Non-occupational physical
  activity and risk of cardiovascular disease, cancer and mortality
  outcomes: a dose-response meta-analysis of large prospective studies.*
  Br J Sports Med 2023;57(15):979–989. DOI: 10.1136/bjsports-2022-105669.
  Pooled 196 prospective studies.
- **Bull FC, Al-Ansari SS, Biddle S, et al.** *World Health Organization
  2020 guidelines on physical activity and sedentary behaviour.*
  Br J Sports Med 2020;54(24):1451–1462. Sets the 150-min/week target.
- **Stamatakis E, Ahmadi MN, Gill JMR, et al.** *Association of wearable
  device-measured vigorous intermittent lifestyle physical activity with
  mortality.* Nat Med 2022;28:2521–2529.
- **Strain T, Wijndaele K, Sharp SJ, et al.** *Impact of follow-up time
  and analytical approaches to account for reverse causality on the
  association between physical activity and health outcomes in UK
  Biobank.* Int J Epidemiol 2020;49(1):162–172. Confirms accelerometer-
  measured MVPA effect after reverse-causality adjustments.

## Caveats

- Observational. Reverse-causation bias is reduced by accelerometer
  cohorts (Strain 2020) but not eliminated.
- "Moderate-intensity" is defined as ≥3 METs in research, but consumer-
  wearable derivation depends on the proxy (HR zones, cadence, or sensor
  fusion). Cadence-based MVPA is a reasonable but imperfect proxy — see
  [[cadence_intensity]].
- WHO's combined-intensity arithmetic ("1 min vigorous = 2 min moderate")
  is a practical simplification, not a precise biological equivalence.

## Operational use

- Display weekly MVPA minutes (moderate + 2×vigorous, WHO MET-equivalent
  rule) vs a 150-min target on the Activity and/or Today page.
- Frame the target as the **lower bound of clinically meaningful**, not
  a maximum; the dose-response continues past 300 min/week with smaller
  marginal gains.
- Surface progress weekly, not daily — single days don't move the
  mortality math.
- Cite this note + [[cadence_intensity]] when displaying derived MVPA.
- Pair with [[pai_activity_score]]: PAI is the intensity-weighted weekly
  composite; MVPA minutes are the raw-time view. Both are valid; PAI is
  more sensitive to intensity differences.
