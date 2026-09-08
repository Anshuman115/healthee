# Backend audit — the server against its own documents, and against what the app draws

Read-only audit of `apps/server/`, with `apps/mobile/lib/` read as the consumer of the
wire, against `CLAUDE.md`, `docs/ENGINEERING_STANDARDS.md`, `docs/HOW_WE_VERIFY.md`,
`docs/AS_OF_DAY.md`, `docs/BACKEND_GAPS_FROM_UI.md`, `packages/knowledge/` and
`packages/contracts/snapshots/`.

The standard applied is the product's own: **"not enough data" always beats an optimistic
guess.** A number reaching a screen from a default, a constant, or a window narrower than
its name violates that premise whether or not it is arithmetically defensible.

**Every finding carries `file:line` and is marked CONFIRMED (code path read end to end) or
SUSPECTED (looks wrong, could not be proven read-only).** Cleared classes are reported too:
a swept class is a result, and the only thing that makes "the backend is done" verifiable
rather than hopeful.

Findings are ranked by **whether the wrong number reaches a screen today**, which is not the
same as how wrong it is. Three of the worst-looking defects sit on payload blocks the app
never parses; they are in section B with the reason stated, because that is the honest
ordering and because they become section-A defects the day someone wires them up.

Nothing was changed BY THE AUDIT. This document recommends; it does not fix.

**Status: every finding is now resolved.** Severity A was fixed and merged first;
sections B, C and D followed. Two findings needed no code — B1 had been closed by the A
pass's `read/acwr.py`, and C1 by its `_stub_night` — and both are recorded as such below
rather than ticked. The rest carry a **RESOLVED** line saying what was done, because the
useful record is not that a box was ticked but which of the three honest moves was taken:
serve the true value, withhold with a reason, or name the limit on the face.

Two things were found while fixing, neither of them in this document:

* **Sleep need had FIVE definitions, not the three C3 and C4 name.** A fourth sat in
  `read/health_metrics.sleep_debt_payload` (`need = need_row[1] if need_row else 480.0`)
  and a fifth in the client's `SleepDebt` parser (`?? 480`). Both were barely reachable,
  which is the argument for removing them rather than against it.
* **`distance_m_daily` shares C7's defect exactly.** The stride tier multiplies the step
  count, so a day nobody counted produced a distance of 0.0 by the same route and entered
  the distance baseline the same way. Fixed with it.

---

## 0. Counts

| Severity | Meaning | Count |
|---|---|---|
| **A — misleads the owner now** | an invented, unqualified or provably wrong value reaches a screen | 13 |
| **B — wrong on the wire, not drawn** | the payload is wrong; today nothing renders it | 4 |
| **C — thin** | the screen works, but the payload says less than it knows | 8 |
| **D — hygiene** | standards violations with no direct honesty consequence | 5 |
| **Swept clean** | classes checked with evidence, no finding raised | 10 classes |

CONFIRMED 27 · SUSPECTED 3 · Corrected from a prior reading 3 (anchor 1's mechanism; the
severity of three payload blocks; one reported-missing test that exists under another name).
Could not determine: 2.

---

## A. Misleads the owner now

### A1 — the ± band on the VO2max card can be the constant #108 deleted for being unsourced — CONFIRMED

`apps/server/src/healthee/read/vo2max.py:186`

```python
"see_ml_kg_min": float(flags.get("see_ml_kg_min", 5.6)),
```

`apps/server/src/healthee/derive/vo2max.py:60-71` records the history in its own words:

> Jurca 2005, Table 5, NASA column: SEE = 1.45 METs for the model whose coefficients we
> use. **Corrected in #108 from an unsourced 5.6 ml/kg/min, which appears nowhere in the**
> [source] … `_JURCA_SEE_ML_KG_MIN = _JURCA_SEE_METS * _METS_TO_ML_KG_MIN  # 5.075`

The derive layer writes 5.075. The read layer restores 5.6 for any row whose flags lack the
key — every pre-#108 row, and any tier that did not stamp one. The default is a bare float
with no null branch, so the payload **always** carries an error bar, including when the row
carries no error figure at all; `see_source` on line 185 is then null beside it, so the
wire says "plus or minus 5.6" and declines to name the instrument. The comment two lines
above is the argument against exactly this: *"`see_source` says WHICH, so a percentage
error cannot be read as a standard error of estimate."*

**It is drawn.** `apps/mobile/lib/data/models/vo2max.dart:141` parses it as
`standardErrorMlKgMin`; `apps/mobile/lib/features/activity/v02/fitness_panels.dart:15`
renders the band and its explainer.

This is the single most serious finding: a refuted constant, live on a screen, in the
metric this repo built specifically so that it would name its own error.

**Recommend:** `flags.get("see_ml_kg_min")` with no default; null when absent, paired with
`see_source` the way `estimate` and `method` are already paired.

### A2 — an unrecorded sex renders as "M" on the Today card, and is spent on the age median — CONFIRMED

`apps/server/src/healthee/read/vo2max.py:161`

```python
age = int(flags.get("age_years") or 0)   # line 160 — GUARDED, see D1
sex = str(flags.get("sex") or "male")    # line 161 — NOT guarded
```

Line 160 is the brief's named-clear site and it is genuinely clear: line 162 is
`median_ref = vo2max_median_for(age, sex) if age else None`. The line beneath has no such
guard, and `sex` is both **shipped** (line 191) and **spent** — `median_for_age` and
`delta_from_median` are computed against the male reference distribution for an owner whose
sex was never recorded.

**It is drawn**, and literally: `apps/mobile/lib/features/today/widgets/vo2max_card.dart:65`
is `final sex = vo2max.sex == 'female' ? 'F' : 'M';`, so absence renders as the letter M.

The same default exists at `derive/trimp.py:37,46` (`_DEFAULT_SEX = "male"`) and there it is
correctly fenced — `read/workout.py:159` computes TRIMP only `if … sex in ("male",
"female")`. One of the two call sites of one fallback checks; the other publishes.

**Recommend:** `sex = flags.get("sex")`, null on the wire, with `median_for_age` and
`delta_from_median` withheld and reasoned when it is absent — exactly as they are for `age`.

### A3 — a VO2max computed outside the model's validated range renders at full confidence — CONFIRMED

Server side is right. `apps/server/src/healthee/derive/vo2max.py:178-196`
(`out_of_range_inputs`) builds an owner-facing message for an age or BMI outside Jurca's
validated bounds, per Directive 5 of `[[non_exercise_vo2max]]`, and
`apps/server/src/healthee/read/vo2max.py:214` puts it on the wire:

```python
"out_of_range_inputs": out_of_range_inputs(age or None, flags.get("bmi")),
```

Client side drops it. `apps/mobile/lib/data/models/vo2max.dart` has no field for it, and the
honesty envelope at `apps/mobile/lib/data/honesty/envelope.dart:69-90` inspects only
`caveats`, `excluded` and `withheld` — `out_of_range_inputs` is none of those keys, and the
`vo2max` block carries no `caveats` sibling. So the estimate resolves to `Present<Vo2max>`:
full confidence, no caveat, for a number the server explicitly flagged as outside the range
its model was tested on.

The honesty layer is a sealed union precisely so that "a number cannot reach a screen
without its confidence" (`docs/HOW_WE_VERIFY.md` section 3). Here a confidence the server
computed does not reach it, because it was filed under a key the envelope does not read.

**Recommend:** either rename the key to `caveats` so the existing envelope picks it up with
no new client code, or add the field and map a non-empty list to `Caveated`. The first is
smaller and closes it at the source.

### A4 — a two-week-old measurement is presented as today's fitness — CONFIRMED

`read/vo2max.py:179` ships `measured_as_of` as a field **distinct** from `as_of_date`,
because they are different facts: `derive/vo2max_tier.py:263-265` sets `measured_as_of =
tier.last_day`, which for the `gps_graded` and `hr_reserve` tiers may be up to
`MEASURED_VO2MAX_MAX_AGE_DAYS = 14` days (`derive/freshness.py:210`) before the row's own
day.

`apps/mobile/lib/data/models/vo2max.dart:132-160` parses `as_of_date` and not
`measured_as_of`; `apps/mobile/lib/features/activity/v02/fitness_panels.dart:120` draws
`vo2max.asOfDate`. The comment at
`apps/mobile/lib/features/today/v02/longer_panels.dart:9-10` claims `measured_as_of` "is on
the panel". It is not.

