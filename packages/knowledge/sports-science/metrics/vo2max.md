---
id: vo2max
name: "VO₂max (Maximal Oxygen Uptake)"
category: metrics
grade: Established
summary: "The aerobic ceiling — one of three performance determinants and the single strongest modifiable longevity marker (CRF↔mortality); slow-moving, large wearable error; a trend tool, not a race predictor or a death-risk number."
aliases: ["vo2max", "vo2 max", "vo2peak", "maximal oxygen uptake", "maximal oxygen consumption", "maximal aerobic capacity", "aerobic power", "maximal aerobic power", "aerobic ceiling", "cardiorespiratory fitness", "CRF", "cardiorespiratory-fitness", "mL/kg/min", "vo2max_fitness_mortality", "vo2max_training_program"]
applies_to_metrics: ["vo2max_estimate"]
applies_to_interventions: ["exercise"]
population: general
last_reviewed: 2026-07-15
related: ["lactate-threshold", "running-economy", "critical-speed", "race-prediction", "maximum-heart-rate", "heart-rate-zones", "polarized-training", "non_exercise_vo2max", "submaximal_vo2max", "mvpa_minutes_mortality", "steps_mortality", "strength_training_mortality", "recovery_readiness"]
daud_metrics: ["vo2max", "vVO2max", "maximalAerobicSpeed"]
units: "mL/kg/min (or L/min absolute)"
---
# VO₂max (Maximal Oxygen Uptake)

## Summary

VO₂max is the highest rate at which the body can take up, transport and use oxygen
during whole-body exercise — the **ceiling on aerobic energy production**. It sets
the upper bound of endurance potential, but it is only one of three physiological
determinants of race performance (alongside the **lactate/metabolic threshold** and
**running economy**), and among trained runners it is usually the *least*
discriminating of the three. The single most important coaching takeaway: treat
VO₂max as a slow-moving ceiling worth raising early in a runner's development, but
**do not predict race times from it, do not chase it once it plateaus, and never
trust a wearable's VO₂max as an exact number** — its individual error band is large
(roughly ±5–10 mL/kg/min), so it is a trend tool, not a measurement.

Beyond performance, VO₂max is also the single **strongest modifiable predictor of
all-cause and cardiovascular mortality** in epidemiology — a low cardiorespiratory
fitness (CRF) carries risk larger than smoking, hypertension or diabetes taken
individually, and CRF is trainable. This makes VO₂max the highest-leverage *longevity*
metric to track and raise, not just an athletic ceiling. Healthee therefore surfaces a
VO₂max **estimate** (never a lab measurement — see the estimator notes
[[non_exercise_vo2max]] and [[submaximal_vo2max]]) and frames it as a fitness
*trajectory*, never as a "death-risk" number.

## What it is

VO₂max (maximal oxygen uptake, also written V̇O₂max) is the maximum volume of
oxygen the body can consume per minute at maximal exertion, where oxygen uptake
plateaus despite increasing workload. It is the product of how much oxygen-rich
blood the heart can pump (maximal cardiac output) and how much oxygen the working
muscles extract from that blood (the maximal arterio-venous oxygen difference) —
the **Fick equation**:

> VO₂max = maximal cardiac output × maximal (a–v)O₂ difference

It is expressed two ways:

- **Absolute** — litres of O₂ per minute (L/min). Best for comparing total aerobic
  power; favours bigger athletes.
- **Relative** — millilitres of O₂ per kilogram of body mass per minute
  (mL·kg⁻¹·min⁻¹). The standard for running, because a runner must carry their own
  mass. This is the number wearables report.

Typical relative VO₂max ranges (mL/kg/min):

| Population | Men | Women |
|---|---|---|
| Sedentary / untrained | ~35–45 | ~27–38 |
| Recreational trained | ~45–55 | ~38–48 |
| Well-trained / sub-elite | ~55–70 | ~48–60 |
| Elite endurance | ~70–85 | ~60–75 |

Elite male endurance champions cluster at **~70–85 mL/kg/min**; elite women average
roughly **~10% lower**, driven mostly by higher body-fat fraction and lower
haemoglobin concentration [Joyner & Coyle 2008]. The highest credible human values
ever recorded (cross-country skiers, cyclists) sit around 90+ mL/kg/min. Note that
"VO₂peak" is the term used when no true plateau is confirmed (common in field and
sub-maximal tests) — most reported and effectively all wearable values are really
VO₂peak.

