---
name: running-form-metrics
title: Advanced Form Metrics & Running Power
category: form
aliases:
  [
    ground contact time,
    GCT,
    vertical oscillation,
    vertical ratio,
    leg stiffness,
    vertical stiffness,
    spring-mass model,
    running power,
    Stryd,
    Garmin running power,
    COROS power,
    running dynamics,
    running economy,
    form drift,
    biomechanics,
  ]
related:
  [running-economy, cadence, running-efficiency, fatigue-and-recovery, pacing]
metrics:
  [groundContactTime, verticalOscillation, verticalRatio, legStiffness, runningPower]
units: ms, cm, %, kN/m, W (watts), AU
evidence_overall: Contested
last_reviewed: 2026-06-29
---

# Advanced Form Metrics & Running Power

## Summary

Advanced form metrics — ground-contact time (GCT), vertical oscillation (VO), vertical ratio, leg/vertical stiffness — and running power are **descriptive, device-dependent estimates**, not gold-standard measurements. At the group level, lower vertical oscillation, lower vertical ratio, higher stiffness, and good left/right symmetry correlate with better running economy, but biomechanics explains only **4–12% of the between-runner variance in economy** [Van Hooren 2024], and GCT alone has essentially **zero** correlation with economy. Running power is a **proprietary model**, not a measured watt: Stryd, Garmin, COROS, Polar and Apple produce numbers that differ by up to ~30% and are **not interchangeable**. The single most important coaching takeaway: treat these metrics as **secondary, trend-only signals on a single device**, never as targets to chase, and only reason from them when the runner's hardware actually records them.

## What it is

These are wearable-derived biomechanical metrics, mostly from a foot pod (Stryd, COROS POD) or a chest/waist accelerometer (Garmin HRM-Pro, Running Dynamics Pod):

- **Ground-contact time (GCT)** — milliseconds the foot is on the ground per step. Typical range ~200–300 ms; elites at race pace ~160–200 ms. Shorter at faster paces. Also reported as **GCT balance** (left/right %, ideally near 50/50).
- **Vertical oscillation (VO)** — the up-and-down travel of the torso/centre of mass per stride, in cm. Typical ~6–13 cm; lower tends to be more economical at a given pace.
- **Vertical ratio** — VO divided by stride length, as a percentage. This normalises bounce to how far you travel. Typical ~6–10%; elites often <7%. Lower is generally better because it means less wasted vertical movement per metre covered.
- **Leg stiffness / vertical stiffness (kleg, kvert)** — spring-mass-model parameters (kN/m, or normalised) describing how much the "leg spring" compresses under load. Vertical stiffness is force ÷ vertical centre-of-mass displacement; leg stiffness is force ÷ leg-spring compression.
- **Running power** — a single watt-like number meant to summarise the mechanical/metabolic cost of running, modelled from speed, grade, accelerations and (for foot pods) stride mechanics.

## Physiology / mechanism

Running is well approximated by a **spring-mass model**: the stance leg behaves like a spring that stores elastic energy in tendons (chiefly the Achilles and plantar fascia) during the braking phase and returns it during push-off [Struzik 2021]. A stiffer, springier system returns more "free" elastic energy and spends less time on the ground, which is why **higher vertical/leg stiffness and lower vertical oscillation track with better economy** at the group level.

Critically, runners self-optimise this. Moore et al. found that trained endurance runners spontaneously couple their mechanics to minimise energy cost: a **1% change in GCT was matched by a ~2.2% change in leg stiffness**, so that runners who spend a large proportion of the gait cycle on the ground end up with **the same metabolic cost** as those who spend a small proportion — the body subconsciously adjusts both mechanically and physiologically to land near its own optimum [Moore 2019] (n=10 trained, treadmill). This is the core reason "fixing your form" by chasing a number usually backfires: the body has already largely solved the optimisation for its own anatomy, and forcing GCT or stiffness away from preferred tends to *raise* energy cost.

