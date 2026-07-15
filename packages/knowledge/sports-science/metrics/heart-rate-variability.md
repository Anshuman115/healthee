---
id: heart_rate_variability
name: "Heart-Rate Variability (HRV)"
category: metrics
grade: Probable
evidence_grade: 2
summary: "Beat-to-beat vagal-tone signal (overnight RMSSD vs personal baseline); a noisy daily autoregulation tool, never an overreaching detector on its own — raised chronically by aerobic exercise, sleep and slow breathing, suppressed acutely by alcohol and short sleep."
aliases: ["heart-rate-variability", "HRV", "RMSSD", "lnRMSSD", "vagal tone", "parasympathetic activity", "autonomic balance", "morning HRV", "cardiac vagal tone", "hrv_improvement", "hrv_recovery_marker", "hrv_rmssd_ms", "hrv_sleep_avg_ms"]
applies_to_metrics: ["hrv_sleep_avg"]
applies_to_interventions: ["exercise", "meditation", "alcohol", "caffeine"]
population: general
last_reviewed: 2026-07-15
related: ["resting-heart-rate", "training-load", "recovery_readiness", "overreaching", "sleep_and_recovery"]
units: "ms (RMSSD); lnRMSSD is unitless (ln of ms); CV in %"
---
# Heart-Rate Variability (HRV)

## Summary
HRV is the beat-to-beat variation in time between heartbeats, and the field-validated
index for it is **RMSSD** (the root-mean-square of successive R-R interval differences),
a marker of cardiac **parasympathetic (vagal)** activity. Measured each morning and
tracked as a **7-day rolling average of lnRMSSD against the runner's own baseline**, it is
a useful — but noisy and highly individual — gauge of autonomic recovery state.
Used to *time* hard sessions (train hard when HRV is at/above baseline, ease when it
drops and stays down), HRV-guided programmes produce **small but real** fitness gains over
fixed plans. The single most important caveat: **HRV alone does not reliably detect
overreaching** — vagal markers can paradoxically *rise* in fatigued athletes — so it must
always be read alongside training load, sleep, and subjective wellness, never in isolation.

## What it is
The heart does not beat like a metronome. Even at rest the interval between consecutive
beats (the R-R interval, in ms) varies from beat to beat. **Heart-rate variability** quantifies
that variation. The most commonly reported time-domain index for athlete monitoring is:

- **RMSSD** — root mean square of successive R-R interval differences (ms). It reflects
  short-term, beat-to-beat variation driven almost entirely by the **vagus nerve**
  (parasympathetic branch), and is the index recommended for field/wearable monitoring
  because it is comparatively robust to recording length and to ectopic-beat artefacts
  [Buchheit 2014].
- **lnRMSSD** — the natural log of RMSSD. Because raw RMSSD is right-skewed and has wide
  between-person range, the log transform stabilises the variance and makes day-to-day and
  trend comparisons meaningful. Most practitioner workflows track **lnRMSSD**, not raw ms.

Other indices exist (SDNN, pNN50; frequency-domain HF/LF power; the Poincaré SD1, which is
mathematically near-equivalent to RMSSD) but RMSSD/lnRMSSD is the workhorse for daily
endurance monitoring.

**Typical ranges are wildly individual and should not be compared across people.** As a
loose orientation, morning supine RMSSD often falls in the ~20–100+ ms range; well-trained
endurance athletes tend toward the higher end, and HRV declines with age. These numbers are
context only — the coaching signal is always *the individual's reading relative to their own
recent baseline*, never an absolute population cut-off. (Standardised metric definitions and
the reference norms behind these orientation ranges are catalogued in [Shaffer & Ginsberg 2017].)

## Physiology / mechanism
The sinoatrial node's firing rate is continuously modulated by the autonomic nervous system:
the **sympathetic** branch accelerates it, the **parasympathetic (vagal)** branch slows it.
Vagal influence acts fast (beat-to-beat), so high-frequency beat-to-beat variation — captured
by RMSSD — is a good proxy for **parasympathetic activity**. A relatively rested, recovered
athlete shows strong vagal tone and therefore **higher** RMSSD; acute stressors (hard training,
poor sleep, alcohol, illness, psychological stress, dehydration) shift autonomic balance toward
sympathetic dominance and typically **lower** RMSSD.

