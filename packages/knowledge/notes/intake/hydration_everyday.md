---
id: hydration_everyday
name: "Everyday hydration (non-exercise)"
topic: There is no evidence-based universal daily water target for a healthy adult; what the reference values actually are, what counts, and that we measure none of it
category: intake
grade: Probable
safety_critical: [5, 6]     # → hard guardrails `hydration_everyday_D5`/`_D6`
summary: "Caffeinated drinks count toward fluid intake, with a crossover trial showing coffee at 4 mg/kg/day matched water on total body water and urine volume (Killer 2014, n = 50 men). Published reference values (EFSA: 2.5 L/day men, 2.0 L/day women) are TOTAL water including the water in food, derived from observed intakes rather than a measured requirement. Dehydration past ~2% body-mass loss does measurably dent attention and executive function (pooled ES −0.28). Healthee measures no hydration at all — no fluid log, no urine marker, no sweat rate. The '8 glasses a day' question is a separate, Myth-graded topic and lives in [[hydration_8x8_rule]] — cite that note for it, never this one."
aliases: ["hydration", "hydrated", "water", "drinking water", "water intake", "how much water", "how much water should i drink", "fluid intake", "fluids", "drink more water", "dehydration", "dehydrated", "thirst", "urine colour", "urine color"]
applies_to_metrics: []
applies_to_interventions: []
population: general
last_reviewed: 2026-08-01
related: ["hydration_8x8_rule", "fueling_and_hydration", "caffeine_sleep", "alcohol_sleep", "weight_bmi_body_composition"]
tags: [hydration, water, intake, honesty]
---

# Everyday hydration (non-exercise)

## Summary

This note covers **ordinary daily hydration in a healthy adult** — the "should I be
drinking more water?" question. It deliberately does **not** cover hydration during
exercise, in heat, or the hyponatremia safety ground: [[fueling_and_hydration]]
owns all of that, including the drink-to-thirst default and the
exercise-associated-hyponatremia guardrail. Nothing here restates, softens or
extends those rules.

Three things are worth saying plainly and one thing is worth saying loudly.

