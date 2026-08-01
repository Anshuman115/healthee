---
id: race_prediction
name: "Race-Time Prediction"
category: metrics
grade: Probable
summary: "Estimates a finish time from a known race via Riegel's power law; well-calibrated short-to-mid, optimistic for under-trained marathoners."
population: runners
aliases: ["race-prediction", "race time predictor", "finish time estimate", "race equivalency", "riegel", "vdot", "race calculator", "predicted race pace", "equivalent performances", "what could i run"]
applies_to_metrics: []
applies_to_interventions: []
last_reviewed: 2026-06-29
related: ["vdot", "critical-speed", "training-paces", "lactate-threshold", "marathon-pacing"]
units: "sec (time), sec/km (pace), dimensionless (fatigue exponent)"
---
# Race-Time Prediction

## Summary
Race-time prediction estimates a finish time at one distance from a known
performance at another, using the empirical fact that running speed decays in a
near-log-linear way as race duration grows. The workhorse is Riegel's power law
`T₂ = T₁·(D₂/D₁)^1.06`; physiological systems (Daniels VDOT, Péronnet–Thibault)
and regressions add fidelity. **The single most important coaching takeaway: these
models are well-calibrated for short-to-mid extrapolations (≤ ~2× distance) but
systematically predict marathons that are too fast for under-trained runners — by
10+ minutes for half the field [Vickers & Vertosick 2016]. Always present a
predicted time as a range, not a number, and tighten it from the runner's own
race history.**

## What it is
A race predictor maps a performance — a time `T₁` over a distance `D₁` — onto an
*equivalent* performance `T₂` over a target distance `D₂`, on the assumption the
runner is equally trained and racing equally hard at both. It answers "given my
recent 10 K, what could I run for a half?" and underpins every "equivalent
paces" table.

Three families exist:

- **Power-law / fatigue-exponent models** (Riegel, Cameron) — pure time-vs-distance
  curve fits, no physiology required. Inputs: one race result + target distance.
- **Physiological / metabolic models** (Daniels–Gilbert VDOT, Péronnet–Thibault) —
  model the oxygen cost of running and the fraction of VO₂max sustainable for a
  given duration, then invert it to a time.
