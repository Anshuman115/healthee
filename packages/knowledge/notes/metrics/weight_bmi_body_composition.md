---
id: weight_bmi_body_composition
name: "Body weight, BMI, and body composition"
topic: What a scale reading is (mostly not fat), what BMI can and cannot tell you, and what we do not measure
category: metrics
grade: Established
summary: "A single weigh-in is a mass measurement, not a fat measurement: day-to-day body mass varies by ~0.5 kg (CV <1%) from water, glycogen and gut contents, and 84% of a two-week weight change is fat-free mass — so only a trend well above that noise floor means anything. BMI is a population screening tool that misses about half the people with excess body fat, cannot separate muscle from fat, and shifts meaning with age, sex and ancestry; we use it in the VO₂max model anyway and must say what that costs."
aliases: ["weight", "body weight", "weight trend", "weight fluctuation", "water weight", "scale", "weighing", "self-weighing", "bmi", "body mass index", "body composition", "body fat", "fat mass", "lean mass", "fat-free mass", "waist circumference", "waist-to-height ratio", "adiposity"]
applies_to_metrics: ["weight_kg", "vo2max_estimate", "basal_calories", "total_calories", "active_calories"]
applies_to_interventions: []
population: general
last_reviewed: 2026-08-01
related: ["non_exercise_vo2max", "energy_expenditure_derivation", "biological_age_estimate"]
tags: [weight, bmi, body composition, adiposity, metrics]
---

# Body weight, BMI, and body composition

## Summary

A scale measures **mass**, and mass is mostly not fat. Within-person day-to-day
body mass varies by about **0.51 ± 0.20 kg** (CV **0.66 ± 0.24%**) in healthy
men under standardised morning conditions (Cheuvront et al. 2004, n = 65), and
over two weeks of ordinary free living **84% of a unit change in body weight is
fat-free mass** (Bhutani et al. 2017). Controlled manipulation makes the point
brutally: 48 h of carbohydrate loading after dehydration moved body mass by
**+2.53 kg** with **no change in fat mass at any timepoint** (Toomey et al.
2017). So a single weigh-in, or a difference between two weigh-ins a few days
apart, carries almost no information about body fat.

**BMI** is a population screening tool. Pooled across 32 samples (n = 31,968),
common BMI cutoffs for obesity had **sensitivity 0.50 (95% CI 0.43–0.57)** and
**specificity 0.90 (0.86–0.94)** against measured body fat — they "fail to
identify half of the people with excess BF%" (Okorodudu et al. 2010). It cannot
separate muscle from fat, and at the same BMI predicted body fat differs by
**sex, age and ethnic group** (Gallagher et al. 2000). We nevertheless feed BMI
into the Jurca non-exercise VO₂max model, and this note is where that cost is
stated.

**We do not measure body composition at all.** No smart scale, no bioimpedance,
no waist tape. We have manually logged weight, whenever the owner chooses to
enter it. Everything downstream inherits that.

## What it is

- **`weight_kg`** — total body mass, self-reported and manually logged into the
  app. One row per local day, only written when the value actually changed.
- **BMI** — mass (kg) ÷ height (m)². Not stored as a metric; computed on the fly
  inside the VO₂max derivation from the latest logged weight and profile height.
- **Body composition** — the split of that mass into fat mass, fat-free mass
  (muscle, organs, bone, glycogen and the water bound to all of it), and where
  the fat sits (visceral vs subcutaneous). **We measure none of it.**

## Physiology / mechanism

Body mass on any given morning is the sum of tissue that changes over months
(fat, muscle, bone) and stores that change over hours:

- **Glycogen and its bound water.** Muscle glycogen is stored hydrated — "per
  each gram of glycogen, 3 g of water was stored in muscle" (Fernández-Elías
  et al. 2015), and glycogen is "stored in the liver, muscles, and fat cells in
  hydrated form (three to four parts water) associated with potassium (0.45 mmol
  K/g glycogen)" (Kreitzman et al. 1992). *Our arithmetic from that ratio*: a
  250 g swing in stored glycogen carries ≥750 g of water with it — about a
  kilogram of scale weight, from a store that turns over inside a day.
