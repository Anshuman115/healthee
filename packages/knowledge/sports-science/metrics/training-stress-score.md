---
id: training_stress_score
name: "Training Stress Score (TSS) and Session Load Quantification"
category: metrics
grade: Probable
summary: "One number per session combining intensity × duration (100 AU ≈ 1 h at threshold); a relative bookkeeping input, not a measured dose. Healthee computes this load as Banister TRIMP (HR-based), surfaced as `cardio_load`."
population: runners
aliases: ["training-stress-score", "tss", "rtss", "hrtss", "training stress score", "training load", "session load", "intensity factor", "IF", "normalized power", "normalized graded pace", "NGP", "grade adjusted pace", "GAP", "trimp", "session rpe", "srpe", "training impulse", "cardio_load_trimp", "cardio load", "cardio-load", "banister trimp", "edwards trimp", "summated heart-rate zone", "strain", "strain 0-21", "strain score"]
applies_to_metrics: ["cardio_load", "hr_zone_minutes"]
applies_to_interventions: ["exercise"]
last_reviewed: 2026-07-15
related: ["training-load-acwr", "fitness-fatigue-form", "grade-adjusted-pace", "lactate-threshold", "running-economy", "vo2max", "sleep-and-recovery"]
daud_metrics: ["computeSessionLoad", "rTSS", "hrTSS", "gradeAdjustedPace"]
units: "AU (arbitrary units; ~100 AU = 1 h at threshold)"
---
# Training Stress Score (TSS) and Session Load Quantification

## Summary
Training Stress Score (TSS) quantifies a single session as **one number combining
intensity and duration**, scaled so that **100 AU ≈ one hour at threshold**. It is
the per-session input the load model accumulates into fitness/fatigue trends
(CTL/ATL, ACWR). The core identity is **TSS = duration(h) × IF² × 100**, where the
**Intensity Factor (IF)** is the session's normalized intensity divided by the
runner's threshold. For runners we use **rTSS** (pace-based, off **Normalized
Graded Pace**) or **hrTSS** (heart-rate-based) rather than cycling's power-based
TSS. The single most important coaching takeaway: **TSS is a useful relative
bookkeeping metric, not a measured physiological dose.** It correlates well with
fitness change at the group level (Probable), but its accuracy collapses for
stop-start/interval sessions, drifts with a stale threshold, and is only as good
as the IF estimate — so the coach must treat it as a trend-level approximation,
cross-check it against sRPE/feel, and never let a tidy number override how the
runner actually responded.

## What it is
TSS answers one question: *how hard was this session, all in?* It collapses two
axes — **how intense** and **how long** — into a single scalar so sessions of
different shape can be compared and summed.

The anchoring convention (from Coggan's power-based original): **a TSS of ~100
represents one hour at exactly your functional threshold.** From there:

- An easy 1 h jog at IF ≈ 0.70 → 0.70² × 100 ≈ **49 TSS**.
- A hard 1 h threshold tempo at IF ≈ 0.95 → ~**90 TSS**.
- A 3 h easy long run at IF ≈ 0.65 → 3 × 0.65² × 100 ≈ **127 TSS**.

Typical magnitudes (single run): recovery jog ~20–40, steady aerobic 45–70, tempo
60–110, long run 90–180, hard race effort can exceed 200+. Weekly totals for
recreational runners commonly sit ~300–600 AU; high-volume/elite blocks run
~700–1200+.

**The family of metrics** (all share the duration × intensity² logic, differing
only in how "intensity" is measured):

| Metric | Intensity source | Threshold anchor | Best for |
|---|---|---|---|
| **TSS** (Coggan) | Normalized Power | Functional Threshold Power (FTP, watts) | Cycling (power meter) |
| **rTSS** | Normalized Graded Pace | Functional Threshold Pace (sec/km) | Running with GPS/pace |
| **hrTSS** | Time in HR zones / avg HR | Threshold HR (or HRmax) | Running without reliable pace; fallback |
| **TRIMP** (Banister) | HR-reserve × exponential weighting | HRrest→HRmax | Original HR load model |
| **sRPE** (Foster) | Session RPE (0–10) | none (RPE × minutes) | Any session; subjective gold standard |

## Physiology / mechanism
The design intent is to approximate **internal physiological cost** from
**external work**, respecting two non-linearities that a naive "average pace ×
time" misses:

1. **Intensity matters disproportionately — hence the square.** Physiological
   strain (glycogen depletion, lactate accumulation, hormonal/sympathetic load)
   rises faster than linearly with intensity. Squaring IF encodes this: doubling
   intensity roughly quadruples the per-minute stress. The square is a modelling
   choice traceable to Banister's exponential HR→lactate weighting [Banister 1991;
   Morton et al. 1990], not a law of nature, but it captures the right shape.

