---
id: cadence_derived_speed
name: "Cadence-derived speed as a workload input"
topic: Whether step cadence can stand in for measured speed as the continuous workload axis of a submaximal VO2max fit — the walk ratio, the fixed-stride error, and why the device-native fitness models do not use this chain
category: activity
grade: Probable
summary: "Cadence bins intensity well but does not measure speed. Step length is not a constant — it rises with cadence (the walk ratio is the invariant, not the stride), so a fixed stride is wrong by construction, and the resulting speed error propagates into any VO₂↔HR regression as a multiplicative error on the slope. Adequate for a daily-distance total; not adequate as the workload axis of an extrapolation to HRmax."
aliases: ["cadence to speed", "cadence derived speed", "stride length assumption", "walk ratio", "cadence speed conversion", "cadence_derived_speed", "cadence workload"]
tags: ["cadence to speed", "cadence derived speed", "stride length assumption", "walk ratio", "cadence speed conversion", "cadence_derived_speed", "cadence workload"]
applies_to_metrics: ["steps_per_minute", "vo2max_submax", "vo2max_estimate", "distance_m_daily"]
applies_to_interventions: []
population: general
last_reviewed: 2026-08-02
related: ["cadence_intensity", "distance_from_steps", "submaximal_vo2max", "non_exercise_vo2max", "cadence"]
---

# Cadence-derived speed as a workload input

> **Scope / cross-link.** Three notes touch cadence and they answer different questions.
> [[cadence_intensity]] bins a minute into light/moderate/vigorous (a coarse MET bin).
> [[distance_from_steps]] turns a day's steps into a distance total and owns the
> canonical step-length constant. **This note asks a third question**: can cadence
> substitute for *measured* speed as a continuous workload value, precise enough to be
> the x-axis of a regression? A ±15% error is fine for the first two and is not fine
> here, which is why this is its own note rather than a caveat inside them.

## Summary

Step cadence is a good **intensity classifier** and a workable **distance** input, but it
is a weak **speed** input. Walking speed is step length × cadence, and step length is not
a person-level constant: during free walking the *ratio* of step length to cadence is what
stays roughly invariant, so step length rises as cadence rises. A fixed stride constant
therefore mis-states speed in a cadence-dependent way, and when that speed is converted to
VO₂ by the ACSM equation and regressed against heart rate, the error lands on the
regression **slope** — which is then multiplied by the distance from the observed heart
rates out to HRmax. The published device-native fitness models that do work from heart
rate and steps do **not** use a cadence→speed→ACSM chain; they learn heart-rate-response
features directly and are not publicly available. On this project's data, cadence-derived
speed did not support a usable submaximal fit on any walking bout (see the implementation
section, and [[submaximal_vo2max]] for the method it would feed).

## What it is

The conversion `speed = cadence × step_length`, used to recover a walking speed when no
GPS track is available. It is the input the submaximal HR-vs-workload method
([[submaximal_vo2max]]) would need in order to run on ordinary walking rather than only on
recorded outdoor workouts. The question this note answers is not whether the conversion is
*possible* — it is arithmetic — but whether its error is small enough for the use.

## Physiology / mechanism

People speed up in two ways at once: they take more steps per minute and they take longer
steps. Gait research describes this with the **walk ratio** — step length divided by
cadence — which is approximately constant for a given person walking freely. The
consequence matters: if the ratio is the invariant, then **step length is a function of
cadence**, not a constant to be multiplied by it. Assuming a fixed stride therefore
under-states speed at high cadence and over-states it at low cadence, in a way that
correlates with the very variable being regressed.

A second mechanism compounds it. The ACSM level-walking equation makes VO₂ a linear
function of speed, so the whole VO₂ axis is a rescaling of the cadence axis by whatever
stride constant was chosen. Choosing a different (equally defensible) stride does not
shift the fitted line — it **rotates** it, changing the slope, and the extrapolated value
at HRmax moves by the slope change times the reach from the observed heart rates to HRmax.
An input uncertainty that would be a modest percentage error on a distance total becomes a
large absolute error on an extrapolated VO₂max.

## The evidence

