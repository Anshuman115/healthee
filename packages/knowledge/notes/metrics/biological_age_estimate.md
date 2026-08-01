---
id: biological_age_estimate
name: "Biological Age (estimate)"
topic: A motivational "biological age" from wearable metrics via the Gompertz hazard→years conversion (the WHOOP-Age method) — a DOCUMENTED EXCEPTION to the no-composite rule
category: metrics
grade: Probable
summary: "A motivational biological-age estimate converts meta-analytic all-cause-mortality hazard ratios into years via the Gompertz law (MRDT ≈ 7.7y) over TWO levers — fitness and sleep duration; a DOCUMENTED exception to the no-composite rule, admissible only because the conversion is published actuarial math, every input HR is meta-analytic, and the per-term year contributions are always shown. Sleep regularity is deliberately NOT priced (no SRI→hazard conversion transports between scoring pipelines) and its exclusion is stated on every surface. An estimate, never a clinical readout."
aliases: ["biological_age", "bio age", "biological age", "whoop age", "gompertz age", "mortality age", "longevity", "composite", "motivational"]
applies_to_metrics: ["biological_age", "vo2max_estimate", "sleep_health_score_4dim"]
applies_to_interventions: []
population: general
last_reviewed: 2026-08-01
---

# Biological Age (estimate)

## Summary
A single "biological age" is estimated by converting all-cause-mortality hazard ratios into years using the Gompertz law of mortality (death hazard doubles every ~7.7–8 years). It is a **deliberate, documented exception to the no-composite rule**, admissible only because (a) the conversion is published actuarial math, (b) every input hazard ratio is meta-analytic, and (c) it is framed as a **motivational estimate, never a clinical readout** — with the per-term year contributions always shown alongside the number. VO₂max (fitness) dominates and is the least certain input, so each term's contribution is capped at ±10 years. Evidence is **★★ moderate**: sound conversion and meta-analytic inputs, but a novel wearable assembly, not a validated clock.

## What it is
Biological age = chronological age + ΔAge, where ΔAge is derived from the product of each tracked input's mortality hazard ratio relative to a "meeting the recommendations" reference. Hitting every target lands the estimate near the person's real age; carrying risk (low fitness, short sleep) adds years. The number is surfaced **only with its per-term breakdown** ("fitness +X · short sleep +Y"), which is the honest part — alongside the levers it deliberately does **not** price, which since 2026-08-01 means sleep regularity.

## Physiology / mechanism
The Gompertz law describes how all-cause mortality hazard rises roughly exponentially with age, doubling over a fixed mortality-rate-doubling-time (MRDT). Because a fixed proportional change in hazard maps to a fixed number of years, a meta-analytic hazard ratio for a risk factor (e.g. lower cardiorespiratory fitness) can be expressed as an equivalent age shift. This is the same hazard→age machinery that validated epigenetic/phenotypic clocks use — the estimate borrows their actuarial conversion, not a new biological measurement.

## Finding

A single "biological age" can be estimated by converting all-cause-mortality
hazard ratios into years, using the **Gompertz law of mortality** (death hazard
rises exponentially, doubling every **MRDT ≈ 7.7–8 years** — Libert et al. 2025
measured **7.7 y, "for both males and females"**, in UK Biobank; the classical
Gompertz figure is ~8 y). The conversion:

```
b        = ln(2) / MRDT                 ≈ 0.693 / 7.7 ≈ 0.090 per year
ΔAge     = ln(HR_total) / b             ≈ 11.1 × ln(HR_total)   (≈11.55 at MRDT 8)
bio_age  = chronological_age + ΔAge
```

This is the SAME hazard→age machinery validated clocks use (Levine PhenoAge 2018;
Hao "GOLD BioAge" 2025). HR_total is the product of each input's hazard ratio
relative to a "meeting the recommendations" reference, so hitting every target
lands you near your real age.

**⚠ This is a composite — a deliberate, documented exception to
[[feedback-no-composite-score]].** It is admissible ONLY because (a) the conversion
is published actuarial math, (b) every input HR is meta-analytic, and (c) it is
framed as a *motivational estimate, never a clinical readout*. The per-metric YEAR
CONTRIBUTIONS are shown alongside the number — the breakdown is the honest part.

## Inputs we use (and the correlation fix)

Naive multiplication of all metrics double-counts cardio-fitness (VO₂max, steps,
MVPA, RHR are heavily correlated). So we collapse them into **ONE fitness term**
and keep the independent sleep axes separate:

| term | HR | reference | source |
|---|---|---|---|
| **Fitness** (VO₂max-anchored, subsumes steps/MVPA/RHR) | **0.85 per +1 MET** (1 MET = 3.5 ml/kg/min) | age/sex-median VO₂max | CRF meta-analyses, 20.9M obs (HR 0.83–0.86/MET) |
| **Sleep duration** (U-shaped) | 1.06 per h **below** 7h; 1.13 per h **above** 7h | 7h | Yin 2017 JAHA |

We deliberately **omit grip/strength** (no sensor) rather than fake a proxy.
HR_total = HR_fitness × HR_sleepdur.

**Sleep regularity is deliberately NOT a term** — see *The regularity term, removed*
below. It was one until 2026-08-01, on Cribb 2023's SRI hazard anchors, and those
anchors are on a different SRI scale from the one we compute. It was removed rather
than re-anchored because the published SRI→mortality hazards are properties of the
software that scored the SRI, not of the index.

## Effect size / sanity checks

- HR_total = 1.10 → ΔAge = +1.05 y (the "10% ≈ 1 year" rule). ✓
- VO₂max is the dominant term (strongest HR per MET) AND the least certain input
  (Jurca non-exercise estimate, ±5.6 ml/kg/min SEE) — so bio_age is sensitive to
  it. We **cap each term's contribution to ±10 years** to stop a single noisy
  input producing an absurd/alarming age.

## Evidence strength

- **Gompertz / MRDT 7.7y**: Libert, Chekholko & Kenyon 2025 (*eLife* 13:RP92092,
  PMID 40497443), whose UK Biobank mortality analysis states verbatim: *"The
  distribution of these deaths among UKBB participants has a typical 'Gompertzian'
  shape, with mortality rates exponentially doubling every 7.7 years for both males
  and females."* Their own framing of the classical value: *"mortality rates increase
  exponentially with time, doubling roughly every 8 years."* **★★★** for the
  conversion math (Gompertz is not in dispute); **★★** for 7.7 as *our* MRDT
  parameter — it is one cohort's empirical estimate, from 8,883 male and 5,668 female
  deaths within 5 years of enrolment in a healthy-volunteer cohort recruited at ages
  40–70, not a universal constant. The estimate is insensitive to the choice within
  the plausible range: ΔAge = 11.1 × ln(HR) at MRDT 7.7 vs 11.55 at MRDT 8 — a ~4 %
  difference, well inside the "±a few years is noise" caveat below.
- **PhenoAge** (Levine et al. 2018, *Aging*) + **GOLD BioAge** (Hao et al. 2025,
  *Nature Aging*) — methodological templates: hazard-score → years. **★★**.
- **CRF/VO₂max**: dose-response meta-analyses, HR 0.83–0.86 per MET, 20.9M obs
  (Kokkinos JACC 2022; Atherosclerosis 2021; ScienceDirect 2024). **★★★**.
- **Sleep duration**: Yin et al. 2017 *JAHA* dose-response (also Cappuccio 2010).
  **★★**.
- **SRI — the evidence that there is no admissible input here.** Czeisler et al. 2026
  (*Sleep* 49(4):zsaf299) is **★★★** for the negative claim: it is a direct head-to-head
  on the same >70 000 participants, and a measurement of non-transportability is not the
  same kind of thing as an association. Cribb et al. 2023 and Windred et al. 2024 are both
  **★★** for SRI↔mortality *within their own pipelines*; neither is admissible against our
  values. See *The regularity term, removed*.
- RHR (Aune 2017 ★★★), steps (del Pozo Cruz 2022 ★★), MVPA (Woodcock 2011 ★★),
  grip (Wu 2017 ★★) — all in the per-metric notes; folded into / informing the
  fitness term, not multiplied separately.

## Caveats (must surface)

- **Not causal, not clinical.** Population associations → a *motivational trend*,
  never a diagnosis. Label every surface as "estimate."
- **Independence is approximated.** Even with one fitness term, residual
  correlation remains; treat ±a few years as noise.
- **Two levers, not three, and the third is named on every surface.** The estimate
  prices fitness and sleep duration. It does not price sleep regularity — see the next
  section for why, and note that this is a limit of the evidence, not of the owner's
  data: no amount of syncing brings it back, so it ships in the payload's `excluded`
  block rather than its `withheld` one.
