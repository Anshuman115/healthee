---
id: sleep_health_score_multidim
topic: Multi-dimensional sleep health composites (RU-SATED binary sums) — what is and is not validated for wearable-only data
evidence_grade: 2
applies_to_metrics: [asleep, sleep_score, sleep_regularity_index, sleep_light_min, sleep_deep_min]
applies_to_interventions: []
tags: [sleep, scoring, ru-sated, multidim, evidence-review]
last_reviewed: 2026-05-13
---

## Finding

A small body of peer-reviewed cohort research validates **multi-dimensional
binary sleep-health composites** — typically a sum of 0/1 indicators across
the RU-SATED dimensions (Regularity, Satisfaction, Alertness, Timing,
Efficiency, Duration) — against mortality, incident cardiovascular disease,
depression, and cognitive decline. These are scientifically distinct from
the proprietary 0–100 "sleep scores" deprecated in [[no_validated_sleep_score]]:
the components, cutoffs, and additive structure are all pre-specified, and
each cutoff has its own validation literature.

However, none of the published composites is *purely* wearable-derived in a
large mortality cohort. Every validated formula includes at least one
self-report dimension (Satisfaction and/or Alertness). The best objective
work either (a) keeps the dimensions separate or (b) clusters them via
unsupervised ML rather than summing binary indicators.

For this reason the multi-dim sum is a **moderate-confidence** construct,
not a `★★★` one. We can build it from wearable data alone (4 of 6
dimensions), but no paper has demonstrated that the actigraphy-only
4-dimension sum predicts mortality better than its components measured
individually.

## The RU-SATED framework (Buysse 2014)

Buysse's conceptual paper proposes six sleep-health dimensions, each with a
suggested cutoff for "good":

| Dim | Definition | Suggested cutoff |
|---|---|---|
| **R**egularity     | Same bed/wake time | Within 1 h every day |
| S**a**tisfaction   | Subjective contentment | "Good or very good" |
| **T**iming (sic — A is alertness here) | When sleep occurs | Asleep 02:00–04:00 |
| **A**lertness      | Daytime function | Awake all day, no dozing |
| **E**fficiency     | Time asleep / time in bed | < 30 min wake in bed |
| **D**uration       | Hours per 24 h | 7–9 h |

The mnemonic stands for **R**egularity, **S**atisfaction, **A**lertness,
**T**iming, **E**fficiency, **D**uration. Buysse 2014 was a definitional
paper; it did not propose a scoring formula. Subsequent groups
operationalized it.

## Validated composite formulas

### Wallace ML 2017 — MrOS, mortality in older men

- *Which Sleep Health Characteristics Predict All-Cause Mortality in Older
  Men? An Application of Flexible Multivariable Approaches.* Sleep
  41(1):zsx189 (published online 2017, journal-dated 2018). PMID 29165696.
  DOI 10.1093/sleep/zsx189.
- **n = 2,887** older men (mean age 76.3), MrOS Sleep Study; 11-year follow-up;
  36.7 % died.
- **Seven dimensions, binary "extreme" indicators:**

| Dim | Cutoff for "extreme/poor" | Source |
|---|---|---|
| Duration       | ≤ 319.6 min or > 450.3 min     | actigraphy |
| Continuity     | WASO ≥ 88 min                  | actigraphy |
| Timing         | midpoint ≤ 02:00 or > 04:00    | actigraphy |
| Rhythmicity    | pseudo-F ≤ 785.6 (24-h fit)    | actigraphy |
| Regularity     | SD of wake-time ≥ 0.75 h       | actigraphy |
| Sleepiness     | Epworth > 10                   | self-report |
| Quality        | PSQI item "fairly/very bad"    | self-report |

- **Sum of extreme dimensions**: HR 1.10 (95 % CI 1.05–1.15) per additional
  extreme trait, fully adjusted Cox.
- **Individually** significant after adjustment: Rhythmicity (HR 0.89 per
  SD), Continuity/WASO (HR 1.16 per SD). Others were not.
- **Five of seven dimensions are actigraphy-derived.** This is the closest
  large cohort to a "wearable-mostly" validation.

### Furihata R 2017 — SOF, depression in older women

- *An Aggregate Measure of Sleep Health Is Associated With Prevalent and
  Incident Clinically Significant Depression Symptoms Among Community-
  Dwelling Older Women.* Sleep 40(3):zsw075 (2017). PMID 28364417.
  DOI 10.1093/sleep/zsw075.
- **n = 6,485** baseline, 3,806 at 6-y follow-up; Study of Osteoporotic
  Fractures; mean age 80.1.
- **Five dimensions, ALL self-report** (satisfaction with duration, daytime
  sleepiness, mid-sleep time, sleep-onset latency, total duration).
  Each binarised good/poor; summed 0–5.
