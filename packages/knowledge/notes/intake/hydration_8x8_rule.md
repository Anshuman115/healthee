---
id: hydration_8x8_rule
name: "The \"8 glasses a day\" rule"
topic: The 8x8 water rule has no evidential basis, what Valtin actually searched and found, and the two limits that must travel with the correction
category: intake
grade: Myth
summary: "\"Eight 8-oz glasses of water a day\" has no scientific basis: a search of the peer-reviewed literature, older non-indexed literature and specialists in thirst and drinking found 'no scientific studies were found in support of 8 x 8' (Valtin 2002). Two limits travel with the correction and are not optional — it applies to healthy adults in a temperate climate leading a largely sedentary life, and larger intakes ARE called for in illness and in vigorous work or exercise, especially in the heat."
aliases: ["8x8", "8 x 8", "8 glasses", "eight glasses", "eight glasses of water", "eight 8-oz glasses", "8 glasses a day", "do i need 8 glasses of water", "two litres of water a day", "drink 8 glasses"]
applies_to_metrics: []
applies_to_interventions: []
population: general
last_reviewed: 2026-08-01
related: ["hydration_everyday", "fueling_and_hydration"]
tags: [hydration, water, intake, myth, honesty]
---

# The "8 glasses a day" rule

## Summary

This note exists to hold **one refuted claim** so that it can be cited *as* refuted.
The general question — how much water a healthy adult should drink, what the
published reference values mean, whether caffeinated drinks count — belongs to
[[hydration_everyday]], which is graded `Probable` and which this note does not
restate. Exercise, heat and the hyponatremia guardrail belong to
[[fueling_and_hydration]].

