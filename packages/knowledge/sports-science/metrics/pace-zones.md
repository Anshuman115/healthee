---
id: pace_zones
name: "Pace Zones & Threshold Pace"
category: metrics
grade: Established
summary: "Speed bands anchored to threshold pace; pace is instantaneous external load (what you did), HR is lagging internal load (what it cost)."
population: runners
aliases: ["pace-zones", "pace zones", "threshold pace", "T-pace", "tempo pace", "Daniels zones", "VDOT", "lactate threshold pace", "critical speed", "pace vs heart rate", "external load", "grade-adjusted pace"]
applies_to_metrics: []
applies_to_interventions: []
last_reviewed: 2026-06-29
related: ["heart-rate-zones", "lactate-threshold", "critical-speed", "aerobic-decoupling", "grade-adjusted-pace", "race-prediction", "polarized-training"]
daud_metrics: ["computePaceZones", "gradeAdjustedPace", "aerobicDecoupling"]
units: "sec/km"
---
# Pace Zones & Threshold Pace

## Summary

Pace zones are running-speed bands anchored to **threshold pace** — the pace a
trained runner can hold for roughly an hour, sitting at the lactate/critical-speed
boundary. Anchoring zones to threshold (the Daniels/VDOT approach) is more
physiologically honest than anchoring to a guessed max, because the threshold is
the metabolic edge that actually governs sustainability. The single most important
operational fact: **pace is an instantaneous, noise-free measure of _external_
load (what the body produced), while heart rate is a lagging, drifting measure of
_internal_ load (what it cost).** They answer different questions — the coach
should read pace for *what you did* and HR/effort for *what it cost*, and trust
pace less, not more, as heat, hills, and fatigue accumulate.

## What it is

A **pace zone** is a band of running speed (here expressed as sec/km) prescribed
for a specific physiological purpose — recovery, aerobic base, tempo, threshold,
or VO₂max intervals. Rather than scatter five arbitrary speeds, modern systems
anchor every zone to **one reference intensity** and express the rest as
fractions of it.

The reference Daud uses is **threshold pace** (T-pace): the speed at the **second
lactate turnpoint (LT2 / maximal lactate steady state / critical speed)** — the
fastest pace at which blood lactate production and clearance stay in balance.
Practically, for a trained runner it is close to **current ~60-minute race pace**
(≈ 10-mile to half-marathon pace for many; ≈ 1-hour effort). Jack Daniels
operationalised this as **VDOT**: an index of effective VO₂max read off a recent
race time, from which Easy (E), Marathon (M), Threshold (T), Interval (I) and
Repetition (R) paces are all derived [Daniels 2014].

Typical threshold-pace ranges (level ground, temperate conditions):

| Runner level | Threshold pace (≈ sec/km) | ≈ min/km | ≈ min/mile |
|---|---|---|---|
| Recreational beginner | 360–420 | 6:00–7:00 | 9:40–11:15 |
| Trained amateur | 240–300 | 4:00–5:00 | 6:25–8:00 |
| Sub-elite / elite | 175–210 | 2:55–3:30 | 4:40–5:40 |

Daud's `computePaceZones` defines the bands as fractions of threshold **speed**
(pace is its inverse, so a slower zone has a *larger* sec/km):

| Zone | Label | Speed fraction of T | Meaning |
|---|---|---|---|
| 1 | Recovery | 0.65–0.80 | Very easy, shake-out |
| 2 | Easy / Endurance | 0.80–0.90 | Aerobic base, conversational |
| 3 | Tempo | 0.90–1.00 | "Comfortably hard", marathon-to-threshold |
| 4 | Threshold | 1.00–1.06 | At/just above LT2, ~1-hour effort |
| 5 | Interval / VO₂max | 1.06–1.20 | 3–5 min reps, above critical speed |

## Physiology / mechanism