Respiratory sinus arrhythmia is the dominant driver of short-term HRV — HR rises on inhalation
and falls on exhalation — which is why **breathing rate and depth strongly affect the
measurement** and why standardised, relaxed breathing during recording matters.

The training interpretation rests on this autonomic-balance logic: HRV at or above baseline
suggests the parasympathetic system has restored homeostasis and the athlete can absorb a hard
stimulus; a suppressed HRV suggests incomplete recovery. The important complication (see
Honesty) is that with *accumulating* fatigue the relationship is not monotonic — some athletes
show **parasympathetic hyperactivity** (elevated vagal markers) when overreached, breaking the
simple "low = tired" reading.

## The evidence

- **[Established]** RMSSD is the preferred HRV index for field/athlete monitoring, and short
  (~1–5 min) and even ultra-short recordings track standard measures acceptably — making daily
  wearable/phone measurement viable. RMSSD "has been advocated as the preferred index of HRV for
  monitoring athletic training status" [Buchheit 2014]. Smartphone photoplethysmography (PPG)
  and chest-strap HR sensors agree near-perfectly with ECG for RMSSD (R ≈ 1.00; differences
  rated "trivial") [Plews 2017].

- **[Probable]** HRV-guided training (timing hard sessions by daily HRV) yields **small but
  meaningful** advantages over predefined plans for aerobic fitness. A meta-analysis of 6 RCTs
  (195 endurance athletes) found a larger pooled effect for HRV-guided training (SMD ≈ 0.40,
  95% CI 0.27–0.53) than for predefined control training (SMD ≈ 0.22), with **amateur** athletes
  responding more than elites (ES 0.36 vs 0.17) [Granero-Gallegos 2020]. A separate methodological
  meta-analysis (8 studies, 199 athletes: 106 HRV-guided vs 93 predefined) found HRV-guidance most
  clearly benefits **vagal HRV itself** (standing RMSSD/SD1 SMD = 0.50, 95% CI 0.09–0.91, significant)
  while effects on VO₂max (SMD = 0.13, 95% CI −0.12–0.39, ns) and endurance performance (SMD = 0.20,
  95% CI −0.09–0.48, ns) were trivial-to-small and not statistically significant [Manresa-Rocamora 2021]. Net read: the method is at worst as good as a
  fixed plan and often modestly better, largely by *not* prescribing intensity on bad days.

- **[Probable]** Seminal primary trials support the approach. In recreational runners (n = 40,
  8 weeks), the HRV-guided group improved 3000 m running speed where a predefined group did not
  (a *small* between-group difference) — achieved with **fewer** moderate/high-intensity sessions,
  i.e. better-timed intensity [Vesterinen 2016]. In well-trained cyclists (n = 17, 8 weeks),
  HRV-guided prescription produced greater within-group gains (peak power, power at VT2, 40-min
  time-trial) than **traditional periodization**, which did not significantly improve [Javaloyes 2019];
  a companion trial against **block periodization** (n = 20) saw the HRV group improve VO₂max, peak
  power, power at VT1/VT2 and 40-min time-trial while the block group did not — though the
  **between-group difference was not statistically significant** [Javaloyes 2020].

- **[Established]** A **rolling multi-day average** (commonly 7-day) of lnRMSSD tracks training
  adaptation far better than single readings and is essential in elite athletes, who exhibit
  individual "HRV fingerprints"; single-day values are too noisy to act on [Plews 2013].

- **[Probable]** **Where you measure matters: morning supine on waking is the standard, and
  automated overnight (sleep) measurement is a validated, more convenient alternative — but the
  two are not interchangeable under load.** In young endurance athletes, weekly nocturnal and
  morning RMSSD showed strong correlation and no significant difference (r ≈ 0.88–0.90 at baseline),
  supporting sleep monitoring as a valid substitute [Mishica 2022]. However, in recreational runners
  put through an overload block, morning and nocturnal HRV correlated well *at baseline* but their
  **responses to intensified training diverged**: only the **nocturnal** signal changed after a
  maximal effort and only nocturnal HRV tracked the performance improvement [Nuuttila 2024]. Practical
  read: pick one protocol (morning supine *or* overnight) and keep it fixed; do not mix them, and do
  not assume a quiet morning reading reflects the autonomic cost of yesterday's hard session as
  faithfully as an overnight one.

