# Fasting × tracked-metrics — research dossier (WIP, verified evidence)

**Status:** evidence dossier for the FINAL note at
`packages/knowledge/notes/intake/fasting.md` (written 2026-07-15). The note is
complete: HRV/RHR + body-composition/metabolic sections use the 3-vote-verified
claims below; sleep (Bohlman 2024 Front Nutr), performance (Abaïdia 2020 Sports
Med, PMID 31960369), and safety (Blumberg 2023 Clin Diabetes Endocrinol) were
each verified directly against their primary source before writing; temperature
and respiratory rate are honestly marked thin/absent. This dossier remains the
audit trail. Any future addition still follows verify-primary-sources.

Method: 5 search angles → 24 sources → 108 extracted claims → 25 adversarially
verified (3-vote). Result: **19 confirmed, 1 refuted, 5 unverified (errored on
session limit).** Raw journal + full output preserved (see end).

⚠ Coverage caveat: verification prioritized autonomic (HRV/RHR) + body-composition
claims. Sleep-architecture, temperature, respiratory-rate, VO₂max/Ramadan, and
safety/contraindication claims were extracted (in the raw journal) but mostly
NOT yet through the 3-vote gate — they must be verified before they enter the note.

---

## CONFIRMED (3-vote adversarial pass)

### Body weight & composition — IF is not superior to plain calorie restriction (STRONG)
- **TREAT RCT (Lowe 2020, JAMA Intern Med; n=116, 12wk):** 16:8 TRE gave no weight
  advantage over control — between-group −0.26 kg (P=.63). `PMC7522780` — vote 3-0.
- **Same RCT — lean-mass loss:** TRE lost significant lean mass; appendicular lean
  mass index between-group −0.16 kg/m² (P=.005); ~65% of weight lost was lean mass
  vs a normal 20–30%. `PMC7522780` — 3-0. *(This is the sharpest honest finding.)*
- **Same RCT — metabolic markers:** no significant improvement in fasting glucose,
  insulin, HbA1c, or lipids vs control over 12wk. `PMC7522780` — 3-0.
- **ADF vs daily CR (Trepanowski 2017, JAMA Intern Med; n=100, 12mo):** alternate-day
  fasting no better than daily calorie restriction (−6.0% vs −5.3%; diff −0.7%,
  95% CI −3.1 to 1.6). jamanetwork 2623528 — 3-0.
- **Same — body composition at 12mo:** fat-mass diff 0.0 kg (CI −2.4 to 2.4), lean
  diff 0.5 kg (CI −1.2 to 2.2) — no fat-loss or lean-sparing advantage over CR.
  jamanetwork 2623528 — 3-0.
- **TREAT-timing RCT (NEJM 2022, NEJMoa2114833; n=139, 12mo):** TRE (8am–4pm)+CR
  weight loss −8.0 kg vs CR-alone −6.3 kg, not significant (net −1.8 kg, P=0.11).
  — 3-0.
- **Same — everything else null:** body fat, lean mass, waist, BMI, BP, metabolic
  risk factors did not differ TRE+CR vs CR. — 3-0.
- **TRF magnitude (review PMC9696013):** TRF alone gives only 1–4% weight loss over
  1–12wk; clinically significant (>5%) loss needs TRF + calorie restriction. — 3-0.
- **Meta-analysis caveat (PMC12309044):** does NOT resolve lean-mass preservation or
  IF-vs-CR — lacked fat/lean breakdown and excluded direct CR comparisons. — 3-0.

### Glucose / insulin sensitivity (MODERATE)
- **TRF & insulin sensitivity (review PMC9696013):** TRF may improve insulin
  sensitivity and daytime glycemic variability in overweight/obese; early-TRF
  reduced HOMA-IR (Xie et al., n=82: −1.08 vs increases in controls). — 3-0.

### HRV — autonomic (the confounder the note must flag)
- **Acute fast raises vagal HRV (AJP-Regu 2021, ajpregu.00283.2021):** R-R rose
  992±30→1,059±37 ms; normalized HF power 55±3%→62±3% — higher parasympathetic tone
  during fasting. — 3-0.
- **Same — RHR down:** resting HR 69±2→65±2 bpm after fasting. — 3-0.
- **Same — mechanism:** muscle sympathetic nerve activity unchanged (16±11 vs 15±8
  bursts/min) → the shift is *increased vagal tone*, not reduced sympathetic outflow.
  — 2-0.
- **BUT acute 48h total fast LOWERS HRV (Chan/female subjects 2013, PMID 23403876):**
  SDNN and RMSSD both fell baseline→48h (P<0.001) — parasympathetic *withdrawal* with
  sympathetic activation. — 3-0. **← the key tension: short overnight fast ≠ prolonged
  total fast; direction of HRV depends on fast length.**
- **Same 48h study — sympathovagal shift:** reduced RMSSD + log-HF on head-up tilt =
  shift toward sympathetic dominance. — 3-0.
- **Prolonged 12-day fast RAISES vagal tone (GENESIS/Buchinger, Int J Obes 2025,
  s41366-025-01843-0 / PMC12532600):** RMSSD 27.16±10.5→32.92±17.65 ms (p=0.01)
  after vs before. — 2-1 and 2-0. ⚠ mislabeled "habitual" in extraction — it's a
  single supervised 12-day near-total fast (n=16, single-arm, no control) = WEAK
  design; reclassify as *prolonged fasting*, distinct from TRE/IF a wearable user does.
- **Same study — biphasic sympathetic:** early-fast sympathetic activation (p<0.05)
  then significant SNS decrease after (p=0.00007). — 3-0.
- **Same study — RHR acute vs habitual:** HR *down* after the fasting block
  (62.79→58.44 bpm, p<0.001) but only a slight non-significant rise *during* the fast
  (67.2→69.2, p=0.52). — 2-1. ⚠ verifier flagged instrument conflation (Polar H10 vs
  sphygmomanometer, different baselines) — must be checked before use.

## REFUTED (do NOT use)
- ✗ "IF produced clinically meaningful weight loss MD −3.73 kg vs control across 15
  RCTs (n=758)" — vote 0-3, source `PMC12309044`. The meta-analysis does not support
  this figure as stated.

