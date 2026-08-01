---
id: recommendations_engine_plan
name: "Daily AI recommendations engine (implementation plan)"
topic: Implementation plan — daily AI recommendations engine that synthesizes findings into 1–3 action items
category: recs
grade: Probable
summary: "Implementation plan for a daily batch recs engine: reads the user's own signals, calls the LLM through the cite-or-don't-say choke point + post-hoc validator, persists 1–3 cited action items with adoption tracking, and renders them on Today + a recommendations page — governed by the safety and behavior-change notes, not by any metric."
aliases: ["recommendations engine", "recs engine", "daily recommendations", "implementation", "dashboard"]
applies_to_metrics: []
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
related: ["llm_health_advice_safety", "behavior_change_and_personalization"]
tags: [implementation, recs, llm, dashboard]
---

# Daily AI recommendations engine (implementation plan)

## Summary

Build a **daily batch** recommendations engine that runs at ~07:00 IST after the
morning HC sleep upload. It reads the user's current state + recent findings + new
signals, calls Sonnet via OpenRouter with a strict **cite-or-don't-say** system
prompt + post-hoc validator, persists **1–3 daily action items**, and renders them
as a card on Today + a `/recommendations` page with full history and adoption
tracking. This is a **process/guardrail note**: it backs the recs engine's
behavior, not a metric (`applies_to_metrics: []`). Its hard constraints come from
`llm_health_advice_safety` and `behavior_change_and_personalization`.

## What it is

A batch synthesis layer, not a chatbot: once a day it turns the user's own data
into at most three cited, adopt/dismiss-tracked suggestions. Every claim cites a
research note that exists in the repo; no diagnosis, dosing, medication, or
supplement recommendations; personal and progress-framed, never deficit language.

## Physiology / mechanism

Not a physiological note — the "mechanism" here is the pipeline: signals in →
grounded LLM synthesis through the citation choke point → post-hoc validation →
persisted, adoption-tracked cards. Every downstream safety property derives from
routing every claim through the validator against `research.load_all()` and from
the behavior-change design rules, not from model trust.

## The evidence

The design claims below are graded; the underlying research lives in the two
sibling notes this plan is gated on.

- Cite-or-don't-say grounding + post-hoc validation is the safe-deployment
  principle for an LLM recs layer [Probable — see `llm_health_advice_safety`].
- Personalized, self-monitoring + goal + discrepancy framing with ≤3 actions/day
  is what actually moves behavior [Established — see
  `behavior_change_and_personalization`].
- The plan itself carries no independent primary citations (it is an
  implementation spec); its evidence grade (★★) reflects that it is a design of
  record, not a measured outcome.

## How we compute it

Hard constraints from `llm_health_advice_safety` + `behavior_change_and_personalization`:

- Every claim cites a research note that exists in the repo.
- No diagnosis, dosing, medication, supplement recommendations.
- Personal + progress-framed; no deficit language.
- 1–3 actions/day max.
- Adopt/dismiss tracked; learns over time which categories resonate.

### Inputs (signals the engine reads per run)

| Source                          | What it carries                          |
|---------------------------------|------------------------------------------|
| `metric_sample.sleep_health_score_4dim` (last 7d) | sleep score trend |
| Sleep debt (last 7d shortfall vs 7–9h band) | from `/api/sleep` derive |
| `finding(kind='personal_cutoff')`           | caffeine/alcohol cutoff (Phase 1a) |
| Weekly `mvpa_min` total + gap to 150        | Phase 1b |
| Weekly `strength_min_weekly`                | Phase 1c |
| `vo2max_estimate` 90-day Δ                  | Phase 2 |
| `illness_flag` (if active)                  | Phase 3 |
| `anomalies` (last 3 days)                   | existing engine |
| `finding(top 5)`                             | existing correlations |
| User profile (age, sex)                     | for personalization |
| Adoption history of last 30 days of recs    | tune signal strength |

### Output schema (DB)

```sql
CREATE TABLE IF NOT EXISTS recommendation (
    id                BIGSERIAL PRIMARY KEY,
    date              DATE NOT NULL,
    rank              INT NOT NULL,            -- 1, 2, 3
    action            TEXT NOT NULL,           -- one-line directive
    rationale         TEXT NOT NULL,           -- with cited research
    expected_effect   TEXT,                    -- "+30 min TST tonight"
    category          TEXT NOT NULL,           -- sleep|activity|recovery|intake|fitness
    evidence_grade    INT NOT NULL CHECK (evidence_grade IN (2, 3)),
    research_note_ids TEXT[] NOT NULL,
    signal_source     TEXT NOT NULL,           -- which input triggered this
    raw_llm_response  JSONB,                   -- audit trail
    raw_llm_prompt    TEXT,                    -- audit trail
    adopted           BOOLEAN,                  -- NULL=untouched, true=adopted, false=dismissed
    adopted_at        TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (date, rank)
);
CREATE INDEX IF NOT EXISTS recommendation_date_idx ON recommendation (date DESC);
```

