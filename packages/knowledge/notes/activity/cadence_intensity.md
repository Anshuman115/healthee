---
id: cadence_intensity
topic: Step cadence (steps/min) as a practical proxy for ambulatory exercise intensity
evidence_grade: 3
applies_to_metrics: [steps_per_minute, moderate_min, vigorous_min]
applies_to_interventions: []
tags: [methodology, cadence, mvpa, intensity]
last_reviewed: 2026-05-15
---

## Finding

Step cadence is a validated, device-independent proxy for ambulatory
exercise intensity in adults. The Tudor-Locke et al. CADENCE-Adults
treadmill calibration program (≈30 published validation papers,
2018–2023) established consensus thresholds tying cadence to metabolic
equivalents (METs):

| Cadence (spm)   | Intensity                | METs    |
|-----------------|--------------------------|---------|
| <100            | Below moderate (light)   | <3      |
| **≥100**        | **Moderate**             | ~3      |
| **≥130**        | **Vigorous**             | ~6      |
| ≥150            | Vigorous to very vigorous| ~7+     |

The 100-spm moderate threshold is a heuristic that holds across most
healthy adults aged 21–60. It systematically underestimates effort in
younger / fitter individuals and overestimates in older / heavier ones,
but the population-average error is small relative to the MET bin width.

## Effect size

- Tudor-Locke 2018 narrative review: 100 spm consistently corresponds to
  ~3.0–3.3 METs across 38 studies in healthy adults — close to the
  3-MET moderate-intensity boundary.
- CADENCE-Adults (Tudor-Locke 2019, n=78, 21–40 yrs): mean cadence at
  3 METs = 101.7 spm (95% CI 97.6–105.7).
- CADENCE-Adults 41–60 (O'Brien 2022, n=80): mean cadence at 3 METs =
  102 spm; at 6 METs = 129 spm.

## Evidence strength

- **Tudor-Locke C, Han H, Aguiar EJ, et al.** *How fast is fast enough?
  Walking cadence (steps/min) as a practical estimate of intensity in
  adults: a narrative review.* Br J Sports Med 2018;52(12):776–788. The
  100-spm moderate-intensity consensus piece.
- **Tudor-Locke C, Aguiar EJ, Han H, et al.** *Walking cadence
  (steps/min) and intensity in 21–40 year olds: CADENCE-adults.* Int J
  Behav Nutr Phys Act 2019;16:8.
- **O'Brien MW, Bray NW, Quirion I, et al.** *Step rate thresholds for
  moderate- and vigorous-intensity activity: CADENCE-Adults age 41–60
  years.* Int J Behav Nutr Phys Act 2022;19:128.
- **Saint-Maurice PF et al.** *Association of daily step count and step
  intensity with mortality among US adults.* JAMA 2020;323(12):1151–1160.
  Found peak 30-min cadence did **not** add prognostic value beyond
  total steps — see [[steps_mortality]]. So cadence is useful for
  **intensity classification**, not as an additional mortality
  predictor on top of step volume.

## Caveats

- **Wrist-based step detection is noisier than waist/hip.** Cadence
  derived from a wrist sensor (Helio Strap, most consumer wearables)
  has slightly lower correlation with treadmill ground truth than
  pedometer-style devices.
- The 100-spm threshold is calibrated to **walking on level ground**.
  Stair-climbing, uphill walking, and carrying loads can be ≥3 METs at
  lower cadences; cycling and rowing are zero-cadence MVPA invisible
  to step counting.
- Older adults (≥65) and people with mobility limitations may achieve
  3 METs at cadences as low as 80–90 spm.
- Single noisy spikes (e.g., a 30-second bus dash) shouldn't count;
  apply a minimum dwell time (≥1 min) before classifying a minute as
  moderate, matching the Stamatakis 2022 bout definition.

## Operational use

- For Helio Strap data: read per-minute step counts from
  `HUAMI_EXTENDED_ACTIVITY_SAMPLE` (Gadgetbridge). Treat each minute as
  **moderate** if steps ≥100 (per-minute cadence ≥100 spm) AND the
  preceding minute also ≥80 spm (debouncing). Treat as **vigorous** if
  steps ≥130 AND preceding minute ≥110 spm.
- Aggregate to daily `moderate_min` and `vigorous_min` derived metrics.
- Add HC workout sessions on top: each `session(kind='workout')` of
  intensity ≥moderate adds its full duration to the MVPA total
  regardless of cadence (covers non-walking MVPA: cycling, weights,
  swimming). Avoid double-counting walking workouts.
- Compose weekly MVPA = moderate_min + 2 × vigorous_min (WHO MET-
  equivalent rule); compare against the 150-min target from
  [[mvpa_minutes_mortality]].
- Cite this note as the derivation method when displaying MVPA.