So a card can read "as of today" over a run recorded a fortnight ago. That is the
stale-as-current class the whole freshness module exists to prevent — reached through the
client rather than through the server, which is why the server's guard did not catch it. The
horizon that permits a 14-day-old measurement to speak is argued at length in
`derive/freshness.py:170-212`; the argument depends on the owner being told which day it
was measured.

**Recommend:** parse and draw `measured_as_of`, and show it whenever it differs from
`as_of_date`.

### A5 — a night with no stage breakdown is drawn as a night of zero sleep — CONFIRMED (anchor 1), mechanism CORRECTED

The full chain, end to end:

1. **Ingest converts absence to zero.** `apps/server/src/healthee/ingest/models.py:62-65`
   gives `SleepIn` the defaults `rem_min: int = 0`, `light_min: int = 0`, `deep_min: int =
   0`, `wake_min: int = 0`, and `ingest/upsert.py:126-134` inserts them unconditionally.
2. **Storage cannot express absence.** `db/schema.sql:41-44` declares all four columns
   `INTEGER NOT NULL DEFAULT 0`.
3. **The read layer sums them.** `read/sleep_extras.py:53`, `:105`, `read/sleep_page.py:140-142`:
   `"duration_min": (light or 0) + (deep or 0) + (rem or 0)`.
4. **The client falls back to them.** `apps/mobile/lib/features/sleep/sleep_history_screen.dart:162`
   and `apps/mobile/lib/features/sleep/sleep_windows.dart:61`:
   `durationMin: night.tstMin.valueOrNull?.round() ?? night.stages.total.round()` — when
   `tst_min` is correctly **withheld**, the client replaces the withhold with the stage sum,
   which for an unstaged night is zero.
5. **The chart draws it.** `apps/mobile/lib/shared/charts/h_stacked_sleep.dart:82-116`
   iterates the four stage ints with no no-session check and paints zero-height segments —
   pixel-identical to a night of literal zero sleep. Reused by Today's `SevenNightCard`
   (`features/today/widgets/seven_night_card.dart:60`) and Sleep's `NightStagesPanel`.

**The brief reads step 3 as summing NULLs. It cannot: the schema forbids NULL there and the
`or 0` guards are dead code.** The zeros are manufactured at step 1, one layer below any
honesty check, and by the time the read layer sees the row the fact that there was no
breakdown is gone. That is worse than the brief's reading, because it is not fixable in
`read/`.

Two things make the failure legible as a defect rather than a design choice:

- **The correct handling already exists 200 lines away.** `read/recovery.py:265-267` — `if
  not row or not row[0]: return None` — treats a zero stage-sum as absence and withholds.
  Two places read one quantity and answer differently about what zero means.
- **The gap-preserving machinery exists and works on the same screen.**
  `apps/mobile/lib/features/sleep/v02/history_panels.dart:83-84` keeps `null` for an
  unmeasured night so the duration line breaks — from the same `SleepNight` object, one file
  away. The stage chart is the one place it was not applied.

Compounding, `apps/mobile/lib/data/models/sleep_history.dart:30` gives the parallel
`sleep_history_7d` model `?? 0` on every stage field with no honesty wrapper at all.

**Recommend:** make the stage minutes `int | None = None` on `SleepIn`, drop the `NOT NULL
DEFAULT 0` in a migration (or add a `has_breakdown` marker), let `duration_min` be null
without a breakdown, and give `h_stacked_sleep.dart` a no-data bar. Report `end_ts -
start_ts` separately as time in bed, which is a different and honestly-nameable quantity.

### A6 — three ingest upserts clobber complete rows with defaults — CONFIRMED

`ingest/upsert.py:130-134` (`sleep_session`), `:161-164` (`workout`), `:306-308`
(`device_daily_total`) are all `ON CONFLICT … DO UPDATE SET col = EXCLUDED.col` with no
`COALESCE`. With the pydantic defaults in `ingest/models.py` (`SleepIn` stages → `0` /
`[]`; `WorkoutIn` `sport=0`, `duration_s=0`, calories/distance/HR → `None`), a partial
re-push of an existing key replaces measured data with defaults.

The team identified and fixed this exact class one table over — `ingest/upsert.py:206-212`
`COALESCE`s `profile.srpa` precisely "so a plain assignment would let the next routine sync
from an un-updated app NULL out an answer the owner had given" — and did not carry it
across.

The shipped client always sends complete records
(`apps/mobile/lib/data/push/push_batch.dart:162-181`), so this is **latent, not live**. It
is ranked in A rather than B because it is the mechanism by which A5's zeros can replace a
night that was recorded correctly, and because `/ingest/helio` is reachable by any device
token, including an older app build.

**Recommend:** `COALESCE(EXCLUDED.col, table.col)` on every optional measurement column in
all three, alongside A5's change making the stage minutes optional so `COALESCE` can tell
"omitted" from "genuinely zero".

### A7 — `baseline_30d` is the mean of however many rows came back, over 36 days, and a ratio is drawn against it — CONFIRMED (anchor 2)

`apps/server/src/healthee/read/fitness.py:52-62`

```python
f"AND day >= ({AS_OF_DAY_SQL} - 35) AND day <= {AS_OF_DAY_SQL} ORDER BY day",
...
prior = [float(v) for _, v, _ in rows[:-1]]
baseline = round(sum(prior) / len(prior), 1) if prior else None
```

**The brief's reading is confirmed, and there are two defects, not one.**

1. The window is `as_of - 35 … as_of` — **36 days**, not 30. The key is named `baseline_30d`.
2. `prior` is every returned row minus the last. With two rows, `baseline_30d` is one day's
   value. No minimum, no `n` on the wire, no way for the client to know.

It is drawn, and as a ratio: `apps/mobile/lib/data/models/activity_today.dart:196` computes
`load / baseline30d`, rendered by
`apps/mobile/lib/features/activity/v02/training_panels.dart`. So today's load is expressed
as a multiple of a "30-day baseline" that may be a single day.

This is also a second definition of "baseline". The canonical one —
`analytics/baselines.py` — is median plus MAD, sentinel-filtered per metric, and carries
`n` (`Baseline.n`, line 34), which `analytics/coverage.py:95` exists specifically to report
as data coverage. `cardio_load_payload` uses none of it.

**Recommend:** compute it through `compute_baseline_cur(…, window_days=30, end_date=as_of)`
like every other baseline on the page, and ship `n` beside it. If an arithmetic mean is
deliberate for a load metric, say so at the site — and still ship `n`.

### A8 — two recovery signals publish a verdict from two days of history — CONFIRMED

`apps/server/src/healthee/read/recovery.py:228-231` (RHR) and `:317-320` (HRV)

```python
b = (reads.baselines.get("rhr_daily") if reads else None) or compute_baseline_cur(…)
if b.median is None or not b.robust_sd:
    return None
z = (value - b.median) / b.robust_sd
```

The only gate is a non-zero `robust_sd`. With **one** day MAD is 0 and the signal correctly
returns None; with **two**, MAD is the half-distance, the z is finite, and the payload
publishes `baseline`, `baseline_sd`, `z` and a `direction` of `"favorable"` or
`"unfavorable"` — a verdict on this owner's autonomic state from two mornings.

Three contrasts inside this codebase mark it as the outlier:

- `_sleep_signal`, same function, `read/recovery.py:272`: `if len(durs) < 5: return None`.
  One payload, three signals, two admission rules.
- `derive/recovery.py:38-60` requires `_BASELINE_MIN_POINTS` before returning a median. The
  derive layer computes RHR-versus-baseline with a minimum; the read layer computes the same
  comparison without one.
- `Baseline.n` is already on the object both functions hold and is simply not consulted.

Related, same function: `recovery_signals` (`read/recovery.py:200-215`) emits `"Recovery
signals lean favorable"` whenever `favorable > unfavorable`, which with one available signal
is a plural sentence from one signal, and is a directional verdict from an unweighted vote
across three markers of differing evidence grade. The module docstring claims "individual
favourable/unfavourable markers, **no composite**".

**Recommend:** gate both on `b.n` at the floor `_sleep_signal` already uses, and ship `n`
beside `baseline` and `baseline_sd`.