## UNVERIFIED — errored on session limit, RE-RUN before use (not refuted)
1. SNS index decreased significantly over the 12-day fast (p=0.00007). — nature s41366-025-01843-0
2. Autonomic response to fasting is biphasic (early sympathetic → later parasympathetic). — nature s41366-025-01843-0
3. Acute 48h total fast lowers overnight HRV (SDNN & RMSSD, P<0.001) — vagal withdrawal. — researchgate 235604122
4. 48h fast → parasympathetic withdrawal + sympathetic activation as a stress response (wearable readiness during a long fast can reflect stress, not recovery). — researchgate 235604122
5. Systematic review of 6 RCTs (548 enrolled) — short/mid-term TRE does not typically worsen sleep. — PMC11322763

## STILL TO RESEARCH (extracted but not verified; in raw journal)
Sleep architecture (early vs late TRE — early-TRE improved actigraphy sleep efficiency;
late dinner PSG null in healthy young), temperature, respiratory rate, VO₂max /
Ramadan performance meta-analysis (Cherif/Chtourou 2020, Sports Med, PMID 31960369),
and safety/contraindications (disordered-eating risk — Clinical Diabetes & Endocrinology
2023, PMC10589984). These need the 3-vote pass before entering the note.

## Primary sources (verified quality = primary unless noted)
- PMC7522780 — Lowe 2020 TREAT RCT (JAMA Intern Med)
- jamanetwork 2623528 — Trepanowski 2017 ADF vs CR (JAMA Intern Med)
- nejm NEJMoa2114833 — Liu/Chen 2022 TRE timing RCT (NEJM)
- PMC12309044 — IF meta-analysis (caveated)
- PMC9696013 — TRF review
- PMC12532600 / nature s41366-025-01843-0 — GENESIS 12-day fast (Int J Obes 2025)
- PMID 23403876 — 48h fast HRV, female subjects 2013
- ajpregu.00283.2021 — acute fast vagal HRV (AJP-Regu 2022)
- PMC11322763 — TRE sleep systematic review
- icr-heart.com — flagged UNRELIABLE by the harness; do not cite
- researchgate 235604122 — 48h fast HRV/cortisol (verify via primary journal, not RG)
- Additional (unverified): frontiersin 1823259, PMC8131073, PMC12199060, PMC9634110,
  medrxiv 2024.10.05, springer s40279-020-01257-0 (Ramadan meta), PMC7284994,
  PMID 20100529, PMID 34198990, PMC10589984 (disordered-eating risk),
  sciencedirect S1471015322000873, PMC8295756

---
Raw run: journal + full output under the workflow transcript dir
`wf_2cb1cb7f-2a9` (resumable via the workflow script with resumeFromRunId to
re-run just the 5 unverified + synthesis after the session resets).

---

## APPENDIX — all 108 extracted claims (complete capture)

Every claim the fetch phase pulled from a source, deduped. Only 25 of these
went through the 3-vote verification gate (see the verified sections above);
the rest are **extracted but UNVERIFIED** — real source material, not yet
adversarially checked. Verify against the primary source before any enters
the knowledge note. Grouped by topical keyword for the note author.


### HRV / autonomic (21)

- **[tangential]** This study measured no autonomic or heart-rate variables, so it cannot speak to wearable-tracked HRV/RHR effects of meal timing — a relevant gap when using it as evidence for a wearable-focused note.
  - quote: "The study measured no autonomic or heart rate measures."
  - source: source in journal
- **[central]** A 48-hour total fast in healthy young women significantly reduced resting HRV (both SDNN and RMSSD) from baseline to 48h, indicating acute parasympathetic (vagal) withdrawal.
  - quote: "Significant decreases in SDNN and RMSSD from Day 1 to Day 3 (P<0.001)... acute (48 h) total fast induced parasympathetic withdrawal with simultaneous sympathetic activation"
  - source: source in journal
- **[central]** The acute 48h fast produced a shift toward sympathetic dominance (sympathovagal imbalance), evidenced by reduced RMSSD and log high-frequency power during head-up tilt testing.
  - quote: "Significant reductions in SDNN, RMSSD, and log high-frequency power (P<0.001)... simultaneous sympathetic activation"
  - source: source in journal
- **[central]** Long-term fasting (12-day Buchinger protocol, ~250 kcal/day) HABITUALLY raised parasympathetic/vagal tone: overnight RMSSD rose significantly from 27.16±10.5 to 32.92±17.65 ms (p=0.01) after the fasting period versus before.
  - quote: "RMSSD significantly increased from 27.16 ± 10.5 to 32.92 ± 17.65 ms"
  - source: source in journal
- **[central]** Sympathetic nervous system activity was biphasic across fasting: an initial sympathetic activation in the early fasting phase (p<0.05), followed by a significant decrease in the SNS index after fasting (p=0.00007).
  - quote: "Decreased after fasting" (p = 0.00007)... Early fasting phase showed initial sympathetic activation (p < 0.05)"
  - source: source in journal
- **[supporting]** The evidence is weak/preliminary: this was a single-arm (uncontrolled) interventional trial with only 16 participants (8M/8F, age 45±11, BMI 26±4), so causal claims about fasting's autonomic benefits require larger randomized studies.
  - quote: "Study authors acknowledge small sample size; larger randomized studies recommended for confirmation."
  - source: source in journal
- **[central]** An acute fast increased vagally-mediated HRV in healthy young adults: R-R intervals rose from 992±30 to 1,059±37 ms and normalized high-frequency spectral power rose from 55±3% to 62±3%, indicating higher parasympathetic (vagal) tone during fasting.
  - quote: "R-R intervals increased from 992±30 to 1,059±37 ms; normalized high-frequency spectral power rose from 55±3 to 62±3%"
  - source: source in journal
- **[central]** Acute fasting did not significantly change muscle sympathetic nerve activity (16±11 vs. 15±8 bursts/minute), so the autonomic shift during fasting was driven by increased vagal tone rather than reduced sympathetic outflow.
  - quote: "Sympathetic Activity: No significant change (16±11 vs. 15±8 bursts/minute)"
  - source: source in journal
- **[supporting]** Acute fasting improved cardiovagal baroreflex sensitivity from 20±2 to 26±5 ms/mmHg and lowered mean arterial pressure from 81±1 to 78±1 mmHg.
  - quote: "Cardiovagal baroreflex sensitivity improved from 20±2 to 26±5 ms/mmHg... Mean arterial pressure decreased from 81±1 to 78±1 mmHg when fasted"
  - source: source in journal