## Physiology / mechanism

Oxygen travels a chain from air to mitochondria: **lungs → blood → heart →
circulation → capillaries → muscle mitochondria.** VO₂max is set by the narrowest
link(s) in that chain. The decades-long "central (delivery) vs peripheral
(extraction)" debate was largely settled by Bassett & Howley:

- **In healthy humans at sea level, oxygen *delivery* — principally maximal cardiac
  output, plus the oxygen-carrying capacity of blood (haemoglobin / total blood
  volume) — is the primary limiting factor**, not the muscle's ability to extract
  oxygen [Bassett & Howley 2000]. Three lines of evidence converge: (1) when O₂
  delivery is manipulated — blood doping or higher haemoglobin *raises* VO₂max,
  hypoxia or β-blockade *lowers* it; (2) the training-induced rise in VO₂max comes
  mostly from a larger maximal **stroke volume / cardiac output**, not a wider a–v O₂
  difference (which is already near-maximal in trained muscle); (3) a small isolated
  muscle group, over-perfused, can consume oxygen at rates far above what the whole
  body achieves — so the muscle's extractive machinery is not usually the bottleneck.
- **Stroke volume** is the headline trainable lever: endurance training expands
  plasma and total blood volume, enlarges the left-ventricular cavity and improves
  filling, so each beat ejects more blood. Maximal heart rate barely changes (and
  drifts *down* slightly with training), so cardiac-output gains come from stroke
  volume.
- **Peripheral adaptations** (capillary density, mitochondrial volume, myoglobin,
  oxidative enzymes) matter enormously for endurance — but they primarily improve
  **running economy and lactate threshold**, i.e. the *fraction* of VO₂max you can
  sustain and the *cost* of a given pace, rather than the VO₂max ceiling itself.
- **The lungs** are normally *not* limiting in most people at sea level (arterial
  blood leaves the lungs ~96–98% saturated). The exception is some elite athletes,
  who develop **exercise-induced arterial hypoxaemia** at very high cardiac outputs
  because red cells transit the pulmonary capillary too fast to fully saturate — here
  the lung does become a co-limiter [Bassett & Howley 2000].

This mechanism is why VO₂max is a genuine *ceiling*: it reflects bulk oxygen
transport, which has finite, partly genetically-bounded headroom — whereas economy
and threshold keep improving for years.

## The evidence

- **[Established]** **O₂ delivery (cardiac output + blood O₂ carriage), not muscle
  extraction, is the primary limiter of VO₂max in healthy humans** — *narrative /
  mechanistic review synthesising decades of manipulation studies* [Bassett &
  Howley 2000, ~2,300+ citations]. Reaffirmed by later integrative reviews
  [Lundby, Montero & Joyner 2017].

- **[Established]** **Endurance performance is determined by the interaction of three
  traits — VO₂max (the ceiling), the lactate/metabolic threshold (the usable
  fraction), and running economy (the O₂ cost of a pace) — not by VO₂max alone** —
  *seminal integrative review* [Joyner & Coyle 2008; Coyle 1995]. Among already
  trained/elite runners with similar high VO₂max, race performance is discriminated
  far more by threshold and economy than by VO₂max. The composite **velocity at
  VO₂max (vVO₂max)** and **maximal aerobic speed (MAS = VO₂max ÷ running economy)**
  predict race pace better than VO₂max alone because they fold economy in.

- **[Established (principle) — illustrated by an n=1 case study]** **VO₂max alone is a
  weak discriminator of performance *within* a homogeneous trained group.** The
  *principle* rests on the integrative-review and cross-sectional evidence above
  [Joyner & Coyle 2008; Coyle 1995], not on any single dataset. The most-cited
  *illustration* is longitudinal but is only one athlete: in the women's-marathon
  world-record holder, **VO₂max was already high at age 18 and stayed essentially flat
  across her career, while running economy improved ~15% (204 → 175 mL/kg/km,
  1992→2003) — and it was economy, not VO₂max, that tracked her improving
  performance** — *single elite longitudinal case study, n=1, hypothesis-illustrating
  not hypothesis-confirming* [Jones 2006]. Across a heterogeneous population
  (untrained → elite), VO₂max *does* correlate with performance; the dissociation
  appears once the field is narrowed to trained runners.

