---
id: biological_age_estimate
name: "Biological Age (estimate)"
topic: A motivational "biological age" from wearable metrics via the Gompertz hazard→years conversion (the WHOOP-Age method) — a DOCUMENTED EXCEPTION to the no-composite rule
category: metrics
grade: Probable
summary: "A motivational biological-age estimate converts meta-analytic all-cause-mortality hazard ratios into years via the Gompertz law (MRDT ≈ 7.7y) over TWO levers — fitness and sleep duration; a DOCUMENTED exception to the no-composite rule, admissible only because the conversion is published actuarial math, every input HR is meta-analytic, and the per-term year contributions are always shown. Sleep regularity is deliberately NOT priced (no SRI→hazard conversion transports between scoring pipelines). Three caveats ship with the number: the sleep hours are converted to their questionnaire equivalent before Yin's curve is applied (Lauderdale 2008); the fitness reference is FRIEND's published treadmill 50th percentile (Kaminsky 2022), a US reference standard rather than a population median; and the fitness term's own VO₂max carries a SELF-REPORTED activity category worth 0.6–2.3 years per level, which is asked of the owner and never inferred from steps. An estimate, never a clinical readout."
aliases: ["biological_age", "bio age", "biological age", "whoop age", "gompertz age", "mortality age", "longevity", "composite", "motivational"]
applies_to_metrics: ["biological_age", "vo2max_estimate", "sleep_health_score_4dim"]
applies_to_interventions: []
population: general
last_reviewed: 2026-08-02
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
| **Fitness** (VO₂max-anchored, subsumes steps/MVPA/RHR) | **0.85 per +1 MET** (1 MET = 3.5 ml/kg/min) | FRIEND's age/sex 50th-percentile treadmill VO₂peak | CRF meta-analyses, 20.9M obs (HR 0.83–0.86/MET); reference Kaminsky 2022 |
| **Sleep duration** (U-shaped) | 1.06 per h **below** 7h; 1.13 per h **above** 7h | 7 h **of self-reported sleep** — ≈ 6 h 20 on our strap, after the Lauderdale conversion | Yin 2017 JAHA + Lauderdale 2008 |

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
  (Jurca non-exercise estimate, SEE 1.45 METs ≈ 5.1 ml/kg/min, plus a self-reported
  activity category worth up to 2.3 y a step) — so bio_age is sensitive to
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
- **One input on the fitness side is the owner's own answer, not a measurement** (#108).
  Jurca's activity category is a self-report about deliberate exercise, worth **0.6–2.3
  years per category and 5.5 across the scale**. It is asked, never inferred from steps —
  and the estimate is withheld until it is answered. See *The fitness term's INPUT, not
  its anchor*.
