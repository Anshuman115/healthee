# Healthee — Intelligence & Grounding Design

How metrics show up on device, how they sync, how data is run against the
knowledgebase, and how the coach produces answers grounded in research.
Based on a full audit of the legacy implementation (2026-07-15); the audit
findings are preserved in §5–§7 so nothing gets lost.

---

## 1 · The device loop — how every number reaches the user

```
06:30  strap sync (BLE) → local store (60d samples, 400d sessions+dailies)
       → device analytics: provisional recovery, baselines, trends, confidence
       → UI renders INSTANTLY — value + personal baseline band + trend arrow
         + confidence chip + one-line grounded "why" from the bundled
         research_summaries.json          (origin tag: provisional)
       → push POST /ingest/helio → server derives canonical, runs analytics
       → GET /api/sync/down reconciles → provisional values replaced
         (drift beyond tolerance is logged, never hidden)
       → LLM surfaces (insight cards, coach, daily action) are server-generated,
         cached per day, always date-stamped; offline shows last cached text
         clearly marked stale — never presented as fresh
```

Rules:
- **Metric card anatomy is standardized**: every card shows value, personal
  baseline band, trend, confidence (coverage/freshness/origin), and a grounded
  "why" line citing a note id. Tapping ⓘ renders the knowledge note itself
  (plain-language + Honesty section) — one source of truth; no hardcoded card
  copy that can drift from the research.
- Interpretation (LLM text) is server-only. Evidence display works fully
  offline via the bundled summaries.
- Device never invents numbers: what it can't compute locally it labels
  "awaiting sync", not a guess.

## 2 · The knowledge platform (`packages/knowledge`)

- **Every doc gets frontmatter**: snake_case `id` (sports-science docs need ids
  + aliases added — see §7 migration), `name`, `category`, unified evidence
  grade (Established / Probable / Emerging / Contested / Myth; legacy numeric
  maps 3→Established, 2→Probable), `applies_to_metrics`,
  `applies_to_interventions`, one-line `summary`, `directives` with
  `safety_critical` flags, `last_reviewed`.
- **Generated manifest** (`make knowledge`): one build step emits
  `manifest.json` (server retrieval index) and `research_summaries.json`
  (mobile asset). Generated, never hand-edited.