2. **Physiological response lags and smooths external power — hence
   "normalized."** The body does not respond instantaneously to a surge; responses
   follow a time course and are curvilinearly related to intensity [Coggan & Allen
   2010]. **Normalized Power (NP)** and its running analogue **Normalized Graded
   Pace (NGP)** apply a 30-second rolling average then a 4th-power weighting to
   reward variability: a stochastic, surging effort earns a higher normalized
   intensity than its raw average, reflecting the extra metabolic cost of the
   spikes.

**Grade adjustment (the running-specific piece).** On hills, pace badly
misrepresents effort. The metabolic cost of running varies strongly and
non-linearly with gradient, measured directly by Minetti et al. (2002) from −45%
to +45%: level running costs ~3.4 J·kg⁻¹·m⁻¹ (speed-independent), rising to ~19
J·kg⁻¹·m⁻¹ at +45% and reaching a *minimum* around −10% to −20% before rising
again on steep descents. **Grade-Adjusted Pace (GAP)** / NGP converts hilly pace
to the equivalent flat pace using this cost curve, so a runner grinding 6:00/km up
a 10% hill is correctly scored as the hard effort it is (≈1.66× flat cost at 10%),
not as an easy jog.

## The evidence

- **[Established]** Both **intensity and duration** independently contribute to
  training stress, and combining them beats either alone. This is the
  uncontroversial foundation under TSS, TRIMP and sRPE alike [Banister 1991;
  Foster et al. 2001].
- **[Established]** The **metabolic cost of running is a steep, non-linear
  function of gradient**, justifying grade adjustment. Minetti et al. (2002, n=10
  male mountain runners, treadmill −45%→+45%) measured Cr = 3.40 ± 0.24
  J·kg⁻¹·m⁻¹ on the level, 18.93 ± 1.74 at +45%, with a minimum near −10% to −20%.
  Level cost is independent of speed [Minetti et al. 2002].
- **[Probable]** **Session-level load metrics track changes in fitness at the
  group level.** In well-trained cyclists (n=15, 10-week preseason), the strongest
  dose–response relationships with gains in submaximal aerobic fitness (power at 2
  and 4 mmol·L⁻¹) came from an individualised TRIMP (iTRIMP) and from TSS, while the
  best predictors of 8-min time-trial change were iTRIMP and Lúcia's TRIMP
  [Sanders et al. 2017]. Take-home: load metrics that fold in individual physiology
  edge out generic ones, but TSS is competitive for tracking aerobic change. Effect
  direction is robust; consistency of measurement matters more than which metric.
- **[Probable]** **The different load metrics largely agree with each other.** In
  well-trained road cyclists (n=12, 8-week training block), TSS correlated very
  strongly with an individualised bioenergetic TRIMP (r ≈ 0.88) and that TRIMP with
  sRPE (r ≈ 0.90) [Moya-Ramón et al. 2018], and sRPE correlates strongly with
  HR-based TRIMP across many sports [Haddad et al. 2017]. They are mostly
  interchangeable proxies for the same underlying construct — but agreement varies
  between individuals, intensities and session types (sRPE–TRIMP agreement is
  weaker for high-intensity work than for low) [Haddad et al. 2017].