- **[Established]** **VO₂max is highly trainable in untrained people but the response
  is large, finite, and reaches a plateau.** *Meta-analyses of RCTs / controlled
  trials:* in previously sedentary or recreationally-active adults <45 y, interval
  training raised VO₂max by ~0.5–1.0 L/min [Bacon et al. 2013, n=334 across studies];
  pooled RCT data found HIIT raised VO₂max by **~4.9 mL/kg/min** vs **~1.9 mL/kg/min**
  for moderate continuous training [Milanović et al. 2015, 13 RCTs]. Typical
  whole-program gains in the untrained are ~15–20% (occasionally higher), but gains
  diminish as fitness rises and the ceiling is approached — the better-trained you
  are, the harder each further mL/kg/min is to win.

- **[Established / Probable]** **Trainability is strongly individual and partly
  genetic.** *Family training study (HERITAGE):* after a standardised 20-week
  program in 481 sedentary adults, the **mean VO₂max gain was ~400 mL/min but ranged
  from near-zero to >1000 mL/min**, and this response variability was **~2.5× greater
  between families than within them, with heritability of the *response* estimated at
  ~47%** [Bouchard et al. 1999]. So "responders" and "low/non-responders" to a given
  dose are real — and baseline VO₂max does *not* predict how much an individual will
  gain.

- **[Probable]** **Apparent "non-response" is often a dose problem, not a hard
  genetic wall.** *Crossover dose-escalation trial:* incidence of non-response fell
  monotonically with weekly training volume (69% → 40% → 29% → 0% → 0% across
  60→300 min/week), and **non-response was abolished when previous non-responders
  added ~120 min/week for 6 more weeks** [Montero & Lundby 2017, small n; needs
  replication]. Interpretation: most people *can* raise VO₂max with enough dose, but
  the dose required is individual.

- **[Established]** **VO₂max plateaus relatively early in a trained athlete's
  development, while threshold and economy keep improving** — which is precisely why
  multi-year performance gains in trained runners come mostly from the latter two,
  not from pushing the ceiling [Joyner & Coyle 2008; Jones 2006; Coyle 1995].

- **[Contested / methodological]** **Whether a true VO₂ "plateau" is even required to
  define VO₂max is debated.** Many participants — especially untrained ones — reach
  volitional exhaustion without a clear oxygen-uptake plateau, so most field and many
  lab values are properly VO₂*peak*. Verification-phase protocols are increasingly
  recommended, but no single criterion is universal.

- **[Emerging / Contested]** **Wearable VO₂max estimates carry small average bias but
  large individual error and should not be read as exact.** *Systematic review +
  meta-analysis (INTERLIVE consortium):* exercise-based algorithms had near-zero
  systematic bias (**−0.09 mL/kg/min**) but **limits of agreement of about ±9.8
  mL/kg/min**; resting-based algorithms were worse (bias +2.17, LoA −13.1 to +17.4)
  [Molina-Garcia et al. 2022]. *Independent validation (Apple Watch Series 7, n=19):*
  mean bias **−4.5 mL/kg/min** (underestimate), MAPE **~15.8%**, with a systematic
  pattern of **over-estimating poor-fitness and under-estimating high-fitness**
  individuals [Caserman et al. 2024]. Consistent finding across devices and brands:
  low *group* bias but poor *individual* validity — good for tracking your own trend,
  unreliable as an absolute or for cross-person comparison.

### Cardiorespiratory fitness and mortality (the longevity case)

- **[Established]** **CRF (VO₂max) is among the strongest known modifiable predictors
  of all-cause and cardiovascular mortality — an association stronger than smoking,
  hypertension, diabetes, or hypercholesterolaemia taken individually, holding across
  age, sex and BMI.** *Largest cohort with directly-measured fitness:* in 122,007
  adults undergoing treadmill testing (Cleveland Clinic, 1991–2014), **elite fitness
  (>2.0× age/sex-predicted) vs low (<25th percentile) carried HR 0.20 (95% CI
  0.16–0.24) — ~80% lower all-cause mortality**, each 1-MET higher CRF ≈ 10–15% lower
  mortality, and the hazard of *low* CRF exceeded that of current smoking, diabetes and
  end-stage renal disease modelled in the same population [Mandsager et al. 2018]. The
  American Heart Association added CRF to its list of clinical vital signs in 2016
  [Ross et al. 2016].