**Running power** rests on the premise that mechanical power output is a fast, fatigue-independent proxy for metabolic intensity. The physiological appeal is real — at steady state, modelled power correlates strongly with VO₂ [Imbach 2020]. But the leap from "correlates with metabolic cost" to "is the cost" is exactly where the science is contested (see below): power devices estimate **external mechanical power**, not metabolic energy, and disagree on whether elastic recoil should even be counted.

## The evidence

- **[Established]** Biomechanics explains only a **small fraction** of running economy. A systematic review and meta-analysis of 51 studies (n=1,115) found running biomechanics explains just **4–12% of between-individual variance in economy** when variables are considered in isolation [Van Hooren 2024]. Form metrics are real but minor levers.
- **[Probable]** **Lower vertical oscillation** is moderately associated with better economy: r = 0.35 (95% CI 0.19–0.49), i.e. less bounce → lower oxygen cost [Van Hooren 2024]. Vertical ratio inherits this (it is VO normalised to stride length) and is arguably the cleaner single index.
- **[Probable]** **Higher vertical and leg stiffness** are moderately associated with better economy: kvert r = −0.31, kleg r = −0.28 [Van Hooren 2024]; higher vertical stiffness also differentiates elite from sub-elite runners [Struzik 2021].
- **[Contested]** **Ground-contact time has essentially no relationship with economy** in the pooled data: r = −0.02 (95% CI −0.15 to 0.12), trivial and non-significant [Van Hooren 2024]. This contradicts the popular "shorter GCT = faster" framing and some single-study reports. GCT is mostly a **consequence of pace**, not an independent target.
- **[Probable]** **GCT *balance* (symmetry) matters more than absolute GCT.** In NCAA Division I runners, a 1% increase in left/right GCT imbalance was associated with ~3.7% higher metabolic cost [Joubert 2020] (small sample, n=11). Asymmetry is a more defensible flag than a raw GCT number.
- **[Established]** **Running power is not interchangeable across brands.** There is no agreed reference standard, unlike cycling power: Garmin and Polar include elastic-recoil/rebound power and read **~30% higher** than the Stryd/COROS/Apple cluster [practitioner consensus: SportTracks 2018; DC Rainmaker 2022 — multiple independent cross-device measurements]. Switching devices creates a discontinuity in your power history. **[Probable, single study]** Within that, the device *repeatability ranking* rests on one peer-reviewed head-to-head crossover of five technologies (Stryd app, Stryd watch, RunScribe, Garmin RP, Polar V) on **n=12 trained men** across treadmill/track and varied speed, weight and slope: **Stryd was the most repeatable (CV ≤ 4.3%, ICC ≥ 0.980) and most valid against VO₂ (r ≥ 0.91)**, whereas Polar, Garmin and RunScribe showed **poor repeatability that questions their suitability** [Cerezuela-Espejo 2021]. Treat "only Stryd is reliably repeatable" as a single-study lean, not settled fact.
- **[Probable]** **Stryd power tracks metabolic intensity well at steady state.** Stryd power vs VO₂ R² = 0.82 and vs external mechanical power R² = 0.88, though it **systematically underestimates absolute power** [Imbach 2020] (n=6, recreational). On inclines (0–8%), running at a fixed Stryd power gave consistent metabolic demand, underestimating by only ~2–4% at the steepest grades [van Rassel 2026] (n=10, trained).
- **[Contested]** **Running power is mechanical, not metabolic — and the two decouple when form changes.** When runners deliberately altered stride length, GCT and arm swing at constant speed, VO₂ rose but foot-pod power did *not* track it: "power only correlates with VO₂ under steady running economy" [Baumgartner 2021] (controlled crossover). This is the crux of the validity debate — a foot pod estimates external mechanical work, so the moment economy shifts (through technique, fatigue, footwear or training adaptation) the watt number stops reflecting true metabolic cost. It is a good *steady-state* intensity proxy, not a fatigue-proof one.
- **[Probable]** **Device metric quality is uneven even within one device, and reliability ≠ validity.** On an incremental treadmill test (n=2 Stryd pods, validity vs Optojump), Stryd was **reliable** for power, cadence, GCT and leg stiffness (CV < 3.34%, ICC > 0.81) but **poorly reliable for vertical oscillation**; against the optical reference it was **valid for cadence but not for GCT** [Pinedo-Jauregi 2025]. This sits alongside an earlier study where Stryd GCT and leg stiffness *did* agree with force-plate/motion-capture references [Imbach 2020] (n=6) — so even GCT validity is **device- and protocol-dependent**, not settled. The consistent, defensible trust order is **cadence > power-as-steady-state-intensity > GCT/leg stiffness > vertical oscillation**.
- **[Probable]** **Fatigue drifts form measurably.** Across endurance-running studies, fatigue **increases GCT** (~+7%), **decreases stride length** (~−13% in the first hour), and **reduces leg/vertical stiffness** as muscles lose the ability to attenuate force [Olaya-Cuartero 2024; Struzik 2021]. In sprinting, vertical stiffness falls with fatigue and predicts performance loss [Morin 2006]. Cadence response to fatigue is **mixed** — some runners increase frequency as a protective strategy, others don't [Olaya-Cuartero 2024].
- **[Myth]** **"There is one correct GCT / vertical oscillation / power target."** Self-optimisation data show runners already sit near their individual metabolic minimum and each favours a personal stiffness/GCT trade-off [Moore 2019]. Population "good" ranges are descriptive, not prescriptive.

