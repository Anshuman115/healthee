# Knowledge audit — the note bodies, and the claims themselves

Read-only audit of `packages/knowledge/` (89 markdown files: 56 under `notes/`, 33 under
`sports-science/`) and `apps/mobile/lib/shared/metric_info/` (the app's own explainer
prose), against `CLAUDE.md`, `docs/ENGINEERING_STANDARDS.md` section 4,
`docs/HOW_WE_VERIFY.md`, `packages/knowledge/TEMPLATE.md`, `packages/knowledge/notes/conventions.md`
and `packages/knowledge/manifest.json`, with `apps/server/src/healthee/` and
`apps/mobile/lib/` read as the consumers of every claim.

It uses the method, evidence standard and severity discipline of `docs/BACKEND_AUDIT.md`
and `docs/LLM_AUDIT.md` section 0.

**What is new here.** Previous audits checked the manifest's grades and the safety
markers — the frontmatter. Nobody had read the prose. This audit reads the prose: the
sentences a coach is handed and the sentences the app prints.

**Every finding carries `file:line` and is marked CONFIRMED (both ends read) or
SUSPECTED.** Cleared classes are reported with their evidence, because a swept class is
a result and it is the only thing that makes "the corpus is sound" verifiable rather than
hopeful.

Findings are ranked by **whether a false claim reaches the owner today** — which is not
the same as how wrong it is. The two channels are ordered deliberately: the app's own
prose is *on the screen now*, whereas corpus prose reaches the model, which may or may
not repeat it. That is one remove, and section B says so rather than flattening the
distinction.

**Nothing was changed by this audit.** This document recommends; it does not fix. No note,
no code, no test was edited — `feedback_never_degrade_knowledge` requires that a conflict
be surfaced, not resolved unilaterally, and several findings below are exactly the kind
where the owner should choose which side moves.

---

## 0. Counts

| Severity | Meaning | Count |
|---|---|---|
| **A — on the owner's screen today** | the app's own prose, or a rendered grade, states something false or forbidden | 9 |
| **B — in every prompt; the coach can repeat it** | corpus prose the model is handed that is wrong, withdrawn, uncited or miscalibrated | 10 |
| **C — wrong in a gate or on the wire** | a threshold or definition disagrees with its note; not visible on a screen today | 7 |
| **D — stale identifiers and hygiene** | a note names code that does not exist, with no honesty consequence | 12 |
| **Swept clean** | classes checked with evidence, no finding raised | 14 classes |

CONFIRMED 36 · SUSPECTED 2 · Could not determine: 2.

Corrected from the brief's own premises: 2 (the sports-science notes **do** carry
bibliographies, under `## Key references`; the `notes/protocol/*.md` files are **not**
citable and correctly fall outside the Honesty mandate — verified against the loader, not
assumed).

### The headline answers

* **Does any note assert product behaviour the code lacks?** **Yes — eleven of them.** The
  `training-load-acwr` precedent that prompted this question is itself now **closed**
  (`read/acwr.py:16-22,82,90` implements the suppression rule the note claimed), but the
  class is alive elsewhere: a note says a hydration rule is a hard guardrail when the
  compiled regex cannot see it (B2), a note says its own feature is unbuilt when it
  shipped (B8), a note documents a calorie model the code replaced (B10).
* **Does the language match the grade?** **Almost everywhere.** Zero notes are missing
  the Honesty section, zero Honesty sections are decorative, all four `Contested` notes
  in `notes/` frame as debated, and the reverse miscalibration — an Established claim
  hedged into uselessness — has **zero instances corpus-wide**. The exceptions are four
  "Act on confidently" lines in causal voice (B7) and one structural grade mismatch on a
  safety claim (D12).
* **Are the citations real, and do they say what the note says?** Every load-bearing
  citation I checked against its primary source **held**: Jurca 2005, Yin 2017, Libert
  2025, Paluch 2022, Drake 2013 (section 3). Two figures are stated with **no** source at
  all (B5, B6), one withdrawn figure survives in five places in the file that withdrew it
  (B1), and one citation in the **app** attributes to Mandsager 2018 a comparator that
  paper does not make (A3).
* **Is the Honesty section present and honest?** **Yes, in all 78 manifest notes.** This
  is the strongest result in the audit.
* **Do the app's explainers agree with the corpus?** **Not yet.** All 36 note ids resolve
  and the resolution test is genuine, but the grounding pass left nine defects on screen,
  two of which are claims the cited notes' own directives forbid printing — and which the
  server hard-blocks the model from writing.
* **Do numbers in notes match numbers in code?** **Overwhelmingly yes** — see the swept
  list in section 4. Seven disagree, and in two of those (C7, and the note side of B2) I
  believe the **note**, not the code.

---

## 1. The two structural observations

These are not findings; they are the reason the findings below exist where they do.

### 1.1 Note prose is the one interpretive channel with no calibration gate

`insights/retrieval.py:230` embeds `prompt_body(n.id)` — the **full body minus the
bibliography** — of the top-6 ranked notes into every LLM call, and lists every other
note as `[id] (Grade): summary` (`retrieval.py:233-234`). So every sentence in a retrieved
note, including its `## Healthee implementation & honesty policy`, is read by the model.

`insights/validator.py:131-167` (`_grade_issue`) enforces calibrated language on the
**model's output sentence**, keyed to the frontmatter `grade` of the notes that sentence
**cites**. It never reads note prose. There is no stage anywhere that checks a note's own
sentences against its own grade.

That is the same shape as the legacy Dart explainers — a grade-free channel into the
product — one layer up, and it is why section B exists as its own severity band. It is
also why B1 matters more than its subject suggests: `wearable_spo2_validity.md:72` does
not merely contain a withdrawn number, it *instructs the coach to state it*.

### 1.2 One claim, two channels, one gate

`insights/output_guard.py:195-206` compiles `personal_death_risk_number`, whose `source`
field cites `steps_mortality.md:115`, `resting-heart-rate.md:143` (D13) and
`vo2max.md:513` — the notes that forbid the sentence. The model cannot write it.

`apps/mobile/lib/shared/metric_info/explainers_body.dart:84` and `:133` write it anyway,
as a hardcoded Dart string, on two cards. Same claim, same forbidding directives, one
channel gated and one not (A1, A2).

`metric_info.dart:25-27` names this exact failure as what the grounding pass set out to
fix on the RHR and steps cards. It fixed those two — `explainers_body.dart:66-69` is now
*"more daily steps track with better long-term health … (Paluch 2022)"*, which is the
directive honoured to the letter — and left the identical shape standing two entries
below.

---

## 2. Findings

### A. On the owner's screen today

#### A1 — the MVPA card prints a mortality percentage three of its four cited notes forbid — CONFIRMED

`apps/mobile/lib/shared/metric_info/explainers_body.dart:83-85`

> 'The 150-minute target is WHO 2020. Pooled across 196 prospective studies, reaching it
> tracks with roughly **22–31% lower all-cause mortality** versus none, and with less
> cardiovascular disease and cancer.'

The entry cites `mvpa_minutes_mortality`, `mvpa_weekly_plan`, `cadence_intensity`,
`exercise_mortality` (`explainers_body.dart:88-93`). Three of those four forbid the
sentence outright:

* `packages/knowledge/notes/activity/mvpa_minutes_mortality.md:116` — Coach Directive 4:
  *"never show a death-risk number. *(high)*"*; and `:85` *"No death-risk number is shown
  to the user."*
* `packages/knowledge/notes/activity/exercise_mortality.md:95` — Coach Directive 1:
  *"never quantify mortality to the user."*
* `packages/knowledge/notes/activity/mvpa_weekly_plan.md:95` — *"No death-risk number; the
  card is a progress/encouragement surface only."*

