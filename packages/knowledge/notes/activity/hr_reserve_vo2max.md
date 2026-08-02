---
id: hr_reserve_vo2max
name: "VO₂max from heart-rate reserve (%HRR = %VO₂R)"
topic: The Swain %HRR/%VO₂R equivalence, inverted to estimate VO₂max from single steady windows — what it is validated for, and why walking is not it
category: activity
grade: Contested
summary: "%HRR ≈ %VO₂R lets every steady window of a session give an independent VO₂max with no regression and no load range — but the equivalence is contested (the largest test, n=737, rejects identity and finds %HRR runs 6–8 points high), it is validated only over roughly 35–95% of reserve on incremental maximal tests, it fails during prolonged constant-load exercise, and measured on real free-living walks it under-reads VO₂max by 17–30 mL/kg/min. Usable for running, refused for walking."
aliases: ["hrr vo2r", "%hrr = %vo2r", "heart rate reserve vo2max", "karvonen vo2max", "vo2 reserve", "swain equivalence", "reserve vo2max", "vo2max_reserve", "hr_reserve_vo2max"]
tags: ["hrr vo2r", "heart rate reserve", "vo2 reserve", "swain", "karvonen", "vo2max", "walking"]
applies_to_metrics: ["vo2max_submax", "vo2max_estimate", "hr", "rhr_daily", "max_hr"]
applies_to_interventions: []
population: general
last_reviewed: 2026-08-02
related: ["submaximal_vo2max", "non_exercise_vo2max", "vo2max", "cadence_derived_speed", "maximum-heart-rate"]
---

# VO₂max from heart-rate reserve (%HRR = %VO₂R)

## Summary

The Karvonen fraction of heart-rate reserve is widely taken to equal the fraction of
oxygen-uptake **reserve** — not of VO₂max. If that holds, it can be inverted: each steady
window of a session gives `VO₂max = VO₂rest + (VO₂ − VO₂rest) / %HRR`, independently, with
**no regression and no need for the workload to vary**. That is the attraction, because a
graded HR-vs-workload fit ([[submaximal_vo2max]]) needs load to rise in steps and an
ordinary walk never supplies it.

The attraction does not survive contact with the evidence at walking intensity. The
equivalence is **contested**: the two founding studies fitted regressions that included a
resting anchor point, which mechanically drags slope toward 1 and intercept toward 0, and
the largest study to exclude that anchor (n = 737) rejects identity and finds %HRR runs
**6–8 percentage points above** %VO₂R with an inter-individual SD of 7.5–11.3 points,
widest at low intensity. It is validated over roughly **35–95% of reserve** on *incremental
maximal tests*, it demonstrably **fails during prolonged constant-load exercise**, and the
walking-specific literature reports correlations as low as **r = 0.31**.

Measured on real free-living data it fails exactly where that predicts: it agrees with an
independent instrument on running and under-reads by 17–30 mL/kg/min on walking. Healthee
therefore uses it as a **fallback for running sessions only** and **withholds on walks**.

## What it is

Three fractions get confused and the distinction is the whole point:

| fraction | definition |
|---|---|
| %HRmax | HR / HRmax |
| **%HRR** | (HR − HRrest) / (HRmax − HRrest) — Karvonen's *reserve* |
| %VO₂max | VO₂ / VO₂max |
| **%VO₂R** | (VO₂ − VO₂rest) / (VO₂max − VO₂rest) — the *oxygen* reserve |

Swain & Leutholtz's claim is that **%HRR maps onto %VO₂R, not onto %VO₂max**. Both are
"fraction of the way from rest to maximum", so the pairing is theoretically the natural
one. Rearranged for our purpose it becomes a VO₂max estimator that consumes one window at
a time.

## Physiology / mechanism

Between rest and maximum, cardiac output and oxygen uptake rise together, and heart rate
carries most of the cardiac-output rise once stroke volume plateaus. Both ratios are
therefore normalised to the same span — from an individual's own resting state to their
own ceiling — which is why the reserve-to-reserve pairing is better behaved than pairing
a reserve fraction against a raw maximum fraction.

