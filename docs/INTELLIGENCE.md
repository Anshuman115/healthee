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
- Template (adopted from sports-science METHODOLOGY): mandatory Honesty
  section (confounders, individual variation, metric limits), Coach Directives
  block, citations real-or-absent with primary sources verified before writing.

## 3 · The grounded-ask choke point (server)

Every LLM surface — coach, sleep/activity/metric/workout insights, recs,
weekly review, challenges — goes through ONE pipeline:

```
question/task
  → deterministic safety pre-classifier (refusal domains A–E, §5.5)
  → context: v2-native builders (today snapshot, trends, sleep + overlays,
    manual logs, baselines, anomalies, personal findings) built on
    derived_daily/sample — the legacy zepp_cloud filter bug class is
    impossible by design
  → retrieval: manifest-ranked — top-N FULL notes matched by
    metric/alias/keyword + one-line summaries of the remainder
    (bounded tokens at any corpus size; replaces legacy dump-all)
  → LLM (tools allowed, §4)
  → validator v2 — BLOCKING:
      · every interpretive sentence carries [note_id] or an honest escape
        ("no strong evidence in our base…")
      · cited ids must exist in the manifest
      · grade-calibrated language: Established→plain, Probable→hedged,
        Emerging→flagged, Contested→"the science is mixed", Myth→corrected
      · banned-tone check (alarming/reassuring words need a citation)
      · personal findings cited as [personal_finding:…], clearly distinguished
        from population research
  → on second validation failure: honest fallback ("I can't ground that in our
    evidence base") — unvalidated text NEVER ships (legacy shipped it anyway)
  → response metadata: citations[], evidence grade floor, data coverage
```

## 4 · Coach loop v2

- **Tools** (all return real JSON the model must echo, never guess):
  the proven five — `query_metric` (v2-native reads), `compare_event`
  (keep its honest "observational, single-subject — a hint, not proof"
  framing), `log_entry`, `adopt_challenge`, `sleep_consistency` — plus
  **`get_knowledge(topic|note_id)`** so the model pulls specific notes
  mid-conversation instead of upfront context stuffing.
- **Anti-hallucination stays absolute**: never claim logged/adopted/started
  unless the tool returned ok:true this turn; numbers only from tool results;
  max tool rounds bounded with an honest failure message.
- **The coach goes through the §3 choke point** — this closes the biggest
  legacy hole (§6.1): the conversational coach was the only surface with NO
  citation validation.
- **Standing context per turn**: today's recovery/readiness block, active +
  suggested challenges, and (Phase 5) the outcome ledger — measured personal
  evidence ("last time MVPA rose 20%, HRV followed in 10 days"), cited as
  personal, never dressed as research.

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

## 6 · AUDIT — the four structural holes the rebuild closes

1. **Coach skips validation** (§5.3) → §3/§4: coach goes through the blocking
   choke point.
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
| **Weight (`weight_kg`)** | weight_log; feeds BMI/VO2max/calories derive.py:204 | **NONE** |
| Strength minutes | app.py:1382 | N strength_adherence_plan, strength_training_mortality; SS strength-training-for-runners |

### 7.2 Missing knowledge docs — the writing backlog

**Priority A — metrics we already surface with NO backing (live honesty
violations):**
1. `wearable_stress_scores` — validity/interpretation of Zepp-style 0–100
   stress; we show a stress card with zero evidence behind it.
2. `weight_bmi_body_composition` — weight trends, BMI limits, adiposity;
   weight feeds three models unbacked.
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
