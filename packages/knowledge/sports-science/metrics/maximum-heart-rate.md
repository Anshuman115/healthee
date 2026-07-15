---
id: maximum_heart_rate
name: "Maximum Heart Rate (HRmax)"
category: metrics
grade: Established
evidence_grade: 3
summary: "The stable, age-declining, non-trainable HR ceiling that anchors every %HRmax zone — use Tanaka, not 220−age, and override with any observed peak."
aliases: ["maximum-heart-rate", "HRmax", "max heart rate", "maximal heart rate", "max hr", "220 minus age", "220-age", "tanaka formula", "fox formula", "gellish formula", "nes formula", "hunt formula", "peak heart rate", "age-predicted max heart rate", "apmhr", "mhr"]
applies_to_metrics: ["max_hr_daily"]
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
related: ["heart-rate-zones", "resting-heart-rate", "heart-rate-variability", "lactate-threshold", "vo2max", "individualization"]
units: "bpm"
---
# Maximum Heart Rate (HRmax)

## Summary
HRmax is the highest heart rate an individual can attain during all-out exercise — a stable, largely genetic ceiling that declines slowly with age and is **not** trainable. It anchors every %HRmax training zone, so getting it wrong miscalibrates the whole intensity model. The critical coaching fact: age-prediction formulas (220−age, Tanaka, Gellish, Nes) estimate the *population mean* well but have a standard error of roughly **±10–12 bpm per individual** — meaning a formula can be 20+ bpm wrong for a given runner. Treat any formula as a provisional placeholder only, and **override it the moment a higher real heart rate is observed** in a hard effort or, ideally, a maximal test. The observed peak almost always beats the formula.

## What it is
HRmax is the maximum number of heartbeats per minute achievable during maximal dynamic exercise to volitional exhaustion. It is:

- **Largely fixed for an individual** at a given age — an intrinsic ceiling, not a fitness marker.
- **Declining with age** at roughly 0.6–0.7 bpm/year on average.
- **Independent of fitness**: an elite marathoner and a sedentary person of the same age often share nearly the same HRmax, even though their resting HR, VO₂max, and lactate threshold differ enormously. Training does *not* raise HRmax (it can fall slightly in highly trained athletes due to increased stroke volume and a larger heart).
- **Mode-specific**: running HRmax is typically a few bpm higher than cycling, and higher still than swimming, because more muscle mass and upright posture are engaged.

Typical ranges are wide. At age 30 the population mean is roughly 185–190 bpm, but the healthy spread spans ~165–210 bpm. At age 50, mean ~170–175 bpm with a similarly wide band. **Two same-age, same-sex, equally fit runners can legitimately differ by 20–25 bpm** — this is the single most important thing to understand about HRmax.

## Physiology / mechanism
HRmax is set by the intrinsic depolarisation rate of the sinoatrial (SA) node combined with the limits of sympathetic drive and the kinetics of cardiac repolarisation. At maximal effort, parasympathetic (vagal) tone is fully withdrawn and sympathetic stimulation is maximal; the rate ceiling is then imposed by how fast cardiac myocytes can repolarise and refill (diastolic filling time) before stroke volume collapses.

The age-related decline is driven principally by **intrinsic remodelling of the SA node and conduction system** — reduced numbers and responsiveness of pacemaker cells, fibrosis, and a downregulation of the β-adrenergic response and the "funny" current (I_f, HCN4 channels) — not by reduced fitness or activity. This is why the decline is so consistent across populations and why it tracks age more tightly than almost any other physiological variable (Tanaka reported r = −0.90 between age and HRmax).

Because HRmax reflects pacemaker hardware rather than aerobic conditioning, it is **not a target to train up**. Aerobic fitness expands cardiac *output* at max (mainly via stroke volume), not the heart-rate ceiling itself. The corollary that matters for coaching: a runner whose HRmax is genuinely high or low is not "fitter" or "less fit" — they simply have a different gauge, and their zones must be set to *their* gauge.

## The evidence

- **[Established]** HRmax is predicted by age, but only at the population level, with a large individual error band. *Meta-analysis* of 351 studies (492 groups, 18,712 subjects) plus a prospective lab validation of 514 healthy adults found **HRmax = 208 − 0.7 × age**, with HRmax strongly related to age (r = −0.90) and *independent of sex and habitual physical-activity status* [Tanaka 2001]. This is the best-evidenced age equation. Crucially, the same body of work documents an individual scatter (SD) of roughly **±10 bpm around the regression line** — the formula nails the mean, not the person.