**Why anchor to threshold rather than max?** The metabolic event that decides how
long a pace is sustainable is the **aerobic–anaerobic transition**, not VO₂max.
Below the threshold, ATP demand is met aerobically and lactate is cleared as fast
as it is made → effort is steady-state and can last hours. Above it, anaerobic
glycolysis outpaces clearance, lactate and H⁺ accumulate, and time-to-exhaustion
collapses from hours to minutes. This boundary is described almost identically by
three research traditions — the **lactate threshold (LT2/MLSS)**, the **critical
speed/critical power** model, and Daniels' **T-pace** — and all three locate the
same physiological edge [Faude 2009; Jones & Vanhatalo 2017].

Endurance performance is governed by the interaction of three traits:
**VO₂max** (the ceiling), **fractional utilisation at threshold** (what % of that
ceiling you can hold), and **running economy** (the O₂ cost of a given speed)
[Joyner & Coyle 2008]. Threshold pace is the *external expression* of the second
and third of those — it already integrates how high your threshold sits and how
economically you run. That is exactly why it is a better single anchor than HR-max
or VO₂max alone.

**Why pace ≠ heart rate.** Pace is **external load**: the mechanical output the
body produced (distance ÷ time), available instantly and essentially noise-free
on flat ground. Heart rate is **internal load**: the cardiovascular *response* to
that output, which (a) lags the effort by 30–120 s as the cardiac and metabolic
systems catch up, and (b) **drifts upward at constant pace** over a long effort
("cardiovascular drift") as stroke volume falls with rising core temperature,
skin blood flow and plasma-volume loss [Coyle & González-Alonso 2001]. So the
same 4:30/km can read 150 bpm in the first 20 min and 165 bpm an hour later in the
heat — the *external* load was identical; the *internal* cost rose. This
input/output split is the formal basis of all training-load monitoring
[Impellizzeri 2019].

## The evidence

- **[Established]** The lactate threshold (and its near-equivalents MLSS / critical
  speed) is one of the strongest single physiological predictors of endurance
  running performance — typically a better discriminator between runners than
  VO₂max itself, because it captures fractional utilisation and economy together
  [Faude 2009; Joyner & Coyle 2008]. A 2009 review of 50 years of lactate-threshold
  work concludes the concept is valid for both performance diagnosis and intensity
  prescription, while cautioning that the many competing "threshold" definitions
  are not interchangeable [Faude 2009].

- **[Established]** Performance and the sustainable steady-state edge are well
  described by the **power/speed–duration (critical power/critical speed)** model:
  below CS, muscle metabolites and blood lactate reach steady state; above CS they
  do not and exhaustion is predictable. CS is "possibly the most important fatigue
  threshold in exercise physiology" [Jones & Vanhatalo 2017]. This independently
  validates anchoring zones to the threshold rather than to max.

- **[Established]** Cardiovascular drift is real and well characterised: after
  ~10–20 min of constant-load exercise, stroke volume falls and HR rises
  progressively, accelerating once sweat loss exceeds ~2% of body mass
  [Coyle & González-Alonso 2001]. Practically this means **HR overstates the true
  effort late in long/hot runs** — a fixed-HR cap would force the runner to slow
  below the intended training stimulus.

- **[Established]** Ambient temperature materially slows pace at a fixed effort.
  Across 1.7M+ marathon finishers, race times worsened as temperature rose above
  an optimum of roughly **~10–12 °C (lower for faster runners)**, with slower
  runners penalised most [El Helou 2012]. Wind, humidity and altitude add further
  cost. → pace targets must be condition-adjusted; HR/effort should lead in heat.

- **[Established (descriptive) / Probable (causal superiority)]** As a *descriptive*
  observation, most successful endurance athletes train with a strongly easy-skewed
  distribution: ~75–80% of volume easy (below LT1), a small slice at/above threshold,
  and little time in the "grey zone" just under threshold. This easy-heavy pattern is
  well documented across many elite endurance sports (observational/cross-sectional)
  [Seiler & Kjerland 2006]. The stronger *causal* claim — that a polarised
  distribution **outperforms** threshold-, HIIT- or high-volume-dominant programmes —
  rests largely on a **single small mixed-sport RCT** (9 weeks, n=48 total ≈ 12 per
  arm; runners, cyclists, triathletes and cross-country skiers), in which the
  polarised group (68/6/26%) showed the largest gains in VO₂peak, time-to-exhaustion
  and velocity at VO₂peak [Stöggl & Sperlich 2014]. One small mixed-sport trial cannot
  establish causal superiority, so that claim is graded **Probable**, not Established.
  → zones exist to *keep easy easy and hard hard*, not to spend the week at tempo.
  (Caveat: mixed-sport sample and small per-arm n, so the precise optimal distribution
  for *runners specifically* — and polarised vs pyramidal — is not settled.)