- **[Established]** **The walk ratio (step length ÷ cadence) is approximately invariant
  within a person during free walking**, which is precisely why step length is not
  independent of cadence [Sekiya et al. 1996; Sekiya & Nagasaki 1998].
- **[Established]** **That invariance has a floor.** Walk-ratio constancy breaks below
  roughly 62 m/min (about 98 steps/min); below that boundary a different gait-control
  strategy applies and the ratio should not be used to infer step length [Murakami & Otaka
  2017, J Phys Ther Sci 29(4):722–725]. Much of free-living ambulation sits below it.
- **[Established]** **Cadence near 140 steps/min marks the walk-to-run transition** in
  adults (heuristic range 135–140), and cadence predicted the transition better than speed
  or Froude number [Chase et al. 2023, Hum Mov Sci 90:103117]. This gives an objective line
  between "walking" and "running" in step data, with no GPS required.
- **[Established]** **Age-predicted HRmax carries a large individual error, and Tanaka
  2001 reports it itself.** The paper has two halves and only the first is a meta-analysis:
  that half regresses *group mean* values (351 studies, 492 groups, 18,712 subjects,
  r = −0.90) and gives no individual scatter. The second half is a laboratory
  cross-validation of 514 measured maximal tests, and it states that "there was substantial
  variation in HRmax across the entire age range, **with standard deviations ranging from 7
  to 11 beats/min**", with the discussion pricing the consequence at "the wide range of
  individual subject values around the regression line for HRmax (**SD ∼10 beats/min**)"
  and an underestimation that "could be >20 beats/min for some older adults" [Tanaka et al.
  2001]. Robergs & Landwehr 2002 independently put age-based univariate HRmax equations at
  **Sxy 7–11 b/min**, but their Table 3 lists Tanaka's own Sxy as *not reported* — so they
  corroborate the magnitude and are **not** the source of it. In an extrapolation this error
  is multiplied by the fitted slope, so it is *larger* for the fits that look best.
- **[Probable]** **The one peer-reviewed model that estimates fitness from wrist heart
  rate and steps does not go through a speed conversion.** Neshitov et al. 2023 (n = 3,115
  training) build a 24-feature vector — cadence-to-HR ratio quartiles and fifteen
  coefficients from piecewise quantile regressions of *heart-rate response to cadence* —
  and never estimate speed at all. Its error against laboratory VO₂max was **4.98
  mL/kg/min** (n = 10); the 3.95 figure is the held-out test set against another model's
  labels, not against measured VO₂max. **The data and trained model are not public**
  (Welltory Inc., available on request).
- **[Emerging]** **No published validation was found** for submaximal HR-vs-workload
  extrapolation driven by *cadence-derived* speed. The absence is worth stating plainly:
  the accuracy figures quoted for the wearable method ([[submaximal_vo2max]]) come from
  GPS- or treadmill-paced *running*, and do not transfer to this input.

## How we compute it

We do not compute a VO₂max from cadence-derived speed. Cadence is used where its error is
tolerable — intensity bins ([[cadence_intensity]]) and daily distance
([[distance_from_steps]], which owns the canonical `step_length_m ≈ 0.414 × height_m`) —
and the submaximal VO₂max fit ([[submaximal_vo2max]]) is restricted to inputs that carry a
**measured** speed. Where a fit cannot be made from measured speed, the value is withheld
rather than estimated from cadence.

## How the coach uses it

- Treat cadence as an **intensity band and a step count**, never as a speed measurement.
  "You averaged 118 steps per minute" is supportable; "you walked at 5.8 km/h" is not,
  unless a GPS track supplied the distance.
- When asked why there is no submaximal VO₂max from a day's walking, name the real reason:
  ordinary walking varies too little in workload for a slope to be fitted, and the speed
  behind it was not measured. Do not offer the cadence-derived number as a lesser estimate.
- If the owner wants the measurement to become available, the actionable answer is about
  **input, not settings**: a recorded outdoor session, or effort sustained above the
  walk-to-run transition, produces the workload range a fit needs.

## Safety bounds