- **Effect**: gradient association — OR 1.62–5.41 for prevalent depression,
  1.47–3.15 for incident, across increasing numbers of "poor" dimensions.
- Not usable as a template for objective scoring; included here as the
  earliest published RU-SATED-style sum.

### Brindle RC 2019 — MIDUS II, empirical cutoffs

- *Empirical derivation of cutoff values for the sleep health metric and
  its relationship to cardiometabolic morbidity: results from the Midlife
  in the United States (MIDUS) study.* Sleep 42(9):zsz116 (2019).
  PMID 31083710. DOI 10.1093/sleep/zsz116.
- **n = 432** derivation + **n = 268** validation; age 51–57; 7-day
  actigraphy + sleep diaries.
- ROC-derived cutoffs for each RU-SATED dimension:

| Dim | "Good" cutoff | Source |
|---|---|---|
| Regularity   | SD of bedtime < 1 h 5 min             | actigraphy |
| Timing       | midpoint 02:24–03:30                  | actigraphy |
| Efficiency   | > 83 %                                | actigraphy |
| Duration     | 5 h 20 min – 7 h 6 min                | actigraphy |
| Satisfaction | diary quality item < 2.8              | self-report |
| Alertness    | diary alertness item < 2.2            | self-report |

- **Effect**: per 1-point better composite, OR 0.901 (0.814–0.997, p = .04)
  for cardiometabolic morbidity. Effect size **small**.
- Cutoffs derived empirically in this cohort — they are not gold-standard
  thresholds and Brindle's own Duration window (5.3–7.1 h) is markedly
  shorter than the Cappuccio mortality U-curve (7–9 h, see
  [[sleep_duration_mortality]]). This disagreement is a meaningful caveat.

### Lee S 2022 — MIDUS, heart disease, with actigraphy sub-cohort

- *Sleep health composites are associated with the risk of heart disease
  across sex and race.* Sci Rep 12:2023 (2022). PMID 35132087.
  DOI 10.1038/s41598-022-05203-0.
- **n = 6,820** self-report; **n = 663** with actigraphy.
- Built two composites:

| Dim | Self-report version | Actigraphy/diary version |
|---|---|---|
| Regularity   | sleep-debt \|wkday − wkend\| > 60 min | SD of sleep midpoint > 1.64 h |
| Satisfaction | ≥ 1 insomnia symptom (4 items)        | PSQI ≥ 2 |
| Alertness    | > 2 naps/wk                           | diary alertness > 3 |
| Timing       | (not captured)                        | midpoint ≤ 02:00 or > 04:00 |
| Efficiency   | sleep-onset latency > 30 min          | actigraphy SE < 85 % |
| Duration     | < 6 or > 8 h                          | actigraphy < 6 or > 8 h |

- Self-report composite 0–5, actigraphy composite 0–6 (binary sum).
- **Effect**: adjusted RR per unit increase: 1.54 for self-report
  composite, 2.41 for actigraphy/self-report composite. Both p < .001.
- The actigraphy composite has the strongest reported effect size in this
  literature, but Satisfaction and Alertness are still self-report. Four
  of six dimensions (R, T, E, D) are actigraphy-derived.

### Lee S 2024 — MIDUS, early mortality

- *Multidimensional Sleep Health Problems Across Middle and Older Adulthood
  Predict Early Mortality.* J Gerontol A Biol Sci Med Sci 79(3):glad258
  (2024). PMID 37950462. DOI 10.1093/gerona/glad258.
- **n = 5,140** baseline, 2,991 with change scores; MIDUS-2 → MIDUS-3;
  15.3 y median follow-up.
- Same MIDUS framework, **5 dimensions** (timing not measured); cutoffs
  identical to Lee 2022 self-report. All five dimensions are self-report
  (the MIDUS actigraphy sub-cohort, n = 214 with 17 deaths, was
  underpowered for survival analysis).
- **Effect**: per additional sleep-health problem, HR 1.12 (1.04–1.21) for
  all-cause mortality. Increase in problems M2→M3 carried HR 1.27 for
  all-cause and HR 2.53 for heart-disease mortality.

### Cavaillès C 2023 — MrOS, cognitive decline

- *Multidimensional sleep health and long-term cognitive decline in
  community-dwelling older men.* J Alzheimers Dis 96(1):65–71 (2023).
  PMID 37742655. DOI 10.3233/JAD-230737.
- **n = 2,811** MrOS men, ≥ 10-y cognitive follow-up.
- **5-dim SATED score, ALL self-report**: dose-response decline in 3MS
  and Trails B across 0 / 1–2 / 3–5 poor-dimension groups.

