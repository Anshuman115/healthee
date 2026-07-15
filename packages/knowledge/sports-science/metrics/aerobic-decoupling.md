---
name: aerobic-decoupling
title: Aerobic Decoupling & Cardiac Drift
category: cardiovascular
aliases:
  - decoupling
  - cardiac drift
  - heart rate drift
  - Pa:HR
  - Pw:HR
  - aerobic durability
  - efficiency factor
  - HR drift
  - heart rate recovery
  - HRR
  - cardiovascular drift
related:
  - hrv
  - aerobic-base
  - easy-running
  - heat-acclimatization
metrics:
  - computeDecoupling
units: "%, bpm"
evidence_overall: Probable
last_reviewed: 2026-06-29
---

# Aerobic Decoupling & Cardiac Drift

## Summary
**Aerobic decoupling** measures how much your heart rate "drifts" upward (or your
pace-per-beat falls) over a steady effort: it compares output-per-heartbeat in the
first half of a run to the second half. A drift **under ~5%** on a genuinely steady
aerobic run signals a well-developed aerobic base and good *durability* — your
cardiovascular system holds its output without extra cardiac cost. Larger drift
points to an under-built base, accumulated fatigue, or — very commonly — **heat,
dehydration, and glycogen depletion**, which physically reduce stroke volume and
force heart rate up to defend cardiac output [Coyle & González-Alonso 2001]. A
related, complementary signal is **heart-rate recovery (HRR)** — how fast HR falls
in the minute after you stop — which tracks vagal (parasympathetic) reactivation
and improves with fitness [Daanen 2012]. Decoupling is a *trend* metric: treat it
as one durability gauge cross-checked against heat, fuelling, and effort, never as
a verdict from a single run.

## What it is
Two distinct but linked concepts:

1. **Cardiac drift (cardiovascular drift)** — the *physiological phenomenon*: during
   constant-load prolonged exercise, heart rate climbs progressively while stroke
   volume falls, even though external workload (pace/power) is unchanged. It
   typically begins after **~10–15 min** and, in moderate steady exercise, adds on
   the order of **10–20 bpm over 30–60 min** [Coyle & González-Alonso 2001;
   Fritzsche et al. 1999].

2. **Aerobic decoupling (Pa:HR / Pw:HR)** — the *metric* that quantifies that drift.
   It is built on the **Efficiency Factor (EF)** = output ÷ heart rate
   (normalised-graded-pace ÷ avg HR for running; normalised power ÷ avg HR for
   cycling). Decoupling compares EF in the first half of a steady effort to the
   second half. The popularised convention (TrainingPeaks) is:

   - **< 5%** → strong aerobic endurance / durability at that intensity
   - **5–10%** → base developing, or moderate fatigue / intensity slightly high
   - **> 10%** → effort likely above aerobic threshold, or the base needs work

Typical ranges by training status (practitioner consensus, anchored to Smyth &
Muniz-Pumares 2022 marathon data): well-trained runners hold low single-digit drift
on long easy/threshold runs; recreational runners commonly show 5–15%+, and drift
magnitude scales with how far above critical speed they run.

**Heart-rate recovery (HRR)** is the third, related cardiovascular durability cue:
the number of beats HR drops in the first **60 s** (sometimes 120 s) after stopping
or easing a hard effort. Faster recovery = stronger parasympathetic reactivation =
generally fitter/fresher.

## Physiology / mechanism

**Why the heart "drifts."** Cardiac output (Q̇ = HR × stroke volume) must stay
roughly matched to the muscle's oxygen demand at a fixed pace. Over a prolonged
bout, **stroke volume progressively falls**, so to defend Q̇ the heart **raises HR**
to compensate [Coyle & González-Alonso 2001]. Two mechanisms drive the falling
stroke volume:

- **Reduced cardiac filling (preload).** Sweating lowers plasma volume, and
  cutaneous vasodilation for cooling pools blood in the periphery — both reduce
  venous return and left-ventricular filling, the dominant cause of the stroke-volume
  drop [González-Alonso et al. 2008; Watanabe et al. 2020].
