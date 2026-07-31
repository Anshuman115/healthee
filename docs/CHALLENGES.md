# Challenges / Programs / Actions — design & build plan

> **What this is.** The plan of record for the challenges/programs/actions system and
> its coach integration. It is grounded in a full audit of the **legacy**
> implementation (`~/projects/healthee-legacy/src/healthee/llm/challenges.py`, 1,193
> lines) — we port its proven core and fix its known flaws against the rebuild's
> honesty contract, multi-tenancy, and engineering standards.
>
> **Status (2026-07-31):** WP-C1 and WP-C2 have shipped. The deterministic engine,
> the `suggested → active → completed | expired | abandoned` lifecycle, the
> confound-aware outcome ledger (migration `0009`) and the five endpoints are live and
> owner-scoped; generation (WP-C3), programs (WP-C4) and the coach tools (WP-C5) are
> not. **Premium gating (6.6) is still NOT built** — the endpoints are reachable by any
> authenticated owner, exactly like every other AI surface today (MULTI_USER.md §12).
> Sequenced independent of Phase 2 mobile — buildable and testable headless.

---

## 0. What this system is (in one sentence)

A challenge is a **measurable rule** — a `metric` + `comparator` + `target_value` over a
`cadence`/`window_days` — that is **auto-tracked from the user's own derived data**, with
a target **calibrated to their own baseline** (progressive overload, not a textbook
ideal), a **deterministic** difficulty adapter, and a **frozen before→after ledger** that
becomes the user's personal cause-and-effect. A program is a multi-week **ladder** of
those challenges toward a goal.

The design philosophy is the same as the Sleep "Tonight" lever: **the numbers are
deterministic, only the prose is LLM.** A challenge's target is computed from the user's
data; the LLM writes the grounded, cited *why* — it never invents the number.

---

## 1. What legacy got RIGHT — port verbatim (science-adjacent, treat as sacred)

The audit's verdict: the core is a crown jewel. Port these with known-value tests, do not
"improve" them during the port (ENGINEERING_STANDARDS §"science is sacred"):

| Piece | Legacy `challenges.py` | Why it's right |
|---|---|---|
| **The metric registry** | `CHALLENGE_METRICS` (:27) | Every challenge binds to a machine-trackable derived metric — this is what makes auto-tracking possible at all. No metric ⇒ no challenge. |
| **Auto-evaluation** | `evaluate_challenge` (:87), `_series` (:50) | Progress scored from the user's own `derived_daily`/`sample` rows on every read. **Zero manual check-ins** — the single strongest design decision. |
| **Baseline-calibrated targets** | `CALIBRATION` block (:218), `_build_context` (:298), `_recent_value` (:157) | The target is computed from the user's *own* recent baseline, not a textbook ideal — "a sedentary user at 35 MVPA min/wk should get ~60, NOT 150". Meets the person where they are. The exact rule is **§5.1a**, which reconciles this example with the percentage band legacy also instructed: a percentage of a low baseline is noise, so the step has a floor. |
| **Recovery-aware streak protection** | `_protected_days` (:73) | A day after a night <60% of the user's **own 30-day sleep median** doesn't break a streak — *relative to self*, so a chronic short sleeper isn't protected every day. Port exactly. |
| **Deterministic adaptation** | `_adapt` (:547) | +20% when averaging ≥1.2× target for ≥5 days; −15% when ≤0.7×; sane rounding + ceiling/floor. **Rule-based, server-authoritative, never LLM.** This IS the "auto-adapting" feature, done correctly. |
| **The lifecycle** | `suggested→active→completed\|abandoned`, `_MAX_ACTIVE=3` | Clean status machine; baseline frozen at adopt so before→after is anchored; the cap prevents overload. |
| **Honest projections in the UI** | `actions_screen.dart` | Shows "+X% vs your ~Y baseline · closes Z% of gap to ideal" — never a bare target. Keep this framing. |

---

## 2. What legacy got WRONG — the fix mandate

The rebuild's contracts (honesty, multi-tenancy, choke-point, no-swallowed-errors) force
each of these. Ranked by importance:

### 2.1 ⛔ The outcome ledger is causally naive (the biggest fix)
Legacy computes `final` and `downstream` as **raw adjacent-window deltas with zero
confound control**, while **up to 4 challenges + a program rung run concurrently** — then
feeds those per-challenge "downstream" hints back into generation. A downstream delta
**cannot be attributed** to any one challenge under concurrency. The prose says
"observational, not proof," but the *data structure* implies attribution.

**Fix (decide — see §7):** the rebuild makes the caveat **structural, not prose**:
- **Attribution honesty:** a `challenge_outcome` records the metric that IS the
  challenge's target (that's a fair before→after). **Downstream effects on *other*
  metrics are demoted to "co-occurring, unattributable"** and stored with the count of
  *other* concurrent challenges during the window — never presented as caused by this one.
- **Confound flags:** the outcome carries structured flags for illness days in-window,
  regression-to-the-mean risk (baseline was itself an anomaly), and concurrency.
- **Data-sufficiency gate:** a thin baseline (<N days) produces an outcome **labelled
  `insufficient_data`**, never a silent `None` that vanishes.
- Where we want real personal cause-and-effect, it goes through the **correlation engine**
  (`analytics/`, FDR-controlled), not a naive window diff.

### 2.2 Generated text bypasses grounding
Legacy's `_validate` (:390) merely *drops* bad citations and ships anyway — a challenge can
persist with **zero valid citations** in its `why`. **Fix:** all four LLM surfaces
(challenge gen, program gen) route through the **grounded-ask choke point** (cite-or-refuse,
blocking validator, grade-calibrated). Same bar as every other insight. Grade gate aligns
to the corpus policy (not the looser `min_grade=2` legacy used only here).

### 2.3 Programs have no deload / failure / back-off (biggest program gap)
Legacy's `_advance_program` (:1091) advances **forward only**, and a rung that **times out
unmet is silently marked "completed."** There is no deload, no repeat-on-failure, no
ramp-down when recovery data says back off; rung targets are **frozen at design time**, not
recalibrated when the rung activates weeks later. **Fix:**
- A rung records its **honest terminal state** (`met` / `unmet_timed_out` / `abandoned`) —
  never "completed" for an unmet rung.
- **Failure handling:** an unmet rung either repeats at an eased target or inserts a
  **deload rung** (deterministic, like `_adapt`), rather than pushing the user up a
  staircase they're already falling off.
- **Recalibrate rung targets against the user's *current* baseline** when the rung
  activates (not the weeks-old design-time baseline).

### 2.4 Everything is single-tenant
Legacy has **zero `user_id`**, `USER_TZ` as a module constant (23×), unscoped SQL,
`profile WHERE id=1`, and global caps. **Fix:** every row/query owner-scoped
(`tenant_transaction`, `AND user_id = %s`, AST guard); per-user timezone threaded (the
baseline/streak anchors are calendar dates — subject to the calendar-date-vs-instant bug
class, so they resolve in the owner's tz); `_MAX_ACTIVE`/one-active-program become per-owner.

### 2.5 Swallowed errors
5× `except Exception: pass` around generation/backfill/context. **Fix:** surface or log
through the one logging path; a generation failure is a reported degraded state, not a
silent empty feed (ENGINEERING_STANDARDS §"errors are never swallowed").

### 2.6 Adherence conflates two things
Legacy's `adherence` = the completion fraction, mixing "did they show up" with "did the
metric move." **Fix:** store them separately — **adherence** (days the behavior happened /
days in window) vs **improvement** (metric delta vs baseline).

---

## 3. Data model — what to add

The three tables are already ported and owner-scoped. Additive changes only (a new
migration), all backward-safe:

- `challenge_outcome`: add `adherence` (kept, redefined as behavior-rate) + **`improvement_pct`**
  (split from adherence, §2.6); **`confounds JSONB`** (illness days, concurrency count,
  regression-risk — §2.1); **`data_confidence TEXT`** (`ok`/`insufficient_data` — §2.1);
  reframe `downstream` as **co-occurring, unattributable** (rename or annotate).
- `program`: add a rung **terminal-state** enum path and a **deload** flag on `challenge`
  rungs (§2.3), or model deload as an inserted rung with a `kind` column.