- **[supporting]** Evidence base: this was a randomized crossover controlled trial in 25 healthy young normotensive volunteers (20 for BP, 23 for baroreflex, 12 for muscle sympathetic nerve activity), a small single-population sample.
  - quote: "Randomized controlled trial with crossover design... 25 young normotensive volunteers (20 for blood pressure analysis, 23 for baroreflex sensitivity, 12 for muscle sympathetic nerve activity)"
  - source: source in journal
- **[central]** In a 12-day supervised fast (~250 kcal/day, Buchinger protocol), parasympathetic tone (HRV RMSSD) rose significantly from 27.16±10.5 ms before fasting to 32.92±17.65 ms after (p<0.001) in 16 adults, indicating habitual/prolonged fasting increases vagal activity.
  - quote: "Pre-fasting: 27.16±10.5 ms; Post-fasting: 32.92±17.65 ms (p<0.001)"
  - source: source in journal
- **[central]** Sympathetic nervous system activity (SNS index) decreased significantly over the 12-day fast (p=0.00007), shifting sympatho-vagal balance toward parasympathetic dominance after prolonged fasting.
  - quote: "Sympathetic Activity (SNS Index): Decreased significantly (p=0.00007)"
  - source: source in journal
- **[central]** The autonomic response to fasting is biphasic: an initial acute rise in sympathetic activation occurs in the early fasting phase (p<0.05) before parasympathetic enhancement dominates, distinguishing acute from habitual effects.
  - quote: "an initial rise in sympathetic activation during the early fasting phase (p<0.05), followed by sustained parasympathetic enhancement during food reintroduction"
  - source: source in journal
- **[central]** In an 8-week study of 60 healthy adults (ages 20-40, normal BMI), a 16:8 intermittent fasting protocol raised overnight HRV RMSSD from 35.2 +/- 7.5 ms to 44.6 +/- 6.9 ms (+9.4 ms, p<0.05) versus +0.7 ms in controls, indicating increased vagal/parasympathetic tone with habitual TRE.
  - quote: "RMSSD also improved: "from 35.2 ± 7.5 ms to 44.6 ± 6.9 ms (p < 0.05)," with a +9.4 ms mean change versus +0.7 ms in controls."
  - source: source in journal
- **[supporting]** The same 16:8 IF intervention raised SDNN from 48.5 +/- 10.2 ms to 61.3 +/- 9.8 ms (+12.8 ms, p<0.01) versus +0.9 ms in controls over 8 weeks, supporting habitual improvement in overall autonomic balance.
  - quote: "SDNN increased significantly in the IF group: "from 48.5 ± 10.2 ms to 61.3 ± 9.8 ms (p < 0.01)," representing a +12.8 ms mean change versus +0.9 ms in controls."
  - source: source in journal
- **[tangential]** In this IF cohort, systolic and diastolic blood pressure showed only modest, non-statistically-significant reductions, indicating the autonomic/HRV benefits were not matched by a clear BP effect over 8 weeks.
  - quote: ""Systolic and diastolic BP showed modest reductions...though not statistically significant.""
  - source: source in journal
- **[supporting]** IF significantly reduced diastolic blood pressure (MD -3.30 mmHg, 95% CI -5.47 to -1.13, p=0.003) but not systolic BP, an autonomic/cardiometabolic signal relevant to fasting effects.
  - quote: "Diastolic BP: Reduced significantly (MD: -3.30 mmHg, 95% CI: -5.47, -1.13, p=0.003) ... Systolic BP: Not significant"
  - source: source in journal
- **[central]** An acute 48-hour total fast significantly lowers overnight/resting HRV: both SDNN and RMSSD decreased from Day 1 to Day 3 (P<0.001), indicating vagal/parasympathetic withdrawal — directly relevant to why a wearable's overnight RMSSD may drop during a fast.
  - quote: "Significant decreases in standard deviation of normal-to-normal intervals (SDNN) and root mean square of successive differences (RMSSD) from Day 1 to Day 3 (P<0.001)."
  - source: source in journal
- **[central]** A 48-hour fast produces parasympathetic withdrawal with simultaneous sympathetic activation, interpreted as a stress response — meaning a wearable HRV/readiness signal during an extended fast can reflect the fast's stress rather than improved recovery.
  - quote: "An acute (48 h) total fast induced parasympathetic withdrawal with simultaneous sympathetic activation. These changes appear to reflect stress."
  - source: source in journal
- **[supporting]** During 48h fasting, head-up tilt testing showed a significant decrease in mean interbeat intervals (i.e., faster heart rate) alongside reduced SDNN, RMSSD and log HF power (P<0.001), linking fasting to acute RHR elevation and reduced high-frequency vagal power.
  - quote: "A 48 h of fasting also induced a significant (P<.001) decrease of mean interbeat intervals (IBIs), SDNN, RMSSD and log high-frequency (HF) power."
  - source: source in journal
- **[supporting]** Evidence base for this acute-fast HRV finding is a small single-arm interventional study of 16 healthy young females over 48h total fast — weak-to-moderate strength, small sample, female-only, and an extreme fast duration not equivalent to typical 16h TRE.
  - quote: "16 healthy young female volunteers underwent 48-hour total fasting with continuous medical oversight. Measurements were taken at baseline (Day 1), 24 hours (Day 2), and 48 hours (Day 3)."
  - source: source in journal

### Resting / heart rate (6)

- **[central]** Resting heart rate DECREASED after the fasting intervention (62.79 to 58.44 bpm, p<0.001), but during the fast itself heart rate showed only a slight, non-significant increase (67.2 to 69.2 bpm, p=0.52) — an acute-vs-habitual distinction.
  - quote: "Mean HR decreased post-fasting: 62.79 to 58.44 bpm (p < 0.001)... Slight non-significant increase during fasting: 67.2 to 69.2 bpm (p = 0.52)"
  - source: source in journal
- **[central]** An acute fast lowered resting heart rate from 69±2 to 65±2 beats/minute in healthy young normotensive volunteers.
  - quote: "Resting heart rate reduced from 69±2 to 65±2 beats/minute after fasting"
  - source: source in journal
- **[central]** Habitual 16:8 intermittent fasting lowered resting heart rate from 74.8 +/- 6.3 bpm to 68.2 +/- 5.7 bpm (-6.6 bpm, p<0.01) versus -0.7 bpm in controls over 8 weeks.
  - quote: "Decreased in IF group: "from 74.8 ± 6.3 bpm to 68.2 ± 5.7 bpm (p < 0.01)," representing a -6.6 bpm mean change versus -0.7 bpm in controls."
  - source: source in journal