- **Shortened filling time.** Coyle's group showed the stroke-volume decline is
  *itself substantially driven by the rising heart rate* reducing diastolic filling
  time — when HR was experimentally held from rising (β-blockade/pacing), the stroke-
  volume drift was largely prevented. This reframed drift as partly a heart-rate-led,
  not purely skin-blood-flow-led, phenomenon [Fritzsche et al. 1999].

**The amplifiers — heat, dehydration, glycogen depletion.**
- **Hyperthermia:** as core temperature rises, more cardiac output is diverted to
  skin for cooling and HR climbs further. Fatigue in the heat tends to converge on a
  core temperature **slightly above 40 °C** regardless of starting temperature
  [González-Alonso et al. 2008].
- **Dehydration:** progressive fluid loss (toward **~2–4% body mass**) compounds
  plasma-volume loss, further cutting stroke volume, cardiac output, and muscle/skin/
  brain blood flow while pushing HR, core temperature, and peripheral resistance up.
  Dehydration *graded* the size of the drift in classic work [Montain & Coyle 1992;
  González-Alonso et al. 1997]. Minimising thermoregulatory load (cool environment)
  blunts both the stroke-volume fall and the HR rise [González-Alonso et al. 2008].
- **Glycogen depletion:** as carbohydrate stores deplete over long efforts, the body
  shifts toward fat oxidation, efficiency falls, and the internal cost of a given
  pace rises — a key driver of late-exercise decoupling and loss of durability.
  Carbohydrate ingestion attenuates the deterioration of thresholds and power output
  during prolonged exercise [Hunter et al. 2025].

**Why HRR tracks fitness.** The rapid HR fall after exercise (especially the first
~30 s) is principally **vagal reactivation** — parasympathetic outflow returning as
sympathetic drive withdraws. Because vagal tone and reactivation improve with
aerobic fitness and freshness (and are blunted by fatigue, illness, dehydration, and
heat), HRR is a low-cost autonomic readout of training status [Cole et al. 1999;
Daanen et al. 2012].

## The evidence

- **[Established]** Cardiovascular drift is real and well-characterised: stroke
  volume declines and HR rises progressively after ~10–15 min of constant-load
  prolonged exercise [Coyle & González-Alonso 2001, *Exerc Sport Sci Rev*]. The
  falling stroke volume is driven largely by reduced ventricular filling, and the
  rising HR itself contributes by shortening filling time [Fritzsche et al. 1999,
  *J Appl Physiol* — controlled human study].

- **[Established]** Heat and dehydration markedly worsen the cardiovascular strain:
  dehydration to ~4% body mass during exercise in the heat reduces stroke volume,
  cardiac output, and arterial pressure while raising HR and core temperature;
  graded dehydration grades the drift; cooling/rehydration attenuates it
  [González-Alonso et al. 1997; Montain & Coyle 1992; González-Alonso et al. 2008,
  *J Physiol* review]. Mechanism confirmed as impaired filling/venous return rather
  than impaired LV contractility [Watanabe et al. 2020, *Physiol Rep*].

- **[Probable]** Lower decoupling indexes better endurance "durability" and predicts
  better long-distance performance. In **82,303 recreational marathoners**, faster
  finishers decoupled less; decoupling magnitude and onset were associated with
  marathon performance and improved performance prediction [Smyth & Muniz-Pumares
  2022, *Sports Medicine*]. Durability is now framed as a distinct, trainable fourth
  endurance parameter alongside V̇O₂max, economy, and thresholds [Maunder et al.
  2021, *Sports Medicine*; Hunter et al. 2025, *Exp Physiol*].

- **[Probable]** Heart-rate recovery reflects training status and improves with
  fitness. A systematic review (5 cross-sectional + 8 longitudinal studies) found
  HRR generally faster in trained athletes and that it rose alongside training status
  longitudinally — though confounders (age, ambient temperature, preceding exercise
  intensity/duration) limit cross-study comparison [Daanen et al. 2012, *IJSPP*].
  Intervention data: HIIT and polarised training improved acute HRR (~8–11%) in
  well-trained athletes, whereas high-volume low-intensity training alone produced
  **no measurable HRR change** over 9 weeks [Stöggl & Björklund 2017, *Front
  Physiol*, n=31].