### A9 — a past workout is scored against today's resting heart rate — CONFIRMED (future leak)

`apps/server/src/healthee/read/workout.py:38`

```python
load = cardio_load_payload(cur, user_id, tz) or {}
hrmax, rhr = load.get("hrmax"), load.get("rhr")
```

No reference day is passed, so `cardio_load_payload` defaults to the owner's **today** and
`hrmax`/`rhr` come off today's row. Those two are the whole Karvonen reserve, so a June
session's `zones`, `avg_pct_hrmax`, `intensity`, `dominant_zone` and `trimp` are computed
from a resting heart rate measured months after it.

The session's own day is selected on line 35 (`start_ts`), so this is a missing argument, not
a missing capability. `docs/AS_OF_DAY.md` section 3 names it exactly: *"An answer for day D
must contain nothing measured, computed or observed after D."* `/api/activity/workout` sat
outside the as-of-day scope because it is addressed by timestamp rather than by day, which
is precisely why it was missed. `apps/mobile/lib/data/workouts/workout_detail.dart` parses
and draws all of it.

**Recommend:** `cardio_load_payload(cur, user_id, tz, start_ts.date())`, and where the
workout's own day has no `cardio_load` row, withhold the reserve-dependent metrics through
the `read/workout_absence.py` envelope rather than borrowing today's.

### A10 — session TRIMP is summed per HR *sample*; the daily one is summed per *minute* — CONFIRMED (unit), magnitude SUSPECTED

`derive/trimp.py:68-71` is explicit about its contract:

> Banister TRIMP summed over per-minute heart rates. … **Each element is taken to be one
> minute** — the sum's unit is minutes × weighting, exactly as the note defines it.

The daily path honours it. `derive/cardio_load.py:48-50`:

```sql
SELECT date_trunc('minute', ts) m, AVG(value) FROM sample … GROUP BY m
```

The session path does not. `read/workout.py:99-105` (`_hr_profile`) selects **raw `sample`
rows** with no minute aggregation and appends one element per row; that list goes straight
to `trimp_total` at `read/workout.py:167` and to `_zone_minutes` at `:115-127`, which
increments one bucket **per sample** and calls the result "minute buckets".

So whenever the strap samples faster than once a minute inside a recorded workout — which is
the reason a workout HR series exists at all — the session TRIMP and every zone minute are
multiplied by the sample rate. `read/workout.py:171` builds `off = int((t -
start_ts).total_seconds() // 60)` per sample with no dedupe, so duplicate `min` values in
`hr_series` would be the visible symptom.

`derive/trimp.py`'s docstring claims the module exists "so the same athlete-minute can never
score two different loads on two different screens". The formula is shared; the input is not.

The unit mismatch is CONFIRMED from the two queries. The **magnitude** is SUSPECTED: it
depends on the strap's in-workout HR cadence, which cannot be observed without a device or
the production database, both out of scope.

**Recommend:** give `_hr_profile` the same `date_trunc('minute', ts), AVG(value) … GROUP BY`
shape as `derive/cardio_load.py`, or make `trimp_total` take `(minute, hr)` pairs so the
contract lives in the type rather than a docstring.

### A11 — `/api/history` has no closing edge on the path that carries every dated panel — CONFIRMED

`apps/server/src/healthee/read/history.py:112-115`

```python
"SELECT metric, day, value FROM derived_daily WHERE user_id = %s AND metric = ANY(%s) "
f"AND day > ({USER_TODAY_SQL} - %s::int) ORDER BY metric, day",
```

Lower bound only. The other two series paths in the same file **do** close: `_flag_points`
filters `if day <= today` (line 133) and `_weight_points` binds `day <= user_today(tz)`
(line 144). Two of three were given the closing edge; the one that serves every
`derived_daily` metric — all 25, and therefore every dated history panel on every screen —
was not.

`docs/AS_OF_DAY.md` section 7 states the principle against this in its own words:
*"Inheriting another place's bound is exactly how 'latest' leaks; the point of section 3 is
that the bound goes where the data is served."* `docs/BACKEND_GAPS_FROM_UI.md` C1 then
records the opposite decision for this endpoint — *"Still no `end=` date, and none is needed
— a client asking for enough `days` and slicing at the chosen date is what both the metric
screen and the dated panels do"* — making the client the bound for the one endpoint the
dated panels read. Those two positions cannot both be the rule.

Whether a future-dated `derived_daily` row can exist is SUSPECTED: `SampleIn.ts`
(`ingest/models.py:45`) is an unvalidated epoch-ms integer, so the input path allows one, but
confirming it has happened needs the production database.

**Recommend:** add `AND day <= (USER_TODAY_SQL)` to `_daily_rows` regardless — it removes no
row in the normal case, matches its two siblings, and costs nothing. Separately, settle
whether `/api/history` takes an `end=`; the current answer places the honesty bound on the
client, which contradicts the document that governs it.

### A12 — regularity verdicts from three nights, beside a withheld SRI — CONFIRMED

`apps/server/src/healthee/read/sleep_extras.py:203-212, 275-297`. Drawn: the client calls
`/api/sleep/consistency` at `apps/mobile/lib/data/sleep_repository.dart:76-78`.

`sleep_consistency` refuses below three nights and then publishes, from three:

- `onset_sd_min`, `wake_sd_min` — population standard deviations of three points;
- `onset_band_h`, a p90-minus-p10 spread which on three points is `sorted[2] - sorted[0]`,
  i.e. the **full range**, reported as a 90th-to-10th-percentile band;
- `onset_band`, a verdict string: **`"tight — top-quintile territory (~1 h band)"`**.

"Top-quintile" is a claim about where this owner sits in a population distribution. No
reference distribution is read, no note is cited for it, and no `n` accompanies it. The
thresholds `1.5` and `2.5` hours are unnamed and uncited, as is `late: median_bed_min < 360`
(line 292, which also classifies a 06:30 bedtime as not-late).

The sharp part is what sits next to it. `_sri_block` (lines 217-256) correctly **withholds**
the Sleep Regularity Index because `[[sleep_regularity_index]]` Directive 4 forbids
reporting one from under seven days — and the same payload then publishes an ungraded,
uncited, home-made regularity verdict from three nights in its place. The endpoint refuses
the cited statistic and substitutes an invented one.

**Recommend:** raise the floor for the band verdict to the same seven nights the SRI
requires — it is the same question — delete the "top-quintile" claim or ground it in a note
with a reference distribution, and name the thresholds.

### A13 — three absences rendered as measured zeros, all drawn — CONFIRMED

Three separate sites, one class, grouped because the remedy is the same.

**(a) A missing intensity breakdown becomes zero moderate and zero vigorous minutes.**
`read/mvpa_week.py:60-61`:

```sql
COALESCE((flags->>'moderate')::float,0), COALESCE((flags->>'vigorous')::float,0)
```