### LLM prompt structure

System prompt (locked, in `src/healthee/llm/recs_prompt.py`):

```
You are the recommendations engine for a personal health dashboard.

GROUND RULES (non-negotiable):
- Cite a research note ID for every claim. The notes available to you
  are listed below; the user has agreed to view evidence inline.
- Do NOT diagnose, name conditions, recommend medications, dosing,
  supplements, or specific clinical tests.
- Frame as suggestions ("consider…"), not prescriptions.
- Use progress framing, not deficit framing.
- Output 1–3 action items, ordered by signal strength. JSON only.

OUTPUT SCHEMA:
{ "recommendations": [
    { "action": "<one-line directive>",
      "rationale": "<≤2 sentences, with [[note_id]] inline citation>",
      "expected_effect": "<quantified where possible>",
      "category": "sleep|activity|recovery|intake|fitness",
      "evidence_grade": 2 | 3,
      "research_note_ids": [...],
      "signal_source": "<short label of the input that triggered this>"
    }, ...
] }

USER CONTEXT (auto-filled per run):
- Age / sex / BMI
- Last 7 days of: sleep score, sleep debt, MVPA min, strength min,
  VO2max estimate, illness flag, top findings, anomalies, last 30
  days of adopted/dismissed recommendations.

RESEARCH NOTES AVAILABLE (id + topic):
- [auto-listed from research.load_all() at runtime]
```

User-context block is built fresh each run from
`src/healthee/llm/recs_context.py`.

### Validator

Reuse `src/healthee/llm/validator.py` shape:
- Parse JSON. If malformed → 1 retry with stricter prompt.
- For each recommendation: every `[[note_id]]` in `rationale` and
  every entry in `research_note_ids` must exist in
  `research.load_all()`. Missing → drop that recommendation.
- After all-drop case: write a NULL-result row with `signal_source =
  'validation_failed'` so we can audit.
- Reject recommendations matching forbidden patterns (see
  `llm_health_advice_safety`) — keyword filter: `mg`, `dose`,
  `prescription`, `consult your doctor`, `diagnose`, etc.
- Reject self-harm / mental-health-emergency outputs; replace with a
  static fallback that points to a hotline.

### Backend

- New CLI: `healthee recs recompute [--force] [--date YYYY-MM-DD]`.
- New systemd timer `healthee-recs.timer` → fires at 07:00 IST
  daily; depends on `healthee-daily-sync.timer` having completed.
- Endpoints:
  - `GET /api/recommendations?days=30` → list of recs grouped by
    date, includes adoption status.
  - `GET /api/recommendations/today` → today's set (cached after
    first call until next morning).
  - `POST /api/recommendations/{id}/adopt`
  - `POST /api/recommendations/{id}/dismiss`
- Kill switch: env `RECS_ENABLED` defaults `1`; `0` disables both
  the timer and the API.

### Frontend

- **Today card** (`web/src/components/today/recommendations-card.tsx`):
  - Header: "For today" + chip with evidence grade
  - 1–3 action items, each with:
    - Action sentence (bold)
    - Rationale paragraph
    - "Why this" expandable → research-note text inline
    - Adopt / Dismiss buttons (left/right tap targets)
  - Footer: "AI-synthesized from your data + research notes. Not
    medical advice."
- **`/recommendations` page** (`web/src/routes/recommendations.tsx`):
  - Header: weekly tally of adopted vs dismissed
  - Timeline of past recs by date
  - Filter chips: sleep / activity / recovery / intake / fitness
  - Cite chips → opens research note in a sheet
- New nav entry in `Sidebar` + (optional) `BottomNav` slot — likely
  replace `/insights` from bottom-nav for now since it's not yet
  built.

### Behavior-loop design (per `behavior_change_and_personalization`)

- **Self-monitoring (BCT 2.3)**: dashboard already covers this.
- **Goal-setting (BCT 1.1)**: weekly MVPA target, sleep score target.
- **Discrepancy (BCT 1.6)**: each recommendation has `expected_effect`.
- **Cues (BCT 7.1)**: card visible on Today every morning.
- **Citation (BCT 5.1, 6.1)**: research-note chips.
- **Adoption tracking (BCT 2.4)**: outcomes of adopted vs dismissed.
- **Progress framing (BCT 13.2)**: "you're 87/150 min, 30 today gets
  you over" — not "you missed your target by 63 min".

### Edge cases

- **First-run / cold start**: no adoption history → engine still runs;
  it just doesn't tune signal strength yet.