- **[Probable]** Threshold pace shifts faster than VO₂max with training and detrains
  faster than economy, so **T-pace is the most responsive single anchor to keep
  current** — it should be re-estimated from recent races/efforts every few weeks,
  not held fixed for a season [Daniels 2014; Faude 2009].

- **[Probable]** **Aerobic decoupling** — the rise in HR relative to pace across a
  long steady run (Pa:HR) — tracks aerobic durability and accumulated fatigue; a
  drift under ~5% on a long aerobic run is commonly read as good base fitness.
  The 5% line is a practitioner convention, not a validated cutoff [TrainingPeaks;
  see `aerobic-decoupling`].

- **[Contested]** Whether to prescribe a session by **pace or by HR** has no single
  right answer: pace wins for short, flat, repeatable work and for race-specific
  rhythm; HR/effort wins for long aerobic runs, heat, hills and fatigue. The honest
  position is *neither alone* — use both, and know which one the conditions make
  unreliable.

- **[Myth]** "Heart-rate zones are the ground truth and pace is just a proxy."
  Backwards. **Pace is the directly measured external output**; HR is a delayed,
  drifting *internal response* to it. Neither is "truer" — they measure different
  things. Treating HR as gospel on a hot day makes the coach prescribe too slow.

## How we compute it

**Threshold-pace anchor.** Estimate T-pace from a recent race (≈ 60-min race pace,
or convert a 5K/10K via VDOT/Riegel), or from a field test (e.g. average pace of a
~30-min time trial, taking the last 20 min). Daud stores it as
`thresholdPaceSecPerKm` and refines it from the runner's own data over time.

**Zones.** `computePaceZones(thresholdPaceSecPerKm)` in `@daud/core` maps the
threshold-speed fractions above into fast/slow sec/km bounds per zone:

```
fastSecPerKm = thresholdPace / hiSpeedFraction   (faster pace = smaller sec/km)
slowSecPerKm = thresholdPace / loSpeedFraction
```

**Grade adjustment.** On hills, raw pace is meaningless as a load measure. Daud's
`gradeAdjustedPace` (Minetti metabolic-cost polynomial, see `grade-adjusted-pace`)
converts pace+grade to a flat-equivalent pace so the *metabolic* external load can
be compared to zone bounds. Valid only within ±45% grade and overstates achievable
downhill speed (it ignores braking/eccentric limits) [Minetti 2002].

**Pace↔HR coupling.** `aerobicDecoupling` (see `aerobic-decoupling`) splits a
steady effort in half and reports the % drop in pace-per-heartbeat — the
quantitative read on how far HR has drifted away from a constant external load.

**Estimation error.** T-pace from a single race carries the race's own noise
(pacing, course, weather) — treat it as ±a few sec/km, and **always prefer a
measured/lab MLSS or a consistent field test over a formula** when available.

## How the coach uses it

The core decision logic is: **prescribe in pace, police in effort/HR, and
down-weight pace as conditions degrade it.**

- **Stage 1 (beginner).** Lead with **effort and HR**, not pace. New runners have
  no stable T-pace, run inefficiently, and chase pace into injury. Use Zone 1–2
  (Recovery/Easy) by feel ("conversational"); display pace for awareness only.
  Re-estimate threshold once the first parkrun/5K exists.

- **Stage 2 (developing).** Pace zones become primary for *structured* sessions —
  tempo (Z3), threshold reps (Z4), intervals (Z5) — because they are repeatable and
  precise. Keep easy days governed by HR/effort to protect the polarised
  distribution: ~75–80% easy, hard days genuinely hard [Seiler 2006; Stöggl 2014].
  Cross-check: if Z2 pace is pushing HR into Z3, the runner is drifting out of the
  easy band — slow down.

