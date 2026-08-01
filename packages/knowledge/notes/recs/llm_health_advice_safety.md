---
id: llm_health_advice_safety
name: "LLM health-advice safety guardrails"
topic: Safety guardrails for LLM-generated health recommendations — what we will and will not do
category: recs
grade: Probable
summary: "LLMs pass medical exams yet hallucinate confident-but-wrong medical content and miscalibrate uncertainty, so the recs layer only SYNTHESIZES the user's own findings into cited action items — never diagnoses, doses, interprets symptoms, or projects personal mortality — with every claim post-hoc validated against repo notes and mental-health emergencies classified BEFORE any model call and answered with a fixed refusal (which names a professional or physician — it carries no hotline number). The directives are safety-critical; SOME are genuinely enforced in code and some are not, and the note says which, item by item — do not read it as a blanket guarantee (#87)."
aliases: ["llm safety", "ai health advice", "recs safety", "guardrails", "cite-or-dont-say"]
applies_to_metrics: []
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
related: ["recommendations_engine_plan", "behavior_change_and_personalization"]
tags: [recs, llm, safety, guardrails]
---

# LLM health-advice safety guardrails

## Summary

Recent large language models (LLMs) can pass medical licensing exams (Singhal 2023,
Med-PaLM 2: 86.5% on USMLE-style questions) and produce clinically reasonable
diagnostic reasoning in controlled settings (Tu 2024, AMIE). **But** they also
hallucinate plausible-sounding medical content, fail systematically at uncertainty
quantification, and amplify confident-but-wrong responses when prompted to be
concise. This is a **safety process note** (`applies_to_metrics: []`): its directives
are SAFETY-CRITICAL, and **some of them — not all — are genuinely enforced in code**.
*Safety bounds* below says which, item by item; do not read this note as a blanket
guarantee. (Corrected 2026-08-01, #87: this paragraph asserted all of them were
"mirrored as hard guardrails in code, never overridable by the LLM". The frontmatter
`summary` still carries the old wording and needs the same fix.)

## What it is

The safe-deployment contract for the recs/coach LLM layer. For a personal-use,
evidence-grounded recommendations layer like this project's, the safe-deployment
principle is:

> The LLM **synthesizes** user-specific findings into action items.
> It does **not** produce novel medical claims, diagnoses, drug or
> dosage recommendations, or symptom interpretation.
> Every assertion is post-hoc validated against the research notes
> already in the project; uncited claims trigger a retry, then drop.

## Physiology / mechanism

Not physiological — the "mechanism" of harm is **model behavior**: LLMs are trained
to produce fluent, confident text and are miscalibrated about their own uncertainty,
so they generate authoritative-sounding but wrong medical content, worst under
brevity pressure. The mitigation mechanism is architectural: constrain the model to
*synthesis only* and gate every claim through a post-hoc citation validator against
repo notes, so confidence cannot substitute for grounding.

## The evidence — where LLMs work and where they fail

### LLMs can match experts on benchmarks — but still hallucinate [Probable]
- **Singhal 2023** (Nature, Med-PaLM 2): **86.5% on USMLE-MedQA**; expert reviewers
  preferred Med-PaLM 2 answers over physician answers on consumer health questions
  in **8 of 9 axes** (clinical accuracy, comprehensiveness, etc.). **But**: residual
  hallucination rate **~3–5%** on consumer-health questions and higher on
  rare-disease prompts.
- **Tu 2024** (AMIE): in simulated patient conversations, AMIE matched/exceeded
  primary-care-physician diagnostic accuracy on text-based history-taking. **But**:
  simulated patients, not real ones; not validated for actionable recommendations.

### Factual-error and over-confidence rates are non-trivial [Probable]
- **Goodman 2023** (JAMA Netw Open, n=180 physician questions to GPT-3.5): **22% of
  responses had at least one factual inaccuracy**; the inaccuracies were graded
  mild-to-moderate but some had safety implications.
- **Birkun 2023** (Nutrients): ChatGPT-generated nutrition advice had **~30%
  factually questionable claims** that experts flagged on audit.
- **Lee 2024** (NEJM AI): GPT-4 mortality and risk predictions **systematically
  over-confident** vs validated risk scores.

## How we compute it

Not a computed metric — this note defines the WILL/WON'T contract and the
engineering guardrails the recs engine (`recommendations_engine_plan`) enforces via
the post-hoc citation validator, the safety keyword filter, and the
mental-health-emergency static-fallback path. In the rebuild those live at
`apps/server/src/healthee/insights/validator.py`, `jobs/recs.py::_BANNED_RE` and
`insights/refusals.py` respectively — the `llm/validator.py` path this note used to
name is the legacy repo's (#87, 2026-08-01).