- **[supporting]** Alternate-day fasting showed no significant effect on heart rate or blood pressure vs daily calorie restriction at 6 or 12 months, and no significant differences in fasting glucose, fasting insulin, or HOMA-IR insulin resistance.
  - quote: "Blood Pressure & Heart Rate: No significant differences between groups at 6 or 12 months... HOMA-IR (insulin resistance): No significant differences between groups"
  - source: source in journal
- **[tangential]** The study measured performance via the Cooper Test and Harvard step test but reported only comparative before-vs-during changes, not absolute VO2max, heart rate, respiratory rate, or temperature values.
  - quote: "Deterioration observed in performance tests (Cooper Test; Harvard step test) during fasting period"
  - source: source in journal
- **[supporting]** Peak heart rate during a step test rose during Ramadan (97.59±17.87 to 102.84±20.90 bpm, p=0.002), suggesting increased cardiovascular strain / reduced efficiency at a given workload during habitual fasting.
  - quote: "Peak heart rate increased during step test: 97.59 ± 17.87 to 102.84 ± 20.90 bpm (p = 0.002)"
  - source: source in journal

### Sleep (31)

- **[central]** In a 12-week RCT (N=197 adults with overweight/obesity), adding time-restricted eating (8-hour window) to usual care produced no significant change in sleep quality, sleep efficiency, awakenings, or Pittsburgh Sleep Quality Index scores versus control, regardless of eating-window timing.
  - quote: "incorporating TRE into a UC intervention, regardless of the timing of the eating window, was not associated with significant changes in sleep, mood, or quality of life compared with UC alone."
  - source: source in journal
- **[central]** Early TRE did not increase total sleep time versus control, with a near-zero mean difference of 0.2 hours (95% CI, -0.2 to 0.6).
  - quote: "mean difference in total sleep time, 0.2 [95% CI, –0.2 to 0.6] hours"
  - source: source in journal
- **[central]** Neither early nor late 8-hour TRE windows differentially affected sleep, mood, or quality of life outcomes over 12 weeks — early TRE started before 10 AM and late TRE started after 1 PM.
  - quote: "regardless of the timing of the eating window, was not associated with significant changes in sleep, mood, or quality of life"
  - source: source in journal
- **[central]** In a randomized crossover PSG study of 20 healthy young adults, late dinner (22:00, ~1h before bed) vs routine dinner (18:00, ~5h before bed) did NOT significantly change total sleep time, sleep efficiency, sleep latency, or whole-night sleep-stage distribution — meaning meal timing's effect on overall sleep architecture is modest in healthy young people.
  - quote: "total sleep time, sleep efficiency, sleep latency, as well as whole-night sleep stage distributions were not significantly different"
  - source: source in journal
- **[supporting]** Late dinner produced localized within-night shifts in sleep staging: higher Stage 2 in the second sleep quarter (49.0% vs 36.5%, p=0.0056) and higher REM in the third quarter (28.1% vs 21.9%, p=0.035).
  - quote: "Stage 2 sleep: significantly higher after LD in 2nd quarter (49.0% vs 36.5%, p=0.0056)... REM sleep: significantly higher after LD in 3rd quarter (28.1% vs 21.9%, p=0.035)"
  - source: source in journal
- **[supporting]** EEG spectral analysis showed late dinner increased delta (slow-wave) power by 2.54% at the start of the night while decreasing alpha and beta power, indicating deeper sleep early in the night that then reversed as the night progressed.
  - quote: "LD increased delta power by 2.54% at night's beginning... Findings suggest "deeper sleep in the beginning of the night" with LD"
  - source: source in journal
- **[central]** A systematic review of 6 RCTs (548 enrolled, 430 completers) found that short-to-mid-term TRE does not typically worsen sleep parameters, though effects were mixed and population-dependent.
  - quote: "short to mid-term TRE does not typically worsen sleep parameters"
  - source: source in journal
- **[central]** Habitual TRE effects on sleep quality/duration were inconsistent: only one study showed improved subjective sleep quality, while others found decreased sleep duration, decreased sleep efficiency (2 studies), or increased sleep onset latency.
  - quote: "Only one study reported significant improvements in subjective sleep quality"
  - source: source in journal
- **[central]** Meal-timing matters: late TRE (12pm-8pm) produced a ~2.7% decrease in objective sleep efficiency, while early TRE (7am-3pm) decreased self-reported PSQI sleep efficiency and increased sleep onset latency.
  - quote: "Late TRE (12pm-8pm): "significant decrease in mean sleep efficiency of 2.7%""
  - source: source in journal
- **[supporting]** The evidence base is limited by short study durations (8-14 weeks) and few objective assessments, so long-term TRE effects on sleep cannot be concluded; no study measured REM/deep sleep architecture and hunger's effect on sleep was not addressed.
  - quote: "studies included in this review had a relatively short duration, ranging from 8 to 14 weeks, thus the long-term effects of TRE on sleep parameters cannot be concluded from this review"
  - source: source in journal
- **[central]** In a 10-week randomized crossover trial, only early TRE (eating 8am-4pm) — not late TRE (1pm-9pm) — significantly improved actigraphy-estimated sleep quality in 31 women with overweight/obesity, increasing sleep efficiency (p=0.047), decreasing awakening length (p=0.043), and lowering the sleep fragmentation index (p=0.029) within-group.
  - quote: "Sleep efficiency increased within eTRE (p = 0.047)... Awakening length decreased within eTRE (p = 0.043)... Sleep fragmentation index declined within eTRE (p = 0.029)... Late TRE showed no significant improvements"
  - source: source in journal
- **[supporting]** The sleep benefits of early TRE appeared only on objective actigraphy measures, not subjective ones: neither early nor late TRE changed the Pittsburgh Sleep Quality Index or self-reported sleep ratings, and no between-intervention (early vs late) differences were statistically detected.
  - quote: "No changes detected with either intervention using Pittsburgh Sleep Quality Index or self-reported ratings"
  - source: source in journal
- **[supporting]** Sleep duration did not change under either early or late TRE, indicating the timing benefit was on sleep quality/efficiency rather than total sleep time.
  - quote: "no change in sleep duration was observed within both TRE interventions"
  - source: source in journal