- **Stage 3 (racing).** Pace is king for race-specific rhythm and pacing discipline
  (the runner must internalise goal pace), but the coach must **explicitly relax
  pace targets in heat/wind/hills** and watch HR/decoupling for over-reaching. On
  race day above ~12–15 °C, shift the pace target outward and let effort lead
  [El Helou 2012].

**Cross-check rules the coach must apply:**

1. **Heat/long-run drift.** If HR is climbing at constant pace late in a long or hot
   run, that is expected cardiovascular drift, *not* a fitness alarm — do **not**
   slow purely to hold an HR cap on a steady aerobic run; judge by pace + effort
   [Coyle 2001]. Conversely on a *threshold* session, rising HR + the same pace
   feeling much harder = stop the rep.
2. **Hills/trails.** Compare **grade-adjusted pace**, never raw pace, to zone bounds.
   On steep terrain, fall back to HR/effort entirely.
3. **Fatigue/illness.** If easy-pace HR is elevated vs baseline at the same pace
   (or decoupling is unusually high), treat the day as higher internal load than the
   pace implies — ease off. This is the input/output gap doing its job
   [Impellizzeri 2019].
4. **Anchor freshness.** Re-estimate T-pace from new races/tests every few weeks;
   a stale anchor mis-scales every zone.

## Honesty & uncertainty

- **One "threshold" is many.** LT1 (first rise), LT2/MLSS (steady-state edge),
  fixed-4 mmol "OBLA", ventilatory thresholds and critical speed are *related but
  not identical*, and lab methods disagree by meaningful margins [Faude 2009]. Our
  "threshold pace" targets LT2/MLSS/~1-hr pace; quoting it to the second is false
  precision. Treat it as a band.
- **Race-derived T-pace inherits race error.** A windy, hot, or badly paced race
  gives a wrong VDOT and mis-scales every zone. Prefer multiple data points.
- **Pace's blind spots.** Flat-ground pace ignores grade, surface (mud/sand/treadmill
  belt), wind, altitude and GPS error (tree cover, tunnels, tangents can throw
  instantaneous pace by 10–20+ sec/km). It tells you the speed, not the cost.
- **HR's blind spots.** Lag (30–120 s, so useless for short reps), cardiovascular
  drift, caffeine/stress/sleep/dehydration shifts, and optical-wrist-sensor cadence
  lock/dropout. HR is a *noisy, delayed* internal signal — never a stopwatch.
- **Individual variation.** Fractional utilisation at threshold ranges widely
  (~75–90% of VO₂max); two runners with the same VO₂max can have very different
  T-paces, and the easy/threshold *speed gap* differs person to person. The fraction
  bands (0.80, 0.90, 1.06…) are population conventions, not laws — refine from the
  runner's own pace–HR–effort data.
- **Day-to-day noise.** Heat, sleep, fuelling and surface move the pace–HR
  relationship by several % day to day. A single session's decoupling or pace–HR
  mismatch means little; the **trend across comparable sessions** is the signal.
- **What's genuinely unsettled.** The precise mechanism mix behind cardiovascular
  drift (thermoregulatory vs HR-driven SV fall) is still debated [Coyle 2001];
  whether strict polarisation beats a pyramidal distribution for *recreational*
  runners specifically is not fully resolved [Seiler 2006; Stöggl 2014].

## Safety bounds

- **No hard physiological ceiling on pace itself**, but the coach must never push a
  Stage-1 runner onto pace targets before a stable threshold exists — effort/HR
  governs (mirrors the readiness/load guardrails in `@daud/core`).
- **Heat guardrail.** Above ~25–28 °C (or high humidity/WBGT), the coach must
  relax pace targets and let effort/HR lead; do not hold pace into exertional heat
  risk. This is the operational expression of the temperature–performance penalty
  [El Helou 2012] and is mirrored in the load/readiness guardrails.