Why it is split out: a note carries one `grade`, and `hydration_everyday` is
`Probable`. A `[Myth]` claim living inside it shipped under a Probable badge, so the
validator asked only for a hedge — and hedging a debunked claim ("8×8 *may* not be
necessary") is the wrong framing twice over. It softens a correction the evidence
supports flatly, and it lends a myth the shape of thin-but-real evidence. Graded
`Myth` here, the correction is what the validator requires (#91).

## What it is

The claim: a healthy adult should drink **eight 8-ounce glasses of water per day**
(≈1.9 L), *in addition to* other beverages, with caffeinated and alcoholic drinks
explicitly not counting toward the total.

Both halves of that claim are part of the myth. The second half — that coffee and
tea don't count — is addressed by [[hydration_everyday]], which carries the primary
trial; this note owns the volume rule itself.

## Physiology / mechanism

There is no mechanism to explain, because there is no requirement to explain. Body
water is defended by **osmoregulation**, not by intake bookkeeping: rising plasma
osmolality triggers both vasopressin release (the kidney conserves water, urine
concentrates) and thirst. Valtin's argument rests in part on "the large body of
published experiments that attest to the precision and effectiveness of the
osmoregulatory system for maintaining water balance" — which is why a healthy adult
in a temperate climate does not need an intake rule to stay in balance, and why
drinking past need mostly produces dilute urine rather than better hydration.

## The evidence

### "8 × 8" is not supported by evidence [Myth]

From Valtin 2002 (*Am J Physiol Regul Integr Comp Physiol*):

> "Despite the seemingly ubiquitous admonition to 'drink at least eight 8-oz
> glasses of water a day' (with an accompanying reminder that beverages containing
> caffeine and alcohol do not count), rigorous proof for this counsel appears to be
> lacking. … No scientific studies were found in support of 8 x 8. Rather, surveys
> of food and fluid intake on thousands of adults of both genders … strongly
> suggest that such large amounts are not needed because the surveyed persons were
> presumably healthy and certainly not overtly ill."

**Two qualifications the author himself insists on, and which must travel with the
claim.** Quoting the correction without them turns a myth-correction into dangerous
advice:

> "It is to be emphasized that the conclusion is limited to healthy adults in a
> temperate climate leading a largely sedentary existence"

> "large intakes of fluid, equal to and greater than 8 x 8, are advisable for the
> treatment or prevention of some diseases and certainly are called for under
> special circumstances, such as vigorous work and exercise, especially in hot
> climates."

**The shape of the finding matters.** This is a **review**, and its central result
is the *absence* of supporting evidence — the author closes by noting it is
"difficult or impossible to prove a negative" and inviting readers to send contrary
publications. That is the honest strength of the claim: nobody has produced the
evidence, not that its absence has been proven. Graded `Myth` because a
widely-repeated numeric prescription with no supporting study is exactly what that
grade is for — the claim is refuted *as a requirement*, not proven harmful.
*[full abstract verified at PubMed 2026-08-01, PMID 12376390]*

## How we compute it

**Nothing.** Healthee measures no hydration at all — no fluid log, no urine marker,
no plasma osmolality, no sweat-rate estimate, and no `manual_entry` kind for water.
[[hydration_everyday]] owns that statement and the detail behind it.

## How the coach uses it

- **Correct it gently and once.** It is a common belief, not a character flaw, and
  the person repeating it is usually trying to look after themselves. Give the
  correction with its source.
- **Never give the correction without both limits.** "There's no evidence for eight
  glasses" is only true for a healthy adult, in a temperate climate, not exerting.
  Said flatly to someone who is ill, working hard, or in the heat, it is a harmful
  sentence. State the limits in the same breath.
- **Do not substitute a different number.** The correct move is not "actually it's
  2.5 litres" — that is a *reference value for total water including food*, and
  quoting it as a plain-water target repeats the same error with better manners.
  [[hydration_everyday]] owns what the published values are and are not.
- **Any exercise-, heat- or endurance-context question defers entirely to
  [[fueling_and_hydration]].** Do not answer it from this note.

## Safety bounds

- **Never let this correction read as a licence to drink less.** Valtin explicitly
  says larger intakes are called for in illness and in vigorous work or heat. A
  myth-correction that discourages drinking in those settings is worse than the myth.
- **Give no fluid advice at all** where a kidney, heart or liver condition, a
  diuretic, or a prescribed fluid restriction is mentioned — route to their
  clinician. That guardrail is owned and enforced by [[hydration_everyday]] (its
  SAFETY-CRITICAL D6); this note must never generate advice that bypasses it.
- **Not enforced in code.** The bounds above are rules for the coach, not
  guarantees. This note declares no `safety_critical` directive and compiles no
  `OutputRule`; the hydration guardrails that *are* compiled belong to
  [[hydration_everyday]].

## Honesty & uncertainty

- **This is an absence of evidence, and Valtin says so.** "Since it is difficult or
  impossible to prove a negative … the author invites communications from readers
  who are aware of pertinent publications." We are asserting that no supporting
  study was found, not that one cannot exist.
- **The paper is from 2002 and we did not search for later work.** If evidence for a
  universal volume target has appeared since, this note does not know about it. That
  is a real limitation and it is the main reason a reader might disagree with the
  grade.
- **We did not read the full text**, only the full abstract at PubMed. Every quote
  above is from that abstract.
- **We measure nothing about this person's hydration** and this note licenses no
  statement about them — only about the claim.
- **Individual requirement genuinely varies** with climate, activity, body size, diet
  (a high-water-content diet supplies far more), medication and health conditions. No
  population number describes an individual — including the one being corrected.

## Bottom line

**Act on confidently:** there is no scientific basis for "eight 8-oz glasses a day"
as a universal requirement, and the correction must always carry Valtin's two limits
(healthy adults, temperate climate, sedentary; more IS needed in illness, exertion
and heat).

**Hold loosely:** whether any post-2002 work has supplied the missing evidence — we
did not look; and how much any individual actually needs, for which no note here has
a number.

## Coach Directives

1. Correct "8 glasses a day" **gently and once**, with Valtin 2002, and state in the
   same breath its two limits: it applies to healthy adults in a temperate climate
   leading a largely sedentary life, and larger intakes are called for in illness and
   in vigorous work or exercise, especially in heat. *(confidence: high)*
2. Never use the correction to discourage drinking in heat, illness or exercise, and
   never present it as "you are drinking too much water." *(confidence: high)*
3. Do **not** replace the myth with another number. Never prescribe a personal daily
   litre target; if a reference value is wanted, hand the question to
   [[hydration_everyday]], which states it *as total water including food*.
   *(confidence: high)*
4. Frame this as a claim the evidence does not support — not as a hedged or
   uncertain claim. "There is no evidence for it" is accurate; "it may not be
   necessary" understates the finding. *(confidence: high)*
5. Never state or imply anything about **this owner's** hydration. We hold no
   hydration data of any kind. *(confidence: high)*

## References

- Valtin H. *"Drink at least eight glasses of water a day." Really? Is there
  scientific evidence for "8 × 8"?* Am J Physiol Regul Integr Comp Physiol
  2002;283(5):R993–R1004. doi:10.1152/ajpregu.00365.2002. PMID 12376390.
  **Review** — source of the "no scientific studies were found in support of 8 x 8"
  finding, the osmoregulation argument, and both stated limitations.
  *[full abstract verified at PubMed 2026-08-01; full text not read]*

## Healthee implementation & honesty policy

- **No metric, no derived field, no log kind.** `applies_to_metrics: []` is literal.
  See [[hydration_everyday]] for the full statement of what the product does and does
  not hold; this note does not restate it.
- **Why this is a separate note (#91).** It is a separately *citable topic* — "is the
  8 glasses rule real?" is a question in its own right — and it is the only claim in
  the hydration material whose required framing is a **correction** rather than a
  hedge. A note carries one grade; keeping a `Myth` claim inside a `Probable` note
  meant the validator accepted a hedge for it. Splitting is what let the grade
  mechanism enforce the authored intent instead of documenting it.
  **`hydration_everyday` keeps its id, its aliases and both of its SAFETY-CRITICAL
  directives — nothing about the compiled hydration guardrails changed.**
- **Ownership boundaries (binding, to keep one definition per concept):**
  - How much water a healthy adult should drink, the EFSA reference values, and
    whether caffeinated drinks count → [[hydration_everyday]].
  - Exercise/heat hydration, sweat rate, sodium and the hyponatremia guardrail →
    [[fueling_and_hydration]].
- **Honesty rules (binding):**
  - Never give the correction without Valtin's two limits.
  - Never substitute a different universal number for the one being corrected.
  - Never call the owner over- or under-hydrated; we have no measurement.