- `challenge`: a `kind` (`standard` / `deload`) if we model deload as a rung.

Everything else (metric/comparator/target/cadence/window/baseline/status/program_id/
rung_index) is already the right shape.

---

## 4. The work packages (dependency order — each an independently-reviewed, CI-green merge)

Built **backend-first**, headless-testable, no mobile dependency. Deterministic core before
any LLM.

| WP | Scope | Depends on | LLM? |
|---|---|---|---|
| **WP-C1 · The deterministic engine** | Port the sacred core (§1): `CHALLENGE_METRICS` registry, `evaluate_challenge`, `_series`, `_recent_value` baseline, `_protected_days` streak protection, `_adapt` adapter. **Pure functions over one owner's window**, owner-scoped, per-user tz, known-value tests. No persistence, no LLM. | derive/ + analytics/ | — |
| **WP-C2 · Lifecycle + ledger** | Persistence + endpoints: adopt/track/complete/abandon, baseline capture at adopt, the **confound-aware outcome ledger** (§2.1, §2.6) with the data-sufficiency gate. Owner-scoped, RLS, AST-guard-clean. Contract tests. | WP-C1 | — |
| **WP-C3 · Grounded generation** | Challenge generation through the **choke point** (§2.2): targets computed **deterministically** from baseline (WP-C1), the LLM writes only the grounded, cited `why`/`how_to`/`expected_outcome`. History-aware (raise the bar on completed, route around abandons, never dup an active). Cite-or-refuse. | WP-C2 + insights/ choke point | ✓ (copy only) |
| **WP-C4 · Programs + deload** | Ladder logic with the **fixed** failure/deload/recalibration handling (§2.3): honest terminal states, deload rungs, current-baseline recalibration on rung activation. Program generation through the choke point. | WP-C3 | ✓ (copy only) |
| **WP-C5 · Coach integration** | Two tools: `adopt_challenge` (adopt a *pre-generated* suggestion) and **`create_challenge(intent)`** (§6a — the coach passes intent, the WP-C3 pipeline computes the target and grounds the copy; refuses on untrackable metric or ungroundable claim). Both anti-hallucination-bound (act only on tool `ok:true`, report the *stored* target). Wire the **outcome ledger into coach context** as `[personal_finding:...]` — the COACH_ROADMAP **C2** the audit found legacy built the store for but never connected. The coach never authors a number and never adapts a target. Mirror any new grounding rule into the coach (INTELLIGENCE §4). | WP-C3 + coach | ✓ (coach) |
| **WP-C6 · App surfaces** | Actions tab (active/suggested/completed, adapt banner, projection framing) + Insights tab (outcome ledger + rollups) + Today focus card. Premium locked/teaser states. | Phase 2 mobile | — |
| **6.6 gating** | `require_ai_access` on generation + coach; the whole system is premium. Threads through, not a WP of its own. | 6.6 | — |

---

## 5. Generation & adaptation — the honesty-critical split

> **Design decision (owner, 2026-07-17):** *"the AI invents it — that's right — but grounded
> against the knowledge and the user's previous data."* The AI **does** author the challenge.
> What makes that safe is not taking the pen away from it, but **grounding both inputs and
> bounding the output**.

### 5.1 Generation — the AI proposes, two deterministic gates dispose

The LLM authors the whole challenge (metric choice, target, cadence, window, copy) —
because that judgement is genuinely valuable and a rules table can't encode it. *Example
this product actually needs:* a chronic ~3.7h sleeper should be offered a sleep-**regularity**
challenge, not a sleep-**duration** one. That's a reasoning call, not a lookup.

**Grounded on three inputs — corpus · data · patterns:**
1. **The corpus** — the ranked research notes (the same manifest retrieval every insight
   uses), so the challenge reflects what the evidence actually supports. *Population truth.*
2. **The user's own data** — real baselines, trends, sleep-timing statistics, recovery
   pattern, and challenge history (completed / abandoned / already active). Legacy's
   `_build_context` + `_history_context` are the proven shape; port that philosophy.
   *Where they actually are.*