## How we compute it

- **Source of truth is the device.** Daud ingests GCT (ms), VO (cm), vertical ratio (%), GCT balance (%), leg stiffness, and running power (W) directly from the wearable/foot pod when present. We do **not** re-derive them from raw accelerometry.
- **Vertical ratio** = vertical oscillation ÷ stride length × 100 (%). Where a device reports VO and cadence/pace but not vertical ratio, `@daud/core` may compute it (stride length = pace ÷ cadence). Flag as estimated.
- **Running power** is taken as the device reports it and **tagged with the source device** (`stryd` | `garmin` | `coros` | `polar` | `apple` | `other`). Power from different sources is stored on **separate scales** and never pooled or compared across devices.
- **Symmetry**: GCT balance is used as |L−R| deviation from 50/50.
- **Estimation error vs ground truth**: every one of these is a model estimate, not lab force-plate/metabolic-cart truth. Expected agreement: cadence (excellent) > power-as-intensity-proxy at steady state (strong correlation, absolute bias) > GCT/leg stiffness (device-dependent) > vertical oscillation (weakest). None is "not yet computed" — all are pass-through with provenance, with vertical ratio optionally derived.

## How the coach uses it

**Default posture: these are tertiary, opt-in signals.** Pace, heart rate, RPE and load drive coaching; form metrics only refine the picture when the data exists and is from a consistent device.

- **Gate on data availability.** If the runner's device does not record a metric, the coach must **not** mention, target, or infer it. No "improve your vertical oscillation" advice to someone whose watch never measured it.
- **Trend on one device, never compare across devices.** Only interpret changes within the same hardware. If the runner switched pods/watches, reset the baseline and say so.
- **Stage 1 (beginner):** Essentially ignore form metrics except as gentle education. Do **not** set GCT/VO/power targets. The priorities are consistency, easy aerobic volume and cadence comfort. Mentioning these numbers risks anxious over-optimisation of a 4–12% lever.
- **Stage 2 (developing):** Use as **secondary economy context only**. A durable drop in vertical ratio or rise in stiffness *at the same pace* over weeks is a plausible (not proven) efficiency gain — frame as "early signal." Flag a worsening **GCT imbalance** (e.g. drifting beyond ~52/48 chronically) as a possible asymmetry/niggle cue and cross-check against pain, single-leg strength, and injury history — never diagnose from the number alone.
- **Stage 3 (racing):** Running **power may be used as a pacing/intensity governor** for the athlete who already trains with it on a single device — especially on hills and in wind, where pace lies but power is steadier [van Rassel 2026]. Anchor power zones to that runner's own lab/field test, not to generic watt charts. Always cross-check with HR and RPE; if they disagree, trust the body.
- **Fatigue / form-drift read.** Within a long run or race, rising GCT, falling stride length and falling stiffness are an expected **fatigue signature**, not a technique flaw [Olaya-Cuartero 2024]. Use the magnitude/onset as a durability cue (late-run drift = pacing or fitness gap), not as a "fix your form" prompt. Step length, GCT and vertical stiffness drift are among the stronger predictors of late-race slowdown.
- **Never prescribe a target number.** Coach toward *symmetry and trend*, and toward indirect drivers (cadence comfort, strength, easy volume), because runners already self-optimise [Moore 2019].