- **[Established]** Age-prediction formulas have a per-individual standard error of estimate of ~10–13 bpm — large enough to mis-set zones. In the **HERITAGE Family Study** (n = 762 sedentary adults, directly measured maximal tests), measured HRmax averaged 184.4 bpm with an SD of **14.2 bpm** at a mean age of ~34; the SEE of prediction was **12.4 bpm for 220−age and 11.4 bpm for Tanaka**, and both formulas performed *worse* in Black participants and those with higher BMI or lower fitness [Sarzynski 2013]. An independent comparison of nine equations (n = 99, verified maximal GXT, RER > 1.10) found RMSEs clustered around **10.7–11.7 bpm** for the best formulas (Tanaka 10.74, Gellish 10.71, Fox 11.65) and concluded individuals "should use data from GXTs to determine HRmax when applicable" rather than rely on age formulas [Shookster 2020]. Findings are **highly consistent**: every validation study converges on a ~±10–12 bpm individual error.

- **[Myth / Refuted]** "220 − age" (the Fox equation) has no rigorous derivation and is the least defensible formula in common use. It originated as an informal eyeballed line of best fit across ~10 heterogeneous datasets in a 1971 review [Fox 1971]; the original authors themselves noted "no single line will adequately represent the data." A widely cited historical analysis traced its origin and concluded it was never validated, systematically overestimates HRmax in the young and **underestimates it in older adults** (potentially >20 bpm), and "should be retired" as a research tool [Robergs & Landwehr 2002]. It survives because it is easy mental arithmetic, not because it is accurate. *The Myth grade applies specifically to the belief that 220−age is reliable for individuals; its population-mean output is merely mediocre, not catastrophic.*

- **[Probable]** Tanaka, Gellish and Nes are modest improvements over 220−age, mainly for older adults, but the gains are small relative to the residual individual error. **Gellish 2007** (longitudinal study, n = 908, ~25,000 observations across a broad age/fitness range) produced **HRmax = 207 − 0.7 × age** and noted a curvilinear form (191.5 − 0.007 × age²) fit slightly better [Gellish 2007]. **Nes 2013** (HUNT Fitness Study, n = 3,320 healthy adults aged 19–89, directly measured maximal tests) produced **HRmax = 211 − 0.64 × age** with an SEE of **10.8 bpm**, and found 220−age underestimated measured HRmax in subjects older than 30 [Nes 2013]. These newer equations reduce *mean bias* in older and well-characterised cohorts but do **not** meaningfully shrink the ±10–12 bpm individual SEE — no age-only formula does.

- **[Established]** A directly measured maximal exercise test is the gold standard. A graded exercise test (GXT) to volitional exhaustion with a verified maximal effort (plateau in HR/VO₂, RER typically ≥ 1.10–1.15, RPE ~19–20, post-test blood lactate ≥ 8 mmol/L) yields the individual's true ceiling and removes formula error entirely [Shookster 2020; exercise-physiology consensus]. This is the reference that all the validation studies above measure formulas *against*.

- **[Probable]** Formula accuracy is population- and mode-dependent, so a generic formula misfits specific runner groups. In **180 recreational marathon runners** (mean age 43; 148 men, 32 women), Tanaka closely matched measured HRmax in men while Fox underestimated it by ~3 bpm; in women both formulas *overestimated* by ~5 bpm [Nikolaidis 2018]. The practical reading: even the "best" formula carries a systematic group bias on top of the individual noise, reinforcing that observed data should always supersede it.

- **[Established]** HRmax does not increase with training and is not a fitness metric. Across the cohorts above, HRmax was independent of activity status and VO₂max [Tanaka 2001; Nes 2013]. Endurance training improves stroke volume, cardiac output, and lactate dynamics — not the HR ceiling. A flat or slightly falling HRmax over a training block is normal and **must not** be read as lost fitness.

## How we compute it
Owned by `estimateHrMax` in `@daud/core`. Priority order (highest-confidence source wins):