- **[Contested → leans negative]** **HRV does not reliably detect functional overreaching on its
  own.** A systematic review and meta-analysis found resting HRV is "largely unaffected by
  overreaching" (resting RMSSD SMD only ≈ 0.26 during overreaching vs ≈ 0.58 during positive
  adaptation), and that **post-exercise HRV increases in *both* positive adaptation and
  overreaching** (SMD ≈ 0.60 and ≈ 0.64), so HRV indices "cannot independently distinguish positive
  from negative adaptations" without additional measures [Bellenger 2016]. Some overreached athletes
  show *paradoxically elevated* vagal markers (parasympathetic hyperactivity). This is the central
  reason HRV must be triangulated with load and wellness, not used as a standalone overtraining alarm.

- **[Emerging]** Between-person HRV comparison is invalid and absolute thresholds don't generalise;
  the actionable signal is intra-individual change against a personal baseline, and the smallest
  worthwhile change is itself individual. This is widely held by HRV-monitoring researchers
  [Plews 2013; Buchheit 2014] but lacks a single definitive trial quantifying it across populations.

## Raising and suppressing HRV — the modifiable levers
Overnight RMSSD is not just a passive readout; it is **modifiable on two distinct
timescales**, and keeping them separate is the whole game — chronic levers move the
*baseline* over weeks, acute exposures move a *single night*. Conflating them is the most
common misuse (don't promise a one-night fix from a chronic lever, and don't read one bad
night as a baseline change — see Honesty).

**Chronic — raises the personal baseline (weeks–months):**
- **[Established] Regular aerobic exercise / improved cardiorespiratory fitness is the single
  largest controllable lever.** A meta-analysis of RCTs in healthy adults found aerobic
  training raised vagally-mediated HRV by a *large* margin: **RMSSD SMD ≈ 0.84**, HF-power
  SMD ≈ 0.89, SDNN SMD ≈ 0.58 vs controls [Exercise-Training-HRV meta 2024, PMID 39015867].
- **[Probable] Slow-paced breathing at resonance frequency (~6 breaths/min) / HRV
  biofeedback** raises resting HRV with sustained practice — a **small-to-moderate** chronic
  effect (pooled g ≈ 0.2–0.3) — and produces a *much larger acute* RMSSD increase during the
  session itself. Best framed as a daily 10–20 min practice at ~4.5–7 breaths/min
  (individually ~6), not a one-off [Lehrer & Gevirtz 2014; Shaffer & Meehan 2020].
- **[Probable] Adequate, regular sleep supports a higher baseline;** habitual short sleep is
  associated with chronically reduced parasympathetic tone [Sleep-Deprivation-HRV meta 2025].

**Acute — suppresses a single night (same night):**
- **[Established] Evening alcohol is the single most reproducible acute suppressor, and it is
  dose-dependent.** During the first hours of sleep, RMSSD fell by **≈ 2 ms (low dose),
  ≈ 6 ms (moderate), ≈ 13 ms (high dose)**, alongside elevated heart rate; the effect is
  **larger in younger adults** (≈ −11 ms for a high dose at age 30 vs ≈ −5 ms at 60)
  [Pietilä 2018; Spaak 2010]. A common cause of an isolated low-HRV night.
- **[Established] Short or fragmented sleep** lowers RMSSD and raises LF/HF (a shift toward
  sympathetic predominance) [Sleep-Deprivation-HRV meta 2025].
- **[Probable] A hard training session the day before, late caffeine, late heavy meals, and
  acute psychological stress** all push autonomic balance toward sympathetic dominance and
  lower that night's RMSSD (stress is a well-replicated HRV suppressor [Kim 2018]).