- **[Established]** HRR carries genuine autonomic/health signal beyond sport. The
  strongest evidence is a **meta-analysis of 9 prospective cohorts (41,600 people,
  2,082 deaths)**: attenuated vs fast HRR carried a pooled hazard ratio of **1.68
  (95% CI 1.51–1.88)** for all-cause mortality and **1.69 (1.05–2.71)** for
  cardiovascular events, with each **10 bpm lower HRR** associated with ~9% higher
  all-cause mortality and ~13% higher CV-event risk — independent of metabolic risk
  factors [Qiu et al. 2017, *J Am Heart Assoc*]. The seminal primary study behind
  this is Cole's cohort: an abnormal 1-minute HRR (**≤12 bpm**) after a treadmill
  test predicted ~4× higher all-cause mortality over 6 years, independent of fitness
  and risk factors [Cole et al. 1999, *NEJM*, n=2,428]. These are clinical, not
  training-load, thresholds — used here only to confirm HRR is a real autonomic
  marker; the *autonomic determinants* of HRR (early fall = vagal reactivation,
  later fall = sympathetic withdrawal) are reviewed in [Peçanha et al. 2014, *Clin
  Physiol Funct Imaging*].

- **[Contested]** The *strength and universality* of the decoupling→performance link
  in tightly controlled lab settings. Some laboratory durability studies have **not**
  found HR-to-speed decoupling to track performance or other durability markers;
  Smyth's huge-sample association may partly reflect that scale averaging out the
  day-to-day noise that swamps individual-run decoupling [Hunter et al. 2025]. Treat
  decoupling as a useful trend, not a precise lab measure.

- **[Myth / Refuted]** "Cardiac drift means you're getting fitter mid-run / your
  heart is failing." Drift is a normal thermoregulatory and filling-time response;
  on a hot or under-fuelled day even a fit runner drifts. A *single* high-drift run
  does not diagnose a weak aerobic base — context (heat, hydration, fuelling,
  pacing) must be weighed first.

## How we compute it

**Decoupling** (owned by `computeDecoupling` in `@daud/core`):

```
EF (efficiency factor) = output / heart_rate
  running:  output = normalised-graded-pace (speed-like, higher = faster)
  cycling:  output = normalised power
Split the steady portion into first half (EF₁) and second half (EF₂).
Decoupling % = (EF₁ − EF₂) / EF₁ × 100
```

A positive value = EF fell from first to second half = HR drifted up relative to
output. `@daud/core` classifies: `< 5%` → **strong-base**, `5–10%` → **moderate**,
`> 10%` → **high**. Implementation note: garbage-in if the effort wasn't steady —
the function should be fed (or restricted to) a sustained, single-intensity block
with warm-up, surges, hills, and stops excluded, or the split is meaningless.

**Heart-rate recovery** — *not yet computed* in `@daud/core`. Definition for when it
is added: `HRR₆₀ = HR_at_effort_end − HR_60s_after_easing`, measured from a
repeatable trigger (end of a hard rep or a standardised submaximal step). Report in
bpm; track the personal trend, not an absolute population cut-off.

**Estimation error vs ground truth.** Both are wrist/chest-HR-driven and inherit
optical-HR lag and motion artefact (especially the abrupt post-effort window for
HRR). Pace-based EF for running depends on GPS quality and grade-adjustment accuracy.
These are *estimates of trends*, not lab cardiac-output measurements.

## How the coach uses it

**Decoupling — durability gauge on long/steady runs.**
- Compute only on genuinely steady aerobic efforts (long easy runs, steady-state /
  threshold blocks), ideally **≥45–60 min** for running so a drift can develop.
- **< 5%** at a target intensity → aerobic base is solid *at that intensity*; the
  runner has earned the right to add duration or step up intensity.
- **5–10%** → base developing or the day's effort/conditions were taxing; hold
  volume, keep building easy aerobic work before piling on intensity.
- **> 10%** on a supposedly easy run → either the "easy" pace was actually above
  aerobic threshold (check effort/HR), or base/durability is the limiter. Counsel
  more easy volume and re-test under controlled conditions.

**Always cross-check before interpreting drift as a base gap:** heat/humidity,
hydration status, fuelling/glycogen state, sleep, illness, caffeine, and pacing.
On a hot or fasted run, attribute drift to conditions first. Weight **effort and
pace alongside HR in heat** — do not let a heat-inflated HR force a slowdown that
effort doesn't justify (see heat-acclimatization).