- **Total body water** — sweat losses, drinking, sodium and carbohydrate intake,
  and the fluid shifts that follow hard exercise.
- **Gut contents** — food and fluid in transit, and stool not yet passed.

Fat mass moves on an energy-balance timescale of weeks. The short-term stores
move on a timescale of hours. That mismatch, not measurement error, is why the
scale is noisy: "the energy density of 1–3 kg short-term changes in body weight
averaged 2380 kcal/kg", against the tissue energy densities the same authors
use — "1020 kcal/kg and 9500 kcal/kg for FFM and FM, respectively" (Bhutani
et al. 2017). A kilogram that costs 2380 kcal is arithmetically nowhere near a
kilogram of fat.

## The evidence

### Day-to-day weight is dominated by non-fat mass [Established]

- Over two weeks of unrestricted free living in 46 adults across two cohorts,
  "a unit change in body weight was composed of 84% change in FFM in the
  combined dataset indicating that 2-week fluctuation in body weight is largely
  composed of FFM"; average change was **0.26 ± 1.2 kg**, "consistent with being
  in energy balance" (Bhutani et al. 2017, TBW by isotope dilution + serial DXA).
- Controlled: after exercise-heat dehydration, "mean body mass decreased by
  −1.93 kg (95% CI −2.3, −1.5)"; 48 h of carbohydrate loading then "induced a
  mean body mass increase of 2.53 kg (2.0, 3.1) and a total LTM increase of
  2.36 kg (1.8, 2.9)". Crucially: "**No change in total fat mass** or bone
  mineral content was observed at any timepoint" (Toomey et al. 2017, n = 12).
  *[primary-source verified 2026-08-01]*

### The size of the normal daily swing [Probable]

Three independent measurements, all consistent, **all in men** (see Honesty):

- "Group daily variation in BM was 0.51 ± 0.20 kg. Group coefficient of
  variation was 0.66 ± 0.24%" — first-morning mass, 4–15 consecutive days
  (Cheuvront et al. 2004, n = 65 active men). Their conclusion: daily
  variability "is less than 1% for active men".
- Typical error of measurement for body mass across a Monday–Friday week was
  **0.6 kg** (Kutáč 2015, n = 86 young men), with the explicit interpretation
  rule that one should "take as provable change caused by the observed factors
  only the ones whose values exceed the value of a weekly TE".
- In 9,521 days of standardised measurement from **one** healthy man,
  day-to-day relative differences had an "SD of 0.53% for the one-day
  interval, which increased to 0.69% for the 7-day interval"; the authors
  recommend allowing "approximately 0.6% (±450 mL in a 75-kg patient)"
  (Schneditz et al. 2023). *[primary-source verified 2026-08-01]*

**Graded Probable, not Established, on purpose**: the direction is unarguable but
every cohort we could verify is male, young-to-middle-aged, and measured under
standardised morning conditions. Nothing here licenses a number for women, for
older adults, or for an unstandardised weigh-in.

### BMI cannot distinguish muscle from fat [Established]

- Pooled over 25 articles / 32 samples / 31,968 people: "Commonly used BMI
  cutoffs to diagnose obesity showed: pooled sensitivity of 0.50 (95% CI:
  0.43–0.57); pooled specificity of 0.90 (CI: 0.86–0.94)"; for BMI ≥30,
  "sensitivity of 0.42 (CI: 0.31–0.43) and pooled specificity of 0.97 (CI:
  0.96–0.97)". Conclusion: BMI cutoffs "have high specificity, but low
  sensitivity to identify adiposity, as they fail to identify half of the people
  with excess BF%" (Okorodudu et al. 2010).