- **[supporting]** Hunger did not differ between early and late TRE, and hunger/satiety showed no association with any sleep-quality metric, arguing against hunger being the mechanism linking meal timing to sleep.
  - quote: "We observed no differences between eTRE and lTRE in desire to eat, hunger, satiety, or perceived capacity to eat and no associations of hunger and satiety with any assessed sleep quality metric."
  - source: source in journal
- **[central]** In a 12-week RCT (secondary analysis) of 20 adults with overweight/obesity, self-selected TRE produced no significant change in objectively measured sleep duration or quality versus non-TRE, with both groups averaging ~6.3 hours (insufficient) throughout.
  - quote: "No significant changes in objectively measured sleep between groups (average ~6.3 hours both periods)"
  - source: source in journal
- **[central]** Greater restriction of the eating window was associated with longer sleep duration at end of intervention (β = −0.46, p = 0.03), suggesting tighter TRE may modestly benefit sleep length even when group-level effects are null.
  - quote: "Greater eating window restriction associated with longer sleep at end-intervention (β = −0.46, p = 0.03)"
  - source: source in journal
- **[supporting]** TRE significantly reduced late-night eating from 36±13% to 14±6% of days (p = 0.028), and 63% of TRE participants completely eliminated eating within 2 hours of bedtime, while non-TRE showed no significant change (~43%).
  - quote: "TRE group significantly reduced late-night eating from 36±13% to 14±6% (p = 0.028)"
  - source: source in journal
- **[tangential]** TRE shifted meal timing by delaying the first eating occasion 2.72±1.48 hours after wake (p<0.001) and advancing the last eating occasion 1.25±0.8 hours before bedtime (p<0.001), quantifying how a self-selected eating window changes meal timing.
  - quote: "TRE group delayed first eating occasion by 2.72±1.48 hours relative to wake (p < 0.001)"
  - source: source in journal
- **[supporting]** Self-reported sleep quality did not change over the 12-day fast despite the caloric restriction, while mental well-being improved significantly (p=0.029).
  - quote: "Improved significantly (p = 0.029)... Sleep quality remained unchanged"
  - source: source in journal
- **[supporting]** Subjective sleep quality did not change significantly across the 12-day fasting intervention (p=0.700), while body weight fell 5.7±1.3 kg and systolic blood pressure dropped 6.9±13.4 mmHg.
  - quote: "Sleep quality: unchanged (p=0.700) ... Body weight: -5.7±1.3 kg (p<0.001) ... Systolic BP: decreased 6.9±13.4 mmHg (p=0.04)"
  - source: source in journal
- **[central]** Late TRE (13:00-21:00) shifted sleep timing later than early TRE (8:00-16:00), delaying the sleep midpoint by 15 minutes, showing meal timing measurably alters the circadian/sleep phase even without metabolic benefit.
  - quote: "lTRE delayed the circadian phase in blood monocytes (24 min; 95% CI, -5 to 54 min, P = .10) and sleep midpoint (15 min; 95% CI, 7 to 22 min, P = .001) compared to eTRE."
  - source: source in journal
- **[supporting]** Athletes can compete in a fasted state with little impact on physical performance, provided sleep and nutrition are optimized to avoid accumulating fatigue.
  - quote: "Athletes appear able to participate in competition in a fasted state with little impact on physical performance."
  - source: source in journal
- **[central]** During Ramadan intermittent fasting, the circadian peak (acrophase) of skin/body temperature is further delayed, indicating a phase shift in the circadian body-temperature rhythm.
  - quote: "there was a further delay in the acrophase of skin temperature during Ramadan, indicating a shift in the circadian pattern of body temperature"
  - source: source in journal
- **[supporting]** The circadian rhythm delays seen during Ramadan are not explained by the shift in eating times alone; other factors contribute.
  - quote: "factors other than a sudden shift in eating habits contribute to delay of circadian rhythms during Ramadan"
  - source: source in journal
- **[central]** This is a very small observational study (6 healthy young men) using portable armband sensors, comparing a pre-Ramadan baseline week to weeks 1 and 2 of Ramadan — weak evidence for temperature/sleep/energy-expenditure effects of fasting.
  - quote: "Sample size: 6 healthy Muslim young adults"
  - source: source in journal
- **[central]** In 32 professional male medium-distance runners, both sleep quality (PSQI) and physical performance deteriorated during Ramadan diurnal fasting versus before.
  - quote: "Both quality of sleep and physical performance of athletes deteriorated during Ramadan."
  - source: source in journal
- **[supporting]** Better sleep quality was associated with better physical fitness/performance both before and during Ramadan fasting, linking the fasting-induced sleep decline to reduced performance.
  - quote: "People with better quality of sleep had better physical fitness/performance both before and during RDF"
  - source: source in journal
- **[supporting]** Athletes who worked in addition to training showed compounded negative effects — worse fitness and sleep quality than those who trained exclusively — indicating lifestyle/workload moderates the fasting effect.
  - quote: "Athletes working alongside training showed compounded negative effects—worse physical fitness results and reduced sleep quality compared to those training exclusively"
  - source: source in journal
- **[central]** In 32 professional male medium-distance runners, Ramadan fasting worsened overall sleep quality: global PSQI rose from 5.06±1.66 (pre-Ramadan) to 6.56±1.81 (during Ramadan), p<0.001, a moderate-strength (prospective cohort/natural-experiment) signal that habitual fasting degrades sleep.
  - quote: "Global PSQI scores increased from 5.06 ± 1.66 before to 6.56 ± 1.81 during Ramadan (p < 0.001)"
  - source: source in journal
- **[supporting]** Ramadan fasting specifically lengthened sleep latency (p<0.001), increased daytime dysfunction (p<0.05), and lowered subjective sleep quality (p<0.05) in these athletes, indicating the sleep decrement is driven by harder sleep onset and daytime impairment rather than merely total duration.
  - quote: "Sleep latency increased significantly (p < 0.001) - Daytime dysfunction intensified (p < 0.05) - Subjective sleep quality declined (p < 0.05)"
  - source: source in journal
- **[supporting]** Athletes with good sleep quality performed significantly better both before and during fasting, and working athletes (53% of sample) showed worse sleep and fitness, indicating fasting's performance/sleep harms are moderated by sleep quality and daytime load.
  - quote: "Athletes with good sleep quality demonstrated significantly better performance both before and during fasting periods"
  - source: source in journal