**HRR — readiness and trend.** A faster-than-usual post-effort HR drop suggests good
autonomic recovery/freshness; a blunted drop versus the personal baseline (alongside
elevated resting HR, low HRV, poor sleep) is a soft flag for fatigue, dehydration,
heat strain, or illness — bias toward easier work. Use the runner's own trend, not
the clinical ≤12 bpm figure, for training decisions.

**By stage:**
- **Stage 1 (beginner):** don't surface raw decoupling numbers; use them internally
  to confirm "easy" is actually easy. High drift on easy runs → prescribe slowing
  down and more easy volume. Keep messaging encouraging, not diagnostic.
- **Stage 2 (developing):** introduce periodic decoupling "durability checks" on long
  runs; use the <5% milestone as a green-light to progress intensity. Begin trending
  HRR if a clean trigger exists.
- **Stage 3 (racing):** use decoupling on long/marathon-specific efforts as a
  race-readiness durability index; pair with fuelling and heat strategy, since those
  are the dominant late-race drift drivers. Use HRR/HRV trends to titrate taper.

## Honesty & uncertainty
- **Decoupling is noisy and condition-sensitive.** Heat, humidity, dehydration,
  under-fuelling, caffeine, sleep, altitude, and even cardiac drift from a single
  hard prior day can all inflate it independent of aerobic base. One run proves
  nothing; only repeated, condition-matched tests trend reliably.
- **Steady-state requirement is strict.** Surges, hills, stops, and GPS pace noise
  corrupt the first-half/second-half split. Running decoupling via grade-adjusted
  pace is shakier than cycling power-based decoupling.
- **The 5% / 10% bands are practitioner conventions**, popularised by TrainingPeaks,
  not hard physiological constants. They're a reasonable starting heuristic to be
  individualised from the runner's own data, not a law.
- **Lab vs field disagreement is real.** Massive field datasets link decoupling to
  performance [Smyth & Muniz-Pumares 2022], but controlled lab studies sometimes find
  no association between HR–speed decoupling and other durability markers [Hunter et
  al. 2025]. The metric is a useful *trend*, weaker as a precise individual measure.
- **HRR confounders are substantial.** Age, ambient temperature, the intensity/
  duration of the preceding effort, body position, active vs passive recovery, and
  hydration all move HRR; protocols aren't standardised across studies, so absolute
  numbers don't transfer [Daanen et al. 2012]. HRR also responds mainly to higher-
  intensity training — a runner doing only easy volume may improve aerobically with
  little HRR change [Stöggl & Björklund 2017].
- **What we still don't know:** the precise individual decoupling threshold that best
  predicts race durability for a given runner, how much of late-run drift is heat vs
  dehydration vs glycogen in the field, and how to cleanly separate "base gap" from
  "today's conditions" without controlled re-testing.

## Safety bounds
- **No autonomous pace/training override from decoupling or HRR alone** — both are
  trend signals, not safety instruments. Do not down-rank or stop a session purely on
  drift.
- **Heat-strain escalation is the safety-relevant edge.** Rising drift *together with*
  signs of heat illness (disproportionate HR, dizziness, chills, stopping sweating,
  confusion) on a hot day is a stop-and-cool signal, mirrored by the
  heat-acclimatization guardrails — core temperatures slightly above 40 °C mark the
  fatigue/danger zone [González-Alonso et al. 2008]. Drift here is a symptom; the
  guardrail belongs to heat/hydration safety, not to decoupling.
- The clinical HRR ≤12 bpm mortality threshold [Cole et al. 1999] is **not** a
  training rule; if a runner reports a persistently and abnormally blunted HRR with
  symptoms, advise medical review rather than acting on it as a training metric.

## Bottom line

**Act on confidently (conclusive):**
- Cardiovascular drift is a real, well-replicated phenomenon: in prolonged constant-
  load exercise, stroke volume falls and HR rises after ~10–15 min — driven mainly by
  reduced ventricular filling, with the rising HR itself shortening filling time
  [Coyle & González-Alonso 2001; Fritzsche et al. 1999]. *Established.*