- In 226 college athletes and 213 non-athletes measured by air displacement
  plethysmography, "Sensitivity was high (0.83–1.0) and **specificity was low
  (0.27–0.66)** in male athletes, male nonathletes, and female athletes" — i.e.
  BMI flags lean muscular people as overweight. Optimal BMI cut points for
  over-fatness ranged from **24.0** (female non-athletes) to **34.1** (football
  linemen). "BMI should be used cautiously when classifying fatness in college
  athletes and nonathletes" (Ode et al. 2007).
- At a given BMI, predicted percentage body fat depends on more than BMI:
  "Independent percentage body fat predictor variables in multiple regression
  models included 1/BMI, **sex, age, and ethnic group**" (Gallagher et al. 2000,
  n = 1,626, white / African American / Asian, 4-compartment model and DXA).
  *[primary-source verified 2026-08-01]*

### BMI's meaning shifts with ancestry [Established]

A WHO expert consultation found "the proportion of Asian people with a high risk
of type 2 diabetes and cardiovascular disease is substantial at BMIs lower than
the existing WHO cut-off point for overweight (≥25 kg/m²)", that "the cut-off
point for observed risk varies from 22 kg/m² to 25 kg/m² in different Asian
populations; for high risk it varies from 26 kg/m² to 31 kg/m²", and — because
the data did not support one replacement number — that "the WHO BMI cut-off
points should be retained as international classifications" alongside additional
public-health action points (WHO Expert Consultation 2004).

**Read that carefully**: the finding is *not* "use 23 instead of 25". It is that
a single global cutoff carries different risk in different populations and that
no clean population-specific replacement exists. A coach that quotes one
threshold as if it were universal is misreading the source.

### The field has moved past BMI-alone [Established]

- "Despite decades of unequivocal evidence that waist circumference provides
  both independent and additive information to BMI for predicting morbidity and
  risk of death, this measurement is not routinely obtained in clinical
  practice" (Ross et al. 2020, IAS/ICCR Consensus Statement).
- Across 31 papers and more than 300,000 adults, waist-to-height ratio "had
  significantly greater discriminatory power compared with BMI"; WC improved
  discrimination of adverse outcomes "by 3% (P < 0.05)" and WHtR "by 4–5% over
  BMI (P < 0.01)" (Ashwell et al. 2012). The improvement is real and **modest** —
  say "adds information", not "replaces".
- The 2025 Lancet Diabetes & Endocrinology Commission: "Current BMI-based
  measures of obesity can both underestimate and overestimate adiposity and
  provide inadequate information about health at the individual level", and
  "BMI should be used only as a surrogate measure of health risk at a population
  level, for epidemiological studies, or for screening purposes, rather than as
  an individual measure of health" (Rubino et al. 2025).
  *[primary-source verified 2026-08-01]*

### Self-reported weight is biased [Established]

A systematic review of 64 studies of adults: "the data show trends of
under-reporting for weight and BMI and over-reporting for height, although the
degree of the trend varies for men and women and the characteristics of the
population being examined. Standard deviations were large indicating that there
is a great deal of individual variability in reporting of results" (Connor
Gorber et al. 2007). The review could not pool the numbers ("Combining the
results quantitatively was not possible because of the poor reporting of
outcomes of interest"), so **the direction is established and the magnitude is
not** — do not quote a correction factor.

### Weighing has a psychological cost for some people [Probable]

In a randomised trial of 69 university women aged 18–22 assigned to daily
self-weighing or a temperature-taking control, "Negative affective lability was
significantly greater for SW versus TT", "weight-related stress was
significantly higher and body satisfaction was significantly lower
post-behavior for SW but not TT", and the authors conclude "Caution is advised
when recommending self-weighing to prevent weight gain for emerging adults"
(Pacanowski et al. 2023). Separately, a review argues weight stigma "is harmful
to health, over and above objective body mass index" and "begets heightened risk
of obesity through multiple obesogenic pathways" (Tomiyama et al. 2018 — an
Opinion/review article, hence Probable, not Established).

