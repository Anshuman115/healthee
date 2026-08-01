---
id: fitness_fatigue_form
name: "Fitness / Fatigue / Form (CTL, ATL, TSB)"
category: metrics
grade: Probable
summary: "Impulse-response bookkeeping: CTL≈fitness, ATL≈fatigue, TSB≈form; useful for trends and tapering, but coarse and never overrides subjective/HRV signals."
population: runners
aliases: ["fitness-fatigue-form", "ctl", "atl", "tsb", "training stress balance", "chronic training load", "acute training load", "fitness fatigue form", "banister model", "impulse response model", "performance management chart", "pmc", "form", "freshness", "training load model"]
applies_to_metrics: []
applies_to_interventions: []
last_reviewed: 2026-06-29
related: ["acute-chronic-workload-ratio", "training-stress-score", "tapering", "periodisation", "recovery", "hrv"]
units: "TSS/day (AU) for CTL/ATL; TSS (AU) for TSB; days for time constants"
---
# Fitness / Fatigue / Form (CTL, ATL, TSB)

## Summary
The fitness–fatigue (impulse–response) model treats every training session as an
"impulse" that produces two opposing, exponentially-decaying responses: a slow,
long-lasting **fitness** response and a fast, short-lived **fatigue** response.
Performance at any moment is **fitness minus fatigue**. TrainingPeaks/Coggan
operationalised this as three numbers from daily Training Stress Score (TSS):
**CTL** (Chronic Training Load, ~42-day average) ≈ fitness, **ATL** (Acute
Training Load, ~7-day average) ≈ fatigue, and **TSB** (Training Stress Balance =
CTL − ATL) ≈ **form/freshness**. The single most important coaching takeaway:
**the model is a genuinely useful bookkeeping tool for trends and tapering —
build CTL slowly, then let ATL fall so TSB rises into a slightly-positive band
for race day — but its parameters are statistically ill-conditioned, the 42/7-day
constants are population defaults not personal truths, and TSB is a coarse
readiness proxy that must never override the runner's own subjective and HRV
signals.**

## What it is
The model has two layers: the **conceptual physiology** (fitness vs fatigue) and
the **practical metrics** (CTL/ATL/TSB) that approximate it.

**Conceptual (Banister impulse–response).** A quantified training dose (an
"impulse", historically TRIMP — Training Impulse) raises two internal state
variables. Fitness rises and decays slowly; fatigue rises higher per unit dose
but decays quickly. Modelled performance = (gain × fitness) − (gain × fatigue).
Because fatigue clears faster than fitness, **reducing load reveals fitness** —
this is the mathematical basis of tapering and supercompensation.

**Practical (CTL/ATL/TSB).** Each metric is an exponentially-weighted moving
average (EWMA) of daily training load (TSS), differing only in time constant:

| Metric | Meaning | Default time constant | Interpreted as |
|---|---|---|---|
| **CTL** | Chronic Training Load | **42 days** | Fitness (aerobic base, durability) |
| **ATL** | Acute Training Load | **7 days** | Fatigue (recent accumulated stress) |
| **TSB** | Training Stress Balance = CTL − ATL | — | Form / freshness / "readiness to race" |

Together, plotted over time, these form the **Performance Management Chart (PMC)**
invented by Coggan & Allen [Allen & Coggan; TrainingPeaks].

Typical CTL ranges (units are TSS/day, where ~100 TSS ≈ one hard threshold hour):

