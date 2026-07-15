---
name: readiness
title: Readiness (Composite)
category: load-recovery
aliases: [readiness, readiness score, daily readiness, training readiness, recovery score, recovery status, body battery, go no-go, green light, autoregulation, morning check-in, wellness check, am I ready to train]
related: [heart-rate-variability, resting-heart-rate, sleep-and-recovery, training-load-acwr, fitness-fatigue-form, training-stress-score, individualization]
metrics: [readiness, recoveryScore]
units: composite band (go / modify / rest) or 0–100 index; component units vary (ms, bpm, h, AU, 1–5)
evidence_overall: Probable
last_reviewed: 2026-06-29
---

# Readiness (Composite)

## Summary
Readiness is a **composite read** of how prepared a runner is to absorb a hard
session today, integrating five signals that each have their own doc: **HRV trend**,
**sleep**, **resting-HR trend**, **prior training load**, and **subjective wellness**.
The single most important rule: **no individual input is decisive.** Every component
is noisy, confounded, and individual on its own — the value comes from
*triangulation*, where concordant signals raise confidence and conflicting signals
lower it. The principle that you should monitor several markers rather than trust one
is well-supported (Established) by the overtraining-monitoring consensus and by the
fact that **subjective wellness is at least as sensitive as objective markers**
[Saw 2016; Meeusen 2013]. What is **not** settled (Emerging/Contested) is any
*specific composite number or weighting*: commercial "readiness/recovery" scores are
proprietary black boxes whose underlying HRV/RHR/sleep signals are validated but whose
composite algorithms are not independently validated [Bellenger 2021; Dial 2025].
Daud therefore treats readiness as a **transparent, opt-in suggestion the runner can
always override — a prompt to ask a question, never a verdict.**

## What it is
"Readiness" (also marketed as *recovery score*, *body battery*, *recovery status*) is a
daily, morning-facing estimate of recovery state, expressed either as a 0–100 index or,
in Daud, as a three-way **go / modify / rest** band. It is a *derived* construct: it has
no ground truth of its own, only the ground truths of its inputs. Daud's five inputs:

| Component | What it contributes | Owning doc |
|---|---|---|
| **HRV trend** | Autonomic (parasympathetic) recovery vs personal baseline | `heart-rate-variability` |
| **Sleep** | The largest single recovery lever: duration trend + debt | `sleep-and-recovery` |
| **RHR trend** | Coarse autonomic/illness/fatigue signal vs baseline | `resting-heart-rate` |
| **Prior load** | What the body is being asked to absorb (ramp / ACWR / form) | `training-load-acwr`, `fitness-fatigue-form` |
| **Subjective wellness** | Fatigue, soreness, stress, mood — cheap and sensitive | `sleep-and-recovery` (and below) |

A readiness read answers one narrow question — *"is today a good day to deliver the
planned hard stimulus?"* — and **not** "how fit am I", "will I get injured", or "am I
overtrained". It is an **autoregulation** tool that times intensity within a plan; it
does not set the plan (periodisation does).

Typical operating bands (starting defaults, individualised per runner):
- **Go / green** — components at or above baseline; proceed with planned quality.
- **Modify / amber** — one or more components meaningfully off-baseline, or mixed
  signals; soften or shift intensity, keep the session.
- **Rest / red** — multiple concordant negatives, or a single safety-critical input
  (illness, acute sleep deprivation, pain); reduce to easy or rest.

## Physiology / mechanism
There is no single "readiness organ"; the construct works only insofar as its
components each track a real strand of recovery and the strands are partly
**independent**:

- **HRV** indexes cardiac **parasympathetic (vagal)** reactivation — fast, beat-to-beat
  autonomic recovery. (See `heart-rate-variability`.)
- **RHR** reflects intrinsic sinoatrial rate plus autonomic tone, and rises with
  systemic stress, inflammation, and incipient illness — a slower, coarser autonomic
  read partly **decoupled** from HRV. (See `resting-heart-rate`.)
- **Sleep** is the master restorative process — GH-driven tissue repair, glycogen
  resynthesis, CNS and immune restoration — and sleep loss degrades the exact
  capacities a hard session taxes (skill control, reaction time, perceived effort)
  *before* it degrades gross force. (See `sleep-and-recovery`.)