- Heat and dehydration (toward ~2–4% body mass) are major, causally-demonstrated
  amplifiers of drift: graded dehydration grades it, and cooling/rehydration blunt it
  [Montain & Coyle 1992; González-Alonso et al. 1997, 2008]. *Established.* Glycogen
  depletion is a mechanistically expected additional amplifier — carbohydrate intake
  attenuates threshold/power deterioration in prolonged exercise — but its specific
  contribution to the decoupling metric rests on indirect/review evidence, not
  controlled drift experiments [Hunter et al. 2025]. *Probable.* → On hot or
  under-fuelled runs, attribute drift to conditions first, and weight effort/pace
  alongside a heat-inflated HR.
- HRR is a genuine autonomic marker: a meta-analysis of 9 cohorts (41,600 people)
  ties slower HRR to higher mortality and CV risk [Qiu et al. 2017; Cole et al. 1999].
  *Established* — but as a health/autonomic signal, not a per-session training dial.
- Decoupling must be computed only on a genuinely steady single-intensity block, or
  the first/second-half split is meaningless. *Established (methodological).*

**Hold loosely (unsettled):**
- The exact decoupling **bands (<5% / 5–10% / >10%)** are TrainingPeaks practitioner
  conventions, not physiological constants — a starting heuristic to individualise.
  *Probable.*
- That **lower decoupling indexes better durability/performance** holds at population
  scale [Smyth et al. 2022] but is weaker and sometimes absent in controlled lab
  studies [Hunter et al. 2025] — treat it as a multi-run *trend*, not a precise
  per-run measure. *Probable, with lab/field disagreement.*
- **HRR as a training-status gauge** is real but confounder-laden (age, temperature,
  preceding-effort intensity, posture, hydration; no standard protocol), and responds
  mainly to higher-intensity work — a runner on easy-only volume may improve
  aerobically with little HRR change [Daanen et al. 2012; Stöggl & Björklund 2017].
  *Probable.* Use the personal trend, never the clinical ≤12 bpm cut-off, for training.

## Coach Directives

- **D1:** Compute decoupling only on a sustained, single-intensity block (running:
  ideally ≥45–60 min); exclude warm-up, surges, hills, and stops. If the effort
  wasn't steady, do not report a drift number. — confidence: Established
- **D2:** Interpret running decoupling bands as **<5% strong-base**, **5–10%
  moderate**, **>10% high**, matching `computeDecoupling`. Treat these as starting
  heuristics to individualise, not physiological constants. — confidence: Probable
- **D3:** Before attributing high drift to a weak aerobic base, rule out heat,
  humidity, dehydration, under-fuelling/glycogen depletion, illness, and pacing above
  aerobic threshold. Attribute drift on hot or fasted runs to conditions first. —
  confidence: Established
- **D4:** Use a sustained **<5%** decoupling at a target intensity as a green-light to
  progress duration or intensity; use **>10%** on a nominally easy run to prescribe
  more easy aerobic volume and a controlled re-test. — confidence: Probable
- **D5:** Treat decoupling as a multi-run **trend**, never a verdict from one session;
  require condition-matched repeats before concluding about durability. — confidence:
  Probable
- **D6:** In heat, weight effort and pace alongside HR; do not force a slowdown that
  perceived effort doesn't justify purely because HR drifted up. — confidence:
  Established
- **D7:** Track HRR as a personal-baseline trend (HR drop in first 60 s after a
  repeatable trigger); a blunted HRR vs baseline — especially with high resting HR /
  low HRV / poor sleep — is a soft fatigue/under-recovery flag biasing toward easier
  work. Use the personal trend, not the clinical ≤12 bpm figure. — confidence:
  Probable
- **D8:** Expect HRR to improve mainly with higher-intensity/polarised training; do
  not interpret a flat HRR under easy-only training as lack of aerobic progress. —
  confidence: Probable
- **D9 (safety):** Never override pacing or stop a session on decoupling/HRR alone.
  Rising drift *plus* heat-illness signs on a hot day defers to the
  heat/hydration safety guardrails (stop-and-cool), which the AI cannot override. —
  confidence: Established

## Key references

- Coyle, E. F., & González-Alonso, J. (2001). *Cardiovascular drift during prolonged
  exercise: new perspectives.* Exercise and Sport Sciences Reviews, 29(2), 88–92.
  https://doi.org/10.1097/00003677-200104000-00009 (PMID: 11337829)