- **Both priced terms carry an anchor caveat, and the payload says so.** The fitness
  reference is now a published one (FRIEND's treadmill 50th percentile) but FRIEND is a
  laboratory-referral cohort, so "population median" is still not a true description of
  it. The sleep term is read at a converted, not a raw, value. See *The anchors, and
  their footing* below; the `caveats` block carries both to the owner.
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

## The anchors, and their footing (2026-08-01, #97)

#86 removed a term because its ANCHOR did not transport. An audit of the two that
survived found both anchored on something other than what they are compared against. A
hazard ratio is a **slope** *and* an **anchor**: 0.85 per MET and 1.06 per hour are
meta-analytic, but they are meaningless until you say *per MET above what*, measured
*with what instrument*. That second half was never sourced. It is now, or its absence is
published — `analytics/reference_scales.py` holds both, and the payload's `caveats` block
carries them to the owner.

### Sleep duration — fixed, because hours are a physical unit

Yin 2017's exposure is a **questionnaire**: "*Sleep duration was measured by self-report
questionnaires in 48 studies and by interview in 19 studies*", and its own limitations
open "*nearly all studies relied on sleep duration that was self-reported by questionnaire
or interview*". Ours is a strap hypnogram. Applying the curve to device hours reads it at
the wrong point on its own x-axis, in the **penalising** direction, and the error is
largest exactly where a short sleeper lives.

The gap is **measured, and dose-dependent rather than a constant**. Lauderdale et al. 2008
(*Epidemiology* 19(6):838–45, PMID 18854708 — CARDIA Chicago, n = 669, 3 days of wrist
actigraphy) publishes three points: mean measured 6.0 h ↔ mean reported 6.8 h; 5 h measured
↔ over-reported by 1.2 h; 7 h measured ↔ over-reported by 0.4 h. All three lie on one line,
`over-report_h = 3.2 − 0.4 × measured_h`, which is also the paper's own "*subjective reports
increased on average by 34 minutes for each additional hour of measured sleep*" to within a
minute. So the device average is converted to its questionnaire equivalent and *then* read
against the 7 h nadir.

Three consequences, all deliberate and all owner-visible:

1. **The lowest-risk point on our scale is ≈ 6 h 20, not 7 h.** That is not a fourth
   recommendation — it is Yin's one nadir expressed on our instrument's axis. The
   *recommended band* remains NSF 2015's 7–9 h, cited by the sleep surfaces that make
   that claim.
2. **The line is not extrapolated.** Below Lauderdale's shortest anchor (5 h) the offset
   is held at 1.2 h rather than grown; from 8 h up, where the line would turn negative
   and start *discounting* the long-sleep tail, it is floored at zero. Both clamps
   choose the conservative side of an unmeasured region.
3. **The residual is stated, not hidden.** Lauderdale's comparator is research
   actigraphy; ours is a consumer strap, a third instrument, never validated here. That
   gap is bounded: a meta-analysis of 22 studies / 798 participants puts consumer
   wrist devices at **−16.9 min of TST vs polysomnography (95% CI −26.3 to −7.4)**, i.e.
   under-reading by under half an hour. *Reasoned, not measured:* an under-reading device
   pushes an owner toward the short branch, so applying Lauderdale unmodified
   **under**-corrects for a short sleeper — the conservative direction — and slightly
   over-credits a long one. Our strap's own bias has never been measured.

> **Why this is not the SRI mistake repeated.** An SRI point is *defined by* the software
> that scored it, so no conversion exists to be found. An hour is an hour: the instruments
> differ by a bias that has been measured, in a physical unit, with the direction of the
> residual known. Refusing to convert is not the neutral option — it asserts that a strap
> and a questionnaire produce the same number, which Lauderdale measured and they do not.

### VO₂max reference median — FIXED in #101, from one published row

The old constants (M 44/41/38/33/28/24, F 36/33/30/26/22/19 across the 20–70 buckets)
drove the **dominant** term and **cited nothing**. Their entire provenance was a comment
in the legacy repo's `api/app.py`, dropped in the port to this one: *"Approximate
population-median VO2max by age band, sex-stratified (ACSM Guidelines 11th ed., ~50th
percentile)"* — whose very next sentence read *"Used only for a 'above/below average for
your age and sex' badge — not for precision claims."* The constant was promoted to
driving a number expressed in years and its own caveat was left behind.

**It is replaced, every cell at once, from one source**: Kaminsky et al. 2022 (*Mayo
Clin Proc* 97(2):285–293, PMID 34809986), **Table 3, treadmill block, the 50th-percentile
row** — directly measured VO₂peak, inclusion criterion RER ≥ 1.0, 16,278 treadmill CPETs
from 34 US laboratories (men n = 9,564, women n = 6,714), tested 1968–2021. Read in full
2026-08-01.

| decade | men (FRIEND 2022) | was | women (FRIEND 2022) | was |
|---|---|---|---|---|
| 20–29 | **46.5** | 44.0 | **36.6** | 36.0 |
| 30–39 | **39.7** | 41.0 | **28.3** | 33.0 |
| 40–49 | **35.3** | 38.0 | **25.7** | 30.0 |
| 50–59 | **29.2** | 33.0 | **22.9** | 26.0 |
| 60–69 | **24.6** | 28.0 | **19.6** | 22.0 |
| 70–79 | **20.6** | 24.0 | **17.2** | 19.0 |
| 80–89 | **17.6** | — | **15.4** | — |

**#97 had the direction backwards for most of the table, and only the full row showed
it.** #97 could check exactly four cells — the two the 2015 abstract prints — found three
of them LOW, and told owners the fitness term *flattered* them by up to ~2.1 y. Across all
twelve cells, **ten were HIGH**: a reference set too fit makes an owner look worse, so the
old table *penalised* nearly everyone. The worst cell was women 30–39 (33.0 against a
published 28.3 — 4.7 ml/kg/min = 1.34 MET ≈ **2.4 years charged and never earned**); the
only genuine flattery was the two 20-something cells (men 20–29 by ≈1.3 y). A four-cell
check is a sample, and a sample's sign does not have to hold — which is why the repair had
to be the whole row from one paper, not a correction of the cells that were visible.

**Why the 2022 edition and not the 2015 one.** Same authors, same registry, same modality,
same effort criterion (the 2015 abstract reads *"maximal (respiratory exchange ratio,
≥1.0) treadmill tests"*), so its Table 3 is the like-for-like successor to the table #97
compared against. Its abstract states the update is *"1.5–4.6 mLO₂·kg⁻¹·min⁻¹ lower
compared with the previous 2015 standards"* and that this *"improve[s] the
representativeness of the US population"*. Both editions were read in full, and the deltas
between their 50th-percentile rows reproduce the 2022 paper's own published ranges exactly
— men 1.5–3.8, women 0.4–1.9 — which is the cross-check that neither table was
mis-transcribed. Using the superseded edition when its authors have published the
replacement would be choosing the number rather than the source.

### What sourcing the table did NOT fix — the surviving caveat

1. **FRIEND is not a population sample, and matching it perfectly would not make
   "population median" true.** The paper's own limitations: *"the individual referral for
   the tests varied (clinical assessment as part of a comprehensive physical exam, fitness
   assessment, and participants in research studies)"*, and *"the term 'apparently
   healthy' may not be appropriate for the entire study population as some had diseases
   (eg, diabetes and obesity)"*. What the term compares against is a **US reference
   standard**, which is a different object from a population's middle.
2. **The direction of that selection has not been measured in the US.** Where FRIEND was
   compared with a whole-population CPET sample measured the same way, it ran LOWER at
   every decade: the 2015 paper's Table 4 puts FRIEND men at 47.6 vs 54.4 (Loe et al.
   2013, n = 3,816 Norwegians) at 20–29 and 25.8 vs 35.3 at 70–79, women 37.6 vs 43.0 and
   18.3 vs 28.3. That paper's own conclusion is that reference values are *"region and
   country specific"*, so this bounds nothing for a US owner — it only shows that the
   choice of reference **cohort** moves this term by more than the correction above did.