## How the coach uses it — what the recs engine WILL and WON'T do

**WILL:**
1. Synthesize 1–3 daily action items from the user's own data (anomalies, findings,
   sleep debt, MVPA gap, illness flag, caffeine cutoff, VO2max trend).
2. Cite a research note ID for every claim in every recommendation (BCT 5.1 — see
   `behavior_change_and_personalization`).
3. Use the existing post-hoc citation validator from `llm/validator.py` (uncited
   claims → 1 retry with stricter prompt → drop if still uncited).
4. Surface evidence grade visibly (★★★ vs ★★).
5. Frame as suggestions, not prescriptions ("Consider going to bed 90 min earlier
   tonight — your sleep debt is 4.2 h, sleep before midnight historically restores
   efficiency in your data").
6. Track adoption (user marks adopted / dismissed). Tune over time.

**WILL NOT:**
1. Diagnose. Period. Even if data strongly suggests illness, the illness flag
   surfaces signals (RR up, skin temp up) — it does not name a condition.
2. Recommend or modify medication, dosing, or supplements. Including "consider
   taking magnesium" — too close to dosing.
3. Recommend specific clinical procedures or tests.
4. Interpret symptoms the user logs (e.g., a manual "headache" note triggers no
   causal recommendation).
5. Make mortality risk projections for the user as an individual. Population HRs
   from research notes can be cited; "you have an X% mortality risk" is forbidden.
6. Produce recommendations on mental-health emergencies. A question mentioning
   self-harm, suicide, depression, anxiety, panic, hopelessness or "can't cope" is
   classified before any model call and answered with a fixed refusal — no LLM call.
   *(#87, 2026-08-01: two details here were wrong. The **mood <2/10 trigger does not
   exist** — nothing in the server reads a logged mood, so the pause is keyword-driven
   only, on the question. And the static response **carries no hotline number**; it
   names a mental-health professional or physician. Do not promise the user a hotline
   this product does not hand them.)*
7. Reference research notes not present in the repository. Notes must be loaded by
   `research.py` and the citation validator must confirm a match. Hallucinated paper
   titles → recommendation dropped.
8. Run if the LLM API is degraded — degraded calls timeout fast. Never auto-substitute
   a fallback model that wasn't validated. *(#87, 2026-08-01: this item used to promise
   "the system shows yesterday's recommendations with a 'no fresh recs today'
   indicator". **The code does the opposite, deliberately**:
   `jobs/recs.py::_no_grounded_output` clears the stale rows and persists an empty day,
   so a bad day is a visibly empty day rather than yesterday's advice masquerading as
   today's. The code's behaviour is the honest one; the note was describing a legacy
   plan. Corrected to match what ships.)*

## Safety bounds