The figure itself is in the corpus. The defect is that printing it to the owner is what
these notes exist to prevent, and what `output_guard` blocks the model from doing.

**Also in the same sentence:** *"and with less cardiovascular disease and cancer"*. Those
strings appear in the cited notes **only inside a bibliography entry** (Garcia 2023's
title, `mvpa_minutes_mortality.md:120-122`); the graded body claim at `:21-22` is
cardiovascular **mortality**, and nothing on cancer. A claim riding on a reference title,
upgrading mortality to disease incidence.

**Recommend:** state the association without the number, as the steps card already does.

#### A2 — the VO₂max card prints a death-risk number the tier it displays forbids — CONFIRMED

`apps/mobile/lib/shared/metric_info/explainers_body.dart:133-135`

> 'In 122,007 adults given treadmill tests, the fittest had about **80% lower all-cause
> mortality** than the least fit…'

* `packages/knowledge/notes/activity/non_exercise_vo2max.md:275` — *"**Do not launder the
  estimate into a death-risk number.** The CRF↔mortality effect sizes in [[vo2max]] are
  CPET-anchored; this estimate carries ~5.1 mL/kg/min SEE on top…"*; Directive 4 at `:312`
  is *"Never present the estimate as a death-risk figure."*
* `packages/knowledge/sports-science/metrics/vo2max.md:524` — Safety bounds: *"Never
  present absolute VO₂max as a 'death-risk' number."*

The population-vs-personal framing arguably escapes `vo2max.md`'s wording. It does not
escape `non_exercise_vo2max` D4, and that is the note governing the Jurca tier this card
actually shows for this owner.

#### A3 — the same card attributes to Mandsager 2018 a comparator that paper does not make — CONFIRMED

`apps/mobile/lib/shared/metric_info/explainers_body.dart:134-136`

> '…low fitness carried more risk than smoking, diabetes or **high blood pressure** did
> **in that same population** (Mandsager 2018).'

`packages/knowledge/sports-science/metrics/vo2max.md:209-210`:

> '…the hazard of *low* CRF exceeded that of current smoking, diabetes and **end-stage
> renal disease** modelled in the same population [Mandsager et al. 2018].'

Hypertension appears in that note only in the *separate*, non-Mandsager sentence at
`:202-204` ("stronger than smoking, hypertension, diabetes, or hypercholesterolaemia"),
which is the general claim, not the cohort-modelled one. Two sentences have been spliced,
ESRD has been swapped for hypertension, and the swap has been attributed to a named
cohort.

This is the audit's clearest instance of the class the brief called worse than an absent
citation: a citation that exists and does not support the claim.

#### A4 — a Contested source renders under a "Probable" stamp — CONFIRMED

`apps/mobile/lib/shared/metric_info/metric_info_sheet.dart:338-342`

```dart
DetailGrounding(
  noteIds: _notes,                                  // merged: explainer + payload
  detail: detail,
  fallbackGrade: explainer == null ? null : weakestGrade(explainer.notes),  // static only
),
```

`_notes` (`metric_info_sheet.dart:221-225`) merges the explainer's static ids with
`detail.notes`, which the server supplies. The grade stamp is computed over the static
list alone.

Two live payload paths ship `Contested` ids the static lists do not carry:

* `apps/server/src/healthee/read/vo2max.py:125` — `METHOD_RESERVE: ["vo2max", "hr_reserve_vo2max"]`.
  `hr_reserve_vo2max` is graded **Contested**.
* `apps/server/src/healthee/read/activity.py:70` — `"training_load_acwr"`, graded
  **Contested**.

So the sheet lists a Contested note as a source and stamps the block `Probable`. The
server's own rule is the opposite: `jobs/recs.py:257` takes the strictest (weakest) grade
among the cited notes as the ceiling, and `insights/validator.py:205-211` (`_grade_floor`)
does the same, fail-closed.

No test covers the merged list — `apps/mobile/test/shared/metric_info_grounding_test.dart`
only ever calls `weakestGrade(entry.value.notes)`.

**Recommend:** `weakestGrade(_notes)`, and a test over the merged list. This is the one
finding on this screen that no amount of prose care can catch.

#### A5 — the sleep-health card disowns a cutoff its own cited note sources four ways — CONFIRMED

`apps/mobile/lib/shared/metric_info/explainers_sleep.dart:88`

> 'The **2–4 am timing band** and SRI ≥ 70 are **both ours** — no published SRI threshold
> of 70 exists.'

The SRI half is correct. The timing half is not.
`packages/knowledge/notes/sleep/sleep_score_implementation_plan.md:157-162` — a note this
entry cites:

> **Cutoff**: sleep midpoint in `[02:00, 04:00)` local time.
> **Citation**: Buysse 2014 RU-SATED definitional cutoff … replicated as the timing
> dimension in Wallace 2017 … and Lee 2022 actigraphy composite. Saint-Maurice 2024 in UK
> Biobank (n = 88,282) reports HR 1.29…

This is the inverse of the usual defect and worth naming as such: the app claims **less**
grounding than it has, in the field whose entire job is to be honest about grounding.

#### A6 — the same card glosses a midpoint as a bedtime, inverting the advice — CONFIRMED

`apps/mobile/lib/shared/metric_info/explainers_sleep.dart:66`

> 'Four qualities of a good night: enough hours, efficient sleep, **a healthy bedtime**,
> and night-to-night regularity.'

The dimension is the sleep **midpoint** in `[02:00, 04:00)` — `sleep_score_implementation_plan.md:157`
and `apps/server/src/healthee/read/sleep_common.py:24` (`"timing_hour_band": [2, 4]` over
`midpoint_local`). Read as a *bedtime*, 2–4 am is the window
`packages/knowledge/notes/sleep/sleep_timing_chronotype.md:54-57` scores worst.

An owner reading the ⓘ learns that the app wants him in bed between 2 and 4 am.

#### A7 — the same card says the checks are never summed, three lines above "Aim for 4 / 4" — CONFIRMED

`apps/mobile/lib/shared/metric_info/explainers_sleep.dart:67` and `:70`

> 'Each is a simple pass/fail, and **they are never summed into a score**.'
> …
> '**Aim for 4 / 4.**'

`packages/knowledge/notes/sleep/sleep_score_implementation_plan.md:36-39`: *"The shipped
composite **is a 0–4 integer** = the count … deliberately not transformed to a 0–100
scale."* `apps/server/src/healthee/derive/sleep_score.py:217` writes
`sleep_health_score_4dim`.

The true statement — the one `no_validated_sleep_score.md:107-108` makes — is *never a
0–100 composite, and the 0–4 sum always rides with its four dimensions*. The explainer
overstates it into a contradiction with its own next sentence.

#### A8 — an unsourced claim rides under the citation row on the sleep-debt card — CONFIRMED

`apps/mobile/lib/shared/metric_info/explainers_sleep.dart:106-107`

> '…while the people in it **reported feeling only slightly sleepy** (Van Dongen 2003).'

`grep -in "sleepy|subjectiv|unaware"` over both cited notes
(`sleep_need_debt.md`, `sleep_duration_mortality.md`) returns **zero hits**. It is not
listed in the entry's `uncited`.

The claim is a real finding of Van Dongen 2003. That is not the point: the corpus does not
carry it, so the citation row implies cover it does not give — which is the precise
mechanism `MetricInfo.uncited` was added to prevent.