1. **The "eight 8-oz glasses a day" question belongs to [[hydration_8x8_rule]]**, which
   is graded `Myth` and states the correction, both of Valtin's own insisted limitations,
   and the "absence of evidence is not proof of absence" framing in full. It is not
   restated here, and citing THIS note for it makes the validator demand a `Probable`
   hedge on a claim the evidence supports flatly — the exact failure #91 closed.
   *(Corrected 2026-09-08: the correction was still stated here, and in the frontmatter
   summary and the Bottom line, sixty lines above this note's own record that it "simply
   stopped being the one that states it".)*
2. **Caffeinated drinks count.** Coffee at 4 mg/kg caffeine per day was
   indistinguishable from water on total body water (51.5 ± 1.4 vs 51.4 ± 1.3 kg)
   and on 24-h urine volume (2409 ± 660 vs 2428 ± 669 mL) across three days
   (Killer et al. 2014, n = 50 habitual male coffee drinkers).
3. **The published reference values are not requirements.** EFSA's Adequate Intake
   for adults is **2.5 L/day for men and 2.0 L/day for women**, and that is *total*
   water — it "includes water from beverages of all kind, including drinking and
   mineral water, **and from food moisture**". It was derived from observed intakes
   in populations, not from a demonstrated physiological requirement.

And the loud thing: **Healthee measures no hydration whatsoever.** There is no
fluid log, no urine marker, no plasma osmolality, no sweat-rate estimate, and no
`manual_entry` kind for water. Any hydration statement we make is general
physiology, never a reading of this person.

## What it is

- **Total water intake** — all water entering the body: drinking water, every other
  beverage, and the water contained in food. This is the quantity reference values
  are stated in, and quoting one as if it meant "glasses of plain water" inflates
  it substantially.
- **Euhydration / hypohydration** — being at, or below, the body's regulated water
  content. Measured properly by plasma osmolality, isotope-dilution total body
  water, or acute body-mass change; approximated in the field by urine
  concentration.
- **Thirst** — the sensation driven by plasma osmolality, and the mechanism the
  osmoregulatory system uses to defend water balance.

We hold **none** of these quantities.

## Physiology / mechanism

Body water is defended by osmoregulation, not by intake bookkeeping. A rise in
plasma osmolality triggers both vasopressin release (renal water conservation, so
urine concentrates) and thirst (intake). Valtin's core argument is that this
system is good at its job — his conclusion rests in part on "the large body of
published experiments that attest to the precision and effectiveness of the
osmoregulatory system for maintaining water balance" — which is why a healthy adult
in a temperate climate does not need an intake rule to stay in balance, and why
drinking beyond need mostly produces dilute urine rather than better hydration.

The diuretic effect of caffeine is real acutely but does not produce a net fluid
deficit at habitual moderate doses, which is what Killer et al. measured directly.

## The evidence

### "8 × 8" is not supported by evidence → **[[hydration_8x8_rule]]** owns this

**Moved out of this note 2026-08-01 (#91), not softened or dropped.** The Valtin 2002
finding, both of its author-insisted limitations, and the "absence of evidence, not
proof of absence" framing all live in [[hydration_8x8_rule]] in full. Nothing was
lost; this note simply stopped being the one that states it.

*Why:* a note carries exactly one `grade` and this one is `Probable`. A `[Myth]`
claim sitting inside it shipped under the Probable badge, so `insights/validator.py`
asked only for a **hedge** — and "8×8 *may* not be necessary" is the wrong framing
twice over: it softens a correction the evidence supports flatly, and it lends a
refuted claim the shape of thin-but-real evidence. `Myth` is the grade whose required
framing is a *correction*, and the only way the validator can require that is for the
claim to be cited from a note graded `Myth`. So the claim moved to a note that is.

**This note's id, aliases, and both SAFETY-CRITICAL directives (D5, D6) are
unchanged** — the compiled hydration guardrails in `insights/guard_directives.py` are
untouched by the split. Only the myth-specific aliases ("8x8", "8 glasses", …) moved,
so that the myth question routes to the note graded to answer it.

The one-line version, for context here: a search of the peer-reviewed literature,
older non-indexed literature and specialists in thirst and drinking found no
scientific studies supporting 8 × 8 — for **healthy adults in a temperate climate
leading a largely sedentary life**, with larger intakes explicitly advisable in
illness and in vigorous work or heat [[hydration_8x8_rule]].

### Caffeinated drinks count toward fluid intake [Probable]

Killer et al. 2014 (*PLoS One*): 50 male habitual coffee drinkers (3–6 cups/day),
counterbalanced crossover, two 3-day trials of 4 × 200 mL coffee providing 4 mg/kg
caffeine/day versus water. Total body water by deuterium-oxide dilution was
**51.5 ± 1.4 vs 51.4 ± 1.3 kg** (coffee vs water); 24-h urine volume
**2409 ± 660 vs 2428 ± 669 mL**. No hydration biomarker differed. Authors:
"These data suggest that coffee, when consumed in moderation by caffeine
habituated males provides similar hydrating qualities to water."

Graded **Probable, not Established**: a single well-controlled crossover, **men
only**, all of them **habituated** to caffeine, at a moderate dose. Valtin 2002
reached the same conclusion from the earlier literature, including that "mild
alcoholic beverages like beer in moderation" may also count — but read that as a
statement about *fluid balance only*; [[alcohol_sleep]] owns what alcohol does to
sleep and overnight autonomics and nothing here softens it.
*[full text verified via PMC 2026-08-01, PMC3886980]*

### The published intake numbers are reference values, not requirements [Probable]

EFSA's Adequate Intakes for total water, adults aged ≥18: **2.5 L/day (M) and
2.0 L/day (F)**, with the footnote that this "includes water from beverages of all
kind, including drinking and mineral water, and from food moisture". Pregnancy
2.3 L/day, lactation 2.7 L/day.

The derivation matters more than the number. An **Adequate Intake** in the EFSA
framework is what is set precisely when a requirement cannot be established; these
values come from observed intakes in populations judged to have acceptable urine
concentration, not from an experiment establishing how much water a person needs.
So they describe what people who appear fine already drink. Quoting "2.5 litres"
as a target to hit — and especially as *plain water* to hit — misreads the source
twice over.

*[Verification note: the AI values and the "includes … food moisture" footnote were
read directly from EFSA's own "Summary of Dietary Reference Values – version 4
(September 2017)", Table 3. The 2010 opinion itself (EFSA Journal 8(3):1459) was
paywalled to us. Its abstract is widely quoted as adding that the values apply
"to conditions of moderate environmental temperature and moderate physical
activity levels (PAL 1.6)" — **we could not verify that condition at primary
source and therefore do not assert it**, though it is consistent with Valtin's own
temperate-and-sedentary limitation.]*

### Dehydration does impair cognition, modestly, past ~2% body mass [Probable]

Wittbrodt & Millard-Stafford 2018 (*Med Sci Sports Exerc*), 33 studies, 280 effect
sizes, 413 subjects, dehydration 1–6% body-mass loss:

- All domains pooled: **ES −0.21 (95% CI −0.31 to −0.11), P < 0.0001** — the
  authors call this "small but significant", with substantial heterogeneity.
- Attention **−0.52 (−0.66 to −0.37)**; motor coordination **−0.40 (−0.63 to
  −0.17)**; executive function **−0.24 (−0.37 to −0.12)**; reaction-time-specific
  tasks **−0.10 (−0.23 to 0.02)** — i.e. not significant.
- Dose: **>2% body-mass loss ES −0.28 (−0.41 to −0.16)** versus **≤2% ES −0.14
  (−0.27 to 0.00)**, P = 0.04 for the difference.

Conclusion: "DEH impairs cognitive performance, particularly for tasks involving
attention, executive function, and motor coordination when water deficits exceed
2% BML."

The honest reading: this is about **deliberately dehydrated** subjects, most of
them dehydrated by exercise or heat, at deficits a person at a desk does not
casually reach. It is not evidence that a mildly thirsty office worker is
cognitively impaired, and it is certainly not evidence that drinking extra water
above euhydration improves anything.
*[full abstract verified at PubMed 2026-08-01, PMID 29933347]*

## How we compute it

**Nothing.** There is no hydration metric, no fluid log and no derived field.
`manual_entry` is written through **`POST /api/log`** (singular — `api/routers/logs.py:18`), whose wire field is **`type`**, not `kind`, and whose value must be one of a **10-value allowlist** (`read/logs.py:20-23`: caffeine, alcohol, water, food, med, symptom, mood, habit, meditation, exercise) — not an arbitrary string. *(Corrected 2026-09-08: this said "arbitrary `kind` via `/api/logs`". The substance below is unaffected — both `water` and `food` are on the allowlist — but three details of the endpoint were wrong.)* But the kinds the analytics layer actually evaluates are fixed —
`analytics/metrics.py::EVENT_KINDS` = alcohol, caffeine, meditation, exercise,
fasting — so even a hand-written "water" log would correlate against nothing.

The only fluid-adjacent number in the product is `weight_kg`, and its water content
is a **confounder there**, not a hydration measurement;
[[weight_bmi_body_composition]] owns that and this note does not restate its
figures.

## How the coach uses it

- **Never tell the owner they are dehydrated.** We cannot know. Not from HRV, not
  from resting heart rate, not from weight, not from anything we hold.
- **If asked how much water to drink**: say the honest thing — there is no
  evidence-based universal number for a healthy adult, the published reference
  values are total water including food and are derived from observed intakes, and
  the body regulates this well. Then hand the specifics back to them or a
  clinician.
- **Correct "8 glasses" gently and once.** It is a common belief, not a character
  flaw. Give the correction with its source and its limits (healthy adults,
  temperate climate, sedentary), never as a licence to drink less in heat or during
  exercise.
- **Do not tell anyone that coffee or tea dehydrates them.** At habitual moderate
  intake this is not supported. This is a fluid-balance statement only — it says
  nothing about caffeine and sleep, which is [[caffeine_sleep]]'s ground.
- **Never attribute a metric movement to hydration.** A low HRV morning, a high
  resting heart rate, a poor night — we have no sourced basis to blame any of them
  on water intake (see Honesty).
- **Any exercise-, heat- or endurance-context hydration question defers entirely to
  [[fueling_and_hydration]].** Do not answer it from this note.

## Safety bounds

- **"Drink more water" is not a universally safe suggestion.** Excess fluid intake
  is the proximate cause of exercise-associated hyponatremia, which can be fatal.
  The guardrail lives in [[fueling_and_hydration]] (its D8/D12) and this note must
  never restate it loosely, dilute it, or generate hydration advice that bypasses
  it. **SAFETY-CRITICAL** — see Coach Directive 5.
- **Never advise a fluid target to anyone who mentions a kidney, heart or liver
  condition, or a fluid restriction.** Fluid intake is a prescribed quantity in
  those conditions and getting it wrong is dangerous in both directions. Route to
  their clinician. **SAFETY-CRITICAL** — see Coach Directive 6.
- Never present thirst, urine colour or any hydration heuristic as a diagnosis.

## Honesty & uncertainty

- **We measure nothing.** No fluid intake, no urine concentration or colour, no
  plasma osmolality, no sweat rate, no body-mass change protocol. This is the
  single most important sentence in the note.
- **We could not source any link between everyday hydration and the metrics we
  actually compute.** We looked specifically for a primary source giving a
  magnitude for how hydration status moves overnight HRV or resting heart rate. The
  literature we found is post-exercise-heat-stress designs in small samples, and we
  did **not** verify any of it at primary source. So: **no figure, no direction, no
  claim.** If the coach wants to explain an HRV dip, hydration is not an
  explanation this corpus can support.
- **The caffeine result is in men only, all habituated, at one moderate dose.**
  Killer et al. tested 4 mg/kg/day in habitual 3–6-cup drinkers. It does not license
  a claim about a non-habituated person, a very high dose, or women.
- **Valtin's finding is an absence of evidence, and he says so.** "Since it is
  difficult or impossible to prove a negative … the author invites communications
  from readers who are aware of pertinent publications." The paper is also from
  2002; we did not search for post-2002 work that might have supplied the missing
  evidence, and that is a real limitation of this note.
- **The EFSA numbers were verified in EFSA's summary tables, not in the 2010
  opinion**, which was paywalled to us. The temperature/activity conditions
  commonly quoted alongside them are **not verified** here and are not asserted.
- **The cognition meta-analysis studied induced dehydration**, mostly by exercise
  or heat, at 1–6% body-mass loss, with high heterogeneity and a small pooled
  effect. Nothing in it supports "drink more water to think better" in a
  euhydrated person — the studies compared dehydrated against euhydrated, not
  euhydrated against over-hydrated.
- **We have no evidence base for urine colour charts**, "drink before you're
  thirsty", pre-loading water in the morning, electrolyte supplementation outside
  exercise, or any of the popular hydration heuristics. We did not verify sources
  for them and we make no claim either way.
- **Individual requirement genuinely varies** with climate, activity, body size,
  diet (a high-water-content diet supplies far more), medication and health
  conditions. No population number describes an individual.
- **Age is a known gap.** Thirst sensitivity declines with age and older adults are
  the group most often flagged clinically for under-drinking; we found and verified
  no primary source for that here, so we state it as a gap rather than a finding.

## Bottom line

**Act on confidently:** caffeinated drinks count toward fluid intake; the published reference values are
total water including food, not plain-water targets; and we measure nothing about
this person's hydration.

**Hold loosely:** how much any individual actually needs; whether mild everyday
under-drinking has any consequence worth acting on; and any connection between
hydration and the metrics Healthee computes — for which we have no source at all.

## Coach Directives

1. Never state or imply that the owner is dehydrated, or attribute any metric
   movement to hydration. We hold no hydration data and no sourced link to any
   metric we compute. *(confidence: high)*
2. When asked "how much water should I drink", answer that there is no
   evidence-based universal number for a healthy adult, name the reference value
   *as total water including food* if a number is wanted, and say the body
   regulates this well. Never prescribe a personal litre target.
   *(confidence: high)*
3. Answer "8 glasses a day" from **[[hydration_8x8_rule]]**, which owns that
   correction and is graded `Myth` so the framing is enforced (#91). Do not restate
   it from here. Whichever note it comes from, the correction never travels without
   Valtin's two limits and never discourages drinking in heat, illness or exercise.
   *(confidence: high)*
4. Do not claim coffee or tea dehydrates at habitual moderate intake
   (Killer et al. 2014). Keep this strictly to fluid balance and do not let it leak
   into caffeine-and-sleep advice, which is [[caffeine_sleep]]'s. *(confidence:
   moderate — one crossover trial, men only, habituated drinkers)*
5. **SAFETY-CRITICAL:** never generate a scheduled or volume-target hydration
   instruction for exercise or heat from this note. Defer to
   [[fueling_and_hydration]], which owns the exercise-associated-hyponatremia
   guardrail. Excess fluid intake can be fatal. *(confidence: high)*
6. **SAFETY-CRITICAL:** if the owner mentions kidney, heart or liver disease, a
   diuretic, or a prescribed fluid restriction, give no fluid-intake advice at all
   and route to their clinician. *(confidence: high)*

## References

- Valtin H. *"Drink at least eight glasses of water a day." Really? Is there
  scientific evidence for "8 × 8"?* Am J Physiol Regul Integr Comp Physiol
  2002;283(5):R993–R1004. doi:10.1152/ajpregu.00365.2002. PMID 12376390.
  **Review** — source of the "no scientific studies were found in support of 8 x 8"
  finding, the caffeinated/mildly-alcoholic-beverages-count point, the
  osmoregulation argument, and the healthy/temperate/sedentary limitation.
  *[full abstract verified at PubMed 2026-08-01; full text not read]*
- Killer SC, Blannin AK, Jeukendrup AE. *No evidence of dehydration with moderate
  daily coffee intake: a counterbalanced cross-over study in a free-living
  population.* PLoS One 2014;9(1):e84154. doi:10.1371/journal.pone.0084154.
  PMID 24416202. PMC3886980. n = 50 **men**, habitual 3–6 cups/day, 4 mg/kg
  caffeine, deuterium-dilution total body water. Source of the TBW and urine-volume
  figures. *[full text verified via PMC 2026-08-01]*
- Wittbrodt MT, Millard-Stafford M. *Dehydration impairs cognitive performance: a
  meta-analysis.* Med Sci Sports Exerc 2018;50(11):2360–2368.
  doi:10.1249/MSS.0000000000001682. PMID 29933347. 33 studies, 280 effect sizes,
  413 subjects, 1–6% body-mass loss. Source of every effect size quoted here.
  *[full abstract verified at PubMed 2026-08-01; full text not read]*
- EFSA Panel on Dietetic Products, Nutrition and Allergies (NDA). *Scientific
  Opinion on Dietary Reference Values for water.* EFSA Journal 2010;8(3):1459.
  doi:10.2903/j.efsa.2010.1459. **The opinion itself was paywalled to us**; the
  adult Adequate Intakes (2.5 L/day M, 2.0 L/day F) and the "includes water from
  beverages of all kind … and from food moisture" footnote were read from EFSA's
  own *Summary of Dietary Reference Values — version 4 (September 2017)*, Table 3.
  *[verified 2026-08-01 in the EFSA summary tables, not in the primary opinion]*

## Healthee implementation & honesty policy

- **No metric, no derived field, no log kind.** `applies_to_metrics: []` is literal:
  hydration touches nothing we compute. `POST /api/log` will accept a `type` of `"water"`
  (it is on the 10-value allowlist in `read/logs.py:20-23`), but
  `analytics/metrics.py::EVENT_KINDS` evaluates
  only alcohol, caffeine, meditation, exercise and fasting, so such a row would
  correlate against nothing and appear nowhere except the coach's raw
  manual-entries table. **Do not imply we track hydration because a log was
  accepted.**
- **Ownership boundaries (binding, to keep one definition per concept):**
  - Exercise/heat hydration, sweat rate, sodium, and the hyponatremia guardrail →
    [[fueling_and_hydration]]. This note must not restate or extend them.
  - Caffeine's effect on sleep → [[caffeine_sleep]]. This note claims only that
    caffeinated drinks count as fluid.
  - Alcohol's effects → [[alcohol_sleep]]. Valtin's "beer in moderation counts as
    fluid" is a fluid-balance claim and never an endorsement.
  - Water's contribution to scale weight → [[weight_bmi_body_composition]].
- **Honesty rules (binding):**
  - Never call the owner dehydrated or well-hydrated; we have no measurement.
  - Never attribute an HRV, RHR, sleep or recovery movement to hydration — we could
    verify no source linking everyday hydration to any metric we compute.
  - Never prescribe a daily litre target, and never quote a reference value without
    saying it is total water including food.
  - Give no fluid advice at all where a kidney/heart/liver condition, a diuretic or
    a prescribed fluid restriction is mentioned.