- **[Probable]** **The HR-based TRIMP variants agree with each other and with sRPE.**
  Banister's HR-reserve TRIMP and Edwards' summated-HR-zone score correlate strongly
  across cohorts (r ≈ 0.7–0.95) and both track sRPE-based internal load [Edwards 1993;
  convergent-validity studies, e.g. Vasquez-Bonilla et al. 2022, PMC9536392]. This is
  the basis for using an HR-derived TRIMP as an internal-load currency when power/pace
  are unavailable — Healthee's case (see the implementation section). Banister TRIMP is
  the better-derived of the two: Edwards' 1→5 zone weights are **arbitrary, with no
  physiological derivation**, so Edwards is best used only as a readable zone
  *breakdown*, not the headline load value [Edwards 1993].
- **[Probable]** **sRPE (RPE × minutes) is a valid, low-cost internal-load
  measure** and is often the best single predictor of adaptation/fatigue,
  capturing cognitive and environmental stress that HR and pace miss [Foster et
  al. 2001; Haddad et al. 2017]. It is the practical cross-check for any
  automatically computed TSS.
- **[Emerging]** **Running power / GOVSS-style models** (velocity, mass, grade,
  air resistance → power → stress) aim to do for running what NP does for cycling.
  Skiba's GOVSS white paper reports it quantifies stress more reproducibly than
  TRIMP in pilot data, and it underlies several commercial running-power estimates
  (Garmin, Stryd-adjacent apps). But running power is *modelled*, not measured at
  the pedal, and validation against outcomes remains thin [Skiba 2006, technical
  white paper].
- **[Contested]** **Whether internal (HR/RPE) or external (pace/power/TSS) load
  better predicts adaptation and injury.** Sanders et al. (2017) found external
  TSS competitive with internal iTRIMP for fitness change; a criterion-validity
  study against measured O₂ cost (n=10 recreational, 18 sessions) concluded that
  **external work was the most valid and reliable** quantifier, with HR-TRIMP and
  sRPE methods showing poor reliability (CV up to ~28% for sRPE) [Wallace et al.
  2014]. Yet that sample is tiny and recreational, and other work favours
  individualised internal measures. There is no settled winner; best practice is to
  track both and let the runner's response arbitrate.
- **[Contested]** **The downstream acute:chronic workload ratio (ACWR) as an
  injury-prediction tool** built on accumulated TSS. Early enthusiasm (the
  "0.8–1.3 sweet spot") has been substantially challenged on methodological
  grounds; evidence is conflicting and standardisation is poor. Use TSS-derived
  load trends descriptively, not as a validated injury predictor (see
  `training-load-acwr`).
- **[Myth]** "TSS is a measured physiological dose." It is a **model output** —
  duration × IF² × 100 — entirely dependent on a correct threshold and a valid
  intensity estimate. Equal TSS from two different sessions does not guarantee
  equal physiological cost, recovery need, or adaptive signal.
- **[Myth]** "Equal TSS = equal training effect." 100 TSS of easy long run and 100
  TSS of VO2 intervals impose very different stresses (mechanical, metabolic,
  neuromuscular) and demand different recovery. TSS deliberately discards session
  *type*; the coach must add it back.

## How we compute it

**Core formula (all variants):**

```
IF  = normalized_intensity / threshold_intensity
TSS = duration_hours × IF² × 100
```

Equivalently, the duration-explicit form used for power/pace:

```
TSS = (duration_sec × NP × IF) / (FTP × 3600) × 100
```

**Normalized Power / Normalized Graded Pace — the 4-step algorithm:**
1. Compute the **30-second rolling average** of the power (or grade-adjusted
   speed) stream.
2. Raise each rolling value to the **4th power**.
3. **Average** those 4th-power values over the whole session.
4. Take the **4th root**. → NP (or NGP, expressed as an equivalent steady pace).

The 4th-power weighting makes variable efforts score higher than their raw mean,
approximating the curvilinear stress response [Coggan & Allen 2010].

**rTSS (running, pace-based):**
- Convert raw pace to **Grade-Adjusted Pace** via the Minetti cost curve (so hills
  count by their true metabolic cost).
- Normalize (30 s rolling + 4th power) → **NGP**.
- `IF = NGP_speed / FTP_speed`, where **FTP (Functional Threshold Pace)** is the
  fastest pace sustainable for ~1 hour (≈ critical speed / lactate-threshold
  pace).
- `rTSS = duration_h × IF² × 100`.