The mechanism also names the failure. Heart rate rises with oxygen demand, but it *also*
rises with core temperature, dehydration, posture, arousal and time-on-feet — none of
which consume oxygen. At high workloads the metabolic component dominates and the
non-metabolic offset is a rounding error. At walking workloads (~3–4 METs, roughly a
quarter of a healthy adult's reserve) the metabolic component is small, and a 20–30 bpm
non-metabolic offset is **larger than the signal**. The inversion divides by that
contaminated fraction, so the error does not merely widen — it biases VO₂max downward,
hard.

## The evidence

- **[Probable]** **%HRR tracks %VO₂R better than it tracks %VO₂max.** On a cycle
  ergometer (n = 63, incremental to max) the %HRR–%VO₂R regression had slope 1.00 ± 0.01
  and intercept −0.1 ± 0.6, *not distinguishable from the line of identity*, while
  %HRR–%VO₂max gave slope 1.12 ± 0.01 and intercept −11.6 ± 1.0, significantly different
  (P < 0.001) [Swain & Leutholtz 1997]. This much is well replicated and is why ACSM
  prescribes in %VO₂R.
- **[Contested]** **The treadmill follow-up did not reproduce identity, and it is
  routinely cited as if it had.** In 50 adults on the Bruce protocol, %HRR–%VO₂R gave
  slope 1.03 ± 0.01, intercept 1.5 ± 0.6, r = 0.990 ± 0.002 — and the paper states that
  **both** regressions "differed statistically from the line of identity", %VO₂R merely
  being significantly *closer* [Swain et al. 1998]. "Closer to identity than a worse
  option" is not identity.
- **[Contested]** **The largest test rejects the equivalence outright.** In 737 HERITAGE
  participants, with resting values *excluded* from the individual regressions, mean slope
  was 0.972 ± 0.189 and intercept 8.855 ± 16.022, both significantly different from 1 and
  0, "with high interindividual variability" — and, strikingly, the %HRR–%VO₂max
  relationship was *closer* to identity than %HRR–%VO₂R (RMSE 7.78% ± 4.49% vs
  9.25% ± 5.54%, P < 0.001) [Ferri Marini et al. 2021].
- **[Established]** **Including the resting point in the regression biases it toward
  identity.** Stated plainly by Ferri Marini 2021 of the earlier literature: including
  resting values along with maximal ones "could induce the slope and intercept to tend to
  1 and 0, respectively". Swain 1997, Swain 1998, Dalleck 2006, Brawner 2002 and Lounana
  2007 all anchored on rest and all found identity or near-identity; the two large studies
  that excluded it did not. That is the fault line in this literature.
- **[Probable]** **The validated range has a floor around 35% of reserve.** Lounana et al.
  2007 (26 elite cyclists) state it in so many words: "Predicted %VO₂R values were
  equivalent to %HRR in the 35–95%HRR range." Nothing below that is validated: the lowest
  *exercise* stage in Swain 1998's Bruce protocol (1.7 mph at 10% grade) is about 4.6–4.7
  METs, so between rest and roughly a third of reserve those regressions contain no
  measured exercise data at all.
- **[Established]** **%HRR sits systematically above %VO₂R, worst at low intensity.**
  Ferri Marini 2021, Table 3 (n = 737): at %VO₂R of 30/50/70/90 the observed mean %HRR is
  38.0/57.4/76.9/96.3, i.e. a bias of **+8.0/+7.4/+6.9/+6.3 points**, with SD
  **11.3/8.8/7.5/8.0 points**. Independently: %HRR "significantly overestimated %VO₂R at
  all intensities less than 85% of VO₂R" [Vehrs et al. 2022].
- **[Established]** **It fails during prolonged constant-load exercise.** The
  GXT-derived relationship "did not apply to prolonged treadmill running", with mean
  %HRR−%VO₂R differences of 8% and 6% [Cunha et al. 2011]. Over steady states
  specifically: no difference at 15 minutes (0.7 points, P = 0.717) but %HRR **6.7 points
  higher at 45 minutes** (P = 0.009) [Ferri Marini et al. 2022]. A free-living walk is
  prolonged constant-load exercise by definition.
- **[Contested]** **During walking the relationship is close to useless.** 28 adults
  walking at 3 mph targeting 50% reserve reached %VO₂R 46.9 ± 2.0 but %HRR 55.3 ± 5.4,
  with **r = 0.31 (P = 0.105)** [Solheim et al. 2014] — against r = 0.990 in a GXT. A
  walking meta-regression estimates %HRR at 3 METs as **33% with a 95% CI of 18–57%**
  [Warner et al. 2022]. A 39-point interval cannot carry a division.
- **[Probable]** **Individual characteristics do not rescue it, and training moves it.**
  Grouping by sex, ethnicity, age, body fat, resting HR and VO₂max explained under 4% of
  the variance in individual intercepts and 1.3% in slopes, and 20 weeks of aerobic
  training shifted both (intercept 8.9 → 13.1, slope 0.971 → 0.891) [Ferri Marini et al.
  2023]. So there is no per-person correction to apply, only a range to respect.
- **[Established]** **The 3.5 mL/kg/min resting term is a convention, and it is high.**
  Measured resting VO₂ in 769 adults was **2.6 ± 0.4 mL/kg/min**; 3.5 "overestimates the
  actual resting VO₂ value on average by 35%" [Byrne et al. 2005]. Corroborated at 3.21
  (95% CI 3.13–3.30) in 125 healthy men [Cunha et al. 2013] and 2.7 ± 0.6 in older adults
  [Leal-Martín et al. 2022]. **We could not source the original derivation of 3.5**; Byrne
  reports only that it came from "the resting VO₂ of one person, a 70-kg, 40-yr-old man".

## How we compute it

Per steady 30-second window of a recorded GPS session (the same windows
[[submaximal_vo2max]] regresses over — one definition of "steady window", shared):

```
%HRR   = (HR − HRrest) / (HRmax − HRrest)
VO₂max = 3.5 + (VO₂ − 3.5) / %HRR
```

- **VO₂** from the ACSM speed→VO₂ equation scaled by the Minetti 2002 gradient-cost ratio,
  on GPS-measured speed and DEM-derived grade — unchanged from [[submaximal_vo2max]].
- **HRrest** = the 7-day median of `rhr_daily`, our sleeping resting HR.
- **HRmax** = Tanaka 2001, `208 − 0.7 × age`.
- **VO₂rest** = 3.5 mL/kg/min, matching the resting term already inside the ACSM equations
  on the other side of the subtraction.
- The session value is the **median** of the admitted windows, never the mean.

**Gates (all must pass, else withhold):** the window is at running speed; its %HRR is
inside **0.35–0.95**; at least 6 such windows exist; the median lands inside 20–85
mL/kg/min.

## How the coach uses it

1. **Never present a walking session as a fitness measurement.** When an owner asks why a
   long walk produced no VO₂max, the answer is that walking cannot measure it — not that
   the walk was too short or too easy. More walking will not fix it.
2. When a reserve-derived value exists, describe it as **measured from a run, and
   conservative** — the published bias runs in the under-estimating direction.
3. Prefer the graded fit when both exist ([[submaximal_vo2max]]), and never average them.
4. Report the **median across sessions and the trend**, not a single session.

## Safety bounds

- This is a wellness estimate, **not a clinical measure** — never use it to clear anyone
  for hard training or to set race pace.
- Beta-blockers, chronotropic incompetence, atrial fibrillation, pacemakers, thyroid
  disease, fever, dehydration and heat all decouple heart rate from oxygen uptake, and
  this method is *nothing but* that coupling. In those states it is not merely less
  precise, it is invalid, and no value should be offered.
- These are rules for the coach, not compiled guarantees: this note declares no
  `safety_critical` directive and no guardrail is compiled for it.

## Honesty & uncertainty

- **The headline caveat: it under-reads walking by roughly half.** On the owner's eight
  real tracks the running windows returned 40.9 and 41.7 mL/kg/min against a graded-method
  anchor of 39.6; the walking windows on the same and other days returned 9.4–23.2. At a
  *matched* 75–85% of reserve, walking windows gave 10.6 and running windows 42.3 — a
  factor of 4.0 at identical cardiovascular strain, which falsifies the equivalence's own
  core prediction in that setting.
- **The estimate is biased low even where it works.** Applying Ferri Marini's Table 3 to
  our running windows implies the reported value is ~2.5–3 mL/kg/min conservative. We do
  not correct for it, because the same paper shows a population correction explains almost
  none of the individual variance.
- **Precision, honestly.** Monte-Carlo over the published scatter, an HRmax SD of 10 bpm
  [Robergs & Landwehr 2002 — the ±10–12 bpm figure everyone attributes to Tanaka comes
  from here] and the owner's own HRrest spread gives, for a 6-window session median:
  ±3.2 mL/kg/min at 80–90% of reserve, ±4.3 at 50%, ±5.6 at 40%, ±8.3 at 30%. It beats the
  Jurca non-exercise SEE of 5.075 only above roughly 42% of reserve. **Between the 35%
  published floor and ~43% it is inside the validated range but no more precise than the
  model it would displace.**
- **Two validating sessions, one owner.** Everything above about where it *works* rests on
  n = 2 running sessions from a single person, cross-checked against three independent
  instruments that agree (graded GPS fit 39.6; Jurca non-exercise 41.0; Kaminsky
  population median for a 32-year-old male 39.7). That is corroboration, not validation.
- **HRrest is a mismatch we accept knowingly.** `rhr_daily` is a *sleeping* resting heart
  rate; Swain's HRrest and the 3.5 convention are awake seated/supine values. Sleeping
  RHR is lower, which widens the reserve span, lowers %HRR and thereby *lowers* the
  estimate — i.e. the mismatch runs in the conservative direction. Measured effect on
  this owner: ±5 bpm of HRrest moves a session median by under 1 mL/kg/min (3.5 at
  +15 bpm) — the smallest of the three error terms, despite appearing in both numerator
  and denominator.
- **Cardiac drift is severe where the signal is weak.** Across the owner's 147-minute
  walk the per-window estimate decayed from 28.1 to 8.8 as HR rose 127 → 151 bpm at
  constant pace. Across a running session's windows spanning 9.7 to 43.3 minutes it did
  not decay at all. This is the [Ferri Marini 2022] 45-minute finding visible in one
  person's data, and it is why the running gate needs no separate duration cap.
- **What could not be sourced.** The full texts of Swain 1997 and Swain 1998 are
  paywalled; no SEE or SD of the individual %HRR−%VO₂R difference is reported in either
  abstract and we could not confirm whether the papers report one. The subject sex/age
  breakdowns are known only from secondary descriptions. We did not read ACSM's Guidelines
  for Exercise Testing and Prescription directly and make no claim about what caveats it
  attaches. The primary derivation of 3.5 mL/kg/min could not be identified.

## Bottom line

**Act on confidently:** that %HRR is a better proxy for %VO₂R than for %VO₂max; that the
equivalence carries a systematic +6–8 point bias with 7.5–11.3 points of individual
scatter; that it is not validated below ~35% of reserve; that it degrades over prolonged
constant-load exercise; and that inverting it on ordinary walking produces values a
person's own sustained oxygen uptake can refute.

**Hold loosely:** any single-session number it produces, including the running ones; the
claim that identity holds at all (the largest study says it does not); and the exact size
of the low bias, which no per-person correction can be fitted for.

## Coach Directives

1. **Never offer a VO₂max derived from walking**, however long or brisk the walk. When
   asked, say that walking cannot measure it and that the effort has to be hard enough
   that oxygen demand — not heat, hydration or time on feet — is what is driving the heart
   rate. *(confidence: high)*
2. Use the reserve inversion only for **running windows inside 35–95% of heart-rate
   reserve**, and only as the fallback when the graded fit ([[submaximal_vo2max]]) cannot
   fit a line. *(high)*
3. When reporting a reserve-derived value, say it is **measured from a run and likely
   conservative** — the published bias under-states VO₂max. *(moderate)*
4. **Never average the two methods.** They are different instruments; a blended number has
   no validation behind it. State which one produced the value. *(high)*
5. Flag HR-decoupling states (beta-blockers, chronotropic issues, fever, heat,
   dehydration, the short sleeper's autonomic state) as making this method invalid rather
   than imprecise. *(high)*
6. Report the **median across sessions and the trend**, never one session as a fact.
   *(high)*

## References

- Swain DP, Leutholtz BC. *Heart rate reserve is equivalent to %VO2 reserve, not to
  %VO2max.* Med Sci Sports Exerc. 1997;29(3):410–414. PMID 9139182.
  DOI 10.1097/00005768-199703000-00018.
- Swain DP, Leutholtz BC, King ME, Haas LA, Branch JD. *Relationship between % heart rate
  reserve and % VO2 reserve in treadmill exercise.* Med Sci Sports Exerc.
  1998;30(2):318–321. PMID 9502363. DOI 10.1097/00005768-199802000-00022.
- Ferri Marini C, Sisti D, Leon AS, Skinner JS, Sarzynski MA, Bouchard C, Rocchi MBL,
  Piccoli G, Stocchi V, Federici A, Lucertini F. *HRR and V̇O2R Fractions Are Not
  Equivalent: Is It Time to Rethink Aerobic Exercise Prescription Methods?* Med Sci Sports
  Exerc. 2021;53(1):174–182. PMID 32694364. DOI 10.1249/MSS.0000000000002434.
- Ferri Marini C, Sisti D, Skinner JS, Sarzynski MA, Bouchard C, Amatori S, Rocchi MBL,
  Piccoli G, Stocchi V, Federici A, Lucertini F. *Effect of individual characteristics and
  aerobic training on the %HRR–%V̇O2R relationship.* Eur J Sport Sci. 2023;23(8):1600–1611.
  PMID 35960537. DOI 10.1080/17461391.2022.2113441.
- Ferri Marini C, Federici A, Skinner JS, et al. *Effect of steady-state aerobic exercise
  intensity and duration on the relationship between reserves of heart rate and oxygen
  uptake.* PeerJ. 2022;10:e13190. PMID 35497191.
- Lounana J, Campion F, Noakes TD, Medelli J. *Relationship between %HRmax, %HR reserve,
  %VO2max, and %VO2 reserve in elite cyclists.* Med Sci Sports Exerc. 2007;39(2):350–357.
  PMID 17277600. DOI 10.1249/01.mss.0000246996.63976.5f.
- Cunha FA, Midgley AW, Monteiro WD, Campos FK, Farinatti PT. *The relationship between
  oxygen uptake reserve and heart rate reserve is affected by intensity and duration
  during aerobic exercise at constant work rate.* Appl Physiol Nutr Metab.
  2011;36(6):839–847. PMID 22034854. DOI 10.1139/h11-100.
- da Cunha FA, Farinatti PdeT, Midgley AW. *Methodological and practical application
  issues in exercise prescription using the heart rate reserve and oxygen uptake reserve
  methods.* J Sci Med Sport. 2011;14(1):46–57. PMID 20833587.
  DOI 10.1016/j.jsams.2010.07.008.
- Solheim TJ, Keller BG, Fountaine CJ. *VO2 Reserve vs. Heart Rate Reserve During Moderate
  Intensity Treadmill Exercise.* Int J Exerc Sci. 2014;7(4):311–317. PMID 27182409.
- Warner A, Vanicek N, Benson A, Myers T, Abt G. *Agreement and relationship between
  measures of absolute and relative intensity during walking: A systematic review with
  meta-regression.* PLoS One. 2022;17(11):e0277031. PMID 36327341.
  DOI 10.1371/journal.pone.0277031.
- Vehrs PR, Tafuna'i ND, Fellingham GW. *Bayesian Analysis of the HR–VO2 Relationship
  during Cycling and Running in Males and Females.* Int J Environ Res Public Health.
  2022;19(24):16914.
- Brawner CA, Keteyian SJ, Ehrman JK. *The relationship of heart rate reserve to VO2
  reserve in patients with heart disease.* Med Sci Sports Exerc. 2002;34(3):418–422.
  PMID 11880804.
- Byrne NM, Hills AP, Hunter GR, Weinsier RL, Schutz Y. *Metabolic equivalent: one size
  does not fit all.* J Appl Physiol. 2005;99(3):1112–1119. PMID 15831804.
  DOI 10.1152/japplphysiol.00023.2004.
- Cunha FA, Midgley AW, Montenegro R, Oliveira RB, Farinatti PT. *Metabolic equivalent
  concept in apparently healthy men: a re-examination of the standard oxygen uptake value
  of 3.5 mL·kg⁻¹·min⁻¹.* Appl Physiol Nutr Metab. 2013;38(11):1115–1119. PMID 24053518.
- Leal-Martín J, Muñoz-Muñoz M, Keadle SK, et al. *Resting Oxygen Uptake Value of 1
  Metabolic Equivalent of Task in Older Adults: A Systematic Review and Descriptive
  Analysis.* Sports Med. 2022;52(2):331–348. PMID 34417980. DOI 10.1007/s40279-021-01539-1.
- Robergs RA, Landwehr R. *The surprising history of the "HRmax = 220−age" equation.*
  J Exerc Physiol Online. 2002;5(2):1–10. (Source of the ±10–12 bpm individual spread
  commonly misattributed to Tanaka.)
- Garber CE, Blissmer B, Deschenes MR, et al. *ACSM Position Stand: Quantity and Quality
  of Exercise for Developing and Maintaining Cardiorespiratory, Musculoskeletal, and
  Neuromotor Fitness in Apparently Healthy Adults.* Med Sci Sports Exerc.
  2011;43(7):1334–1359. PMID 21694556.

## Open questions (deferred)

- Whether the equivalence's low bias is stable enough within one person over time to be
  worth calibrating against that person's own graded-fit sessions. Untested, and it needs
  more than the two running sessions this owner has.
- Whether a treadmill or track session with a known constant grade would let the walking
  case work by removing the DEM grade term. Not measurable from free-living data.
- The lowest %HRR at which Swain 1998 actually took an exercise measurement. Requires the
  paywalled full text.

## Healthee implementation & honesty policy

- **Derived field: `vo2max_submax`**, written by `derive/vo2max_reserve.py` via
  `derive/gps.py`. It is the SAME metric [[submaximal_vo2max]] writes — one metric, one
  definition ("VO₂max measured from a recorded session"), two instruments — and every row
  names its instrument in `flags.method` (`gps_graded` or `hr_reserve`).
- **Precedence, stated and not negotiable in code**: the graded fit wins whenever it
  fires, because it measures this person's own VO₂–HR relationship instead of assuming a
  contested population equivalence. The reserve inversion runs only when the graded fit
  declines, and `flags.graded_why_not` records why. **The two are never blended.**
- **Withhold, never caveat, outside scope.** `walking_intensity_only` is the reason an
  ordinary walk produces nothing, and its message must say that a longer or brisker walk
  will not help. The other reasons are `no_steady_windows`, `too_few_reserve_windows`,
  `heart_rate_reserve_fraction_too_low`, `no_resting_hr` and
  `implausible_reserve_estimate`, in `derive/vo2max_reserve.py`'s vocabulary.
- **Constants and their sources**: `MIN_HRR = 0.35` / `MAX_HRR = 0.95` from Lounana 2007's
  stated validated range — *not* tuned to our data, and on the owner's 381 steady windows
  the floor excludes exactly one. `VO2_REST_ML_KG_MIN = 3.5` matches the resting term
  inside the ACSM equations it is subtracted from, and is documented as a convention known
  to be ~35% high (Byrne 2005) whose effect here is ~0.1 mL/kg/min. `MIN_SPEED_MS` reuses
  the existing ACSM walking/running equation switch.
- **Honesty rules (carry into UI + LLM)**: label it an estimate and name the method; say
  it is conservative; never present a walking session as a fitness measurement; never
  average the two estimators; surface HR-decoupling states as invalidating rather than
  widening; report the cross-session median and trend rather than one number.