- **Do not enforce a fixed HR cap that forces dangerous over-slowing or, inversely,
  ignore a large HR spike at easy pace** — both are mis-reads of the internal signal.

## Bottom line

- **Act on confidently (conclusive):**
  - Anchoring zones to a current **threshold pace** (LT2 / MLSS / critical speed /
    ~60-min race pace) is physiologically sound — the threshold, not VO₂max or an
    estimated HR-max, is the metabolic edge that governs how long a pace lasts, and
    it is a better single predictor of endurance performance than VO₂max
    [Faude 2009; Joyner & Coyle 2008; Jones & Vanhatalo 2017].
  - **Pace is instantaneous external load; HR is a lagging, drifting internal
    response.** Cardiovascular drift (HR rising at constant pace late in long/hot
    runs) is real and well characterised — so HR overstates true effort late in
    long/hot efforts and must not be read as a fitness alarm [Coyle & González-Alonso
    2001; Impellizzeri 2019].
  - **Heat (and wind, humidity, altitude, grade) slows pace at a fixed effort.**
    Above an optimum of ~10–12 °C, marathon pace degrades measurably and slower
    runners are penalised most [El Helou 2012]; pace targets must be condition-
    adjusted and effort/HR should lead in the heat.
  - **Keeping the week easy-skewed** (most volume easy, a little genuinely hard,
    minimal grey-zone) is well documented across trained endurance athletes
    [Seiler 2006]. (The stronger claim that *strict polarisation beats a pyramidal
    split* is only Probable — see "Hold loosely" — as it rests on a single small
    mixed-sport RCT [Stöggl & Sperlich 2014].)

- **Hold loosely (unsettled):**
  - The *exact* fraction-of-threshold band edges (0.80, 0.90, 1.06…) are population
    conventions, not validated constants — fractional utilisation varies ~75–90% of
    VO₂max between runners, so the easy↔threshold speed gap is individual and must be
    refined from the runner's own pace–HR–effort data.
  - **Whether to prescribe a session by pace or by HR** has no universal answer
    (Contested) — it depends on session type and conditions; use both and know which
    one the conditions make unreliable.
  - The **5% decoupling cutoff** for aerobic durability is a useful practitioner
    convention, not a validated threshold.
  - Whether strict **polarisation beats a pyramidal distribution for *recreational*
    runners** specifically, and the precise mechanism mix behind cardiovascular
    drift, remain genuinely open questions [Seiler 2006; Coyle 2001].
  - Any single race- or test-derived threshold inherits that day's noise (pacing,
    weather, course) — treat it as a band of ±a few sec/km, never an exact number.

## Coach Directives

- **D1:** Anchor all pace zones to a current **threshold pace** (≈ LT2 / ~60-min
  race pace), recomputed via `computePaceZones`, not to an estimated max. —
  confidence: Established
- **D2:** Re-estimate threshold pace from a recent race or field test **every few
  weeks**; never carry a season-old anchor. — confidence: Probable
- **D3:** Treat **pace as external load** (instantaneous, what was produced) and
  **HR as internal load** (lagging, drifting, what it cost). Prescribe in pace,
  police in effort/HR. — confidence: Established
- **D4:** On long or hot steady runs, attribute rising HR at constant pace to
  **cardiovascular drift** — do not slow purely to hold an HR cap; judge by pace +
  effort. — confidence: Established
- **D5:** Compare **grade-adjusted pace** (not raw pace) to zone bounds on any
  graded terrain; on steep/technical ground defer to HR/effort. — confidence:
  Established (Minetti cost model)
- **D6:** Above ~25–28 °C / high humidity, **widen pace targets** and let effort/HR
  lead; expect roughly slower paces at the same effort. — confidence: Established
- **D7:** Keep the week **easy-skewed** — ~75–80% of volume in Z1–Z2 by effort/HR,
  hard sessions genuinely at Z4–Z5; avoid drifting easy runs up into tempo. The
  easy-heavy distribution is well documented (Established); whether *strict
  polarisation* beats a pyramidal split is less settled (Probable). — confidence:
  Established (easy-heavy distribution) / Probable (polarised vs pyramidal)