1. **Lab/field-measured maximal test** — direct GXT or a validated maximal field test (e.g. a hilly 2 km all-out finish, or repeated near-maximal intervals). Highest confidence; zero formula error. Stored as `hrMaxObserved` with a `measured` flag.
2. **Observed peak from real efforts** — the highest reliable HR seen in races, hard interval sessions, or hill repeats over a rolling window (e.g. last 6–12 months), after filtering sensor artefacts (see Safety / Honesty). The coach continuously ratchets the working HRmax *up* toward any new credible peak. Optical wrist-PPG peaks are treated with caution; chest-strap ECG peaks are trusted.
3. **Age formula (fallback only)** — used only until real maximal data exists. Default: **Tanaka, 208 − 0.7 × age** (best meta-analytic support, sex-independent). For runners > ~40, **Nes (211 − 0.64 × age)** is an acceptable alternative that reduces under-prediction in older adults. **Do not use 220 − age** except as a rough sanity check.

Every estimate carries an `hrMaxConfidence` and an explicit error band: formula-derived values are flagged ±10–12 bpm; measured values are flagged ±2–3 bpm (sensor/day noise).

```
estimateHrMax(age):           208 - 0.7 * age        // Tanaka default, ±~11 bpm SEE
estimateHrMaxOlder(age):      211 - 0.64 * age       // Nes, for age > ~40
// Always prefer max(observedReliablePeak, formulaEstimate) once a credible peak exists.
```

## How the coach uses it
HRmax is the denominator for %HRmax zones and (with resting HR) for heart-rate-reserve / Karvonen zones — so its error propagates directly into every zone boundary. Decision logic:

- **Stage 1 (beginner):** Start from the Tanaka formula. Communicate the uncertainty plainly ("this is an estimate; we'll refine it from your runs"). Lean on RPE and the talk test as primary intensity guides, because a ±10 bpm HRmax error can shift a "Zone 2" ceiling enough to push an easy run too hard. Never instruct a beginner to chase HRmax.
- **Stage 2 (developing):** Actively refine. Whenever a hard session or race shows a credible HR above the current working HRmax, ratchet it up and recompute zones. Watch for the pattern where a runner repeatedly "exceeds" their formula HRmax — that is a signal the formula under-rated them, not that they are overtraining.
- **Stage 3 (racing):** Prefer a measured HRmax (field or lab) and, better still, anchor zones to lactate/ventilatory threshold or critical speed rather than %HRmax, since threshold-anchored zones are individually accurate where %HRmax is not. Use HRmax mainly as a ceiling / sanity bound.

Cross-checks the coach must apply:
- **Heat, dehydration, stimulants, illness, and altitude** alter the HR–effort relationship; never "discover" a new HRmax from a single hot or caffeinated session without corroboration.
- **Effort and pace outrank HR** when they disagree (e.g. HR drifting up in heat at constant pace is cardiac drift, not a new max).
- If observed peaks regularly sit *below* a formula HRmax even in genuinely hard efforts, lower the working estimate — the formula may have over-rated this runner (common in some older or beta-blocker–medicated individuals).

## Honesty & uncertainty
- **The headline limitation: ±10–12 bpm individual error.** Every formula predicts the crowd, not the person. For a substantial fraction of people the error exceeds 10 bpm, and for a meaningful minority it exceeds 20 bpm [Sarzynski 2013; Shookster 2020]. Any coaching built purely on a formula HRmax is built on sand for those individuals.
- **Which formula "wins" is largely noise.** Head-to-head, Tanaka, Gellish and Fox have nearly identical RMSE (~10.7–11.7 bpm) in mixed-age adults [Shookster 2020]; differences emerge mainly at the age extremes and in specific populations. We default to Tanaka for its meta-analytic pedigree and sex-independence, not because it is decisively more accurate per individual.
- **Sex, ethnicity, body composition, and medication shift accuracy.** Formulas performed worse in Black participants and higher-BMI / lower-fitness individuals [Sarzynski 2013], and over-predicted in female recreational runners [Nikolaidis 2018]. β-blockers and other rate-limiting drugs lower true HRmax substantially and invalidate every age formula — a flagged confounder.
- **Observed-peak estimation has its own failure modes.** Optical wrist sensors produce HR *spikes* (motion artefact, cadence lock) that can fake a high HRmax; chest straps can drop out and read low. The coach must filter physiologically implausible jumps and prefer sustained peaks over single-second spikes.
- **A maximal test is unpleasant and not always safe or appropriate** (deconditioned, symptomatic, or older runners). The pragmatic path for most recreational runners is opportunistic refinement from real hard sessions, not a formal max test.
- **What the science does *not* settle:** no validated age-only equation achieves individual precision; multivariate models (adding fitness, body composition, mode) are an *emerging* research direction but not yet robust enough to recommend. The honest position is that age formulas are a starting placeholder, full stop.