**hrTSS (heart-rate fallback):**
- Derived from **time in HR zones** relative to threshold HR (TRIMP-like), scaled
  so 1 h at threshold HR ≈ 100. Used when pace/power are unreliable or missing.
- **Accurate for steady-state efforts, poor for hypervariable/interval sessions**
  — HR cannot rise and fall fast enough to register short surges, so hrTSS
  *under-counts* interval and sprint work [TrainingPeaks; Coggan & Allen 2010].

**The reference method:** session load is computed deterministically from the
activity stream. Preference order mirrors data quality: **power (if present) → rTSS
(GPS pace + grade) → hrTSS (HR only) → sRPE-only (duration × RPE)**. The chosen
method should be stored alongside the value so the coach knows how much to trust it.
Grade adjustment uses the Minetti (2002) polynomial cost curve. **Estimation
error vs a true physiological dose is irreducible** — see Honesty.

> ⚠️ **Provenance of the preference order, checked 2026-08-01 (#88).** This paragraph
> opened "**In `@daud/core`:**" — a module that exists **nowhere** (not this repo, not
> `~/projects/healthee-legacy`, not git history; the string came in with the upstream
> corpus import). **The ordering carries no citation and we found no primary source
> for it.** [Coggan & Allen 2010] is cited in this note for how NP/IF/hrTSS behave —
> it is *not* a citation for this ranking, and Coggan & Allen is a trade book, not a
> peer-reviewed comparison of the four methods against a criterion dose. Read the
> order as **practitioner consensus about data quality**, which is defensible on its
> face (a direct power measurement beats an inferred one) and is unvalidated as
> written.
>
> It is also **not implemented**: Healthee computes no TSS, rTSS, hrTSS or sRPE, has
> no method-selection branch and stores no "which method was used" field (verified by
> grep across `apps/`, 2026-08-01). See the implementation section — the shipped load
> currency is Banister HR-reserve TRIMP (`derive/cardio_load.py`), a single path with
> no ladder. The one place this ordering reaches anyone is the coach's prompt.

## How the coach uses it
**General stance:** treat per-session TSS as the **bookkeeping entry** that feeds
the load model (rolling chronic/acute load, ACWR), and as a *relative* comparator
within one runner over time — never as a cross-runner ranking or an exact dose.

- **Stage 1 (beginner):** Don't expose raw TSS as a target — it invites
  number-chasing. Threshold estimates are least reliable here (no recent race),
  so IF (and therefore TSS) is noisiest. Lean on **duration and sRPE/feel**;
  use TSS only internally to keep week-to-week progression gentle.
- **Stage 2 (developing):** TSS becomes useful for **managing progression** — cap
  how fast weekly accumulated load rises, balance hard (high-IF) and easy
  sessions, and ensure recovery days actually post low TSS. Re-estimate threshold
  every few weeks (or after a race/time-trial) so IF stays honest.
- **Stage 3 (racing/trained):** TSS supports **periodisation and taper** — track
  chronic load build, then taper accumulated load while holding intensity.
  Reliable here *because* the runner has a recent, accurate threshold. Still
  cross-check the model's TSS against the athlete's RPE.

**Cross-check rules:**
- **Always pair computed TSS with sRPE/feel.** If a session "felt" far harder or
  easier than its TSS, trust the divergence as signal: stale threshold, heat,
  fatigue, or a hypervariable session the algorithm mis-scored [Foster et al.
  2001].
- **Discount hrTSS for interval/fartlek sessions** — expect it to under-read;
  prefer pace/power-based rTSS for variable workouts.
- **Re-anchor on threshold drift.** If fitness has clearly changed, an out-of-date
  FTP/FTPace silently corrupts every IF and TSS. Update the anchor before trusting
  the trend.
- **Never compare TSS between runners** — it is normalised to each person's own
  threshold; 80 TSS means different absolute work for different athletes.
- **Don't equate equal TSS across session types** — weight VO2/interval and heavy
  downhill (eccentric) sessions as costing *more* recovery than their TSS implies.

## Honesty & uncertainty
- **It's a model, not a measurement.** Every TSS is `duration × IF² × 100` with a
  chosen square exponent and a chosen normalization. The square and the 4th-power
  weighting are reasonable approximations of curvilinear stress, not measured
  constants — they can be wrong for any given physiology.
- **Garbage-in on the threshold.** The single largest error source is a wrong
  threshold anchor. IF scales linearly with it and TSS with its square, so a 5%
  error in FTP/FTPace becomes ~10% in TSS. Thresholds drift with fitness, day,
  heat and fatigue; an un-updated anchor quietly biases the whole load history.
- **Hypervariable sessions break it.** Stop-start intervals, sprints and
  fartleks are exactly where 30 s smoothing and HR lag fail. hrTSS under-counts
  them badly; even rTSS struggles when GPS pace is noisy at speed changes.
- **Grade adjustment is built on a tiny, narrow sample.** The Minetti (2002) cost
  curve comes from **10 male mountain runners on a treadmill**. It generalises
  imperfectly to women, recreational runners, technical terrain, and especially
  **steep downhills**, where almost no one realises the theoretical energy saving
  and eccentric muscle damage *raises* real cost by ~3–7% — so GAP/NGP tends to
  flatter (under-score) hard descents and over-credit easy ones.
- **External ≠ internal load.** TSS counts work done, not how the body coped. The
  same rTSS on a hot, under-slept, dehydrated day is a far larger physiological
  insult than on a fresh day; pace-based load is blind to this. sRPE and HR
  partially recover the internal signal — which is why the coach cross-checks.
- **Day-to-day and device noise.** GPS pace error, HR strap dropouts/cadence-lock,
  optical-HR lag, and elevation-data error all feed straight into TSS. Treat
  small session-to-session TSS differences (<~10%) as noise.
- **Type-blindness is by design and is a real limitation.** TSS deliberately
  discards *what kind* of stress (metabolic vs mechanical vs neuromuscular). 100
  TSS of intervals, 100 of long-run pounding, and 100 of tempo demand different
  recovery and drive different adaptations.
- **What's genuinely unsettled:** whether internal or external load better
  predicts adaptation and injury [Sanders et al. 2017]; whether modelled running
  power adds accuracy over pace-based NGP [Skiba 2006]; and the validity of the
  ACWR injury-risk framework that consumes accumulated TSS (contested — see
  related doc). Individual variation in all of these is large.

## Safety bounds
TSS itself is not a hard guardrail, but it is the **input to the load-management
guardrails** that are:
- Accumulated TSS feeds the **acute:chronic workload trend**; the engine's
  progression and ACWR limits (see `training-load-acwr`) are the binding
  safety bounds, not TSS per se.
- **A wrong/stale threshold is a safety issue**, not just an accuracy one: it
  under-reports true load and can let progression limits be silently exceeded. The
  engine should flag thresholds older than a set window (e.g. >6–8 weeks without
  re-test) as low-confidence.
- **Never let a low computed TSS justify adding load** when sRPE/readiness signals
  are red — internal load overrides external bookkeeping for safety decisions.
- Weight **high-eccentric (steep downhill) and high-intensity interval** sessions
  as costing more recovery than their TSS suggests when scheduling hard days.

## Bottom line

**Act on confidently (conclusive):**
- TSS is a **bookkeeping construct**, not a measured physiological dose:
  `duration_h × IF² × 100`. It is normalised to each runner's own threshold, so it
  must never be compared between runners and must be re-anchored when fitness
  changes [Coggan & Allen 2010].
- **Both intensity and duration drive training stress**, and combining them beats
  either alone — the uncontested foundation under TSS, TRIMP and sRPE [Banister
  1991; Foster et al. 2001].
- **The metabolic cost of running is a steep, non-linear function of gradient**, so
  hilly pace must be grade-adjusted before it can be turned into a fair load number
  [Minetti et al. 2002].
- A **stale or wrong threshold is the dominant error source**: IF scales linearly
  with it and TSS with its square (≈5% threshold error → ≈10% TSS error). Keep the
  anchor current.
- **hrTSS under-counts short, hypervariable efforts** (intervals, sprints) because
  HR cannot rise and fall fast enough; prefer pace/power-based rTSS there
  [Coggan & Allen 2010].

**Hold loosely (unsettled):**
- **Which load currency is "best."** TSS, iTRIMP, luTRIMP and sRPE all track
  fitness change comparably at the group level; individualised internal metrics
  sometimes edge out TSS, sometimes external work wins — samples are small and
  populations differ (cyclists, recreational) [Sanders et al. 2017; Wallace et al.
  2014; Moya-Ramón et al. 2018]. No settled winner.
- **The exact square exponent and 4th-power normalization.** Reasonable shape
  approximations, not measured constants — they can mis-score any given physiology.
- **Modelled running power / GOVSS adding accuracy over pace-based NGP.** Plausible
  but thinly validated against outcomes [Skiba 2006].
- **Grade adjustment on steep descents.** The Minetti curve comes from 10 male
  treadmill runners and ignores eccentric muscle damage, so GAP/NGP flatters hard
  downhills [Minetti et al. 2002].
- **The downstream ACWR injury-prediction framework** that consumes accumulated TSS
  is genuinely contested — use load trends descriptively, not as a calibrated
  injury gauge (see `training-load-acwr`).

## Coach Directives
- **D1:** Compute every session's load as `duration_h × IF² × 100`, choosing the
  best available method in order **power → rTSS → hrTSS → sRPE**, and store which
  method was used. — confidence: Established (formula); **the ordering itself is
  uncited practitioner consensus, not Probable-by-evidence** — see the ⚠ box under
  "How we compute it" (#88). Neither half is implemented in Healthee.
- **D2:** Anchor IF to the runner's **current** threshold (FTP/FTPace/threshold
  HR); re-estimate after any race/time-trial and flag anchors older than ~6–8
  weeks as low-confidence. A 5% threshold error ≈ 10% TSS error. — confidence:
  Established
- **D3:** For running, grade-adjust pace via the Minetti (2002) cost curve before
  normalizing (30 s rolling + 4th-power → NGP). — confidence: Established (cost
  curve); Probable (its application to load)
- **D4:** Always cross-check computed TSS against the runner's **sRPE/feel**; when
  they diverge, trust the divergence as signal (stale threshold, heat, fatigue, or
  a mis-scored variable session) over the raw number. — confidence: Probable
- **D5:** Discount **hrTSS for interval/fartlek/sprint** sessions — it under-counts
  short surges; prefer pace/power-based rTSS for hypervariable workouts. —
  confidence: Probable
- **D6:** Never compare TSS **between runners** — it is normalised to each
  person's own threshold. — confidence: Established
- **D7:** Do **not** treat equal TSS as equal training effect or equal recovery
  cost; weight VO2/interval and steep-downhill (eccentric) sessions as more
  costly than their TSS implies. — confidence: Probable
- **D8:** Use accumulated TSS for **progression and taper** management, but defer
  to the ACWR/progression guardrails and to readiness signals for go/no-go
  decisions; never let a low computed TSS justify more load when readiness is
  red. — confidence: Probable (load model); Established (safety mirror)
- **D9:** Treat GAP/NGP on **steep descents** as optimistic — flatter than reality
  because of eccentric damage and unrealised energy savings; don't under-score
  hard downhill efforts. — confidence: Probable
- **D10:** Present TSS to runners as a **relative trend**, not a precise dose or a
  target to maximise; hide raw TSS from beginners and coach duration + feel
  instead. — confidence: Probable

## Key references
- Banister, E. W. (1991). *Modeling elite athletic performance.* In MacDougall,
  J. D., Wenger, H. A., & Green, H. J. (Eds.), *Physiological Testing of the
  High-Performance Athlete* (2nd ed., pp. 403–424). Human Kinetics. (Origin of
  TRIMP and the fitness–fatigue impulse–response model TSS is modelled on.)
- Morton, R. H., Fitz-Clarke, J. R., & Banister, E. W. (1990). *Modeling human
  performance in running.* Journal of Applied Physiology, 69(3), 1171–1177.
  https://doi.org/10.1152/jappl.1990.69.3.1171
- Edwards, S. (1993). *The Heart Rate Monitor Book.* Polar Electro Oy / Fleet Feet
  Press. (Origin of the summated-HR-zone training-load score; the 1→5 zone weights
  are a practitioner convention with no physiological derivation — Healthee uses it
  only as a readable zone breakdown, not the headline load value.)
- Vasquez-Bonilla, A. A., et al. (2022). *Training load, TRIMP and internal-load
  convergent-validity references* (representative of the HR-TRIMP validation
  literature; Banister ↔ Edwards ↔ sRPE agreement r ≈ 0.7–0.95). PMC9536392.
- Coggan, A. R., & Allen, H. (2010). *Training and Racing with a Power Meter* (2nd
  ed.). VeloPress. (Defines TSS, Normalized Power, and Intensity Factor; basis for
  rTSS/NGP and hrTSS.)
- Foster, C., Florhaug, J. A., Franklin, J., Gottschall, L., Hrovatin, L. A.,
  Parker, S., Doleshal, P., & Dodge, C. (2001). *A new approach to monitoring
  exercise training.* Journal of Strength and Conditioning Research, 15(1),
  109–115. https://doi.org/10.1519/1533-4287(2001)015<0109:ANATME>2.0.CO;2
- Minetti, A. E., Moia, C., Roi, G. S., Susta, D., & Ferretti, G. (2002). *Energy
  cost of walking and running at extreme uphill and downhill slopes.* Journal of
  Applied Physiology, 93(3), 1039–1046.
  https://doi.org/10.1152/japplphysiol.01177.2001
- Sanders, D., Abt, G., Hesselink, M. K. C., Myers, T., & Akubat, I. (2017).
  *Methods of monitoring training load and their relationships to changes in
  fitness and performance in competitive road cyclists.* International Journal of
  Sports Physiology and Performance, 12(5), 668–675.
  https://doi.org/10.1123/ijspp.2016-0454
- Haddad, M., Stylianides, G., Djaoui, L., Dellal, A., & Chamari, K. (2017).
  *Session-RPE method for training load monitoring: validity, ecological
  usefulness, and influencing factors.* Frontiers in Neuroscience, 11, 612.
  https://doi.org/10.3389/fnins.2017.00612
- Wallace, L. K., Slattery, K. M., Impellizzeri, F. M., & Coutts, A. J. (2014).
  *Establishing the criterion validity and reliability of common methods for
  quantifying training load.* Journal of Strength and Conditioning Research,
  28(8), 2330–2337. https://doi.org/10.1519/JSC.0000000000000416
  (n=10 recreational; external work was the most valid/reliable quantifier vs
  HR-TRIMP and sRPE.)
- Moya-Ramón, M., Javaloyes, A., & Sarabia, J. M. (2018). *Hayes & Quinn's TRIMP
  concurrent validity for cycling.* Journal of Science and Cycling, 7(1), 17–23.
  https://www.jsc-journal.com/index.php/JSC/article/view/394 (n=12 cyclists;
  TSS–TRIMP r≈0.88, TRIMP–sRPE r≈0.90 — the cross-metric agreement figures.)