> [!WARNING] **This table is uncited (#100).** No source in this note supports any of these four bands, or the “−30 to +25” TSB range stated below the table. It
> is practitioner convention from the TrainingPeaks/Coggan tradition, restated without a source; CTL is a modelled bookkeeping quantity, not a measured one, so there is no population it *could* be sampled from. It is flagged rather than deleted because the numbers do carry the one genuinely useful fact — that CTL is comparable only to the same athlete's own history, and an “elite” number means nothing without the same load model behind it — but the coach must present
> these as rough orientation, never as norms a runner can be measured against, and must
> not attach a runner's own number to a row as if that placed them.
> Why this matters more than an ordinary uncited line: **the note body is what reaches
> the model** (`manifest.prompt_body`), so an unlabelled norm table is a constant the
> coach will quote with the note's authority and no hedge.


| Athlete | CTL (TSS/day) |
|---|---|
| Casual / Stage 1 beginner | ~20–40 |
| Committed recreational runner | ~50–80 |
| Competitive amateur (marathon-focused) | ~80–110 |
| Elite endurance athlete | ~120–150+ (rarely sustained above ~150) |

TSB is unitless-feeling but carries TSS units; it typically ranges from about −30
(deep in a hard block) to +25 (well rested/tapered).

## Physiology / mechanism
The model is **phenomenological, not mechanistic** — it does not claim to measure
any specific tissue. It is a control-systems abstraction (a first-order linear
filter) that happens to fit observed performance reasonably well. The biological
intuition behind it:

- **Fitness (slow component)** stands in for the durable adaptations of endurance
  training — plasma-volume expansion, mitochondrial and capillary density,
  cardiac remodelling, glycogen storage, tendon/bone remodelling. These take
  weeks to build and weeks to lose, hence the long (~42–50 day) time constant.
- **Fatigue (fast component)** stands in for transient, recoverable costs —
  glycogen depletion, muscle damage and soreness, fluid and hormonal
  disturbance, neuromuscular and central fatigue. These resolve in days, hence
  the short (~7–15 day) time constant.
- Because the two responses share the same input but decay at different rates,
  **the net curve (performance) lags training and overshoots when training is
  withdrawn** — the model's elegant explanation of why a taper makes you faster:
  you stop adding fatigue while fitness is still high, so the gap (form) widens.

The EWMA implementation is a discrete recursion of exactly this first-order
filter — each day's value carries forward most of yesterday's plus a sliver of
today's load.

## The evidence

- **[Established]** The qualitative impulse–response structure — training raises
  both fitness and fatigue, fatigue decays faster, and net performance is their
  difference — is the foundational framework of quantitative training-load
  modelling and has survived 50 years in various forms [Banister et al. 1975;
  Calvert et al. 1976]. That *load must be built progressively and tapered to
  peak* is not seriously disputed.
- **[Established]** Reducing training load before competition (a taper) while
  maintaining intensity improves performance — the operational prediction of the
  model. Two independent meta-analyses confirm this: Bosquet et al. (2007) pooled
  27 studies and found a **2-week taper with training volume reduced 41–60%**
  (intensity and frequency held) is optimal, with a moderate overall effect on
  performance (ES ≈ 0.59, p < 0.001) [Bosquet et al. 2007]; Wang et al. (2023)
  replicated this specifically in endurance athletes (time-trial SMD −0.45, 95% CI
  −0.68 to −0.23) [Wang et al. 2023]. Caveat: these reviews validate *tapering*,
  not the Banister parameters per se — the model predicts the right direction, but
  the meta-analytic evidence stands on its own.
- **[Probable]** The original Banister fits used a fitness time constant of
  ~**45–50 days** and a fatigue time constant of ~**11–15 days**, with the
  fatigue gain factor (k2) roughly **2× the fitness gain** (k1) — i.e. each unit
  of training costs about twice the fatigue it earns in fitness, which is why
  fatigue dominates acutely and fitness dominates chronically [Banister et al.
  1975; Morton et al. 1990]. TrainingPeaks rounded these to the now-ubiquitous
  **42 / 7** day constants for CTL/ATL [Allen & Coggan].
- **[Probable]** The model can fit an individual's past performances well *in
  sample*. Morton, Fitz-Clarke & Banister (1990) modelled running performance
  from training and reproduced the criterion performances closely [Morton et al.
  1990].
- **[Probable]** Slightly-positive form predicts better performance than deep
  fatigue or excessive freshness. Coggan's practitioner guidance: TSB **below
  ~−10** rarely feels fresh, **−10 to +10** is "neutral", and **above ~+10**
  usually brings fresh legs; A-race form is typically targeted around **+5 to
  +25** [Allen & Coggan; TrainingPeaks; Friel].
- **[Contested]** Whether the **fatigue component is statistically real or an
  overfit artefact.** Hellard et al. (2006) showed the Banister model is
  **ill-conditioned** in elite swimmers — fitness and fatigue parameters cannot
  be reliably separated, and adding the fatigue parameters did **not** improve
  out-of-sample prediction (p > 0.40) [Hellard et al. 2006]. Marchal et al.
  (2025) replicated this with Bayesian/cross-validation methods: the model is
  ill-conditioned, fitness and fatigue are poorly identifiable, and the fatigue
  terms add complexity that captures noise rather than signal [Marchal et al.
  2025].
- **[Contested]** Whether the time-constant numbers mean anything physiological.
  Vermeire et al. (2022) argue the τ parameter **cannot** be read as "a number of
  days" and the k parameters are not clean magnitude/conversion factors; the
  model should be treated as one inseparable entity, not decomposed into "your
  fitness decays in 42 days" claims [Vermeire et al. 2022].
- **[Probable]** Better-conditioned variants exist but are not in mainstream
  apps. Busso (2003) added a **variable (nonlinear) fatigue** term — fatigue per
  unit load grows when prior load is high — which models overreaching better than
  the fixed-constant version [Busso 2003]. Machine-learning and Bayesian
  reformulations improve generalisation but add data and complexity [Imbach et
  al. 2022].
- **[Contested]** The *rate of change* of load (closely related to ATL/CTL and to
  the acute:chronic ratio) may track injury risk in runners: even modest fortnightly
  increases in the acute:chronic workload ratio were associated with higher
  injury risk in a single observational cohort of 23 competitive runners over 24
  months [Dijkhuis et al. 2020]. This is suggestive that CTL **ramp rate** matters,
  not just CTL level — but it is one small cohort, and the broader ACWR
  injury-prediction framework is methodologically contested (see
  `acute-chronic-workload-ratio`), so treat ramp limits as prudent governors, not
  validated cutoffs.
- **[Myth]** "TSB is a measured readiness/recovery score." It is not — TSB is
  derived **purely from logged training load**. It knows nothing about your
  sleep, illness, life stress, nutrition, or HRV. A perfect TSB on paper can sit
  on top of a runner who is sick or sleep-deprived.

## How we compute it
**TSS (the input).** Daily training load. For running, TrainingPeaks uses
**rTSS** from Normalized Graded Pace (NGP) relative to functional threshold pace
(FTP): `rTSS = (duration_s × NGP × IF) / (FTP × 3600) × 100`, where the Intensity
Factor `IF = NGP / FTP`. One hour at threshold = 100 TSS by definition. (Daud may
substitute a TRIMP- or session-RPE-based load; the model is agnostic to the load
unit so long as it is consistent.)

**CTL / ATL (EWMA recursion).** Each is yesterday's value decayed plus today's
load weighted in:

```
CTL_today = CTL_yesterday × e^(−1/42) + TSS_today × (1 − e^(−1/42))
ATL_today = ATL_yesterday × e^(−1/7)  + TSS_today × (1 − e^(−1/7))
```

So CTL carries forward ~97.6% of yesterday daily; ATL only ~86.7%. CTL therefore
moves slowly (fitness), ATL fast (fatigue).

**TSB (form).** The standard convention uses **yesterday's** CTL and ATL so that
today's planned session does not retroactively change today's freshness:

```
TSB_today = CTL_yesterday − ATL_yesterday
```

Treat outputs as **trend signals with wide uncertainty**, not precise physiology. The
time constants (42/7) are **defaults to be individualised** — a runner who detrains
fast or recovers slowly may warrant different constants, but changing them is an
advanced, data-hungry operation (see Honesty).

> **Provenance, checked 2026-08-01 (#88) — and this one holds up.** This paragraph
> used to begin "**In @daud/core:** these map to the load-model functions
> (`computeCTL`/`computeATL`/`computeTSB`…)". `@daud/core` exists **nowhere** — not
> this repo, not `~/projects/healthee-legacy`, not git history — so the sentence
> described an implementation that has never existed, and it is removed rather than
> reworded.
>
> **The 42/7 constants themselves are NOT a phantom-source case**, unlike the
> `pace-zones` bands and the `training-stress-score` preference order audited
> alongside them. Their trail is stated in full in "The evidence" above and it is
> real: Banister's own fits (~45–50 d fitness, ~11–15 d fatigue, k2 ≈ 2·k1) [Banister
> et al. 1975; Morton et al. 1990], **rounded** by TrainingPeaks to 42/7 [Allen &
> Coggan 2019 — a trade book, cited as the origin of the Performance Management Chart
> and named as such in the References]. The note already says the rounding is a
> rounding, already warns that τ "cannot be interpreted as a literal number of days"
> [Vermeire 2022], and already grades the constants **Contested** in D7. Nothing here
> needs correcting except the module that never existed.
>
> Nor is anything shipped: no CTL, ATL or TSB is computed anywhere in `apps/`
> (verified by grep, 2026-08-01) — see the implementation section.

## How the coach uses it
**General stance:** use CTL for the slow story (is the base growing?), TSB for the
fast story (is the runner fresh or buried?), and the **CTL ramp rate** as a load-
safety governor. Always cross-check TSB against the runner's reported feel,
sleep, and HRV before acting — TSB is blind to all of those.

**Reading TSB (form) — practitioner bands, treat as Probable, individualise:**

| TSB | State | Coaching use |
|---|---|---|
| **below −30** | Dangerously buried | Heightened injury/illness/overtraining risk — back off [Friel] |
| **−30 to −10** | Productive overload | Normal, healthy hard-training range; expected mid-block |
| **−10 to +5** | Neutral / "grey zone" | Transitional; should be brief, not a parking spot |

> **The +5 edge is ours, not Coggan's (#100).** The only *cited* band set in this note
> — under *The evidence* — reads **neutral −10 to +10, fresh above +10** [Allen & Coggan;
> TrainingPeaks; Friel]. This table and every downstream use (D3, `periodization`,
> `COACHING-RULES`) put the fresh/race-ready floor at **+5**, so TSB +5 to +10 is
> simultaneously "grey zone" here and "race-ready" there. The **+5 to +25 race-target
> band is the corpus's canonical one** and it is practitioner consensus, not a measured
> threshold; the +5–+10 overlap with "neutral" is real ambiguity in the source material,
> not a number to resolve by picking. Do not restate either edge as sourced.
| **+5 to +15** | Fresh, race-ready (lower) | Good A-race form for many runners; sharpening |
| **+15 to +25** | Peaked | Classic A-race target; well-tapered |
| **above +25** | Detraining | Too rested — fitness (CTL) is bleeding away |

**Building fitness (CTL).** Raise CTL through consistent load, but **cap the ramp
rate**: avoid sustained increases beyond ~**5–7 TSS/day/week** for four+ weeks —
faster escalation is repeatedly linked to illness, overtraining and injury [Allen
& Coggan; Dijkhuis et al. 2020]. A rising CTL with TSB held in the productive
band (−10 to −30) is the signature of a healthy build.

**Tapering / peaking (the model's headline use).** To peak: hold CTL as high as
possible while letting ATL fall, so TSB climbs into the target band by race day.
Practically — cut volume substantially (the meta-analytic optimum is **41–60%
over ~2 weeks**, intensity and frequency preserved) while keeping some intensity,
so fatigue clears faster than fitness [Bosquet et al. 2007; Wang et al. 2023].
Aim to **arrive at race day
with TSB roughly +5 to +25**, biased toward the lower end for shorter/repeated
races and the higher end for a single marathon goal [Friel; TrainingPeaks]. The
individual sweet spot varies — refine it from the runner's own race-day TSB-vs-
result history.

**By stage:**
- **Stage 1 (beginner):** Do not surface CTL/ATL/TSB numbers as targets. Use the
  *ramp-rate* logic invisibly to keep progression gentle. Beginners' load data is
  sparse and noisy, so the EWMAs are unreliable early; lean on subjective feel
  and simple weekly-volume caps instead.
- **Stage 2 (developing):** Introduce CTL as a "fitness trend" and use TSB to time
  recovery weeks (let TSB recover toward neutral every ~3–5 weeks [progressive-overload D5]). Enforce the
  CTL ramp-rate cap. Begin learning the runner's personal "fresh" TSB.
- **Stage 3 (racing/trained):** Full PMC use — periodise CTL build → overload →
  taper, and plan the taper to land TSB in the runner's validated race band. This
  is where the model earns its keep.

**Cross-check rules:**
- If TSB is positive (fresh) but HRV is suppressed, sleep is poor, or the runner
  reports heavy legs — **trust the body, not the number**; defer hard work.
- If TSB is deeply negative but the runner feels great and HRV is stable, a
  planned overload may be fine — but watch the ramp rate.
- A sudden CTL/ATL jump from a single huge session (e.g. an ultra or a GPS error
  inflating TSS) distorts the EWMAs for days — discount it.

## Honesty & uncertainty
- **The fatigue component may be statistically illusory.** Two independent
  analyses (elite swimmers; Bayesian cross-validation) found the model
  ill-conditioned: fitness and fatigue parameters are not separately identifiable,
  and the fatigue terms do not improve out-of-sample prediction [Hellard et al.
  2006; Marchal et al. 2025]. Read TSB as a **useful heuristic**, not a measured
  truth.
- **The time constants are not personal physiology.** 42 and 7 days are rounded
  population defaults. Vermeire et al. (2022) warn the τ parameter cannot be
  interpreted as a literal number of days; individual fitness/fatigue dynamics
  vary substantially and the "right" constants differ by athlete, sport, and load
  metric [Vermeire et al. 2022]. Fitting personal constants requires many
  performance data points and is itself unstable — so individualisation is
  aspirational, done cautiously, not a quick toggle.
- **Garbage in, garbage out.** Everything downstream depends on the load (TSS)
  input being accurate and consistent. rTSS needs a correct functional threshold
  pace; a stale FTP, GPS/pace errors, treadmill runs, heat, or trail terrain all
  corrupt TSS and therefore CTL/ATL/TSB. Strength work, cross-training, and
  non-running stress are often invisible to the model.
- **TSB is load-only and life-blind.** It excludes sleep, illness, psychological
  stress, travel, nutrition, and menstrual-cycle effects. A textbook +15 taper
  means nothing if the runner is fighting a virus. This is precisely why the
  model must be *one* input among several (data + HRV/readiness + subjective),
  never the sole arbiter.
- **Linearity and fixed gains are simplifications.** Real fatigue compounds
  nonlinearly when load stacks; Busso's variable-fatigue model exists because the
  fixed-constant version under-predicts deep-overreaching fatigue [Busso 2003].
  The standard CTL/ATL/TSB you see in apps does **not** use that refinement.
- **Day-to-day noise and the "grey zone."** Small TSB wobbles (±5) are within the
  noise of imperfect load logging — do not over-interpret them. The −10 to +10
  band is genuinely ambiguous.
- **What's still unknown / debated:** the true individual time constants and
  whether they are stable within a person across a season; whether the optimal
  race-day TSB is a fixed target or shifts with event duration and training
  history; and how to best fuse TSB with HRV and subjective readiness into a
  single trustworthy signal. These are open questions, so the coach should hold
  TSB-based claims with light hedging.

## Safety bounds
- **CTL ramp-rate cap (safety-mirrored):** do not let planned load drive a
  sustained CTL increase beyond ~**5–7 TSS/day/week** for four or more
  consecutive weeks; faster ramps are linked to illness/overtraining/injury
  [Allen & Coggan; Dijkhuis et al. 2020]. This pairs with the acute:chronic
  workload ratio guardrail (see `acute-chronic-workload-ratio`).
- **Deep-fatigue floor:** treat sustained TSB **below ~−30** as a heightened
  injury/illness-risk zone [Friel]; permitted only briefly and deliberately, and
  never when HRV/readiness/subjective flags are also negative.
- **Never let a "fresh" TSB override a red readiness signal.** A positive TSB does
  not authorise hard training when HRV is suppressed, the runner is ill, or sleep
  is severely disrupted. Subjective and HRV red flags win.

## Bottom line

**Act on confidently (conclusive):**
- The qualitative impulse–response structure — training builds slow-decaying
  fitness and fast-decaying fatigue, and net form is their difference — is the
  settled foundation of load modelling [Banister 1975; Calvert 1976].
- **Tapering works.** Reducing volume 41–60% over ~2 weeks while holding intensity
  and frequency improves endurance performance — two independent meta-analyses
  agree [Bosquet et al. 2007; Wang et al. 2023]. This is the model's headline,
  evidence-backed use.
- **CTL/ATL/TSB are sound bookkeeping for trends.** Build CTL gradually, watch the
  ramp rate, and let ATL fall before a race so TSB rises into a slightly-positive
  band — directionally reliable.
- **TSB is load-only and life-blind.** It is computed purely from logged training
  and knows nothing about sleep, illness, HRV, or life stress — a settled fact
  about what the number is, not a debate.

**Hold loosely (unsettled):**
- **The fatigue component may be a statistical artefact.** Two independent analyses
  found the Banister model ill-conditioned, with fitness and fatigue not separately
  identifiable and the fatigue terms failing to improve out-of-sample prediction
  [Hellard et al. 2006; Marchal et al. 2025]. Treat TSB as a heuristic, not a
  measurement.
- **The 42/7-day constants are population defaults, not personal physiology**, and
  the τ parameter cannot be read literally as "a number of days" [Vermeire et al.
  2022]. Individualising them is data-hungry and itself unstable.
- **The optimal race-day TSB is not a fixed target.** The +5 to +25 band is
  practitioner consensus; the real sweet spot shifts with event duration, training
  history, and the individual — learn it from the runner's own race-day-TSB-vs-
  result record.
- **CTL ramp-rate / ACWR injury thresholds are suggestive, not validated.** Faster
  ramps associate with higher injury risk in small cohorts [Dijkhuis et al. 2020],
  but the broader ACWR injury-prediction framework is methodologically contested
  (see `acute-chronic-workload-ratio`) — use ramp limits as prudent governors, not
  proven cutoffs.

## Coach Directives
- **D1:** Model every training stimulus as raising both fitness (slow,
  CTL/~42-day) and fatigue (fast, ATL/~7-day); judge readiness by their
  difference, TSB = CTL − ATL. — confidence: Established
- **D2:** Build fitness by raising CTL gradually; cap sustained increases at
  ~5–7 TSS/day/week over four+ weeks and flag faster ramps as injury/overtraining
  risk. — confidence: Probable (safety mirror)
- **D3:** To peak for an A-race, hold CTL high while letting ATL fall, targeting
  race-day TSB in the **+5 to +25** band (lower for short/repeat races, higher for
  a single marathon goal); refine the exact target from the runner's own race-
  day-TSB history. — confidence: Probable
- **D4:** Treat TSB **below −30** as a heightened risk zone — permit only briefly
  and never alongside negative HRV/subjective signals. — confidence: Probable
  (safety mirror)
- **D5:** Treat TSB **above +25** as detraining; if seen outside a deliberate
  short taper, add load back. — confidence: Probable
- **D6:** Never let a positive (fresh) TSB override a red readiness signal —
  suppressed HRV, illness, or severe sleep loss veto hard training regardless of
  form. — confidence: Established. **Not enforced in code** *(#87: this said "safety
  mirror", which claimed a guardrail that does not exist. Only a directive a note
  declares `safety_critical` in frontmatter compiles a blocking rule into
  `insights/guard_directives.py`, and this note declares none — nor could it, since
  Healthee computes no TSB for a rule to key on.)*
- **D7:** Treat the 42/7-day constants and all TSB bands as population defaults to
  be individualised from the runner's data, never as literal personal physiology;
  speak about them with light hedging. — confidence: Contested
- **D8:** Communicate CTL and TSB as **trends**, not precise scores; ignore TSB
  wobbles within ~±5 and discount EWMA distortion from single anomalous sessions
  or bad pace/GPS data. — confidence: Probable
- **D9:** Validate the TSS input before trusting any CTL/ATL/TSB — stale threshold
  pace, heat, trails, treadmills, and non-running load all corrupt it; missing
  load means the model is blind, not that the runner is fresh. — confidence:
  Established
- **D10:** For beginners (Stage 1), use the ramp-rate logic invisibly and do not
  surface CTL/ATL/TSB as targets until enough consistent data exists for the EWMAs
  to be meaningful. — confidence: Probable

## Key references
- Banister, E. W., Calvert, T. W., Savage, M. V., & Bach, T. (1975). *A systems
  model of training for athletic performance.* Australian Journal of Sports
  Medicine, 7(3), 57–61. (No DOI — seminal pre-digital paper.)
- Calvert, T. W., Banister, E. W., Savage, M. V., & Bach, T. (1976). *A systems
  model of the effects of training on physical performance.* IEEE Transactions on
  Systems, Man, and Cybernetics, SMC-6(2), 94–102.
  https://doi.org/10.1109/TSMC.1976.5409179
- Morton, R. H., Fitz-Clarke, J. R., & Banister, E. W. (1990). *Modeling human
  performance in running.* Journal of Applied Physiology, 69(3), 1171–1177.
  https://doi.org/10.1152/jappl.1990.69.3.1171
- Busso, T. (2003). *Variable dose-response relationship between exercise training
  and performance.* Medicine & Science in Sports & Exercise, 35(7), 1188–1195.
  https://doi.org/10.1249/01.MSS.0000074465.13621.37
- Hellard, P., Avalos, M., Lacoste, L., Barale, F., Chatard, J.-C., & Millet, G.
  P. (2006). *Assessing the limitations of the Banister model in monitoring
  training.* Journal of Sports Sciences, 24(5), 509–520.
  https://doi.org/10.1080/02640410500244697
- Vermeire, K. M., Ghijs, M., Bourgois, J. G., & Boone, J. (2022). *The
  fitness–fatigue model: what's in the numbers?* International Journal of Sports
  Physiology and Performance, 17(5), 810–813.
  https://doi.org/10.1123/ijspp.2021-0494
- Imbach, F., Sutton-Charani, N., Montmain, J., Candau, R., & Perrey, S. (2022).
  *The use of fitness-fatigue models for sport performance modelling: conceptual
  issues and contributions from machine-learning.* Sports Medicine - Open, 8, 29.
  https://doi.org/10.1186/s40798-022-00426-x
- Marchal, A., Benazieb, O., Weldegebriel, Y., Méline, T., & Imbach, F. (2025).
  *Statistical flaws of the fitness-fatigue sports performance prediction model.*
  Scientific Reports, 15(1), 3706. https://doi.org/10.1038/s41598-025-88153-7
- Bosquet, L., Montpetit, J., Arvisais, D., & Mujika, I. (2007). *Effects of
  tapering on performance: a meta-analysis.* Medicine & Science in Sports &
  Exercise, 39(8), 1358–1365. https://doi.org/10.1249/mss.0b013e31806010e0
- Wang, Z., Wang, Y., Gao, W., & Zhong, Y. (2023). *Effects of tapering on
  performance in endurance athletes: a systematic review and meta-analysis.* PLoS
  ONE, 18(5), e0282838. https://doi.org/10.1371/journal.pone.0282838
- Dijkhuis, T. B., Otter, R. T. A., Aiello, M., Velthuijsen, H., & Lemmink, K. A.
  P. M. (2020). *Increase in the acute:chronic workload ratio relates to injury
  risk in competitive runners.* International Journal of Sports Medicine, 41(11),
  736–743. https://doi.org/10.1055/a-1171-2331
- Allen, H., Coggan, A. R., & McGregor, S. (2019). *Training and Racing with a
  Power Meter* (3rd ed.). VeloPress. (Origin of the Performance Management Chart
  and the 42/7-day CTL/ATL operationalisation.)
- TrainingPeaks. *The science of the Performance Manager.* TrainingPeaks Learn.
  https://www.trainingpeaks.com/learn/articles/the-science-of-the-performance-manager/
- Friel, J. *Applying the numbers, part 3: Training Stress Balance.* TrainingPeaks.
  https://www.trainingpeaks.com/learn/articles/applying-the-numbers-part-3-training-stress-balance/

## Healthee implementation & honesty policy
- **Not currently computed.** Healthee runs no Banister impulse-response model: no
  CTL, ATL or TSB field, and no `computeCTL`/`computeATL`/`computeTSB` in `derive/`.
  It does derive a per-day **cardio-load** (`derive/cardio_load.py`), but does not
  run the exponentially-weighted moving averages that turn a load stream into
  fitness/fatigue/form. This note is **reference science + a future-metric
  candidate** (`applies_to_metrics: []`; `daud_metrics` provenance dropped — and this
  bullet used to add "those helpers are legacy `@daud/core`", which was false: the
  module exists in no repo. There is no implementation to port, only a documented
  method to build. #88.)
- **Future-metric candidate (feasible once one load currency is settled).**
  CTL/ATL/TSB are just EWMAs (≈42-day and ≈7-day time constants) over a daily
  training-load series — computable directly from Healthee's existing daily
  cardio-load once the corpus settles a **single load currency** (the
  legacy-TRIMP-vs-TSS `load_currency` reconciliation); without one canonical
  currency, an impulse-response chart would silently mix units.
- **Population: runners** (endurance-load bookkeeping); loosely generalises to
  other trained aerobic activity but is calibrated on endurance training.
- **Honesty rules (carry into any future UI + the coach today):**
  - This is **coarse bookkeeping**, not physiology — the time constants are
    conventions, and CTL/ATL/TSB **must never override** subjective wellness, HRV,
    sleep or the recovery signals Healthee already derives.
  - **TSB (form) is not readiness** — a "fresh" TSB does not clear a fatigued or
    ill athlete; present it as a trend/taper aid, not a green light.