## Safety bounds
- **Never prescribe efforts targeting a specific HRmax to beginners, deconditioned, symptomatic, or cardiac-risk runners.** Maximal exertion is the highest-risk moment in endurance training; HRmax discovery must be opportunistic and athlete-led, not coach-mandated, for these groups.
- **Reject implausible HR readings before updating HRmax.** Hard bounds: ignore any single reading implying HRmax above ~220 bpm in adults, or any abrupt jump > ~15–20 bpm/second (sensor artefact). These bounds are mirrored as guardrails in `@daud/core`.
- **β-blocker / rate-limiting medication flag:** if present, disable formula-based HRmax and zone prescription and fall back to RPE / talk test; surface this to the user.
- **Symptom override:** chest pain, syncope, or disproportionate breathlessness at submaximal HR overrides any HR target — stop and advise medical review. Not a metric decision.

## Bottom line

**Act on confidently (conclusive):**
- HRmax is a largely genetic, age-declining ceiling that is **not improved by training** and is **not a fitness metric** [Tanaka 2001; Nes 2013]. *(Established)*
- Age formulas carry a **±10–12 bpm individual error** and can be 20+ bpm wrong for some people; they are population estimates, not personal truths [Sarzynski 2013; Shookster 2020]. *(Established)*
- A verified maximal exercise test is the gold standard and removes formula error [Shookster 2020]. *(Established)*
- "220 − age" has no rigorous derivation and notably under-predicts HRmax in older adults; prefer Tanaka (208 − 0.7 × age) or, for older runners, Nes (211 − 0.64 × age) as the fallback [Robergs & Landwehr 2002; Nes 2013]. *(Established / Myth-correcting)*
- The observed peak from a genuine hard effort should override a formula estimate [all validation studies]. *(Established)*

**Hold loosely (unsettled):**
- *Which* age formula is "best" for a given individual — the RMSE differences are mostly noise, and group biases (sex, ethnicity, mode) are real but imperfectly characterised. *(Probable / Contested)*
- Multivariate HRmax models adding fitness / body-composition / mode — promising but not yet robust enough to deploy. *(Emerging)*
- The reliability of optical-wrist-derived peaks for ratcheting HRmax — treat with caution pending chest-strap corroboration. *(Emerging)*

## Coach Directives

- **D1:** Default the HRmax estimate to Tanaka, `208 − 0.7 × age`; for runners older than ~40, Nes `211 − 0.64 × age` is an acceptable alternative. — confidence: **Established**
- **D2:** Never use `220 − age` except as a coarse sanity check; flag it as inaccurate if a user cites it. — confidence: **Established**
- **D3:** Attach a ±10–12 bpm uncertainty band to every formula-derived HRmax and communicate it to the user; never present a formula HRmax as exact. — confidence: **Established**
- **D4:** Treat any credible observed peak HR (chest-strap preferred) above the current working HRmax as the new HRmax; continuously ratchet the estimate upward from real hard efforts and races. — confidence: **Established**
- **D5:** Prefer a measured maximal test or threshold-anchored zones over %HRmax zones for Stage-3 / racing athletes. — confidence: **Probable**
- **D6:** Do not interpret a flat or slightly declining HRmax over a training block as lost fitness — HRmax is not trainable. — confidence: **Established**
- **D7:** For beginners and deconditioned / symptomatic runners, never prescribe targeting a specific HRmax; guide intensity by RPE / talk test and discover HRmax opportunistically. — confidence: **Established (safety)**
- **D8:** Reject HR readings implying adult HRmax > ~220 bpm or showing > ~15–20 bpm/s jumps as sensor artefact before updating HRmax. — confidence: **Established (safety)**
- **D9:** If a rate-limiting medication (e.g. β-blocker) is flagged, disable formula HRmax / zone prescription and fall back to RPE / talk test. — confidence: **Established (safety)**
- **D10:** Down-weight or discard HRmax candidates recorded under heat, dehydration, illness, altitude, or heavy stimulant use unless corroborated. — confidence: **Probable**

## Key references

