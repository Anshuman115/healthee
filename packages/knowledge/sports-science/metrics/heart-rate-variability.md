---
name: heart-rate-variability
title: Heart-Rate Variability (HRV)
category: load-recovery
aliases: [HRV, RMSSD, lnRMSSD, rMSSD, vagal tone, parasympathetic activity, autonomic balance, morning HRV, readiness]
related: [resting-heart-rate, training-load, recovery, overreaching, sleep]
metrics: [hrvBaseline, hrvCv]
units: ms (RMSSD); lnRMSSD is unitless (ln of ms); CV in %
evidence_overall: Probable
last_reviewed: 2026-06-29
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
recent baseline*, never an absolute population cut-off.

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

## How we compute it
Owned by **`@daud/core` `hrv.ts`** (`hrvBaseline`, `hrvCv`); inputs are daily morning
`HrvSample { date, rmssd (ms) }`.

- **Work in lnRMSSD.** Raw RMSSD is right-skewed, so the baseline and the change band are
  computed on `ln(rmssd)`.
- **Baseline** = rolling **7-day** mean of daily morning lnRMSSD, reported back in raw ms as the
  geometric mean, `exp(mean(lnRMSSD))`.
- **Direction / smallest-worthwhile-change band**: a reading is flagged `rising` / `falling` only
  when today's lnRMSSD sits **outside the 7-day mean ± 1 SD** of lnRMSSD; otherwise it's `flat`
  (i.e. within normal individual noise).
- **`hrvCv`** = coefficient of variation (%) of the last 7 days of raw RMSSD — a **noise gauge**.
  A rising CV (instability of the daily values) is itself informative: it can flag a runner who is
  not coping with load even when the mean has not yet dropped.
- Ground-truth caveat: RMSSD itself is measured (not estimated), but **acquisition error** dominates
  — posture, breathing, time-of-day, sensor (PPG vs ECG), and motion all move the number. The 7-day
  average and CV exist to manage that noise, not eliminate it.

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

## Key references

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