3. **Our side of the comparison is an estimate, not a measurement.** Jurca 2005 was
   validated against measured maximal-treadmill VO₂max, so the unit transports (unlike an
   SRI point, *The regularity term, removed*), but it carries SEE = 1.45 METs ≈ 5.1 ml/kg/min ≈ **2.6
   years of ΔAge** — larger than every anchor effect discussed in this section.
   [[non_exercise_vo2max]].

### Why the estimate still ships

Both anchor defects were **bounded, and the sign of each term is robust to the whole
plausible range of anchors** — which is precisely what was NOT true of the regularity
term, whose zero point sat 13 points below the owner's own typical week and which credited
36 days and penalised 35 of the same 71. A bounded bias that is disclosed is a different
object from a coin flip presented as a measurement. Measured on the real owner's data
(prod, 71 days of sleep, VO₂max 22.4, chronological 32): the estimate moved **42.5 → 41.9**
with #97's sleep fix and **41.9 → 41.2** when the fitness reference became FRIEND's
published 39.7 for a 30–39 male instead of the uncited 41.0. The conclusion "markedly less
fit than the reference for your age, and it is worth years" survives every anchor in the
literature's range; what moved is how many.

The line the estimate must not cross is the third state going silent. `withheld` means
*you can fix this*, `excluded` means *nobody can price this*, `caveats` means *this IS in
your number and here is which way it leans*. If a future change drops `caveats` while
keeping the number, the exception this note claims to the no-composite rule lapses.