**So the read is:** a single night *below* the personal baseline is usually an **acute**
signal — check the prior day's evening alcohol, sleep, training and stress first — while
**sustained** low HRV is what the chronic levers are for. Within-individual deviations of
**>1 SD from the personal rolling baseline correlate with acute stressors the day before**;
between-individual differences track fitness, age and cardiometabolic status, but the
within-individual signal is what consumer wearable HRV is actually good for [Shaffer &
Ginsberg 2017; Plews 2013]. To *raise* the baseline, the evidence-ranked order is: (1)
regular aerobic exercise (zone-2 / MVPA volume), (2) consistent adequate sleep (the largest
lever for a habitual short sleeper), (3) a daily slow-breathing practice, (4) reducing
evening alcohol.

## How we compute it
Healthee derives the daily metric **`hrv_sleep_avg`** — the **bounded mean of overnight
RMSSD** across the sleep window (`derive/hrv_spo2_resp.py`; exact provenance in the
implementation section). The interpretive layer that turns that number into a *signal*
follows the field-standard method:

- **Work in lnRMSSD for the baseline.** Raw RMSSD is right-skewed, so a baseline and the
  change band are best computed on `ln(rmssd)` and reported back in raw ms as the geometric
  mean, `exp(mean(lnRMSSD))`.
- **Baseline = a personal rolling average, not a population norm.** The field standard is a
  rolling **7-day** mean of lnRMSSD (a **28-day** window is a common longer reference); the
  Healthee recovery scorer uses a **robust ~6-week (42-day) personal median ± MAD-scaled SD**
  so a few odd nights cannot move the reference (see `recovery_readiness`).
- **Direction / smallest-worthwhile-change band**: flag a reading `rising` / `falling` only
  when it sits **outside the baseline ± ~1 SD** of lnRMSSD; otherwise it's `flat` (within
  normal individual noise) — the unit of action is the trend, never a single raw value.
- **Coefficient of variation (CV, %)** of the recent daily RMSSD is a useful **noise gauge**:
  a rising CV (instability of the daily values) can flag someone not coping with load even
  when the mean has not yet dropped.
- Ground-truth caveat: RMSSD itself is measured (not estimated), but **acquisition error**
  dominates — posture, breathing, time-of-day, sensor (PPG vs ECG), and motion all move the
  number. The overnight window, the rolling average and the CV exist to manage that noise, not
  eliminate it.

## How the coach uses it
Core logic: **HRV times intensity; it does not set the plan.** The plan comes from periodisation;
HRV decides whether *today* is a good day to deliver the planned hard stimulus.

- **At/above baseline (flat/rising, within or above the band)** → green light. Proceed with planned
  quality (intervals, tempo, long-run surges).
- **Below baseline but a single day (still inside or just under the band)** → treat as noise. Hold
  the plan; do not panic-rest on one low reading.
- **Sustained suppression (multiple days falling, or the 7-day mean trending down)** → ease: convert
  quality to easy/aerobic, cut volume, or insert recovery. A persistent drop with poor sleep/wellness
  is a stronger signal than HRV alone.
- **Rising CV / erratic daily values** → caution flag even if the mean looks fine; the autonomic
  system is unsettled.
- **Always cross-check**: read HRV alongside resting HR, sleep, subjective wellness/soreness, and
  recent training load. Concordant signals (low HRV + bad sleep + high recent load + heavy legs)
  warrant action; an isolated low HRV with everything else normal usually does not.
- **On a below-baseline night, name the likely *acute* cause before alarming on the number** —
  surface the prior day's evening alcohol, short/poor sleep, a hard workout, or late caffeine from
  the user's own logged/derived data, rather than treating the dip as a verdict.
- **When HRV is *chronically* low and the goal is to raise the baseline, recommend the
  evidence-ranked levers** — regular aerobic exercise first, then consistent adequate sleep, then a
  daily slow-breathing practice, then cutting evening alcohol — always paired with the user's own
  data (their baseline, their logged alcohol/sleep) and cited to this note. Frame breathing/
  biofeedback as **moderate-confidence** for chronic baseline change but reliable for acute,
  in-session vagal activation.