## How we compute it

- **`weight_kg`** — read verbatim from the owner's manual entry into
  `weight_log`, deduped to one row per local day and only rewritten when the
  value changed by more than 0.01 kg (`ingest/upsert.py::upsert_weight`).
  Plausibility filter `value > 30 AND value < 250` (`analytics/metrics.py`).
  **We derive nothing from it directly — no trend, no baseline, no BMI metric.**
- **BMI** — `weight_kg / (height_cm/100)²`, computed inside
  `derive/vo2max.py` only, from the weight logged **on or before** the day being
  derived (`derive/_common.py::_weight_as_of`), so a new entry never rewrites
  past days. That weight must be **within 14 days** of the day being derived, or
  the VO₂max estimate is withheld outright — see "Freshness" below.
- **Downstream** — BMI enters Jurca at `−0.17 METs per BMI unit`
  ([[non_exercise_vo2max]]), and weight enters Mifflin-St Jeor at `10 kcal/kg/day`
  ([[energy_expenditure_derivation]]). See the implementation section for what a
  wrong weight actually costs.

## How the coach uses it

- **Never read a single weigh-in as a change.** Two readings a few days apart
  differing by less than the noise floor (~0.5–0.6 kg, Cheuvront 2004 / Kutáč
  2015) are the same reading.
- **Frame weight against the person's own trend**, not a population ideal. We
  have no validated personal target and no body-composition measurement to make
  one from.
- **Never call BMI body fat.** If BMI comes up — because it is an input to the
  VO₂max estimate — say what it is: a mass-for-height ratio the model was
  calibrated on, which cannot see muscle.
- **Never infer body composition.** "You've lost fat", "you've gained muscle",
  "that's water weight" are all claims about a quantity we do not measure. The
  honest sentence is *short-term weight change is mostly not fat* — cite this
  note, and say it as a statement about the population, not a reading of this
  person's body.
- **Do not moralise.** Weight is a measurement, not a behaviour and not a moral
  outcome. No praise for a drop, no disappointment at a rise, no unsolicited
  weight-loss framing.
- If the owner asks about body composition, waist, or body-fat percentage:
  **say we do not measure it**, and say what would (a tape measure, a DXA scan).

## Safety bounds

- **Never present a weight, BMI or weight change as a diagnosis, a disease
  classification, or a risk number.** The Lancet Commission's whole point is
  that BMI is not an individual-level health measure; we hold to that.
- **Never prescribe a weight target, a calorie deficit, or a rate of loss.**
  We are not a weight-management product and have no dietary intake data.
- **Never initiate a weight-loss conversation the owner did not ask for.**
  Unsolicited weight framing is where a health companion does harm
  (Pacanowski et al. 2023; Tomiyama et al. 2018).
- If an owner discloses disordered eating, or asks us to help them restrict,
  we do not coach it — that is a clinician's ground.

## Honesty & uncertainty

- **We have self-reported, manually logged weight only.** No smart scale, no
  enforced timing, no standardisation of clothing, hydration or time of day.
  Every fluctuation figure quoted above comes from **standardised** first-morning
  measurement; an unstandardised weigh-in is noisier than any of them, by an
  amount we cannot quantify. Data confidence for `weight_kg` is therefore low by
  construction and its cadence is whatever the owner chose.
- **Self-report is biased downward** (Connor Gorber 2007) and the magnitude is
  unpooled — so we cannot correct for it, only name it.
- **Stale weight is no longer used as current weight for BMI — but it still is
  for BMR.** Since 2026-08-01 a weight more than 14 days from the day being
  computed withholds the VO₂max estimate (and therefore the biological age)
  rather than anchoring it. `derive/energy.py` is deliberately unchanged: a
  kilogram of weight error is ~10 kcal/day of BMR, far inside the MET model's own
  error, and refusing a whole day's calorie total over it would be a refusal no
  evidence asked for. So a calorie number can still rest on an old weight, and
  the coach must not describe it as if the weight behind it were fresh.