### Cavaillès C 2025 — MrOS, ML profiles, dementia / CVD

- *Multidimensional sleep profiles via machine learning and risk of
  dementia and cardiovascular disease.* Commun Med 4:181 (2025).
  PMID 39228701. DOI 10.1038/s43856-025-01019-x.
- **n = 2,667** MrOS men, ≥ 65, 12-y follow-up.
- 37 actigraphy variables (sleep, circadian, non-parametric) clustered
  via unsupervised ML into three profiles:
  - Active Healthy Sleepers (64 %)
  - Fragmented Poor Sleepers (14 %) — HR 1.35 dementia, 1.32 CVD vs AHS
  - Long & Frequent Nappers (22 %) — HR 1.16 CVD (borderline)
- **First large actigraphy-only multi-dimensional sleep-health work in a
  mortality-relevant outcome cohort.** Note: it does NOT use binary
  RU-SATED sums; it uses ML clustering. So it validates the *concept*
  that objective multi-dimensional sleep predicts disease, not a specific
  formula we could compute.

### Bowman 2025 — UK Biobank, "Unfavourable Sleep Profile"

- *Health risks and genetic architecture of objectively measured
  multidimensional sleep health.* Nat Commun (2025).
  DOI 10.1038/s41467-025-62338-0.
- **n = 85,233** UK Biobank participants, 587,152 nights of accelerometer
  data.
- Built an **Unfavourable Sleep Profile (USP)** by factor-analysing 37
  accelerometer-derived features and clustering. The USP is purely
  objective — no self-report — but again it is a multivariate latent
  construct, not a sum-of-binaries score we can reproduce from a single
  formula.
- Demonstrates that an **objective-only multidimensional sleep marker can
  predict diverse health outcomes** in UK Biobank, but the method
  requires the full feature matrix and unsupervised model — it is not a
  closed-form composite.

### Wang 2025 — Health Data Science, phenome-wide

- *Phenome-wide Analysis of Diseases in Relation to Objectively Measured
  Sleep Traits…* Health Data Sci 5:0161 (2025). PMID 40464054.
  DOI 10.34133/hds.0161.
- **n = 88,461** UK Biobank, ≥ 7-y follow-up; six objective sleep traits
  (duration, onset timing, relative amplitude, interdaily stability,
  efficiency, awakenings) tested individually against 172 ICD-10
  outcomes.
- **Sleep rhythm** (relative amplitude + interdaily stability) was the
  single strongest predictor across 48 % of significant disease
  associations — exceeding duration. Reinforces SRI / regularity primacy
  noted in [[sleep_regularity_index]].
- Did **not** construct a composite — supports the view that each
  dimension carries distinct information.

## Synthesis

### Is there a clearly best-validated multi-dim composite for wearable data?

**No, but with nuance.** The most evidence-rich operationalisation is the
**Lee 2022 actigraphy/diary 0–6 composite** (largest reported aRR for heart
disease in a multi-dim sum). The most actigraphy-pure binary sum tested
against mortality is **Wallace 2017** (5 of 7 dimensions from actigraphy,
HR 1.10 per extreme).

Neither study validates a 4-dimension **purely actigraphy** sum (Duration +
Efficiency + Regularity + Timing) as a standalone score. The wearable-only
subset works at the *concept* level (Cavaillès 2025, Bowman 2025) but with
ML/factor approaches, not closed-form sums.

### What does the literature say about dropping Satisfaction & Alertness?

Wallace 2017 explicitly examined which dimensions remain predictive after
adjustment in MrOS. The dimensions that survived (Continuity, Rhythmicity)
are *both* actigraphy-derived. Sleepiness (Epworth) and Quality (PSQI item)
did not independently predict mortality after adjustment. This is one piece
of evidence that the self-report dimensions add limited unique information
once objective sleep is measured well.

But: no paper specifically validates the 4-dim subset {Duration, Efficiency,
Regularity, Timing} as a composite against a hard outcome. Doing so in
healthee is therefore a **reasonable extrapolation, not a replication**.

### Pitfalls of binary-cutoff multi-dim sums

1. **Equal weighting is arbitrary.** Wallace 2017 showed dimensions
   contribute unequally (Rhythmicity HR 0.89 per SD; Sleepiness n.s.).
   Summing binaries treats them as equal — a known limitation called out
   in the Brindle 2019 discussion.
2. **Binary cutoffs lose information.** A duration of 6.5 h and 7.5 h both
   score "good" under most schemas, but only the latter is on the optimum
   of the Cappuccio mortality curve.
3. **Cutoffs disagree across papers.** Brindle 2019's empirical good-duration
   range (5.3–7.1 h) conflicts with the mortality-validated 7–9 h band
   ([[sleep_duration_mortality]]). Choosing one cutoff implicitly endorses
   one validation paradigm.