- **Safety-critical directives compile into a hard-guardrail table** loaded by
  server code — deterministic checks the LLM can never override (bone-stress /
  REDs hard stop, never advise through chest pain, never advise sleep
  restriction…).
  > **Status — both halves are now live (#87, 2026-08-01).** *Enforcement:*
  > `insights/output_guard.py` blocks regardless of citations or validation (§3),
  > covering exactly the examples above, from a hand-compiled `_DOCUMENTED_RULES`
  > table where each rule cites the **doc line** that forbids it. *Compilation:* a
  > note declares a directive hard with `safety_critical: [5, 6]` in frontmatter;
  > `gen_manifest.py` refuses a marker that points at a directive which does not
  > exist or does not say `SAFETY-CRITICAL` in its own text;
  > `insights/guard_directives.py` compiles one blocking rule per marker; and
  > `tests/insights/test_guard_directives.py` asserts a **bijection** between the
  > markers and the rules, in both directions. `output_guard.output_rules()` is the
  > seam and returns both tables.
  >
  > The corpus is marked up **deliberately sparsely** — four directives today
  > (`napping` D5, `hydration_everyday` D5/D6, `late_eating_sleep` D5), each a case
  > where the wrong answer has a plausible path to real harm. Marking a directive is
  > research judgement and every marker costs a reviewed regex; an over-broad safety
  > filter that eats honest cited science is its own harm. What has changed is that
  > an *unmarked* note may no longer pretend otherwise: ~24 notes used to assert
  > "mirrored as a hard guardrail in `@daud/core`, the AI may not override" about a
  > module that exists in no repo, and those sentences now say what is true.
- Template (adopted from sports-science METHODOLOGY): mandatory Honesty
  section (confounders, individual variation, metric limits), Coach Directives
  block, citations real-or-absent with primary sources verified before writing.

## 3 · The grounded-ask choke point (server)

Every LLM surface is held to ONE pipeline — and since the coach was collapsed onto
it (#46) that is now literally one body of code, not two that agree: the stages
below live in **`insights/pipeline.py`**, and both entry points run them. The
non-conversational surfaces enter through `grounded_ask` (`grounded.py`); the coach
enters through `run_coach` (`coach.py`). Each contributes only its message layout
and its turn shape; neither owns a stage. The surfaces held to it: the coach, the
sleep/activity/metric/workout insights, notable shifts, the daily coaching lines,
recs, and challenge/program generation.

```
question/task
  → deterministic safety pre-classifier (refusal domains A–E, §5.5)
  → context: v2-native builders (today snapshot, trends, sleep + overlays,
    manual logs, baselines, anomalies, personal findings) built on
    derived_daily/sample — the legacy zepp_cloud filter bug class is
    impossible by design
  → retrieval: manifest-ranked — top-N FULL notes matched by
    metric/alias/keyword + one-line summaries of the remainder
    (replaces legacy dump-all. It bounds the note COUNT, not the token
    count: measured 2026-08-01, the same "top 6" ran 16k–34k tokens and
    is 65–83% of every prompt the product sends — PRICING §3.1's box.
    A note reaches the prompt through `manifest.prompt_body`, i.e.
    minus its bibliography, which the model cannot cite)
  → LLM (tools allowed, §4)
  → hard OUTPUT GUARDRAILS (`insights/output_guard.py`) — BLOCKING, and checked
    BEFORE the validator on purpose: a documented forbidden output (personal
    death-risk projection, advising through a red-flag symptom, sleep
    restriction, bone-stress/REDs) does not ship REGARDLESS of its citations,
    grade or validation result. The pre-classifier guards the QUESTION; this
    guards the ANSWER — a benign question can still produce a forbidden answer,
    perfectly cited. No retry: a forbidden output is not a grounding problem to
    nudge the model out of, it is a floor. Every rule cites the doc/note line
    that forbids it; a rule with no documented origin does not ship.
  → validator v2 — BLOCKING:
      · every interpretive sentence carries [note_id] or an honest escape
        ("no strong evidence in our base…")
      · cited ids must exist in the manifest
      · grade-calibrated language: Established→plain, Probable→hedged,
        Emerging→flagged, Contested→"the science is mixed", Myth→corrected
      · banned-tone check (alarming/reassuring words need a citation)
      · personal findings cited as [personal_finding:…], clearly distinguished
        from population research
  → anti-hallucination: a first-person action claim ("I logged/adopted/created…")
    is an issue unless the tool that can make it true returned ok THIS turn. On a
    tool-less surface the set of successful tools is empty, so every such claim is
    rejected — the strictest reading, not an exemption (`insights/action_claims.py`)
  → on second failure: honest fallback ("I can't ground that in our evidence
    base") — unvalidated text NEVER ships (legacy shipped it anyway).
    The retry budget is RESERVED, never shared with tool-gathering: the coach's
    gathering allowance and MAX_VALIDATION_RETRIES are two counters, so an answer
    arrives at its gates with the same tolerance however much data preceded it
    (they were one counter until 2026-08-01, and a 5-tool-round question exited
    having never been asked for an answer at all)
  → response metadata: citations[], evidence grade floor, data coverage
```

**Where each stage lives, and why that is now checkable.** The stages above are
`insights/pipeline.py`: `check_question` · `user_context` · `evidence` ·
`complete` · the answer-gate registry (`answer_gates()`: output guard → validator →
anti-hallucination) · `drive` (one nudged retry, then the fallback). The two answer
gates that block do so through the **registry**, and the question gate through
`question_gates()` — so **a stage added to a registry reaches every surface by
construction**. `tests/insights/test_pipeline_shared.py` proves it two ways: it
injects a new stage and asserts BOTH surfaces obey it, and an AST guard asserts that
no module outside `pipeline.py` reaches `classify_refusal` / `check_output` /
`validate` / `validate_json` / `evidence_section` / `build_context` at all. The
first proves a registered stage propagates; the second proves a stage cannot be
added *outside* the registry to one surface only. Both are mutation-verified.

## 4 · Coach loop v2

- **Tools** (all return real JSON the model must echo, never guess) — the seven in
  `COACH_TOOLS` today: `query_metric` (v2-native reads), `compare_event` (keeps
  its honest "observational, single-subject — a hint, not proof" framing),
  `sleep_consistency`, `log_entry` (a write),
  **`get_knowledge(topic|note_id)`** so the model pulls specific notes
  mid-conversation instead of upfront context stuffing, and — from **WP-C5** —
  **`adopt_challenge`** and **`create_challenge`** (`insights/challenge_tools.py`,
  CHALLENGES.md §6/§6a). `adopt_challenge` was DEFERRED for exactly the reason
  the next bullet gives: a tool that can't really adopt anything is the
  hallucination the rule forbids, so it landed only once the subsystem existed.
  `create_challenge` takes an **intent** and calls
  `challenges.generate.generate_challenges(intent=…)` — it does NOT author a
  target or fork a second pipeline, because Gate A and Gate B would then be two
  things to keep in step, which is precisely what the mirror rule below warns
  about. (The legacy five were `query_metric`, `compare_event`, `log_entry`,
  `adopt_challenge`, `sleep_consistency`, §5.3.)
- **Anti-hallucination stays absolute**: never claim logged/adopted/created/started
  unless the tool returned ok:true this turn; numbers only from tool results;
  max tool rounds bounded with an honest failure message — **20 gathering rounds**
  (`coach.GATHERING_ROUNDS`), a ceiling and not a spend: narrow questions were
  measured converging in **2** rounds against a live instance
  (VERIFICATION_2026_08_01 §7), an unused round costs nothing, and the last round
  withdraws
  `tools=` so the model is always *asked* for an answer with what it has rather than
  cut off mid-gather. A round that only repeats a call it already made (same tool,
  same arguments) ends the gathering early — a loop that is not making progress
  should stop on its own, not run out of budget. Worst case per question: 22 LLM
  calls; the **metering charges the question, not the call** (`api/routers/coach.py`).
  WP-C5 made the guard
  **per-tool** (`coach._CLAIM_TOOLS`): with one action tool, "did any action tool
  succeed" was the same question, but with three a successful `log_entry` would
  otherwise have licensed "I started your challenge".
- **The coach is ROUTED THROUGH §3** (#46, done). It used to be *enforced-equivalent*
  instead: `coach.py` drove its own loop and called the choke point's primitives
  itself, so **every rule added to the choke point had to be mirrored in the coach or
  the coach silently missed it** — and that was not hypothetical, the hard output
  guardrail had to be written in **two** places for exactly this reason. That rule is
  gone, and this bullet is the record of why it was worth removing rather than a
  standing instruction.

  What changed: the stages moved to `insights/pipeline.py` and both surfaces run
  them. `coach.py` now contributes exactly two things `grounded_ask` cannot — a
  message layout (persona + context in the system turn, conversation after it) and a
  bounded **tool loop**, expressed as a `pipeline.Loop` whose `next_turn` returns
  `Turn(text=None)` for a round that ran tools instead of answering. The tool loop is
  a *parameter*, not a fork. Every guarantee is unchanged or stronger: refusal before
  any tool runs, the output guard on every text candidate, the blocking validator on
  every final free-text answer, the honest fallback on repeat failure, and the
  anti-hallucination guard — which is now a shared gate, so the *other* surfaces got
  it too (they have no tools, so any action claim from them is rejected outright).

  **The rule that replaced the mirror rule:** a stage enters through
  `pipeline.answer_gates()` / `pipeline.question_gates()`, and
  `tests/insights/test_pipeline_shared.py` fails if a surface stops inheriting one or
  reaches a primitive directly. Nobody has to remember anything.
- **Standing context per turn** (`insights/coach_context.py`): today's
  recovery/readiness block plus a wide (≥30-day) `build_context` — trends,
  baselines, anomalies, sleep sessions, the manual-entry log, and personal
  findings — so the coach reasons over history and routines, not a snapshot
  (COACH_PROMPT.md). **WP-C5 added the third block**
  (`insights/challenge_context.py`): their active + suggested challenges (with the
  ids `adopt_challenge` takes) and the **frozen outcome ledger** — measured personal
  evidence ("last time MVPA rose 20%, HRV followed in 10 days"), cited as
  `[personal_finding:challenge_outcome]`, never dressed as research. The ledger's
  caveats are enforced by **what is in the prompt**, not by asking: an
  `insufficient_data` outcome is listed with **no numbers at all** (there is nothing
  to quote), and a `co_occurring` cross-metric delta is **never rendered**
  (CHALLENGES.md §2.1 — a number you hand over is a number that can be attributed).
  *Still not present:* live progress, which `query_metric` can fetch and which the
  coach may never adapt anyway (CHALLENGES.md §5.2).

---

## 5 · AUDIT — how the legacy system actually grounds (preserved findings)

All references are to `~/projects/healthee-legacy`.

### 5.1 Corpus & retrieval
- Loader `src/healthee/research.py`: parses `research/*.md` YAML frontmatter
  (`id, topic, evidence_grade 3/2/1, applies_to_metrics,
  applies_to_interventions, tags, last_reviewed`) into EvidenceNote; notes
  without frontmatter are silently dropped; **no caching** — the whole tree
  re-parses on every call.
- Retrieval is NOT semantic: `rank_notes_by_relevance` (context.py:468) is a
  keyword→metric/intervention regex ranker (+100 direct id hit, +10 per
  metric/intervention match) that only REORDERS; **all ★★★ notes are always
  included in full** (`_research_notes_md`, context.py:558). ★★ notes reach
  only the recs engine (grade≥2 whitelist, recs.py:450).

### 5.2 Validator contract (`llm/validator.py`)
- Citation = `[snake_case_id]` (regex `\[([a-z0-9_]+…)\]`) — comma-separable.
  Hyphenated ids can never match (why sports-science docs are uncitable, §7).
- Three rules: cited ids must exist in the loaded base (set-membership);
  banned-tone words (concerning/alarming/dangerous/great/excellent) require a
  citation in-sentence; interpretive sentences (likely/suggests/associated
  with/…) require a citation or an escape phrase ("no strong evidence…").
- Hard refusals bypass validation (template-fragment match).
- **Advisory only**: one retry with a nudge listing issues; after that the
  response is returned anyway with `validation_ok=False`.

### 5.3 Coach endpoint (`api/app.py:4330 POST /api/coach`)
- Context: last 12 messages, build_context(days=14), active+suggested
  challenges, today's recovery block; `_COACH_SYSTEM_PROMPT` (app.py:3712).
- Loop: max 4 rounds of `chat_raw(tools=_COACH_TOOLS)`; fixed apology on
  overflow.
- Tools (exactly 5): query_metric (metric_sample; avg/series/latest/min/max/
  sum/trend), compare_event (on/off-day averages + "hint, not proof" caveat),
  log_entry (caffeine/alcohol/water/meditation/exercise/weight/fast_start/
  fast_end), adopt_challenge (by title match), sleep_consistency (median
  bedtime, SDs, SRI, irregular nights).
- Anti-hallucination: prompt rule "NEVER say you logged/adopted unless the
  tool returned ok:true this turn"; metric namespace constrained by
  `_COACH_METRICS_HINT`; tool results returned as JSON.
- **`/api/coach` never runs the validator** — citation discipline and refusal
  domains are prompt-only on the flagship surface.

### 5.4 Context builders & the v2 breakage
- Sections: safety scan (SpO2<90, sustained RHR>baseline+10, <4h nights),
  today snapshot (value vs 30d baseline, z-scores), 7d-vs-30d trends, recent
  daily metrics table, sleep sessions + overnight overlays, manual entries,
  baselines, anomalies, personal findings (FDR-significant correlations,
  explicitly "not citations"), evidence notes.
- **Broken on v2 data**: `source='zepp_cloud'` filters at context.py:108, 240,
  267 return empty (v2 emits gadgetbridge/derived); metric keys are stale v1
  names (`distance_m`, `calories`, `hrv_rmssd_ms`, `sleep_score` vs v2's
  `distance_m_daily`, `total_calories`, `hrv_sleep_avg`,
  `sleep_health_score_4dim`) — today-snapshot/trend/anomaly sections silently
  under-report. The rebuild's v2-native builders fix this by design.

### 5.5 Refusal domains & calibration (`llm/prompts.py:23-56`)
- A emergency/red-flag · B diagnosis/clinical evaluation · C medication/
  treatment changes · D pregnancy/lactation/pediatric · E mental-health
  distress — each with an exact refusal template. KEEP ALL FIVE.
- Language calibration is hedge-verb based ("consistent with" / "may be
  related to" / "associated with in [population]" / "no strong evidence");
  bans "is caused by/definitely/always/never" and population thresholds.
  The star grade has no automatic tone mapping — binary gate only (≥3 coach,
  ≥2 recs). Validator v2 upgrades this to per-grade calibration (§3).

### 5.6 Recs engine (separate grounding path)
- Own context builder; grade≥2 citation whitelist; JSON-shape validation;
  drops recs citing unknown ids; each rec self-declares evidence_grade 2|3
  and carries raw prompt/response audit fields.
- ⚠ "self-declares" was the hole, in legacy AND in the rebuild's first cut: the
  declared grade was checked for being 2|3 but never compared against the cited
  notes, so a rec citing a Contested note could ship labelled *Established*.
  → rebuild: `jobs/recs.py::_provable_grade` resolves the shipped grade from the
  strictest cited note (`manifest.grade_of`) — overclaims corrected down, below
  Probable dropped. The grade≥2 whitelist lives THERE, on the provable floor; it
  is not a retrieval filter (weaker notes stay retrievable so the coach can still
  discuss — or correct — them).

## 6 · AUDIT — the four structural holes the rebuild closes

1. **Coach skips validation** (§5.3) → **closed, and now closed structurally**: the
   coach was first made *enforced-equivalent* (it called the blocking primitives
   itself), and #46 collapsed it onto the shared pipeline (§4). Unvalidated coach
   text cannot ship, and no new choke-point rule has to be mirrored by hand.
2. **Validation is advisory** (§5.2) → §3: blocking, with an honest fallback.
3. **Retrieval is dump-all** (§5.1) → §3: manifest-ranked top-N + summaries.
4. **Sports-science docs uncitable** (hyphen ids, no frontmatter) → §7
   migration.

## 7 · Knowledgebase coverage & gaps (full audit matrix)

### 7.1 Coverage matrix (metric → legacy derivation → backing notes)

N = packages/knowledge/notes, SS = packages/knowledge/sports-science.

| Metric | Legacy derivation | Backing notes |
|---|---|---|
| RHR (`rhr_daily`) | derive.py:53 | N resting_hr_health_marker, wearable_hr_validity; SS resting-heart-rate |
| HRV overnight (`hrv_sleep_avg`) | derive.py:170 | N hrv_recovery_marker, hrv_improvement, recovery_readiness; SS heart-rate-variability |
| VO2max (Jurca `vo2max_estimate`) | derive.py:399 | N non_exercise_vo2max, vo2max_estimate_plan, vo2max_fitness_mortality, vo2max_training_program; SS vo2max |
| VO2max submax (`vo2max_submax`) | derive.py:426; vo2max_submax.py | N submaximal_vo2max |
| MVPA (`mvpa_min`) | derive.py:372 | N mvpa_minutes_mortality, mvpa_weekly_plan, cadence_intensity |
| Steps (`steps_total`) | derive.py:310 | N steps_mortality, sedentary_mortality, exercise_mortality |
| Cardio load / TRIMP (`cardio_load`, zones) | derive.py:629 | N cardio_load_trimp; SS training-stress-score, heart-rate-zones |
| **Strain (0–21)** | app.py:1636 | **NONE dedicated** (implicit via cardio_load_trimp) |
| Sleep score (4-dim) | derive.py:131 | N sleep_health_score_multidim, sleep_score_implementation_plan, no_validated_sleep_score, wearable_sleep_stage_validity |
| Sleep need/debt | derive.py:683 | N sleep_need_debt |
| SRI / consistency | derive.py:154; app.py:3907 | N sleep_regularity_index, sleep_consistency, sleep_timing_chronotype |
| Recovery score | derive.py:748 | N recovery_readiness; SS sleep-and-recovery |
| **Readiness (live intraday decay)** | app.py:3077 | recovery_readiness loosely; **formula self-admittedly unvalidated** |
| Biological age | analytics/biological_age.py:30 | N biological_age_estimate |
| Respiratory rate (sleep) | derive.py:182 | N respiratory_rate_normal, illness_flag_plan |
| SpO2 (overnight/min) | derive.py:173-180 | N wearable_spo2_validity |
| Skin temp | ingested; app.py:1475 | N skin_temp_signals, illness_flag_plan |
| Illness flag | app.py:1475 | N illness_flag_plan |
| **Stress (Zepp 0–100)** | ingested; app.py:1773 | **NONE** |
| Calories / TEE | derive.py:350 | N energy_expenditure_derivation |
| Distance | derive.py:329 | N distance_from_steps |
| PAI | app.py:1281 | ~~pai_activity_score~~ — note removed 2026-07-16 (PAI not derived in v2; owner decision) |
| ACWR | app.py:2593 | SS training-load-acwr |
| HRmax (Tanaka) | derive.py:230; vo2max_submax.py | SS maximum-heart-rate; N wearable_hr_validity (partial) |
| **Weight (`weight_kg`)** | weight_log; feeds BMI/VO2max/calories derive.py:204 | N weight_bmi_body_composition |
| Strength minutes | app.py:1382 | N strength_adherence_plan, strength_training_mortality; SS strength-training-for-runners |

### 7.2 Missing knowledge docs — the writing backlog

**Priority A — metrics we already surface with NO backing (live honesty
violations):**
1. `wearable_stress_scores` — validity/interpretation of Zepp-style 0–100
   stress; we show a stress card with zero evidence behind it.
2. ~~`weight_bmi_body_composition`~~ — **WRITTEN 2026-08-01** (#11,
   `notes/metrics/`). It backs the weight card and names what weight costs the
   Jurca VO₂max and Mifflin-St Jeor models. Two implementation gaps it
   documents remain OPEN: `_weight_as_of` has no staleness bound (a year-old
   weight anchors today's BMR/BMI silently), and `_weight_card` surfaces a bare
   latest weigh-in with no baseline, trend or date.
3. `strain_scale` (or extend `cardio_load_trimp`) — document our 0–21 scaling
   honestly.
4. `napping` — the app gives strategic nap guidance with no napping note.
5. `intraday_readiness_decay` — find evidence for the live-decay formula, or
   the card must label it "our heuristic, unvalidated" (the honesty contract
   applied to ourselves).

**Priority B — user-loggable / coach-reasoned topics with no note:**
6. `fasting_time_restricted_eating` — fasting is loggable + comparable; zero
   notes (legacy code comments literally say "no notes yet").
7. `hydration_general` — water logging exists; only athletic fueling (SS) is
   covered.
8. `nutrition_protein_basics` — or an explicit policy note that nutrition
   stays out-of-base (an honest refusal needs a documented reason).

**Priority C — computable-metric candidates that would activate orphaned SS
docs** (we already record GPS workouts): aerobic decoupling, grade-adjusted
pace (Minetti is already implemented in the VO2max estimator), pace zones,
race prediction, critical speed, cadence/stride from per-minute data.
Each new derived metric makes its SS doc citable.

**Promotions:** `mvpa_min_weekly` and `strength_min_weekly` to first-class
derived metrics (their notes already exist; legacy computed them ad-hoc in
API payloads).

### 7.3 Migration task — make sports-science citable
Add frontmatter to all 29 SS docs: snake_case `id` (e.g. `heart_rate_zones`),
aliases (the hyphenated original name), category, grade mapped from their
Established/Probable/Emerging/Contested scale (already matches the unified
scale), `applies_to_metrics`. Without this they cannot be cited at all
(§5.2 regex). Generalize runner-specific directives on import — flag with
`population: runners` where they shouldn't apply blindly.

### 7.4 Orphans (exist, back no computed metric — fine, tracked)
- Protocol/engineering docs in notes/protocol/ (no frontmatter, never loaded —
  correct; they're engineering references, move out of the citable corpus
  eventually).
- Meta/process notes: recommendations_engine_plan, llm_health_advice_safety,
  behavior_change_and_personalization (back the recs engine, not metrics —
  keep).
- 12 SS running-performance docs + 5 SS principles + 2 SS wellness — orphaned
  until Priority C metrics exist; principles docs ground *plan design*
  (challenges/programs), wire them into the challenges generator context.

## 8 · Phase mapping & acceptance

| Work | Phase | Done when |
|---|---|---|
| Manifest + SS frontmatter migration + validator v2 + choke point + coach v2 | 1 | Coach answer with a fabricated citation is blocked in test; SS note citable end-to-end |
| Card anatomy + bundled summaries + ⓘ-renders-the-note | 2 | Every metric card shows confidence + grounded why; ⓘ sheet is the note |
| Sync-down reconcile + offline stale-stamping | 3 | Airplane-mode card shows provisional tag + dated cached insight |
| Device analytics + confidence chips | 4 | Parity suite green |
| Priority A/B notes | parallel, start now | Each merged note passes template check (Honesty + Directives + verified primary sources) |
| Priority C metrics + SS activation | 5+ | New derived metric ↔ its SS doc citable |
| Outcome-ledger coach memory + weekly review | 5 | First weekly review cites only real notes + personal findings |
