# Final audit — `db/`, `jobs/`, the `today.json` contract models, and the credits/challenges internals

Read-only audit of the last unexamined parts of the server. It closes items **4, 5, 7 and
8** of `docs/AUDIT_COVERAGE.md`:

| item | scope | modules |
|---|---|---|
| 4 | `db/` — migrations, the purge tool, retention | 7 + 18 migrations |
| 5 | `jobs/` — the nightly scheduler | 9 |
| 7 | the five `today.json` models spot-checked rather than diffed | 5 blocks |
| 8 | `insights/credits.py` arithmetic; `challenges/` `levers` · `ladder` · `program_store` · `windowed` | 5 + `core/allowance.py` |

Read against `CLAUDE.md`, `docs/ENGINEERING_STANDARDS.md`, `docs/HOW_WE_VERIFY.md`,
`docs/AS_OF_DAY.md`, `docs/BACKEND_AUDIT.md` (section 0's method) and
`docs/WRITE_PATH_AUDIT.md`. This audit is **downstream of the write-path audit** and does
not re-open `ingest/` or `derive/`; where a finding touches them it says which document
already owns it.

Every finding carries `file:line` and is marked **CONFIRMED** (code path read end to end)
or **SUSPECTED** (looks wrong, could not be settled read-only). **Cleared classes are
reported too** — a swept class is a result, and it is the only thing that makes "the audit
programme is complete" verifiable rather than hopeful. Where a comment or docstring named
a guard, **the test was opened**; where the test does not exist, or exists but does not
reach the branch it is credited with, that is recorded as a finding in its own right. Two
such claims did not survive (A2, D9).

Findings are ranked by **whether the damage reaches the owner** and **whether it is
recoverable**.

Nothing was changed by this audit. It recommends; it does not fix. No mutation script was
run. No device, production server, production database or token was touched.

---

## 0. Counts, and the headline answers

| Severity | Meaning | Count |
|---|---|---|
| **A — misleads the owner now** | an unqualified, mislabelled or stale value reaches a screen | **4** |
| **B — wrong now, recoverable** | work is silently skipped and only an operator can get it back | **1** |
| **C — right mechanism, wrong disclosure, or a reachable dead end** | | **6** |
| **D — hygiene** | standards violations and unverified claims, no direct honesty consequence | **10** |
| **Swept clean** | classes checked with evidence, no finding raised | **26 classes** |

CONFIRMED 20 · SUSPECTED 1 · Could not determine: 4.

**Every severity-A finding is on the client half of the `today.json` wire**, which is the
half `BACKEND_AUDIT.md` explicitly declined to certify. Four of the five blocks are clean
key-for-key; what is not clean is what the client does with the keys after parsing them.

**The questions the brief asked, answered up front:**

* **Does any migration lose data without saying so?** **No.** Four migrations destroy
  something (`0005:41`, `0010:86`, `0012:38`, `0015:23`) and all four say so in their own
  header, name what goes, and argue why. `0009:59`'s type change *preserves* the old text
  under an explicit `legacy_note` key rather than dropping it. Migrations are forward-only
  (no `down`), and the runner applies each file plus its ledger row in one transaction
  (`migrate.py:73-85`, `core/db.py:253-260`), so a file cannot half-apply.
* **Can the purge tool over-reach?** **No.** It is bounded four ways — owner predicate
  *and* RLS, an explicit day span, a caller-named metric list it will not invent, and
  `derived_at < transaction_timestamp()` — and **every one of those bounds has a test that
  asserts it** (`tests/db/test_stale_derived.py:206-341`, all opened). `--apply` with no
  metric named is refused; a compute-once gated metric is refused until its gate is
  reopened. See F4 for the table, and D5 for the one structural seam.
* **What does the nightly chain do on partial failure?** Each step runs in its own
  transaction, every failure is logged and Telegrammed, and a `correlate` failure correctly
  skips the two steps that consume its findings. **But the dedup marker advances on
  `correlate` alone** (`chain.py:245-250`), so a failed `illness` or `challenges` step is
  marked done and never retried, and `briefing` is not even attempted until after the mark
  is written. That is **B1**.
* **Every key-level mismatch in the five `today.json` models.** Section E. Headline:
  **zero phantom reads and zero type mismatches** in all five blocks — the worst class the
  brief named is empty. Six client gaps, three of which are honesty fields (A3), and four
  fields parsed and then never drawn.
* **Can the credits ledger double-charge or lose a charge?** **No, on either.** The spend
  is serialized by a real row lock inside one transaction (`core/allowance.py:105-160`), a
  refused attempt is never recorded, the truncation cannot drop an in-window instant, and a
  refund is net-neutral and idempotent at the call site (`api/gate.py:288-309`). Six
  mechanisms and their tests are set out in F19. The one gap is that **the lock itself has
  no test** — D6.

---

## A. Misleads the owner now

### A1 — every finding's effect is labelled `r` on the Today screen, whatever statistic it is — CONFIRMED

`apps/mobile/lib/features/today/widgets/insights_section.dart:116`

```dart
ModuleFoot('r ${effect.toStringAsFixed(2)} · $samples days of your data'),
```

The letter is hard-coded. `effect_metric` is on the wire (`read/findings.py:101`), is
parsed (`data/models/finding.dart:50`), and is ignored. The server sends `rho` for a
Spearman correlation (`analytics/correlations.py:154`) and the Mann-Whitney rank-biserial
statistic for an event finding (`:201`) — so a rank correlation is drawn under the symbol
for Pearson's *r*, and an event effect gets the same letter for a different statistic
entirely.

The rule this breaks is written on the field itself, `finding.dart:97-99`:

> **WHICH statistic [effectSize] is** — `rho`, `d`, … Without it a number between −1 and 1
> could be read as three different things.

This is `BACKEND_AUDIT` A1's shape exactly — a number on a screen wearing the wrong
instrument's name — on the surface the repo built `effect_metric` specifically to prevent
it on.

**Recommend:** render `finding.effectMetric` and withhold the letter when it is absent, the
way `estimate` and `method` are already paired on the VO₂max card.

### A2 — the raw statistical string reaches the home screen as the headline, and the guard that was supposed to stop it does not cover this path — CONFIRMED

`apps/mobile/lib/features/today/widgets/insights_section.dart:174-178`

```dart
if (finding.metricB == null || b.isEmpty) {
  return (
    headline: finding.description ?? 'Pattern found in your data.',
    context: context,
  );
}
```

`finding.description` is `description_raw`, and its own docstring
(`data/models/finding.dart:88-91`) is unambiguous:

> **Do not render it.** `findings_section.dart` composes the owner-facing sentence from the
> structured fields; this is kept because a log line is worth having when a finding looks
> wrong, and it is deliberately not on any surface. **It reached the home screen verbatim
> once.**

It reaches it again. `metricB` is null for every `event_effect` and `personal_cutoff`
finding, `read/findings.py:62-63` screens only `pairwise_lag` for triviality, and
`InsightsSection` is drawn on the live Today screen
(`features/today/today_day_sections.dart:221`). For an event finding the string the owner
would read is `analytics/correlations.py:193-196`:

> `caffeine days vs others (same day, sleep_health_score_4dim): rank-biserial r=-0.42 (p=0.031, n_event=12, n_other=45)`

**The guards were opened and they do not reach this branch.**
`test/features/findings_wording_test.dart:59-64` asserts that "Spearman" never reaches a
surface — but it calls `findingHeadline` from **`shared/findings_section.dart`**, a
different function, and its fixture (`:28-41`) is a pairwise finding with `metricB` set, so
the fallback branch is never entered. `grep describeFinding test/` returns nothing. This is
the exact failure `HOW_WE_VERIFY.md` section 2 calls *the fictional mutation's cousin*: a
test that goes green having exercised something adjacent.

The correct handling already exists — `shared/findings_section.dart:186-190` builds *"Your
&lt;metric&gt; on &lt;event&gt; days, against your other days"* from `event_kind`, which the
Today copy parses (`finding.dart:47`) and never uses.

**Recommend:** give `describeFinding` the `event_kind` branch `findings_section.dart`
already has, and point the wording test at *both* functions. A guard that names one of two
composers is half a guard.

### A3 — three server-side honesty fields on the recovery ladder are dropped at the client boundary — CONFIRMED

`apps/mobile/lib/data/models/recovery_signals.dart:36-48` parses `name`, `value`,
`baseline`, `baseline_sd`, `z`, `direction`, `unit` and `research_note_id`. Three keys the
server sends are absent from that list and from the whole of `apps/mobile/lib`
(`grep direction_basis population_floor_min` returns nothing):

| field | wire | what it exists to say |
|---|---|---|
| `n` | `read/recovery_signals.py:187, 248, 305` | how many days the baseline and z rest on |
| `direction_basis` | `read/recovery_signals.py:255` | which limb produced the sleep verdict |
| `population_floor_min` | `read/recovery_signals.py:256` | the cut-point the verdict was taken against |

Each was added deliberately and each has the reason written beside it. `n`
(`recovery_signals.py:43-57`): before it, the RHR and HRV signals had no count gate at all
and published a verdict *"on this owner's autonomic state from two mornings"*; the fix added
`_SIGNAL_MIN_DAYS = 5` **and** shipped `n` *"beside `baseline` and `baseline_sd` … so a
reader can weigh a direction rather than take it."* The reader cannot.

`direction_basis` is the sharper loss, and it is sharpest for **this owner**
(`recovery_signals.py:251-254`):

> WHICH limb produced that word. Both limbs are legitimate and both are reported; what a
> reader could not previously tell is that **for a chronic short sleeper the population
> floor decides every night and the personal number beside it cannot change the verdict**.

The owner of this repo is a chronic short sleeper (`MEMORY`, `user_chronic_short_sleep`), so
this is not a hypothetical: the ladder draws a personal z beside a verdict that z did not
produce, and the field built to disclose that is disclosed to nobody. The server half is
real and tested — `tests/read/test_honesty_b_c.py:312` asserts
`direction_basis == "population"` and `tests/read/mutations.sh:526-527` mutation-covers it.
The client half does not exist.

This is `BACKEND_AUDIT` A3's shape, three times over: the server did the honest work and the
client filed it under a key nothing reads.

**Recommend:** parse all three, and render at least `n` and `direction_basis` — `n` beside
the baseline the way the VO₂max card carries `n_sessions`, and `direction_basis` as the
sentence that says which limb spoke.

### A4 — an illness flag up to two days old is drawn as today's, and the date that would say otherwise is parsed and never rendered — CONFIRMED

`read/health_metrics.py:203-210` selects the newest flag in
`[anchor − 2 days, anchor]` (`_ILLNESS_ACTIVE_DAYS = 2`, `:179`), and the payload carries
`date` (`:235`) precisely so a reader can tell which day it is about. The client parses it
(`data/models/illness_flag.dart:41`, field at `:55`) and the only consumer,
`features/today/widgets/illness_banner.dart:36-95` (wired at
`features/today/today_sections.dart:261-262`), draws framing, sustained, notes and deltas —
never the day.

Meanwhile the framing sentence the banner prints verbatim is present-tense
(`read/health_metrics.py:263`):

> `Possible early signal — consider lighter activity today. …`

So a flag raised on Monday is rendered on Wednesday as advice about Wednesday, with nothing
on screen able to say otherwise. That is stale-as-current — the lie
`HOW_WE_VERIFY.md` section 3 says has been swept three times — on the one **safety-critical**
block on the Today screen.

The repo has already fixed this exact bug once, on the block beside it:
`data/models/recommendation.dart:61-76` and
`features/today/widgets/actions_section.dart:105-111,198-205` print "actions from
&lt;day&gt;" when the set is older than the viewed day, guarded by
`test/features/actions_dating_test.dart:9-15`. The illness banner never got it. (C5 is the
third instance of the same class.)

**Recommend:** the same treatment `ActionsSection` already has — compare `flag.date` with
the viewed day and say so on the face. It is a one-line comparison and the precedent is in
the next file.

---

## B. Wrong now, and only an operator can get it back

### B1 — a failed step is marked done: the chain's dedup marker advances on `correlate` alone — CONFIRMED

`apps/server/src/healthee/jobs/chain.py:245-254`

```python
if correlate.status == "ok":
    steps.extend(_after_correlate(day, user_id, tz, client=client, premium=premium))
    # Correlate succeeded → the generating steps had valid inputs and their chance
    # to run; mark the day done so they aren't re-run. ...
    _mark_chain_done(user_id, day)          # line 250
else:
    steps.extend(_skipped_after_correlate())

steps.append(_briefing_step(day, user_id, tz, client=client, premium=premium))   # line 254
```

The chain is six steps — `illness` → `challenges` → `correlate` → `recs` → `warm` →
`briefing` (`chain.py:232-254`). Only the third gates the mark. With `correlate` green:

* a failed **`illness`** (step 1, `chain.py:234`) is marked done;
* a failed **`challenges`** (step 2, `chain.py:237-239`) is marked done;
* **`briefing`** runs at line 254, *after* the mark is written, so a briefing failure can
  never be retried by construction.

The next tick reads the marker (`chain.py:306-319`, `value >= day`) and returns `deduped`,
and the day rolls over.

**`illness` is the one that costs something the ordinary tools cannot rebuild.**
`derive_illness_flag` has exactly one production call site — `jobs/steps.py:47` — and it is
**not** part of `derive_batch` (`grep illness src/healthee/derive/orchestrator.py
src/healthee/derive/__init__.py` returns nothing), so `db/rederive.py` does not recover it.
A transient DB blip on step 1 with step 3 succeeding leaves that day with no illness row,
permanently, short of a hand-run `run_chain(..., day=D, force=True)`.

**The blast radius is smaller than it first looks, and that is worth stating.** The read
layer treats a flag as active across a two-day window (`read/health_metrics.py:203-210`), so
a single missing day is usually absorbed by its neighbour, and a failed step leaves any
*previous* row standing rather than deleting it (`derive/illness.py:391` is the delete, and
it does not run when the step raises). What is lost outright is day D's own answer, on the
Today card for D and on every as-of-day read of D thereafter. `challenges` is milder still:
`ladder.advance_due` is idempotent by construction (`ladder.py:131-143`, it reads stored
statuses) and simply runs a day late.

**Not covered by any test.** `tests/jobs/test_chain_supervision.py:48-52` replaces
`_chain_done`/`_mark_chain_done` with an in-memory set and never asserts the marker's state
on a failure path; `tests/jobs/test_chain_marker.py:158-172` uses only non-raising step
stubs. The comment at `chain.py:247-249` describes steps 4-6 ("the generating steps") and
silently annexes steps 1 and 2 — a guard claimed in a comment, absent in the code, untested.

**Recommend:** gate the mark on the steps that must not be silently skipped — at minimum
`illness` — and move `_mark_chain_done` below line 254 so `briefing` sits inside whatever
rule is chosen. Then assert it: one test per step that a failure leaves the day unmarked, or
deliberately does not, with the reason written next to it.

---

## C. Right mechanism, wrong disclosure — or a reachable dead end

### C1 — `claim_sentinel` refuses an owner who was granted premium first, and calls it "already owns data" — CONFIRMED

`apps/server/src/healthee/db/claim_sentinel.py:78` names the one table excluded from the
owns-data refusal:

```python
_NON_TENANT_TABLES = frozenset({"device_token"})
```

with the reason: *"`device_token` references app_user but holds credentials, not health
data: an owner who paired a device before claiming is not an 'ambiguous merge'."*

That argument applies verbatim to `subscription`, which is **not** excluded. It carries an
FK to `app_user` (`db/migrations/0011_subscription.sql:43`), so `referencing_tables`
(`:107-113`) discovers it, `tenant_tables` (`:116-118`) keeps it, and `plan` (`:169-175`)
raises *"already owns data … this tool re-keys, it does not merge. Merging two owners'
health data is a judgement call about whose numbers are whose"*.

An entitlement row is not health data and there is nothing to merge. The sequence that
reaches it is the ordinary one: the owner signs in, the operator comps them
(`db/grant_premium.py:122-127` requires an `app_user` row, so a grant before the claim is
the natural order), then the claim is permanently refused. **There is no shipped way out:**
`--revoke` writes `status = 'canceled'` (`grant_premium.py:130`) through the same
`ON CONFLICT DO UPDATE` upsert (`:68-74`) — the row persists — and nothing deletes from
`subscription`. The operator is left hand-writing SQL, which is the thing this family of
committed ops modules exists to replace.

The refusal is also the wrong *diagnosis*, which matters more than the inconvenience: it
tells the operator their target owns health data when it does not.

**Recommend:** add `subscription` to `_NON_TENANT_TABLES` with the same one-line reason
`device_token` carries. It stays inside `_verify`'s post-check (`:215-235`), which walks
`referencing_tables()` and is where "nothing may still belong to the sentinel" is actually
enforced — so nothing is weakened.

### C2 — `send_briefing` stamps an arbitrary day onto text generated for today — CONFIRMED mechanism, operator-only path

`apps/server/src/healthee/jobs/briefing.py:52-55`

```python
day = day or user_today(tz)
warmed = coaching.cached_line(user_id, tz, coaching.MORNING_BRIEFING_KEY)
body, status = _body(user_id, tz, warmed, client=client)
sent = send_telegram(_compose(day, body))
```

`cached_line` (`insights/coaching.py:71-80`) is keyed on the owner's *today* and takes no
day; `_compose` (`briefing.py:87-89`) prefixes `healthee briefing — {day}`. So
`run_chain(user_id, tz, day=<past>, force=True)` sends **today's judgement under an older
date** — the stale-as-current lie `docs/AS_OF_DAY.md` section 3 names and that
`jobs/recs.py:142-176` writes thirty lines refusing, with a hard `ValueError` and a test
proving the refusal precedes any model call (`tests/jobs/test_recs_day.py:47`).

Two things bound it, and both are real. `recs` raises first on the same call
(`recs.py:169`), so a forced past-day chain already reports a failed step; and **`force=True`
has no production caller** — `grep "run_chain("` over `src/healthee/` returns
`chain.py:198` (the definition), `scheduler.py:172` (which never passes `force`), and a
comment at `api/app.py:136` describing a wire deliberately not built. Every `force=True`
call site is a test.

**Recommend:** give `send_briefing` the refusal `generate_recs` already has, or generate from
`day` rather than from the cache. Low urgency; it is not reachable without a Python shell.

### C3 — the abandon cooldown rests on a row bound whose stated reason is not the binding one — SUSPECTED

`apps/server/src/healthee/challenges/levers.py:87`

```python
_HISTORY_ROWS = 50
```

with the reason: *"these two rules only care about the LATEST row per metric, and there are
nine metrics."* Nine metrics is not what makes 50 sufficient. `_recently_abandoned`
(`:337-354`) walks `ledger.recent(cur, user_id, limit=_HISTORY_ROWS)` newest-first and takes
the first row per metric; a metric whose latest outcome sits at row 51 or beyond reads as
**never abandoned**, and `_blocked_reason` (`:300-301`) then re-offers a challenge inside its
60-day cooldown.

So the correctness of a 60-day rule depends on an unstated invariant: *fewer than ~50
outcomes are frozen in any 60 days*. The legal worst case exceeds it —
`lifecycle.MAX_ACTIVE = 3` (`lifecycle.py:76`) concurrent challenges at
`gen_prompt.MIN_WINDOW_DAYS = 3` (`gen_prompt.py:31`) is up to 60 outcomes in 60 days. In
practice the generator favours week-scale windows and ladder rungs are floored higher
(`program_prompt.MIN_RUNG_DAYS`), so this is **SUSPECTED**, not confirmed reachable.

The damage is bounded and is not a wrong number: the owner is re-offered something they
dropped. `_attempted_metrics` (`:357-359`) shares the bound and only feeds a tie-break.

**Recommend:** bound the read by the cooldown itself (`ended_at >= today − 60d`, which is
the quantity the rule is actually about), or state the throughput invariant in the docstring
and put a test on it. A limit chosen against "nine metrics" cannot see the failure mode.

### C4 — the illness banner prints the deltas twice, and the second copy drops the baseline window a directive requires — CONFIRMED

`read/health_metrics.py:254-258` builds the framing sentence with the window named:

```python
parts.append(f"breathing rate +{rr_delta:.1f} bpm vs your 14-day baseline")
```

and `:248-252` records why: `[[respiratory_rate_normal]]` Coach Directive 1 — *"never quote
a '+X br/min above baseline' without saying which baseline"* — because that note ships
**three** baseline windows (14 nights here, 42 days in `recovery_score`, 30 in the anomaly
layer).

`features/today/widgets/illness_banner.dart:76` prints that sentence verbatim. Then
`:77-80` and `:86-95` print a second line built client-side:

```dart
'breathing rate ${_signed(rr, 1)} bpm vs your baseline'
```

— the same number, the window dropped. The owner does see the window on the line above, so
this is a duplicated and under-qualified restatement rather than an unqualified claim, which
is why it is C and not A. It is still the banner's own second line breaking the directive
its first line exists to satisfy.

**Recommend:** drop `_deltas()`. The server sentence already contains the numbers and their
window; a second copy can only ever agree less.

### C5 — `recommendations[].date` is honoured on Today and ignored on the v02 Actions screen — CONFIRMED

`read/today.py:210` reaches back two days for recommendations. Today handles it:
`features/today/widgets/actions_section.dart:105-111` compares `items.first.date` with the
viewed day and `:198-205` prints "actions from &lt;day&gt;", guarded by
`test/features/actions_dating_test.dart`.

The v02 Actions screen does not. `features/actions/v02/actions_screen.dart:142` labels the
set with `prettyDate(snapshot.date)` — the *viewed* day — and
`features/actions/v02/suggestion_card.dart` never reads `rec.date` (grep confirms). The
identical two-day-stale set is relabelled as today's.

Same class as A4, third instance. One surface fixed, one not, and the fix is in the file
next door.

**Recommend:** move `otherDay()` into a shared helper both screens call, so a fix cannot
land on one surface again.

### C6 — `routine.logs_summary` is dropped, and the Daily journal panel disappears on a log-only day — CONFIRMED

`read/routine.py:30, 98-104` ships `logs_summary` — the per-kind `{count, total}` roll-up of
the day's manual entries. `grep logs_summary apps/mobile/lib` returns nothing.

The consequence is visible, not merely dead weight. `Routine.isEmpty`
(`data/models/routine.dart:124-125`) is
`workouts.isEmpty && meditationCount == 0 && openFast == null`, and
`features/today/today_day_sections.dart:198-202` draws the Daily journal panel only when
`!isEmpty`. So a day whose only entry was caffeine — or hydration, or any kind other than
meditation — renders **no journal panel at all**, while the wire explicitly reported that
entry.

Nothing is fabricated: the panel is silent, not wrong, and the data is reachable from the
Journal screen's own feed (`data/journal/journal_repository.dart:21`, `/api/log/recent`). It
is the payload saying less than it knows, which is `BACKEND_AUDIT`'s severity-C definition.

**Recommend:** either parse `logs_summary` into `isEmpty` so the panel follows the wire, or
delete the key and say why. Shipping an answer nothing can read is the state that invites a
future reader to assume it is drawn.

---

## D. Hygiene

### D1 — no test ever replays a migration's SQL; fourteen files claim "replay-safe" on trust — CONFIRMED

Every migration from `0004` on carries a *Replay-safety* paragraph. The nearest thing to a
test is `tests/integration/test_db_integration.py:51-53`:

```python
def test_second_migrate_run_is_a_no_op(db: None) -> None:
    migrate.apply_migrations()                  # ensure applied
    assert migrate.apply_migrations() == []     # nothing pending the second time
```

That proves the **ledger** skips a recorded file. It never re-executes one, so the
`IF NOT EXISTS` / drop-by-name-first discipline the headers describe is asserted nowhere.
`tests/test_migrate.py:16-110` is entirely unit-level against a fake cursor and covers the
splitter and the pending calculation, not the SQL.

This is low severity precisely because `_apply_one` (`migrate.py:73-85`) runs a whole file
plus its `schema_migrations` row on one `admin_connection()`, which commits on clean exit
(`core/db.py:253-260`) — so a file cannot half-apply and be replayed. The claim only has to
hold after a `schema_migrations` loss (a restore from a partial dump, a hand-edit).
`0009:39-44` is the one file that states the limit honestly: its two `RENAME COLUMN`
statements (`:52`, `:58`) are **not** replay-safe, Postgres has no `RENAME … IF EXISTS`, and
the conditional form needs a `DO` block the splitter cannot carry. `0005:30-33` says
"(probed: a second full pass is a clean no-op)" — probed by hand, once.

**Recommend:** one integration test that applies the whole set, clears `schema_migrations`,
and applies it again. It would either prove the fourteen claims or find the one that is
wrong, and it is the only thing that can.

### D2 — the migration splitter strips `--` inside string literals, and only the `;` half of that hazard is documented — CONFIRMED

`apps/server/src/healthee/db/migrate.py:38-51`

```python
_LINE_COMMENT_RE = re.compile(r"--[^\n]*")
...
stripped = _LINE_COMMENT_RE.sub("", sql)
return [stmt.strip() for stmt in stripped.split(";") if stmt.strip()]
```

The docstring names the assumption ("migrations contain no `;` or `--` inside string
literals"), and `0010:83-85` repeats it — but only for the semicolon. The `--` case is the
one that will bite first: `COMMENT ON COLUMN` strings are ordinary English and a dash pair
is easy to type, and eleven migrations already carry long prose comments. The failure is
loud, not silent (an unbalanced quote is a syntax error at apply time and the whole file
rolls back), which is why this is hygiene.

Verified clean today: simulating `_split_statements` over all 18 committed files yields 250
statements and **zero** with an unbalanced `'` or `"`.

**Recommend:** a test that runs `_split_statements` over every committed migration and
asserts each statement has balanced quotes. A derived check beats a listed one
(`HOW_WE_VERIFY.md` section 4).

### D3 — the schema drift guard compares only table and index NAMES — CONFIRMED

`apps/server/tests/test_schema_files.py:15-32` extracts `CREATE TABLE IF NOT EXISTS (\w+)`
and `CREATE INDEX IF NOT EXISTS (\w+)` from both sides and asserts set equality. A column, a
type, a nullability, a `CHECK` vocabulary or a foreign-key action can differ between
`db/schema.sql` (the stated reference, `db/__init__.py:3`) and the migrations that actually
build the database, and this passes.

Two things keep it from mattering much. `test_schema_reference_lists_every_rls_policy`
(`:49-67`) does check the 18 policies against the migrations, and two tests interrogate the
**live** database rather than the file for the things that were got wrong before
(`tests/db/test_outcome_ledger_schema.py`, `tests/db/test_program_rung_fk.py` — both open
with "a column/constraint that exists only in `schema.sql` protects nobody"). Spot-checked
against the newest three migrations the reference is currently accurate: `0016`'s
`derived_at`, `0017`'s `device_daily_total` and `0018`'s four nullable stage columns all
appear correctly at `schema.sql:87`, `:107-116`, `:45-48`, and `0010`'s `stalled` status is
at `:319-321`.

**Recommend:** nothing urgent. If it is ever extended, columns and `CHECK` vocabularies are
where the value is — those are what `0009`, `0010` and `0011` added and what code reads.

### D4 — `0018` is committed and unapplied; the code that needs it is merged — CONFIRMED, and the sanctioned deploy path closes it

`db/migrations/0018_sleep_stage_minutes_nullable.sql` drops `NOT NULL` and `DEFAULT 0` from
`sleep_session`'s four stage columns. **Its own reasoning holds**, checked point by point:

* the forward-only claim is correct — a night the strap did not stage and a night of zero
  REM are the same four bytes in every existing row, `stages` is `NOT NULL DEFAULT '[]'` so
  an empty array is equally ambiguous, and no other column records the distinction. No
  backfill would be honest and none is attempted;
* the "catalogue-only, no table rewrite" claim is correct for `DROP NOT NULL` /
  `DROP DEFAULT` in PostgreSQL;
* the "one representation, one meaning" argument against a `has_breakdown` boolean is the
  same argument `#83` and `#118` were paid for, applied before the fact rather than after;
* the other half of the fix **is present**: `ingest/models.py:161-164` defaults all four to
  `None`, and `ingest/upsert.py:156-159` is
  `COALESCE(EXCLUDED.rem_min, sleep_session.rem_min)` on each — so "omitted" and "genuinely
  zero" really are different values on the wire. This closes `WRITE_PATH_AUDIT` B3;
* `schema.sql:45-48` already carries the nullable form.

The operational consequence is worth naming, because `AUDIT_COVERAGE.md:68` lists 0018 as a
deploy prerequisite without saying what happens if it is missed. `upsert_sleep`
(`ingest/upsert.py:147-176`) passes the four values **explicitly** in the `VALUES` tuple, so
against an unmigrated database a push omitting a stage field raises `NotNullViolation`
before `ON CONFLICT` is ever reached (PostgreSQL checks NOT NULL before the speculative
insertion), and the whole push transaction rolls back — every sleep sync fails until the
migration lands.

**Cleared for the sanctioned path.** `infra/deploy.sh` stops `api` and `scheduler` (`:161-162`),
backs up (`:152-154`), applies pending migrations from the **new** image (`:170-171`),
provisions the app role (`:187`), and only then recreates the services (`:203-204`). The new
code cannot serve against the old column. The hazard is real only for a deploy that
bypasses `deploy.sh`.

### D5 — the purge's gated-metric refusal lives in the CLI, not beside the delete — CONFIRMED

`db/rederive.py:180-208` (`purge_metrics`) holds both refusals — `--apply` with nothing
named, and a `GATED_METRICS` name whose gate is shut. Its only caller is `main`
(`:377-381`). `run` (`:305`) and `rederive_owner` (`:211`) take `purge=` and `applying=`
directly and pass them straight to `stale_derived.purge_stale` (`:250`), which applies
neither refusal (`stale_derived.py:129-151`).

There is no such caller today — `grep` over `src/` finds only `main` and the tests. But the
module's own argument is that the gated-metric refusal is *"the single way this feature
could destroy correct data, so it is a refusal with the fix in the message, not a caveat in
the docs"* (`rederive.py:190-194`), and a refusal reachable only through one of three entry
points is a caveat about which door you used.

**Recommend:** move the `GATED_METRICS` check into `purge_stale` itself, beside
`_NOT_WRITTEN_BY_THIS_RUN` and `GATED_METRICS`, which already live in that module. The CLI
can keep its friendlier message.

### D6 — the allowance lock is argued at length and tested nowhere — CONFIRMED

`core/allowance.py:58-69` devotes a full docstring section to why the spend is serialized by
`SELECT … FOR UPDATE` inside one transaction rather than by one self-modifying statement,
and the reasoning is right: the operation is a set edit that must also report *whether it
appended*, and a statement returning only the new value cannot say.

The mechanism is sound on inspection. `_CLAIM_SQL` (`:105-107`) is
`INSERT … ON CONFLICT DO NOTHING`, which waits on a concurrent inserter before deciding;
`_LOCK_SQL` (`:108`) then holds the row for the rest of the transaction, so a second request
blocks and reads committed truth. But `tests/premium/test_allowance_ledger.py` drives an
injectable `now` through a single connection and never runs two transactions against each
other — `grep "FOR UPDATE\|concurren\|thread\|race"` across `tests/premium/` returns nothing
but prose. The one property the lock exists for is the one property untested.

**Recommend:** two connections racing one `spend` at `limit=1`, asserting exactly one
`allowed is True`. The cheapest possible test of the most expensive possible bug on this
path.

### D7 — three private helpers in `jobs/recs_context.py` take an untyped cursor — CONFIRMED

`jobs/recs_context.py:44`, `:62`, `:87` — `cur` has no annotation, against standards
section 2's type-hint rule; the rest of the package annotates `Cur` consistently. Cosmetic.

### D8 — `illness_flag.severity` is parsed, used nowhere, and its docstring names an impossible grade — CONFIRMED

`data/models/illness_flag.dart:42` parses `severity`; `grep severity` over
`apps/mobile/lib/features/` and `shared/` returns only an unrelated comment. The banner has
one visual treatment for `moderate` and `high` alike. Separately, `illness_flag.dart:57`
documents the vocabulary as `mild · moderate · high`, but `mild` cannot occur:
`schema.sql:187` is `CHECK (severity IN ('moderate', 'high'))` and `derive/illness.py:213`
says mild is never written. A docstring naming a state the schema forbids is the same
species as a comment naming a test that does not exist.

### D9 — `top_findings[].points_n` is dropped, and the model docstring describes code that does not exist — CONFIRMED

`read/findings.py:110` ships `points_n` (server-tested at
`tests/read/test_wire_thinness.py:114,145`), and `data/models/finding.dart:153` says *"the
server's `points_n` is what tells the screen how many survived"*. Nothing parses it. The
screen uses `finding.points.length`
(`features/insights/v02/finding_detail_parts.dart:188,195`).

In effect this is harmless and arguably better: the client's own count is the number
actually plotted after `FindingPoint.maybe` drops half-pairs (`finding.dart:148-161`), which
is the stricter and more honest figure. What is wrong is the docstring, which tells a reader
a field is load-bearing when it is inert.

### D10 — the recovery block returns a bare `None` under its own count gate, so the client reports a possible bug — CONFIRMED

`read/recovery_signals.py:120-121` returns `None` when fewer than `_SIGNAL_MIN_DAYS` days of
history exist, with no `withheld`/reason envelope. The client's fallback for an absent block
is `Withheld(unexplained_absence)` (`data/honesty/envelope.dart:85-87`), which renders *"No
value for today, and the server did not say why … if this persists it is a bug on our
side"* (`:44-46`).

The server knows exactly why — `b.n < _SIGNAL_MIN_DAYS` — and does not say. The direction is
the safe one (it under-claims rather than over-claims), but "not enough data yet" and
"something is broken" are the two states standards section 1 requires a caller to be able to
tell apart, and here the honest answer is reported as the alarming one.

---

## E. The five `today.json` models, diffed key by key

`BACKEND_AUDIT.md`'s closing section recorded these five as *"structurally spot-checked
against their Dart counterparts, not diffed key by key … not certified clean to the depth of
section E."* This is that diff.

**Wire → client:** `illness_flag`→`IllnessFlag`, `routine`→`Routine`,
`recommendations[]`→`Recommendation`, `recovery`→`RecoverySignals`,
`top_findings[]`→`Finding`. Entry points confirmed end to end:
`api/routers/today.py:48` → `read/today.py:83-94` → the five builders; client at
`apps/mobile/lib/data/models/today_snapshot.dart:87,98,111,113,116`.

**The snapshot is a live pin, not decoration** — verified rather than assumed.
`apps/server/tests/contracts/test_contracts.py:52` runs `assert_conforms` over
`packages/contracts/snapshots/today.json`; `tests/contracts/shape.py:48-52` enforces
*identical* key sets for dicts (missing **and** extra both fail) and `:68-85` enforces
union-coverage across object lists. The mobile side reads the same file
(`apps/mobile/test/data/today_snapshot_golden_test.dart:26`).

### The three classes the brief named as worst

* **PHANTOM READ (client reads a key the server does not send): none, in any block.** Every
  key the five Dart parsers read is a key the server sends.
* **TYPE MISMATCH: none.** Every nullable wire value is parsed nullably; every numeric is
  read through `num?` and converted; no list is read as a scalar. The two non-null `!` reads
  (`Recommendation.action`, `RecoverySignal.name`) are each backed by a `NOT NULL` column
  **and** an upstream guard (`schema.sql:208`; `today_snapshot.dart:118`).
* **DEFAULT ON ABSENCE: nine, and none fabricates a measurement.**

| default | site | verdict |
|---|---|---|
| `sustained` → `false` | `illness_flag.dart:43` | unreachable (`NOT NULL`, `schema.sql:192`); conservative direction |
| `research_note_ids` → `const []` | `illness_flag.dart:47`, `recommendation.dart:49`, `finding.dart:54` | drops citations, never invents them |
| `meditation.count`/`.minutes` → `0`; `workouts` → `[]`; `kind` → `'workout'` | `routine.dart:100-105`, `:30` | suppressed by `isEmpty`, so nothing asserts "you logged nothing" |
| `favorable`/`unfavorable`/`neutral` → `0`, `total` → `signals.length` | `recovery_signals.dart:120-127` | documented; consumed by nothing |
| `points_truncated` → `false` | `finding.dart:63` | the only default in the flattering direction ("this chart is complete"); unreachable — `findings.py:111` always emits it and `tests/read/test_shaping.py:64-82` pins it |

### Per-block verdict

| block | keys | key-for-key | consumer layer |
|---|---|---|---|
| `illness_flag` | 7 | **CLEAN** | **not clean** — A4, C4, D8 |
| `routine` | 15 | **not clean** — `logs_summary` dropped with a visible consequence (C6); three benign gaps | clean |
| `recommendations[]` | 11 | **CLEAN** — every key rendered somewhere | **not clean** — C5 |
| `recovery` | 7 envelope + 10 per signal | **not clean** — three honesty fields dropped (A3) | partly — see below |
| `top_findings[]` | 16 | **CLEAN except `points_n`** (D9, benign) | **not clean** — A1, A2 |

### Client gaps, complete list

**Honesty fields (A3):** `recovery.signals[].n` (`read/recovery_signals.py:187,248,305`),
`.direction_basis` (`:255`), `.population_floor_min` (`:256`).

**Consequential but not honesty:** `routine.logs_summary` (`read/routine.py:30`) — C6.

**Benign, with the reason each is benign:** `recommendations[].rank` (`read/recommendations.py:15`
— the SQL orders `rank ASC` at `read/today.py:209` and the client preserves list order, so
rank is carried implicitly); `top_findings[].points_n` (D9 — the client's own count is
stricter); `routine.open_fast.id` (no action targets an open fast);
`routine.workouts[].end_iso` (derivable from start plus duration);
`routine.workouts[].intensity` (`read/routine.py:91` hard-codes `None`, so there is nothing
to drop); the free-tier `locked` block that replaces `recommendations`
(`api/gate.py:150,341-356` — `TodaySnapshot.fromJson` yields an empty list, so the app shows
"no suggestions" rather than "this is the paid tier": a missed explanation, not a lie, and
`Entitlement.isLocked` at `data/models/entitlement.dart:147` gives the app the same fact
from `/api/entitlement`).

### Parsed and never drawn

`illness_flag.date` (A4, the worst of this class) · `illness_flag.severity` (D8) ·
`recovery.signals[].direction` · `recovery.favorable`/`unfavorable`/`neutral`/`total` ·
`routine.workouts[].start_iso` · `routine.open_fast.start_iso`.

`direction` is the one to leave alone: `shared/v02/signal_chart.dart:38-41` argues the dot
must **not** be coloured by side, because which side is favourable is a research question,
not a rendering one. That is the right call. The consequence — that the server's per-signal
verdict now reaches the owner only through the aggregate `summary` sentence, with no row
saying whether *it* is the unfavourable one — is worth knowing and is not a defect. The four
tallies are the denominator of legacy's *"N of M favorable"* line, which nothing draws any
more: dead parses, harmless.

---

## F. Swept clean — classes checked, with the evidence

### `db/` — migrations, the purge tool, retention

**F1 — migrations are forward-only and cannot half-apply.** No `down` file, no rollback
path, no `--target`. `_apply_one` (`migrate.py:73-85`) runs every statement of one file
*plus* its `schema_migrations` row on one `admin_connection()`, which commits on clean exit
and rolls back on any exception (`core/db.py:253-260`). Ordering is lexical over
zero-padded four-digit prefixes (`migrate.py:54-56`), chronological for the 18 files present
and for the next 9,981.

**F2 — no migration loses data silently.** Every destructive statement was read with its
header. `0005:41` drops `profile.id` (a surrogate `CHECK (id = 1)` key superseded by
`user_id`, argued at `:1-40`). `0010:86` drops `program.current_rung` (argued at `:81-85`:
"the rungs already say where you are, and a pointer maintained beside them is a second
definition that can drift"). `0012:38` deletes the per-day chain markers *after* folding
them into one row per owner at the **maximum** day, and the choice of `max` is itself
argued — anything lower would re-run and re-send a briefing for a completed day. `0015:23`
deletes the pre-window allowance rows, and its "nothing is lost and nobody gains" argument
is CONFIRMED against the code: `gate.FREE_ALLOWANCE` is all zeros (`api/gate.py:109-115`)
and the premium cap lives under a different key entirely (`allowance:<feature>:30d`,
`core/allowance.py:303-304` with `PREMIUM_WINDOW_DAYS = 30` at `gate.py:135`), so the
deleted rows had no window and no limit to count toward. `0009:59`'s
`ALTER COLUMN … TYPE JSONB USING` **preserves** the old text under
`jsonb_build_object('legacy_note', co_occurring)` rather than dropping it, argued at
`:29-33` — *"'we assume it is empty' is not the same as 'we checked', and the cost of being
wrong is someone's history."*

**F3 — `0018`'s reasoning holds.** Checked point by point in D4, including the half of the
fix that lives in `ingest/`.

**F4 — the purge tool cannot over-reach, and every bound is tested.**
`stale_derived.purge_stale` (`:129-151`) is the only `DELETE` against `derived_daily` in the
tree and is bounded by `user_id = %s`, `day >= %s AND day <= %s`,
`metric = ANY(%s::text[])` and `derived_at < transaction_timestamp()`. The tests were
opened and they assert exactly what the docstrings claim:

| bound | test | asserts |
|---|---|---|
| preview vs apply | `tests/db/test_stale_derived.py:206` | `--purge-stale` alone leaves the row |
| no "delete what you found" | `:215` | `--apply` alone exits 2 and leaves the row |
| compute-once gate | `:224` | `vo2max_submax` refused, exit 2, row survives |
| other metrics | `:252` | an unnamed metric's stale rows survive |
| the day window | `:269` | rows outside the span survive |
| the owner, under RLS | `:282` | another owner's row survives the CLI path |
| the owner, as a predicate | `:293` | run on the **admin** connection, which bypasses RLS, so a missing `user_id = %s` would be observable at all |
| the empty list | `:311` | `metric = ANY('{}')` removes nothing — there is no "all" spelling |
| honest counts | `:325` | the reported number is the `DELETE`'s own `RETURNING` |
| the discriminator | `:343` | only rows this transaction did not write are counted |

`db/rederive.py:196-208` holds the two refusals and
`tests/db/test_rederive.py:214-244` covers the gate-reopened, no-gate-needed and
purge-nothing-without-apply cases. This confirms and deepens `BACKEND_AUDIT` E10, which
cleared the same tool from the code alone. The one structural seam is D5.

**F5 — `claim_sentinel`'s delete cascades cleanly.** `_rekey` (`:190-212`) is three
statements in that order: park the target's device tokens on the sentinel, delete the
target's `app_user` row to free the primary key, re-key the sentinel onto it while stamping
the target's real email and timezone. The `DELETE` at `:208` can only cascade to rows the
target owns, and `plan` (`:168-175`) has already proved they own none — using the table
list the **database** supplies (`referencing_tables`, `:107-113`, off `pg_constraint`)
rather than a hand-written one that could miss a table added later. Device tokens are the
one deliberate exclusion and they are parked, not cascaded, so a device paired before the
claim is not silently unpaired. `_verify` (`:215-235`) then walks *every* referencing table
including the identity ones and raises if anything still belongs to the sentinel, and the
whole thing shares one transaction (`claim`, `:244-258`), so a failed post-check rolls the
re-key back rather than scattering one person's history across two owners. The one gap is
C1.

Two residuals recorded rather than raised: `_count_rows` (`:121-133`) hardcodes
`WHERE user_id = %s`, so a future table referencing `app_user` through a differently-named
column raises `UndefinedColumn` — **loud**, which is the right direction; and the table name
is composed with `psycopg.sql.Identifier` rather than an f-string even though it comes from
the catalog, which is the standard's rule applied where it was not strictly needed.

**F6 — no path drops or truncates a tenant table.** A sweep for `TRUNCATE`, `DROP TABLE` and
`DROP SCHEMA` across `src/healthee/` returns only prose. `provision_app_role.py:106-108`
grants `SELECT, INSERT, UPDATE, DELETE` and comments that TRUNCATE is *"the one DML-shaped
privilege that can erase a life's health history in one statement"*; `:114`'s
`_READ_ONLY_REVOKED` revokes it explicitly rather than merely not granting it, because
`ALTER DEFAULT PRIVILEGES` would hand it to a table a future migration creates; and `:120`'s
`_ROLE_ATTRIBUTES` spells out `NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE`. The only
`TRUNCATE` in the repo is `tests/contracts/seed.py::reset`, on the admin connection, in the
test harness (`core/db.py:284` lists it as a sanctioned caller). This confirms and extends
`BACKEND_AUDIT` E9 into the `db/` package itself.

**F7 — `subscription` cannot be written from a request path.** `provision_app_role.py:104`
puts it in `_READ_ONLY_TABLES` so the API and scheduler role holds `SELECT` and nothing else,
and `db/grant_premium.py` — the one writer — runs as the admin (`core/db.py:278-283`).
Entitlement is a privilege, not a code review.

**F8 — the migration splitter is currently safe.** Simulating `_split_statements` over all
18 committed migrations yields 250 statements with **zero** unbalanced `'` or `"`. The
latent hazard is D2.

### `jobs/` — the nightly chain

The chain, with what each step writes and in which transaction:

| # | step | file:line | writes | transaction |
|---|---|---|---|---|
| 1 | `illness` | `chain.py:234` → `steps.py:33-47` | `illness_flag` upserted or deleted | own (`steps.py:46`) |
| 2 | `challenges` | `chain.py:237-239` → `steps.py:50-79` | `challenge` · `program` · `challenge_outcome` | one shared, deliberately (`steps.py:65-76`) |
| 3 | `correlate` | `chain.py:240-243` → `correlate.py:27-47` | `finding` | two, inside `analytics/` |
| 4 | `recs` | `chain.py:270` → `recs.py:127-203` | `recommendation`, DELETE-then-INSERT for the day | own (`recs.py:316`) |
| 5 | `warm` | `chain.py:271` → `coaching.warm_lines` | `kv` cache rows keyed on the owner's today | own, per write |
| 6 | `briefing` | `chain.py:254` → `briefing.py:38-65` | nothing durable — sends Telegram | none |

Steps 4-6 are skipped for a non-premium owner by one `is_premium` lookup taken before any
step (`chain.py:227-229`); `illness` is inside the free set by policy, not accident
(`PRICING.md` section 1a: never paywall safety).

**F9 — no swallowed errors.** Exactly two `except` clauses exist across the nine modules
(`chain.py:187`, `scheduler.py:161`); both `log.exception` with context, send Telegram, and
return a typed failure outcome. Nothing returns `{}` or `""` to mean failure. Standards
section 1's "background contexts must report to their health surface" is met.

**F10 — no `subprocess`, no import-time side effects.** Legacy's
`Popen("healthee correlate && …")` is gone; every step is an in-process supervised call
(`chain.py:1-14`, `scheduler.py:1-7`). Standards section 2.

**F11 — the dependency logic between steps is correct and tested.** A `correlate` failure
skips `recs` and `warm` with a named reason (`chain.py:251-252`, `:289-303`); `warm` and
`briefing` failures are non-fatal; `challenges` is never reached back into.
`tests/jobs/test_chain_supervision.py:85-213` asserts each of these **on a call counter**,
not on a status string — so an implementation that ran a step and discarded its output would
fail. Same for the free-tier gate at `:257-275`. That is the right assertion, and it is what
makes B1's absence conspicuous rather than expected.

**F12 — no job writes a value under the wrong day.** Every day resolution is per-owner from
the owner's `tz`: `scheduler.py:156-157` (`local_now(...).date()`), `chain.py:222`
(`day or user_today(tz)`), `derive/illness.py:261-291` (bounds every input at or before
`day`), and the warm cache is stamped `today_iso(tz)` with `steps.py:112-115` documenting
that `_day` is *deliberately* unused so a forced past-day chain warms today's lines rather
than filing today's advice under yesterday. `jobs/recs.py:168-176` goes further and
**refuses** any day but the owner's today with an explicit `ValueError`, argued at
`:142-166`; `tests/jobs/test_recs_day.py` proves the refusal fires before any model call by
injecting a `_NeverCalled()` client. There is no `date.today()` and no naive `now()`
anywhere in `jobs/`. The single exception is C2, which is not reachable in production.

**F13 — the dedup marker's shape, growth, monotonicity and per-owner isolation.**
`tests/jobs/test_chain_marker.py:78-201` covers same-day dedup, next-day fire, two owners
independent, 400 days producing exactly one row per owner (`:118-132`), and `greatest()`
never moving the mark backwards (`:135-152`). `:220-264` replays migration `0012`'s own
statements — read from the file rather than copied — and proves it takes the maximum day
and is replay-safe. These guards were opened and they assert what `chain.py:86-110` claims.
What they do **not** cover is B1.

**F14 — a backwards clock cannot re-run a day.** `_chain_done` compares `value >= day`
against a high-water mark (`chain.py:314-319`), so a local date that regresses across a zone
change reads as already covered. Safe by the marker's monotonicity rather than by a special
case, which is the better shape.

**F15 — two runs cannot overlap in the shipped deployment.** `scheduler.py:219-222` is a
single-threaded `while True` with a blocking `sleep(300)`, so a slow tick delays the next
rather than running beside it. Across processes the marker *is* a check-then-act, with the
whole chain between the read (`chain.py:306-319`) and the write (`:334-339`) and no lock
anywhere — `grep pg_advisory` over `src/healthee/` returns nothing, and the only row lock in
the codebase is `core/allowance.py:108`. What prevents it is the deployment:
`infra/docker/docker-compose.prod.yml` defines one `scheduler` service with a fixed
`container_name`, which compose cannot scale past one replica. Recorded as **latent, blocked
by the deployment shape rather than by the code.** If that ever changes, `recs._persist` is
DELETE-then-INSERT for the day (`recs.py:316-335`) and `correlate` upserts on its key, so
both are idempotent; the exposure would be `step_challenges` (`steps.py:76-79`), whose two
calls would run twice in one transaction.

*Recommend, not raised:* a `pg_try_advisory_xact_lock` on the owner around the chain would
cost one line and turn "safe because compose will not scale it" into "safe because it
cannot happen".

**F16 — a `correlate` failure re-sends the briefing, and the module says so.** `briefing`
runs unconditionally at `chain.py:254`, including on the failure branch, which leaves the
day unmarked — so the next tick repeats the chain, briefing included. Bounded to three by
`_ATTEMPT_BUDGET` (`scheduler.py:83`), and `scheduler.py:76-82` states this outcome in its
own words ("plus a re-sent briefing each time"). A declared, bounded cost; recorded rather
than raised.

**F17 — no LLM call in `jobs/` bypasses the choke point.** The package imports
`insights.grounded.grounded_ask`, `insights.morning`, `insights.coaching` and the
`LLMClient` *type*; no choke-point primitive is imported and no client method is called
directly. Standards section 2's `pipeline.py` rule holds here.

**F18 — file and function size gates.** Largest module in `jobs/` is `chain.py` at 339
lines; no function exceeds 40 lines excluding docstrings.

### The credits ledger and the challenges internals

**F19 — the ledger cannot double-charge or lose a charge.** Six mechanisms, each read end to
end:

1. **Serialization.** `spend` (`core/allowance.py:150-160`) claims the row with
   `INSERT … ON CONFLICT DO NOTHING` — which waits on a concurrent inserter before deciding —
   then holds it with `SELECT … FOR UPDATE` for the rest of the transaction, so a second
   request blocks and reads committed truth rather than both seeing "one used".
2. **A refusal is not recorded** (`:158-159`, argued at `:50-56`): pushing a fresh instant on
   every refused attempt would stop the window ever rolling and lock the owner out forever.
   `tests/premium/test_allowance_ledger.py:165` asserts it.
3. **The truncation cannot drop an in-window instant.** `(window + [now])[-limit:]` runs only
   when `len(window) < limit`, so the slice is a no-op; a *lowered* limit reaches the write
   through the refusal branch, which prunes but does not truncate.
4. **A refund is net-neutral and cannot mint.** `refund` (`:205-238`) pops the newest instant
   from the **pruned** window, so it can only ever remove one, and only one still inside the
   window. `test_allowance_ledger.py:183` and `:192` assert both.
5. **A double refund cannot mint a second use.** `gate.refund_ai_use` (`api/gate.py:302-309`)
   clears `_CHARGED_ATTR` before calling, so a handler that refunds in both a branch and its
   `except` refunds once.
6. **One question charges once, whatever the model does.**
   `tests/premium/test_premium_cap.py:261` —
   `test_a_tool_calling_question_charges_once_not_once_per_model_call`. The gate is a FastAPI
   dependency and the five gated user types are module-level singletons
   (`gate.py:370-374`), so no route can charge twice through two instances.

The two priced windows are structurally separated by
`allowance:<feature>:<window_days>d` (`:303-304`), asserted by
`test_the_two_windows_do_not_share_a_kv_row` (`test_allowance_ledger.py:260-277`) and
`test_a_lapsed_owners_free_row_and_their_paid_row_are_different_rows`
(`test_premium_cap.py:374`). The one gap is D6.

**F20 — the rolling window is computed correctly at its boundaries.** `_resets_at`
(`core/allowance.py:256-268`) moves the owner's local calendar date forward `window_days`
and keeps the wall-clock time, rather than adding N×24 h, and `_in_window` (`:271-273`) keeps
a use while `now < resets_at` — half-open, so the use rolls out at exactly its anniversary.
The boundary suite drives an injectable `now` and asserts the edges directly: refused at
6 d 23 h and granted at exactly 7 d (`test_allowance_ledger.py:81-89`), a local midnight
*not* resetting it the way a daily counter would (`:92-103`), the 30-day window counting 719
hours rather than 720 across a DST transition and landing back on the promised 21:00
wall-clock (`:127-150`), and 29 vs 30 local days (`:153-159`). Each was opened. One residual
recorded: `spend`'s `if limit > 0 else []` branch (`:159`) is unreachable, because
`allowed = len(window) < limit` is already false at `limit <= 0`, and `gate._free`
(`api/gate.py:271-273`) refuses before calling at all — so the "retry now, forever" verdict
`_verdict` would produce at `limit == 0` never reaches an owner.

**F21 — the ladder cannot adapt into a state nothing supports, and rungs stay inside their
bounds when re-activated.**

* **Every terminal status the code writes is in the database's vocabulary.** `ladder._end`
  (`:273-284`) writes `completed`, `stalled` and `abandoned`; all three are in
  `program_status_chk` (`0010:67-69`, mirrored at `schema.sql:319-321`). `insert_rung`
  writes `kind='deload'`, which is in `challenge_kind_chk` (`0010:52-54`).
* **Every transition carries its predicate in the statement.** `mark_ended`
  (`program_store.py:205-224`, `… AND status = 'active'`), `mark_adopted` (`:190-203`,
  `… AND status = 'suggested'`) and `activate_rung` (`:240-270`, `… AND status = 'locked'`)
  each return `rowcount == 1`, and both callers **raise** on false (`ladder.py:276-277`,
  `rung.py:131-135`) rather than continuing on a stale read.
* **Re-activation is bounded by Gate A's own band.** `rung.recalibrated_target` (`:148-205`)
  reads `bounds.calibrate` at the moment the rung starts, and `_snap_into` (`:220-233`)
  rounds *inward* — up at the low end, down at the high end — then falls back to the band
  edge verbatim when no step multiple fits inside a band narrower than one step, so the
  returned target is provably inside the band or is the band. A deload is exempt with the
  argument written out (`:160-172`): its target was computed from the owner's current data
  seconds earlier, and recalibrating it would snap it *above* the number they just failed,
  making the whole failure branch dead code.
* **The deload loop terminates and cannot double-insert.** `_already_deloaded`
  (`ladder.py:178-187`) is a real idempotency guard needing no extra column — "the rung at
  index + 1 is a deload" is an exact record of having been here — and without it a failure
  whose deload could not be activated would grow a new deload every nightly tick.
  `_deloads_in_run` (`:228-243`) counts back through the unbroken run of expired rungs and
  stops at `MAX_CONSECUTIVE_DELOADS = 2`, which is three failures including the original.
* **A zero-rung ladder cannot exist, and so cannot be marked "completed".** `advance_due`
  would `_end(..., "completed")` a program with no rungs (`:251-253`), but the state is
  unreachable: `program_screen` refuses a design outside `MIN_RUNGS = 3 … MAX_RUNGS = 6`
  (`program_screen.py:150-153`, `program_prompt.py:35-36`); `program_generate.py:202-218`
  inserts the program and every rung inside **one** `tenant_transaction`; and
  `programs.adopt` re-refuses `no_rungs` at adoption (`programs.py:105-107`) on the stated
  principle that "a stored row is not proof it is expressible".
* **`shift_rungs_after` cannot violate a constraint.** `challenge_program_rung_idx`
  (`0010:58-59`, `schema.sql:300-301`) is a plain index, not unique, so the bulk
  `rung_index = rung_index + 1` cannot hit a transient duplicate. Nothing structurally
  prevents two rungs sharing an index, but the only two writers — `insert_rung` with an
  explicit index, and this shift — cannot produce one.

**F22 — `0013`'s `ON DELETE CASCADE` claim is true.** The migration asserts that *"the only
program ever deleted is an un-adopted suggestion whose rungs never ran"* (`0013:60-63`).
Verified: the only `DELETE FROM program` is `program_store.delete_suggested_programs:186`,
scoped to `status = 'suggested'`, and its companion rung delete at `:182-185` puts the status
predicate **inside the subquery** so a live ladder's rungs cannot be caught by it;
`mark_adopted:196-201` flips a program to `active` before its first rung starts
(`programs.py:98-102`), so an adopted ladder is permanently outside the delete's reach; and
terminal programs are never deleted at all. `challenges/store.py:159`'s standalone-suggestion
delete carries `AND program_id IS NULL` for the same reason.

**F23 — `insights/credits.py` is the OpenRouter balance probe, and its arithmetic and
thresholds are clean.** `remaining_usd = total - used` (`:179`); `exhausted` is `<= 0` and
deliberately not `< threshold`, because at or below zero every call 402s and that is a
different event (`:102-108`); a failed or shape-changed probe returns `ERROR`, never a
plausible-looking zero (`:166-175`, and the comment names both sign errors); freshness is
measured on `time.monotonic` so an NTP step cannot make a cached reading look younger
(`:126-129`); the API key reaches the wire and never a log, and the error path records the
status code and exception type only, never the response body (`:39-43`, `:155-162`).
`UNCONFIGURED` is kept distinct from `ERROR` — a deployment with no key is a supported
configuration, not a fault. This is standards section 1's "no data and operation failed are
different states" applied correctly, including to a cached failure.

**F24 — `windowed.py` refuses to invent the number the corpus refuses to state.** A windowed
metric is an ordinary registry entry (`:96-118`), deliberately **not** a subclass of
`ManualEntrySource` so that no `isinstance` dispatch can sweep it up and hand it the
zero-fill it exists to refuse (`:100-106`) — the type checker is made to force each dispatch
to decide. Its hours and substances are the cutoff finder's own (`CUTOFF_HOURS` /
`SUBSTANCE_CONFIG`, `:92-93`), and `metric_key` (`:120-128`) is byte-identical to the
`metric_a` that finder writes, so the finding-to-challenge link is equality rather than a
parser that could drift — one definition, per `CLAUDE.md`. Cadence is `daily`-only because a
`weekly`/`total` rule sums its days and a sum cannot tell an unmeasured day from a zero one
(`:53-60`). And `levers._unfounded_window` (`:311-334`) **blocks** a window outright unless
the owner's own FDR-controlled finding names that exact hour — the corpus evidences late
intake and explicitly declines to name an hour, so choosing one would be inventing precisely
the number the evidence base refuses. This is the honesty contract enforced structurally,
and it is the cleanest example of it in the package.

**F25 — the coach's 10-second timeout is closed in code.** `AUDIT_COVERAGE.md:57` lists
"whether the coach's 10-second timeout has actually charged the owner" as needing
production. The mechanism no longer exists: `apps/mobile/lib/core/env.dart:121` defines a
dedicated `coachTimeout` of **180 s**, applied at
`apps/mobile/lib/data/coach/coach_client.dart:156-158`, and both files carry the exact
reasoning — *"the gate charges the slot before the handler starts, so the socket closing at
ten seconds left the server producing an answer, charging for it, matching no refund branch,
and delivering it to nobody."* The server pays out on all four no-value branches
(`api/routers/coach.py:110-119`: the exception path refunds then re-raises unchanged, and
`refused | not validated | not answered` refunds). **Residual, stated rather than raised:** a
turn that genuinely exceeds 180 s still charges and delivers nothing, and the client's word
for that state is `CoachCharge.unknown` (`coach_client.dart:162`) — the honest vocabulary,
not a fabricated one.

### The five models

**F26 — no phantom reads and no type mismatches anywhere in the five blocks**, plus: every
`null` path resolves to a refusal or a silence, never to an invented number;
`FindingPoint.maybe` (`finding.dart:148-161`) drops half-pairs instead of zero-filling;
`RecoverySignals.maybe` (`recovery_signals.dart:107-108`) refuses an empty ladder rather than
drawing an empty frame; `IllnessFlag.maybe` (`illness_flag.dart:36-39`) refuses a flag with
no calibrated sentence, so `framing` gates the whole banner; the
`baseline`/`baseline_sd`/`z` triple reconciles and has a real golden test behind it
(`today_snapshot_golden_test.dart:86-105`, opened, asserts
`z == (value − baseline) / sd`); `Recommendation.gradeLabel` (`:107-111`) returns **null**
for an unrecognised evidence rank rather than guessing; and the degenerate empty-framing
illness sentence is unreachable, because a flag only fires when a limb fires and a fired limb
has a non-null delta (`derive/illness.py:138-139, 289-290`).

---

## G. Could not determine, and why

1. **Whether B1 has ever cost this owner an illness flag in production.** It needs the
   `illness_flag` table read against the chain's log history. Out of scope by the brief and
   by `AUDIT_COVERAGE.md`'s standing decision that device and production checks happen after
   the audit programme.
2. **Whether A2 fires for this owner today.** It requires at least one `significant = TRUE`
   finding of kind `event_effect` or `personal_cutoff` in the owner's `finding` table. The
   code path is confirmed reachable; whether a row currently exists is a live-database
   question.
3. **Whether C3 is reachable for this owner.** It turns on the distribution of `window_days`
   in the challenges the model has actually generated, which lives in the production
   `challenge_outcome` table.
4. **The real cost of `correlate`'s unbounded read.** `analytics/series.py:47-52` calls
   `daily_series` with `since=None` on purpose (*"the correlation engine needs every day it
   has"*) and `event_days` (`:94-110`) has no date bound in either direction. The
   unboundedness is confirmed from the code; its wall-clock cost is not, and no performance
   measurement was taken here — that is `AUDIT_COVERAGE.md` item 6 and it remains open. Two
   observations recorded rather than raised: the *payload* is capped at 90 paired days per
   finding (`analytics/correlations.py:44-54`), so the standards' "unbounded data is
   windowed" is honoured on the wire but not in the query; and the missing **closing** edge
   makes `correlate` a second consumer of `BACKEND_AUDIT` A11's gap, not a new finding — a
   future-dated `derived_daily` row would enter tonight's correlation. Bound it at
   `day <= user_today(tz)` when A11 is closed.

---

## H. Recommended order

Ranked by whether the damage reaches the owner, then by cost to fix.

1. **A1** — render `effect_metric`. One line, and it is a wrong instrument name on a number,
   the same class as `BACKEND_AUDIT` A1.
2. **A2** — give `describeFinding` the `event_kind` branch, and point the wording test at
   both composers. The raw statistic is on the home screen for the second time.
3. **A4 + C5** — one shared "these are from &lt;day&gt;" helper, applied to the illness
   banner and the v02 Actions screen. Three surfaces have now needed the same fix; the fourth
   should not be a fourth patch.
4. **A3** — parse `n`, `direction_basis` and `population_floor_min`, and render at least the
   first two. The server work is done and tested; only the boundary is missing.
5. **B1** — gate the chain marker on `illness`, move it below the briefing step, and test
   every failure path.
6. **C4, C6, D10** — three disclosure corrections: drop the duplicated delta line, let
   `logs_summary` reach `isEmpty`, give the recovery block a reason when its count gate
   fires.
7. **C1** — one entry in `_NON_TENANT_TABLES`.
8. **D6, D1, D2** — three tests that would each have caught a class this audit could only
   reason about: the allowance lock, the migration replay, the splitter's quoting.
9. **C2, C3, D5, D3, D7, D8, D9** — corrections and hygiene.

Nothing here should be run against production without the owner's word.

---

## I. What this closes, and what it does not

`docs/AUDIT_COVERAGE.md` items **4, 5, 7 and 8** are now examined. Item **6** (performance
against the standards' budgets) is the last unexamined item; items 1, 2 and 3 were closed by
the auth, write-path and knowledge audits. Of the four questions listed there as needing
production, **the coach-timeout question is now answered from code** (F25); the other three
stand.

Two things this audit did **not** re-open, deliberately: `ingest/` and `derive/`
(`WRITE_PATH_AUDIT.md` owns them, and its A1 and B1 remain open on their own merits), and the
`insights/` choke point beyond confirming that `jobs/` does not go around it.

The honest caveat is the one `AUDIT_COVERAGE.md` already states: completing the programme
means every area has been *examined* against the honesty standard. It does not mean no defect
remains — this audit found four owner-facing defects in the one place a previous audit said
it had not looked closely, which is the argument for the caveat rather than against it. What
it does mean is that no area is unexamined, and that is the only claim worth making.