By **stage**:
- **Stage 1 (beginner)**: HRV is informational/educational, not directive. Daily noise and a still-
  forming baseline make it unreliable for a new runner; rely on RPE, sleep and simple consistency.
  Use HRV mainly to *teach* the recovery concept, and require ≥2–3 weeks of data before any baseline
  is trusted.
- **Stage 2 (developing)**: begin light HRV-guided autoregulation — shift or soften a quality session
  when HRV is persistently suppressed and corroborated by wellness. This is where the meta-analytic
  benefit (especially in amateurs) is strongest [Granero-Gallegos 2020].
- **Stage 3 (racing/advanced)**: full HRV-guided timing of hard blocks against a stable individual
  fingerprint and 7-day trend [Plews 2013], but **never** as a sole overtraining detector — pair with
  performance markers and load monitoring because of the overreaching paradox [Bellenger 2016].

## Honesty & uncertainty
This metric is genuinely useful **and** genuinely noisy. Be calibrated, not evangelical.

- **Day-to-day noise is large.** Morning RMSSD legitimately swings ~10–30% day to day from sleep,
  alcohol, caffeine, late meals, posture, breathing rate, hydration, illness, menstrual-cycle phase,
  and psychological stress — independent of training. **One low reading is usually noise.** This is
  why we never act on single days, only on the trend/band.
- **It is intensely individual.** "Normal" HRV and the size of a meaningful change differ enormously
  between people. **Cross-person comparison is invalid** — a runner's 55 ms could be high for them and
  low for someone else. All thresholds are personal baselines, not population numbers.
- **Measurement conditions dominate.** Posture (supine vs seated vs standing), breathing, and
  time-of-day must be standardised or the "signal" is just protocol drift. PPG and chest straps are
  acceptable vs ECG [Plews 2017], but mixing devices/positions corrupts the trend. Morning-supine and
  overnight-sleep protocols each work but are **not interchangeable** — they can respond differently to
  intensified training [Nuuttila 2024], so the runner must stay on one method.
- **The overreaching paradox is the big one.** HRV does *not* cleanly fall with accumulating fatigue.
  Some athletes show *elevated* vagal markers when functionally overreached, and post-exercise HRV
  rises in both good adaptation and overreaching — so HRV "cannot independently distinguish positive
  from negative adaptations" [Bellenger 2016]. **HRV alone cannot diagnose overtraining.**
- **The performance benefit is small and not guaranteed.** Pooled effects on VO₂max and endurance
  were trivial and non-significant in one meta-analysis [Manresa-Rocamora 2021]; the clearest,
  most reliable effect of HRV-guidance is on vagal HRV itself, with fitness gains modest and more
  evident in amateurs than elites [Granero-Gallegos 2020]. Sell it as a *timing/autoregulation* tool,
  not a magic performance unlock.
- **Chronic and acute timescales must not be conflated.** Aerobic exercise and slow breathing move
  the *baseline* over weeks; alcohol and a short night move a *single* reading. Don't promise a
  one-night fix from a chronic lever, and don't read one suppressed night as a baseline change.
- **An acute post-exercise dip is expected recovery, not harm.** Exercise *raises* HRV chronically,
  yet a hard session can lower HRV the following night; that transient suppression is the normal
  autonomic cost of the stimulus, not a warning sign.
- **The breathing-practice dose is only loosely established.** "~10–20 min/day at ~6 breaths/min" is
  a pragmatic, not precisely-calibrated, prescription; minutes/day and weeks-to-effect are not firmly
  quantified.
- **What's still unknown / debated**: the optimal averaging window and decision band; whether CV adds
  reliably beyond the mean; how to weight HRV vs subjective wellness; and reliable individual rules for
  reading parasympathetic hyperactivity. Treat advanced interpretation as Emerging.

## Safety bounds
HRV is **not** a clinical diagnostic and carries no hard performance guardrail of its own, but two
safety-adjacent rules apply:

- **Never escalate training on HRV alone, and never use HRV alone to rule out overreaching/overtraining.**
  A normal or high HRV does not clear an athlete who reports rising fatigue, sleep disruption, mood
  decline, or stalling performance [Bellenger 2016].