- Any VO₂max presented to a user is a wellness estimate, never a clinical measure, and must
  never be used to clear someone for hard training. This is a rule for the coach, not a
  compiled guardrail — nothing in code enforces it from this note.
- A cadence-derived speed must not be presented as a measured pace anywhere in the product;
  the error is large enough that a user could act on it (e.g. pacing a run) and be wrong.

## Honesty & uncertainty

- **The stride constant is unmeasurable without GPS, and the choice changes the answer.**
  Three defensible step-length models applied to the same bout of this project's owner's
  data produced VO₂max estimates of 28.2, 34.3 and 47.7 mL/kg/min. The spread is a
  property of the assumption, not of the person.
- **Wrist cadence is not gait cadence.** Wrist-worn step detection is noisier than
  waist- or hip-worn ([[cadence_intensity]]), and arm movement without travel can register
  as steps. Where measured speed and wrist cadence disagree, either the gait or the sensor
  may be at fault and the data cannot distinguish them.
- **Level ground is assumed and usually wrong.** Without GPS there is no terrain lookup, so
  grade is taken as zero; hills raise heart rate at a given cadence and bias the fit.
- **Good fit statistics do not mean a good answer here.** A regression through a workload
  axis that barely varies can report a small residual scatter and a respectable r² while
  the slope — the only quantity the extrapolation actually uses — is essentially
  unidentified. Report the slope's uncertainty, not the fit's.
- **These magnitudes are from one person's data** (n = 1, 110 days). The direction is
  supported by mechanism and literature; the exact numbers are not a population claim.
- **This note argues against a method, not against the metric.** The submaximal method
  itself remains the better estimator when it has a measured speed ([[submaximal_vo2max]]).

## Bottom line