- **[Established]** *Meta-analysis (33 studies, n=102,980):* **each 1-MET higher CRF ≈
  13% lower all-cause and 15% lower cardiovascular mortality**; low (<7.9 METs) vs high
  (>10.9 METs) CRF pooled HR 0.30 (CV events) / 0.35 (CV mortality) [Kodama et al.
  2009].
- **[Established]** *Directly-measured VO₂max, 25-year follow-up (BALL State LLS,
  n=4,876):* **each 1 mL/kg/min higher VO₂max ≈ 9% lower all-cause mortality**
  [Imboden et al. 2019]. Because VO₂max is *trainable* (HERITAGE and the trainability
  evidence above), this longevity association is the highest-leverage modifiable target
  we track — but the mortality effect sizes are anchored on **CPET-measured** fitness,
  so extending them to a wearable/non-exercise *estimate* carries the estimator's error
  (see [[non_exercise_vo2max]], [[submaximal_vo2max]]) and must never be recited to the
  user as a personal death-risk number.

### Raising VO₂max — how much, how fast (trainability, expanded)

- **[Established]** *Meta-analysis (37 studies, n=334, 6–13 wk):* interval/combined
  training raised VO₂max **+0.51 L·min⁻¹ (95% CI 0.43–0.60)**; the longer **3–5 min
  intervals produced ~0.8–0.9 L·min⁻¹**, continuous-only training only ~0.2–0.4
  [Bacon et al. 2013]. For an ~80 kg adult, +0.51 L·min⁻¹ ≈ **+6.4 mL/kg/min** in young
  untrained people over ~10 weeks — the upper end; Healthee deliberately projects
  **~half** of that for real-world adherence and a recovery-limited user (see the
  implementation section). Combined with Milanović et al. 2015 (HIIT > MICT by
  ~1.2 mL/kg/min), the practical protocol is **polarized**: a large easy aerobic base
  plus a small dose of hard, ~vVO₂max intervals or vigorous bursts.
- **[Established]** **Brief, non-exercise vigorous bursts ("VILPA") also raise fitness
  and sharply lower mortality** — a median 4.4 min/day associated with HR ≈ 0.62 for
  all-cause mortality [Stamatakis et al. 2022]; see [[mvpa_minutes_mortality]]. So the
  hard-stimulus half of the plan need not be a structured workout.

## How we compute it

**Lab gold standard (ground truth).** Graded maximal exercise test (treadmill or
cycle) to volitional exhaustion with breath-by-breath gas analysis (indirect
calorimetry); VO₂max = the highest 30-second VO₂, ideally confirmed by a plateau
(ΔVO₂ < ~150 mL/min despite rising workload) plus secondary criteria (RER > ~1.10,
HR near age-predicted max, blood lactate > ~8 mmol/L). A verification bout at a
supramaximal workload is the modern confirmation. Reproducible to roughly ±2–3% in a
good lab.

**Field / sub-maximal estimates (what `@daud/core` actually uses or ingests).**

1. **vVO₂max / Maximal Aerobic Speed (MAS)** — the running speed at which VO₂max is
   reached (or estimated from a 5–6 min maximal effort, e.g. a maximal 1500–2000 m or
   a 6-min time trial). More useful to a runner than VO₂max itself because it already
   integrates economy. `@daud/core: vVO2max / maximalAerobicSpeed`.