### Weight / body composition (17)

- **[supporting]** Populations studied were mostly adults with overweight or obesity (4 of 6 studies), plus one young-adult and one shift-worker study, mean ages 22-49; five of six studies were low risk of bias.
  - quote: "Four studies: "adults with overweight or obesity""
  - source: source in journal
- **[supporting]** The study was a single-arm interventional trial (no control group) with only 16 participants (mean age 45±11, BMI 26±4) and measured no cortisol, limiting evidence strength to weak/mechanistic and leaving the cortisol/stress-hormone question unaddressed.
  - quote: "Single-arm interventional trial (GENESIS study) with 16 participants ... No cortisol measurements were included in this study."
  - source: source in journal
- **[central]** In the TREAT RCT (n=116, 12-week), 16:8 time-restricted eating (noon-8pm window) produced no significant weight loss advantage over unstructured control eating: between-group difference −0.26 kg (P=.63).
  - quote: "Between-group difference: −0.26 kg (P=.63, not significant)"
  - source: source in journal
- **[central]** TRE caused significant loss of lean/muscle mass: in the in-person cohort lean mass fell −1.10 kg (P<.001) with an appendicular lean mass index between-group difference of −0.16 kg/m² (P=.005), with ~65% of weight lost being lean mass versus a normal 20-30%.
  - quote: "Between-group difference: −0.16 kg/m² (P=.005, significant); "approximately 65% of weight lost was lean mass" versus normal 20-30%"
  - source: source in journal
- **[supporting]** The trial was a randomized 10-week crossover of two 2-week isocaloric 8-hour TRE arms in 31 non-diabetic women with overweight/obesity (mean BMI 30.5, median age 62), with high adherence (~96-98%) — a small, narrow female older population limiting generalizability.
  - quote: "31 female participants (mean (SD) BMI of 30.5 (2.9) and median [IQR] age of 62 [53-65] years) completed the trial. Timely adherence was 96.5 % in eTRE and 97.7 % in lTRE."
  - source: source in journal
- **[central]** In a 12-month RCT of 139 adults with obesity, time-restricted eating (8 AM–4 PM window) plus calorie restriction produced weight loss (-8.0 kg) that was not significantly greater than calorie restriction alone (-6.3 kg), net difference -1.8 kg (P=0.11).
  - quote: "not significantly different in the two groups at the 12-month assessment (net difference, -1.8 kg; 95% CI, -4.0 to 0.4; P = 0.11)"
  - source: source in journal
- **[central]** Body composition changes (body fat and lean mass), waist circumference, BMI, blood pressure, and metabolic risk factors did not differ significantly between the TRE-plus-calorie-restriction group and the calorie-restriction-alone group over 12 months.
  - quote: "Results of analyses of waist circumferences, BMI, body fat, body lean mass, blood pressure, and metabolic risk factors were consistent with the results of the primary outcome."
  - source: source in journal
- **[central]** In a 12-month RCT of 100 metabolically healthy obese adults, alternate-day fasting produced no superior weight loss vs daily calorie restriction (ADF -6.0% vs DCR -5.3%; between-group difference -0.7%, 95% CI -3.1 to 1.6), indicating IF's body-weight effect is driven by calorie restriction, not fasting per se — strong evidence (RCT).
  - quote: "Alternate-day fasting did not produce superior adherence, weight loss, weight maintenance, or cardioprotection vs daily calorie restriction."
  - source: source in journal
- **[central]** Alternate-day fasting and daily calorie restriction produced statistically indistinguishable changes in body composition at 12 months — fat mass difference 0.0 kg (95% CI -2.4 to 2.4) and lean mass difference 0.5 kg (95% CI -1.2 to 2.2) — so IF confers no fat-loss or lean-mass-sparing advantage over simple calorie restriction.
  - quote: "Fat mass at 12 months: "0.0 (−2.4 to 2.4)" kg difference; Lean mass at 12 months: "0.5 (−1.2 to 2.2)" kg difference"
  - source: source in journal
- **[central]** Intermittent fasting produced clinically meaningful body weight loss in overweight/obese adults: MD -3.73 kg (95% CI -5.29 to -2.17) vs control, pooled across 15 RCTs (n=758).
  - quote: "IF significantly reduced BW (MD: -3.73 kg, 95% CI: -5.29, -2.17)"
  - source: source in journal
- **[supporting]** IF did NOT significantly improve glycemic markers (fasting plasma glucose or HbA1c) versus control in this meta-analysis, weakening claims of glucose-regulation benefit in non-diabetic overweight adults.
  - quote: "Fasting Plasma Glucose: Not significant (MD: -3.36 mg/dl, 95% CI: -9.02, 2.31, p=0.25) ... HbA1c: Not significant (MD: -0.64 mg/dl, 95% CI: -2.04, 0.77, p=0.37)"
  - source: source in journal
- **[central]** This meta-analysis does NOT resolve whether IF preserves lean mass or beats continuous calorie restriction: it lacks fat/lean-mass breakdown and excluded direct CR comparisons (only IF vs control pooled).
  - quote: "If a study included IF, CR, and CON, only the comparison between IF and CON was included"
  - source: source in journal
- **[supporting]** Intermittent fasting significantly reduces body mass (all protocols pooled SMD = -0.435, p = 0.023; Ramadan SMD = -0.638, p = 0.04) and relative fat mass (SMD = -0.848, p < 0.001).
  - quote: "Fat Mass (relative): SMD = −0.848, p < 0.001"
  - source: source in journal
- **[central]** Time-restricted feeding produces only mild weight loss (1-4% over 1-12 weeks) on its own, and clinically significant loss (>5%) requires combining TRF with caloric restriction — meaning TRE per se is not superior to simple calorie restriction for weight.
  - quote: "Mild weight loss observed: 1-4% after 1-12 weeks in most studies ... Clinically significant loss (>5%) achieved when "TRF is combined with caloric restriction""
  - source: source in journal
- **[supporting]** A 14-hour fasting window may be as effective as 16 hours for weight loss, suggesting no strict dose-response benefit to extending the fast beyond ~14h.
  - quote: "The review found "14 h of fasting may be as effective as 16 h in terms of weight loss""
  - source: source in journal