- **Prior load** is the demand side: the fitness–fatigue balance and recent ramp set
  how much residual fatigue the autonomic and musculoskeletal systems are clearing.
  (See `fitness-fatigue-form`, `training-load-acwr`.)
- **Subjective wellness** integrates everything the sensors miss — psychological
  stress, life load, muscle soreness, motivation, illness prodrome — through the
  athlete's own perception, which is why it is often the **first** thing to move.

The mechanistic case for *combining* them is that each captures a different failure
mode, and any one can be fooled. The classic trap is the **overreaching paradox**:
vagal HRV markers can *rise* paradoxically in functionally overreached athletes, and
post-exercise HRV increases in both good adaptation and overreaching — so HRV alone
"cannot independently distinguish positive from negative adaptations" [Bellenger 2016].
A composite covers that blind spot: an HRV that looks fine is contradicted by rising
RHR, poor sleep, a load spike, and heavy-legged wellness. **Concordance is the signal;
a lone outlier is usually noise.**

## The evidence

Readiness sits on two evidence layers: (1) strong evidence for the **principle** of
multi-marker, triangulated monitoring and for each component's validity, and (2) thin,
unsettled evidence for any **specific composite score** as a validated predictor.

### The principle: monitor several markers, not one

- **[Established]** No single marker diagnoses recovery/overtraining; integrated,
  multi-parameter monitoring is the consensus standard — *expert joint consensus
  statement (ECSS/ACSM)*. Diagnosis of overtraining "requires exclusion of other
  causes" and the combination of markers; no individual physiological or biochemical
  variable is pathognomonic [Meeusen 2013]. Narrative and methodological reviews of
  HR-based monitoring reach the same conclusion: resting/submaximal HR and HRV each add
  partial information and must be read together with load and wellness, not in isolation
  [Buchheit 2014].

- **[Established]** **Subjective self-report is at least as sensitive as objective
  markers** — *systematic review of 56 studies* [Saw 2016, BJSM]. Subjective and
  objective measures of athlete well-being generally **did not correlate** with each
  other, yet subjective measures reflected acute and chronic training load with
  *superior* sensitivity and consistency: subjective well-being reliably declined with
  acute load increases and chronic loading, and improved with acute load reduction. The
  practical implication is foundational for readiness — the cheap 1–5 morning check-in
  is not a poor substitute for sensors; it is a first-class, often *earlier*, signal.

- **[Probable]** A simple composite **subjective** index tracks staleness/overtraining
  and can outperform biochemical markers — *seminal prospective cohort, 14 elite
  swimmers over a 6-month season* [Hooper 1995]. A battery of self-reported well-being
  ratings (fatigue, stress, sleep, muscle soreness — the original "Hooper index")
  predicted staleness scores, accounting for **~76% of variance** (rising to ~85% with
  resting catecholamines added), and the authors concluded psychological self-report was
  *more* sensitive to overtraining than the physiological/biochemical measures. Small,
  single-sport, and dated, but directionally consistent with [Saw 2016].

- **[Probable]** Readiness-style autoregulation (timing hard sessions by a recovery
  signal) modestly beats fixed plans. The closest body of trial evidence is
  **HRV-guided training**: a meta-analysis of 6 RCTs (195 endurance athletes) found a
  larger pooled fitness effect for HRV-guided than predefined training (SMD ≈ 0.40 vs
  0.22), strongest in amateurs [Granero-Gallegos 2020], though a stricter meta-analysis
  found effects on VO₂max/endurance trivial and non-significant [Manresa-Rocamora 2021].
  This validates the *autoregulation behaviour* readiness drives (don't prescribe
  intensity on a bad day), not any particular composite formula. (Detail in
  `heart-rate-variability`.)

### The components are individually valid (so the inputs are real)

- **[Established]** The underlying physiological signals readiness rests on are
  measurable on consumer wearables. Overnight **RHR** agrees near-perfectly with ECG
  (e.g. CCC 0.91–0.98 across Oura/WHOOP; Oura MAPE ~1.7–1.9%), and **HRV (RMSSD)** agrees
  well though more loosely (CCC 0.82–0.99; MAPE ~6–8%) — *device-validation studies vs
  Polar H10 / ECG* [Dial 2025; Bellenger 2021]. So the *inputs* to a readiness score are
  trustworthy when measured with a fixed, validated protocol.