## Honesty & uncertainty

- **Small effect size.** Biomechanics explains only 4–12% of economy variance [Van Hooren 2024]. Chasing form numbers is low-yield versus aerobic volume, body composition, and footwear.
- **Correlation ≠ modifiable cause.** Lower VO and higher stiffness *associate* with economy across people; that does **not** prove that deliberately lowering one runner's VO improves their economy. Causal/intervention evidence is weak, and forcing a change can worsen economy.
- **Device dependence is severe.** Running "power" has **no standard**: Garmin/Polar count elastic recoil, Stryd/COROS/Apple largely don't, producing ~30% spreads [practitioner consensus], and only Stryd has demonstrated repeatability tight enough for training [Cerezuela-Espejo 2021]. Two runners (or one runner on two devices) cannot compare watts. This is the single biggest reason to keep power device-locked and trend-only.
- **Power is mechanical, not metabolic.** Because the watt number tracks external mechanical work, it decouples from oxygen cost whenever running economy shifts [Baumgartner 2021] — so power does *not* "normalise effort" across fatigue, terrain footwear, or technique change the way its marketing implies. Its honest use is a steady-state pacing proxy on one device, not a metabolic gold standard.
- **Within-device validity is patchy.** Even on a respected pod, vertical oscillation is unreliable and GCT may not match an optical reference [Pinedo-Jauregi 2025], while small validation samples (n=6–11) [Imbach 2020; Joubert 2020] limit confidence.
- **Day-to-day noise.** Shoes (especially carbon-plated/high-stack), surface, grade, wind, fatigue, pod placement and even shoe lacing shift these numbers. A single session's metric is noisy; only multi-week trends at matched pace are meaningful.
- **GCT is largely an output of pace.** Its near-zero correlation with economy [Van Hooren 2024] means absolute GCT is a poor coaching target; symmetry is the more defensible signal, and even that rests on small samples.
- **Population skew.** Much of the supporting data is male, treadmill, and recreational-to-college level; transfer to women, masters, and elite outdoor running is assumed, not established.
- **Unknown optimal stiffness.** A per-individual optimal leg-spring stiffness is theorised but not quantifiable in the field [Struzik 2021]; we cannot tell a runner their "right" value.

## Safety bounds

- **No metric here is safety-critical on its own** — none can trigger a stop or hard load cap by itself.
- **One soft guardrail:** a **chronic, worsening GCT imbalance** combined with reported pain or a known injury should be surfaced as a "see how this leg feels / consider load review" prompt — never as a diagnosis. The asymmetry number is a flag, not a finding.
- **Never let device "power" override physiological guardrails.** HR ceilings, RPE, heat, and load limits take precedence; running power is an intensity *convenience*, not a safety signal.

## Bottom line

- **Act on confidently (conclusive):**
  - Biomechanics is a **minor** lever on economy (4–12% of between-runner variance); aerobic volume, strength and footwear matter far more [Van Hooren 2024]. Don't let form numbers dominate coaching.
  - Form metrics are **device-dependent estimates**, not lab truth; interpret only as within-device trends at matched pace, and reset the baseline on any hardware change.
  - **Running power is not interchangeable across brands** and is not metabolic power: Garmin/Polar read ~30% higher than the Stryd/COROS/Apple cluster, and the watt decouples from VO₂ when running economy shifts [Cerezuela-Espejo 2021; Baumgartner 2021]. Keep power device-locked and steady-state. (That Stryd is the *most repeatable* device is plausible but rests on a single n=12 study — hold it loosely, below.)
  - **Absolute GCT is a poor target** — it correlates ~0 with economy and is mostly a by-product of pace [Van Hooren 2024].
  - **Don't prescribe target form numbers**; runners self-optimise near their own metabolic minimum [Moore 2019].