- **[central]** TRF may improve insulin sensitivity and glycemic responses/variability across the day in overweight/obese individuals, with early-TRF reducing HOMA-IR (Xie et al., 82 healthy participants: 1.08 HOMA-IR decrease vs increases in controls).
  - quote: "TRF may lead to improved insulin sensitivity and glycemic responses/variability throughout the day in individuals with overweight/obesity ... Xie et al. (82 healthy participants): Early TRF reduced HOMA-IR (1.08 decrease vs. increases in co…"
  - source: source in journal
- **[supporting]** Evidence specific to Ramadan fasting is thin: only 2 RCTs met inclusion criteria, e.g. Zouhal et al. (30 obese males) showed 3.2% body weight and 5.8% body fat loss; Lum et al. (97 T2DM) showed 0.4% HbA1c reduction.
  - quote: "Ramadan Fasting **Limited Evidence:** Only 2 RCTs met inclusion criteria - Lum et al. (97 with T2DM): 0.4% HbA1c reduction ... Zouhal et al. (30 obese males): 3.2% body weight loss, 5.8% body fat loss"
  - source: source in journal

### Glucose / metabolic (8)

- **[supporting]** At baseline, more frequent late-night eating correlated with worse metabolic markers — higher fasting glucose (r = 0.59, p = 0.006) and higher HbA1c (r = 0.46, p = 0.016).
  - quote: "At baseline, late-night eating correlated with higher fasting glucose (r = 0.59, p = 0.006) and HbA1c (r = 0.46, p = 0.016)"
  - source: source in journal
- **[central]** 16:8 TRE produced no significant improvement in metabolic markers (fasting glucose, insulin, HbA1c, total/LDL/HDL cholesterol, triglycerides) versus control over 12 weeks.
  - quote: "No significant changes between groups: Fasting glucose, insulin, HbA1c... "no significant within-group or between-group differences" in these markers"
  - source: source in journal
- **[supporting]** TRE reduced total energy expenditure (−177.9 kcal/day, P=.001) but with no significant between-group difference versus control and no change in resting metabolic rate.
  - quote: "Total Energy Expenditure: TRE: −177.9 kcal/day (P=.001)... No significant between-group difference; Resting Metabolic Rate: No significant differences"
  - source: source in journal
- **[central]** In a randomized isocaloric crossover trial, 8-hour time-restricted eating did not improve insulin sensitivity — no difference between early vs late TRE and no within-intervention change, meaning cardiometabolic benefits of TRE seen elsewhere are likely driven by calorie reduction rather than the eating-window timing itself.
  - quote: "Insulin sensitivity did not differ between eTRE and lTRE (-0.07; 95% CI, -0.77 to 0.62, P = .83) and showed no within-intervention changes (eTRE: 0.31; 95% CI, -0.14 to 0.76, P = .11; lTRE: 0.19; 95% CI, -0.22 to 0.60, P = .25)."
  - source: source in journal
- **[central]** Under nearly isocaloric conditions, neither early nor late TRE improved 24-hour glucose, lipids, inflammatory or oxidative stress markers — supporting that isocaloric TRE alone does not confer cardiometabolic benefit.
  - quote: "24-hour glucose levels, lipid, inflammatory, and oxidative stress markers showed no clinically meaningful between- and within-intervention differences."
  - source: source in journal
- **[tangential]** Alternate-day fasting raised LDL cholesterol by 11.5 mg/dL (95% CI 1.9-21.1) relative to daily calorie restriction at 12 months, an unfavorable lipid signal not present with continuous calorie restriction.
  - quote: "LDL cholesterol at 12 months: ADF increased "11.5 mg/dL (95% CI, 1.9-21.1 mg/dL)" relative to DCR"
  - source: source in journal
- **[supporting]** Evidence is limited by short interventions (mostly <=12 weeks) and high heterogeneity, so sustained metabolic and safety benefits remain unvalidated.
  - quote: "the majority of included studies featured short-term interventions (≤ 12 weeks), which may inadequately capture the full spectrum of metabolic adaptations"
  - source: source in journal
- **[supporting]** Evidence on fasting glucose was mixed across RCTs — some studies showed decreases and others increases — indicating the glucose effect of TRF is not consistent.
  - quote: "Some studies showed decreases; others showed increases"
  - source: source in journal

### Performance / VO2max / Ramadan (7)

- **[central]** A meta-analysis of 11 studies in athletes found that most physical performance parameters were unaffected by Ramadan fasting whether tested in the morning or afternoon.
  - quote: "The majority of physical performance parameters were not influenced by Ramadan fasting when tested either in the morning or in the afternoon."
  - source: source in journal
- **[central]** Aerobic performance (VO2max/aerobic capacity), strength, jump height, fatigue index, and total work were not significantly affected by Ramadan fasting.
  - quote: "Not Significantly Affected: Aerobic performance (VO2max/capacity), Strength measurements, Jump height, Fatigue index, Total work output"
  - source: source in journal
- **[supporting]** Ramadan fasting negatively affected mean and peak power during Wingate/repeated-sprint tests and morning sprint performance.
  - quote: "Negatively Affected: Mean and peak power during Wingate/repeated sprint tests; Morning sprint performance showed negative effects from fasting"
  - source: source in journal
- **[supporting]** Ramadan fasting delays the timing of peak energy expenditure across both weeks of observation (R1 and R2).
  - quote: "a delay in the peak of energy expenditure during R1 and R2"
  - source: source in journal
- **[central]** Ramadan intermittent fasting significantly REDUCES VO2max/maximal aerobic capacity (SMD = -2.20, p < 0.001), whereas time-restricted feeding (TRF) protocols significantly ENHANCE VO2max (SMD = 1.32, p = 0.001) — the two fasting modalities have opposite directional effects on aerobic capacity.
  - quote: "reduced with Ramadan intermittent fasting (Ramadan IF; SMD = −2.20, p < 0.001) ... maximum oxygen uptake is significantly enhanced with TRF protocols (SMD = 1.32, p = 0.001)"
  - source: source in journal
- **[central]** Intermittent fasting has non-significant effects on muscular strength and anaerobic capacity (e.g., vertical jump SMD = 0.012, p = 0.945), indicating strength/power is largely preserved rather than impaired by fasting.
  - quote: "Non-significant effects were observed for muscle strength and anaerobic capacity"
  - source: source in journal