### The composite *score* itself is unsettled

- **[Emerging / Contested]** **No specific readiness/recovery composite is independently
  validated as a predictor.** Commercial scores (WHOOP Recovery, Oura Readiness, Garmin
  Body Battery) are **proprietary black boxes**: the component signals they ingest (HRV,
  RHR, sleep) are validated [Bellenger 2021; Dial 2025], but the **weighting and the
  composite output** are not transparently published and lack independent peer-reviewed
  validation of their decision accuracy. The WHOOP validation that does exist covers the
  *sensor accuracy* (HR near-perfect, HRV approaching its own meaningful-change
  threshold), **not** the recovery percentage's predictive value [Bellenger 2021].
  Treat any single readiness number — Daud's included — as a **low-precision summary**,
  not a measured quantity.

- **[Emerging]** Multivariate/machine-learning models that fuse training, sleep, HRV and
  subjective wellness to predict next-day recovery are an active research area and
  outperform single inputs in-sample, but are early, dataset-specific, and not yet
  cross-validated into deployable, generalising rules. Promising direction, not settled
  science.

- **[Probable]** **How readiness is *delivered* changes whether it helps.** Imposed,
  controlled self-monitoring can backfire: athletes who used a self-report measure
  because they were *instructed to* (rather than autonomously) were **less responsive**,
  and forced monitoring showed preliminary signs of reduced intrinsic motivation —
  *qualitative/implementation research in elite sport* [Saw 2015]. This is the empirical
  basis for making readiness **opt-in and overridable**, not a mandatory verdict. It
  parallels "orthosomnia," where anxious chasing of device sleep/recovery scores worsens
  the very thing being measured (see `sleep-and-recovery`).

**Consistency verdict:** the *principle* (triangulate; no single number; subjective
counts) is **consistent and well-supported**. Any *specific composite score or
threshold* is **unsettled** — plausible, component-valid, but not independently proven
as a predictor or shown in an RCT to improve outcomes over its parts.

## How we compute it
Daud computes readiness **transparently from its own component metrics**, not as an
opaque score — every readiness read can be decomposed back to the inputs that drove it.
The `readiness` / `recoveryScore` metrics are **partially owned** by `@daud/core` and
should be flagged **not-yet-fully-verified-in-code** until the function and its tests
exist; the component metrics it consumes are owned by their respective modules.