That reaches `/api/activity.mvpa.week_moderate_min` / `week_vigorous_min`, every entry of
`daily`, and `fitness_plan_payload`'s `zone2_done_min` / `vilpa_done_min`. `mvpa_week` is
careful about exactly this distinction one function down (`read/mvpa_week.py:69-76`: *"an
owner whose strap has written no `mvpa_min` row in the window has not been measured as
still, they have not been measured"*) — the row-level absence is honoured, the flag-level
absence is not.

**(b) A workout with no device calories contributes zero after its minutes were removed.**
`derive/energy.py:126-131` excludes workout minutes from the MET walk because they are
"counted via the device's measured calories by the caller"; `:265-270` then does
`COALESCE(SUM(calories),0)` over a nullable column. A 60-minute run the strap logged without
a calorie figure removes an hour of at-least-sedentary METs and adds nothing back.
`total_calories` and `active_calories` are understated with `caveats` still `[]`. The
direction is conservative rather than flattering, which is the right side to be wrong on,
but it is a wrong number served without a caveat in a payload built with a caveat
vocabulary for this.

**(c) The client invents a weekly MVPA target when the server sends none.**
`apps/mobile/lib/data/models/activity_today.dart:76`: `weekTarget: (json['week_target'] as
num?)?.toInt() ?? 150`. The same file's docstring (lines 8-11) says "the app never
hard-codes it". `weekProgress` (`:114-115`) and the ring at
`apps/mobile/lib/features/today/v02/effort_panels.dart:170-172` then draw a confident
percentage of a number the server never sent, with no `Reading` wrapper and no withheld
path.

**Recommend:** (a) drop the `COALESCE`, let the flags be null; (b) either keep the workout
minutes in the MET walk when no device calories exist, or add a `caveats` entry naming the
uncounted session — `weight_caveats` (`derive/energy.py:186-200`) is deliberately a list "so
a second thing worth disclosing later does not change this shape"; (c) make `weekTarget`
nullable and withhold the ring.

---

## B. Wrong on the wire, not drawn

These are ranked below section A only because nothing renders them today.
`apps/mobile/lib/data/workouts/workout_repository.dart:8-15` is the **only** place
`/api/activity` is fetched, and it reads `data['workouts']` and discards the rest — so
`acwr`, `fitness_plan`, `steps`, `distance`, and both calorie blocks on that endpoint reach
no screen. The Activity tab sources those from `/api/today` instead.

That is a reprieve, not a defence: the payloads are wrong now, and a wiring change makes
them section-A defects the same day.

### B1 — `acwr` ships a verdict the corpus grades Contested and forbids, cites the wrong note, and the corpus asserts a suppression rule the code does not have — CONFIRMED

**RESOLVED — MOOT.** Closed in full by the severity-A pass before this section was
worked, and verified rather than assumed: `read/acwr.py` deletes `state` outright (the
argument for deleting rather than rewording is in that module, and rests on
Dalen-Lorentsen 2021 — the only RCT, and null), implements the 28-day suppression its own
note already claimed the product had, cites `training_load_acwr`, and ships `n_acute` and
`n_chronic`. Two mutations in `tests/read/mutations.sh` hold all of it.

`apps/server/src/healthee/read/fitness.py:213-238`

```python
"""... 0.8-1.3 = the progressive "sweet spot". Ported VERBATIM. [[training_stress_score]]."""
if len(vals) < 7:
    return None
acute = sum(vals[-7:]) / 7.0
chronic = sum(vals[-28:]) / min(len(vals), 28)
state = ("detraining" if ratio < 0.8 else "optimal" if ratio <= 1.3
         else "caution" if ratio <= 1.5 else "overreaching")
```

Four defects on one twenty-line function.

1. **The verdict is forbidden by its own note.**
   `packages/knowledge/sports-science/metrics/training-load-acwr.md` is `grade: Contested`
   and its summary reads *"a descriptive load-spike signal whose injury-prediction claim is
   discredited — avoid spikes, but don't gate on the numbers."* Line 24: *"a useful
   descriptive signal for spotting load spikes — **never a verdict**."* Line 30: the
   cut-points are *"soft heuristics, not guardrails."* Line 419 names the exact output:
   *"not the ratio's **discredited numeric verdict**."* The payload ships that verdict as a
   bare categorical string.
2. **It cites the wrong note.** The only citation is `[[training_stress_score]]` — a
   different, Probable-graded note about TRIMP — and `read/activity.py:44` embeds
   `acwr(cardio)` with no note key of its own, so `training_load_acwr` appears nowhere on
   this wire and the explainer sheet for the number would open blank.
3. **"Optimal" is reachable from seven rows.** With exactly seven, `vals[-7:]` and
   `vals[-28:]` are the same seven values, so `acute == chronic`, `ratio == 1.0`, and the
   payload publishes the Gabbett sweet spot from one week and no history to compare it
   against. Between 8 and 27 rows the arithmetic is honest and the key still says `28d`.
   `vals` are *rows*, not days — `derived_daily` holds a `cardio_load` row only for days it
   could compute one — so `acute_7d` can span three weeks of calendar time, and a gap in
   wear inflates it and the ratio with it.
4. **The corpus states a behaviour the code does not have.** The same note, lines 404-413,
   says of this product: *"Healthee … **suppresses ACWR entirely when chronic history < 28
   days or chronic load ≈ 0** (the small denominator manufactures alarming ratios for
   new/returning users)."* The code's only floor is seven rows. That is a false claim about
   the product inside the knowledge base — the same class as the `@daud/core` prose claims
   #87 removed, and `docs/ENGINEERING_STANDARDS.md` section 4 says why it is the worst kind:
   *"an auditor reads it and stops looking."*

The correct pattern exists in this repo: `derive/sleep_score.py:328-338` stores
`window_nights: 14` **and** `nights: len(tsts)` on every sleep-debt row — the window it meant
and the count it got.

**Recommend:** implement the suppression the note already claims (chronic history under 28
days, or chronic load near zero), drop `state` or demote it to a descriptive
"above/below your usual load" cue, cite `training_load_acwr`, and report `n_acute` and
`n_chronic`. Whichever way it resolves, the note and the code must be made to agree — the
note is currently the wrong one.

### B2 — `median_for_age` is fabricated when absent, under the name of a computed value — CONFIRMED

**RESOLVED — withheld with a reason.** `read/fitness_plan.py` (moved out of
`read/fitness.py`) takes `median_for_age` as it comes, null included. With no median there
is no gap and no projection: `median_for_age`, `gain` and `projected_12wk` go null behind a
`withheld` block naming the new `freshness.NO_AGE_MEDIAN` reason, and the weekly Rx, which
needs no median, still ships.

`apps/server/src/healthee/read/fitness.py:255,275`

```python
median_ref = float(vo.get("median_for_age") or 41)
...
"median_for_age": round(median_ref, 1),
```

`read/vo2max.py` correctly returns `median_for_age: None` when the owner's age is unknown
(A2's guard). `fitness_plan_payload` replaces that considered null with `41` and ships it
back out **under the same key name**, so the same response has `median_for_age: null` in one
block and `median_for_age: 41.0` in another. `41` cites nothing.

**Recommend:** return `None` from `fitness_plan_payload` when `median_for_age` is absent — a
VO2max-raising plan whose target is unknown is a plan we cannot write.

### B3 — the 12-week projection cannot say "no gain" — CONFIRMED

**RESOLVED — the bound and its provenance ship beside the number, and the code yielded to
the corpus.** The primary sources were read before anything was deleted, because deleting
the projection was the cheap move and would have been wrong: `[[vo2max]]`'s own
implementation section specifies this formula — "bounded **+2 to +5 mL/kg/min**:
`gain = clamp(0.4 × gap, 2, 5)`" — and sites it at the conservative end of Bacon 2013's
meta-analysis, projecting about half of that study's +6.4 ml/kg/min in young untrained
adults. The +2 floor is a claim about a training program's typical effect, which does not
depend on the trainee starting below their age median.

What the note DOES forbid is what the code was doing. D5, Established: *"Never promise a
specific VO₂max gain — trainability is ~47% heritable and ranges from near-zero to
>1 L/min for the same program"* [Bouchard 1999]; the number is licensed only "as an
estimate of typical response, never a promise", shown "if you follow the plan". So the
constants are named and cited, `gain_floor` / `gain_cap` / `gain_gap_fraction` ship beside
the number so it reads as a range, and D5's conditional travels as a caveat the honesty
envelope can see instead of living in a docstring.

`apps/server/src/healthee/read/fitness.py:256`

```python
gain = round(min(5.0, max(2.0, 0.4 * max(0.0, median_ref - cur_vo))), 1)
```

The inner `max(0.0, …)` correctly floors the deficit at zero for an owner at or above the
age median. The outer `max(2.0, …)` raises that zero back to **+2.0 ml/kg/min**. There is no
input for which this returns a gain of zero or a decline.

The docstring calls it "an estimate of typical response, bounded +2..+5 ml/kg/min, never a
promise", but the payload carries no caveat, no error band, no note explaining the bound and
no `data_confidence`. `0.4`, `2.0` and `5.0` are unnamed and uncited.

A number that can only ever be favourable is flattery by construction, which is the failure
this product is defined against.

**Recommend:** withhold the projection until a cited response model backs it, or ship the
bound and its provenance beside the number (`gain_floor`, `gain_cap`, `note_id`) so a reader
can see it is a range, not a forecast.

### B4 — two definitions of stride, and the intraday one is a population constant — CONFIRMED

**RESOLVED — both fields removed, on the wire and in the model.** There is no per-bucket
quantity behind either name, so nulling them would have kept two keys that could only ever
say nothing. `distance_m` was the second definition of stride and the only one that could
never refuse; `calories` was a hardcoded zero. Neither is read by any widget, so nothing
loses a number. The mobile guard is a DERIVED check rather than a listed one — the model's
source is scanned for the two keys, because a field nothing reads is invisible to a widget
test, which is exactly how both survived.

Canonical, `derive/activity.py:22,58`:

```python
_STRIDE_HEIGHT_FRACTION = 0.414  # stride length ~= 0.414 x height [[distance_from_steps]]
stride_m = _STRIDE_HEIGHT_FRACTION * prof["height_cm"] / 100.0 if prof else None
```

with `select_distance` returning `None` when there is no profile — the honest refusal.

Second definition, `read/today_series.py:261,266`:

```python
"""One local day's 15-minute step buckets (distance ≈ steps × 0.78 m stride)."""
"  SUM(value)::int AS steps, (SUM(value) * 0.78)::int AS dis_m, "
```

`0.78` is inline in SQL, is not a named constant, cites no note, and needs no profile — so
this path never withholds. It implies a 188 cm owner; at 175 cm the personal stride is
0.7245 m, so the bars would be about **7.7% long** and would not sum to the
`distance_m_daily` card above them.

The same function ships `"calories": 0` on every bucket (`read/today_series.py:281`) — a
hardcoded zero for a quantity nobody computed, bypassing the MET model entirely. That is the
empty-collection failure `read/today.py:100-118` argues at length for `anomalies` (*"an empty
list is indistinguishable from 'nothing was anomalous'"*), repeated as a scalar.

Both are parsed by `apps/mobile/lib/data/models/today_series.dart:94-95` and read by no
widget, which is why this sits in B.

**Recommend:** remove `distance_m` and `calories` from the bucket payload. If the chart ever
wants them, pass the derived `stride_m` as a bound parameter and return null without a
profile, matching `derive/activity.py`; per-bucket energy would have to come from the MET
model, which is a real piece of work to scope on its own.

---

## C. Thin — the payload knows more, or claims more, than it says

### C1 — the blank night ships four zeroed stages — CONFIRMED (anchor 3)

**RESOLVED — MOOT.** Taken by the severity-A sleep work and verified: `_stub_night` sends
`"stages": None`, with the reasoning in place beside it.

`read/sleep_page.py:152-179` (`_stub_night`), used at `:97`. **The brief's reading is
confirmed exactly.** Every field is `None` — including `duration_min`, which is honest —
except:

```python
"stages": {"light": 0, "deep": 0, "rem": 0, "awake": 0},
"stage_timeline": [],
```

A stub is emitted for any date with a `derived_daily` row and no `sleep_session` row.
`stage_totals` (`read/sleep_common.py:64-66`) has the same shape, so those zeros are the
*correct* answer for a session that genuinely recorded no stages — which is why this cannot
be fixed mechanically, and why A5's ingest-level defaults make it unfixable in `read/` at
all. It is drawn through the same painter as A5 step 5.

**Recommend:** `"stages": None` in the stub. Absence of a session is not a measurement of
zero minutes in four stages, and null is already the convention for every other field of the
same object.

### C2 — a night's `duration_min` and a nap's `duration_min` are different quantities — CONFIRMED

**RESOLVED — one name, one quantity.** Both objects now carry `tst_min` and `tib_min`,
the vocabulary this payload already spoke. On a night this is a DE-DUPLICATION rather than
a rename: `duration_min` held total sleep time while the derived pivot already wrote the
identical quantity to `tst_min` from the same stage columns, so the key was dropped and
`tst_min` is set from the session too (through the same `stage_sleep_min`, so the two
writers cannot disagree). A nap gains `tst_min` from the stage minutes its row already
carried.

Night (`read/sleep_page.py:140-142`, `read/sleep_extras.py:53,105`): light + deep + REM —
total sleep time, wake excluded. Nap (`read/sleep_page.py:257,270`): `EXTRACT(EPOCH FROM
(end_ts - start_ts))/60` — wall-clock time in bed, wake included. Both keyed `duration_min`
in one `/api/sleep` payload. `_naps`' docstring says a nap is "shaped exactly like a night"
and lists the two stage helpers it shares; duration is the one field it does not share, and
nothing on the wire says so.

**Recommend:** `tst_min` for the night, `tib_min` for the nap — both names already exist in
this payload's vocabulary.

### C3 — the client computes a second, age-blind sleep need — CONFIRMED

**RESOLVED — the server sends what the client was inventing.** `/api/sleep` carries
`sleep_debt`, the same block the Today page carries, from the same rows through
`sleep_debt_payload` itself — a second shaping would have had to re-decide the debt's
freshness window, its withhold and `need_min`'s survival of one, and would have got one of
them different. `kSleepNeedMin` is deleted rather than corrected. Where the server has no
need, the panel withholds with the reason and draws no chart, no percentage and no gap:
all four are ratios against a target we do not have. This also closes
`docs/BACKEND_GAPS_FROM_UI.md` B5, which had accepted it as a labelling problem.

`apps/mobile/lib/features/sleep/sleep_format.dart:25`: `const double kSleepNeedMin = 480;`,
used through `apps/mobile/lib/features/sleep/v02/need_panel.dart:94-115,137,165,173` to
compute the Sleep tab's shortfall, performance percentage and nightly gap.

The server's need is age-selected: `derive/sleep_score.py:44-45` — `SLEEP_NEED_MIN_18_64 =
480`, `SLEEP_NEED_MIN_65P = 450`. The client is flat 480 for every owner, so for an owner
over 65 the Sleep tab overstates the shortfall against a need the Today tab reports
correctly from `sleep_debt.need_min` (`apps/mobile/lib/data/models/sleep_debt.dart`). The
panel's docstring (`need_panel.dart:17-30`) argues the API-shape constraint honestly and
never mentions the age dependency it drops.

This is `docs/BACKEND_GAPS_FROM_UI.md` B5 in practice — *"`/api/sleep` sends no need and no
debt"* — accepted there as a labelling problem, and it is a second definition of a metric.

**Recommend:** put `sleep_need_min` and `sleep_debt_min` on `/api/sleep` from the same rows
Today reads, and delete `kSleepNeedMin`. That closes B5, C3 and C4 together.

### C4 — the server's own recovery composite falls back to the same flat 480 — CONFIRMED

**RESOLVED — withheld, not defaulted.** `_DEFAULT_NEED_MIN` is gone. With no
`sleep_need_min` row the sleep factor is ABSENT rather than scored against an invented
target and then published as this owner's own; `derive_recovery` already weights only the
factors it has, so absence costs nothing except the fabrication.

`derive/recovery.py:36,107`: `_DEFAULT_NEED_MIN = 480.0`, used as `need = float(nr[0]) if nr
and nr[0] else _DEFAULT_NEED_MIN`. For an owner over 65 with no `sleep_need_min` row, the
recovery score's sleep factor is scored against a need 30 minutes higher than the canonical
one, and `flags.factors.sleep.need_min` publishes 480 as this owner's need. Not reachable
for the current owner (age 32); it is a fabricated personal target in code, and the same
metric having three definitions (here, `derive/sleep_score.py`, and C3's client constant) is
the failure CLAUDE.md names first.

### C5 — the step count does not name its instrument on the wire — CONFIRMED

**RESOLVED — served, with the instrument named.** `read/common.provenance` forwards an
explicit allow-list of what the derive layer recorded — `source`, `reported_at`,
`steps_per_minute_sum`, `sample_minutes`, and the distance and calorie fields — on both the
Today card and the Activity tab, which render the same rows and must not differ about
them. `reported_at` also grew teeth: a counter read while its own day was still running now
carries a caveat saying so, through the disclosure channel the read layer already forwards,
instead of being a comment in `device_totals.py` that nothing emitted.

`derive/device_totals.py:113-127` records which of two instruments produced a day's steps
(`flags.source`, plus `flags.steps_per_minute_sum` and `flags.reported_at` so a reader can
see the divergence and know the counter may describe a partial day).
`read/today_series.py:120-146` (`_derived_card`) ships `metric`, `label`, `value`, `unit`,
`median_30d`, `sd_30d`, `z`, `anomalous`, `as_of_date`, `withheld` and `caveats` — and
**not** `source` or `reported_at`. `read/fitness.py:290-320` drops them too.

`flags.reported_at` matters specifically: the module's own comment says *"a counter read at
09:00 is a statement about a partial day."* So today's step card can be a partial day's
count with nothing on the wire saying so. VO2max names its instrument on the wire; steps went
through the same reasoning at derive time and the read layer discards the answer.

### C6 — the calorie split is recorded at derive time and dropped before the wire — CONFIRMED

**RESOLVED — the mix and the citation both ship.** `provenance` carries `bmr`,
`workout_cal` and `pal`, and `read/meta.METRIC_NOTE_ID` gives the three calorie rows the
note id they had never had, so `energy_expenditure_derivation`'s own ±15-20% estimate label
has somewhere to render. Keys a row does not carry are ABSENT rather than null: a null
`workout_cal` on a step card would read as "no workout calories" rather than "not a
question about steps".

`derive/energy.py:266-282` stores `flags["workout_cal"]` beside the total, so the row knows
how much of the day came from the MET-by-state model and how much from the device's own
figure for workout windows. `read/fitness.py:283-325` (`activity_metric`) reads only
`flags.get("caveats")` and forwards neither. The owner sees one number with no indication of
the mix. The mixing itself is correct and licensed —
`packages/knowledge/notes/activity/energy_expenditure_derivation.md:157-158` Directive 2 says
to use the device's measured workout calories for workout windows — so this is a disclosure
gap, not a model violation.

Also: the calorie payload carries **no note id at all**, unlike its VO2max, MVPA and strain
siblings, so the note's own Directive 3 estimate label (±15-20% individual error) has nowhere
to render.

### C7 — an unworn day is stored and baselined as zero steps — CONFIRMED

**RESOLVED — decided at the source, and the limit of the evidence stated.**

**Can coverage distinguish them? No, and it inherits the defect rather than solving it.**
`analytics/coverage.py` counts days with a stored daily value via `Baseline.n`, which
applies `METRIC_FILTERS`; `steps_total`'s filter is `value >= 0`, which admits the zero. So
an unworn day counted as covered, and coverage would have called a 14/14 window excellent.

**What does distinguish them, and what does not.** The strap's own parser emits a
`steps_per_minute` sample only for a minute that recorded a step
(`apps/mobile/lib/ble/parsers/activity_parser.dart`: `if (steps > 0 && steps != 0xFF)`), so
counting the day's samples answers "how many minutes did the instrument speak for", and
zero of them means it did not speak. That count is now taken and stored as
`flags.sample_minutes`, and with no counter and no samples `derive_daily_activity` writes
NO ROW. It does **not** distinguish an unworn day from a worn day on which the owner took
no step in any minute of it — nothing in this server models wear, and building a wear
signal out of the heart-rate stream would be a second definition of "worn" beside no first
one. The claim made is the narrow one the data supports.

The device tier is untouched: a strap reporting a counter of 0 has measured zero steps, and
that row is written and kept. `distance_m_daily`'s stride tier inherits the silence, since
it is the step count multiplied.

**Priced (#118).** A narrowing derivation leaves any false zero already in `derived_daily`
serving forever, because every write is an upsert and nothing deletes. **No migration
reaches it** — the rows are per owner and per day, and no schema change identifies them —
but the tool for exactly this already exists and needed no change:
`db/stale_derived.py --purge-stale steps_total`, run inside a re-derive's own transaction,
removes the rows this pass declined to rewrite, and `steps_total` is not in
`GATED_METRICS` so the purge admits it. **Nothing was run against production.**

`derive/activity.py:53-55` upserts `steps_total` unconditionally (*"0 is valid, so
re-derivation overwrites stale rows"*), and `device_totals.select_steps` returns
`DailyValue(0.0, {"source": "steps_per_minute"})` with no counter and no samples.
`analytics/metrics.py:86` then admits that row to every baseline: `"steps_total": "value >=
0"`. Compare `"rhr_daily": "value > 30 AND value < 120"` on line 81 — the sentinel filter
exists precisely because "rhr=0 means 'not measured', not a real zero" — and
`"total_calories": "value >= 500"` on line 88, which does exclude the degenerate case.
`flags.source` distinguishes the two cases; the sentinel filter cannot see flags. The error
drags the step baseline down, which flatters a low-step day.

**Recommend:** decide it explicitly and record the decision — a `value > 0` sentinel, a
flags-aware filter, or a documented ruling that a zero-step day is a real reading. Any of the
three beats the current position, which is that nobody has decided.

### C8 — sleep need and debt are blocked by a weight they do not use — CONFIRMED

**RESOLVED — the gate reads what the computation reads.** A new
`derive/_common._date_of_birth` loads the one field NSF 2015 selects on, and sleep need and
debt use it instead of `_load_profile`. The withhold reason narrows from
`profile_or_weight_missing` to a new `DOB_MISSING`, because naming a weight would tell the
owner to do something that would not bring the number back; `tz` leaves both signatures
with the loader that wanted it.

`derive/sleep_score.py:311-315` gates on `_load_profile`, and `derive/_common.py:186-188`
returns `None` when `_weight_as_of` finds no logged weight. Sleep need is a function of `dob`
alone. The message is honest (`SLEEP_DEBT_MESSAGES[PROFILE_INCOMPLETE]` names the weight), so
it cannot mislead — but the profile loader's own comment makes exactly this argument for the
neighbouring field (*"`srpa` … NOT part of the 'profile is complete' gate above … sleep need
only wants `dob` and must not be blocked by it (#108)"*) and the same reasoning was not
applied to weight.

---

## D. Hygiene

### D-a — magic numbers in science-adjacent code, uncited — CONFIRMED

**RESOLVED.** `read/today_series.py`'s `0.78` and `read/fitness.py`'s `41` died with B4
and B2; `read/vo2max.py`'s `5.6` died with A1; `read/sleep_extras.py`'s three were already
named. The rest are now named constants with their provenance beside them: the projection's
`0.4 / 2.0 / 5.0` and the plan's `90 / 15` (in `read/fitness_plan.py`, quoted from
`[[vo2max]]`), the yoga half-credit, the sleep signal's `360 / 300` floors and its
`-0.5 / -1.0` personal limbs, and the autonomic signals' `0.3 / 0.5`. Where a number has no
paper behind it the comment says so rather than dressing it as a citation.

The standards require every magic number to be a named constant and every research-derived
constant to cite its note. These do not: `read/today_series.py:266` (`0.78`);
`read/fitness.py:255-256` (`41`, `0.4`, `2.0`, `5.0`); `read/fitness.py:270,275`
(`zone2_target_min: 90`, `vilpa_target_min: 15`); `read/fitness.py:177` (yoga at `dur * 0.5`
— described in a comment on `_YOGA_MIN_DURATION`, the coefficient itself inline);
`read/recovery.py:295-299` (`360` / `300` minute sleep thresholds) and `:232,330` (the
`-0.3 / 0.5 / 0.3 / -0.5` direction thresholds); `read/sleep_extras.py:286-292` (`1.5`,
`2.5`, `360`); `read/vo2max.py:186` (`5.6`).

### D-b — a comment points an auditor at a guard that does not exist under that name — CONFIRMED, and a prior reading CORRECTED

**RESOLVED.** The comment names the real test and the file it lives in.

`read/activity.py:56-57` says: *"`tests/test_source_citations.py` states the rule for
`[[id]]` citations in source; **`test_wire_note_ids`** there now holds the wire to it too."*
No `test_wire_note_ids` exists anywhere in the repo — the string appears exactly once, inside
that comment.

**The guard is real, under another name.** It is
`apps/server/tests/read/test_wire_honesty.py:307::test_every_note_id_on_the_wire_resolves_to_a_manifest_id`,
exactly as `docs/BACKEND_GAPS_FROM_UI.md` A4 documents, and it walks `today_snapshot`,
`activity_snapshot` and `sleep_page` with two vacuity assertions. So this is a stale comment,
not a false safety claim — but the cost is real and was paid during this audit: a reader who
checks concludes the net is fictional. I record the correction because the difference between
those two findings is exactly what this audit is for.

### D-c — the sleep signal's population floor overrides the personal baseline beside it — CONFIRMED

**RESOLVED — the limit is named on the face.** The thresholds are cited and unchanged
(moving a scoring cutoff is a science behaviour change owed its own PR with known-value
tests), and the signal now ships `direction_basis` — `population`, `personal` or `both` —
plus `population_floor_min`, so a reader can see that for a chronic short sleeper the
absolute floor decided it and the personal number beside it could not have.

`read/recovery.py:295-299` returns `"unfavorable"` when `today_dur < 300` **or** `z < -1`.
For a chronic short sleeper the absolute floor is met every night, so the personal z the
signal computes, ships and labels can never change the verdict. The signal presents itself as
a comparison against "personal usual" (its docstring) and is a population threshold with a
personal-looking number attached. `sleep_duration_mortality` supports the population claim;
the framing is what is wrong.

### D-d — `pace_min_per_km` uses elapsed time, not moving time — CONFIRMED

**RESOLVED — the limit is named on the face, and the alternative was priced and refused.**
`moving_s` exists only where a GPS track does, and it is reconstructed from every point of
the track at read time rather than stored, so reaching for it from the workout payload
would mean loading a whole track inside a p95 < 100 ms read on the chance one exists. The
pace stays elapsed-based and ships `pace_basis: "elapsed"`; the GPS detail endpoint already
publishes the moving-time pace for the sessions that have one.

`read/workout.py:148-150` divides the device's `duration_s` by distance. The GPS path
computes and reports `moving_s` separately (`derive/gps_detail.py:135`), so the concept
exists in the repo and the workout payload does not use it. A paused session reports a slower
pace than it was run at.

### D-e — carried and never drawn — CONFIRMED

**NOT DONE, and deliberately.** This is the one item dropped as costing more than it
returns, and the reason is that it is not one finding but three unrelated ones:

* `vo2max.submax.{n_sessions, method_caveat, trend}` — unparsed by the client, but the
  block they belong to is the tiered-estimator disclosure #117 exists to publish. Deleting
  them would remove the evidence for a number the app already draws; the fix is client
  work, on a screen not in this pass.
* `StepBucket.distanceM` / `.calories` — **done**, with B4.
* `/api/activity`'s `steps`, `distance`, `active_calories`, `total_calories`, `as_of` and
  `research_notes` — fetched and discarded because
  `workout_repository.dart` reads only `data['workouts']`. Removing them from the payload
  would be a large contract change to blocks that are correct and that a wiring change
  makes live; removing the FETCH instead is the same client work as the first item.

`docs/BACKEND_GAPS_FROM_UI.md` E already records this debt on the client side, and it
belongs there rather than being half-paid from the server end.

Beyond B1-B4: `vo2max.submax.{n_sessions, method_caveat, trend}` are on the wire and unparsed
(`apps/mobile/lib/data/models/vo2max.dart:66-101`); `StepBucket.distanceM` and `.calories` are
parsed and read by no widget; `/api/activity`'s `steps`, `distance`, `active_calories`,
`total_calories`, `as_of` and `research_notes` are fetched and discarded
(`apps/mobile/lib/data/workouts/workout_repository.dart:8-15`).
`docs/BACKEND_GAPS_FROM_UI.md` E already records 47 unreachable client files; this is the same
debt on the server side of the boundary.

---

## E. Swept and clean — what was checked, and the evidence

### E1 — `read/vo2max.py:160` `age = int(flags.get("age_years") or 0)` — CLEAR, confirmed

The brief names this as a site that looks like fabrication and is not. Line 162 is
`median_ref = vo2max_median_for(age, sex) if age else None`, so the zero never reaches a
computation. `age_years: 0` does still ship (line 190) as a bare integer — a cosmetic version
of A2, worth a null for symmetry — but it is not spent. **Its neighbour on line 161 is not
clear; see A2.**

### E2 — `workout.py:44`, `fitness.py:355`, `routine.py:82` — CLEAR, confirmed

All three are `round((dur_s or 0) / 60) if dur_s else None`. The `or 0` is unreachable
because the `if dur_s` guard has already excluded every falsy value. Dead but harmless.

### E3 — `routine.py:69,104` journal counts — CLEAR, confirmed

`int(c or 0)` / `float(t or 0)` over `COUNT(*)` and `COALESCE(SUM(amount),0)` on
`manual_entry`. Zero entries genuinely is zero entries: that is a measurement of the log, not
of the body.

### E4 — interpolation across a gap — CLEAR

The only interpolator in the server is `derive/gps.py:77-100` (`make_hr_interpolator`) and it
is exemplary: `None` outside a 2-minute edge tolerance and across any gap longer than
`_HR_INTERP_GAP_S`, with the reason stated — *"so a missing HR stays distinct from an
interpolated one."* No other module fills, forward-carries or `generate_series`-pads a gap;
`read/history.py:87-90` states the rule (*"a gap is a gap"*) and `read/sleep_page.py:86` states
it again for nights.

One residual, not raised: `derive/gps_detail.py:141-142` computes a track's `avg_hr` and
`max_hr` from the interpolated per-point series rather than the raw samples. `max` is safe
(linear interpolation cannot exceed its endpoints); `avg` is a resampled mean. Small, and the
per-point `hr` is documented as interpolated.

### E5 — calories are MET-by-state, with no Keytel or HR-EE survivor — CLEAR, confirmed

`derive/energy.py:1-6` states the model and cites `[[energy_expenditure_derivation]]`. The
only occurrences of Keytel or an HR-to-energy regression anywhere in `apps/server/src/` or
`apps/mobile/lib/` are inside the note **documenting its rejection**
(`packages/knowledge/notes/activity/energy_expenditure_derivation.md:24,53-55,120,156,192`:
*"deliberately NOT raw Keytel or HR→EE, which overcount free-living days 2-3×"*).
`apps/mobile/lib/analytics/` computes no energy at all — calories are server-only, one source.

A double count looked likely and is not there: `_tee_met` excludes workout minutes from the
MET walk (`derive/energy.py:130`) precisely because the device's workout calories are added
separately at `:270`. Disclosure of the mix is C6; the model is correct.

### E6 — safety-critical directives compile to real guardrails, bijectively — CLEAR, confirmed

Four notes declare `safety_critical` in the manifest, carrying five markers — `napping [5]`,
`hydration_everyday [5, 6]`, `late_eating_sleep [5]`, `environmental_stress [12]` — and
`insights/guard_directives.py:176-224` compiles exactly five matching rules. The bijection is
held by a real test, `apps/server/tests/insights/test_guard_directives.py:20-49`, whose three
cases include a non-vacuity check.

The prose ban is also held: sweeping the corpus for "hard guardrail", "may not override" and
"@daud" turns up no live instance of the banned claim. Every `@daud/core` hit is a
self-correcting retrospective, and the two notes that do assert a compiled guardrail
(`behavior_change_and_personalization.md:120-127`, `recommendations_engine_plan.md:258-274`)
cite `output_guard._DOCUMENTED_RULES` — the second, standards-sanctioned table — and name the
functions.

### E7 — one definition per metric, where it matters — CLEAR, confirmed, with the exceptions named above

`sleep_debt_min` has one derivation (`derive/sleep_score.py:304`) and every other module reads
the stored row. MVPA has one per-day derivation and one weekly rollup, and
`read/mvpa_week.py:1-17` documents killing the duplicate that preceded it. VO2max is one
tiered metric, never averaged (`derive/vo2max_tier.py`). Resting HR has one derivation
(`derive/rhr.py`); `derive/cardio_load.py::_measured_rhr` and `derive/vo2max.py::rhr_week` only
read it. TST and TIB are two genuinely different quantities, distinctly named at
`derive/sleep_score.py:193-194`.

`read/recovery.py:41-52` argues its own baseline exception at length — a floor in minutes
rather than ms/bpm, two disjoint legacy floors deliberately kept distinct rather than unified
without a note. A documented, argued exception, not a silent duplicate.

The violations of this rule found by this audit are A7 (baseline), B4 (stride), C2 (sleep
duration key), C3 and C4 (sleep need), and A10 (the TRIMP input basis).

### E8 — `derived_at` provenance — CLEAR, confirmed

`derive/_common.py:41-64` is the sole writer of `derived_daily` and stamps `derived_at` on both
the INSERT and the `ON CONFLICT DO UPDATE` branch, unconditionally, even when the value is
unchanged. The column is `NOT NULL DEFAULT now()` (`db/schema.sql:87`), so a hand-written
insert bypassing the helper still could not land a null. `read/common.py:158-176` serves it as
the max across the day's rows and documents why the max rather than the min. The #118 lesson
is intact.

### E9 — nothing prunes raw data on the server; the #121 class has no second instance — CLEAR, confirmed

A sweep for `DELETE`, `TRUNCATE`, `DROP`, retention policies and `drop_chunks` found that
`sample`, `sleep_session`, `workout`, `device_daily_total`, `weight_log`, `gps_track`,
`gps_point` and `profile` never appear as a deletion target anywhere in
`apps/server/src/healthee/`. No TimescaleDB retention policy exists; the only `INTERVAL '7
days'` on the hypertable is its chunk size (`db/schema.sql:28-29`), and
`db/provision_app_role.py:106-114` revokes `TRUNCATE` from the app role. Every `DELETE`
targets a regenerable cache (`finding`, `recommendation`, `illness_flag`, suggested
`challenge`/`program` rows, `kv`) or, at `db/claim_sentinel.py:208`, an `app_user` row that
`plan()` at `:141-146` has already proven owns nothing.

Every ingested measurement lands in a raw table before any derivation (`ingest/upsert.py:71-90`,
`:118-151`, `:154-177`, `:180-214`, `:222-264`, `:267-311`), and no `apply_*`-shaped writer
survives. `db/rederive.py` rewrites only `derived_daily` and `gps_track`'s denormalized summary
columns. `gps_track.vo2max_submax` / `r2` look like the #121 shape and are not: a recomputable
scoring-gate cache over untouched `gps_point` rows (`derive/gps_scoring.py:35-53`).

Two residuals, recorded not raised. `derived_daily` holds one `vo2max_submax` row per owner-day,
so a second GPS-scored session in a day overwrites the first in the daily aggregate — the raw
track survives and can be re-scored (`derive/gps_scoring.py:50-53`). And
`derive/_common.py:203-221` (`_weight_as_of`) falls back to the **earliest** logged weight for
days before the owner's first weigh-in, so a March day's BMR can rest on a June measurement;
`weight_caveats` discloses it past 14 days, so it is caveated rather than bounded — the one
place a value observed after day D reaches day D's answer by design.

The mobile 60-day horizon is local-only: `apps/mobile/lib/data/store/horizon_prune.dart`
operates solely on Drift tables, imports no HTTP client, refuses to drop any measurement whose
`pushed_at_ms` is null, and logs the loss when the one-year unsent bound fires.

### E10 — the purge tool cannot reach raw data or a gated metric — CLEAR, confirmed

`db/stale_derived.py:144-152` deletes from `derived_daily` alone, bounded by owner, an explicit
day span, an explicit caller-named metric list, and `derived_at < transaction_timestamp()`.
`db/rederive.py:180-199` refuses `--apply` with no `--purge-stale`. `db/rederive.py:200-206`
refuses any purge naming a metric in `GATED_METRICS` (`vo2max_submax` → `--rescore-tracks`)
unless the gate was re-opened first, so "delete every GPS-measured estimate" is structurally
prevented rather than merely documented.

### E11 — the as-of-day bound in the shared read primitives — CLEAR, confirmed

`read/common.py`'s five primitives all take `on_or_before` as a **required** argument and the
module docstring gives the reason. `read/today.py`, `read/activity.py` and `read/sleep_page.py`
resolve the reference day once and thread it. `read/findings.py:125-137` re-bounds a finding's
stored pairs by the reference day rather than inheriting the finding's own gate, and reports
`points_n` beside `n_samples` so a scatter cannot silently plot fewer points than the statistic
above it. `read/today.py:178` and `read/routine.py:48` correctly return `None` for the two
blocks that describe *now* rather than a day.

The exceptions found are A9 and A11. `insights/context.py:91` (`latest_value`, unbounded) is
**not** one: `docs/AS_OF_DAY.md` section 6 puts the LLM surfaces out of scope deliberately, and
`analytics/coverage.py:94` anchors on the owner's today for the same documented reason.

Also clean, and worth naming because it is the model the rest should follow:
`derive/sleep_score.py:328-338` stores `window_nights: 14` **and** `nights: len(tsts)` on every
sleep-debt row; `derive/freshness.py` is the single answer to "is this current", with both
horizons argued against measured instrument error rather than chosen; `derive/recovery.py`
publishes its composite's `weights`, `method` and `note_id` and refuses to score without at
least one autonomic marker (`:132`); and every composite the server computes has a research
note documenting its methodology — `recovery_readiness`, `no_validated_sleep_score` plus
`sleep_score_implementation_plan`, `training-stress-score.md:485-494` for the 0-21 strain
including its 0.75 exponent, and `biological_age_estimate` (whose module docstring names itself
"a DOCUMENTED exception to the no-composite rule" and argues the rejection of an uncited SRI
term at `analytics/biological_age.py:38-60`). B1's `state` field is the only exception, and it
is an uncited field on a documented metric rather than an undocumented composite.

---

## F. The three anchors

| Anchor | Verdict |
|---|---|
| Summed-NULL sleep durations (`read/sleep_extras.py:53,105`, `read/sleep_page.py:140`) | **Confirmed in effect; mechanism corrected, and it is worse.** The columns are `NOT NULL DEFAULT 0` (`db/schema.sql:41-44`), so nothing sums a NULL and the `or 0` guards are dead. The zeros are manufactured at ingest by the pydantic defaults (`ingest/models.py:62-65`), can overwrite good data via the clobbering upsert (`ingest/upsert.py:130-134`), survive a correct server-side withhold via the client's `?? night.stages.total` fallback (`sleep_history_screen.dart:162`), and are painted as a real zero-sleep night (`h_stacked_sleep.dart:82-116`). Not fixable in `read/`. See A5, A6, C1. |
| `baseline_30d` computed over however many rows returned (`read/fitness.py:62`) | **Confirmed, and there are two defects.** No minimum and no `n` on the wire — and the window is 36 days, not 30. The client draws `load / baseline_30d` as a ratio (`activity_today.dart:196`). See A7. |
| The blank night, all null except four zeroed stages (`read/sleep_page.py:161`) | **Confirmed exactly as read**, and it reaches the screen through the same painter as the anchor above. See C1. |

---

## G. The most serious thing not in the brief

**`read/vo2max.py:186` ships `see_ml_kg_min` defaulted to 5.6** — the precise constant #108
deleted from `derive/vo2max.py` for appearing nowhere in the literature, restored in the read
layer, drawn on the fitness panel as the model's error band, and unaccompanied by a
`see_source` when it fires. The repo documents the removal in the very file that computes the
correct 5.075.

Two others of the same weight: **`out_of_range_inputs` never reaches the honesty envelope**
(A3), so a VO2max computed outside its model's validated range renders as `Present` — the
server did the honest work and the client filed it under a key the envelope does not read; and
**`training-load-acwr.md` asserts a suppression rule the code does not implement** (B1), a
false claim about the product inside the knowledge base, which the standards call the worst
kind because an auditor reads it and stops looking.

---

## H. Could not determine

1. **The magnitude of A10.** Whether the session TRIMP and zone minutes are inflated, and by
   how much, depends on the strap's in-workout HR sample cadence. That needs a real device or
   the production database, both out of scope. The unit mismatch itself is confirmed from the
   two queries.
2. **Whether a future-dated `derived_daily` row can exist in practice (A11).** `SampleIn.ts` is
   an unvalidated epoch-ms integer so the input path allows one; confirming it has happened
   needs the production database. The missing closing edge is confirmed regardless and should
   be closed on its own merits.

---

## I. Out of scope for this audit

- The LLM surfaces (`insights/`) beyond confirming that `docs/AS_OF_DAY.md`'s out-of-scope
  decision is honoured and that the safety-critical bijection holds. The choke point, gate
  registries, refusals and output guardrails were not audited.
- `challenges/` and `programs/`.
- Authentication, tenancy and RLS beyond noting that `provision_app_role` revokes `TRUNCATE`.
- Performance against the standards' budgets. The read layer's batching comments are detailed
  and credible; no measurement was taken.
- `today.json`'s `illness_flag`, `routine`, `recommendation`, `recovery_signals` and `finding`
  models were structurally spot-checked against their Dart counterparts, not diffed key by key.
  No discrepancy was found in what was sampled; they are not certified clean to the depth of
  section E.