**Act on confidently:** cadence is a sound intensity classifier and an acceptable
distance input; step length rises with cadence rather than staying fixed; ~140 steps/min
separates walking from running in step data; age-predicted HRmax carries roughly ±10 bpm of
individual error (Tanaka's own 514-subject validation: SD 7–11 beats/min) that any
extrapolation multiplies.

**Hold loosely:** any speed inferred from cadence alone, and any quantity derived from it
that is sensitive to the slope of a fit rather than to a level. The specific error
magnitudes here come from a single person's data.

## Coach Directives

1. Never present a cadence-derived speed as a measured pace; cadence supports an intensity
   band and a step count. *(confidence: high)*
2. Do not derive or report a VO₂max from cadence-derived speed — withhold instead, and say
   which input is missing. *(high)*
3. When explaining a withheld submaximal estimate, name the workload range and the missing
   measured speed as the cause; do not imply the owner did something wrong. *(high)*
4. Use ~140 steps/min as the walking/running boundary when classifying a bout from step
   data alone, and state it as a heuristic. *(moderate)*
5. Flag that grade is assumed zero whenever no terrain source exists, and that level-ground
   assumptions bias a fit downward on hills. *(moderate)*

## References

- Sekiya N, Nagasaki H, Ito H, Furuna T. *The invariant relationship between step length
  and step rate during free walking.* J Hum Mov Stud 1996;30:241–257.
- Sekiya N, Nagasaki H. *Reproducibility of the walking patterns of normal young adults:
  test-retest reliability of the walk ratio (step-length/step-rate).* Gait Posture
  1998;7(3):225–227.
- Murakami R, Otaka Y. *Estimated lower speed boundary at which the walk ratio constancy is
  broken in healthy adults.* J Phys Ther Sci 2017;29(4):722–725. PMID 28533617.
  doi:10.1589/jpts.29.722
- Chase CJ, Aguiar EJ, Moore CC, Chipkin SR, Staudenmayer J, Tudor-Locke C, Ducharme SW.
  *Cadence (steps/min) as an indicator of the walk-to-run transition.* Hum Mov Sci
  2023;90:103117. PMID 37336086. doi:10.1016/j.humov.2023.103117
- Neshitov A, Tyapochkin K, Kovaleva M, Dreneva A, Surkova E, Smorodnikova E, Pravdin P.
  *Estimation of cardiorespiratory fitness using heart rate and step count data.* Sci Rep
  2023;13(1):15808. PMID 37737296. doi:10.1038/s41598-023-43024-x. Lab-validation error
  4.982 mL/kg/min (n=10); data and model not public.
- Robergs RA, Landwehr R. *The surprising history of the "HRmax=220−age" equation.*
  J Exerc Physiol Online 2002;5(2):1–10. Reports Sxy (standard error of estimate) of
  **7–11 b/min** across age-based univariate HRmax equations, ">10 b/min" for the
  majority, and their own re-regression over 30 equations at Sxy 7.2. Table 3 lists every
  Tanaka equation with **Sxy = N/A**. The paper never states a ±10–12 bpm SD and never
  attributes one to Tanaka. *(Full text read 2026-08-02, #112.)*
- Tanaka H, Monahan KD, Seals DR. *Age-predicted maximal heart rate revisited.* J Am Coll
  Cardiol 2001;37(1):153–156. PMID 11153730. doi:10.1016/S0735-1097(00)01054-8.
  Meta-analysis of **group mean** values (351 studies, 492 groups, 18,712 subjects,
  r = −0.90) **plus** a laboratory cross-validation in 514 measured subjects reporting
  "standard deviations ranging from 7 to 11 beats/min" and, in the discussion, "SD ∼10
  beats/min". **This is the primary source of the ±10 bpm individual spread.**
  *(Full text read 2026-08-02, #112.)*

## Open questions (deferred)

- Whether a **per-person** cadence→speed calibration learned from the owner's own GPS
  sessions would carry over to their non-GPS walking. Untested here; it would need enough
  GPS sessions to fit, which is the same input scarcity that motivates the question.
- Whether the Neshitov feature family (HR-response-to-cadence quantile regressions) could
  be re-derived on a wrist-strap population. Not attempted — the published model is not
  public and reconstructing it from the paper's description would be fabrication.

## Healthee implementation & honesty policy

- **No metric is derived from this conversion.** `vo2max_submax` is computed only from a
  measured-speed source ([[submaximal_vo2max]]); `distance_m_daily` uses the canonical
  height-based step length owned by [[distance_from_steps]]; `moderate_min`/`vigorous_min`
  use cadence bins from [[cadence_intensity]]. **This note introduces no new constant** —
  there is one step-length definition in the corpus and it is not here.
- **Measured on the owner's real data (2026-08-02, 110 days, ~459k samples, n = 1).**
  Reproduced with the shipped module's own gates:
  - 64 ambulation bouts of ≥10 min at ≥60 steps/min. Using the corpus's canonical step
    length (0.737 m at 178 cm), the gate attrition was 60 → 41 (HR range ≥15 bpm) → 22
    (positive slope) → **1** (r² ≥ 0.5), and that one bout peaked at 166 steps/min, i.e.
    it was running, not walking.
  - **Restricted to bouts that never exceed the 140 steps/min walk-to-run transition (54
    of 64), zero produced a usable fit at any r² threshold tested down to 0.2.**
  - The reason is the workload axis, not the heart rate: the VO₂ values within a bout had
    a median standard deviation of **0.28 mL/kg/min**, and 53 of 60 bouts were under 1.0.
    HR range was rarely the binding gate (41 of 64 cleared it); the median r² among bouts
    that reached a fit was **0.083**, and 19 of 41 had a *negative* slope.
  - Against GPS on the same sessions, cadence and measured speed diverge where it matters:
    speed was effectively flat (~96 m/min) across 100–150 steps/min, so the cadence axis
    moved while real workload did not.
  - Error budget on the single best bout: regression extrapolation ±3.4, HRmax uncertainty
    ±4.2, stride-length choice ±14.5 → combined **±15.5 mL/kg/min**, against the 5.6
    mL/kg/min SEE of the non-exercise model it would have replaced
    ([[non_exercise_vo2max]]).
- **Honesty rules (carry into UI + LLM)**: never show a cadence-derived pace as measured;
  never fill a withheld VO₂max with a cadence-derived one; when the submaximal estimate is
  unavailable, say which input is missing rather than showing a weaker number — "not enough
  data" outranks an optimistic guess. The measured figures above are **one owner's**, and
  any claim built on them says so.