- Skiba, P. F. (2006). *Calculation of power output and quantification of training
  stress in distance runners: the development of the GOVSS algorithm.* Technical
  white paper. https://runscribe.com/wp-content/uploads/power/GOVSS.pdf
  (Non-peer-reviewed; basis for several running-power load estimates.)

## Healthee implementation & honesty policy

**Healthee does NOT compute TSS / rTSS / NGP.** The preference order above (power →
rTSS → hrTSS → sRPE) is the general reference convention from the running-coach
corpus — uncited, and previously mis-attributed to `@daud/core`, a module that exists
in no repo (#88). Healthee has **no power meter, no FTP, and no reliable
per-second running pace** — only per-minute heart rate from an Amazfit Helio Strap.
So Healthee's single session/day load currency is **Banister HR-reserve TRIMP**,
surfaced in `derived_daily` as **`cardio_load`**. TSS is documented here for
cross-reference and shared vocabulary only; the two units are **not
interchangeable** (see `load_currency`).

**The load Healthee actually computes — Banister TRIMP (primary).** Per-minute HR is
weighted by how hard the heart was working, using Karvonen HR-reserve and a
lactate-derived exponential so high-intensity minutes count disproportionately
(matching the non-linear blood-lactate response). Verified against Banister (1991):

```
ΔHR   = (HR_ex − HR_rest) / (HR_max − HR_rest)     # Karvonen HR-reserve fraction, 0–1
y     = 0.64 · e^(1.92 · ΔHR)   (men)              # lactate weighting factor
        0.86 · e^(1.67 · ΔHR)   (women)
TRIMP = Σ_minutes ( 1 min · ΔHR · y )              # summed over all non-sleep HR minutes
```

- **Inputs we already have:** per-minute HR (`hr`); **measured** resting HR
  (`rhr_daily`, taken from the sleep window — preferred over a generic 60); HR_max
  from **Tanaka (2001): HR_max = 208 − 0.7 × age** (materially better than Fox
  `220 − age`, which overestimates in the young and underestimates in the old).
  Anchoring is **Tanaka HRmax + Karvonen HRR — identical to the sports-science
  `heart-rate-zones` note** (no conflict between the two corpora on this).
- **Science code is sacred** (Engineering Standards §1): the TRIMP function ports
  verbatim from legacy, cites this note, and carries a known-value test. The
  sex-split lactate coefficients are named constants, never "simplified."

**Edwards summated-HR-zone score (secondary — the readable zone breakdown → `hr_zone_minutes`).**
Per-minute HR is binned into five %HR_max zones; the minutes-per-zone strip is stored
as **`hr_zone_minutes`**. Edwards' weighted-sum load is shown only as a breakdown, not
the headline number, because the 1→5 weights are arbitrary (see Evidence):

| zone | %HR_max | weight |
|------|---------|--------|
| 1 | 50–60% | 1 |
| 2 | 60–70% | 2 |
| 3 | 70–80% | 3 |
| 4 | 80–90% | 4 |
| 5 | 90–100% | 5 |

`Edwards TL = Σ_z (minutes_in_zone_z · weight_z)`. (The zone *boundaries* and their
anchoring live in `heart-rate-zones`; this note owns only how the minutes are summed
into load.)

**Strain 0–21 (added on informed user request) — a single-signal rescale, NOT a composite.**
Strain is the **same** `cardio_load` rescaled onto a personal 0–21 scale:

```
Strain = 21 · (cardio_load / P95)^0.75
```

where **0 = zero load** and the user's own **rolling 90-day P95 of `cardio_load` = 21**,
with a mild concave exponent (0.75) so the scale tracks perceived exertion. It is
anchored to **P95, not the personal min/max** — so a quiet or partial day reads
genuinely low rather than a misleading 0, and a single freak day does not peg the
scale. Because it is a monotonic rescale of **one measured metric**, it stays inside
the **no-composite-score rule**: it is not a multi-marker index.

**Acute:chronic context.** Comparing today's `cardio_load` to the user's 7-/30-day
average is fine — it is a **ratio of our own measured loads** (descriptive), not a
proprietary composite. The full ACWR treatment (windows, EWMA, the discredited
injury-prediction claim, safety bounds) lives in `training-load-acwr`, which reasons
over this same `cardio_load` currency.

**Honesty rules the coach must obey.**
- **Never present load as a proprietary black-box "Strain/Recovery" number.** Label it
  plainly as *cardio load* (a published TRIMP), always alongside the user's own
  baseline ("today is above your usual") — never a cross-person absolute. HR_max is
  estimated (Tanaka SEE ≈ 10 bpm, so an individual can sit ±10–20 bpm off), which makes
  absolute TRIMP a **personal-trend** signal; **direction and day-to-day change are the
  trustworthy parts**, not the absolute value — especially for untrained users, since
  Banister's lactate weighting was derived in trained adults.
- **TRIMP captures cardiovascular load only.** It under-credits resistance training,
  isometrics, and very short maximal efforts where HR lags — pair it with device-measured
  workout calories / strength minutes, do not let it replace them.
- **Wrist/optical HR is noisier during high-intensity intervals** (motion artefact — see
  `wearable-hr-validity`): the daily aggregate load is robust, but a single hard interval
  session may be under-counted.
- **UI evidence label:** ★★ Probable for the load construct (a validated
  load-quantification method, **not** a health-outcome score with its own risk ratio);
  the HR_max basis (Tanaka 2001) is ★★★ Established.
