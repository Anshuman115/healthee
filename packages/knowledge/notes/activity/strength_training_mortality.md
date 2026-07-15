---
id: strength_training_mortality
topic: Muscle-strengthening (resistance) training and all-cause mortality
evidence_grade: 3
applies_to_metrics: []
applies_to_interventions: [exercise]
tags: [strength, resistance-training, mortality, sarcopenia]
last_reviewed: 2026-05-15
---

## Finding

Muscle-strengthening activity (resistance training, calisthenics,
weight-bearing yoga, climbing) is independently associated with lower
all-cause mortality, **separate from and additive to** aerobic activity.
The effect is non-monotone with a clear J-shape: benefit appears at
~30–60 min/week, peaks around 30–60 min/week, and plateaus or slightly
attenuates above ~150 min/week.

WHO 2020 guidelines recommend muscle-strengthening activities on **≥2
days/week**, in addition to aerobic MVPA. Most population-level cohort
studies replicate the additive benefit of meeting both targets vs only
the aerobic one.

## Effect size

- **Momma 2022 meta-analysis** (BJSM, 16 cohorts, n=1.5M+ pooled
  person-years):
  - Any vs no muscle-strengthening activity:
    - All-cause mortality: HR 0.85 (95% CI 0.80–0.90) — **15% lower**
    - CVD: HR 0.83 (95% CI 0.73–0.93)
    - Cancer: HR 0.86 (95% CI 0.78–0.95)
    - Diabetes incidence: HR 0.83 (95% CI 0.73–0.95)
  - **Dose-response peaks at 30–60 min/week**:
    - 30–60 min/week vs none: ~10–17% lower all-cause mortality
    - >140 min/week: benefit attenuates, may flatten or slightly reverse
- **Saeidifard 2019 meta-analysis** (Eur J Prev Cardiol, 11 studies):
  HR ≈ 0.85 (15% reduction) for any vs no resistance training.
- **Combined with aerobic** (Liu 2019, Mayo Clin Proc, n=479,856 from
  NHIS): people meeting both aerobic AND strength guidelines had ~40%
  lower all-cause mortality vs those meeting neither; meeting only
  aerobic gave ~29%; only strength gave ~11%.

## Evidence strength

- **Momma H, Kawakami R, Honda T, Sawada SS.** *Muscle-strengthening
  activities are associated with lower risk and mortality in major
  non-communicable diseases: a systematic review and meta-analysis of
  cohort studies.* Br J Sports Med 2022;56(13):755–763. The current
  strongest synthesis.
- **Saeidifard F, Medina-Inojosa JR, West CP, et al.** *The association
  of resistance training with mortality: A systematic review and meta-
  analysis.* Eur J Prev Cardiol 2019;26(15):1647–1665.
- **Liu Y, Lee D, Li Y, et al.** *Associations of resistance exercise
  with cardiovascular disease morbidity and mortality.* Med Sci Sports
  Exerc 2019;51(3):499–508.
- **Kraschnewski JL, Sciamanna CN, Poger JM, et al.** *Is strength
  training associated with mortality benefits? A 15-year cohort study
  of US older adults.* Prev Med 2016;87:121–127. n=30,162 NHIS adults
  ≥65; HR 0.81 (0.74–0.88).

## Caveats

- All cohort studies; no large RCT directly testing strength training
  on mortality endpoints (would require decades of follow-up).
- Self-report of strength training is noisier than aerobic activity;
  effect sizes likely under-estimated in cohorts that only ask "do you
  do resistance training, yes/no" without dose detail.
- Mechanism is plural — muscle mass / sarcopenia prevention, glycemic
  control, bone density, falls reduction in older adults. So the
  effect attribution is not just one pathway.
- The plateau/reversal at very high doses (>140 min/week) is based on
  few cohorts and may reflect over-training or reverse causation
  (athletes injured); should not be over-interpreted as "strength
  training above 2 h/week is harmful."

## Operational use

- Manual `healthee log exercise` entries with type ∈ {strength,
  weights, weightlifting, gym, resistance, calisthenics, climbing} are
  the canonical source. Yoga and pilates are mixed — count only if the
  user tags as "strength yoga" or duration ≥30 min (proxy for
  resistance-focused practice). Default behavior: don't auto-count
  generic "yoga" as strength.
- Surface weekly minutes vs the **30–60 min/week sweet spot** on the
  Activity / Today page, citing this note.
- Frame as "the under-tracked half of activity guidelines" — most
  users hit MVPA targets but miss strength.
- Do **not** push toward more than 150 min/week; the dose-response
  plateaus and the marginal benefit is small.
- Cite this note + [[mvpa_minutes_mortality]] together — meeting both
  targets is what the Liu 2019 ~40% reduction is anchored on.