Two more of the same shape in the same file, both CONFIRMED, both absent from `uncited`:
`:101-102` *"Even an **extra 30 min a night** moves it the right way"* (no sleep-extension
dose exists anywhere in `notes/`; `sleep_need_debt.md:107-108` permits only "recommend
(not prescribe) catch-up"), and `explainers_recovery.dart:133-134`'s *"a drop of more than
about **a standard deviation**"*, stated plainly from a band that
`sports-science/metrics/heart-rate-variability.md:322` (D1) explicitly flags as *"unsourced
practitioner/methodological convention — no source in this note supports it (#100)"*.

#### A9 — `uncited` is used backwards in four places, so the sheet calls sourced claims unsourced — CONFIRMED

`apps/mobile/lib/shared/metric_info/metric_info_blocks.dart:227` renders the field as
*"Not covered by those sources: …"*.

`apps/mobile/lib/shared/metric_info/explainers_body.dart:51-53` puts under it:

> 'If your logged weight is old, the BMR under this number is old too — about **0.6% per
> kilogram** out of date.'

`packages/knowledge/notes/activity/energy_expenditure_derivation.md:132-133` says, verbatim:

> '…the relative error a wrong mass puts on `total_calories`, `active_calories` and
> `basal_calories` alike is at most `10·Δkg / BMR` — about **0.6% per kilogram**, exact at
> `basal_calories`.'

The same inversion at `explainers_recovery.dart:60-62` (intraday decay ←
`recovery_readiness.md:200,409-410`), and twice more at `explainers_body.dart:145-148`
and `:173-178` (regularity-not-priced and the questionnaire conversion ←
`biological_age_estimate.md:65,117,246-252`; the SR-PA step cost ← `non_exercise_vo2max`
D7).

A disclaimer that fires on the wrong claims is worse than none: it teaches the reader that
the label carries no information.

---

### B. In every prompt; the coach can repeat it

Everything in this section is embedded verbatim into the model's context by
`retrieval.evidence_section` (section 1.1). None of it is checked by the validator.

#### B1 — the SpO₂ note still prints, in five places, the figure it records as withdrawn — CONFIRMED

`packages/knowledge/notes/metrics/wearable_spo2_validity.md`

| line | text |
|---|---|
| `:7` (frontmatter `summary`) | "…not for absolute precision **(±2–3% RMSE)**…" |
| `:18` | "consumer devices run **±2–3% RMSE vs arterial reference**" |
| `:55` | "**Hold loosely:** … **sub-2% differences**" |
| `:62` (Directive 5) | "Acknowledge reduced reliability for single readings, **sub-2% precision**…" |
| `:72` (Healthee honesty rules) | "…acknowledge the dark-skin bias and the **±2–3% absolute imprecision**." |

The same file, `:29` and `:45`, records that this figure was **withdrawn in #98** as a
mis-attribution — the FDA bar for *cleared medical oximeters* applied to an uncleared
wellness wearable — and that the real error is *"unquantified and at least"* ≥±3.5%,
because a wrist sensor is reflectance and the Helio Strap has no published validation.

Three consequences, all live:

1. `:72` is not a leftover figure; it is an **instruction to the coach to state it**.
2. The `summary` at `:7` is what `packages/knowledge/tools/gen_manifest.py` writes into
   `manifest.json` and `research_summaries.json`; I confirmed the withdrawn sentence is
   in the generated `research_summaries.json` record for `wearable_spo2_validity` today.
3. `retrieval.py:234` lists every non-embedded note by that `summary`, so the withdrawn
   figure is in the prompt on **every** LLM call where this note does not make the top-6.

Direction of the error is the aggravating factor: it makes the device sound **more**
precise than the evidence allows. That is the #108 shape — flattery of the instrument.

**Recommend:** finish #98. The correct sentence is already written at `:45`; it needs to
reach the other five places.

> The app is clean here, and by a wide margin: `explainers_recovery.dart:173` routes at
> ~92%, calls it a clinical convention rather than a wearable-validated cutoff, and names
> the unquantified device error. The corpus is behind its own consumer.

#### B2 — two notes claim a hard guardrail for a rule the compiled regex cannot see — CONFIRMED

`packages/knowledge/sports-science/wellness/environmental-stress.md:434-437`

> **D14:** Never advise **drinking ahead of thirst** even in heat (hyponatremia risk) …
> (SAFETY-CRITICAL; **enforced in code** via `[[hydration_everyday]]` D5, whose compiled
> rule takes heat as one of its subject triggers)

`packages/knowledge/sports-science/wellness/fueling-and-hydration.md:386` makes the same
claim for its D8 (*"Never advise drinking **beyond thirst** or in excess of sweat losses …
enforced in code via [[hydration_everyday]] D5/D6"*).

The subject half is true — `insights/guard_directives.py:119` scopes the rule to
`red_flags.EXERTION_OR_HEAT_RE`. The forbidden-move half is not.
`_FLUID_TARGET_RE` (`guard_directives.py:121-131`) matches **only numeric volume and rate
instructions**. I extracted the four alternatives verbatim and probed them:

```
PASSES  "In the heat, stay ahead of your thirst - don't wait until you feel thirsty to drink."
PASSES  "When running in hot weather, drink before you get thirsty."
PASSES  "Keep drinking steadily through the hot run rather than waiting for thirst."
FIRES   "During your hot run, drink 500 ml every hour."
FIRES   "Sip 250 ml every 20 minutes while training in the heat."
```

The exact phrasing both directives name — and which
`fueling-and-hydration.md:165` grades **[Myth]** (*"You must drink ahead of thirst"*) and
`:349` restates as *"never coach drinking ahead of thirst"* — passes clean. `grep -rn
"thirst" apps/server/src/healthee/` returns one hit, and it is a comment.

**Which is right:** the **code's scope** is defensible (a numeric schedule is a text
pattern; "ahead of thirst" is a paraphrasable stance), and `fueling-and-hydration.md:320-329`
already says so honestly — *"That is exactly this note's 'never advise drinking beyond
thirst / to a schedule', made deterministic. A regex catches phrasings, not every possible
phrasing."* The **directive lines** are the defect: they read as unqualified enforcement
of a move the rule does not recognise. Standards section 4 names this as the worst kind —
*"a false safety claim inside the safety system … an auditor reads it and stops looking."*

**Recommend:** qualify D14 and D8 to say what the rule covers (numeric volume/rate
instructions in an exercise-or-heat sentence) and what it does not, matching the prose
`fueling-and-hydration.md` already carries 60 lines earlier.

#### B3 — a retrieval-visible note republishes the two Jurca figures #108 withdrew — CONFIRMED

`packages/knowledge/notes/activity/submaximal_vo2max.md:64`, in the method-comparison
table:

> | *Jurca 2005 (fallback baseline)* | **r≈0.78, SEE≈5.6** | — (resting-HR only…) |

`packages/knowledge/notes/activity/non_exercise_vo2max.md:69-74` is the correction that
made those figures unusable:

> **[Corrected 2026-08-02, #108.]** … **None of those five figures is in the paper.** …
> the paper reports one R per cohort, not sex-stratified r; and 5.6 mL/kg/min is nobody's
> SEE…

The same file contradicts itself: `submaximal_vo2max.md:199` correctly uses **5.075** in
the freshness-horizon argument. Both sentences are in the model's context together.

The residue survives in code too, as a docstring:
`apps/server/src/healthee/derive/vo2max.py:288` — *"(≈0.2 ml/kg/min per kg of weight
error, against **Jurca's own 5.6 SEE**)"* — 220 lines below `:60-71`, where the same file
records that 5.6 *"appears nowhere in the [source]"* and sets
`_JURCA_SEE_ML_KG_MIN = 5.075`. No computation reads it; a reader does.

#### B4 — the coach-facing section of the Jurca note gives an error bar the wire contradicts — CONFIRMED

`packages/knowledge/notes/activity/non_exercise_vo2max.md:228`, under **How the coach uses it**:

> Report the latest 7-day median estimate with a **±1 SEE band (~6 mL/kg/min)**…

The same note says **5.1** at `:7` (the summary that ships to the manifest) and `:276`,
and **~5** at `:285`. `apps/server/src/healthee/derive/vo2max.py:70-71` computes
`1.45 × 3.5 = 5.075`, and that is what the app draws.

The error is conservative in direction, which is why it is B and not A. It is still a
number in the section the coach reads that disagrees with the number on the card beside
the coach's answer.

#### B5 — an Established note states a load-bearing figure with no source — CONFIRMED

`packages/knowledge/notes/metrics/respiratory_rate_normal.md:33`

> - **[Established] Personal night-to-night stability is high** — a healthy individual's
>   own nightly average varies typically **<1 br/min**, which is what makes a
>   personal-baseline deviation informative.

Every neighbouring bullet carries a citation — `:32` [Cretikos 2008], `:34` [Mishra 2020;
Quer 2021] — and the References block at `:80-82` holds exactly those three. None supports
this figure. It is reprinted as fact in the frontmatter `summary` at `:7`.

It is load-bearing: `apps/server/src/healthee/derive/illness.py:118`
(`RR_TRIGGER_BPM = 2.0`) is only meaningful because normal variation is claimed to be
under 1. Standards section 4: *"citations are real or absent — a claim that can't be
sourced is labelled practitioner consensus or omitted."*

#### B6 — a second uncited figure, one bullet below a correction that fixed the first — CONFIRMED

`packages/knowledge/notes/sleep/sleep_consistency.md:62`

> - **[Probable] Bedtime variability and cardiometabolic outcomes** — SDs of bedtime ≥1
>   hour vs <30 min carry small-to-moderate elevations in risk (**typically RR 1.1–1.3**).

No source. "Typically" is doing a citation's work. The bullet **directly above**
(`:51-58`) carries a 2026-08-01 primary-source correction retracting a fabricated
`HR ≈ 1.46` — so the pass that fixed one bullet stopped one bullet short.

#### B7 — four "Act on confidently" lines are in causal voice, against the corpus's own rule — CONFIRMED

`packages/knowledge/notes/conventions.md:62` is binding: *"If a finding is from
observational data only, do not say 'causes.'"*

| file:line | line |
|---|---|
| `notes/activity/strength_training_mortality.md:112` | "**Act on confidently:** any strength training **lowers** mortality (~15%)…" |
| `notes/activity/sedentary_mortality.md:95` | "**Act on confidently:** long sedentary time **raises** mortality…" |
| `notes/activity/exercise_mortality.md:87` | "**Act on confidently:** even ~15 min/day … meaningfully **cuts** mortality" |
| `notes/sleep/sleep_consistency.md:46` | "timing variability … **raises** cardiometabolic and mortality risk" |

Each note's own evidence bullets say **"associated with"** (`sedentary:21`, `exercise:22`,
`strength:27`, `consistency:22`) and each Honesty section opens **"Observational"**. The
causal verb appears only in the frontmatter `topic`/`summary` and in the "Act on
confidently" line — i.e. in exactly the two places that ship to `research_summaries.json`
and that tell the model what it may state plainly. All four are `Established` (rank 3), so
`_grade_issue` demands nothing extra, and all four are above `MIN_ACTIONABLE_RANK`, so
these sentences may drive a daily recommendation.

**The standard is demonstrably achievable in this corpus**, which is what makes this a
defect rather than house style: `steps_mortality` says "**track** progressively lower",
`sauna_cv_benefits` says "**associated with**" in the summary too, `resting-heart-rate`
says "**tracks**", and `sleep_duration_mortality:126` goes further — "marker, **not a
cause**".

#### B8 — a note says its own feature is unbuilt; it shipped — CONFIRMED

`packages/knowledge/notes/sleep/caffeine_alcohol_cutoff_plan.md:207`

> **Status:** this note is a *plan* (methodology of record), **not yet shipped**…

and `:100` *"New module `src/healthee/analytics/cutoff_finder.py`"*.

It is shipped, under a different filename, exactly as specified:
`apps/server/src/healthee/analytics/cutoffs.py` (Mann-Whitney U over H ∈ {12,14,16,18,20,22}
local, caffeine and alcohol only, `kind="personal_cutoff"`, `replace_findings_of_kind`),
wired into the weekly correlate job at
`apps/server/src/healthee/jobs/correlate.py:20,37-38`.

A coach grounding an answer in this note tells the owner a live feature does not exist.
This is the `illness_flag_plan` defect class running backwards — a note claiming vapour
where shipped code stands.

#### B9 — the distance note calls a device measurement a stride estimate — CONFIRMED

`packages/knowledge/notes/activity/distance_from_steps.md:118-123`

> With HC retired, **this is the sole distance source** except for GPS-backed workouts…
> **Honesty rules**: always "estimate"; ±10–20% vs GPS; … never fabricate (**needs profile
> height**).

`apps/server/src/healthee/derive/device_totals.py:174-190` (`select_distance`) returns the
strap's **own measured daily distance** whenever `device_daily_total.distance_m` exists,
ahead of `steps × stride`; the stride tier is the fallback. The note's honesty rules then
mislabel a measurement as a ±10–20% estimate, and the height precondition is false for
that branch.

Same note, same shape as B10: written before #121 gave the device counter a durable home.

#### B10 — the calorie note documents a model the code replaced — CONFIRMED

`packages/knowledge/notes/activity/energy_expenditure_derivation.md:87`

> awake, no steps  → **1.4 MET**  (light NEAT; Compendium sitting 1.3 / standing 1.8) ← tunable

`apps/server/src/healthee/derive/energy.py:70-78,155-160` runs a **two-state** model
instead: `AWAKE_SEDENTARY_MET = 1.3` (Compendium 07021) or `AWAKE_ACTIVE_MET = 1.55`,
chosen by whether any step falls within `NEAT_WINDOW = 7` minutes either side.

The code's model is the better one and its own comment argues why (*"A flat 1.4
overcounts long sedentary stretches AND undercounts time up-and-about between strides"*).
But the note's worked verification — `:91`, *"Verified on the real day: total 2470, PAL
1.40"* — checks a formula the product no longer runs, and a coach explaining the owner's
calories from this note explains a model that is not producing them. Neither `1.55` nor
`NEAT_WINDOW = 7` is cited anywhere (see D11).

---

### C. Wrong in a gate or on the wire; not visible on a screen today

#### C1 — the challenge engine caps the sleep target below the owner's own need, citing a note that disclaims the band — CONFIRMED

`apps/server/src/healthee/challenges/scales.py:64`

```python
"tst_min": 450.0,  # 7.5 h, mid-band of the U-curve [sleep_duration_mortality]
```

Two defects in one line.

**The citation does not support the claim.**
`packages/knowledge/notes/sleep/sleep_duration_mortality.md:53-60` is a 2026-08-01 (#88)
correction whose whole point is that this paper has no reference band:

> **Cappuccio 2010 states no reference band, and this note used to attach "7–8 h" to it
> four times.** … So **neither "7–8 h" nor "7–9 h" is Cappuccio's**…

**And the number is a third definition of sleep need.** `derive/sleep_score.py:44` is the
canonical one — `SLEEP_NEED_MIN_18_64 = 480` (NSF 2015). `IDEAL` is read by
`challenges/adapt.py:310-334` as the **hard ceiling on any raise**, so the engine can
never move a sleep-duration target above 7.5 h — for an owner whose own computed need is
8 h, and who is a chronic short sleeper. CLAUDE.md's "ONE canonical definition per metric"
is the rule this breaks.

**Which is right:** 480. The 450 has no source and contradicts the derive layer.

#### C2 — `mvpa_min` has two definitions: the notes MET-weight it, the code does not — CONFIRMED

`packages/knowledge/notes/activity/mvpa_minutes_mortality.md:37`

> Reported as a **weekly** total, **MET-weighted by the WHO rule that one vigorous minute
> counts as two moderate**…

Stated five times across three notes (`mvpa_minutes_mortality.md:37,69,137`,
`mvpa_weekly_plan.md:81,120`, `cadence_intensity.md:80`), and it is the guideline's own
equivalence (WHO 2020: 150–300 moderate **or** 75–150 vigorous).

`apps/server/src/healthee/derive/mvpa.py:68` — `mvpa = moderate + vigorous`, unweighted.
`apps/server/src/healthee/read/mvpa_week.py:108` sums those rows unweighted, and
`apps/server/src/healthee/read/fitness.py:187` compares the sum to `"week_target": 150`.

**Which is right:** the notes. The owner is measured against a MET-equivalent target using
un-weighted minutes. The error direction is *under*-crediting, which is the safe
direction and why this is C rather than A — and it is invisible for this owner today,
who has recorded zero vigorous minutes. It ships for anyone who runs.

> The app's own explainer at `explainers_body.dart:80-81` states the rule correctly —
> *"Vigorous minutes count double"* — so the screen and the server currently disagree.

#### C3 — MVPA excludes workouts entirely, and two notes say it does not — CONFIRMED

`packages/knowledge/notes/activity/mvpa_weekly_plan.md:56,69,140` and
`mvpa_minutes_mortality.md:68,138` describe MVPA as derived from per-minute cadence **plus
`session(kind='workout')`**, *"which covers cycling, weights, swimming"*
(`cadence_intensity.md:78-80`).

`apps/server/src/healthee/derive/mvpa.py:46-72` reads `metric='steps_per_minute'` from
`sample` and nothing else. There is no workout join in the MVPA path, and no `session`
table in `apps/server/src/healthee/db/schema.sql`.

The aggravating detail: `mvpa_weekly_plan.md:144` promises the coach will *"surface likely
under-count when workouts are **unlogged**"*. Workouts are never counted whether logged or
not, so the promised disclosure names the wrong cause.

**Which is right:** the notes describe the correct behaviour; the code is the gap.

#### C4 — three notes are keyed to a metric that exists nowhere, and cannot be retrieved by it — CONFIRMED

`applies_to_metrics: ["strength_min_weekly"]` in
`notes/activity/strength_adherence_plan.md:10`,
`notes/activity/strength_training_mortality.md:10`, and
`sports-science/wellness/strength-training-for-runners.md:9`; the function
`weekly_strength_minutes(end_date)` is named in the first two.

Neither identifier exists in `apps/server/src` or `apps/mobile/lib`. The real thing is
`apps/server/src/healthee/read/fitness.py:196` `strength_payload()` — read-time only, no
`derived_daily` row — and `analytics/metrics.py` does not carry the name.

**Live consequence:** `insights/retrieval.py:174` scores notes by
`metrics.intersection(note.applies_to_metrics)`, so a name no metric set contains can
never intersect. All three notes score **zero** metric hits, permanently, and rank on
aliases and lexical overlap alone. I found this independently by resolving every
`applies_to_metrics` value in the manifest against `derive/`, `analytics/`, `read/` and
`schema.sql`: it is the **only** unresolved name of 31.

#### C5 — the only place in `derive/` that invents an input instead of withholding — CONFIRMED

`apps/server/src/healthee/derive/cardio_load.py:22`

```python
_RHR_FALLBACK = 60.0  # when no measured resting HR is available
```

`packages/knowledge/sports-science/metrics/training-stress-score.md:458-459` says the
opposite: *"**measured** resting HR (`rhr_daily`, taken from the sleep window — **preferred
over a generic 60**)"*.

When no RHR row exists, `_measured_rhr` (`cardio_load.py:70-81`) returns 60 and the module
publishes a full `cardio_load` row, which then feeds strain, ACWR and the readiness decay.

**A second defect in the same function, not previously reported:** the query is
`WHERE ... day <= %s ORDER BY day DESC LIMIT 1` with **no maximum age**. A resting HR from
a year ago is used as today's, silently — the same stale-as-current shape that
`derive/vo2max.py:_profile_withhold_reason` was written to close for weight, quoting
`weight_bmi_body_composition` on exactly this pattern. `derive/freshness.py` already owns
the horizon vocabulary this would need.

**Which is right:** the note. Every other gate in `derive/` withholds; this one fabricates.

#### C6 — one metric, two anchors, across two notes — CONFIRMED

`hr_zone_minutes` is written by `apps/server/src/healthee/derive/cardio_load.py:100`
as plain **%HRmax** (`pct = hr / hrmax`) against `EDWARDS_ZONE_LO` at `:21`.

* `packages/knowledge/sports-science/metrics/training-stress-score.md:473-479` describes
  exactly that, and matches.
* `packages/knowledge/sports-science/metrics/heart-rate-zones.md:207-218` specifies
  **Karvonen %HRR** bands (`HRR = HRmax − HRrest`, `method` tagged `"hrr-karvonen"`) with
  the same 50/60/70/80/90 edges, and `:249` — under **How the coach uses it**, the section
  the model reads — says *"**Default anchor:** use Karvonen **%HRR** zones from
  `computeHrZones`"*.

The same numeric edges mean materially different heart rates under the two anchors.
`heart-rate-zones.md:201-202` already admits *"Healthee's real implementation is
`derive/cardio_load.py`… not a TypeScript module"* — the admission reached the
implementation section and not the zone table or the coaching section.

**Which is right:** the code and `training-stress-score.md` agree, so the corpus should
converge on them. The break is CLAUDE.md's "ONE canonical definition per metric", on the
corpus side.

#### C7 — the code should yield: a plausibility filter the note says exists on both paths, and one path lacks — CONFIRMED

`packages/knowledge/notes/metrics/skin_temp_signals.md:68`

> …surfaced by averaging over the sleep window at read time (`read/sleep_extras.py`,
> `read/sleep_page.py` — `AVG(skin_temp_c)` over the night, **filtered to plausible
> values, e.g. `value>25`**).

`apps/server/src/healthee/read/sleep_page.py:247` has it —
`AND s.metric='skin_temp_c' AND s.value>25`.
`apps/server/src/healthee/read/sleep_extras.py:95` does **not** — a raw
`AVG(CASE WHEN metric='skin_temp_c' THEN value END)`.

**Which is right: the note.** This is the ACWR shape — the code should move to meet it. A
sentinel or off-wrist sample pulls the "last sleep" skin temperature down on one surface
and not the other, and the note's own downstream section (`:69`) names this metric as a
limb of the illness early-warning flag.

---

### D. Stale identifiers and hygiene

Each of these is a note naming code that does not exist. None reaches the owner as a false
health claim; all of them mislead the next reader.

**D1 — four sports-science meta-documents deny a live safety guardrail. CONFIRMED.**
`sports-science/COACHING-RULES.md:22` (*"None of them is compiled into one yet"*) and `:41`
(*"**No sports-science doc declares a marker**, so nothing in this section is
automatically enforced"*); `sports-science/METHODOLOGY.md:57`; `sports-science/README.md:29`
and `:86-87` (*"Four directives are marked so far, all in `notes/`"*);
`sports-science/TEMPLATE.md:62-64` (*"no note carries a `safety_critical` flag and the
manifest emits no directives"*).
`sports-science/wellness/environmental-stress.md:6` declares `safety_critical: [12]`, the
manifest publishes it, and `insights/guard_directives.py:285-300` compiles
`environmental_stress_D12_exertional_red_flags_to_urgent_care`. There are **five** markers
across four notes, one of them in this collection. And the compiled one is
COACHING-RULES' own rule 8 (`:86`, heat-illness stop-and-cool), so the document denies the
existence of its own live guardrail.
None of these four files is in the manifest (`gen_manifest.py:53` `SS_SKIP`), so nothing
reaches the coach — the direction is an **under**-claim, which is the safe one. It stays a
finding because `TEMPLATE.md` is what every new sports-science note is authored from, and
it teaches an author that the mechanism does not exist.

**D2 — a sleep-debt cap the code deliberately does not apply. CONFIRMED.**
`notes/sleep/sleep_need_debt.md:90` — *"cap total debt at a sane ceiling (~ 2 nights'
need)"*. `derive/sleep_score.py:239` returns `max(0.0, shortfall - 0.5 * surplus)` with no
cap, and its docstring at `:326` says so on purpose: *"no artificial cap, so a real chronic
deficit shows in full"*.
**Which is right: the code.** The cap is uncited, and for a ~3.7 h/night sleeper it would
clip a real fortnightly deficit to two nights' worth — flattery by construction, in the
one metric this product exists to be honest about. The note should be corrected to match.

**D3 — a 480-minute fallback the code removed on purpose. CONFIRMED.**
`notes/recovery/recovery_readiness.md:531` documents *"reading `sleep_need_min` (fallback
480 min)"*. `derive/recovery.py:92-138` deleted it; the sleep factor is now **absent**, not
defaulted, and the weights renormalise. Its docstring calls the old fallback *"a personal
target invented for an owner we have never been able to compute one for"* and *"the third
definition of one metric"*.

**D4 — a wire field and a norm table that do not exist. CONFIRMED.**
`notes/activity/non_exercise_vo2max.md:391-395` says `/api/today` carries `age_percentile`
(vs Mandsager 2018 quintiles) and the UI shows a percentile subtext. `age_percentile`
appears nowhere in `apps/`. `read/vo2max.py:207-208` ships `median_for_age` and
`delta_from_median`, off FRIEND (`analytics/reference_scales.py`), not Mandsager. The
`see_ml_kg_min` half of the same sentence **is** correct
(`apps/mobile/lib/data/models/vo2max.dart:142`).

**D5 — a module and a systemd timer that do not exist. CONFIRMED.**
`notes/recs/recommendations_engine_plan.md:330-333` names
`src/healthee/llm/recs_prompt.py`, `recs_context.py`, `validator.py` and *"the
`healthee-recs.timer`"*. There is no `healthee/llm/` package; the only `.timer` in the repo
is `infra/backup/healthee-backup.timer`; scheduling is in-process (`jobs/scheduler.py`).
The sibling `notes/recs/llm_health_advice_safety.md:293` already corrected exactly this
class and this note was missed.

**D6 — three notes assert a `source` column the schema does not have. CONFIRMED.**
`notes/activity/cadence_intensity.md:143` (*"`source='gadgetbridge'` from
`HUAMI_EXTENDED_ACTIVITY_SAMPLE`"*), `notes/activity/mvpa_weekly_plan.md:137`
(*"`source='derived'`"*), `notes/activity/non_exercise_vo2max.md:373` (same).
`db/schema.sql:20` — `sample` is `(ts, metric, value, user_id)`. `:77` — `derived_daily` is
`(day, metric, value, flags, user_id, derived_at)`. Only `device_daily_total` carries a
`source`. `gadgetbridge` and `HUAMI_EXTENDED_ACTIVITY_SAMPLE` appear nowhere in `apps/`.
v1 vocabulary that survived the v2 rename pass.

**D7 — two registrations, one of which exists nowhere. CONFIRMED.**
`notes/activity/mvpa_weekly_plan.md:138-139` says `moderate_min`/`vigorous_min`/`mvpa_min`
are added to `DEFAULT_DAILY_METRICS` "so they appear in correlations" and `mvpa_min` to
`METRICS_HIGH_IS_GOOD`. The real set is `V2_DAILY_METRICS` (`analytics/metrics.py:31-56`)
and it contains **only** `mvpa_min`; the other two are `FLAG_DERIVED_METRICS` and are not
in the correlation set. `METRICS_HIGH_IS_GOOD` does not exist in the repo.

**D8 — three wrong details about the logging endpoint, in two notes. CONFIRMED.**
`notes/intake/late_eating_sleep.md:180,320` and `notes/intake/hydration_everyday.md:176,330`
say `manual_entry` accepts an **arbitrary** `kind` through **`/api/logs`**. The endpoint is
`/api/log` (`api/routers/logs.py:18`), the wire field is `type` (`read/logs.py:74`), and it
is a **10-value allowlist** (`read/logs.py:20-23`), not arbitrary. `"water"` and `"food"`
are both on it, so each note's substance survives.

**D9 — `mvpa_weekly_plan.md:142` reverses two wire field names. CONFIRMED.** It gives
`moderate_min_week`/`vigorous_min_week`; `read/fitness.py:185-192` ships
`week_moderate_min`/`week_vigorous_min`.

**D10 — `packages/knowledge/README.md:30-36` describes a corpus that no longer exists.
CONFIRMED.** It says the `notes/` collection is *"written to the older convention (numeric
grades: 3 (★★★) → Established … **no Honesty/Directives sections yet**)"* and counts 55
notes. All 49 citable notes carry a string `grade`, a `## Honesty & uncertainty` section,
a `## Coach Directives` block and a `## Healthee implementation & honesty policy` section
(structural scan, this audit). `evidence_grade` was removed in #83 and `make knowledge`
rejects it.

**D11 — research-shaped constants with no citing note.** Standards section 1: *"Every
constant derived from research cites its note."* CONFIRMED absent for each of:
`derive/energy.py:76` `AWAKE_ACTIVE_MET = 1.55` (the note's standing value is 1.8) and
`:77` `NEAT_WINDOW = 7`; `derive/vo2max_reserve.py:194` `_MIN_RESERVE_SPAN_BPM = 40.0` (no
comment at all); `derive/vo2max_submax.py:44-45` `MIN_R2 = 0.5` and `SPEED_CV_MAX = 0.20`
(absent from `submaximal_vo2max.md`'s implementation section, which documents every other
gate); `derive/hrv_spo2_resp.py:29,43` the HRV 5–200 ms and RR 4–40 br/min plausibility
bounds (SpO₂'s 70–100 **is** cited, at `wearable_spo2_validity.md:70`). Also
`analytics/correlations.py:39` `FDR_Q_THRESHOLD = 0.10` against
`analytics/cutoffs.py:38` `FDR_Q_THRESHOLD = 0.20` — one name, two values, two exploratory
surfaces, no note governing either. And the 12 Minetti 2002 gradient coefficients live
inline at `derive/vo2max_submax.py:88,92` with **no note-side copy anywhere**, so nothing
in the repo could catch a future typo — the pre-#108 SEE shape exactly. (I checked them
against Minetti 2002 and they are correct today.)

**D12 — a `Contested` note whose safety-critical core is stated as Established.
CONFIRMED (structural).** `sports-science/wellness/menstrual-cycle-and-training.md` is
graded `Contested`; its `:147` and `:153` carry *"**[Established]** Low energy availability
disrupts reproductive function"* and *"Low energy availability … **causes REDs**"*, and the
Bottom line at `:345` calls this *"the safety-critical core"*. Because
`insights/calibration.MIXED_RE` is keyed to the note grade,
`validator._grade_issue:161-162` will demand "debated/mixed/contested" framing of **every**
sentence citing this note, including one raising an amenorrhea red flag — and
`MIN_ACTIONABLE_RANK = 2` means a `Contested` note may never drive an action at all. This
is the #91 pattern (a claim whose required framing differs from its note's headline grade)
on a safety claim rather than a myth, and the fix the standards prescribe is the split that
produced `hydration_8x8_rule` and `napping_chronic_health`. It **fails safe** — a blocked
answer, not a wrong one — and `output_guard.py:169-180` compiles an independent REDs hard
stop, which is why it is D. The cost is that the corpus cannot say the true thing here.

**D13 — smaller residue, all CONFIRMED.** `notes/intake/hydration_everyday.md:8,29-34,262`
still states the 8×8 correction itself, while `:81-85` says *"this note simply stopped
being the one that states it"* and D3 at `:281` routes the question to the `Myth`-graded
note — so a coach grounding the correction here gets a hedge demanded, which is the exact
failure #91 closed. · `sports-science/metrics/running-form-metrics.md:158` says GRADE_RANK
*"lives once, in `insights/manifest.py`"*; it lives in `core/knowledge.py:42` and is
re-exported (`manifest.py:28`), so the path is reachable and the "lives once" claim is
still true. · `sports-science/wellness/environmental-stress.md:494` lists D12 among
guardrails that *"WOULD be worth mirroring in code"* while `:421-428` and `:326-340`
correctly say it **is** compiled. · `apps/mobile/lib/data/models/sleep_health.dart:141`
attributes the 7–9 h band to *"AASM adult recommendation"*; `sleep_duration_mortality.md:146-151`
attributes it to NSF 2015, and AASM's own figure is "≥ 7 h"
(`sleep_timing_chronotype.md:74`) — the file contradicts its own explainer's `uncited`
text. · `sleep_health.dart:159` states *"SRI over 14 nights"*; the window is 7
(`derive/sleep_score.py:41`, `SRI_DAYS = 7`) and 14 is the debt window. ·
`insights/manifest.py:182` says `note_body` is *"what a human gets when they open the ⓘ
sheet to read the evidence themselves, which PRICING section 1a keeps on the free tier"* —
**no endpoint serves it**; `note_body` has no caller outside `prompt_body`, and no router
under `api/routers/` exposes the corpus. The owner's only access to the sourcing is the
Dart explainer prose, which is why section A matters as much as it does.

**SUSPECTED (2).** `sports-science/metrics/running-form-metrics.md:85-110` marks
directives *"confidence: Established"* under `grade: Contested` — same tension as D12, but
every affected directive is a **restraint** ("never pool power across brands", "stay silent
on a metric the device doesn't record"), so a blocked sentence costs nothing; I did not
trace each to a live surface. The same file uses a `confidence: Established/Probable`
vocabulary where the rest of the corpus uses `(confidence: high)` — cosmetic drift, not
traced further.

---

## 3. Citations checked against their primary sources

The brief asked for the claims the product **acts on**, not all ~70 notes. These are the
ones a directive enforces, a threshold is derived from, or the coach can cite. Every one
below was checked against the source, not against another note.

| Claim | Note | Verdict |
|---|---|---|
| Jurca 2005 NASA model: `18.07 + 2.77·sex − 0.10·age − 0.17·BMI − 0.03·RHR + SRPA`; R = 0.81; SEE = **1.45 METs**; cross-validation R = **0.76** (ACLS) / **0.75** (ADNFS); SR-PA dummy-coded `0/0.32/1.06/1.76/3.03` | `non_exercise_vo2max.md:120-141,398-408` | **CONFIRMED.** The equation form and the 1.45 SEE are independently reproduced; the cross-validation Rs are reported verbatim as 0.76 and 0.75 for the NASA model applied to the other two cohorts — which is the quantity the note claims, and distinct from each cohort's own model (0.81/0.77/0.76). `derive/vo2max.py:313` matches term for term. **The #108 correction is sound and the note is right.** |
| Yin 2017: U-shaped, nadir **7 h**; RR **1.06** per 1-h reduction below; **1.13** per 1-h increment above | `biological_age_estimate.md:60` | **CONFIRMED verbatim.** `analytics/biological_age.py:165-167` matches exactly. |
| Libert 2025: UK Biobank mortality *"doubling every **7.7 years** for both males and females"* | `biological_age_estimate.md:82-86` | **CONFIRMED verbatim** in the paper's Results. `GOMPERTZ_MRDT_YEARS = 7.7` (`biological_age.py:159`). |
| Paluch 2022: 15 international cohorts, n = **47,471**; plateau **8,000–10,000** under 60, **6,000–8,000** at 60+ | `steps_mortality.md:23-24,74-75` | **CONFIRMED** (cohort count, n, and both age bands). The HR 0.49 (0.41–0.59) sub-claim at `:52` I could not confirm from open sources — SUSPECTED, and it is not a number the product acts on. |
| Drake 2013: 400 mg at **0/3/6 h** before bed all significant vs placebo; **>1 h** total sleep time lost at 6 h out | `caffeine_sleep.md:57-67` | **CONFIRMED verbatim**, including the study's own conclusion that it supports a **6-hour** abstinence recommendation — which is where the note's cutoff comes from, and the note says so at `:40-41` rather than deriving it from the half-life. |

Two citation defects were found, and both are reported above rather than here because they
are not "the paper says otherwise" — they are **a claim with no paper at all** (B5, B6),
**a withdrawn figure still in print** (B1, B3), and **a real paper credited with a
comparator it does not make** (A3, in the app).

---

## 4. What I swept clean

A swept class is a result. Each of these was checked with evidence and produced no finding.

1. **The Honesty section, all 78 manifest notes.** Present in every one, and **not one is
   decorative** — no "individual variation applies" boilerplate; every section names a
   specific confounder, population gap, or thing the metric cannot say. Reference
   implementations, for anyone calibrating: `hydration_8x8_rule.md` (a Myth note that owns
   the correction flatly, mandates both of Valtin's limits in the same breath, and admits
   only the abstract was read); `napping_chronic_health.md` (*"Hold loosely: literally
   every effect estimate on this page"*); `late_eating_sleep.md` (*"This note cannot be
   resolved with current evidence, and that is the finding"*, plus an Honesty section that
   records a **removal**).
2. **Grade calibration, the reverse direction: zero instances.** No Established note hedges
   its own Summary or "Act on confidently" line.
3. **`Contested` framing in `notes/`: all four correct.** `hr_reserve_vo2max`,
   `late_eating_sleep`, `napping_chronic_health` and (in `sports-science/`)
   `training-load-acwr`, `running-form-metrics` and `menstrual-cycle-and-training` all
   present the disputed core as disputed in their own prose.
4. **The `@daud/core` prose class is genuinely purged (#87).** All 94 surviving mentions
   across 32 files are explicit *"a module that exists in no repo"* disclaimers. Not one
   note asserts enforcement in it.
5. **The `safety_critical` bijection holds, end to end, both directions.** Five markers
   (`napping` D5, `hydration_everyday` D5/D6, `late_eating_sleep` D5,
   `environmental_stress` D12), five compiled rules, each directive carrying
   **SAFETY-CRITICAL** in its own text, each reached through `output_guard.output_rules()`,
   with `gen_manifest.py:260` refusing a marker whose directive does not say it and
   `tests/insights/test_guard_directives.py` asserting set equality both ways plus a
   not-vacuously-satisfied test. B2 is a defect in what two *other* notes claim **about**
   this mechanism, not in the mechanism.
6. **The `training-load-acwr` precedent is closed.** `read/acwr.py:16-22` carries
   `_ACWR_MIN_CHRONIC_DAYS = 28`, `:82` suppresses on short history and `:90` on
   `chronic <= 0` — the note's D6, both limbs, with the derivation of "≈ 0" written out
   rather than an invented epsilon.
7. **`notes/protocol/*.md` (5 files) are correctly outside the corpus.**
   `gen_manifest.py:326-330` returns `None` for a doc with no `id` (*"engineering/protocol
   reference — not citable evidence"*); all five land in `skipped`, are never indexed,
   never retrieved, never prompt-embedded. Verified against the loader, not assumed. One
   caveat worth recording: the exclusion keys on **absence of an `id`**, not on the
   directory, so adding an `id` to a protocol note would silently make it citable.
8. **The sports-science bibliographies exist.** All 33 carry one — 32 under
   `## Key references`, `heart-rate-variability.md` under `## References` — with 8–19 full
   entries each, and the highest inline-citation density in the corpus.
   `manifest.py:162`'s `_BIBLIOGRAPHY` regex matches both spellings, so prompt-stripping
   works on all of them.
9. **Every `applies_to_metrics` name but one resolves.** 31 distinct metrics claimed across
   the manifest, checked against `derive/`, `analytics/`, `read/` and `schema.sql`. Only
   `strength_min_weekly` (C4) is missing.
10. **The app's note ids all resolve, and the test that says so is genuine.** All 36
    distinct ids across the 17 explainers exist in `manifest.json`, and
    `apps/mobile/test/shared/note_names_test.dart:23,114-118` reads
    `../../packages/knowledge/manifest.json` **out of the repo** and asserts `kNoteNames`
    and `kNoteGrades` equal it id-for-id and grade-for-grade. This half of the grounding
    pass is sound.
11. **The three legacy explainer defects are genuinely gone.** `grep` confirms "~7,500",
    "16%" and "1,760" appear nowhere in `apps/mobile/lib/`. The steps card is now
    exemplary — `explainers_body.dart:55-71` carries the age-banded plateau verbatim from
    `steps_mortality.md:23-25`, calls 10,000 a marketing artefact, says cadence adds
    nothing beyond volume, and prints **no** death-risk number. It is the same directive
    the MVPA card two entries below breaks (A1), which is what makes A1 a lapse rather
    than a house style.
12. **Seven explainers are fully clean, both ends read.** `spo2` (the ~92% routing, the
    "clinical convention, not a wearable-validated cutoff", the unquantified device error
    and the dark-skin bias are `wearable_spo2_validity.md:45-46` and D2/D5 near-verbatim —
    and it is *ahead* of its own note, see B1); `stress` (arousal-not-valence, HR-dominated,
    the confounder list, and "no consumer stress score has been validated on our
    Huami/Zepp hardware"); `rhr_daily` (60–100 / 60–80 / 50–65 from
    `resting-heart-rate.md:24-25`, with the `why` deliberately carrying **no** number,
    satisfying D13); `resp`; `recovery`; `recovery_score`; `steps_total`. `biological_age`
    is clean on every checked sentence (Gompertz 7.7 y, ±10 y cap, PhenoAge, and the
    questionnaire-conversion caveat verbatim from `biological_age_estimate.md:248-252`).
13. **The numeric corpus↔code agreement is broad.** Verified matching on both ends, beyond
    the citations in section 3: the full Jurca gate set (MAD > 8 bpm, RHR 40–100, age
    20–70, BMI 16–45, floor 20) · Tanaka `208 − 0.7·age` in all three consumers
    (`cardio_load.py:34`, `gps.py:216`, `vo2max_submax.py`) · %HRR reserve 0.35–0.95, ≥6
    windows, 20–85 output guard, VO₂rest 3.5, running-only refusal · Carrier 2023 MAPE
    6.85% · the 14-day measured-VO₂max and weight horizons (`freshness.py:178,233`) ·
    Banister TRIMP `0.64·e^1.92ΔHR` / `0.86·e^1.67ΔHR` · Edwards 50/60/70/80/90 with 1–5
    weights · strain `21·(load/P95)^0.75` over a 90-day P95 · bio-age MRDT 7.7, ±10 y cap,
    0.85/MET, the FRIEND medians cell by cell, the Lauderdale conversion `3.2 − 0.4·h`
    clamped 0–1.2 (checks out at both of the note's worked points), and the regularity term
    correctly **absent** with a build-failing test guarding the deletion · recovery weights
    0.42/0.28/0.20/0.10, k = 20/20/15, 42-day window, ≥5 points, 0.5 SD floor,
    renormalisation, `None` without HRV-or-RHR · **every** illness-flag number (14/10
    nights, RR +2.0/+1.5 sustained, temp +0.5, MAD ×1.5/×2.0) · sleep 7.0–9.0 h, 0.85
    efficiency, 2–4 h midpoint, SRI ≥ 70 (correctly labelled *derived, not cited* in three
    places), the SRI formula and its 66.67 known-value test, need 480/450, 14-night debt
    window, 0.5 recovery credit · cadence 100/80/130/110 spm · stride 0.414 · Mifflin–St
    Jeor 10/6.25/5/±161 and ACSM `0.1·speed + 3.5` switching at 134 m/min · strength 30–60
    min/wk · the VO₂max projection `clamp(0.4×gap, 2, 5)`.
14. **`apps/mobile/lib/analytics/` is empty** (`.gitkeep` and a README). There is no
    on-device analytics engine yet, so there is no second implementation of any of these
    numbers to disagree with the server. The mobile numeric surface is
    `lib/shared/metric_info/` alone.

---

## 5. What I could not determine

1. **Whether any of section A's sentences has actually been read by the owner.** The
   explainers are on cards behind an ⓘ; which ones he has opened is not knowable from the
   repo, and I did not touch the device.
2. **Whether the Paluch 2022 HR 0.49 (0.41–0.59) figure at `steps_mortality.md:52` is the
   paper's.** The pooled cohort count, n, and both age bands are confirmed; this specific
   quartile comparison is behind a paywall in the sources I could reach. Marked SUSPECTED.
   It is not a number the product acts on — no gate reads it and no directive permits
   printing it.

---

## 6. Recommended order

Not a plan, a ranking — by how directly a false claim reaches the owner.

1. **A1, A2, A3.** Two forbidden death-risk numbers and one mis-attributed comparator, on
   screen, on the two cards whose evidence is strongest. `output_guard` already blocks the
   model from writing exactly these; the Dart strings are the unguarded channel.
2. **A4.** The only finding on that screen that prose care cannot catch —
   `weakestGrade(_notes)` plus a test over the merged list.
3. **A5, A6, A7.** A disclaimer that is backwards, a gloss that inverts the advice, and a
   sentence contradicted three lines later.
4. **B1.** Finish #98: the correct sentence is written at `:45` and needs to reach the
   frontmatter summary and four other places, one of which instructs the coach to state
   the withdrawn figure.
5. **B2.** Qualify the two directive lines to what the compiled rule actually recognises.
   A false safety claim inside the safety system is the one the standards single out.
6. **C1, C5.** The two places a gate misbehaves: a sleep ceiling below the owner's own
   need, and the one function in `derive/` that fabricates an input instead of withholding
   (and reads it with no freshness bound).
7. **B5, B6, B7.** Source the two figures or withdraw them; change four causal verbs to the
   corpus's own established voice.
8. **C7.** The one place the **code** should move: add `value > 25` to
   `read/sleep_extras.py:95`.
9. **The rest of B, C and D** as corpus corrections. Two of them — B3's withdrawn Jurca
   figures reappearing in a second note and a code docstring, and `challenges/targets.py:101-103`
   justifying the steps target with a *"~7,000–8,000"* band that appears in **no** note —
   are the same retracted-figure pattern surviving a fix in a place the fix did not look.
   That is a candidate for a check rather than a one-off edit: a withdrawn number is worth
   pinning by test, the way `MEASURED_HORIZON` and the bio-age regularity deletion already
   are.