2. **Race-derived estimate** — VO₂max can be back-estimated from recent race
   performances (e.g. Daniels' VDOT, Léger/Mercier velocity relationships). This is
   really a *performance* index reported in VO₂max units, conflated with economy and
   threshold — treat it as a fitness proxy, not a physiological measurement. See
   `race-prediction`.
3. **Wearable auto-estimate** — devices estimate VO₂max from the HR-vs-pace/power
   relationship during outdoor runs (exercise-based algorithm). **Ingest only as a
   coarse trend**; do not treat as ground truth.

**Error to surface to the coach:** lab ≈ ±2–3%; race-derived ≈ a fitness proxy, not
a measurement; **wearable ≈ ±5–10 mL/kg/min for an individual** (small group bias,
wide limits of agreement) and brand-/condition-dependent [Molina-Garcia et al. 2022;
Caserman et al. 2024]. Always present any single VO₂max value as a band, and trust
the *direction of change over weeks* far more than the absolute number.

## How the coach uses it

VO₂max is a **context and ceiling metric**, not a primary dial. The coach should use
threshold pace/HR and running economy as the operational anchors (see
`lactate-threshold`, `running-economy`), and use VO₂max to:

- **Gauge headroom and set expectations.** A low VO₂max in a developing runner means
  there is a trainable ceiling to raise; a high one near plateau means future gains
  must come from threshold and economy. Never quote a race-time prediction from
  VO₂max alone.
- **Justify a phase of VO₂max-oriented work** (short, high-intensity intervals at
  ~vVO₂max, e.g. 3–5 min reps at ~95–100% of velocity at VO₂max) when the runner is
  early-stage, has stagnated, or is building toward shorter races — gated by recovery
  rules and kept a small fraction of weekly volume.
- **Track long-term trend**, not week-to-week noise.

**The raising-VO₂max protocol (polarized — easy base + a hard stimulus).** When a phase
of VO₂max work is justified (low-fit or stalled user, longevity goal), the
evidence-backed shape is:
- **Aerobic base** — ~3 sessions/week, 30–45 min easy/conversational (~60–70% HRmax,
  zone 2). Builds the mitochondrial/aerobic base and carries the bulk of the volume.
- **One weekly high-intensity stimulus** — intervals (e.g. 4–5 × 1–4 min hard, or
  3–5 min reps at ~95–100% vVO₂max) **or** VILPA (short all-out bursts: stairs, a hill,
  a fast walk-to-jog). This is the part that actually drives the ceiling up
  [Bacon et al. 2013; Stamatakis et al. 2022].
- Polarized (mostly easy + a little very hard) beats all-moderate for VO₂max, and the
  hard fraction stays **small and recovery-gated** (Safety bounds). Scale the intensity
  to recovery — no hard session on a low-recovery day (see [[recovery_readiness]]).

**By stage:**

- **Stage 1 (beginner):** Highest absolute trainability — easy aerobic volume plus
  occasional faster strides will lift VO₂max substantially. Do **not** order maximal
  VO₂max tests or vVO₂max intervals early; build the aerobic base first. Use the
  wearable VO₂max only as a motivational trend line, with an explicit "this is an
  estimate, ±several points" caveat.
- **Stage 2 (developing):** Introduce structured vVO₂max intervals (e.g. 3–5 × 3 min
  @ ~95–100% vVO₂max, equal recovery) in dedicated blocks to nudge the ceiling, but
  keep threshold work and easy volume dominant. Expect VO₂max to rise then plateau;
  shift emphasis to threshold/economy as it flattens.
- **Stage 3 (racing):** VO₂max is largely a maintained background trait; small
  sharpening blocks of vVO₂max work preserve the ceiling while the real race gains
  come from threshold velocity, economy and race-specific work. Pace races from
  threshold/critical-speed and race data — **never from a VO₂max number**.

**Cross-checks (mandatory):**

- If a wearable VO₂max jumps or drops several points week-to-week, treat it as
  measurement noise (heat, GPS/HR error, hills, fatigue) — not a real fitness change.
- A flat or plateaued VO₂max with improving race/threshold pace is **normal and
  good** (economy/threshold gains) — do not interpret it as stagnation.
- VO₂max reported in mL/kg/min moves with body mass: weight loss can raise relative
  VO₂max with no change in aerobic power, and vice versa — flag this when mass changes.

## Honesty & uncertainty

- **VO₂max is necessary but not sufficient for performance.** It sets the ceiling,
  but among trained runners the threshold (usable fraction) and economy (cost of
  pace) determine who wins. Coaching a runner *toward a VO₂max number* is the wrong
  target once they are past the beginner stage [Joyner & Coyle 2008; Jones 2006].
- **Trainability is genuinely individual and partly heritable** (~47% heritability of
  the *response*; gains from near-zero to >1 L/min for the same program). Baseline
  VO₂max does not predict how much a given runner will gain [Bouchard et al. 1999].
  Avoid promising a specific improvement.
- **"Non-responder" is usually dose-dependent, but the evidence that more volume
  abolishes non-response rests on small studies** and needs replication [Montero &
  Lundby 2017]. Hold this loosely; some genuine ceilings may exist.
- **Wearable VO₂max is a trend, not a truth.** Average group bias is small, but the
  individual error band is large (±5–10 mL/kg/min) and devices systematically
  over-estimate the unfit and under-estimate the fit [Molina-Garcia et al. 2022;
  Caserman et al. 2024]. Two different watches, or the same watch on a hilly/hot run,
  can disagree by several points. Never compare two people's wearable VO₂max.
- **The "plateau" criterion itself is contested** — many people never show a clear
  VO₂ plateau, so most reported values are VO₂peak, and even lab tests carry ~2–3%
  measurement variability.
- **Relative VO₂max is confounded by body mass.** A change in mL/kg/min can be pure
  weight change with no aerobic adaptation — always separate the two.
- **Cross-modal:** running VO₂max ≠ cycling VO₂max for the same person (running is
  typically higher); don't transfer a cycling-derived value to running prescription.

## Safety bounds

- **Maximal VO₂max tests and supramaximal vVO₂max intervals are near-maximal
  efforts** — gate behind adequate aerobic base, full recovery, and medical clearance
  where relevant (cardiac risk, symptoms, older/clinical populations). Never schedule
  for an injured, ill, or acutely fatigued runner, and not for Stage-1 beginners.
- Keep **above-threshold / VO₂max-intensity work a small, recovery-gated fraction**
  of the week (it accumulates fatigue fast and is non-steady-state); it does not
  replace aerobic volume.
- Do **not** use a wearable or formula VO₂max to clear someone for hard training or to
  set race pace — it is not a clinical or precise measure.
- **Not enforced in code.** The bounds above are rules for the coach to follow, not
  guarantees. (This line previously read "These bounds are mirrored as guardrails in
  `@daud/core` intensity/recovery checks" — a module that exists nowhere in this repo,
  in `~/projects/healthee-legacy`, or in git history; the phrase arrived with the
  upstream sports-science corpus import. Only directives a note declares
  `safety_critical` in its frontmatter compile into `insights/guard_directives.py`, and
  this note declares none — these bounds are a candidate for that mechanism, not a user
  of it. Corrected 2026-08-01, #87.)

## Bottom line

- **Act on confidently (conclusive):**
  - VO₂max is the **ceiling on aerobic capacity**, set primarily by **oxygen delivery
    (cardiac output + blood O₂ carriage)**, not muscle extraction, in healthy humans
    [Bassett & Howley 2000].
  - **VO₂max alone does not determine race performance.** It is one of three
    determinants with threshold and economy, and the *least* discriminating among
    trained runners; predict performance from threshold/economy/vVO₂max, not VO₂max
    [Joyner & Coyle 2008; Jones 2006; Coyle 1995].
  - VO₂max is **highly trainable in the untrained (~15–20%, ~4.9 mL/kg/min for HIIT)
    but the response is finite and plateaus** as fitness rises [Milanović et al. 2015;
    Bacon et al. 2013].
  - **Trainability is strongly individual and ~47% heritable** — never promise a
    specific gain from a program [Bouchard et al. 1999].
  - **Wearable VO₂max has small group bias but large individual error (±5–10
    mL/kg/min)** — a trend tool, never an exact value or a cross-person comparison
    [Molina-Garcia et al. 2022; Caserman et al. 2024].

- **Hold loosely (unsettled):**
  - That **more training volume abolishes "non-response" universally** — plausible but
    from small studies needing replication [Montero & Lundby 2017].
  - The **exact magnitude of an individual's trainable headroom** — heritable and
    unpredictable from baseline.
  - Whether a **true VO₂ plateau is required** to call a value VO₂max (definitional/
    methodological debate); most field and wearable values are really VO₂peak.
  - The **precise accuracy of any specific wearable model** — brand-, firmware- and
    condition-dependent, and evolving.

## Coach Directives

- **D1:** Treat VO₂max as a **ceiling/context metric, not a primary dial**; anchor
  prescription and progress to **threshold pace/HR and running economy**, not to a
  VO₂max number. — confidence: Established
- **D2:** **Never predict a race time or set race pace from VO₂max alone**; use
  threshold/critical-speed, recent race data, and vVO₂max (which folds in economy). —
  confidence: Established
- **D3:** Treat a **flat/plateaued VO₂max alongside improving threshold or race pace
  as normal and good** (economy/threshold gains), not as stagnation. — confidence:
  Established
- **D4:** Prioritise **VO₂max-raising work (vVO₂max intervals + aerobic volume) early
  in development** when headroom is largest; de-emphasise it once VO₂max plateaus and
  shift to threshold/economy. — confidence: Established
- **D5:** **Never promise a specific VO₂max gain** — trainability is ~47% heritable
  and ranges from near-zero to >1 L/min for the same program; individualise from the
  runner's own response. — confidence: Established
- **D6:** If a runner appears to be a **non-responder, escalate training dose/volume**
  before concluding a ceiling — but hedge, since this evidence is from small studies.
  — confidence: Probable
- **D7:** Attach an explicit **uncertainty band to every wearable VO₂max (±5–10
  mL/kg/min)**, use only the **multi-week trend**, never the absolute value, and
  **never compare two people's wearable VO₂max**. — confidence: Established
- **D8:** **Discount week-to-week wearable VO₂max swings** as noise (heat, hills,
  HR/GPS error, fatigue); require a sustained multi-week trend before inferring real
  change. — confidence: Established
- **D9:** Note that **relative VO₂max (mL/kg/min) moves with body mass** — separate
  weight change from aerobic adaptation before interpreting a change. — confidence:
  Established
- **D10:** Gate **maximal VO₂max tests and supramaximal vVO₂max intervals** behind
  aerobic base, full recovery, and (where relevant) medical clearance; never for
  injured/ill/fatigued or Stage-1 runners, and keep VO₂max-intensity work a small,
  recovery-gated fraction of the week. — confidence: Established (safety-critical;
  **not enforced in code** — the gate is the runner's aerobic base, recovery state and
  medical clearance, none of which an output rule can read from the answer text. A rule
  for the coach, not a guarantee. #100)

## Key references

- Bassett, D. R., Jr., & Howley, E. T. (2000). *Limiting factors for maximum oxygen
  uptake and determinants of endurance performance.* Medicine & Science in Sports &
  Exercise, 32(1), 70–84. PMID: 10647532. https://pubmed.ncbi.nlm.nih.gov/10647532/
- Joyner, M. J., & Coyle, E. F. (2008). *Endurance exercise performance: the
  physiology of champions.* The Journal of Physiology, 586(1), 35–44.
  https://doi.org/10.1113/jphysiol.2007.143834
- Coyle, E. F. (1995). *Integration of the physiological factors determining endurance
  performance ability.* Exercise and Sport Sciences Reviews, 23, 25–63. PMID: 7556353.
  https://pubmed.ncbi.nlm.nih.gov/7556353/
- Jones, A. M. (2006). *The physiology of the world record holder for the women's
  marathon.* International Journal of Sports Science & Coaching, 1(2), 101–116.
  https://doi.org/10.1260/174795406777641258
- Bouchard, C., An, P., Rice, T., Skinner, J. S., Wilmore, J. H., Gagnon, J., …
  Rao, D. C. (1999). *Familial aggregation of V̇O₂max response to exercise training:
  results from the HERITAGE Family Study.* Journal of Applied Physiology, 87(3),
  1003–1008. https://doi.org/10.1152/jappl.1999.87.3.1003
- Bacon, A. P., Carter, R. E., Ogle, E. A., & Joyner, M. J. (2013). *VO₂max
  trainability and high intensity interval training in humans: a meta-analysis.*
  PLOS ONE, 8(9), e73182. https://doi.org/10.1371/journal.pone.0073182
- Milanović, Z., Sporiš, G., & Weston, M. (2015). *Effectiveness of high-intensity
  interval training (HIT) and continuous endurance training for VO₂max improvements:
  a systematic review and meta-analysis of controlled trials.* Sports Medicine,
  45(10), 1469–1481. https://doi.org/10.1007/s40279-015-0365-0
- Montero, D., & Lundby, C. (2017). *Refuting the myth of non-response to exercise
  training: 'non-responders' do respond to higher dose of training.* The Journal of
  Physiology, 595(11), 3377–3387. https://doi.org/10.1113/JP273480
- Lundby, C., Montero, D., & Joyner, M. (2017). *Biology of VO₂max: looking under the
  physiology lamp.* Acta Physiologica, 220(2), 218–228.
  https://doi.org/10.1111/apha.12827
- Molina-Garcia, P., Notbohm, H. L., Schumann, M., Argent, R., Hetherington-Rauth, M.,
  Stang, J., … Ortega, F. B. (2022). *Validity of estimating the maximal oxygen
  consumption by consumer wearables: a systematic review with meta-analysis and
  expert statement of the INTERLIVE network.* Sports Medicine, 52(7), 1577–1597.
  https://doi.org/10.1007/s40279-021-01639-y
- Caserman, P., Yum, S., Göbel, S., Reif, A., & Matura, S. (2024). *Assessing the
  accuracy of smartwatch-based estimation of maximum oxygen uptake using the Apple
  Watch Series 7: validation study.* JMIR Biomedical Engineering, 9, e59459.
  https://doi.org/10.2196/59459
- Mandsager, K., Harb, S., Cremer, P., Phelan, D., Nissen, S. E., & Jaber, W. (2018).
  *Association of cardiorespiratory fitness with long-term mortality among adults
  undergoing exercise treadmill testing.* JAMA Network Open, 1(6), e183605.
  https://doi.org/10.1001/jamanetworkopen.2018.3605
- Kodama, S., Saito, K., Tanaka, S., et al. (2009). *Cardiorespiratory fitness as a
  quantitative predictor of all-cause mortality and cardiovascular events in healthy men
  and women: a meta-analysis.* JAMA, 301(19), 2024–2035.
  https://doi.org/10.1001/jama.2009.681
- Imboden, M. T., Harber, M. P., Whaley, M. H., et al. (2019). *The association between
  the change in directly measured cardiorespiratory fitness across time and mortality: an
  observational study.* Progress in Cardiovascular Diseases, 62(2), 157–162.
  https://doi.org/10.1016/j.pcad.2018.12.003
- Ross, R., Blair, S. N., Arena, R., et al. (2016). *Importance of assessing
  cardiorespiratory fitness in clinical practice: a case for fitness as a clinical vital
  sign* (AHA scientific statement). Circulation, 134(24), e653–e699.
  https://doi.org/10.1161/CIR.0000000000000461
- Stamatakis, E., Ahmadi, M. N., Gill, J. M. R., et al. (2022). *Association of wearable
  device-measured vigorous intermittent lifestyle physical activity with mortality.*
  Nature Medicine, 28, 2521–2529. https://doi.org/10.1038/s41591-022-02100-x

## Healthee implementation & honesty policy

- **Derived field: `vo2max_estimate`** (mL/kg/min) in `derived_daily` — an **estimate,
  never a lab value.** Healthee never runs a CPET; it derives the number by a tiered
  estimator and the maths live in two companion notes (this physiology note does not
  duplicate them): a **submaximal HR-vs-pace extrapolation** as the primary path when a
  workout has good steady-state HR+pace data ([[submaximal_vo2max]]), falling back to the
  **Jurca 2005 non-exercise model** from resting HR + demographics + activity
  ([[non_exercise_vo2max]]). Report the **7-day median + trend**, not a single value.
- **Projected-trajectory feature (the "visible plan").** Healthee shows a 12-week
  *projected* VO₂max gain to motivate the raising-VO₂max protocol above. The projection
  scales with the **gap to the age-median** (low fitness = more trainable headroom),
  bounded **+2 to +5 mL/kg/min**: `gain = clamp(0.4 × gap, 2, 5)` — i.e. ~40% of the gap
  closed in a 12-week block. This sits at the **conservative end** of the trainability
  literature (Bacon 2013's ~+6.4 mL/kg/min in young untrained would be the optimistic
  bound; we project ~half) and is physiologically right (bigger headroom → bigger
  response). It is shown as "≈{current}→{projected} in 12 wk **if you follow the plan**"
  with the citation, and **re-anchors to the user's own measured VO₂max estimate each
  week** so the projection cannot drift away from reality.
- **Age/sex percentile.** The value is shown against age- and sex-adjusted norms
  (Mandsager 2018 quintile table / ACSM) so the user sees a *percentile trajectory*, not
  an absolute — approximate, not clinical-grade.
- **Honesty rules (carry into UI + LLM):**
  - **Always labelled "estimate"** with a ±SEE / uncertainty band; never a single
    two-decimal number, and the **trend over months** is the signal, not the level.
  - **Never present absolute VO₂max as a "death-risk" number.** The CRF↔mortality
    evidence justifies *why we track and raise it* and frames it as a fitness
    *trajectory*; it is never converted into a personal hazard figure.
  - **Never compare two people's estimates** (large individual error; over-estimates the
    unfit, under-estimates the fit).
  - Relative VO₂max (mL/kg/min) **moves with body mass** — separate a weight change from
    a real aerobic change before interpreting a shift.
  - The projection is an **estimate of typical response, never a promise**; it depends on
    adherence and recovery, and for a recovery-limited/short-sleeping user, recovery is
    the binding constraint (tie intensity to [[recovery_readiness]]).
