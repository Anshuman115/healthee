---
id: llm_health_advice_safety
name: "LLM health-advice safety guardrails"
topic: Safety guardrails for LLM-generated health recommendations — what we will and will not do
category: recs
grade: Probable
evidence_grade: 2
summary: "LLMs pass medical exams yet hallucinate confident-but-wrong medical content and miscalibrate uncertainty, so the recs layer only SYNTHESIZES the user's own findings into cited action items — never diagnoses, doses, interprets symptoms, or projects personal mortality — with every claim post-hoc validated against repo notes and mental-health emergencies routed to a static hotline. Safety-critical guardrails, mirrored in code."
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
concise. This is a **safety process note** (`applies_to_metrics: []`): its
directives are SAFETY-CRITICAL and mirrored as hard guardrails in code, never
overridable by the LLM.

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
the post-hoc citation validator (`llm/validator.py`), the safety keyword filter,
and the mental-health-emergency static-fallback path.

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
6. Produce recommendations on mental-health emergencies. If a logged mood is <2/10
   or a logged note flags self-harm keywords, the recs engine pauses and surfaces a
   static "consider talking to a professional or hotline" card with a hotline
   reference — no LLM call.
7. Reference research notes not present in the repository. Notes must be loaded by
   `research.py` and the citation validator must confirm a match. Hallucinated paper
   titles → recommendation dropped.
8. Run if the LLM API is degraded — degraded calls timeout fast; the system shows
   yesterday's recommendations with a "no fresh recs today" indicator. Never
   auto-substitute a fallback model that wasn't validated.

## Safety bounds

All eight WON'T items above are **SAFETY-CRITICAL** hard guardrails, mirrored in
code and never overridable by the LLM. In particular:
- **No diagnosis, no medication/dosing/supplements, no clinical procedures/tests,
  no symptom interpretation.**
- **No individual mortality-risk projection** — population HRs may be cited but "you
  have an X% mortality risk" is forbidden.
- **Mental-health-emergency path** (mood <2/10 or self-harm keywords) bypasses the
  LLM entirely and shows a static hotline card.
- **No unvalidated fallback model** on API degradation.

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
mortality outright, and route mental-health emergencies to a static hotline. These
are hard, code-mirrored guardrails.

**Hold loosely:** the specific benchmark numbers (obsolete fast), and whether the
tool measurably helps users live better (essentially unmeasured) — but the
guardrails hold regardless.

## Coach Directives

1. **SAFETY-CRITICAL:** never diagnose or name a condition; surface signals only.
   *(confidence: high)*
2. **SAFETY-CRITICAL:** never recommend or modify medication, dosing, or supplements
   (including "consider magnesium"). *(high)*
3. **SAFETY-CRITICAL:** never recommend specific clinical procedures/tests, and
   never interpret logged symptoms causally. *(high)*
4. **SAFETY-CRITICAL:** never make an individual mortality/risk projection;
   population HRs may be cited as "associated with," never "you have X% risk."
   *(high)*
5. **SAFETY-CRITICAL:** on a mental-health emergency (mood <2/10 or self-harm
   keywords), bypass the LLM and show the static hotline card — no LLM call. *(high)*
6. **SAFETY-CRITICAL:** cite a repo research note for every claim; uncited → 1 retry
   → drop; never reference a note not loaded by `research.py`. *(high)*
7. **SAFETY-CRITICAL:** on LLM/API degradation, show yesterday's recs with a "no
   fresh recs today" indicator; never auto-substitute an unvalidated fallback model.
   *(high)*

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
  dashboard hides the card.

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
  behavior, not a derived metric. Provenance: `llm/validator.py` (post-hoc citation
  check), the safety keyword filter, the mental-health static-fallback path, the
  `RECS_ENABLED` kill switch, and the per-recommendation audit log.
- **All eight WON'T items and Directives 1–7 are SAFETY-CRITICAL hard guardrails**
  mirrored in server code — they can never be overridden by the LLM. This is the
  binding standard from ENGINEERING_STANDARDS §4 ("safety-critical directives are
  hard guardrails in code").
- Honesty rules for the user: the "not medical advice / cite-tap the study" footer
  is mandatory; the displayed evidence grade is the cited note's grade; nothing
  below grade 2 ships; and personal mortality projections are forbidden while
  population HRs may be cited as "associated with."
