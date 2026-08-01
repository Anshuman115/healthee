---
id: cadence_intensity
name: "Step cadence as exercise-intensity proxy"
topic: Step cadence (steps/min) as a practical proxy for ambulatory exercise intensity
category: activity
grade: Established
summary: "Step cadence is a validated, device-independent proxy for ambulatory intensity: the Tudor-Locke CADENCE-Adults program ties ~100 spm to ~3 METs (moderate) and ~130 spm to ~6 METs (vigorous) in healthy adults — the basis of Healthee's cadence-based MVPA classification. (Health-intensity angle; the running-form meaning of cadence is a separate note.)"
aliases: ["cadence", "step cadence", "steps per minute", "spm", "walking cadence", "cadence intensity", "cadence_intensity"]
tags: ["cadence", "step cadence", "steps per minute", "spm", "walking cadence", "cadence intensity", "cadence_intensity"]
applies_to_metrics: ["steps_per_minute", "moderate_min", "vigorous_min"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
related: ["cadence", "mvpa_minutes_mortality", "mvpa_weekly_plan", "steps_mortality", "non_exercise_vo2max"]
---

# Step cadence as exercise-intensity proxy

> **Scope / cross-link.** This note is cadence as a **health / MVPA-intensity** proxy
> (steps-per-minute → METs). The sports-science note [[cadence]] covers cadence as a
> **running-form** metric (stride turnover, injury/economy). They are complementary and
> kept **separate** — do not merge; different question, different evidence.

## Summary

Step cadence is a validated, device-independent proxy for ambulatory exercise intensity in
adults. The Tudor-Locke et al. CADENCE-Adults treadmill calibration program (≈30 published
validation papers, 2018–2023) established consensus thresholds tying cadence to metabolic
equivalents (METs):

| Cadence (spm)   | Intensity                | METs    |
|-----------------|--------------------------|---------|
| <100            | Below moderate (light)   | <3      |
| **≥100**        | **Moderate**             | ~3      |
| **≥130**        | **Vigorous**             | ~6      |
| ≥150            | Vigorous to very vigorous| ~7+     |

The 100-spm moderate threshold is a heuristic that holds across most healthy adults aged
21–60. It systematically underestimates effort in younger / fitter individuals and
overestimates in older / heavier ones, but the population-average error is small relative
to the MET bin width.

## What it is

Cadence is the number of steps taken per minute (`steps_per_minute`). Used here as an
**intensity classifier**: each minute of ambulation is binned to light / moderate /
vigorous by its cadence, which is how Healthee derives MVPA minutes from the per-minute
step stream ([[mvpa_weekly_plan]]).

## Physiology / mechanism

Walking/running metabolic cost rises with speed, and at a given stature speed rises with
cadence — so steps/min tracks the oxygen cost (METs) of ambulation closely enough to bin
intensity. The relationship is calibrated to level-ground walking; anything that changes
the work per step at a given cadence (grade, load, stairs) shifts the true MET level away
from the cadence estimate.

## The evidence

- **[Established]** **100 spm consistently corresponds to ~3.0–3.3 METs** across 38 studies
  in healthy adults — close to the 3-MET moderate boundary [Tudor-Locke et al. 2018,
  narrative review].
- **[Established]** **Mean cadence at 3 METs = 101.7 spm (95% CI 97.6–105.7)** in 21–40 year
  olds [Tudor-Locke et al. 2019, CADENCE-Adults, n = 78].
- **[Established]** **Mean cadence at 3 METs = 102 spm; at 6 METs = 129 spm** in 41–60 year
  olds [O'Brien et al. 2022, CADENCE-Adults, n = 80].
- **[Established]** **Peak 30-min cadence did NOT add prognostic value beyond total steps**
  for mortality [Saint-Maurice et al. 2020] — so cadence is useful for **intensity
  classification**, not as an additional mortality predictor on top of step volume (see
  [[steps_mortality]]).

## How we compute it

For Helio Strap data: read per-minute step counts from `HUAMI_EXTENDED_ACTIVITY_SAMPLE`.
Treat each minute as **moderate** if steps ≥ 100 (per-minute cadence ≥ 100 spm) AND the
preceding minute also ≥ 80 spm (debouncing); **vigorous** if steps ≥ 130 AND preceding
minute ≥ 110 spm. Aggregate to daily `moderate_min` / `vigorous_min`. Add HC/logged workout
sessions on top (each `session(kind='workout')` of intensity ≥ moderate adds its full
duration regardless of cadence — covers non-walking MVPA: cycling, weights, swimming),
avoiding double-counting walking workouts. Compose weekly MVPA = `moderate_min + 2 ×
vigorous_min` (WHO MET-equivalent) vs the 150-min target ([[mvpa_minutes_mortality]]).

## How the coach uses it

- Use cadence-classified minutes as the derivation method behind displayed MVPA; **cite this
  note as the method**.
- Do **not** claim cadence adds longevity beyond step volume (it classifies intensity, it is
  not an extra mortality signal — [[steps_mortality]]).
- Apply a minimum dwell (≥1 min) before classifying a minute as moderate/vigorous, matching
  the Stamatakis 2022 bout definition.

## Safety bounds

- Cadence classification is an **estimate**, not a measured MET value; do not use it for
  clinical intensity prescription.

## Honesty & uncertainty

- **Wrist-based step detection is noisier than waist/hip.** Cadence from a wrist sensor
  (Helio Strap, most consumer wearables) correlates slightly less well with treadmill
  ground truth than pedometer-style devices.
- **The 100-spm threshold is calibrated to level-ground walking.** Stair-climbing, uphill
  walking, and carrying loads can be ≥3 METs at *lower* cadences; **cycling and rowing are
  zero-cadence MVPA invisible to step counting**.
- **Older adults (≥65) and people with mobility limitations** may reach 3 METs at cadences
  as low as 80–90 spm.
- **Single noisy spikes** (e.g. a 30-second bus dash) shouldn't count — apply a minimum
  dwell time (≥1 min).

## Bottom line

**Act on confidently:** ~100 spm ≈ moderate, ~130 spm ≈ vigorous in healthy adults — a
sound, device-independent way to bin ambulatory intensity for MVPA.

**Hold loosely:** the exact per-person threshold (age/fitness/grade shift it), wrist-sensor
noise, and any use beyond level-ground walking.

## Coach Directives

1. Classify per-minute ambulation by cadence (≥100 moderate, ≥130 vigorous) with a
   **≥1-min dwell/debounce**; add non-walking logged workouts. *(confidence: high)*
2. Cite this note as the **MVPA derivation method**; never claim cadence adds mortality
   benefit beyond step volume. *(high)*
3. Flag that grade/stairs/load and zero-cadence modalities (cycling, rowing) break the
   cadence→MET mapping. *(moderate)*

## References

- Tudor-Locke C, Han H, Aguiar EJ, et al. *How fast is fast enough? Walking cadence
  (steps/min) as a practical estimate of intensity in adults: a narrative review.* Br J
  Sports Med 2018;52(12):776–788. The 100-spm moderate-intensity consensus piece.
- Tudor-Locke C, Aguiar EJ, Han H, et al. *Walking cadence (steps/min) and intensity in
  21–40 year olds: CADENCE-adults.* Int J Behav Nutr Phys Act 2019;16:8.
- O'Brien MW, Bray NW, Quirion I, et al. *Step rate thresholds for moderate- and
  vigorous-intensity activity: CADENCE-Adults age 41–60 years.* Int J Behav Nutr Phys Act
  2022;19:128.
- Saint-Maurice PF, Troiano RP, Bassett DR, et al. *Association of daily step count and step
  intensity with mortality among US adults.* JAMA 2020;323(12):1151–1160. Peak 30-min
  cadence did not add prognostic value beyond total steps — see [[steps_mortality]].

## Healthee implementation & honesty policy

- **Metric role**: `steps_per_minute` (per-minute, `source='gadgetbridge'` from
  `HUAMI_EXTENDED_ACTIVITY_SAMPLE`) → binned to `moderate_min` / `vigorous_min` by the
  cadence thresholds above (debounced), the derivation feeding [[mvpa_weekly_plan]].
- **Honesty rules**: cadence is an intensity *proxy*, not a measured MET; wrist detection is
  noisier than hip; grade/stairs/load and non-ambulatory modalities break the mapping; cite
  this note as the method when displaying MVPA. This is the **health/MVPA** meaning of
  cadence — the running-form meaning lives in [[cadence]] and the two are not merged.