- **No new signals today**: engine runs anyway and may return an
  empty list. Today card shows "no recommendations today — your
  baseline is steady" with no negative framing.
- **LLM API down**: yesterday's recs persist; card shows "fresh recs
  unavailable; from yesterday" indicator.
- **Mental-health emergency in logs**: engine bypasses LLM and shows
  static hotline card. Tracked in `signal_source = 'safety_override'`.

### Sequencing within Phase 4

1. Schema migration (add `recommendation` table).
2. Context builder (`recs_context.py`).
3. Prompt template + LLM call wrapper.
4. Validator + safety keyword filter.
5. CLI + systemd timer.
6. Endpoints.
7. Today card.
8. /recommendations page.
9. Adoption tracking + tuning hook.

### Out-of-scope

- Recurring weekly plans (multi-day prescriptions). Daily refresh
  only.
- Push notifications. Surface in app only.
- Long-term outcome A/B (do adopted recs actually improve sleep score
  vs dismissed?). Useful but separate analytics feature; the data
  will accumulate, so it can be added later without redesign.
- Speech / chat interface. The FAB Ask sheet is the eventual chat
  surface; recs are passive cards by design.

## How the coach uses it

- The recs engine and the coach share the same grounding contract: **cite a
  repo research note for every claim, or don't say it.** This note defines that
  the recs surface is a **passive daily card**, not a chat turn.
- 1–3 actions/day max, ordered by signal strength; empty is a valid, non-negative
  output ("your baseline is steady").
- All safety refusals (diagnosis, dosing, mental-health emergency) defer to
  `llm_health_advice_safety`; all framing rules defer to
  `behavior_change_and_personalization`.

## Safety bounds

- **SAFETY-CRITICAL:** the mental-health-emergency path bypasses the LLM entirely
  and shows a static hotline card (`signal_source = 'safety_override'`). This is a
  hard guardrail, not an LLM decision — see `llm_health_advice_safety`.
- Every recommendation must pass the citation validator; uncited claims are
  dropped, never shipped.
- No diagnosis / dosing / medication / supplement / clinical-test recommendations,
  enforced by the keyword filter.
- Kill switch `RECS_ENABLED=0` fully disables the engine and hides the card.

## Honesty & uncertainty

- This is an implementation plan (evidence grade ★★), not a measured outcome;
  whether adopted recs actually improve sleep score vs dismissed is explicitly
  out-of-scope until data accumulates.
- The engine never substitutes an unvalidated fallback model; on LLM outage it
  shows yesterday's recs with a clear "no fresh recs today" indicator.
- Empty output is honest, not a failure — no negative framing when the baseline is
  steady.

## Bottom line

**Act on confidently:** ship a daily batch engine that grounds every claim in a
repo note, caps at 1–3 progress-framed actions, tracks adoption, and routes all
safety cases to hard guardrails.

**Hold loosely:** the long-term efficacy of adopted-vs-dismissed recs, signal-
strength tuning weights, and any UI/nav placement details — all revisable.

## Coach Directives

1. Surface at most 1–3 recommendations per day, each citing an existing repo note;
   drop any uncited item. *(confidence: high)*
2. Use progress framing, never deficit framing; empty output is a valid, positive
   "baseline steady" state. *(high)*
3. **SAFETY-CRITICAL:** route mental-health-emergency inputs to the static hotline
   card, bypassing the LLM (`safety_override`). *(high)*
4. Never diagnose, dose, or recommend medication/supplements/clinical tests; the
   keyword filter is a hard block. *(high)*
5. On LLM outage, show yesterday's recs with a clear indicator; never auto-swap an
   unvalidated fallback model. *(moderate)*

## References
- No independent primary citations — this is an implementation spec. Its governing
  evidence lives in `llm_health_advice_safety` and
  `behavior_change_and_personalization` (which carry the primary sources).

## Healthee implementation & honesty policy

- **This note has no `applies_to_metrics`** — it governs the recs engine's behavior
  and pipeline, not a derived metric. Provenance: `src/healthee/llm/recs_prompt.py`
  (locked system prompt), `recs_context.py` (per-run context), `validator.py`
  (post-hoc citation check), the `recommendation` table above, the
  `healthee-recs.timer`, and the `/api/recommendations*` endpoints.
- **Composite-score honesty**: the engine ranks by signal strength but never emits
  a single "health score"; each recommendation carries its own evidence grade and
  cited note(s).
- **Grounding is the contract**: the displayed grade is the cited note's grade;
  anything below grade 2 is dropped. Uncited claims → retry once → drop. Audit
  trail (`raw_llm_prompt` / `raw_llm_response`) is persisted per recommendation.
- Honesty rules baked in: no deficit framing, no mortality-as-personal-prognosis,
  empty-is-honest, and yesterday's-recs-on-outage (never a silent unvalidated
  fallback).