## The fitness term's INPUT, not its anchor (2026-08-02, #108)

#97 and #101 fixed where the fitness hazard is measured *from*. #108 found the number on
**our** side of that comparison was itself part-invented, and it was the largest error yet
found in this metric: the real owner read **26.4 against a chronological 32**, while
stating plainly that he does not exercise.

### What was wrong, in two independent parts

**(a) The activity term was mis-transcribed.** Jurca 2005 dummy-codes its five-level
self-reported physical-activity scale — Table 5, NASA column: **0 / 0.32 / 1.06 / 1.76 /
3.03 METs**, with level 0 as the reference folded into the intercept. `derive/vo2max.py`
added the **category number** instead (0/1/2/3/4). At the owner's level that is 3.00 METs
where the paper says 1.76 — **4.3 ml/kg/min of fitness nobody earned, ≈ 2.2 years**.

**(b) The category itself was synthesised from step cadence.** Jurca's fifth input is a
*self-report about deliberate exercise*; we banded the trailing 7 days of MVPA-equivalent
minutes at 10/20/60/180 min per week. No such crosswalk has ever been published, and the
constructs differ: Jurca's own level-1 text is "little activity other than **walking for
pleasure**", while a cadence detector counts every minute above 100 steps/min. Measured on
the owner: **159 min/week, every minute of it moderate — zero vigorous all week** — 107 of
it on one day. Scored SR-PA-3, "1 to 3 hours per week of aerobic exercise".

### Why this is a withheld input and not a wider caveat

The obvious repair was to keep the term and widen its caveat with the ±1-band sensitivity.
That was rejected: a ±1.8-year caveat on a number that is ~5 years wrong for a real owner
is still a wrong number with a footnote, and #86's test — *is the error bounded, or is the
input simply not the thing the model requires?* — comes out on the second answer here. The
literature closes the question rather than sizing it: Prince 2008's 187 comparisons put
self-report-vs-device agreement at **mean r = 0.37, spanning −0.71 to 0.96, in both
directions**, and at the five-way *category* level agreement is a few per cent. There is
no crosswalk to find, no bout definition that rescues one, and no device-input variant of
Jurca from him or anyone since.

**But it is `withheld`, not `excluded`, and that distinction is the whole point.** An SRI
point is defined by the software that scored it, so nobody can ever price it. A
self-reported activity category is not unavailable — *it was simply never asked for*. So
the estimate now takes it from `profile.srpa` and withholds until the owner answers.
Removing the fitness term instead would have taken biological age with it (fitness is the
dominant term, and every term is required), and it would have done so over an input that
one question restores.

**Defaulting to the reference level was also rejected**, for the reason this note already
gives for a silently-omitted term: SR-PA-0 is not "unknown", it is the assertion *you do no
deliberate exercise*. Conservative inventions are still inventions.

### What it is worth, measured

The category steps are **0.32 / 0.74 / 0.70 / 1.27 METs** and ΔAge is **1.81 y per MET**,
so one category is worth **0.6 to 2.3 years** and the whole scale **5.5**. Those figures
are owner-independent (a proportional hazard step is the same wherever on the scale it
happens), which is why the payload's third `caveats` entry
(`vo2max_srpa_self_reported`) states them flatly. Note that the steps are **uneven** — the
largest is four times the smallest — which is why [[non_exercise_vo2max]]'s old "the model
is robust to ±1 category noise" could not have been right about more than one of them.

### The owner's number

| | VO₂max | fitness term | biological age |
|---|---|---|---|
| before (cadence → SR-PA-3, linear coding) | 51.1 | −5.9 y | **26.4** |
| SR-PA-3 with the published coefficient | 46.8 | −3.6 y | 28.7 |
| **SR-PA-0, his own answer** | **40.6** | **−0.5 y** | **31.9** |