All eight WON'T items above are **SAFETY-CRITICAL**. This section used to say they were
all "mirrored in code and never overridable by the LLM". That was too strong, and in a
safety note the over-claim is the dangerous direction: an auditor reads it, believes the
enforcement exists, and stops looking. **Item by item, verified against the tree
2026-08-01 (#87):**

- **Individual mortality-risk projection — ENFORCED, on every LLM surface.**
  `insights/output_guard.py`'s `personal_death_risk_number` and
  `personal_life_expectancy_projection` block the answer when one sentence carries both
  a second person ("you"/"your") and a death-risk figure or a life-expectancy
  projection. It fires regardless of citations, grade, refusal status or validator
  outcome. Population HRs without a "you" still ship, by design.
- **Mental-health emergency — ENFORCED, on the incoming question.**
  `insights/refusals.py` classifies the question first and `insights/grounded.py`
  returns the template without calling the model, so it cannot be prompted or jailbroken
  past. Its trigger is keywords in the question, **not** a logged mood, and the response
  **contains no hotline number**.
- **Advising through a red-flag symptom, and bone-stress / REDs — ENFORCED**, though
  they are not phrased as WON'T items here: `output_guard.py`'s
  `advise_through_red_flag_symptom` and `advise_through_bone_stress_or_reds` block the
  answer, and `advise_sleep_restriction` blocks prescribed sleep restriction.
- **No diagnosis · no medication/dosing/supplements · no symptom interpretation —
  ENFORCED ON TWO PATHS, NOT ON THE COACH'S PROSE.** `insights/refusals.py` refuses a
  *question* that asks for a diagnosis or a medication decision, and
  `jobs/recs.py::_BANNED_RE` drops any generated *recommendation* containing
  mg/dose/dosing/prescri/diagnos/symptom/medication/supplement/medicine/drug/pill/
  tablet. There is **no output rule** stopping the conversational coach from naming a
  condition or interpreting a logged symptom in prose. That gap is real; treat these as
  strong rules with partial mechanical backing, not guarantees.
- **No clinical procedures or tests — NOT ENFORCED, beyond one narrow case.** The
  refusal classifier catches "interpret my labs/results/blood"; nothing filters an
  answer that recommends an MRI, a blood panel or a sleep study. This is the weakest
  item in the list.
- **Every claim cites a repo note; no note outside the repo — ENFORCED.** The citation
  validator gates every grounded answer, and `jobs/recs.py::_shippable_rec`
  additionally drops a rec missing an inline `[note_id]` or citing an id the manifest
  does not know.
- **No unvalidated fallback model on API degradation — NOT ENFORCED as a check.** No
  code chooses a substitute model, so nothing today violates it; but nothing stops a
  future edit either. It is a design commitment, not a guardrail.

**Why the difference matters mechanically.** Only directives a note declares
`safety_critical` in its frontmatter compile into `insights/guard_directives.py` with a
test asserting a rule exists for every marker. **This note declares none** — everything
enforced above is hand-compiled in `output_guard.py` or lives in the recs job, and
nothing fails the build if it is deleted. Directives 1–4 are strong candidates for the
`safety_critical` mechanism.

## Honesty & uncertainty

Evidence grade is ★★, not ★★★, because:
- The fast pace of model iteration makes individual benchmark results obsolete
  quickly.
- Most safety studies are on physician-facing tools; consumer self-management tools
  are under-studied.
- Real-world deployment outcomes (does it help users live better) are essentially
  unmeasured outside small RCTs.

LLMs' **uncertainty miscalibration** is the biggest practical risk. They will
produce confident-sounding text about things they don't know. The cite-or-don't-say
guardrail addresses this for our context but doesn't fully eliminate it.

## Bottom line

**Act on confidently:** constrain the LLM to synthesis-only, validate every claim
against repo notes, refuse diagnosis/dosing/symptom-interpretation/personal-
mortality outright, and route mental-health emergencies to a static refusal. **Some of
these are code-enforced and some are not** — the personal-mortality block, the
mental-health routing and the citation gate are real code; diagnosis/dosing/symptom
interpretation are enforced only on the question and on generated recs, not on coach
prose. See *Safety bounds* for the item-by-item ledger (#87).

**Hold loosely:** the specific benchmark numbers (obsolete fast), and whether the
tool measurably helps users live better (essentially unmeasured) — and, per *Safety
bounds*, exactly how much of this contract a machine holds versus a prompt.

## Coach Directives

Each directive is annotated with what code, if any, backs it (#87, 2026-08-01) — the
detail is in *Safety bounds*.

1. **SAFETY-CRITICAL:** never diagnose or name a condition; surface signals only.
   *(confidence: high; enforced on the incoming question by `insights/refusals.py` and
   on generated recs by `jobs/recs.py::_BANNED_RE` — NOT on the coach's prose)*
2. **SAFETY-CRITICAL:** never recommend or modify medication, dosing, or supplements
   (including "consider magnesium"). *(high; same two paths as D1 — NOT on coach prose)*
3. **SAFETY-CRITICAL:** never recommend specific clinical procedures/tests, and
   never interpret logged symptoms causally. *(high; symptom interpretation is dropped
   from recs by the keyword filter, but **procedures/tests are not enforced anywhere** —
   the weakest item in this note)*
4. **SAFETY-CRITICAL:** never make an individual mortality/risk projection;
   population HRs may be cited as "associated with," never "you have X% risk."
   *(high; **enforced on every LLM surface** by `insights/output_guard.py`)*
5. **SAFETY-CRITICAL:** on a mental-health emergency (self-harm, suicide, or a
   mental-health-crisis keyword in the question), bypass the LLM and return the static
   refusal — no LLM call. *(high; **enforced** by `insights/refusals.py`. Corrected:
   there is no mood <2/10 trigger and the response carries no hotline number.)*
6. **SAFETY-CRITICAL:** cite a repo research note for every claim; uncited → drop;
   never reference a note the manifest does not know. *(high; **enforced** by
   `insights/validator.py` + `jobs/recs.py::_shippable_rec`. `research.py` was the
   legacy loader; the rebuild's index is `insights/manifest.py`.)*
7. **SAFETY-CRITICAL:** on LLM/API degradation, never auto-substitute an unvalidated
   fallback model; ship an empty day rather than stale advice. *(high; the empty-day
   behaviour **is** what `jobs/recs.py::_no_grounded_output` does — the old "show
   yesterday's recs" wording described a legacy plan the rebuild deliberately dropped.
   The no-fallback-model half is a design commitment, not a check.)*

## Implementation guardrails (engineering)

- **Model**: Sonnet via OpenRouter per `llm_model_preference` /
  feedback_llm_model_choice.md. Never Opus by default.
- **System prompt**: ships citation requirement in every prompt; retries with
  stricter wording once if validation fails.
- **Output schema**: structured JSON `{action: string, rationale: string,
  evidence_grade: 2|3, research_note_ids: string[], expected_effect: string}`.
- **Validator**: every recommendation must cite ≥1 note ID that exists in
  `research/`; the note's `evidence_grade` is the displayed grade; falls below 2 →
  recommendation dropped.
- **Rate limit**: one batch / day max; manual `healthee recs recompute --force` is
  the only override.
- **Audit log**: persist the LLM prompt + raw response per recommendation so we can
  review failure modes.
- **Kill switch**: env var `RECS_ENABLED=0` disables the engine entirely and the
  dashboard hides the card. **NOT BUILT** — no `RECS_ENABLED` setting exists in the
  server (#87, 2026-08-01). Planned control, not a shipped one.

## Honest framing for the user

The Today recs card should carry a one-line footer:

> "AI-synthesized from your data + research notes. Not medical
>  advice. Cite-tap to read the underlying study."

## References
- **Singhal K, Azizi S, Tu T, et al.** *Large language models encode clinical
  knowledge.* Nature 2023;620:172–180.
- **Tu T, Schaekermann M, Palepu A, et al.** *Towards conversational diagnostic AI.*
  arXiv:2401.05654 (2024). Google AMIE; not yet peer-reviewed.
- **Goodman RS, Patrinely JR, Stone CA, et al.** *Accuracy and reliability of chatbot
  responses to physician questions.* JAMA Netw Open 2023;6(10):e2336483.
- **Birkun AA, et al.** ChatGPT-generated nutrition advice audit. *Nutrients* 2023.
  ~30% factually questionable claims flagged by experts.
- **Lee et al.** GPT-4 mortality/risk-prediction over-confidence vs validated risk
  scores. *NEJM AI* 2024.
- **Howell MD, Corrado GS, DeSalvo KB.** *Three epochs of artificial intelligence in
  health care.* JAMA 2024;331(3):242–244. Sets the framing for safe deployment.
- **FDA 2023.** *Marketing Submission Recommendations for a Predetermined Change
  Control Plan for Artificial Intelligence/Machine Learning (AI/ML)-Enabled Device
  Software Functions.* — This project is **not** a medical device and explicitly
  opts out of any clinical claim space.

## Healthee implementation & honesty policy

- **No `applies_to_metrics`** — this note governs the recs/coach LLM layer's safety
  behavior, not a derived metric. Provenance in the rebuild:
  `insights/validator.py` (post-hoc citation check), `insights/output_guard.py` (the
  hard output rules), `insights/refusals.py` (the pre-LLM refusal classifier),
  `jobs/recs.py::_BANNED_RE` (the safety keyword filter) and the per-recommendation
  audit row. The `llm/validator.py` path and the `RECS_ENABLED` kill switch named here
  before are legacy / unbuilt respectively (#87).
- **All eight WON'T items and Directives 1–7 are SAFETY-CRITICAL — but only some are
  enforced in server code.** This bullet claimed all of them were mirrored and could
  never be overridden by the LLM; *Safety bounds* now carries the item-by-item ledger of
  which are and which are not (#87, 2026-08-01). ENGINEERING_STANDARDS §4 is the binding
  standard, and it is explicit that the mechanism is a declared `safety_critical`
  marker compiling into `insights/guard_directives.py` — **this note declares none**, so
  what enforcement exists here is hand-compiled and untested against the note. Closing
  that gap is owed work, and until it is closed the honest sentence is this one.
- Honesty rules for the user: the "not medical advice / cite-tap the study" footer
  is mandatory; the displayed evidence grade is the cited note's grade; nothing
  below grade 2 ships; and personal mortality projections are forbidden while
  population HRs may be cited as "associated with."