3. **Their discovered patterns** — the personal findings the analytics layer has *earned*:
   FDR-controlled correlations and personal cutoffs from the `finding` table ("caffeine
   after 15:00 → −40 min sleep"), behavioural routines from their logs (fasting window,
   caffeine timing, training cadence), and — once WP-C2 lands — the **outcome ledger**
   (what previously worked *for them*). *What actually moves this person.*

Input 3 is the one no competitor can copy and the one that makes a challenge feel authored
rather than assigned: a challenge built on *your own discovered cause-and-effect* ("cut
caffeine after 15:00 — on your data that's worth ~40 min of sleep") is both the most
motivating and the most honest thing we can offer. It also **closes the loop** — outcomes
and correlations feed back into what we suggest next, so the system gets better at *this
person* over time. Patterns are cited as `[personal_finding:...]`, always distinguished
from population research and always labelled single-subject/observational.

**Then two deterministic gates it cannot talk its way past:**

- **Gate A — the baseline-bounds check (new; legacy's biggest miss).** The proposed
  `target_value` is checked against the band **§5.1a** computes from the owner's *own*
  recent baseline. A target outside it is **rejected — never clamped** (a clamp
  desynchronises the stored number from the copy the model wrote around it), so a proposal
  of "12,000 steps" for a 3,000-step baseline never reaches the DB. Legacy only
  *instructed* calibration in the prompt (`CALIBRATION`, :218) and never verified it; we
  instruct **and** enforce. Rejections are logged, not swallowed.
- **Gate B — cite-or-refuse through the choke point.** Every interpretive claim in
  `why`/`expected_outcome` must carry a real, grade-calibrated citation. No valid citation
  ⇒ **the challenge does not ship** (legacy dropped bad citations and shipped anyway, §2.2).

Plus the structural invariants: the metric must exist in `CHALLENGE_METRICS` (machine-
trackable or it isn't a challenge), owner-scoped write, per-owner `_MAX_ACTIVE` cap, no
duplicate of an active challenge.

This is the same architecture as the rest of the product: **the model generates, a blocking
deterministic layer decides what ships** — exactly how the validator and `output_guard`
already work, and how `jobs/recs.py::_provable_grade` corrects an LLM's overclaimed evidence
grade *down* against the notes it actually cited.

Generation stays **lazy/on-demand** (empty feed, user Refresh, or a coach request) — legacy
never had the scheduler generate, and there's no reason to spend tokens on a feed nobody
opened. Premium-gated regardless.

### 5.1a Calibration — ONE rule (this section is the definition; §1 defers to it)

> **This resolves a contradiction the doc used to carry.** §1 quotes legacy's canonical
> example (35 MVPA min/week → ~60, not 150 — i.e. **+71%**) while §5.1 specified a
> **+10–30%** band. Both were right about different owners, and the reason is that a
> percentage is the wrong *shape* at a low baseline: **+30% of 35 min/week is a minute and
> a half a day.** Nobody feels it and nothing measures it. At 140 min/week the same +30% is
> a real push. So the step gets a floor, and the whole thing gets a ceiling:

```
move   = max(fraction × baseline, minimum_meaningful_step, rounding_step)
target = baseline ± move, capped at the evidence target
```

applied **in the metric's own improving direction** (`good:"down"` cap metrics move
*downward*, and their evidence target is a **floor**, not a ceiling). Worked, on
`mvpa_min` weekly — floor 25 min/week, target 150 min/week:

| baseline | what governs | band |
|---|---|---|
| 35 min/wk | the **floor** (30% = 10.5, under it) | 60 — legacy's example, reconciled |
| 90 min/wk | the **percentage** (30% = 27, over it) | 115–117 |
| 140 min/wk | the **cap** (the step would reach 182) | 150 |
| 148 min/wk | nothing left — under one rounding step from the goal | *no band; refused* |

**The floor is per-metric and only exists where a note attaches an outcome to an increment
of that size.** Where none does, **there is no floor** and the percentage is the whole
rule — documented, not filled in with a guess. Today exactly two metrics have one, and
they are exactly the two whose notes state the dose-response is *steepest at the bottom*
(`mvpa_min` 25 min/week `[mvpa_minutes_mortality]`, `steps_total` 1,000/day
`[steps_mortality]`). The evidence targets are `mvpa_min` 150 min/week, `steps_total`
8,000/day, `sri` 70 `[sleep_regularity_index]`, and `tst_min` the owner's **own**
age-banded `sleep_need_min` `[sleep_need_debt]`. `cardio_load`, `active_calories`,
`workouts_week`, `alcohol_units` and `caffeine_mg` have **neither** — stated as an
absence, in `challenges/targets.py`, with the reason for each.

**Reject, never clamp** (unchanged): out of band costs the whole proposal, because a
clamp desynchronises the stored number from the model's copy *and* from what the ledger
will later publish.

**Provisional by construction — and tuned PER OWNER, never by pooling.** The targets and
curve shapes above are cited; the *step sizes are anchored, not derived*, so they are
defensible guesses.

**They are not tuned by comparing owners, and must not be.** Two reasons, and the first is
structural:

- **There is no pool to query.** Healthee is self-hostable and row-level isolated: a
  self-hosted install contains exactly one person's data, and even on the hosted instance
  every read is owner-scoped under RLS. "Which step size works across users" is not a query
  this architecture can answer, and building a path that *could* answer it would mean
  aggregating health data across people — against the product's own promise
  (`ARCHITECTURE.md`: *the user owns the data*) and against the brand the landing page
  sells (no trackers, own your data). We are not going to do it.
- **It would be the wrong science anyway.** Everything else here is deliberately n-of-1 —
  baselines are the owner's own median, streak protection is relative to *their* sleep,
  findings are FDR-controlled within one person. A population-tuned step size would be a
  worse fit for any individual than their own measured response.

**So the tuning loop is per-owner, and it already exists: the adapter (§5.2).** If the
opening target is too easy for *you*, `suggest_adaptation` raises it ~20% after five days
of beating it; too hard, it eases ~15%. That self-corrects within about a week, for that
person, using only their rows. **Which is why the opening constant matters much less than
it appears to** — it is a starting point the engine walks away from, not a verdict.

The **outcome ledger's role is also per-owner**: over time one person accumulates enough
frozen `target` / `baseline` / `status` / `adherence` / `improvement_pct` rows to show what
*they* actually complete and what actually moved *their* numbers — the same n-of-1 evidence
the coach cites as `[personal_finding:...]`. The query is written down in
`challenges/targets.py`. Editing the shipped constants is a judgement call informed by the
corpus, never a fit to pooled user data.

### 5.1b Targeting — which lever, decided deterministically

The model chooses the words. It does **not** choose where this person has the most to
gain. `challenges/levers.py` ranks the trackable metrics before the prompt is built, and
the ranking is an **explainable ordering, not a score** — no 0–100 "opportunity" number
exists, because the inputs (a mortality-hazard gap, a Spearman rho, a recovery band) share
no scale and any weighting between them would be invented (CLAUDE.md: no composite scores
without documented methodology and a note). Each lever carries its own gap, its target,
its citation and the rule that placed it.

The order is lexicographic over named rules:

1. **A personal finding implicates the metric** — FDR-controlled (`finding`, q ≤ 0.10),
   trivial/definitional pairs filtered by the same rule the Today page uses. The owner's
   own measured evidence, cited as `[personal_finding:…]` and always labelled
   single-subject/observational. It may legitimately outrank a population gap, and it is
   the only tier a metric with no population target can reach.
2. **A population gap on a curve the corpus says is steepest at the bottom** — the least
   active owner has the *most* to gain per added minute, which is exactly the case a
   percentage step under-serves (§5.1a).
3. **A population gap with no curve-shape evidence.**
4. **At or past the evidence target** — no gap left; ranked last, never hidden.
5. **Unranked** — no population target exists for this metric, so no gap is computable.
   An unranked metric is an honest output, not a hole: it is still proposable, and the
   prompt says plainly that we cannot say what it is worth.

Within a tier: by the shown gap fraction (or |effect| for tier 1), then never-attempted
before previously-attempted.

Three **exclusions** are separate from the ranking and are *enforced*, not instructed — a
proposal on an excluded metric is rejected by the same gate that rejects an out-of-band
target:

- **Already active** — never duplicate a live commitment (unchanged).
- **Recently abandoned** — they dropped it; re-pushing it is the thing legacy's own prompt
  told itself not to do and never checked.
- **A hard training lever while under-recovered** — `mvpa_min`, `cardio_load` and
  `workouts_week` are withheld when the owner's trailing-week recovery sits in the `low`
  band or an illness flag is active. `[recovery_readiness]` D7 (safety inputs are hard
  overrides, not votes) and D8 (recovery *eases or holds*, it never escalates). Legacy did
  this by hardcoding "this user is a chronic short sleeper with low recovery" into the
  prompt for its one tenant; here it is computed per owner and blocking.

### 5.2 Adaptation — the engine auto-calibrates on measured progress (deterministic, never LLM)

**Confirmed as a keeper (owner, 2026-07-17): "the engine automatically calibrates the
challenge based on the progress, as it was doing before."** This is legacy's `_adapt`
(`challenges.py:547`) — port it verbatim (§1).

Once a challenge is live, the engine **continuously watches actual performance against the
target** and recalibrates:

- **Too easy** — averaging **≥1.2× target for ≥5 days** (with enough logged days to be
  real) ⇒ **raise ~+20%**. The challenge keeps stretching instead of going stale.
- **Too hard** — averaging **≤0.7× target** ⇒ **ease ~−15%**. It meets the person where they
  actually are rather than letting them fail out.
- Sane **rounding steps** per metric (`:536`) so targets stay human ("8,000 steps", not
  "7,943"), with **ceiling/floor guards** so it can neither run away upward nor collapse to
  nothing.

Three properties that make this trustworthy and must survive the port:
1. **Deterministic** — a rule over measured adherence, not a judgement call. No LLM. Adapting
   a live commitment must be predictable and explainable ("you beat this for 5 days, so I
   raised it").
2. **Server-authoritative** — recomputed on the server and **never trusted from the client**
   (legacy `:697–717`). A client can request an adapt; it cannot dictate the new number.
3. **Relative to the person** — like streak protection, calibration is measured against their
   own trajectory, never a population ideal.

**Apply mode:** legacy auto-*detected* the adaptation and applied it on a one-tap banner in
the app (`POST /api/challenges/{cid}/adapt`) rather than silently changing the target under
the user. Keep that default — a commitment the user agreed to shouldn't move without them
noticing — with the option of auto-apply for eases (making something *easier* silently is
kinder than harder). Small UX call for WP-C6; the engine is identical either way.

The coach may *surface* that a calibration is available and explain it; it never computes
one. Program rungs get the same treatment at activation (§2.3 — recalibrate against the
owner's *current* baseline, not the weeks-old design-time one).

---

## 6. What the coach can and cannot do (the explicit answer)

**Decided (2026-07-17):** the coach **can create a challenge on request**, authoring it
itself — grounded on corpus + the user's data + their patterns (§5.1), and subject to the
same two gates (baseline bounds, cite-or-refuse) as any generated challenge. See §6a.

| Coach can | Coach cannot |
|---|---|
| **Create** a challenge on request (`create_challenge`, §6a) — authored by the model, grounded on corpus · data · patterns | Ship a target that fails the **baseline-bounds gate** (§5.1 Gate A) |
| **Adopt** a pre-generated suggested challenge (tool, on `ok:true`) | **Adapt** a live target — that's the deterministic engine's job (§5.2) |
| **Suggest** which challenge fits the user's goal | Create a challenge for a metric we cannot machine-track |
| **Cite outcomes** as `[personal_finding:...]` — "when your MVPA rose 20%, HRV followed ~10 days later" (WP-C5) | Claim an outcome that isn't in the ledger, or present a co-occurring delta as caused |
| Explain the *why*, grounded in corpus + their patterns | Ship any challenge/program text that fails the validator |

"Auto-adapting" = the deterministic `_adapt` engine + program deload (WP-C1/C4). The coach
is the *voice* over a deterministic substrate, exactly as everywhere else in the product.

### 6a. `create_challenge` — the coach-initiated flow (the honesty rails)

> *"We need the coach to create a challenge as well, but it should be based on our research
> and knowledge."* — owner, 2026-07-17. That second clause is the whole design.

The user asks ("make me a sleep challenge"). The coach calls `create_challenge(proposal)` —
and, unlike adopt, it **authors the proposal**: the metric, target, cadence, window and copy,
reasoned from the same three grounded inputs as §5.1 (corpus · their data · their patterns),
all of which are already in the coach's standing context. It then passes through the **same
WP-C3 gates** as any system-generated challenge:

1. **Bind to a trackable metric.** The proposal must resolve to a metric in
   `CHALLENGE_METRICS` (§1). If it can't ("a challenge to feel happier"), the tool refuses
   and the coach says so honestly. *A challenge we cannot measure is a promise we cannot keep.*
2. **Gate A — baseline bounds.** The proposed target is checked against the band §5.1a
   computes from the owner's own baseline, and **rejected** — never clamped — if outside
   it. The coach cannot talk its way past this; if it proposes 12,000 steps on a 3,000
   baseline, the proposal dies and the coach reports that it could not build it, rather
   than reporting a number it did not write.
3. **Gate B — cite-or-refuse.** The `why`/`expected_outcome` must carry real, grade-calibrated
   citations (corpus) and may cite the user's own patterns as `[personal_finding:...]`. No
   valid grounding ⇒ **nothing is created**, and the coach says the evidence base doesn't
   cover it. This is *"based on our research and knowledge"* made structural.
4. **Invariants:** per-owner `_MAX_ACTIVE` cap, no duplicate of an active challenge,
   owner-scoped write, premium-gated.
5. **Return the created row.** Anti-hallucination is absolute (INTELLIGENCE §4): the coach
   may only claim it created something if the tool returned `ok:true` **this turn**, and it
   must report the *stored* target — not the one it proposed.

**Why this is safe.** The coach gains authorship, not authority. It writes the proposal; the
gates decide what persists — the same generate-then-block architecture as the validator and
`output_guard`. The failure mode we refuse to ship is an LLM number that nobody checked
against the person's real baseline; the failure mode we refuse to *cause* is a rules table so
rigid it offers a 3.7-hour sleeper a "sleep 8 hours" challenge.

---

## 7. Decisions — TAKEN (owner, 2026-07-17)

1. **Downstream/confound → (a) claim only what we can prove.** Only the challenge's **own
   target metric** is reported as a before→after. Effects on *other* metrics are stored and
   shown as **co-occurring, unattributable**, with the concurrency count — never as caused by
   this challenge (§2.1). Real personal cause-and-effect is the job of the FDR-controlled
   correlation engine, not a naive window diff. *Rationale: with 2–4 challenges running at
   once, attribution is genuinely unknowable, and a small confident lie is exactly what this
   product exists not to do.*
2. **Sequencing → backend first.** WP-C1→C5 build now, independent of Phase 2 mobile:
   headless-testable, and the substrate the coach-companion (COACH_ROADMAP C2/C4) needs. App
   surfaces (WP-C6) land during Phase 2. *Accepted tradeoff: the engine is "done but
   invisible" until the app catches up.*
3. **Coach reach → create AND adopt; the AI authors, the gates bound.** *"The AI invents it —
   that's right — but grounded against the knowledge and the user's previous data — and
   patterns."* So the model authors the challenge (metric, target, cadence, copy), reasoning
   from **corpus · their data · their patterns** (§5.1), and every proposal passes **Gate A**
   (baseline bounds — clamp/reject) and **Gate B** (cite-or-refuse). Untrackable intents are
   refused honestly. **Adaptation of a live challenge stays deterministic** and
   server-authoritative (§5.2) — the coach never changes a running target.
   *Rationale: authorship is where the value is (a 3.7h sleeper needs a regularity challenge,
   not a duration one — judgement a rules table can't encode); enforcement is where the safety
   is. Legacy instructed calibration and never checked it; we instruct **and** check.*

---

## 8. Build tracker

- ✅ **WP-C1** deterministic engine (port sacred core, owner-scoped, known-value tests)
- ✅ **WP-C2** lifecycle + confound-aware ledger + endpoints (migration `0009`; the
  cumulative-comparator fix #61 and its two cap metrics; auto-completion on write
  paths only — argued in `challenges/lifecycle.py`; `expired` is a real terminal
  state; premium gating still NOT built, see below)
- ✅ **WP-C3** grounded generation — the pipeline and both gates
  (`challenges/{generate,screen,bounds,gen_context,gen_prompt}.py`). Gate A **rejects,
  never clamps**, so no code path rewrites a target and the stored number is always the
  one the copy was written around; the band is expressed as a fractional move *in the
  metric's own good direction*, so a `good:"down"` cap tightens instead of loosening.
  Gate B routes the whole batch through `grounded_ask(response_format="json")` — which
  needed `validator.validate_json` to learn the challenges shape AND to **fail closed on
  an unregistered one** (it previously returned `ok=True` for any payload it could not
  read: a real bypass, now pinned). `generate_challenges(..., intent=…)` is the WP-C5
  seam. Lazy only — no scheduler hook.
  **Three refusals worth knowing:** a metric with fewer than
  `series.MIN_COMPARISON_DAYS` measured days, or a baseline of zero (an owner who never
  logs a substance reads as zero over seven zero-filled days), has no band and is offered
  to the model as unavailable; and `cadence:"total"` is **not generatable at all**,
  because `series.recent_value` builds a `total` baseline from the trailing SEVEN days
  while `evaluate` scores a `total` over the whole window — for any `window_days != 7`
  those are different units (a WP-C1 inconsistency inherited from legacy `_recent_value`,
  which also skews `adapt`'s ease floor and the ledger's `improvement_pct` for any
  `total` challenge adopted through the API today).
- ✅ **WP-C3c** biggest-lever targeting + meaningful-step calibration
  (`challenges/{targets,levers,lever_findings}.py`). **§5.1a** is now the one
  calibration rule and §1 defers to it, so the doc no longer contradicts itself; the
  step gets a per-metric floor where the corpus attaches an outcome to an increment,
  and the band is capped at the evidence target. **§5.1b** ranks the levers
  deterministically as an explainable ordering (never a score), and its three
  exclusions — active, recently abandoned, and a hard training lever while
  under-recovered — are enforced in `screen`, not just asked for in the prompt.
  Every constant is marked **provisional**, cited, and in one file with the ledger
  query that would tune it.
  **Two things it deliberately did NOT do, both worth knowing:**
  `metrics.IDEAL["sri"]` is **85** while the note's own constant (and the evidence
  target here) is **70** — the 85 could not be sourced to `[sleep_regularity_index]`,
  but it is `adapt`'s ceiling and moving it is a behaviour change in the adapter that
  needs its own PR with known-value tests. And `(sri, weekly)` is still a generatable
  pair even though a weekly SRI is seven 0–100 scores added together (~490) — a
  pre-existing WP-C3 hole that no lever reads (the ranking uses the level), so it is
  reported rather than fixed here.
- ⬜ **WP-C3b** the refresh wiring: `POST /api/challenges/generate` (+ its latency budget
  and rate limit) and the empty-feed trigger. Split out deliberately — the pipeline is
  complete and tested headless; the HTTP surface is a separate concern that also carries
  the 6.6 gate when it lands.
- ⬜ **WP-C4** programs + deload/failure/recalibration
- ⬜ **WP-C5** coach: adopt tool + outcome ledger → `[personal_finding:...]` (COACH_ROADMAP C2)
- ⬜ **WP-C6** Actions + Insights tabs (Phase 2) + premium states
- ⬜ **6.6** premium gating threaded through

## 9. Source map
Legacy design mined from `~/projects/healthee-legacy/src/healthee/llm/challenges.py`
(generation/tracking/adaptation/ledger/programs), `api/app.py` (endpoints, coach tool),
`app/lib/{actions_screen,programs,insights_screen}.dart` (UI). Rebuild contracts:
`docs/ARCHITECTURE.md` (honesty), `docs/INTELLIGENCE.md` §4 (coach enforced-equivalent),
`docs/MULTI_USER.md` (owner-scoping), `docs/PRICING.md` §1a (premium), `docs/COACH_ROADMAP.md`
C2/C4, `docs/ENGINEERING_STANDARDS.md` (gates). Schema: `0001_initial.sql`.