- **VO₂max-dominated + uncertain** — see the cap above. If the VO₂max estimate
  looks off, the bio_age inherits that error.
- Reference = "meeting recommendations," so the number is *relative to healthy
  targets*, not a measured age.

## The regularity term, removed (2026-08-01, #86)

Until 2026-08-01 the table above had a third row: SRI, log-interpolated through
**Cribb 2023**'s anchors (SRI 41 → HR 1.53, SRI 75 → HR 0.90, relative to Cribb's
median). It was **removed, not re-anchored.** This section is the record so nobody
re-derives it or quietly puts it back.

### What was wrong

Cribb's anchors are on Cribb's SRI scale. Cribb's UK Biobank cohort had a **median SRI
of 60 (SD 10)**; Windred 2024's UK Biobank cohort — the same biobank, the same
accelerometry — had a **median of 81.0 [IQR 73.8–86.3]**. Neither is wrong: the SRI a
study reports depends on its sleep-detection pipeline (Windred ran GGIR then `sleepreg`,
which counts naps and subtracts long wake episodes; Cribb ran GGIR 2.7-1 alone, which
*"is not able to identify naps"*; ours is night-only from the strap's hypnogram).

Where our own scale sits was **measured** (`tests/derive/test_sri_scale.py`, which drives
the real estimator over seeded sleep sessions):

- `derive/sleep_score.py::_compute_sri` reduces, for a sleeper whose bed and wake times
  shift by *d* minutes between consecutive days, to **SRI = 100 − (200/1440) × 2d**.
  Cross-check: the canonical worked example (7 h sleep drifting 2 h, *d* = 120) gives
  **66.67**. ✓
- Windred's own behavioural description of its quintiles, pushed through that formula,
  lands **3.35–4.35 points high** of Windred's own published quintile boundaries at both
  ends. Cribb's numbers do not survive the same test: Cribb's *median* of 60 would be a
  person moving their sleep 2.4 h at each end every night.
- The consequence needed no scale assumption: the log-linear crossed HR = 1.0 at
  **SRI 68.24**, which on our estimator is a ~1.9 h shift at each end, nightly.

### Why it was not simply re-anchored to Windred

Windred 2024 **does** publish all-cause-mortality hazards on a scale close to ours
(quintile medians 65.10 / 75.62 / 80.99 / 85.22 / 89.80; fully-adjusted HRs vs the
least-regular quintile 0.80 / 0.75 / 0.72 / 0.70). Re-anchoring was therefore
arithmetically available and was refused, on three grounds:

1. **The hazard belongs to the calculator, not to the index — measured, not argued.**
   *Czeisler et al. 2026* (**Sleep** 49(4):zsaf299, PMID 41001850) scored **the same
   >70 000 UK Biobank adults** with both standard SRI calculators. Verbatim: SRI scores
   *"differed markedly, both in absolute and relative values"*, and *"Applied to
   prospective clinical outcome models for all-cause mortality, incident type 2 diabetes,
   and incident atrial fibrillation or atrial flutter, the method of calculation alone
   meaningfully changed results and interpretations."* Its accompanying editorial
   (*Cedernaes et al. 2026*, Sleep 49(4):zsaf289) gives the size: *"only two-fifths of
   participants were classified into the same sleep regularity index quintile"*, and
   *"Using sleepreg, middle-aged participants with the most irregular sleep patterns had
   a 1.19-fold higher adjusted hazard of death … In contrast, no significant association
   was observed when the same data were analyzed using GGIR."*
2. **Windred's numbers are quintile-MEMBERSHIP contrasts**, and quintile membership is
   precisely the quantity Czeisler measured as non-transportable. Windred publishes no
   continuous per-point hazard — its design is quintiles only (*"This approach allowed
   for unspecified non-linearity"*), so there is no pipeline-agnostic slope to borrow.
3. **An SRI point has no physical unit.** The other two terms survive scale differences
   because ml/kg/min and hours mean the same thing in every study; a fixed proportional
   hazard per MET or per hour transports. An SRI point is defined by its detection
   pipeline and transports nothing. Ours is a **third** pipeline (strap hypnogram, global
   Phillips, night-only by documented design), never run against any outcome cohort.

*Reasoned, not measured:* the residual bias of a Windred-anchored term would sit in the
**flattering** direction, because our documented night-only deviation drops naps that
`sleepreg` counts and a missed irregular nap can only raise our score. The direction
follows from the definitions; the magnitude has never been measured.

### What was measured on real owner data

71 days of a real owner's `sleep_regularity_index` (prod, 2026-04-20 → 2026-07-15):
median **68.3**, IQR 59.5–72.7, range 46.5–80.4, SD 8.2. Over those 71 days the Cribb-
anchored term averaged **+0.35 y**, crediting 36 days and penalising 35 — so the earlier
write-up's claim that "every realistic owner gets an age-reducing contribution" was
**false for the one real owner we have**, whose distribution straddles the 68.24 neutral
point. The term was not a constant subtraction; it was noise dressed as years, with the
whole curve displaced ~21 points from the population it was estimated on. That does not
rescue it — a term whose zero is 13 points below our own owner's typical week is not
measuring what it claims — but the magnitude is recorded honestly rather than assumed.

### What would let it come back

Our SRI pipeline validated against an outcome cohort, or a published crosswalk between
nap-detecting and non-nap-detecting SRI. The latter does not exist: the one study that
compared the pipelines head to head responded with a 14-item reporting checklist (RIRI),
not a conversion. Until then, regularity is coached on its own page with its behavioural
target (`sleep_regularity_index`), where the portable claim — *keep sleep and wake inside
a ~1 h band* — lives, and it contributes no years here.

## Operational use

- Surface `biological_age` = chronological + ΔAge, with the **per-term year
  contributions** (e.g. "fitness +X · short sleep +Y") — the breakdown is
  mandatory, not optional, and so is the `excluded` line naming sleep regularity as
  a lever this number does not price.
- UI label: **"Biological age · estimate"** + a one-line "motivational, not
  clinical" note; full method in the ⓘ sheet.
- Evidence label: **★★ moderate** (sound conversion + meta-analytic inputs; novel
  wearable assembly, not a validated clock).

## How the coach uses it
- **Stage 1 (thin data):** hold the number back or heavily caveat it until the VO₂max estimate and ≥14 nights of sleep exist; without inputs there is no estimate (returns nothing).
- **Stage 2 (estimate available):** present it motivationally with the **per-term breakdown** always visible; point the user at whichever term contributes the most years (usually fitness) as the highest-leverage lever.
- **Stage 3 (tracking over time):** frame movement as a motivational trend, treating ±a few years as noise; never imply a measured or clinical age change.
- **Always:** never present it as a diagnosis, a real age, or a mortality/risk number; the breakdown is mandatory.
- **Never imply sleep regularity is in this number.** If the owner asks why their regularity is not reflected, say plainly that the published SRI risk figures belong to the software that scored the SRI — two standard calculators disagreed on the quintile for three in five of the same people — so we report regularity on its own with its ~1 h-band target rather than converting it into years. Do not offer a substitute conversion.

## Safety bounds
- **Never present biological age as a clinical, diagnostic, or mortality figure** — it is a motivational estimate from population associations only.
- The per-term breakdown is **mandatory**, not optional; the composite number must never be shown alone.
- Each term's contribution is hard-capped at **±10 years** so a single noisy input cannot produce an alarming age.

## Honesty & uncertainty
See **Caveats (must surface)** above — all mandatory. In brief: not causal or clinical (label "estimate"); independence only approximated (±a few years is noise); VO₂max-dominated and uncertain (the ±10y cap exists for this); the reference is "meeting recommendations," so the number is relative to healthy targets, not a measured age. It is a **novel wearable assembly, not a validated clock (★★ moderate)**.

## Bottom line
**Act on confidently:** the Gompertz hazard→years conversion math (★★★); the single-fitness-term correlation fix; showing the mandatory per-term breakdown; the ±10y-per-term cap; framing as a motivational estimate.

**Hold loosely:** the exact biological-age number for an individual (VO₂max-dominated and uncertain); small movements over time (noise); anything resembling a clinical or mortality readout.

## Coach Directives
1. Always surface the **per-term year contributions** with the number — never the composite alone — and the `excluded` line naming sleep regularity as a lever this number does not price. *(confidence: high)*
2. Label every surface **"Biological age · estimate"** and "motivational, not clinical." *(high)*
3. **SAFETY:** never present it as a clinical/diagnostic age or a mortality/risk figure. *(high)*
4. Treat ±a few years as noise; point the user at the largest-contributing term (usually fitness) as the highest-leverage lever. *(moderate)*
5. Keep the **±10-years-per-term cap**; if the VO₂max estimate looks off, say the bio-age inherits that error. *(high)*

## References
- Levine ME, et al. (2018). *An epigenetic biomarker of aging for lifespan and healthspan (PhenoAge).* Aging 10(4):573–591.
- Hao et al. (2025). *GOLD BioAge.* Nature Aging (hazard-score → years methodological template).
- Kokkinos P, et al. (2022). *Cardiorespiratory fitness and mortality risk.* JACC (CRF dose-response, HR 0.83–0.86 per MET, 20.9M obs); with corroborating Atherosclerosis 2021 and ScienceDirect 2024 meta-analyses.
- Yin J, et al. (2017). *Relationship of sleep duration with all-cause mortality: a dose-response meta-analysis.* JAHA 6(9):e005947. (Also Cappuccio FP, et al. 2010.)
- Cribb L, Sha R, Yiallourou S, Grima NA, Cavuoto M, Baril A-A, Pase MP (2023). *Sleep regularity and mortality: a prospective analysis in the UK Biobank.* eLife 12:RP88359. DOI 10.7554/eLife.88359. PMID 37995126. (n=88,975; median SRI 60; HR 1.53 @SRI 41 [5th pct] → 0.90 @SRI 75 [95th pct]. **The former source of the removed regularity term** — GGIR 2.7-1, no nap detection.)
- Windred DP, Burns AC, Lane JM, Saxena R, Rutter MK, Cain SW, Phillips AJK (2024). *Sleep regularity is a stronger predictor of mortality risk than sleep duration.* Sleep 47(1):zsad253. (Quintile medians 65.10 / 75.62 / 80.99 / 85.22 / 89.80; fully-adjusted all-cause HRs vs the least-regular quintile 0.80 / 0.75 / 0.72 / 0.70; **no continuous per-point hazard is published**. GGIR + `sleepreg`, median SRI 81.0.)
- Czeisler MÉ, Leota J, Le F, Campbell-Brown B, Rajaratnam SMW, Pase MP, Kramer DB (2026). *Comparison of Sleep Regularity Index scores calculated by open-source packages and implications for outcomes research: rationale and design of the RIRI statement (Reporting Items for Regularity Indices).* Sleep 49(4):zsaf299. DOI 10.1093/sleep/zsaf299. PMID 41001850. (**The source of the removal.** >70,000 UK Biobank adults scored by both calculators; the method of calculation alone changed all-cause-mortality results and interpretations.)
- Cedernaes J, Sielaff B, Benedict C (2026). *Time to regularize sleep regularity* (editorial on the above). Sleep 49(4):zsaf289. DOI 10.1093/sleep/zsaf289. (Source of "only two-fifths of participants were classified into the same … quintile" and the 1.19-vs-null mortality contrast.)
- Libert S, Chekholko A, Kenyon C (2025). *A mathematical model that predicts human biological age from physiological traits identifies environmental and genetic factors that influence aging.* eLife 13:RP92092. DOI 10.7554/eLife.92092. PMID 40497443. (Source of MRDT = 7.7 y, UK Biobank, both sexes.)
- Gavrilov LA, Gavrilova NS (2024). *Exploring patterns of human mortality and aging: a reliability theory viewpoint.* Biochemistry (Moscow) 89(2):341–355. DOI 10.1134/S0006297924020123. PMID 38622100. (Review; "human mortality rates double approximately every 8 years of adult age" — the classical ~8 y comparator.)
- Aune D, et al. (2017). *Resting heart rate and the risk of CVD, cancer, and all-cause mortality.* Nutr Metab Cardiovasc Dis 27(6):504–517.
- del Pozo Cruz B, et al. (2022). *Daily step count and mortality.* (Steps dose-response.)
- Woodcock J, et al. (2011). *Non-vigorous physical activity and all-cause mortality: meta-analysis.* Int J Epidemiol 40(1):121–138.
- Wu Y, et al. (2017). *Grip strength and all-cause mortality: meta-analysis.* (Folded into/informing the fitness term, not multiplied separately.)

## Healthee implementation & honesty policy
- **Computed on read, not stored as a daily metric.** `analytics/biological_age.py::compute_biological_age` produces the estimate from `derived_daily` reads; `read/health_metrics.py::biological_age_payload` is a thin wrapper. It returns `chronological_age`, `biological_age`, `delta_years`, `data_confidence`, a `withheld` block, an `excluded` block, the signed per-term `contributions`, a `disclaimer` ("Motivational estimate from population data — not a clinical or diagnostic age."), and `research_notes: ["biological_age_estimate"]`; returns **None** without a profile (`dob`/`sex`) or inputs.
- **EVERY term is REQUIRED — no current input for either of the two, no number.** The Stage-1 directive above ("hold the number back … until the VO₂max estimate and ≥14 nights of sleep exist") is enforced structurally, not by caveat. A term simply left out of `chrono + ΣΔAge` is not an omission: it is the assertion `HR_term = 1.0`, i.e. *this person is exactly at the reference for that lever* — silently invented. So when the owner has no `vo2max_estimate` for their **own today** (withheld by [[non_exercise_vo2max]]'s gate, or not derived yet), or no recorded night in the trailing 14, `biological_age` and `delta_years` are `null`, `data_confidence` is `insufficient_data`, and `withheld.terms` lists EVERY absent term with the input metric's own reason and message verbatim (`derive/vo2max.py::WITHHOLD_MESSAGES`) alongside one `consequence` explaining what the absence costs. The contribution that IS current still ships: it is a standalone hazard→years fact, and hiding it would withhold something we do know. With two terms, *both* absent means no contribution at all, which is the pre-existing "nothing to say" floor — `None`, no card.
  - One rule over all terms, rather than a per-term policy, is deliberate: "which terms matter enough" is the question that produced an uncited constant elsewhere in this codebase.
  - The freshness rule is `derive/vo2max.py::estimate_unavailable_reason`, bound to the one shared rule in `derive/freshness.py` and shared with `read/vo2max.py` — so the VO₂max card and this estimate can never disagree about whether today has a number.
- **`excluded` is NOT `withheld`, and the difference is load-bearing.** `withheld` means "you could have this; here is the action". `excluded` names a term the estimate does not price *for anyone*, permanently, because the evidence has no transportable number — `EXCLUDED_TERMS` in `analytics/biological_age.py`, reason id `sri_hazard_not_transportable`. Merging them would promise the owner a fix that does not exist, and would make the composite null forever. Removing a term without saying so would be worse still: "biological age" would mean two different things across two releases under an unchanged key.
- **Constants (ported verbatim from legacy `biological_age.py`):** `GOMPERTZ_MRDT_YEARS = 7.7` (Libert et al. 2025, eLife 13:RP92092 — UK Biobank, both sexes; verified against the paper 2026-08-01, replacing an unattributed "UK Biobank actuarial analysis"), `TERM_CAP_YEARS = 10.0`, and the age/sex population-median VO₂max tables (`_VO2MAX_MEDIAN_MALE/FEMALE`, 20–70 buckets — ⚠ these are **uncited**, carried over from legacy; unverified whether the Jurca non-exercise estimate and this reference table are on the same footing). `b = ln(2)/7.7`; each term `d = clamp(±10, ln(hr)/b)`.
- **The two terms (v2 field names):**
  - **Fitness** — latest `vo2max_estimate` vs age/sex median, `0.85 ** ((vo2 − ref)/3.5)`.
  - **Sleep duration** — 14-night average TST read from `sleep_health_score_4dim` flags (`tst_min`), U-shaped about 7h (`1.06**(7−h)` if h<7 else `1.13**(h−7)`). ⚠ Yin 2017's exposure is **self-reported** sleep duration, which [[sleep_duration_mortality]] records as over-estimating device-measured TST by 30–60 min; ours is device-measured. That is the same anchor-vs-scale class as the removed regularity term, in the *penalising* direction, and it is open rather than fixed here — unlike SRI, hours are a physical unit and the offset is measurable, so this one is repairable.
  - **Regularity — removed 2026-08-01 (#86).** `compute_biological_age` reads no `sleep_regularity_index` row at all; `tests/analytics/test_biological_age_math.py` fails the build if it does.
  `applies_to_metrics` names `biological_age` (the estimate; the v1 note wrote `biological_age_delta`) plus its real inputs `vo2max_estimate` and `sleep_health_score_4dim` (the TST source; the v1 `asleep` name is retired). `sleep_regularity_index` was dropped from that list with the term.
- **Composite exception:** this is the one documented composite; the per-term breakdown is required by both the note and the code (contributions are always returned). See [[feedback-no-composite-score]].
- **Honesty rules (carry into UI + LLM):** always show the per-term breakdown; label "estimate / motivational, not clinical"; never a mortality/risk/real-age number; ±a few years is noise; if VO₂max looks off, the estimate inherits that error.