- Tanaka, H., Monahan, K. D., & Seals, D. R. (2001). *Age-predicted maximal heart rate revisited*. Journal of the American College of Cardiology, 37(1), 153–156. https://doi.org/10.1016/S0735-1097(00)01054-8
- Nes, B. M., Janszky, I., Wisløff, U., Støylen, A., & Karlsen, T. (2013). *Age-predicted maximal heart rate in healthy subjects: The HUNT Fitness Study*. Scandinavian Journal of Medicine & Science in Sports, 23(6), 697–704. https://doi.org/10.1111/j.1600-0838.2012.01445.x
- Gellish, R. L., Goslin, B. R., Olson, R. E., McDonald, A., Russi, G. D., & Moudgil, V. K. (2007). *Longitudinal modeling of the relationship between age and maximal heart rate*. Medicine & Science in Sports & Exercise, 39(5), 822–829. https://doi.org/10.1097/mss.0b013e31803349c6
- Fox, S. M., Naughton, J. P., & Haskell, W. L. (1971). *Physical activity and the prevention of coronary heart disease*. Annals of Clinical Research, 3(6), 404–432. (Origin of the "220 − age" approximation.) https://pubmed.ncbi.nlm.nih.gov/4945367/
- Robergs, R. A., & Landwehr, R. (2002). *The surprising history of the "HRmax=220-age" equation*. Journal of Exercise Physiology Online, 5(2), 1–10. https://www.asep.org/asep/asep/Robergs2.pdf
- Sarzynski, M. A., Rankinen, T., Earnest, C. P., Leon, A. S., Rao, D. C., Skinner, J. S., & Bouchard, C. (2013). *Measured maximal heart rates compared to commonly used age-based prediction equations in the HERITAGE Family Study*. American Journal of Human Biology, 25(5), 695–701. https://doi.org/10.1002/ajhb.22431
- Shookster, D., Lindsey, B., Cortes, N., & Martin, J. R. (2020). *Accuracy of commonly used age-predicted maximal heart rate equations*. International Journal of Exercise Science, 13(7), 1242–1250. https://pmc.ncbi.nlm.nih.gov/articles/PMC7523886/
- Nikolaidis, P. T., Rosemann, T., & Knechtle, B. (2018). *Age-predicted maximal heart rate in recreational marathon runners: A cross-sectional study on Fox's and Tanaka's equations*. Frontiers in Physiology, 9, 226. https://doi.org/10.3389/fphys.2018.00226

## Healthee implementation & honesty policy
- **How HRmax exists in Healthee today: an inline Tanaka constant, not a stored per-user metric.** `HRmax = 208 − 0.7 × age` (Tanaka 2001) is computed **inline** wherever a %HRmax anchor is needed — `derive/cardio_load.py` (`hrmax = 208 - 0.7 * age`, anchoring the Edwards zone thresholds and the TRIMP cardio-load term) and `derive/gps.py` (`hrmax_tanaka`, anchoring per-workout GPS effort zones). Age comes from the `profile` row (`dob`).
- **`max_hr_daily` is a registry name that v2 does not currently emit.** `analytics/metrics.py` explicitly lists `max_hr_daily` among the v1 names **DROPPED** on v2 — no `derive/` `_upsert_daily` writes it to `derived_daily`. So `applies_to_metrics: ["max_hr_daily"]` names the metric this note *backs*, not one presently computed; treat it as **not-yet-computed**. When per-user HRmax is stored, this is the field it lands in.
- **The observed-peak override is documented but not yet wired.** The note's core rule — ratchet HRmax up toward any credible observed peak, prefer a measured maximal test, attach a ±10–12 bpm band to any formula value — is the target behaviour; the shipped code uses the age formula only. Until an observed-peak/measured path exists, %HRmax zones inherit the formula's ±10–12 bpm individual error, so RPE / talk-test remain the primary intensity guides and the artefact-rejection bounds (reject > ~220 bpm or > ~15–20 bpm/s jumps) apply to any future peak-ingestion path.
- **Honesty rules (carry into UI + LLM):**
  - **A formula HRmax is a population placeholder, never exact** — communicate the ±10–12 bpm uncertainty and never present it as a measured ceiling.
  - **Never use `220 − age`**; if a user cites it, correct gently (it under-predicts in older adults). Default to Tanaka.
  - **A flat or slightly falling HRmax is not lost fitness** — HRmax is not trainable.
  - If a rate-limiting medication (e.g. β-blocker) is present, disable formula-HRmax/zone prescription and fall back to RPE / talk test.