- **A sudden, sustained, unexplained HRV collapse — especially with elevated resting HR, illness
  symptoms, or chest symptoms — is a stop-and-assess flag, not a training cue.** Defer to medical
  guidance; do not prescribe intensity into it. (Mirrored as a wellness guardrail in `@daud/core`.)

## Bottom line

- **Act on confidently (conclusive):**
  - RMSSD/lnRMSSD is the **validated field index** of cardiac-vagal (parasympathetic) activity, and
    short/ultra-short PPG or chest-strap recordings agree near-perfectly with ECG — daily wearable
    measurement is sound [Buchheit 2014; Plews 2017].
  - **Act on the trend, not the day.** A 7-day rolling lnRMSSD against the runner's *own* baseline is
    the signal; single readings are noise, and HRV must **never** be compared between people [Plews 2013].
  - **HRV alone does not detect overreaching.** Resting HRV is largely unmoved by overreaching and
    post-exercise HRV rises in *both* good adaptation and overreaching, so HRV cannot independently tell
    them apart — always triangulate with load, sleep, performance and wellness [Bellenger 2016].
  - Standardise the protocol (posture, breathing, device, time) or the number is meaningless.

- **Hold loosely (unsettled):**
  - **HRV-guided training helps, but modestly and unevenly.** Pooled gains over fixed plans are small
    (VO₂max ES ≈ 0.40 vs 0.22), clearest in amateurs and on vagal HRV itself, and non-significant for
    VO₂max/endurance in a stricter meta-analysis — sell it as autoregulation, not a performance unlock
    [Granero-Gallegos 2020; Manresa-Rocamora 2021].
  - The **optimal averaging window, the smallest-worthwhile-change band, the value of CV beyond the
    mean, and how to weight HRV against subjective wellness** are not settled.
  - **Morning-supine vs overnight-sleep** measurement: both are valid, but they can respond
    differently under intensified load and are not interchangeable [Mishica 2022; Nuuttila 2024].

## Coach Directives

- **D1**: Compute HRV state as **lnRMSSD vs a 7-day rolling baseline**, flagging change only when
  today sits **outside mean ± 1 SD** of lnRMSSD. Never act on a single day's raw value. — confidence: Established
- **D2**: When HRV is at/above baseline (flat or rising), **green-light** the planned quality session. — confidence: Probable
- **D3**: When HRV is **persistently** suppressed (multiple days falling or the 7-day mean trending
  down) **and** corroborated by poor sleep/wellness or high recent load, **reduce intensity/volume or
  insert recovery**. — confidence: Probable
- **D4**: Treat an **isolated** low reading (everything else normal) as **noise** — hold the plan. — confidence: Probable
- **D5**: **Never** use HRV alone to detect overreaching/overtraining or to clear a fatigued athlete;
  vagal markers can rise paradoxically when overreached — always triangulate with load, performance,
  sleep and subjective wellness. — confidence: Established (safety-critical)
- **D6**: **Never** compare HRV between runners or apply absolute population thresholds; the only valid
  signal is intra-individual change vs personal baseline. — confidence: Probable
- **D7**: Require **standardised measurement** (same posture, relaxed breathing, same device, same
  time/protocol — morning-supine *or* overnight-sleep, never mixed) and **≥2–3 weeks** of data before
  trusting any baseline. — confidence: Established
- **D8**: Frame HRV to the runner as an **autoregulation/timing** tool with modest expected fitness
  benefit (clearest in non-elites), **not** a guaranteed performance booster. — confidence: Probable
- **D9**: Treat a **rising 7-day CV** (`hrvCv`) as an early instability flag warranting caution even
  when the mean has not dropped. — confidence: Emerging
- **D10**: In Stage 1, keep HRV **informational/educational only**; begin HRV-guided autoregulation
  in Stage 2 and full hard-session timing in Stage 3. — confidence: Probable
- **D11**: To raise a **chronically** low HRV baseline, prioritise the levers in evidence order —
  regular aerobic exercise > consistent adequate sleep > daily slow breathing (~6/min) > less evening
  alcohol — and frame chronic levers as week-scale, never a one-night fix. — confidence: Probable