Chronological 32. At the reference level the model returns essentially the population
median (40.6 against FRIEND's published 39.7 for a 30–39 male), which is what a sedentary
person should read and is the sanity check the fabricated category failed.

*Reasoned, not measured:* what remains is ordinary self-report bias — people answer with
their best week rather than their typical one — which tilts this **towards flattery**. Its
size has not been measured here.

## Operational use

- Surface `biological_age` = chronological + ΔAge, with the **per-term year
  contributions** (e.g. "fitness +X · short sleep +Y") — the breakdown is
  mandatory, not optional, and so is the `excluded` line naming sleep regularity as
  a lever this number does not price **and the `caveats` lines naming how the two
  priced terms lean**.
- UI label: **"Biological age · estimate"** + a one-line "motivational, not
  clinical" note; full method in the ⓘ sheet.
- Evidence label: **★★ moderate** (sound conversion + meta-analytic inputs; novel
  wearable assembly, not a validated clock).

## How the coach uses it
- **Stage 1 (thin data):** hold the number back or heavily caveat it until the VO₂max estimate and ≥14 nights of sleep exist; without inputs there is no estimate (returns nothing).
- **Stage 2 (estimate available):** present it motivationally with the **per-term breakdown** always visible; point the user at whichever term contributes the most years (usually fitness) as the highest-leverage lever.
- **Stage 3 (tracking over time):** frame movement as a motivational trend, treating ±a few years as noise; never imply a measured or clinical age change.
- **Always:** never present it as a diagnosis, a real age, or a mortality/risk number; the breakdown is mandatory.
- **Never present a term as better-footed than it is.** If asked why the sleep target
  on this card looks lower than the 7–9 h the sleep page recommends: the studies measured
  *reported* sleep, reports run long, so the strap's equivalent of their 7 h is about
  6 h 20 — and 7–9 h remains the recommendation, which is a different kind of claim. If
  asked how solid the fitness comparison is: say plainly that the reference is FRIEND's
  published median of 16,278 US treadmill tests, that FRIEND is people who went to a lab
  for a test rather than a sample of the population, and that the bigger uncertainty is on
  our side anyway — their own VO₂max is estimated, not measured, and that estimate's error
  is worth about two and a half years either way. And if asked what "estimated" means
  here: four of its five inputs are measured (age, sex, BMI, resting heart rate) and the
  fifth is **their own answer** about how much deliberate exercise they do in a typical
  week, which is worth between half a year and two and a half per category. Say why we ask
  rather than count it: a step counter cannot tell a training session from walking to the
  shops, and the model's own bottom category already includes walking for pleasure.
- **Never imply sleep regularity is in this number.** If the owner asks why their regularity is not reflected, say plainly that the published SRI risk figures belong to the software that scored the SRI — two standard calculators disagreed on the quintile for three in five of the same people — so we report regularity on its own with its ~1 h-band target rather than converting it into years. Do not offer a substitute conversion.

## Safety bounds
- **Never present biological age as a clinical, diagnostic, or mortality figure** — it is a motivational estimate from population associations only.
- The per-term breakdown is **mandatory**, not optional; the composite number must never be shown alone.
- Each term's contribution is hard-capped at **±10 years** so a single noisy input cannot produce an alarming age.

## Honesty & uncertainty
See **Caveats (must surface)** above — all mandatory. In brief: not causal or clinical (label "estimate"); independence only approximated (±a few years is noise); VO₂max-dominated and uncertain (the ±10y cap exists for this); the reference is "meeting recommendations," so the number is relative to healthy targets, not a measured age. It is a **novel wearable assembly, not a validated clock (★★ moderate)**.

## Bottom line
**Act on confidently:** the Gompertz hazard→years conversion math (★★★); the single-fitness-term correlation fix; showing the mandatory per-term breakdown; the ±10y-per-term cap; framing as a motivational estimate.

**Hold loosely:** the exact biological-age number for an individual (VO₂max-dominated and uncertain — the estimate’s own SEE of 1.45 METs ≈ 5.1 ml/kg/min is worth ~2.6 y, and its self-reported activity input up to 2.3 y a category — both more than the reference cohort’s choice); small movements over time (noise); anything resembling a clinical or mortality readout; the ~6 h 20 device-scale nadir as anything other than where the curve bottoms out on our instrument.

## Coach Directives
1. Always surface the **per-term year contributions** with the number — never the composite alone — and the `excluded` line naming sleep regularity as a lever this number does not price. *(confidence: high)*
2. Label every surface **"Biological age · estimate"** and "motivational, not clinical." *(high)*
3. **SAFETY:** never present it as a clinical/diagnostic age or a mortality/risk figure. *(high)*
4. Treat ±a few years as noise; point the user at the largest-contributing term (usually fitness) as the highest-leverage lever. *(moderate)*
5. Keep the **±10-years-per-term cap**; if the VO₂max estimate looks off, say the bio-age inherits that error. *(high)*
6. Surface the `caveats` block alongside the breakdown: the fitness reference is **FRIEND's published treadmill median — a US reference standard, not a population median** (and the owner's own VO₂max is an estimate, the larger uncertainty of the two), and the sleep hours are read at their **questionnaire equivalent**, so the low-risk point is ≈ 6 h 20 on the strap. *(high)*
7. Never quote the ≈ 6 h 20 device-scale nadir as a sleep *recommendation*. The recommended band is **NSF 2015's 7–9 h**, cited from the sleep surfaces; the nadir is where a mortality curve bottoms out on our instrument. *(high)*

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
- Lauderdale DS, Knutson KL, Yan LL, Liu K, Rathouz PJ (2008). *Self-reported and measured sleep duration: how similar are they?* Epidemiology 19(6):838–845. PMID 18854708. (n=669, CARDIA Chicago, 3 days wrist actigraphy vs usual-sleep questions. Mean measured 6.0 h vs reported 6.8 h; over-report 1.2 h at 5 h measured, 0.4 h at 7 h measured; reports rose 34 min per measured hour. **The source of the device→questionnaire conversion.** *Abstract verified at PubMed 2026-08-01.*)
- Kaminsky LA, Arena R, Myers J, Peterman JE, Bonikowske AR, Harber MP, Medina Inojosa JR, Lavie CJ, Squires RW (2022). *Updated reference standards for cardiorespiratory fitness measured with cardiopulmonary exercise testing: data from the Fitness Registry and the Importance of Exercise National Database (FRIEND).* Mayo Clin Proc 97(2):285–293. DOI 10.1016/j.mayocp.2021.08.020. PMID 34809986. (**The source of the fitness reference table** — Table 3, treadmill, directly measured VO₂peak, inclusion criterion RER ≥ 1.0, the 50th-percentile row: men 46.5 / 39.7 / 35.3 / 29.2 / 24.6 / 20.6 / 17.6 and women 36.6 / 28.3 / 25.7 / 22.9 / 19.6 / 17.2 / 15.4 across the 20–29 → 80–89 decades. 16,278 treadmill CPETs, 34 US laboratories, men n = 9,564 / women n = 6,714, tested 1968–2021. States the update is "1.5–4.6 mLO₂·kg⁻¹·min⁻¹ lower compared with the previous 2015 standards". *Full text and Table 3 read at the publisher 2026-08-01.*)
- Kaminsky LA, Arena R, Myers J (2015). *Reference standards for cardiorespiratory fitness measured with cardiopulmonary exercise testing: data from the Fitness Registry and the Importance of Exercise National Database (FRIEND).* Mayo Clin Proc 90(11):1515–1523. PMID 26455884. (7,783 maximal — RER ≥ 1.0 — treadmill CPETs, ages 20–79. **Superseded by the 2022 edition above and NOT the source of our table**; read in full because its Table 3 is what #97 compared against [men 48.0 / 42.4 / 37.8 / 32.6 / 28.2 / 24.4, women 37.6 / 30.2 / 26.7 / 23.4 / 20.0 / 18.3] and its deltas to the 2022 row reproduce that paper's published "men 1.5–3.8, women 0.4–1.9" exactly — the cross-check that neither table was mis-transcribed. Its Table 4 is also the source of the FRIEND-vs-Norway comparison quoted above. *Full text read at PMC4919021, 2026-08-01.*)
- Loe H, Rognmo Ø, Saltin B, Wisløff U (2013). *Aerobic capacity reference data in 3816 healthy men and women 20–90 years.* PLoS One 8(5):e64319. (The whole-population CPET sample FRIEND ran below at every decade — the measured reason "reference standard" and "population median" are not the same claim. Cited here **only** via Kaminsky 2015's Table 4; not read directly and not a source of any constant.)
- Lee YJ, Lee JY, Cho JH, Kang YJ, Choi JH (2025). *Performance of consumer wrist-worn sleep tracking devices compared to polysomnography: a meta-analysis.* J Clin Sleep Med 21(3):573–582. DOI 10.5664/jcsm.11460. PMID 39484805. (22 studies, 798 participants; total sleep time mean difference **−16.854 min, 95% CI −26.332 to −7.375** vs PSG — consumer wrist devices UNDER-read TST. Bounds the residual our Lauderdale conversion does not correct.)
- Aune D, et al. (2017). *Resting heart rate and the risk of CVD, cancer, and all-cause mortality.* Nutr Metab Cardiovasc Dis 27(6):504–517.
- del Pozo Cruz B, et al. (2022). *Daily step count and mortality.* (Steps dose-response.)
- Woodcock J, et al. (2011). *Non-vigorous physical activity and all-cause mortality: meta-analysis.* Int J Epidemiol 40(1):121–138.
- Wu Y, et al. (2017). *Grip strength and all-cause mortality: meta-analysis.* (Folded into/informing the fitness term, not multiplied separately.)

## Healthee implementation & honesty policy
- **Computed on read, not stored as a daily metric.** `analytics/biological_age.py::compute_biological_age` produces the estimate from `derived_daily` reads; `read/health_metrics.py::biological_age_payload` is a thin wrapper. It returns `chronological_age`, `biological_age`, `delta_years`, `data_confidence`, a `withheld` block, an `excluded` block, a `caveats` block, the signed per-term `contributions`, a `disclaimer` ("Motivational estimate from population data — not a clinical or diagnostic age."), and `research_notes: ["biological_age_estimate"]`; returns **None** without a profile (`dob`/`sex`) or inputs.
- **EVERY term is REQUIRED — no current input for either of the two, no number.** The Stage-1 directive above ("hold the number back … until the VO₂max estimate and ≥14 nights of sleep exist") is enforced structurally, not by caveat. A term simply left out of `chrono + ΣΔAge` is not an omission: it is the assertion `HR_term = 1.0`, i.e. *this person is exactly at the reference for that lever* — silently invented. So when the owner has no `vo2max_estimate` for their **own today** (withheld by [[non_exercise_vo2max]]'s gate, or not derived yet), or no recorded night in the trailing 14, `biological_age` and `delta_years` are `null`, `data_confidence` is `insufficient_data`, and `withheld.terms` lists EVERY absent term with the input metric's own reason and message verbatim (`derive/vo2max.py::WITHHOLD_MESSAGES`) alongside one `consequence` explaining what the absence costs. The contribution that IS current still ships: it is a standalone hazard→years fact, and hiding it would withhold something we do know. With two terms, *both* absent means no contribution at all, which is the pre-existing "nothing to say" floor — `None`, no card.
  - One rule over all terms, rather than a per-term policy, is deliberate: "which terms matter enough" is the question that produced an uncited constant elsewhere in this codebase.
  - The freshness rule is `derive/vo2max.py::estimate_unavailable_reason`, bound to the one shared rule in `derive/freshness.py` and shared with `read/vo2max.py` — so the VO₂max card and this estimate can never disagree about whether today has a number.
- **`excluded` is NOT `withheld`, and the difference is load-bearing.** `withheld` means "you could have this; here is the action". `excluded` names a term the estimate does not price *for anyone*, permanently, because the evidence has no transportable number — `EXCLUDED_TERMS` in `analytics/biological_age.py`, reason id `sri_hazard_not_transportable`. Merging them would promise the owner a fix that does not exist, and would make the composite null forever. Removing a term without saying so would be worse still: "biological age" would mean two different things across two releases under an unchanged key.
- **`caveats` is the THIRD state, and the three are not interchangeable (#97).** `withheld` = "you could have this; here is the action". `excluded` = "nobody can price this, ever". `caveats` = "this IS in your number, and here is which way it leans" — one permanent entry per priced term, `CAVEAT_TERMS` in `analytics/biological_age.py` over the footing statements in `analytics/reference_scales.py`, reason ids `vo2max_reference_clinical_cohort` (renamed from `vo2max_reference_median_uncited` in #101, when the anchor stopped being uncited and the caveat became the part sourcing cannot fix) and `sleep_duration_self_report_scale`. It carries no machine-readable direction field on purpose: neither residual has a single direction we can stand behind — the sleep one pushes short and long sleepers opposite ways, and the fitness one's direction depends on how a lab-referral cohort differs from the US population, which has not been measured. A key that is right for most owners and wrong for some is worse than a sentence right for all of them.
- **Constants.** `GOMPERTZ_MRDT_YEARS = 7.7` (Libert et al. 2025, eLife 13:RP92092 — UK Biobank, both sexes; verified against the paper 2026-08-01, replacing an unattributed "UK Biobank actuarial analysis") and `TERM_CAP_YEARS = 10.0` live in `analytics/biological_age.py`; `b = ln(2)/7.7`, each term `d = clamp(±10, ln(hr)/b)`. The **anchors** moved out to `analytics/reference_scales.py` in #97, because "which anchor came from where" is the question that has now produced three bugs: `_FRIEND_TREADMILL_MEDIAN_MALE/FEMALE` (one published row, sourced per cell, with the replaced table and the full delta beside them — #101), and the Lauderdale device→questionnaire conversion with its two non-extrapolation clamps. `read/vo2max.py` imports `vo2max_median_for` from there too, so the card and the term cannot disagree about the median or about its footing.
- **The two terms (v2 field names):**
  - **Fitness** — latest `vo2max_estimate` vs FRIEND's age/sex 50th percentile, `0.85 ** ((vo2 − ref)/3.5)`. Sourced in #101; the table it replaced was invented, and the payload's `target` moves with it (e.g. 41 → 40 for a 30-something man).
  - **Sleep duration** — 14-night average TST read from `sleep_health_score_4dim` flags (`tst_min`), converted to its questionnaire equivalent by `reference_scales.self_reported_equivalent_h` and only then read against the U-shape about 7 h (`1.06**(7−h)` if h<7 else `1.13**(h−7)`). Fixed in #97: Yin 2017's exposure is **self-reported** and ours is device-measured, so the raw comparison read the curve at the wrong point on its own x-axis. The payload keeps `value` as the hours we actually measured and adds `compared_as`, the converted hours the curve was read at, so the hazard is reproducible from the payload and the translation is visible rather than implied.
  - **The `target` label now says what the maths does.** It read `"7–9"` while charging 1.13× at 8 h and 1.28× at 9 h (#88) — telling the owner 9 h was on target while pricing it as risk. It is now `7.0`, Yin's single-point nadir, on the self-report axis the conversion lands on. This does not create a fourth definition of optimal sleep; it removes the third. The recommended **band** stays NSF 2015's 7–9 h, a consensus recommendation rather than a hazard turning point, cited from the sleep surfaces that make that claim.
  - **Regularity — removed 2026-08-01 (#86).** `compute_biological_age` reads no `sleep_regularity_index` row at all; `tests/analytics/test_biological_age_math.py` fails the build if it does.
  `applies_to_metrics` names `biological_age` (the estimate; the v1 note wrote `biological_age_delta`) plus its real inputs `vo2max_estimate` and `sleep_health_score_4dim` (the TST source; the v1 `asleep` name is retired). `sleep_regularity_index` was dropped from that list with the term.
- **Composite exception:** this is the one documented composite; the per-term breakdown is required by both the note and the code (contributions are always returned). See [[feedback-no-composite-score]].
- **Honesty rules (carry into UI + LLM):** always show the per-term breakdown; label "estimate / motivational, not clinical"; never a mortality/risk/real-age number; ±a few years is noise; if VO₂max looks off, the estimate inherits that error.