- **Hold loosely (unsettled):**
  - That lower vertical oscillation / vertical ratio and higher stiffness *cause* better economy in a given individual — the associations are real but only moderate (r ≈ 0.3) and **observational, not causal** [Van Hooren 2024].
  - That **GCT-balance asymmetry** flags injury/economy risk — based on a single small sample (n=11) [Joubert 2020]; treat as a soft cue, not a finding.
  - The exact magnitude and per-runner meaning of **fatigue-driven form drift** (GCT ↑, stride ↓, stiffness ↓) — direction is consistent, but thresholds and cadence response vary by individual [Olaya-Cuartero 2024].
  - That **Stryd specifically is the most repeatable/valid** power device — directionally supported but resting on a single n=12 head-to-head crossover [Cerezuela-Espejo 2021] plus a 2-pod reliability study [Pinedo-Jauregi 2025]; the *non-interchangeability* of brands is solid, the device-ranking is not yet replicated.
  - Whether **Stryd Critical Power** zones are a better intensity anchor than pace/HR for any given runner — promising but built on small validation samples and proprietary models.

## Coach Directives

- **D1:** Treat GCT, vertical oscillation, vertical ratio, leg/vertical stiffness and running power as **secondary, trend-only** signals; never let them override pace, HR, RPE, or load. — confidence: Established
- **D2:** Only reference or reason from a form metric if the runner's device actually records it; otherwise stay silent on it. — confidence: Established
- **D3:** Interpret these metrics **only as within-device trends over weeks at matched pace**; on a device change, reset the baseline and tell the runner. — confidence: Established
- **D4:** **Never pool or compare running power across brands** (Garmin/Polar read ~30% higher than Stryd/COROS/Apple); store power with its source device and keep scales separate. — confidence: Established
- **D5:** Do **not** prescribe target numbers for GCT, VO, vertical ratio, or power; runners self-optimise near their own metabolic minimum. — confidence: Probable
- **D6:** Prioritise metric trust as **cadence > power-as-steady-state-intensity > GCT/leg stiffness > vertical oscillation**; downweight vertical oscillation as device-noisy. — confidence: Probable
- **D7:** When discussing economy, weight form metrics lightly — biomechanics explains only ~4–12% of economy; favour aerobic volume, strength, and footwear first. — confidence: Established
- **D8:** Use **GCT balance (symmetry)** rather than absolute GCT as the form flag; surface a chronic worsening imbalance (beyond ~52/48) plus pain as a load/niggle review cue, never a diagnosis. — confidence: Probable
- **D9:** Read within-run rises in GCT and falls in stride length/stiffness as a **normal fatigue signature**, used as a durability/pacing cue — not a technique fault to correct mid-run. — confidence: Probable
- **D10:** Permit **running power as a pacing governor only for Stage 3 athletes** who already train with it on one device, with zones from their own test, and always cross-checked against HR/RPE. — confidence: Probable
- **D11:** If a device's running power disagrees with HR/RPE, **trust the physiological signals**, not the watts. — confidence: Probable
- **D12:** Do **not** treat running power as a fatigue- or terrain-proof "normalised effort"; it is mechanical, not metabolic, and decouples from oxygen cost when running economy shifts. Use it as a steady-state pacing proxy only. — confidence: Probable

## Key references