- **D12**: When HRV drops **below baseline**, surface the most likely **acute** cause (evening
  alcohol, short/poor sleep, prior hard session, late caffeine) from the user's own data **before**
  alarming on the number. — confidence: Probable
- **D13**: **Never conflate timescales** — an acute post-exercise or post-alcohol dip is expected
  physiology/recovery, not a baseline change or a sign of harm. — confidence: Probable

## References

- Buchheit, M. (2014). *Monitoring training status with HR measures: do all roads lead to Rome?*
  Frontiers in Physiology, 5, 73. https://doi.org/10.3389/fphys.2014.00073
- Plews, D. J., Laursen, P. B., Stanley, J., Kilding, A. E., & Buchheit, M. (2013). *Training
  adaptation and heart rate variability in elite endurance athletes: opening the door to effective
  monitoring.* Sports Medicine, 43(9), 773–781. https://doi.org/10.1007/s40279-013-0071-8
- Plews, D. J., Scott, B., Altini, M., Wood, M., Kilding, A. E., & Laursen, P. B. (2017).
  *Comparison of heart-rate-variability recording with smartphone photoplethysmography, Polar H7
  chest strap, and electrocardiography.* International Journal of Sports Physiology and Performance,
  12(10), 1324–1328. https://doi.org/10.1123/ijspp.2016-0668
- Vesterinen, V., Nummela, A., Heikura, I., Laine, T., Hynynen, E., Botella, J., & Häkkinen, K.
  (2016). *Individual endurance training prescription with heart rate variability.* Medicine &
  Science in Sports & Exercise, 48(7), 1347–1354. https://doi.org/10.1249/MSS.0000000000000910
- Javaloyes, A., Sarabia, J. M., Lamberts, R. P., & Moya-Ramón, M. (2019). *Training prescription
  guided by heart-rate variability in cycling.* International Journal of Sports Physiology and
  Performance, 14(1), 23–32. https://doi.org/10.1123/ijspp.2018-0122
- Javaloyes, A., Sarabia, J. M., Lamberts, R. P., Plews, D., & Moya-Ramón, M. (2020). *Training
  prescription guided by heart rate variability vs. block periodization in well-trained cyclists.*
  Journal of Strength and Conditioning Research, 34(6), 1511–1518.
  https://doi.org/10.1519/JSC.0000000000003337
- Granero-Gallegos, A., González-Quílez, A., Plews, D., & Carrasco-Poyatos, M. (2020). *HRV-based
  training for improving VO2max in endurance athletes: a systematic review with meta-analysis.*
  International Journal of Environmental Research and Public Health, 17(21), 7999.
  https://doi.org/10.3390/ijerph17217999
- Manresa-Rocamora, A., Sarabia, J. M., Javaloyes, A., Flatt, A. A., & Moya-Ramón, M. (2021).
  *Heart rate variability-guided training for enhancing cardiac-vagal modulation, aerobic fitness,
  and endurance performance: a methodological systematic review with meta-analysis.* International
  Journal of Environmental Research and Public Health, 18(19), 10299.
  https://doi.org/10.3390/ijerph181910299
- Bellenger, C. R., Fuller, J. T., Thomson, R. L., Davison, K., Robertson, E. Y., & Buckley, J. D.
  (2016). *Monitoring athletic training status through autonomic heart rate regulation: a systematic
  review and meta-analysis.* Sports Medicine, 46(10), 1461–1486.
  https://doi.org/10.1007/s40279-016-0484-2
- Mishica, C., Kyröläinen, H., Hynynen, E., Nummela, A., Holmberg, H.-C., & Linnamo, V. (2022).
  *Evaluation of nocturnal vs. morning measures of heart rate indices in young athletes.* PLoS ONE,
  17(1), e0262333. https://doi.org/10.1371/journal.pone.0262333
- Nuuttila, O.-P., Kyröläinen, H., Kokkonen, V.-P., & Uusitalo, A. (2024). *Morning versus nocturnal
  heart rate and heart rate variability responses to intensified training in recreational runners.*
  Sports Medicine - Open, 10, 120. https://doi.org/10.1186/s40798-024-00779-5