4. **Wearable stage classification is noisy.** AASM-style efficiency
   requires TST/TIB, and TST from a consumer wrist device has macro-F1
   ≈ 0.26–0.69 vs PSG (Chinoy 2021). The "Efficiency = TST/TIB > 85 %"
   cutoff inherits that noise.
5. **Effect sizes for the composite are not impressive.** Brindle 2019:
   OR 0.90 per point (small). Lee 2024: HR 1.12 per problem (small).
   Compare to SRI alone in Windred 2024: HR up to 1.48 for lowest vs
   highest quintile (see [[sleep_regularity_index]]). The single best
   dimension often beats the composite.
6. **No external validation of the actigraphy-only sum.** All composites
   that have been replicated include self-report.

## Operational use

This note is moderate-confidence (`★★`) and the LLM should qualify
references with words like *"a 4-dimension sleep health composite, by
analogy with Wallace 2017 and Lee 2022 but not directly validated as such…"*.

For the dashboard implementation, see [[sleep_score_implementation_plan]].

## What this note adds beyond [[no_validated_sleep_score]]

[[no_validated_sleep_score]] correctly rejects proprietary continuous
0–100 scores (Whoop, Oura, etc.) for the dashboard. This note covers a
**different** scientific object: pre-specified, binary, sum-of-dimensions
scores with peer-reviewed cutoff sources. The two notes are complementary,
not contradictory — and we still do not display a continuous 0–100 score.

## References

- Buysse DJ. *Sleep health: can we define it? Does it matter?* Sleep
  37(1):9-17 (2014). DOI 10.5665/sleep.3298.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC7289662/
- Wallace ML, Stone K, Smagula SF, et al. *Which Sleep Health
  Characteristics Predict All-Cause Mortality in Older Men? An Application
  of Flexible Multivariable Approaches.* Sleep 41(1):zsx189 (2017/2018).
  PMID 29165696. https://pmc.ncbi.nlm.nih.gov/articles/PMC5806578/
- Furihata R, Hall MH, Stone KL, et al. *An Aggregate Measure of Sleep
  Health Is Associated With Prevalent and Incident Clinically Significant
  Depression Symptoms Among Community-Dwelling Older Women.* Sleep
  40(3):zsw075 (2017). PMID 28364417.
- Brindle RC, Yu L, Buysse DJ, Hall MH. *Empirical derivation of cutoff
  values for the sleep health metric and its relationship to
  cardiometabolic morbidity: MIDUS study.* Sleep 42(9):zsz116 (2019).
  PMID 31083710. https://pmc.ncbi.nlm.nih.gov/articles/PMC7458275/
- Lee S, Mu CX, Wallace ML, et al. *Sleep health composites are associated
  with the risk of heart disease across sex and race.* Sci Rep 12:2023
  (2022). PMID 35132087.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC8821698/
- Lee S, Mu CX, Wallace ML, et al. *Multidimensional Sleep Health Problems
  Across Middle and Older Adulthood Predict Early Mortality.* J Gerontol
  A Biol Sci Med Sci 79(3):glad258 (2024). PMID 37950462.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC10876079/
- Cavaillès C, Yaffe K, Blackwell T, et al. *Multidimensional sleep health
  and long-term cognitive decline in community-dwelling older men.*
  J Alzheimers Dis 96(1):65-71 (2023). PMID 37742655.
- Cavaillès C et al. *Multidimensional sleep profiles via machine learning
  and risk of dementia and cardiovascular disease.* Commun Med (2025).
  PMID 39228701. https://pmc.ncbi.nlm.nih.gov/articles/PMC12283935/
- Bowman et al. *Health risks and genetic architecture of objectively
  measured multidimensional sleep health.* Nat Commun (2025).
  DOI 10.1038/s41467-025-62338-0.
- Wang Y, Wen Q, Luo S, et al. *Phenome-wide Analysis of Diseases in
  Relation to Objectively Measured Sleep Traits…* Health Data Sci
  5:0161 (2025). PMID 40464054. DOI 10.34133/hds.0161.
- Saint-Maurice PF, Freeman JR, Russ D, et al. *Associations between
  actigraphy-measured sleep duration, continuity, and timing with
  mortality in the UK Biobank.* Sleep 47(3):zsad312 (2024).
  PMID 38066693.
- Windred DP et al. *Sleep regularity is a stronger predictor of
  mortality risk than sleep duration.* Sleep 47(1):zsad253 (2024). See
  [[sleep_regularity_index]].
- Cappuccio FP et al. *Sleep duration and all-cause mortality:
  meta-analysis.* Sleep 33(5):585-92 (2010). See
  [[sleep_duration_mortality]].