- Van Hooren, B., Jukic, I., Cox, M., Frenken, K. G., Bautista, I., & Moore, I. S. (2024). *The relationship between running biomechanics and running economy: a systematic review and meta-analysis of observational studies*. Sports Medicine, 54(5), 1269–1316. https://doi.org/10.1007/s40279-024-01997-3
- Moore, I. S., Ashford, K. J., Cross, C., Hope, J., Jones, H. S. R., & McCarthy-Ryan, M. (2019). *Humans optimize ground contact time and leg stiffness to minimize the metabolic cost of running*. Frontiers in Sports and Active Living, 1, 53. https://doi.org/10.3389/fspor.2019.00053
- Struzik, A., Karamanidis, K., Lorimer, A., Keogh, J. W. L., & Gajewski, J. (2021). *Application of leg, vertical, and joint stiffness in running performance: a literature overview*. Applied Bionics and Biomechanics, 2021, 9914278. https://doi.org/10.1155/2021/9914278
- Joubert, D. P., Guerra, N. A., Jones, E. J., Knowles, E. G., & Piper, A. D. (2020). *Ground contact time imbalances strongly related to impaired running economy*. International Journal of Exercise Science, 13(4), 427–437. https://pubmed.ncbi.nlm.nih.gov/32509121/
- Imbach, F., Candau, R., Chailan, R., & Perrey, S. (2020). *Validity of the Stryd power meter in measuring running parameters at submaximal speeds*. Sports (Basel), 8(7), 103. https://doi.org/10.3390/sports8070103
- Cerezuela-Espejo, V., Hernández-Belmonte, A., Courel-Ibáñez, J., Conesa-Ros, E., Mora-Rodríguez, R., & Pallarés, J. G. (2021). *Are we ready to measure running power? Repeatability and concurrent validity of five commercial technologies*. European Journal of Sport Science, 21(3), 341–350. https://doi.org/10.1080/17461391.2020.1748117
- Baumgartner, T., Held, S., Klatt, S., & Donath, L. (2021). *Limitations of foot-worn sensors for assessing running power*. Sensors (Basel), 21(15), 4952. https://doi.org/10.3390/s21154952
- van Rassel, C. R., Gow, S., Watanabe, T., Jaén-Carrillo, D., & MacInnis, M. J. (2026). *Validity of Stryd running power for estimating metabolic demand during incline treadmill running*. International Journal of Sports Physiology and Performance, 21(4), 597–603. https://doi.org/10.1123/ijspp.2025-0382
- Pinedo-Jauregi, A., & Ozaeta-Beaskoetxea, E. (2025). *Reliability and validity of Stryd for measuring running kinematics during an incremental treadmill test*. Journal of Strength and Conditioning Research, 39(11), e1295–e1304. https://doi.org/10.1519/JSC.0000000000005207
- Olaya-Cuartero, J., Lopez-Arbues, B., Jimenez-Olmedo, J. M., & Villalon-Gasch, L. (2024). *Influence of fatigue on the modification of biomechanical parameters in endurance running: a systematic review*. International Journal of Exercise Science, 17(1), 1377–1391. https://doi.org/10.70252/LLLT3293
- Morin, J. B., Jeannin, T., Chevallier, B., & Belli, A. (2006). *Spring-mass model characteristics during sprint running: correlation with performance and fatigue-induced changes*. International Journal of Sports Medicine, 27(2), 158–165. https://pubmed.ncbi.nlm.nih.gov/16475063/
- Garmin. *Vertical ratio* (Running Science / Running Dynamics). https://www.garmin.com/en-US/garmin-technology/running-science/running-dynamics/vertical-ratio/ — manufacturer definition of vertical ratio and typical ranges.
- DC Rainmaker (2022). *Apple Watch running power data comparison (vs Garmin/Stryd/Polar/COROS)*. https://www.dcrainmaker.com/2022/06/running-comparison-garmin.html — practitioner cross-device comparison (non–peer-reviewed); ~30% inter-brand power spread.
- SportTracks (2018). *Running power options: the differences between Stryd, Garmin, Coros, RunScribe, and Polar*. https://www.sporttracks.mobi/blog/how-to-choose-a-running-power-meter — practitioner consensus on non-interchangeability of running power.