- **[central]** Ramadan fasting reduced endurance performance and estimated VO2max: Cooper Test distance fell from 3585.09±332.65m to 3521.56±327.70m and VO2max from 68.86±7.44 to 67.44±7.33 ml/kg/min (both p=0.023), a small but significant decline over ~3 weeks of fasting in elite runners.
  - quote: "VO2max declined: 68.86 ± 7.44 to 67.44 ± 7.33 ml/kg/min (p = 0.023)"
  - source: source in journal

### Cortisol / stress (3)

- **[supporting]** TRE did not worsen mood measures (depression, anxiety, stress) over 12 weeks; early TRE vs control depression score difference was 0.2 points (95% CI, -1.0 to 1.3).
  - quote: "Depression score, 0.2 [95% CI, –1.0 to 1.3] points"
  - source: source in journal
- **[supporting]** Contrary to a simple cortisol-driven stress response, diurnal cortisol shifted toward LOWER values by the end of the 48h fast.
  - quote: "Diurnal cortisol profile "significantly shifted towards lower values from baseline to the end" (P=0.002)"
  - source: source in journal
- **[supporting]** The diurnal cortisol profile slope shifted significantly toward lower values by the end of the 48-hour fast (P=0.002), a nuance for the fasting-cortisol/stress-marker discussion.
  - quote: "The slope of the diurnal cortisol profile significantly shifted towards lower values from baseline to the end of experiment (P=0.002)."
  - source: source in journal

### Safety / contraindication (8)

- **[supporting]** Adding time-restricted eating to calorie restriction did not increase adverse events relative to calorie restriction alone over 12 months.
  - quote: "No substantial differences between the groups in the numbers of adverse events"
  - source: source in journal
- **[central]** Patients with an eating disorder or a history of an eating disorder/disordered eating should never be encouraged to do intermittent fasting.
  - quote: "Patients with an eating disorder or history of an eating disorder or disordered eating should never be encouraged to engage in intermittent fasting."
  - source: source in journal
- **[central]** Extreme caution is warranted before recommending IF to people carrying disordered-eating risk factors, i.e. adolescents/young adults, particularly females and gender-diverse individuals.
  - quote: "extreme caution should be taken in recommending intermittent fasting to patients that carry risk factors for disordered eating such as being an adolescent/young adult, particularly those who identify as female or gender diverse populations."
  - source: source in journal
- **[supporting]** In a cross-sectional study of 2,762 Canadian adolescents/young adults (Ganson et al., 2022), intermittent fasting use in the prior year was common — 47.7% of females, 38.4% of males, and 52.0% of transgender/gender-non-conforming individuals — with stronger IF–disordered-eating associations in women.
  - quote: "47.7% of female participants, 38.4% of male participants, and 52.0% of transgender and gender non-conforming individuals reported having used intermittent fasting"
  - source: source in journal
- **[supporting]** Clinicians should provide an explicit warning about the potential for acquiring an eating disorder whenever IF is recommended to at-risk demographics, plus routine disordered-eating screening.
  - quote: "every time intermittent fasting is recommended to an individual from this demographic, an explicit warning is to be provided on the potential deleterious outcome of acquiring an eating disorder."
  - source: source in journal
- **[central]** In this epidemiological sample, intermittent fasting engagement (past 12 months and past 30 days) was significantly associated with eating disorder psychopathology, measured via the Eating Disorder Examination Questionnaire.
  - quote: "intermittent fasting in the past 12 months and 30 days was significantly associated with eating disorder psychopathology."
  - source: source in journal
- **[central]** The association between intermittent fasting and eating disorder behaviors varied by gender, but was most consistent in women.
  - quote: "Varying patterns of association between intermittent fasting and eating disorder behaviors were found across genders, with the most consistent relationships between intermittent fasting and ED behaviors in women."
  - source: source in journal
- **[supporting]** The study used modified Poisson regression on cross-sectional data (Canadian Study of Adolescent Health Behaviors), so it establishes association rather than causation between fasting and disordered eating.
  - quote: "The researchers analyzed data from the Canadian Study of Adolescent Health Behaviors using multiple modified Poisson regression analyses to examine associations between intermittent fasting engagement... and eating disorder psychopathology"
  - source: source in journal

### Other (7)

- **[supporting]** The study was small (16 healthy young female volunteers) and used a prolonged 48-hour total fast, limiting generalizability to typical overnight/16h time-restricted eating.
  - quote: "16 healthy young female volunteers... 48 hours total, with measurements at baseline (Day 1), 24 hours (Day 2), and 48 hours (Day 3)"
  - source: source in journal
- **[supporting]** TRE modestly lowered diastolic blood pressure (−4.08 mm Hg, P=.047) but had no significant between-group effect on systolic blood pressure.
  - quote: "Diastolic TRE: −4.08 mm Hg (P=.047)"
  - source: source in journal
- **[supporting]** Early TRE produced a minor spontaneous calorie deficit while late TRE did not, illustrating that unmonitored TRE trials confound eating-window effects with calorie reduction.
  - quote: "Food records showed a minor daily calorie deficit in eTRE (-167 kcal) but not in lTRE."
  - source: source in journal
- **[supporting]** Alternate-day fasting had a higher dropout/attrition rate (38%, 13 of 34) than daily calorie restriction (29%) or control (26%), with withdrawals attributed to difficulty adhering — evidence that IF is harder to sustain long-term.
  - quote: "More participants in the alternate-day fasting group than in the daily calorie restriction group withdrew owing to difficulties adhering with the diet."
  - source: source in journal
- **[supporting]** Combining intermittent fasting with a low-carbohydrate diet produces a substantially higher likelihood of binge eating and food cravings than either intervention alone.
  - quote: "substantially higher likelihood of binge eating and having food cravings than either intervention independently."
  - source: source in journal
- **[supporting]** The evidence base is limited and heterogeneous: this systematic review with meta-analysis pooled 28 studies (1980-2019) with small samples (8-85 participants, most commonly 10-20), predominantly male participants aged 18-39, and only 7 of 28 studies reported anaerobic outcomes.
  - quote: "only seven studies (of 28) reported results for anaerobic changes"
  - source: source in journal
- **[supporting]** Intermittent fasting was common among Canadian adolescents and young adults, reported by 47.7% of women, 38.4% of men, and 52.0% of transgender/gender non-conforming participants in the past 12 months (N=2,762).
  - quote: "47.7 % of women, 38.4 % of men, and 52.0 % of transgender/gender non-conforming participants reported past-year intermittent fasting."
  - source: source in journal