Inputs (each a *direction/deviation vs the runner's own baseline*, never an absolute):
- **HRV** — `hrvBaseline` direction (lnRMSSD vs 7-day mean ± 1 SD) and `hrvCv`.
- **RHR** — `rhrDeviation` (bpm and within-person SD vs baseline).
- **Sleep** — 7-night duration trend and accumulated debt vs personal target; subjective
  sleep quality.
- **Prior load** — weekly ramp / long-run progression and (hedged) EWMA-ACWR / form.
- **Subjective wellness** — a daily 1–5 self-report of fatigue, soreness, stress, mood
  (a Hooper-style mini-index) [Hooper 1995; Saw 2016].

Composition rules (design intent, not a validated formula):
- **Each component maps to a contribution ∈ {negative, neutral, positive}**, gated by its
  own smallest-worthwhile-change band so within-noise readings count as neutral.
- **No single component can force "go".** A clean HRV cannot upgrade a day that sleep,
  load, or wellness drag down.
- **Safety-critical inputs can unilaterally force "rest/modify"** (illness signs, acute
  sleep deprivation, reported pain) — these are guardrails, not votes (see *Safety*).
- **Concordance scales confidence.** ≥3 inputs agreeing → high-confidence band and firmer
  coaching language; mixed/conflicting inputs → low-confidence band, defer to the runner.
- **Weights are individualised and start equal-ish**, refined as the runner's own history
  reveals which signals track their performance (per `individualization`).

**Estimation-error flags:** readiness inherits *every* input's noise and confounds
(alcohol, caffeine, heat, late meals, menstrual-cycle phase, travel, psychological
stress, device/protocol drift, and ACWR's instability at low chronic load). It is
**undefined or low-confidence** until each component has enough history (≈2–3 weeks for
HRV/RHR baselines; ≥28 days before ACWR contributes). A single day is never decisive;
the unit of action is the **multi-day trend**.

## How the coach uses it
Core stance: **readiness is an opt-in suggestion that opens a conversation; the runner
can always override it.** The coach surfaces *why* (which components moved), proposes a
modification, and lets the athlete decide — it never silently rewrites the plan or
delivers a bare verdict.

- **Go (concordant positives / all near baseline):** green-light the planned quality.
  Speak plainly ("everything looks recovered — good day for the intervals").
- **Modify (mixed or one meaningful negative):** keep the session but soften it — cut
  reps, drop to the easier end of the intensity range, or swap quality order. Hedge the
  language ("HRV and sleep are a bit down — let's trim the session and see how you feel
  in the warm-up").
- **Rest / easy (multiple concordant negatives):** convert to easy aerobic or rest, and
  say which signals drove it. A persistent multi-day decline across HRV + RHR + sleep +
  wellness is the strongest non-safety signal to back off.
- **Conflict → defer to the runner.** When signals disagree (great HRV, terrible sleep;
  or clean sensors, heavy legs), confidence is low — present both, weight the
  **subjective report and any pain** highest [Saw 2016], and let the athlete choose.
- **Always show the components.** Never present readiness as a number alone; the
  decomposition is what makes it trustworthy and overridable.

By **stage**:
- **Stage 1 (beginner):** readiness is **educational, not directive**. Baselines aren't
  formed, ACWR is meaningless, and device noise is alarming. Lean on **sleep and a simple
  subjective check-in**; use readiness to *teach* the recovery concept. After a clearly
  bad night, keep the run easy and short rather than skipping — protect the habit.
- **Stage 2 (developing):** begin light autoregulation — let a **persistent, concordant**
  readiness dip shift or soften the next quality session, corroborated across ≥2 inputs.
  This is where the autoregulation benefit is clearest, especially for non-elites
  [Granero-Gallegos 2020].
- **Stage 3 (racing/advanced):** full readiness-guided timing of hard blocks against
  stable individual baselines, read **through the plan's intent** (a taper lowers load by
  design; an overload block elevates fatigue by design). Never let a single green
  readiness clear a runner reporting rising fatigue, and never let one red day derail a
  well-judged plan.

## Honesty & uncertainty
- **The composite number is the weakest part.** The triangulation *principle* is strong;
  the specific *score and weighting* are not validated. No RCT shows that any composite
  readiness score improves performance or reduces injury **better than its components**.
  Daud keeps the score transparent and hedged for exactly this reason.
- **Garbage in, garbage out — multiplied.** Readiness inherits every confounder of every
  input: alcohol, caffeine, heat, dehydration, late meals, illness, psychological/life
  stress, menstrual-cycle phase, travel/jet-lag, and device/protocol drift all move
  components independent of training. A "low readiness" morning is frequently a
  late-meal-plus-wine morning, not a training signal.
- **Components disagree, and that's expected.** HRV and RHR are only partly coupled;
  subjective wellness routinely **doesn't correlate** with objective markers [Saw 2016].
  Disagreement is information (lower confidence), not a malfunction. Forcing a single
  tidy number hides this.
- **The overreaching blind spot persists.** Because vagal markers can rise when
  overreached [Bellenger 2016], a *high* readiness does **not** clear an athlete reporting
  mounting fatigue, sleep disruption, mood decline, or stalling performance. Readiness can
  be falsely reassuring; subjective decline and performance trump a green score.
- **Reactivity / orthosomnia.** Pushing a daily verdict at an anxious runner can *cause*
  the stress and poor sleep it claims to measure, and imposed monitoring reduces
  responsiveness and intrinsic motivation [Saw 2015]. Readiness must be opt-in,
  framed as information, and never moralised.
- **Individual weighting is unknown a priori.** Which signal best predicts *this* runner's
  good and bad days is learned, not assumed; population-default weights are a starting
  estimate only (per `individualization`).
- **What's still unknown:** the right component weights; whether a composite beats reading
  components separately; the smallest-worthwhile-change band for the composite; how to fuse
  signals that conflict; and whether ML fusion models generalise out of sample. Treat
  advanced composite scoring as **Emerging**.

## Safety bounds
Readiness is **not** a clinical tool and its *score* is not a guardrail, but it
**routes** several safety-critical inputs that are hard bounds in their own docs and are
mirrored in `@daud/core`. These **override** any "go" the composite would otherwise give:

- **Illness rule (hard, mirrored):** RHR sustained above baseline *with* illness symptoms
  (fever, sore throat, body aches, malaise) → do **not** prescribe hard/intense training;
  advise rest. Training intensely through febrile illness carries cardiac risk
  (myocarditis). Cannot be overridden by a green readiness or by the runner
  [see `resting-heart-rate`].
- **Acute sleep deprivation (hard, mirrored):** acute deprivation (e.g. <~4–5 h, or a
  string of sub-6-h nights) caps prescribed intensity/load regardless of other inputs —
  no PRs, max efforts, or load jumps; default easy/short or rest [see `sleep-and-recovery`].
- **Pain / injury (hard override):** any reported pain, injury, or red-flag wellness signal
  overrides every "safe"/"go" readiness reading [see `training-load-acwr`].
- **Clinical red flags (refer out):** syncope, chest pain, unexplained breathlessness,
  symptomatic bradycardia — route to medical advice; never reassure cardiac symptoms.
- Otherwise: readiness-driven *easing* is conservative and low-risk. Readiness must
  **never** be used to *escalate* training on its own (no input may justify a hard
  session that the safety bounds or a runner's pain report forbid).

## Bottom line

- **Act on confidently (conclusive):**
  - **Triangulate; never decide on one number.** No single physiological marker
    diagnoses recovery — the consensus standard is multi-parameter monitoring read
    together [Meeusen 2013; Buchheit 2014].
  - **Subjective wellness is a first-class signal**, at least as sensitive as objective
    markers and often earlier — always include a cheap morning self-report, and weight it
    (and any pain) highest when signals conflict [Saw 2016; Hooper 1995].
  - **Concordance = confidence.** Multiple inputs agreeing (HRV down + RHR up + poor sleep
    + high load + heavy legs) is a strong, actionable "ease" signal; a lone outlier is
    usually noise.
  - **A high readiness never clears a fatigued or ill athlete** — vagal markers can rise
    when overreached, so subjective decline and the safety bounds override a green score
    [Bellenger 2016].
  - **Safety inputs (illness, acute sleep loss, pain) are hard overrides**, not votes.

- **Hold loosely (unsettled):**
  - **Any specific composite score or weighting.** Commercial readiness scores are
    proprietary and not independently validated as predictors; the underlying signals are
    valid, the composite is not [Bellenger 2021; Dial 2025]. Daud's score is a
    transparent, hedged summary, not a measurement.
  - **The exact thresholds and component weights** — starting defaults to be individualised
    from the runner's own history; which signal best predicts *their* days is learned.
  - **Whether a composite beats reading the components separately**, and whether ML fusion
    models generalise — Emerging.

## Coach Directives

- **D1:** Compute readiness by **triangulating ≥3 components** (HRV trend, sleep, RHR
  trend, prior load, subjective wellness); **no single input may be decisive**, and never
  present a readiness number without its component breakdown. — confidence: Established
- **D2:** **Always include a subjective morning check-in** (fatigue/soreness/stress/mood);
  treat it as at least as sensitive as the sensor data, and weight it (plus any pain)
  **highest when signals conflict**. — confidence: Established
- **D3:** Act on the **multi-day trend and concordance**, not a single day or single
  input; scale coaching confidence to how many inputs agree. — confidence: Established
- **D4:** Map readiness to **go / modify / rest** as a **suggestion the runner can
  override**, explaining which components drove it — never a bare verdict or a silent plan
  rewrite. — confidence: Probable
- **D5:** **Never let a high/green readiness clear a runner** who reports rising fatigue,
  poor sleep, mood decline, illness, pain, or stalling performance; vagal markers can rise
  when overreached. — confidence: Established (safety-relevant)
- **D6:** **Safety inputs are hard overrides, not votes:** illness-symptom + elevated RHR,
  acute sleep deprivation, and any reported pain/injury force modify/rest regardless of the
  composite. Mirror in `@daud/core`; cannot be overridden by the AI or the score. — confidence: Established (safety-critical)
- **D7:** **Never use readiness to escalate** training beyond the plan; it eases or holds,
  it does not justify extra intensity. — confidence: Probable
- **D8:** Treat the **composite number as low-precision** and **individualise the weights**;
  population defaults are a starting estimate, refined from the runner's own data. Do not
  present commercial-style scores as validated measurements. — confidence: Probable
- **D9:** Suppress or down-weight readiness when components lack history (≈2–3 weeks for
  HRV/RHR baselines; ≥28 days before ACWR contributes) or when an obvious confounder
  (alcohol, late meal, heat, travel, illness, menstrual phase) explains a dip. — confidence: Probable
- **D10:** Keep readiness **opt-in and non-moralised**; imposed daily verdicts reduce
  responsiveness and can cause the stress they measure (reactivity/orthosomnia). — confidence: Probable
- **D11:** In **Stage 1**, use readiness **educationally** (lean on sleep + subjective
  check-in); begin light autoregulation in **Stage 2** (persistent concordant dips soften
  quality); full readiness-guided block timing in **Stage 3**, read through the plan's
  intent. — confidence: Probable

## Key references

- Saw, A. E., Main, L. C., & Gastin, P. B. (2016). *Monitoring the athlete training
  response: subjective self-reported measures trump commonly used objective measures: a
  systematic review.* British Journal of Sports Medicine, 50(5), 281–291.
  https://doi.org/10.1136/bjsports-2015-094758
- Saw, A. E., Main, L. C., & Gastin, P. B. (2015). *Monitoring athletes through
  self-report: factors influencing implementation.* Journal of Sports Science & Medicine,
  14(1), 137–146. https://pmc.ncbi.nlm.nih.gov/articles/PMC4306765/
- Hooper, S. L., Mackinnon, L. T., Howard, A., Gordon, R. D., & Bachmann, A. W. (1995).
  *Markers for monitoring overtraining and recovery.* Medicine & Science in Sports &
  Exercise, 27(1), 106–112. https://doi.org/10.1249/00005768-199501000-00019
- Meeusen, R., Duclos, M., Foster, C., et al. (2013). *Prevention, diagnosis, and treatment
  of the overtraining syndrome: Joint consensus statement of the ECSS and the ACSM.*
  European Journal of Sport Science, 13(1), 1–24 (also Med Sci Sports Exerc, 45(1),
  186–205). https://doi.org/10.1080/17461391.2012.730061
- Buchheit, M. (2014). *Monitoring training status with HR measures: do all roads lead to
  Rome?* Frontiers in Physiology, 5, 73. https://doi.org/10.3389/fphys.2014.00073
- Bellenger, C. R., Fuller, J. T., Thomson, R. L., Davison, K., Robertson, E. Y., &
  Buckley, J. D. (2016). *Monitoring athletic training status through autonomic heart rate
  regulation: a systematic review and meta-analysis.* Sports Medicine, 46(10), 1461–1486.
  https://doi.org/10.1007/s40279-016-0484-2
- Bellenger, C. R., Miller, D. J., Halson, S. L., Roach, G. D., & Sargent, C. (2021).
  *Wrist-based photoplethysmography assessment of heart rate and heart rate variability:
  validation of WHOOP.* Sensors, 21(10), 3571. https://doi.org/10.3390/s21103571
- Dial, M. B., Hollander, M. E., Vatne, E. A., Emerson, A. M., Edwards, N. A., & Hagen, J. A.
  (2025). *Validation of nocturnal resting heart rate and heart rate variability in consumer
  wearables.* Physiological Reports, 13(16), e70527. https://doi.org/10.14814/phy2.70527
- Granero-Gallegos, A., González-Quílez, A., Plews, D., & Carrasco-Poyatos, M. (2020).
  *HRV-based training for improving VO2max in endurance athletes: a systematic review with
  meta-analysis.* International Journal of Environmental Research and Public Health, 17(21),
  7999. https://doi.org/10.3390/ijerph17217999
- Manresa-Rocamora, A., Sarabia, J. M., Javaloyes, A., Flatt, A. A., & Moya-Ramón, M.
  (2021). *Heart rate variability-guided training for enhancing cardiac-vagal modulation,
  aerobic fitness, and endurance performance: a methodological systematic review with
  meta-analysis.* International Journal of Environmental Research and Public Health, 18(19),
  10299. https://doi.org/10.3390/ijerph181910299
</content>
</invoke>