- Fritzsche, R. G., Switzer, T. W., Hodgkinson, B. J., & Coyle, E. F. (1999). *Stroke
  volume decline during prolonged exercise is influenced by the increase in heart
  rate.* Journal of Applied Physiology, 86(3), 799–805.
  https://doi.org/10.1152/jappl.1999.86.3.799
- González-Alonso, J., Mora-Rodríguez, R., Below, P. R., & Coyle, E. F. (1997).
  *Dehydration markedly impairs cardiovascular function in hyperthermic endurance
  athletes during exercise.* Journal of Applied Physiology, 82(4), 1229–1236.
  https://doi.org/10.1152/jappl.1997.82.4.1229
- Montain, S. J., & Coyle, E. F. (1992). *Influence of graded dehydration on
  hyperthermia and cardiovascular drift during exercise.* Journal of Applied
  Physiology, 73(4), 1340–1350. https://doi.org/10.1152/jappl.1992.73.4.1340
- González-Alonso, J., Crandall, C. G., & Johnson, J. M. (2008). *The cardiovascular
  challenge of exercising in the heat.* The Journal of Physiology, 586(1), 45–53.
  https://doi.org/10.1113/jphysiol.2007.142158 (PMCID: PMC2375553)
- Watanabe, K., Stöhr, E. J., Akiyama, K., Watanabe, S., & González-Alonso, J. (2020).
  *Dehydration reduces stroke volume and cardiac output during exercise because of
  impaired cardiac filling and venous return, not left ventricular function.*
  Physiological Reports, 8(11), e14433. https://doi.org/10.14814/phy2.14433
- Smyth, B., Maunder, E., Meyler, S., Hunter, B., & Muniz-Pumares, D. (2022).
  *Decoupling of internal and external workload during a marathon: an analysis of
  durability in 82,303 recreational runners.* Sports Medicine, 52(9), 2283–2295.
  https://doi.org/10.1007/s40279-022-01680-5 (PMID: 35511416)
- Maunder, E., Seiler, S., Mildenhall, M. J., Kilding, A. E., & Plews, D. J. (2021).
  *The importance of 'durability' in the physiological profiling of endurance
  athletes.* Sports Medicine, 51(8), 1619–1628.
  https://doi.org/10.1007/s40279-021-01459-0
- Hunter, B., Maunder, E., Jones, A. M., Gallo, G., & Muniz-Pumares, D. (2025).
  *Durability as an index of endurance exercise performance: methodological
  considerations.* Experimental Physiology, 110(11), 1612–1624.
  https://doi.org/10.1113/EP092120
- Cole, C. R., Blackstone, E. H., Pashkow, F. J., Snader, C. E., & Lauer, M. S.
  (1999). *Heart-rate recovery immediately after exercise as a predictor of
  mortality.* New England Journal of Medicine, 341(18), 1351–1357.
  https://doi.org/10.1056/NEJM199910283411804 (PMID: 10536127)
- Qiu, S., Cai, X., Sun, Z., Li, L., Zuegel, M., Steinacker, J. M., & Schumann, U.
  (2017). *Heart rate recovery and risk of cardiovascular events and all-cause
  mortality: a meta-analysis of prospective cohort studies.* Journal of the American
  Heart Association, 6(5), e005505. https://doi.org/10.1161/JAHA.117.005505
- Peçanha, T., Silva-Júnior, N. D., & Forjaz, C. L. M. (2014). *Heart rate recovery:
  autonomic determinants, methods of assessment and association with mortality and
  cardiovascular diseases.* Clinical Physiology and Functional Imaging, 34(5),
  327–339. https://doi.org/10.1111/cpf.12102 (PMID: 24237859)
- Daanen, H. A. M., Lamberts, R. P., Kallen, V. L., Jin, A., & Van Meeteren, N. L. U.
  (2012). *A systematic review on heart-rate recovery to monitor changes in training
  status in athletes.* International Journal of Sports Physiology and Performance,
  7(3), 251–260. https://doi.org/10.1123/ijspp.7.3.251 (PMID: 22357753)
- Stöggl, T. L., & Björklund, G. (2017). *High intensity interval training leads to
  greater improvements in acute heart rate recovery and anaerobic power than high
  volume low intensity training.* Frontiers in Physiology, 8, 562.
  https://doi.org/10.3389/fphys.2017.00562
