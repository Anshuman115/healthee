# Challenges / Programs / Actions — design & build plan

> **What this is.** The plan of record for the challenges/programs/actions system and
> its coach integration. It is grounded in a full audit of the **legacy**
> implementation (`~/projects/healthee-legacy/src/healthee/llm/challenges.py`, 1,193
> lines) — we port its proven core and fix its known flaws against the rebuild's
> honesty contract, multi-tenancy, and engineering standards.
>
> **Status (2026-07-17):** the three DB tables (`challenge`, `program`,
> `challenge_outcome`) exist in `0001_initial` and are owner-scoped + RLS'd by Phase 6.
> **Zero application code exists.** This is a greenfield backend feature WP + two app
> surfaces (Actions, Insights). Premium (PRICING §1a). Sequenced independent of Phase 2
> mobile — buildable and testable headless now.

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
| **Baseline-calibrated targets** | `CALIBRATION` block (:218), `_build_context` (:298), `_recent_value` (:157) | Targets set ~10–30% above the user's *own* recent baseline ("sedentary user at 35 MVPA/wk → 60–80, NOT 150"). Meets the person where they are. |
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
| **WP-C5 · Coach integration** | Re-add the `adopt_challenge` tool (adopt a *pre-generated* suggestion — anti-hallucination: acts only on tool `ok:true`). Wire the **outcome ledger into coach context** as `[personal_finding:...]` — the COACH_ROADMAP **C2** the audit found legacy never built. The coach **suggests and cites**, it does **not** author or adapt targets. Mirror any new grounding rule into the coach (INTELLIGENCE §4). | WP-C2 + coach | ✓ (coach) |
| **WP-C6 · App surfaces** | Actions tab (active/suggested/completed, adapt banner, projection framing) + Insights tab (outcome ledger + rollups) + Today focus card. Premium locked/teaser states. | Phase 2 mobile | — |
| **6.6 gating** | `require_ai_access` on generation + coach; the whole system is premium. Threads through, not a WP of its own. | 6.6 | — |

---

## 5. Generation & adaptation — the honesty-critical split

**Generation:** deterministic target + grounded prose.
1. WP-C1 computes the candidate **target** from the user's own baseline (progressive
   overload) — a number, not an LLM guess.
2. The LLM, through the choke point, writes the **why** and **how** for that target, citing
   the corpus. Cite-or-refuse: no valid citation ⇒ the challenge does not ship (the opposite
   of legacy's "drop the citation, ship anyway").
3. Generation stays **lazy/on-demand** (empty feed or user Refresh) — legacy never had the
   scheduler generate, and there's no reason to spend LLM tokens generating a feed nobody
   opened. (Premium-gated regardless.)

**Adaptation:** deterministic, server-authoritative, never LLM (§1). This is the direct
answer to "auto-adapting challenges." `_adapt` recomputes the target from the user's
trailing performance and applies it server-side (never trusted from the client). The coach
may *surface* that an adaptation is available; it never computes it.

---

## 6. What the coach can and cannot do (the explicit answer)

| Coach can | Coach cannot |
|---|---|
| **Adopt** a pre-generated suggested challenge (tool, on `ok:true`) | **Author** a bespoke challenge with an LLM-chosen target |
| **Suggest** which suggested challenge fits the user's goal | **Adapt** a target — that's the deterministic engine's job |
| **Cite outcomes** as `[personal_finding:...]` — "when your MVPA rose 20%, HRV followed ~10 days later" (WP-C5) | Claim an outcome that isn't in the ledger, or present a co-occurring delta as caused |
| Explain the *why* behind a challenge, grounded in the corpus | Ship any challenge/program text that fails the validator |

"Auto-adapting" = the deterministic `_adapt` engine + program deload (WP-C1/C4). The coach
is the *voice* over a deterministic substrate, exactly as everywhere else in the product.

---

## 7. Open decisions (yours)

1. **The downstream/confound approach (§2.1)** — the honest options: **(a)** demote all
   downstream (other-metric) effects to "co-occurring, unattributable" and only ever report
   the challenge's *own* target metric as before→after (simpler, unimpeachably honest); or
   **(b)** invest in a quasi-experimental design (control windows, concurrency adjustment) to
   make *some* downstream attribution defensible (harder, and single-subject data may not
   support it). **My recommendation: (a) now**, and let the FDR-controlled correlation engine
   be the place real personal cause-and-effect is discovered. Cheaper, and it can't lie.
2. **Sequencing** — backend WPs (C1–C5) **now**, independent of Phase 2, since they're
   headless-testable and are the substrate the coach-companion (C2/C4) needs; app surfaces
   (C6) during Phase 2. Or hold the whole thing until Phase 2 so it ships with UI. **My lean:
   backend now.**
3. **Coach's reach** — adopt-only (recommended, matches anti-hallucination), or also let the
   coach *trigger generation* ("make me a sleep challenge") which then runs the deterministic
   + grounded pipeline? The latter is safe *if* it routes through the same pipeline (no
   LLM-chosen numbers). Worth deciding for WP-C5.

---

## 8. Build tracker

- ⬜ **WP-C1** deterministic engine (port sacred core, owner-scoped, known-value tests)
- ⬜ **WP-C2** lifecycle + confound-aware ledger + endpoints
- ⬜ **WP-C3** grounded generation (choke point, deterministic targets)
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