- Shaffer, F., & Ginsberg, J. P. (2017). *An overview of heart rate variability metrics and norms.*
  Frontiers in Public Health, 5, 258. https://doi.org/10.3389/fpubh.2017.00258
- (Exercise-Training-HRV meta) (2024). *Effects of exercise training on heart rate variability in
  healthy adults: a systematic review and meta-analysis of randomized controlled trials.* PMID: 39015867.
  (RCT meta-analysis; RMSSD SMD ≈ 0.84.)
- Lehrer, P. M., & Gevirtz, R. (2014). *Heart rate variability biofeedback: how and why does it work?*
  Frontiers in Psychology, 5, 756. https://doi.org/10.3389/fpsyg.2014.00756
- Shaffer, F., & Meehan, Z. M. (2020). *A practical guide to resonance frequency assessment for heart
  rate variability biofeedback.* Frontiers in Neuroscience, 14, 570400. PMC7793964.
  https://doi.org/10.3389/fnins.2020.570400
- Pietilä, J., Helander, E., Korhonen, I., Myllymäki, T., Kujala, U. M., & Lindholm, H. (2018). *Acute
  effect of alcohol intake on cardiovascular autonomic regulation during the first hours of sleep in a
  large real-world sample of Finnish employees: observational study.* JMIR Mental Health, 5(1), e23.
  PMC5878366. https://doi.org/10.2196/mental.9519
- Spaak, J., Tomlinson, G., McGowan, C. L., et al. (2010). *Dose-related effects of red wine and alcohol
  on heart rate variability.* American Journal of Physiology - Heart and Circulatory Physiology, 298(6),
  H2226–H2231. https://doi.org/10.1152/ajpheart.00700.2009
- (Sleep-Deprivation-HRV meta) (2025). *Effects of sleep deprivation on heart rate variability: a
  systematic review and meta-analysis.* Frontiers in Neurology. PMC12394884.
- Kim, H.-G., Cheon, E.-J., Bai, D.-S., Lee, Y. H., & Koo, B.-H. (2018). *Stress and heart rate
  variability: a meta-analytic review of the literature.* Psychiatry Investigation, 15(3), 235–245.
  https://doi.org/10.30773/pi.2017.08.17

## Healthee implementation & honesty policy
- **Derived field: `hrv_sleep_avg`** (ms) in `derived_daily`. Provenance:
  `derive/hrv_spo2_resp.py::derive_night_vitals` computes the **bounded mean of overnight RMSSD**
  over the sleep window via `_window_stat` with a physiological validity range of **5–200 ms**
  (out-of-range and sentinel samples are dropped, so "no data" stays distinct from a real value; no
  row is written when the window has no valid RMSSD). Ported verbatim from the legacy v2
  `derive_night` window-stat blocks — science code, not to be "simplified" on refactor.
- **Raw source:** the per-sample metric is `hrv` (RMSSD in ms) sampled across the night; the
  legacy note names `hrv_rmssd_ms` / `hrv_sleep_avg_ms` map to the v2 derived metric
  **`hrv_sleep_avg`** (carried as aliases).
- **Downstream:** `hrv_sleep_avg` is the **highest-weighted input (0.42)** to `recovery_score`
  (`derive/recovery.py`), scored as a robust z vs the person's own ~42-day median (see
  `recovery_readiness`), and is referenced by the fasting note (fasting shifts overnight HRV in a
  direction that depends on fast length — a "better" fasted-night HRV can be meal-timing physiology,
  not recovery).
- **Honesty rules (carry into UI + LLM):**
  - **Never compare absolute ms between users** — a 35 ms night can be low for one person and high for
    another; only intra-individual change vs the personal baseline is a valid signal.
  - **Trends are reliable; exact ms values are not** (wrist/strap PPG < ECG). Compare like-for-like
    (overnight window only); never mix protocols/devices.
  - **Never present HRV as a health-status or overtraining verdict.** Always pair a below-baseline
    reading with the likely acute cause from the user's own data, and require the personal rolling
    baseline (≥2–3 weeks of data) before trusting any direction.