- **Regression / data-driven models** (Vickers–Vertosick, machine-learned, and
  *the runner's own* race log) — fit finish time to predictors like training
  volume, age, BMI and past races.

The **fatigue exponent** is the key parameter. An exponent of exactly 1.0 would
mean pace is independent of distance (physiologically impossible beyond sprints);
the observed value sits near **1.06**, i.e. doubling the distance costs about
`2^1.06 ≈ 2.085×` the time, not 2×. Typical ranges: elites and high-mileage
runners fit ~1.04–1.06; recreational/low-mileage runners empirically need
~1.07–1.12 for long extrapolations.

## Physiology / mechanism
Speed declines with duration because the metabolic power a runner can sustain
declines with duration. Three mechanisms dominate:

1. **Fractional utilisation of VO₂max falls with time.** A runner can hold
   ~100% VO₂max for ~6–11 min (≈ the duration of a hard 3 K), but only ~75–85% at
   marathon duration. The decay is roughly log-linear in race time — the explicit
   core of the Péronnet–Thibault and Daniels models.
2. **Substrate and the glycogen ceiling.** Longer races shift fuelling toward a
   point where glycogen depletion, dehydration and rising core temperature force a
   slowdown ("the wall"). This is highly trainable and highly individual, which is
   precisely why the marathon breaks tidy power laws.
3. **Neuromuscular and biomechanical fatigue.** Eccentric muscle damage and
   declining running economy late in long races add a penalty no curve fit from
   shorter races can see.

Because mechanisms 2 and 3 only bite hard at marathon-plus durations, predictors
calibrated on shorter races have no information about them and therefore extrapolate
too optimistically into the marathon.

## The evidence

- **[Established]** Running speed decays as a power law of distance with an exponent
  near 1.06 across pooled human performances from sprints to ultras. Riegel fitted
  `T = a·D^1.06` to world-record and group data spanning 100 m to 100 miles
  [Riegel 1981]. The relationship is one of the most replicated in the sport and
  underlies essentially every commercial predictor (Garmin, Strava, VDOT tables).

- **[Established]** Sustainable fraction of VO₂max declines approximately
  log-linearly with race duration, giving physiological models real predictive
  power without a lab test. Péronnet & Thibault built an energetics model
  (anaerobic capacity A, maximal aerobic power MAP, and an endurance term E that
  reduces peak aerobic power with `ln(T)` for `T > ~420 s`) that reproduces world
  records 60 m–marathon [Péronnet & Thibault 1989]; Daniels & Gilbert's VDOT tables
  use the same idea via an oxygen-cost equation `VO₂ = -4.60 + 0.182258·v +
  0.000104·v²` (v in m/min) and a %VO₂max-vs-duration curve [Daniels & Gilbert 1979].

- **[Probable]** Predictions are well-calibrated for short-to-moderate
  extrapolations but break down for the marathon. In 2,303 recreational runners,
  Riegel was well-calibrated up to the half-marathon but **underestimated marathon
  time, giving predictions ≥10 min too fast for half the runners**; a regression
  adding training volume cut prediction error sharply (mean squared error 208–228
  vs 381 for Riegel) [Vickers & Vertosick 2016].

- **[Probable]** Adding the runner's own training/anthropometric data beats any
  universal formula. The Vickers–Vertosick equations and the systematic review by
  [Keogh et al. 2019] both conclude that weekly mileage is the strongest
  non-race predictor and that no single universal equation dominates.

- **[Probable]** A *personalised* power law (fit to one runner's own multi-distance
  results) outperforms the universal 1.06. Modelling individual runners with their
  own personalised power law (a three-component "Local Matrix Completion" model)
  gave lower out-of-sample RMSE than Riegel and the Purdy Points scheme — the
  improvement exceeded 50% for the fastest quartile of runners — and was
  statistically significant (p ≤ 2×10⁻⁸ for the top 95%) [Blythe & Király 2016].

- **[Contested]** There is no agreed "best" equation. Keogh et al.'s systematic
  review found **36 studies, 114 equations** (61 from training/anthropometric data,
  53 needing lab tests); reported fit ranged enormously (r² = 0.10–0.99 across 68
  equations; SEE 0.27–27.4 min across 19 equations) and key variables (course
  gradient, sex, weather) were frequently omitted. Their explicit recommendation:
  *runners should be wary of relying on a single equation* [Keogh et al. 2019]. The
  upper end of that SEE spread (~27 min) is itself the honest headline: a "predicted
  marathon time" can carry a standard error larger than the gap between two adjacent
  finish goals.

- **[Probable]** The strongest *single-race* anchor for a marathon prediction is a
  recent half-marathon, not a 5 K/10 K. Half-marathon pace already taxes the same
  fractional-utilisation and fuelling regime the marathon extends, so the
  extrapolation is shorter and the unmodelled "wall" mechanisms are partly observed.
  Marathon-specific models built on half-marathon time and pacing report lower error
  than generic power laws [Keogh et al. 2019; consistent with practitioner consensus].

- **[Myth]** "The race calculator tells me exactly what I'll run." Treating a point
  estimate as a guarantee is unsupported. Stated accuracy is ~80% within a useful
  band; ~1 in 5 runners miss notably, and error grows with the distance gap and
  into the marathon. A predictor states *potential under ideal pacing, fitness and
  conditions* — not a delivery date.

## How we compute it

**Riegel power law** (default; owns `@daud/core → predictRaceTime`):

```
T₂ = T₁ · (D₂ / D₁) ^ k
```
where `k` is the fatigue exponent (default 1.06). Units: T in seconds, D in metres
(any consistent unit). Inverting for pace is direct.

**Cameron** (variable exponent, better for long extrapolations; non-peer-reviewed
practitioner formula):
```
T₂ = T₁ · (D₂/D₁) · f(D₁)/f(D₂),   f(x) = 13.49681 − 0.000030363·x + 835.7114 / x^0.7905
```
(x in metres). The `f(D₁)/f(D₂)` ratio makes the effective exponent rise with
distance, partly correcting Riegel's optimism at the long end.

**Daniels VDOT** — compute VDOT from the input race (energetic demand vs
%VO₂max-at-duration), then read the equivalent time for `D₂` off the same VDOT
curve. Equivalent to assuming constant running economy and fractional utilisation
across events. See companion doc `vdot`.

**Péronnet–Thibault** — solves the energetics model (A, MAP, E) for the
distance–time pair; an improved variant exists [Álvarez-Ramírez 2002].

**Personal regression (preferred when data exists)** — fit the runner's *own*
exponent `k_self` from ≥2 recent maximal efforts at different distances
(`k = ln(T₂/T₁) / ln(D₂/D₁)`), or fit finish time to mileage + recent races. This
replaces the population default with the individual's true fatigue resistance.

**Estimation error vs ground truth:** all of the above are estimates, not measured.
Flag every output with a confidence band (see Honesty). The only ground truth is an
actual maximal race at the target distance under similar conditions.

## How the coach uses it

- **Choose the model by data available.**
  - 0 prior races logged → do not predict; ask for a recent time-trial or parkrun.
  - 1 race → Riegel/VDOT with a **wide** band; flag as provisional.
  - ≥2 races at different distances → fit `k_self`; prefer it over 1.06.
  - Rich history + mileage known → personal regression (mileage-aware).

- **Clamp the extrapolation distance.** Trust predictions out to roughly **2× the
  input distance**. Beyond that, widen the band and warn. A marathon predicted from
  a 5 K is the least trustworthy common case.

- **Apply the marathon correction.** For target = marathon from inputs ≤ half, bias
  the prediction *slower* than raw Riegel (use `k ≈ 1.07–1.12` for low-mileage
  runners, or require a recent long run / half result before committing). Never
  surface the optimistic raw number as the headline for a first marathon.

- **By stage:**
  - **Stage 1 (beginner):** use prediction only to set *realistic effort
    expectations*, never an aggressive goal time. Lean conservative; emphasise the
    range.
  - **Stage 2 (developing):** use it to pick training paces (via VDOT) and a
    sensible goal window; refine `k_self` as races accumulate.
  - **Stage 3 (racing):** use the personalised model for goal pacing; cross-check
    against the runner's most recent race at the nearest distance and current
    fitness trend.

- **Cross-checks:** weight predictions against the freshness of the input race
  (a 6-month-old PB is stale), course profile, expected heat/altitude, and whether
  marathon-specific endurance (long runs, fuelling) has actually been trained.

## Honesty & uncertainty
This section is mandatory and load-bearing.

- **Point estimates are false precision.** Report a *range* (a prediction interval),
  not a single number. A defensible default band is roughly ±2–3% for same-ish
  distances, widening to ±5% or more for marathon extrapolations from short races.
  ~80% of runners land within a useful band; ~20% miss notably [practitioner
  consensus; consistent with Keogh 2019's SEE spread]. Be explicit that the band is a
  *confidence range*, not a guarantee — the published SEE reaching 27 min for some
  marathon equations [Keogh et al. 2019] means a confidently-stated single time is
  actively misleading. The narrower the distance gap and the more of the runner's own
  data behind it, the tighter the honest band.
- **The marathon is where models lie.** Riegel/VDOT/Cameron all assume the limiter
  is the same across distances. It isn't: glycogen depletion, fuelling, pacing
  discipline and long-run training govern the marathon and are invisible to a 5 K
  or 10 K input. Empirically Riegel ran ≥10 min too fast for half of recreational
  marathoners [Vickers & Vertosick 2016].
- **Individual variation in the fatigue exponent is large.** Population 1.06 hides
  a spread from ~1.04 (endurance-strong) to ~1.12 (speed-strong / low-mileage). A
  45-min 10 K runner is predicted ~3:18 at `k=1.06` but ~3:42 at `k=1.12` — a
  24-minute swing from one runner-dependent parameter. Use the runner's own data.
- **Day-to-day and condition noise.** Heat, wind, hills, altitude, sleep, fuelling
  and taper quality each move a finish time by minutes; none are in a basic
  predictor. A predicted time assumes flat course, good weather, sound pacing and
  peak readiness.
- **Garbage in.** A pace from a workout, a downhill course, or a non-maximal
  parkrun corrupts the prediction. The input must be a genuine, recent, maximal
  effort.
- **Reverse direction is unreliable too.** Predicting a 5 K from a marathon
  over-predicts (marathon pace under-represents top-end speed). Models are most
  trustworthy interpolating between two known races, least trustworthy
  extrapolating outward.
- **What's unknown / debated:** no consensus "best" equation exists [Keogh et al.
  2019]; the right exponent for an individual ultra runner, and how to encode
  course and weather generically, remain open.

## Safety bounds
- **No medical safety bound on the prediction itself**, but predictions feed pacing,
  which has a safety dimension: an over-optimistic marathon goal drives early
  over-pacing → glycogen crash, heat strain and DNF/collapse risk. Therefore the
  coach must **never present an un-banded, aggressive marathon prediction as a
  target**, especially for a first marathon — marathon predictions carry a mandatory
  conservative bias + range.
- Do not let a stale or non-maximal input drive a race-day pace plan without an
  explicit confidence flag.
- **Not enforced in code.** The bounds above are rules for the coach to follow, not
  guarantees. (The marathon bullet previously ended "(mirror as guardrail in
  `@daud/core`: marathon predictions carry a mandatory conservative bias + range)" — a
  module that exists nowhere in this repo, in `~/projects/healthee-legacy`, or in git
  history; the phrase arrived with the upstream sports-science corpus import. Only
  directives a note declares `safety_critical` in its frontmatter compile into
  `insights/guard_directives.py`, and this note declares none — these bounds are a
  candidate for that mechanism, not a user of it. Corrected 2026-08-01, #87.)

## Bottom line

- **Act on confidently (conclusive):**
  - Running speed decays as a near-log-linear power law of distance, with a
    population fatigue exponent near **1.06**; this is one of the most replicated
    relationships in the sport [Riegel 1981; Péronnet & Thibault 1989].
  - Predictions are **well-calibrated for short-to-moderate extrapolations**
    (roughly within 2× the input distance — e.g. 10 K from a 5 K, half from a 10 K)
    when the input is a genuine, recent, maximal effort [Vickers & Vertosick 2016].
  - **Marathon predictions extrapolated from shorter races are systematically too
    fast** for recreational/low-mileage runners — Riegel ran ≥10 min optimistic for
    half the field — so marathon goals must be biased slower and gated on
    marathon-specific endurance [Vickers & Vertosick 2016].
  - **Adding the runner's own data beats any universal formula.** A model with one
    or two prior races, or training volume, cut error substantially (MSE 208–228 vs
    381 for Riegel), and a personalised power law outperforms the universal 1.06
    [Vickers & Vertosick 2016; Blythe & Király 2016].
  - **Always report a range, never a single time** — point estimates are false
    precision and ~1 in 5 runners miss a useful band.

- **Hold loosely (unsettled):**
  - The exact "best" prediction equation — there is **no consensus**; 114 published
    equations vary wildly in fit and inputs [Keogh et al. 2019].
  - The precise individual fatigue exponent for a given runner, especially toward
    the **ultra** end and for atypical speed/endurance profiles — population 1.06
    hides a ~1.04–1.12 spread that only the runner's own races resolve.
  - The exact width of the confidence band (the ±2–3% / ±5% defaults are
    practitioner-calibrated, consistent with but not precisely fixed by the SEE
    spread in [Keogh et al. 2019]).
  - How to encode course gradient, sex and weather generically — frequently omitted
    from published models and a known source of error [Keogh et al. 2019].

## Coach Directives

- **D1:** Default to the Riegel power law `T₂ = T₁·(D₂/D₁)^k` with `k = 1.06` when
  only one maximal race is known. — confidence: Established
- **D2:** When ≥2 maximal races at different distances exist, compute and use the
  runner's own exponent `k_self = ln(T₂/T₁)/ln(D₂/D₁)` in preference to 1.06. —
  confidence: Probable
- **D3:** Only trust an extrapolation out to ~2× the input distance; beyond that,
  widen the band and warn the runner explicitly. — confidence: Probable
- **D4:** For marathon targets extrapolated from ≤ half-marathon inputs, bias the
  prediction slower (use `k ≈ 1.07–1.12` for low-mileage runners) and never surface
  the raw optimistic number as the headline. — confidence: Probable
- **D5:** Always output a *range*, never a single time: ~±2–3% for near-distance,
  ≥±5% for marathon extrapolations. — confidence: Probable
- **D6:** Require the input to be a recent (≤~3 months), genuinely maximal effort on
  a fair course; flag predictions built on stale or non-maximal inputs. —
  confidence: Established
- **D7:** When training volume / mileage is known, prefer a mileage-aware regression
  over any universal formula for marathon prediction. — confidence: Probable
- **D8:** Never present an un-banded, aggressive marathon goal — especially for a
  first marathon — and gate marathon goal-pace on evidence of marathon-specific
  endurance training (long runs, fuelling). — confidence: Probable (safety-linked)
- **D9:** Speak with calibrated confidence: state near-distance predictions plainly,
  hedge marathon predictions, and never imply a guaranteed finish time. —
  confidence: Established
- **D10:** For a marathon goal, prefer a recent half-marathon as the anchor over a
  5 K/10 K; if only short-race inputs exist, widen the band and flag the prediction
  as low-confidence until a long-distance result is logged. — confidence: Probable

## Key references

- Riegel, P. S. (1981). *Athletic records and human endurance: A time-vs.-distance
  equation describing world-record performances may be used to compare the relative
  endurance capabilities of various groups of people.* American Scientist, 69(3),
  285–290. PMID: 7235349. https://pubmed.ncbi.nlm.nih.gov/7235349/
- Péronnet, F., & Thibault, G. (1989). *Mathematical analysis of running performance
  and world running records.* Journal of Applied Physiology, 67(1), 453–465.
  https://doi.org/10.1152/jappl.1989.67.1.453
- Daniels, J., & Gilbert, J. (1979). *Oxygen Power: Performance Tables for Distance
  Runners.* Tempe, AZ: self-published. (Origin of the VDOT system and the
  oxygen-cost / %VO₂max-vs-duration equations; see also Daniels, J. (2014).
  *Daniels' Running Formula*, 3rd ed., Human Kinetics.)
- Vickers, A. J., & Vertosick, E. A. (2016). *An empirical study of race times in
  recreational endurance runners.* BMC Sports Science, Medicine and Rehabilitation,
  8, 26. https://doi.org/10.1186/s13102-016-0052-y
- Keogh, A., Smyth, B., Caulfield, B., Lawlor, A., Berndsen, J., & Doherty, C.
  (2019). *Prediction Equations for Marathon Performance: A Systematic Review.*
  International Journal of Sports Physiology and Performance, 14(9), 1159–1169.
  https://doi.org/10.1123/ijspp.2019-0360
- Blythe, D. A. J., & Király, F. J. (2016). *Prediction and Quantification of
  Individual Athletic Performance of Runners.* PLoS ONE, 11(6), e0157257.
  https://doi.org/10.1371/journal.pone.0157257
- Álvarez-Ramírez, J. (2002). *An improved Péronnet–Thibault mathematical model of
  human running performance.* European Journal of Applied Physiology, 86(6),
  517–525. https://doi.org/10.1007/s00421-001-0555-3
- Cameron, D. (c. 1998). *Running-time prediction formula* (variable-exponent
  time/distance model fitted to world-class 400 m–50 mile performances). Practitioner
  formula, not peer-reviewed; documented at
  https://www.had2know.org/sports/race-performance-prediction-calculator-cameron.html

## Healthee implementation & honesty policy
- **Not currently computed.** Healthee stores no race personal-bests and runs no
  Riegel / VDOT / equivalent-performance calculation; there is no `predictRaceTime`
  in `derive/`. This note is **reference science + a future-metric candidate**
  (`applies_to_metrics: []`; `daud_metrics` provenance dropped — the
  `predictRaceTime`/`vdot`/`equivalentPerformance` helpers are legacy `@daud/core`).
- **Future-metric candidate (feasible from existing data).** A recorded GPS race
  or hard time-trial (`gps_track`, with distance and elapsed time) is exactly the
  single anchor Riegel's power law needs; predicting equivalent times across
  distances would be a small addition, and would also seed a `pace-zones` threshold
  anchor.
- **Population: runners.** Race equivalence is a running/endurance construct.
- **Honesty rules (carry into any future UI + the coach today):**
  - Riegel is **well-calibrated short-to-mid** (5K↔half) but **optimistic for the
    marathon**, especially for under-trained runners — a predicted marathon time
    only holds with adequate long-run endurance work, so any marathon estimate must
    carry that caveat rather than be shown as a target.
  - A prediction inherits the **source race's own noise** (pacing, course,
    weather); present it as a band, and prefer multiple recent efforts.