- **The 14-day horizon is a judgement, not a finding.** No study we could verify
  says when a weight stops describing a person. It is anchored to the longest
  elapsed interval for which this note holds a *measured* drift figure (Bhutani
  2017's two weeks, where the drift is smaller than the weigh-in noise floor);
  past that we have no number, and the product's rule at the edge of the evidence
  is to refuse. Widening it needs evidence, not a product argument.
- **Every fluctuation cohort we verified was male.** Cheuvront: 65 men. Kutáč:
  86 men. Schneditz: one man. Bhutani's combined cohort included women but
  reports composition, not a daily-variability figure. We therefore state the
  daily-swing magnitude as a men's figure and do not extend it.
- **We could not source a menstrual-cycle weight magnitude.** The best study we
  found tracked *self-reported* fluid-retention scores across 765 cycles in 62
  women — peaking on the first day of flow (White et al. 2011) — not measured
  body mass. So: cycle-related fluid shifts are real and reported, and **we have
  no kilogram figure for them**. Do not invent one.
- **We could not source "how many days until a trend is real."** The literature
  gives a noise floor, not a validated detection window. Kutáč's rule — only a
  change exceeding the weekly typical error (0.6 kg) is provable — is the closest
  citable thing, and it is a within-week rule from one cohort. The ≥2-week
  rolling-mean comparison we recommend below is **practitioner consensus**, built
  on the sourced noise floor, not a finding.
- **BMI in our VO₂max estimate is a known, uncorrected structural error.**
  Jurca sees mass-for-height, so a muscular person and a fatter person of the
  same height and weight get the **same** estimate. No flag catches this; the
  only guard is the validated-range check (BMI 16–45,
  `read/vo2max.py::out_of_range_inputs`), which is about the model's calibration
  range, not about composition.
- **Weight is not a health outcome we track.** We surface it because it is an
  input to other models. Nothing in this corpus supports us telling anyone what
  their weight should be.

## Bottom line

**Act on confidently:** a scale reading is a mass measurement, not a fat
measurement; the normal day-to-day swing is around half a kilogram in
standardised conditions; two weeks of weight change is ~84% fat-free mass; BMI
misses about half of the people with excess body fat and cannot see muscle; we
measure no body composition at all.

**Hold loosely:** the exact daily-swing magnitude for any individual (male
cohorts only, standardised conditions only, and our data is neither); any
population BMI threshold as a personal statement; and the length of window over
which a personal weight trend becomes trustworthy — we have the noise floor,
not the window.

## Coach Directives

1. **Never read a single weigh-in, or a gap between two readings smaller than
   ~0.6 kg, as a change in the person's body.** Origin: Cheuvront et al. 2004
   ("Group daily variation in BM was 0.51 ± 0.20 kg") and Kutáč 2015 ("take as
   provable change … only the ones whose values exceed the value of a weekly
   TE" — TE for body mass 0.6 kg). *(confidence: high)*
   *[primary-source verified 2026-08-01]*
2. **Never call BMI body fat, and never state a BMI category as a health
   verdict about this person.** Origin: Okorodudu et al. 2010 (pooled
   sensitivity 0.50) and Rubino et al. 2025 ("BMI should be used only as a
   surrogate measure of health risk at a population level … rather than as an
   individual measure of health"). *(confidence: high)*
3. **Never infer body composition, fat loss, muscle gain, or "water weight" for
   this person — we do not measure any of it.** The population fact ("two-week
   weight change is largely fat-free mass", Bhutani et al. 2017) may be offered
   as context, explicitly as a population fact, never as a reading of their
   body. *(confidence: high)*
4. **Frame weight against the person's own trend, never a population ideal, and
   never propose a target weight, a deficit, or a rate of loss.** Origin: Rubino
   et al. 2025 (BMI is not an individual health measure) plus the fact that we
   hold no intake data — there is nothing to prescribe from.
   *(confidence: high)*
5. **Do not moralise about weight, and never open a weight-loss topic the owner
   did not raise.** Origin: Pacanowski et al. 2023, RCT — daily self-weighing
   significantly raised negative affective lability and weight-related stress
   and lowered body satisfaction; Tomiyama et al. 2018 (Opinion review) —
   weight stigma is "harmful to health, over and above objective body mass
   index". Reinforced by `docs/COACH_PROMPT.md` ("Meet the person where they
   are"). *(confidence: moderate — the stigma evidence is an opinion review;
   the self-weighing harm is a single small RCT)*
6. **Say plainly that our weight is self-reported and manually logged whenever
   weight is used to justify anything — and name its date when it has one.**
   Origin: Connor Gorber et al. 2007 (self-report under-reports weight, magnitude
   unpooled). Since #85 the payloads carry `as_of_date`, so "your weight" is
   always sayable as "the 79.9 kg you logged on the 4th". A weight-derived number
   that survives the freshness gate is still not a fresh *measurement*: calories
   in particular can rest on a weight up to a year old. *(confidence: high)*
7. **When comparing weight over time, compare rolling means at least two weeks
   apart, never endpoints.** *(confidence: Emerging / practitioner consensus —
   derived from the sourced noise floor (Cheuvront 2004; Kutáč 2015; Bhutani's
   2-week change SD of 1.2 kg); no study we could verify validates a specific
   detection window.)*

## References

- Bhutani S, Kahn E, Tasali E, Schoeller DA. *Composition of two-week change in
  body weight under unrestricted free-living conditions.* Physiol Rep
  2017;5(13):e13336. doi:10.14814/phy2.13336. PMID 28676555. n = 46 across two
  cohorts; TBW by stable-isotope dilution and serial DXA. Source of the 84%-FFM
  figure, the 0.26 ± 1.2 kg two-week change, and the 2380 kcal/kg energy density.
- Toomey CM, McCormack WG, Jakeman P. *The effect of hydration status on the
  measurement of lean tissue mass by dual-energy X-ray absorptiometry.* Eur J
  Appl Physiol 2017;117(3):567–574. doi:10.1007/s00421-017-3552-x.
  PMID 28204901. n = 12; the controlled ±2 kg body-mass swing with **no fat-mass
  change**.
- Cheuvront SN, Carter R 3rd, Montain SJ, Sawka MN. *Daily body mass variability
  and stability in active men undergoing exercise-heat stress.* Int J Sport Nutr
  Exerc Metab 2004;14(5):532–540. doi:10.1123/ijsnem.14.5.532. PMID 15673099.
  n = 65 men; source of 0.51 ± 0.20 kg and CV 0.66 ± 0.24%.
- Kutáč P. *Inter-daily variability in body composition among young men.*
  J Physiol Anthropol 2015;34(1):32. doi:10.1186/s40101-015-0070-6.
  PMID 26395170. n = 86 men, Mon–Fri; source of the 0.6 kg typical error of
  measurement and the "provable change" rule.
- Schneditz D, Hofmann P, Krenn S, Waller M, Mussnig S, Hecking M. *Day-to-day
  variability in euvolemic body mass.* Ren Fail 2023;45(2):2273421.
  doi:10.1080/0886022X.2023.2273421. PMID 37955103. **n = 1** (9,521 days);
  carried as corroboration of magnitude only, never as a population figure.
- Fernández-Elías VE, Ortega JF, Nelson RK, Mora-Rodriguez R. *Relationship
  between muscle water and glycogen recovery after prolonged exercise in the
  heat in humans.* Eur J Appl Physiol 2015;115(9):1919–1926.
  doi:10.1007/s00421-015-3175-z. PMID 25911631. n = 9; the 1 g glycogen : 3 g
  water ratio, measured by biopsy.
- Kreitzman SN, Coxon AY, Szaz KF. *Glycogen storage: illusions of easy weight
  loss, excessive weight regain, and distortions in estimates of body
  composition.* Am J Clin Nutr 1992;56(1 Suppl):292S–293S.
  doi:10.1093/ajcn/56.1.292S. PMID 1615908.
- Okorodudu DO, Jumean MF, Montori VM, et al. *Diagnostic performance of body
  mass index to identify obesity as defined by body adiposity: a systematic
  review and meta-analysis.* Int J Obes (Lond) 2010;34(5):791–799.
  doi:10.1038/ijo.2010.5. PMID 20125098. 25 articles, 32 samples, n = 31,968.
- Ode JJ, Pivarnik JM, Reeves MJ, Knous JL. *Body mass index as a predictor of
  percent fat in college athletes and nonathletes.* Med Sci Sports Exerc
  2007;39(3):403–409. doi:10.1249/01.mss.0000247008.19127.3e. PMID 17473765.
  n = 439; BOD POD reference.
- Gallagher D, Heymsfield SB, Heo M, Jebb SA, Murgatroyd PR, Sakamoto Y.
  *Healthy percentage body fat ranges: an approach for developing guidelines
  based on body mass index.* Am J Clin Nutr 2000;72(3):694–701.
  doi:10.1093/ajcn/72.3.694. PMID 10966886. n = 1,626, three ethnic groups.
- WHO Expert Consultation. *Appropriate body-mass index for Asian populations
  and its implications for policy and intervention strategies.* Lancet
  2004;363(9403):157–163. doi:10.1016/S0140-6736(03)15268-3. PMID 14726171.
- Rubino F, et al. *Definition and diagnostic criteria of clinical obesity.*
  Lancet Diabetes Endocrinol 2025;13(3):221–262.
  doi:10.1016/S2213-8587(24)00316-4. PMID 39824205. Commission report.
- Ross R, Neeland IJ, Yamashita S, et al. *Waist circumference as a vital sign
  in clinical practice: a Consensus Statement from the IAS and ICCR Working
  Group on Visceral Obesity.* Nat Rev Endocrinol 2020;16(3):177–189.
  doi:10.1038/s41574-019-0310-7. PMID 32020062. Consensus statement, not a
  meta-analysis.
- Ashwell M, Gunn P, Gibson S. *Waist-to-height ratio is a better screening tool
  than waist circumference and BMI for adult cardiometabolic risk factors:
  systematic review and meta-analysis.* Obes Rev 2012;13(3):275–286.
  doi:10.1111/j.1467-789X.2011.00952.x. PMID 22106927. 31 papers, >300,000
  adults.
- Connor Gorber S, Tremblay M, Moher D, Gorber B. *A comparison of direct vs.
  self-report measures for assessing height, weight and body mass index: a
  systematic review.* Obes Rev 2007;8(4):307–326.
  doi:10.1111/j.1467-789X.2007.00347.x. PMID 17578381. 64 studies; **results
  could not be pooled** — direction only.
- Pacanowski CR, Dominick G, Crosby RD, Engel SG, Cao L, Linde JA. *Daily
  self-weighing compared with an active control causes greater negative
  affective lability in emerging adult women: a randomized trial.* Appl Psychol
  Health Well Being 2023;15(4):1695–1713. doi:10.1111/aphw.12463.
  PMID 37339756. n = 69, 2 weeks; small and in one narrow population.
- Tomiyama AJ, Carr D, Granberg EM, et al. *How and why weight stigma drives the
  obesity 'epidemic' and harms health.* BMC Med 2018;16(1):123.
  doi:10.1186/s12916-018-1116-5. PMID 30107800. **Opinion/review article** — not
  a systematic review; carried as Probable.
- White CP, Hitchcock CL, Vigna YM, Prior JC. *Fluid retention over the
  menstrual cycle: 1-year data from the prospective ovulation cohort.* Obstet
  Gynecol Int 2011;2011:138451. doi:10.1155/2011/138451. PMID 21845193. 765
  cycles in 62 women — **self-reported** fluid-retention scores, **not measured
  body mass**; cited only to say we have no kilogram figure.

## Healthee implementation & honesty policy

- **Metric: `weight_kg`**, stored in `weight_log` (not `derived_daily`), written
  by `ingest/upsert.py::upsert_weight` from the owner's manual profile entry —
  one row per local day, updated only when the value moved by >0.01 kg.
  Plausibility filter `value > 30 AND value < 250` (`analytics/metrics.py`).
- **No derived weight metric exists.** `read/today_series.py::_weight_card`
  surfaces the single latest logged value with `median_30d: None`, `z: None`,
  `anomalous: False` — there is no baseline, no trend and no rolling mean for
  weight anywhere in the server today. Until one exists, **the coach must not
  speak about a weight trend as if the product computed one.** The card now also
  carries `as_of_date`, and past 14 days its `value` is `null` with a `withheld`
  block holding the last reading.
- **Three models consume weight, and each inherits its error:**
  - `derive/vo2max.py` — BMI at **−0.17 METs per BMI unit** (×3.5 →
    ≈ −0.6 mL/kg/min per BMI unit). *Our arithmetic, not a cited figure*: at
    1.75 m, a 1 kg weight error is ≈0.33 BMI units ≈ 0.2 mL/kg/min — small next
    to Jurca's own SEE of 5.6 mL/kg/min. The error that matters is **structural,
    not numeric**: BMI cannot see composition, so two people of identical
    mass-for-height and opposite body composition receive the same estimate.
  - `derive/energy.py` — Mifflin-St Jeor at **10 kcal/kg/day**, so a 1 kg weight
    error is ≈10 kcal/day of BMR, and BMR anchors the whole MET-by-state TEE.
    *Our arithmetic from the code constant.*
  - [[biological_age_estimate]] — indirectly, because `vo2max_estimate` is its
    dominant term. A weight error propagates two models deep.
- **Freshness (fixed 2026-08-01, #85).** `derive/_common.py::_weight_as_of` takes
  the most recent entry on or before the derived day, falling back to the
  *earliest* logged weight for days before the first entry. It now returns the
  weight's **log date** alongside the value, and `derive/freshness.py` holds the
  one rule — `weight_is_stale`, horizon `WEIGHT_MAX_AGE_DAYS = 14`, measured as an
  absolute distance so a weight logged long *after* a day is equally rejected for
  it. Consumers, deliberately not the loader, decide what to do:
  - `derive/vo2max.py` **withholds** (no row written), so
    `analytics/biological_age.py` withholds the whole composite through the gate
    it already shares.
  - `read/today_series.py::_weight_card` nulls its `value` and returns a
    `withheld` block; `read/history.py::profile` keeps the value (it restores a
    reinstall) and dates it.
  - `derive/energy.py` is unchanged — see the Honesty section.
- **The weight's age was previously unmeasurable, and that was the real defect.**
  The app re-pushes its cached weight on every sync and `/api/profile` hands it
  straight back, so `ingest/upsert.py::upsert_weight` — which deduped only within
  a local day — inserted the same value at `now()` each new day. Measured in the
  2026-07-15 production dump: 41 `weight_log` rows over six weeks, all 79.9 kg but
  one, from an owner who weighed themselves about twice. A weight could therefore
  never *look* older than a day and no freshness gate could have fired. It now
  writes a row only when the value actually changed.
- **Honesty rules (binding):**
  - Never present `weight_kg` as a body-fat or body-composition measurement.
  - Never present BMI as a health verdict or a diagnosis; it is an input to a
    model, and this note is what the ⓘ sheet must show when it appears.
  - Never show a weight target, a calorie deficit, or a rate of loss.
  - Never open a weight topic the owner did not open.
  - When weight is used to justify a number, say it is self-reported, manually
    logged, and possibly stale.