- **D8:** For **short/flat reps** lead with pace (HR lags too much to govern them);
  for **long aerobic runs** lead with HR/effort and read pace for awareness.
  — confidence: Probable
- **D9:** If easy-pace HR is elevated vs baseline at the same pace, or decoupling is
  unusually high, treat internal load as higher than the pace implies and **ease
  off** (possible fatigue/illness/heat). — confidence: Probable
- **D10:** In **Stage 1**, govern by effort/HR and use pace for awareness only until
  a stable threshold pace exists. — confidence: Probable (practitioner consensus +
  injury-risk caution)
- **D11:** Quote threshold pace and zone edges as **bands, not exact seconds** —
  reflect the genuine ±noise in any threshold estimate. — confidence: Established

## Key references

- Daniels, J. (2014). *Daniels' Running Formula* (3rd ed.). Human Kinetics. ISBN
  978-1-4504-3183-5. (VDOT, E/M/T/I/R threshold-anchored zones.)
- Faude, O., Kindermann, W., & Meyer, T. (2009). Lactate threshold concepts: how
  valid are they? *Sports Medicine, 39*(6), 469–490. doi:10.2165/00007256-200939060-00003
- Joyner, M. J., & Coyle, E. F. (2008). Endurance exercise performance: the
  physiology of champions. *The Journal of Physiology, 586*(1), 35–44.
  doi:10.1113/jphysiol.2007.143834
- Jones, A. M., & Vanhatalo, A. (2017). The 'critical power' concept: applications
  to sports performance with a focus on intermittent high-intensity exercise.
  *Sports Medicine, 47*(Suppl 1), 65–78. doi:10.1007/s40279-017-0688-0
- Coyle, E. F., & González-Alonso, J. (2001). Cardiovascular drift during prolonged
  exercise: new perspectives. *Exercise and Sport Sciences Reviews, 29*(2), 88–92.
  doi:10.1097/00003677-200104000-00009
- El Helou, N., Tafflet, M., Berthelot, G., et al. (2012). Impact of environmental
  parameters on marathon running performance. *PLoS ONE, 7*(5), e37407.
  doi:10.1371/journal.pone.0037407
- Impellizzeri, F. M., Marcora, S. M., & Coutts, A. J. (2019). Internal and external
  training load: 15 years on. *International Journal of Sports Physiology and
  Performance, 14*(2), 270–273. doi:10.1123/ijspp.2018-0935
- Seiler, K. S., & Kjerland, G. Ø. (2006). Quantifying training intensity
  distribution in elite endurance athletes: is there evidence for an "optimal"
  distribution? *Scandinavian Journal of Medicine & Science in Sports, 16*(1),
  49–56. doi:10.1111/j.1600-0838.2004.00418.x
- Stöggl, T., & Sperlich, B. (2014). Polarized training has greater impact on key
  endurance variables than threshold, high intensity, or high volume training.
  *Frontiers in Physiology, 5*, 33. doi:10.3389/fphys.2014.00033
- Minetti, A. E., Moia, C., Roi, G. S., Susta, D., & Ferretti, G. (2002). Energy cost
  of walking and running at extreme uphill and downhill slopes. *Journal of Applied
  Physiology, 93*(3), 1039–1046. doi:10.1152/japplphysiol.01177.2001
- Tanaka, H., Monahan, K. D., & Seals, D. R. (2001). Age-predicted maximal heart rate
  revisited. *Journal of the American College of Cardiology, 37*(1), 153–156.
  doi:10.1016/S0735-1097(00)01054-8
- Riegel, P. S. (1981). Athletic records and human endurance. *American Scientist,
  69*(3), 285–290. (Endurance/fatigue exponent for race-pace equivalence.)
- TrainingPeaks. Aerobic decoupling (Pa:HR / Pw:HR) and Efficiency Factor (EF).
  Practitioner reference. https://help.trainingpeaks.com/hc/en-us/articles/204071724-Aerobic-Decoupling-Pw-Hr-and-Pa-HR-and-Efficiency-Factor-EF
  (Cited as practitioner consensus, not peer-reviewed.)
