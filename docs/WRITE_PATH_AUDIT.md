# Write-path audit — `ingest/` and `derive/`, where every value is born

Read-only audit of `apps/server/src/healthee/ingest/` (5 modules) and
`apps/server/src/healthee/derive/` (27), against `CLAUDE.md`,
`docs/ENGINEERING_STANDARDS.md`, `docs/HOW_WE_VERIFY.md`, `docs/AS_OF_DAY.md`,
`db/schema.sql`, `packages/knowledge/`, and `~/projects/healthee-legacy` as the port
reference. `apps/mobile/lib/data/push/` and `apps/mobile/lib/data/store/` were read as
the producer of the wire; `db/rederive.py`, `db/stale_derived.py` and `jobs/chain.py`
were read where they decide what this layer leaves behind.

This is item 2 of `docs/AUDIT_COVERAGE.md`. `docs/BACKEND_AUDIT.md` audited `read/` and
said explicitly that it did not audit these layers. It found a defect it could not fix
because the value was already wrong when it arrived: sleep-stage zeros manufactured by a
pydantic default and pushed through a COALESCE-less upsert. **A value that is wrong on
arrival is wrong everywhere downstream, forever, and re-derives do not heal it.** That
is the standard applied here.

Every finding carries `file:line` and is marked **CONFIRMED** (code path read end to
end) or **SUSPECTED** (looks wrong, could not be settled read-only). Findings are ranked
by **whether the damage is recoverable**: an unrecoverable loss of a raw measurement
outranks a wrong number a re-derive would fix. Cleared classes are reported too — a
swept class is a result, and it is the only thing that makes the verdict verifiable
rather than hopeful.

Nothing was changed by this audit. This document recommends; it does not fix. No device,
no production server, no production database, no token was touched.

---

## 0. Counts

| Severity | Meaning | Count |
|---|---|---|
| **A — unrecoverable** | a raw measurement with no durable home; nothing can restore it | 1 |
| **B — wrong now, recoverable** | a wrong or absent value a code fix plus a re-derive would repair | 7 |
| **C — right number, wrong disclosure** | the value stands; the provenance beside it does not | 4 |
| **D — hygiene** | standards violations with no direct honesty consequence | 4 |
| **Swept clean** | classes checked with evidence, no finding raised | 14 classes |

CONFIRMED 13 · SUSPECTED 3 · Could not determine: 3 (section 6).

**The headline answers, up front:**

* **Can a raw measurement still be destroyed by a derive pass?** No. `_upsert_daily` is
  the only writer of `derived_daily` in the tree, and no derive module writes any raw
  table. `#121` is genuinely closed. **But one raw measurement is still destroyed — at
  the wire, before it ever reaches a table.** See A1.
* **Which upserts clobber?** Three: `upsert_profile` (`height_cm`, `sex`, `dob`),
  `upsert_workouts` (`sport`, `duration_s`), and `device_daily_total`'s newest-arrival
  precedence. B2, B4, B6.
* **Where does absence become a value at write time?** `orchestrator.py:84`
  (`int(v or 0)` over a partial stage breakdown) and `cardio_load.py:80`
  (`_RHR_FALLBACK = 60.0`). B3, C2.
* **Has any ported science drifted?** No. Three differences from legacy are declared
  behaviour changes with the reason written next to them and a test behind each; the
  fourth — the Jurca equation — is the `#108` correction, not drift. Section 5.
* **What does a mid-chain derive failure leave behind?** Nothing. The whole push is one
  transaction and it rolls back the raw rows with the derivation. Section 4.

---

## A. Unrecoverable

### A1 — the strap counter's READ INSTANT is a raw measurement with no durable home — CONFIRMED

This is `#121`'s exact shape, one field to the left, and it is still open.

The phone records **when it asked the strap** for its since-midnight counters and keeps
that instant deliberately. `apps/mobile/lib/data/store/tables.dart:207-209`:

> `/// When the reply landed, epoch milliseconds. A counter read at 09:00 is a`
> `/// claim about nine hours, not about a day, and the screen says so.`
> `IntColumn get readAtMs => integer()();`

It is load-bearing on the client: `apps/mobile/lib/data/store/push_reader.dart:126-133`
keys the pending-marker on `(day, readAtMs)` specifically so a newer reading that
overlapped a push is not marked sent — *"Marking it here would send the 09:00 figure and
then never send the 21:00 one."*

**The wire drops it.** `apps/mobile/lib/data/push/push_batch.dart:147-158` sends exactly
`day`, `steps`, `distance_m`, `calories`. `ingest/models.py:218-236` (`DailyTotalIn`) has
no field for a read instant and is `extra="ignore"`, so a client that sent one would have
it discarded. `ingest/upsert.py:346-352` then supplies its own:

```sql
INSERT INTO device_daily_total (user_id, day, steps, distance_m, calories, reported_at)
VALUES (%s, %s, %s, %s, %s, now())
```

`now()` is the **arrival** instant. The read instant falls off the phone's 60-day local
horizon and is gone. There is no second home for it anywhere — not in
`device_daily_total`, not in `sample`, not in a log. The pre-repair-backup argument that
made `#121`'s 142 days unrecoverable applies identically.

**And it is spent as if it were a measurement.** `derive/device_totals.py:135-170` builds
the owner-facing partial-day disclosure from it:

```python
if device is None or device.steps is None or device.reported_at >= day_end_utc:
    return []                                                          # line 156
...
"This is the strap's own step counter as it stood at "
f"{device.reported_at.isoformat()}, while the day was still running — so "   # line 163
```

Two consequences, both live:

1. **The quoted instant is wrong whenever the push is later than the read.** The sentence
   asserts, in the second person, when the counter "stood at" a value, using the moment
   the HTTP request landed. The function's own docstring calls the test *"exact rather
   than heuristic"*. It is exact about the wrong quantity.
2. **The caveat is suppressed entirely whenever the push crosses the owner's local
   midnight.** `reported_at >= day_end_utc` is then true for a counter read hours before
   the day ended, so `partial_day_caveats` returns `[]` — and `derive/activity.py:117`
   stores that empty list under the key `read/today_series.py` renders. This is not a
   corner: `MEMORY` records that auto-sync fires only on a foreground transition, so an
   overnight gap between the last read and the first push is the normal case.

The amplifier is that `select_steps` (`device_totals.py:123-132`) prefers the device
counter **unconditionally** over the per-minute sum. So a day whose only counter reading
is partial, pushed after midnight, serves the lower number as the day's step total with
`caveats: []`. `flags.steps_per_minute_sum` sits beside it on the row and would disagree
— which is the inspectability the module was built for, and it is not on the face.

**Why this is A and not B.** The step count itself is recoverable: `sample` still holds
the per-minute stream and `flags.steps_per_minute_sum` records it. The read instant is
not. Every `device_daily_total` row already written carries an arrival instant that no
code change and no re-derive can turn back into a measurement, exactly as the 142
overwritten counters could not be turned back into strap counts.

**Recommend:** add an optional `read_at` (epoch ms, `event_instant`-checked) to
`DailyTotalIn`; send `readAtMs` from `push_batch`; store it in a new column and let
`reported_at` keep meaning arrival. Where `read_at` is absent — every row written so
far — `partial_day_caveats` should refuse to name an instant rather than name the wrong
one, and should not treat an unknown read time as "after the day closed". The honest
default for a row that cannot say when it was read is a caveat that says so.

---

## B. Wrong now, and a re-derive would repair it

### B1 — two GPS sessions in one day: recency beats precedence, which is the rule the tier module forbids — CONFIRMED

`derived_daily`'s key is `(user_id, day, metric)` (`db/schema.sql:92`), so a day holds
exactly **one** `vo2max_submax` row. `derive/gps_scoring.py:105-113` scores a day's
pending tracks oldest-first and each `_store` (`derive/gps.py:276`) upserts that one
cell, so **the last track of the day owns it**. The module says so
(`gps_scoring.py:100-101`) and treats it as harmless.

It is not harmless, because `derive/vo2max_tier.py:209-227` reads the measured tier out
of those daily rows and nothing else. Concretely: a graded fit at 09:00 and a reserve
inversion at 18:00 on the same day leave only the reserve row, and
`select_measured_tier` — whose whole point is that *"a graded fit three days older than a
reserve inversion still wins"* (`vo2max_tier.py:172-175`, `[[hr_reserve_vo2max]]` D2) —
never sees the graded value at all. Inside one day, precedence **is** recency, which is
the ordering the module's own test `test_precedence_is_not_recency`
(`tests/derive/test_vo2max_tier.py:96`) exists to forbid.

Nor does a repair reach it: `unscored_tracks` (`gps_scoring.py:88-94`) skips any track
that already carries an estimate, so an ordinary `db/rederive` leaves the losing session
invisible forever, and `--rescore-tracks` reproduces the same ordering.

The session estimate itself is not lost — `gps_track.vo2max_submax` holds each track's
own number (`gps_scoring.py:148-160`) and `gps_point` is never rewritten — which is why
this is B and not A.

**No test covers two tracks in one day.** `grep -rn "two track\|second track\|both
tracks" tests/` returns nothing, and `tests/integration/test_gps_track_scoring.py` drives
one track per day throughout.

**Recommend:** let the tier read the session records rather than the day cells —
`gps_track` already carries per-track `vo2max_submax` and `r2`, and `start_ts` dates each
one. Failing that, `_store` should decline to overwrite a `METHOD_GRADED` row with a
`METHOD_RESERVE` one, so the daily cell obeys the same precedence the tier does.

### B2 — the ingest profile upsert NULLs demographics the profile editor is careful to preserve — CONFIRMED (latent with both shipped clients)

`ingest/upsert.py:241-253`:

```sql
ON CONFLICT (user_id) DO UPDATE SET
  name = COALESCE(EXCLUDED.name, profile.name), height_cm = EXCLUDED.height_cm,
  sex = EXCLUDED.sex, dob = EXCLUDED.dob,
  srpa = COALESCE(EXCLUDED.srpa, profile.srpa), updated_at = now()
```

`name` and `srpa` are protected; `height_cm`, `sex` and `dob` are assigned. Every field
on `ProfileIn` defaults to `None` (`models.py:259-267`), so a push whose `profile` block
omits a demographic **erases it**.

The docstring one screen up says the opposite of what the SQL does — `models.py:241-242`:
*"All optional — the app only sends a complete profile, but the server upserts whatever
is present."* It upserts what is present **and nulls what is not**. A comment claiming a
guard that is not a guard.

The same table has a second writer that gets it right. `read/profile_edit.py:44-69`
resolves each field against `model_fields_set` so that *"Omitted fields are preserved;
explicit null clears a demographic answer"* (`profile_edit.py:17`). **Two writers of one
table, two rules about absence**, and the ingest one can silently undo the editor.

The blast radius is the whole profile-dependent half of the layer: `_load_profile`
(`_common.py:205`) returns `None` when any of height/sex/dob is missing, which takes
out calories, distance, cardio load and the Jurca tier; `_date_of_birth`
(`_common.py:165-183`) takes out sleep need and sleep debt. And `profile` has no history
table — nothing anywhere else holds the owner's date of birth.

**Reachability.** The v02 client never sends `profile` at all
(`push_batch.dart:28-31`: *"this app has no profile to send … Nothing is better than
nearly"*), and the legacy installed app sends it only `if (profile.complete)` with all
four fields (`healthee-legacy/app/lib/ble/helio_api.dart:97-103`). So this is **latent,
not live** — the same standing the sleep-COALESCE defect had, and the team fixed that one
anyway, for a reason that applies verbatim: `/ingest/helio` is reachable by any device
token including an older app build.

**Recommend:** `upsert_profile` takes `profile_edit`'s `model_fields_set` shape, so
"omitted" and "explicitly cleared" stay distinguishable, and one rule governs the table.

### B3 — a partial stage breakdown becomes zeros, and an absent `wake_min` fabricates 100% efficiency — CONFIRMED (latent)

`derive/orchestrator.py:83-84`:

```python
if sr and any(v is not None for v in sr):
    rem, light, deep, wake = (int(v or 0) for v in sr)
```

The gate is `any`, not `all`. The comment above it argues correctly that a night with
**no** breakdown must not be scored, and `0018` made the columns nullable so that state
is representable. A **partial** breakdown still becomes zeros.

The sharpest case is `wake_min`. With it absent,
`sleep_score._sleep_efficiency(tst, 0)` returns `min(1.0, tst/tst) == 1.0`
(`sleep_score.py:52-61`), so the night scores `p_eff = 1` and stores
`flags.efficiency_pct = 100.0`. That is a fabricated perfect efficiency, on a dimension
of the 4-dim score, from a measurement nobody made. An absent `rem_min` or `light_min`
understates `tst_min`, which then feeds `sleep_debt_min` (`_tst_window:253-259`) and the
recovery sleep factor (`recovery._sleep_factor:118-139`).

**Reachability.** The v02 store's four stage columns are non-nullable
(`apps/mobile/lib/data/store/tables.dart:116-125`) and `push_batch.dart:175-178` sends
all four, so no shipped client produces a partial record. Same standing as B2, same
argument for closing it anyway.

**Recommend:** the gate becomes `all(v is not None for v in sr)`, or the four minutes are
carried as `int | None` into `derive_sleep_score` and each dimension withholds on its own
missing input. `_sleep_efficiency` should return `None` on an unknown `wake_min` rather
than 1.0 — a ratio with an unknown denominator term is not a measurement.

### B4 — a re-pushed workout can zero its own duration — CONFIRMED (latent)

`ingest/upsert.py:198-199` assigns `sport` and `duration_s` unconditionally while every
other measurement on the row is COALESCEd. `WorkoutIn` defaults both to `0`
(`models.py:201-204`), so a re-push omitting `duration_s` replaces a recorded duration
with zero.

The docstring (`upsert.py:187-191`) names this and declines to fix it, on the correct
ground that a COALESCE would pin the first value ever pushed — but it does not price the
consequence, which is that a zeroed session **disappears from three gates at once**:
`read/fitness.py:344` and `challenges/series.py:126` both filter on
`COALESCE(duration_s, 0) >= min_duration_s`, and `energy._tee_met:118` stops removing the
session's minutes from the MET walk, so the day's calories move.

**Recommend:** the model change the docstring already identifies — `duration_s: int |
None` and `sport: int | None`, COALESCEd like the rest — so absence stays absence at the
boundary. It is a wire-compatible change: the columns are `NOT NULL DEFAULT 0`
(`schema.sql:62,61`), and a first insert can keep supplying the default.

### B5 — a nap-only push derives nothing, and naps change the day's calories and load — CONFIRMED mechanism, SUSPECTED reachability

`ingest/service.py:107-118` (`_is_derivable_night`) excludes naps, and it gates **both**
`_affected_nights` and `_affected_days` (`service.py:134-137`). So a push carrying a nap
and nothing else for that day marks no work at all, and `derive` is not called for it.

That would be right if a nap changed nothing. It does not: `energy._tee_met:107-112` and
`cardio_load.py:41-46` both read

```sql
SELECT start_ts, end_ts FROM sleep_session WHERE user_id = %s AND end_ts>=%s AND start_ts<%s
```

with **no `kind` filter**. Every nap minute is therefore scored at `SLEEP_MET = 0.95`
instead of NEAT, and excluded from the day's TRIMP as "recovery, not load". A nap that
arrives without new samples for its day leaves both numbers computed as if the owner had
been awake through it, until some unrelated reason re-derives that day.

`_is_derivable_night`'s docstring says the two passes ask "the same question because they
answer it about the same sessions". They do not — the night pass is about a night, and
the day pass is about anything that moved the day.

**Reachability is SUSPECTED**, and it turns on whether a page can carry a nap with no
samples for the same day. The service's own docstring says the client "sends sessions and
samples on separate pages" (`service.py:27-29`) and `push_reader.dart:60-79` pages
samples while sending sessions unpaged, so a session-only page is a real shape; whether a
nap ever lands on one without its day already being marked by other sections could not be
established without a device.

**Recommend:** `_affected_days` adds `local_date(session.start_ts)` for **every** pushed
session including naps, while `_affected_nights` keeps excluding them. The two questions
are different and the code should stop sharing one predicate between them.

### B6 — a regressing device counter permanently replaces a higher reading — SUSPECTED

`ingest/upsert.py:355-359` merges per field on conflict:

```sql
ON CONFLICT (user_id, day) DO UPDATE SET
  steps = COALESCE(EXCLUDED.steps, device_daily_total.steps), …
  reported_at = EXCLUDED.reported_at
```

COALESCE guards **nulls**, not staleness. The docstring's justification is that *"the
counter is a live since-midnight accumulator, so the newest reading is the most complete
one"* (`upsert.py:333-335`) — an assumption of monotonicity within a day. A since-midnight
accumulator on the strap resets on a device reboot or a clock change; when it does, the
next reading is **lower**, it is written, and the higher one is gone. There is one row per
`(user_id, day)` and no history, so nothing can restore it.

The client makes the regression unlikely from its side — the local table is keyed on
`{day}` alone (`tables.dart:230`) and is overwritten in place, so at most one reading per
day is ever in flight — which is why this is SUSPECTED rather than confirmed. Proving or
clearing it needs the strap.

**Recommend:** make the write monotone in the counter's own terms —
`steps = GREATEST(EXCLUDED.steps, device_daily_total.steps)` is wrong if a reset is real
(it would pin the pre-reset value forever), so the honest form is to keep the higher value
**and record that a lower reading arrived**, in a flag the derivation can disclose. Either
way the decision belongs in code with its evidence beside it, not in an unstated
assumption.

### B7 — two main sessions ending on one wake date silently collide — SUSPECTED

`derive_night` keys every metric it writes to `_wake_date(end_ts)`
(`orchestrator.py:58`), and `derive_batch` iterates a **sorted** night list
(`service.py:155`, `orchestrator.py:156-157`). Two `kind='main'` sessions ending on the
same local date therefore both write `rhr_daily`, `hrv_sleep_avg`, `spo2_overnight`,
`respiratory_rate_sleep` and `sleep_health_score_4dim` for that date, and **the later one
wins every cell**. `sleep_health_score_4dim.flags.tst_min` would then hold only the second
fragment's total sleep time, which `_tst_window` (`sleep_score.py:253-259`) reads into the
14-night debt and `recovery._sleep_factor` reads into the readiness score — so a
fragmented night reads as a short one twice over.

`sleep_session`'s key is `(user_id, start_ts)` (`schema.sql:52`) and the client sends
`kind: night.isNap ? 'nap' : 'main'` (`push_batch.dart:171`), so nothing prevents two
main rows for one night. Whether the strap ever produces them — plausible for a chronic
short sleeper who wakes and re-sleeps — needs the device.

**Recommend:** if the shape is real, `derive_night` should derive over the **wake date's**
main sessions as one window set rather than one session at a time, so a fragmented night
sums instead of overwriting. Until that is settled, the cheap honest step is to detect it:
log when a wake date receives a second `derive_night`, so it stops being invisible.

---

## C. The number stands; the provenance beside it does not

### C1 — every sleep row is stamped with an instrument that does not exist in this repo — CONFIRMED

`derive/sleep_score.py:215` writes, on all six rows a night produces:

```python
"session_source": "zepp_cloud",
```

It is a verbatim carry-over from legacy (`healthee-legacy/src/healthee/v2/derive.py:154`),
where sleep genuinely arrived from Zepp Cloud. **In the rebuild the only writer of
`sleep_session` is `ingest/upsert.upsert_sleep`**, fed by the strap over BLE
(`grep -rn "INSERT INTO sleep_session"` returns that one site). There is no Zepp path.
The read layer repeats the literal at `read/sleep_page.py:171` and `:306`.

Standards section 6 of this audit's brief asks whether any writer sets a flag it did not
measure. This is the clearest instance in the layer: a provenance field naming an
instrument that did not take the reading, on the product whose premise is that every
number names its instrument.

It is C rather than higher because the value is never rendered. The client uses the field
as a presence sentinel only — `apps/mobile/lib/data/models/sleep_night.dart:113`:
`final hasSession = json['session_source'] != null || json['start_iso'] != null;` — and
`data/honesty/sleep_gap.dart:21` documents it as such. Nothing draws the string.

**Recommend:** `'strap_ble'`, written once beside the ingest that produces it, and the
read layer's two literals replaced by the stored value. This is `MEMORY`'s
`project_source_naming_cleanup` and it is still open.

### C2 — an unmeasured resting HR becomes 60 bpm and the flag does not say so — CONFIRMED

`derive/cardio_load.py:22` and `:72-80`:

```python
_RHR_FALLBACK = 60.0  # when no measured resting HR is available
...
return float(r[0]) if r and r[0] is not None else _RHR_FALLBACK
```

and line 62 stores `"rhr": round(rhr)` in the row's flags with nothing distinguishing a
measured 60 from an assumed one. RHR is the Karvonen denominator
(`trimp.hr_reserve_fraction`), so the whole day's `cardio_load` and its Edwards zone
minutes rest on it, and the row advertises a resting heart rate the owner never had.

This is a **verbatim port** — legacy `derive.py:640-643` does exactly the same — so
changing the number is a behaviour change owed its own PR with known-value tests
(`CLAUDE.md`). Changing what the row *says about itself* is not.

**Recommend:** the smallest honest change is a flag: `"rhr_source": "measured" |
"assumed_60"`, and a `caveats` entry when assumed, using `freshness.caveat_block` — the
vocabulary the layer already has. Whether a day with no measured RHR should produce a
`cardio_load` at all is the separate science PR.

### C3 — `cardio_load` spends a resting HR of unbounded age with no horizon — CONFIRMED

`derive/cardio_load.py:74-78` takes the most recent `rhr_daily` on or before the day,
with no maximum age. A resting HR measured in March anchors August's TRIMP.

Every other held measurement in this layer now has a horizon with its evidence written
next to it: `freshness.WEIGHT_MAX_AGE_DAYS` (14, `freshness.py:148-178`) and
`freshness.MEASURED_VO2MAX_MAX_AGE_DAYS` (14, `freshness.py:181-233`). `derive/vo2max.py`
goes further and withholds on a stale weight. `cardio_load` is the one consumer of a held
measurement that never asks how old it is, and it is not exempt by kind — RHR moves with
training, illness and season exactly as the quantities that do get horizons.

**Recommend:** state the horizon or state that there is none. If the evidence for one
cannot be sourced — which is a real possibility — then the honest form is
`freshness.caveat_block` naming the RHR's date on the row, the way
`derive/energy.weight_flags` names the weight's date on all three calorie metrics.

### C4 — a live gate's argument is priced against the constant `#108` deleted — CONFIRMED (comment only)

`derive/vo2max.py:287-288`, inside `_profile_withhold_reason`'s docstring:

> *"Note what is NOT the argument: the numeric error is small (≈0.2 ml/kg/min per kg of
> weight error, against Jurca's own 5.6 SEE)."*

5.6 is the unsourced figure `#108` removed, and the correct value sits 220 lines above in
the same file (`_JURCA_SEE_ML_KG_MIN = 5.075`, line 71) under a comment explaining that
5.6 *"appears nowhere in the paper"*. The gate itself is correct and unaffected; the
reasoning a reader is handed for it quotes the refuted number as the reference.
`docs/BACKEND_AUDIT.md` A1 removed the same constant from a payload; this is its last
occurrence in the tree.

**Recommend:** correct the sentence to 5.075. The arithmetic conclusion does not change.

---

## D. Hygiene

### D1 — `emit_sleep_minutes` materialises thousands of rows per night that nothing reads — CONFIRMED

`ingest/upsert.py:95-117` runs `generate_series(..., interval '1 minute')` per hypnogram
stage, writing a `sleep_stage` sample per minute and an `asleep` sample per non-awake
minute — up to ~2,880 rows in the `sample` hypertable per fresh night. Its docstring says
they exist *"so downstream SRI / stage reads have a per-minute stream"*.

**No such reader exists.** A repo-wide grep across `apps/` and `packages/` for
`metric='sleep_stage'` and `'asleep'` returns: the writer itself; three assertions in
`tests/integration/test_ingest_integration.py` that the write happened; a cluster-name
list in `read/findings.py:38`; and a display-name map in
`apps/mobile/lib/shared/format/metric_names.dart:82`. SRI is computed from
`sleep_session.stages` (`derive/sleep_score._sri_grid:77-82`), and so is the sleep page.
`analytics/metrics.py:31-54` enumerates the daily metrics explicitly and neither name is
in it.

Legacy had v1 compat views (`metric_sample`) reading these rows; `db/schema.sql:11-12`
records that those views were deliberately dropped in the rebuild. The write survived the
consumer.

This is also the most expensive statement in a push, and the reason the whole
`_MAX_STAGES` / `_MAX_SESSION_STAGE_MINUTES` bounding apparatus exists
(`models.py:80-116`) — a denial-of-service surface maintained for output nobody consumes.

**Recommend:** delete it, or name the consumer it is being kept for. Standards, "Dead
code": delete, don't keep just in case; git has it. If it is being held for a planned
per-minute read, that belongs in a comment saying so, not in a docstring asserting a
reader that does not exist.

### D2 — the per-minute emit is not idempotent under a corrected hypnogram — CONFIRMED

`sleep_stage` is written `ON CONFLICT … DO UPDATE` (`upsert.py:108`) while `asleep` is
`ON CONFLICT … DO NOTHING` (`upsert.py:115`), and **neither deletes minutes the new
hypnogram no longer covers**. A re-pushed session that reclassifies a block from light
sleep to awake updates `sleep_stage` to 7 and leaves the old `asleep = 1` rows standing;
a shortened session leaves orphan minutes at both ends forever.

Harmless today only because of D1. If either metric ever gains a reader, this becomes a
correctness defect on the same day.

### D3 — a docstring points at a test in the wrong file — CONFIRMED

`derive/orchestrator.py:104` cites
`tests/derive/test_vo2max_tier.py::test_derive_day_scores_the_days_tracks_before_it_reads_them`.
The test is real and does what the docstring claims, but it lives in
`tests/derive/test_vo2max_tier_surfaces.py:310`. A reader who follows the pointer finds
nothing — the failure mode `docs/HOW_WE_VERIFY.md` section 2 names, and the one a prior
audit was misled by.

Two neighbouring citations were checked and are sound: `derive/vo2max.py:257`'s
unqualified `test_vo2max_freshness` resolves to `tests/read/test_vo2max_freshness.py`
(which does pin the writer/reader equivalence, at `:238-251`), and
`derive/sleep_score.py:152`'s `tests/derive/test_sri_freshness.py` exists and pins what it
says.

### D4 — `samples_accepted` counts rows stored, new or not — CONFIRMED

`upsert.py:92` returns `len(rows)` — every whitelisted sample in the payload, including
the ones the `ON CONFLICT` branch merely rewrote with the identical value. The client
prints it verbatim as `accepted N` (`apps/mobile/lib/data/push/push_client.dart:87`).
"Accepted" reads as "landed and was new"; it means "was not rejected". Low consequence —
the string is a summary line, not a progress gate — but it is the sync surface, and
`MEMORY` records a whole session lost to misreading exactly this kind of counter.

---

## 4. What a mid-chain derive failure leaves behind

**Nothing half-written, and that is structural rather than careful.**

`derive_batch` (`orchestrator.py:155-159`) opens one cursor and runs every night and then
every day inside the **caller's** transaction; it commits nothing. The caller is
`ingest_helio` (`service.py:182-201`), which holds `core.db.tenant_connection`
(`core/db.py:218-231`) — a pooled connection whose context manager commits on a clean exit
and rolls back on any exception. An exception in day 3 of 10 therefore discards the
derivation **and the raw upserts of the same push**, together.

So a partially derived day that looks complete is not representable by this path. That is
the right trade, and the cost should be stated rather than discovered: a derive bug makes
the whole push fail, so raw rows cannot land while it is unfixed. The client is built for
that — `push_reader.markPushed` is *"Called only after a 2xx"* and its comment names the
`#121` shape as the reason (`push_reader.dart:99-103`) — and the 60-day local store means
the rows survive to be re-sent. The failure is loud, bounded and recoverable.

**The nightly chain does not derive.** `jobs/chain.py` runs illness → challenges →
correlate → recs → warm → briefing, each supervised in its own transaction
(`chain.py:177-192`, `jobs/steps.py:46-47`), and only `step_illness` writes anything this
audit covers — one `illness_flag` row per owner per day, upserted or deleted, in its own
transaction. `gps_scoring.py:29-33` states deliberately that the chain is not a derive
seam, and it is not. So the "half-derived day" question has exactly one answer path and
it is atomic.

**One asymmetry worth naming.** `derive_day`'s steps swallow nothing but they also check
nothing: each derivation returns `None` or `{}` when it declines, and `derive_day`
(`orchestrator.py:107-121`) merges whatever comes back. A day where five metrics wrote and
two withheld is indistinguishable, at the row level, from a day where five wrote and two
were never attempted — the row simply is not there. `db/stale_derived.py`'s unconditional
detection is the answer to that at repair time, and it is a good one; there is no
equivalent at push time, and `IngestSummary` reports `days_derived` as the count of days
**planned**, not the count that produced anything (`service.py:219`).

---

## 5. Science fidelity against legacy

Diffed function by function against `~/projects/healthee-legacy/src/healthee/v2/derive.py`
and `vo2max_submax.py` (read-only; nothing there was modified).

**No silent drift found.** Every difference is either declared with its reason in the code
or is a documented correction. Specifically:

| Rebuild | Legacy | Verdict |
|---|---|---|
| `vo2max_submax.py` — all 11 tunables, `_haversine_m`, `_vo2_speed_grade`'s two Minetti polynomials, the window gates, the least-squares fit, every rounding | `vo2max_submax.py:22-219` | **Identical.** The split into `_smooth_elevation` / `_build_intervals` / `_window_point` / `_fit` moves code without editing it; `robust.median` is byte-equivalent to the private `_median` it replaced (both take the mean of the two central values). |
| `trimp.py` — `(0.64, 1.92)` / `(0.86, 1.67)`, the 0–1 reserve clamp | `derive.py:373` `TRIMP_W`, `derive.py:664` | **Identical**, and now one definition instead of two call sites. |
| `mvpa.py` — 100/80/130/110 thresholds, per-minute max, prior-minute gate | `derive.py:372-396` | **Identical.** The deleted `_mvpa_to_pa_score` is `#108`, argued at `mvpa.py:23-41`. |
| `sleep_score.py` — 7.0/9.0, 0.85, `(2, 4)`, 70.0, 7 days, 480/450, 14 nights, 0.5 credit, the SRI grid and its `-100 + 200/(1440·6)·matches` | `derive.py:301-306`, `derive.py:101-129`, `derive.py:365-370` | **Identical.** The duration band's citation was re-attributed from Cappuccio to NSF 2015 with the value explicitly unchanged (`sleep_score.py:26-34`). |
| `recovery.py` — weights 0.42/0.28/0.20/0.10, k = 20/20/15, 42-day window, 5-point minimum, 0.5 SD floor | `derive.py:391`, `derive.py:732-790` | **Identical.** |
| `energy.py` — 1.3 / 1.55 / 0.95 / 7-min NEAT window, the ACSM 134 m/min switch, Mifflin-St Jeor | `derive.py:362-366`, `derive.py:262-302` | **Identical.** |
| `rhr.py`, `hrv_spo2_resp.py` — 5-minute buckets, `HAVING COUNT(*) >= 3`, the (5,200)/(70,100)/(4,40) window bounds | `derive.py:53-88`, `derive.py:158-198` | **Identical.** |
| `_sleep_efficiency` = `tst/(tst+wake)` | `derive.py:135` `eff = tst / tib` | **Declared change** — legacy could report >100%; cited to `[[no_validated_sleep_score]]` at `sleep_score.py:52-58`. |
| `_day_bounds_utc` = next local midnight; `_day_minutes` replaces `range(1440)` | `derive.py:305-308` (23:59:59), `derive.py:288` | **Declared change** — DST correctness, argued at `_common.py:100-154` with three worked zones and pinned by `tests/derive/test_energy_dst.py`. |
| `robust.median` replacing five hand-rolled upper-middle medians | `derive.py:744` `mad = devs[len(devs)//2]` and four others | **Declared change** — a dated science-behaviour PR with known-value tests, argued at `robust.py:41-61` and `recovery.py:44-49`. |
| `_vo2max_jurca` = `18.07 + 2.77·sex − 0.10·age − 0.17·bmi − 0.03·rhr + srpa_mets(srpa)`, ×3.5 | `derive.py:230-238` — a **sex-stratified** pair (`56.363 + 1.921·pa − 0.381·age − 0.754·bmi − 0.084·rhr`) | **Not drift — the `#108` correction.** Legacy's coefficients appear nowhere in Jurca 2005; the rebuild carries the paper's Table 5 NASA column, dummy-coded per `derive/srpa.py:41-58`. |

Two further checks the brief asked for by name:

* **`#108`'s deleted constant.** `_JURCA_SEE_ML_KG_MIN = 1.45 × 3.5 = 5.075`
  (`vo2max.py:70-71`) is what the derive layer writes. The `5.6` the read layer restored
  as a default was `docs/BACKEND_AUDIT.md` A1 and is fixed there; its only surviving
  occurrence in the tree is the prose at `vo2max.py:288` (C4). It formats cleanly — the
  message at `vo2max.py:213-215` renders "5.075", not a float artefact.
* **No blending, structurally.** `select_measured_tier` (`vo2max_tier.py:177-197`) filters
  to one method **before** any median, and `select_steps` (`device_totals.py:123-132`)
  returns one instrument's value with the other in a flag. Both are tested against a
  mutation of themselves — `test_the_two_methods_are_never_averaged` and
  `test_no_ordering_of_sessions_can_produce_a_value_from_two_instruments`
  (`tests/derive/test_vo2max_tier.py:115,133`). Opened and read; they do what they claim.

---

## 6. Swept clean — classes checked, with the evidence

1. **`derived_daily` has exactly one writer.** `grep -rn "INSERT INTO derived_daily"`
   across `apps/server/src` returns `derive/_common.py:60` and nothing else. The second
   writer `#121` named — ingest's post-derive override — is gone; `db/stale_derived.py:144`
   holds the only `DELETE`, and it is bounded by owner, day window, and a metric list the
   tool refuses to invent (`stale_derived.py:87-101`).
2. **No derive pass writes a raw table.** The only writes in `derive/` are that upsert,
   `illness_flag` (`illness.py:376,391`), and `gps_track`'s derived summary columns.
   Checked by grep for `INSERT INTO` / `UPDATE` / `DELETE FROM` across the package.
3. **Every raw section of the payload has a durable home.** `samples` → `sample`;
   `sleep` → `sleep_session` including the `stages` hypnogram and the device's own
   `score`; `workouts` → `workout`; `daily_totals` → `device_daily_total` (0017);
   `profile.weight_kg` → `weight_log`. Each survives a re-derive by construction, because
   of (2). The one field with no home is A1.
4. **The `gps_track` denormalisation cannot destroy anything the phone measured.**
   `read/gps.py:41-51` inserts only `id, user_id, start_ts, end_ts, source` plus the
   points; the five columns `_denormalise_summary` overwrites
   (`gps_scoring.py:148-160`) are all derived summary fields. `gps_point` is written once
   with `ON CONFLICT DO NOTHING` and never rewritten.
5. **No swallowed errors.** Exactly one `try/except` exists in the 32 modules
   (`derive/dem.py:93-102`), narrowed to `OSError, URLError, EOFError, BadGzipFile`,
   logged with context, and its miss is a documented meaningful fallback to the phone's
   own elevation. `_scalar` (`_common.py:250-259`) raises loudly rather than returning 0
   for a missing aggregate row.
6. **Replay cannot double-count.** Every write in `ingest/upsert.py` is `ON CONFLICT` on a
   natural key; nothing accumulates, increments, or appends. `upsert_weight:292-308`
   additionally refuses to re-stamp an unchanged mass, which is what stops a weight's
   *age* being laundered — the defect measured at 41 rows for two real weigh-ins.
7. **Boundary refusal beats a stored bad value.** `SampleIn` sets `allow_inf_nan=False`
   and bounds `value` by `MAX_MAGNITUDE` (`models.py:111-115`); `ts` goes through the one
   `event_instant` range check; every list carries a `max_length`
   (`models.py:75-78, 300-303`); `SleepIn._the_hypnogram_is_bounded` (`:173-190`) caps
   what one session can materialise, with an arity check so `stages: [[]]` is a 422 and
   not a 500. Nothing converts a refused value into a stored one.
8. **`activity.py:50`'s `or 0.0` is not a fabricated zero.** It reads a `COALESCE`'d
   aggregate that always returns a row, and the write is gated on line 100's `counted`,
   which uses the sample **count**, not the sum. This is exactly the class the read audit
   correctly cleared — a default that looks like fabrication because the next line guards
   it.
9. **`derived_at` is set on every write and cannot be omitted.** One statement sets it on
   insert **and** on conflict from `now()` (`_common.py:58-67`), so a whole batch shares
   the transaction instant and `stale_derived._NOT_WRITTEN_BY_THIS_RUN` can ask "what did
   this run not touch" in one predicate. There is no writer that could forget it, because
   there is one writer.
10. **No future leak from the write side.** Every window closes at or before the day being
    derived: `rhr_week` (`vo2max.py:239-243`), `_tst_window` (`sleep_score.py:253-259`),
    `_recovery_baseline` (`recovery.py:51-55`, strictly `day < %s`), `measured_sessions`
    (`vo2max_tier.py:209-214`), `_weight_as_of` (`_common.py:229-233`), `_measured_rhr`
    (`cardio_load.py:74-78`), `_sleep_factor`'s need lookup (`recovery.py:124-128`).
    `measured_fitness_is_stale` (`freshness.py:236-248`) is signed on purpose so a session
    recorded **after** the day cannot speak for it.
11. **`derive/` never calls `analytics/`.** `grep -rn "from healthee.analytics"` over
    `ingest/` and `derive/` returns nothing; the dependency runs the other way
    (`analytics/baselines.py`, `analytics/biological_age*.py`, `analytics/finding.py`
    import from `derive/`). The brief's "analytics where a derive calls into it" is an
    empty set, which is the correct direction under standards section 1.
12. **SQL is parameterized.** The only interpolated fragments in the two layers are
    `_window_stat`'s aggregate name, allowlisted at `_common.py:81-82` and cast to
    `LiteralString`, and `hr_validity.HR_VALID_SQL`, which is a `LiteralString` carrying
    `%s` placeholders (`hr_validity.py:49-57`). Every tenant query carries an explicit
    `AND user_id = %s` beside RLS.
13. **The tiered writers are gate-equivalent to their read-side twins, and the tests
    exist.** `vo2max_tier.withhold_reason_for_day` ↔ `derive_vo2max_estimate` is pinned by
    `tests/derive/test_vo2max_tier_surfaces.py:160`; `vo2max.withhold_reason_for_day` ↔
    `derive_vo2max` by `tests/read/test_vo2max_freshness.py:238`;
    `sri_withhold_reason_for_day` ↔ `_compute_sri` by `tests/derive/test_sri_freshness.py`;
    `sleep_debt_withhold_reason_for_day` ↔ `derive_sleep_debt` by
    `tests/derive/test_sleep_need_inputs.py:102`. All four opened.
14. **`#121` is closed on the step count itself.** `apply_daily_totals` is gone;
    `upsert_daily_totals` stores raw and `derive/device_totals.py` decides `steps_total`
    on every pass, so the repair path is idempotent for steps and distance instead of
    lossy. `db/rederive.py:39-51` records the old behaviour and states plainly that the
    142 lost production days are **not** recovered. Verified against `db/schema.sql:107-116`
    and the absence of any other `device_daily_total` writer.

---

## 7. Could not determine, and why

1. **Whether the strap ever reports two `main` sessions ending on one wake date (B7), or a
   0x0016 counter that regresses within a day (B6).** Both are statements about firmware
   behaviour and need the device or production data. The brief forbids both, correctly.
2. **The blast radius of A1 in production** — how many `device_daily_total` rows already
   carry an arrival instant far from their read instant, and how many days lost their
   partial-day caveat to a midnight-crossing push. Needs the production database.
3. **Whether B2, B3 and B4 are live or latent right now**, which turns on which client is
   actually pushing to production. Both clients in this repo's reach are safe — the v02
   app sends no profile and full stage/workout records, and the legacy app sends a profile
   only when complete — but `MEMORY` records that prod still runs from the legacy repo's
   remote, and an installed build cannot be inspected from here.

---

## 8. Recommended order

Ranked by recoverability, then by whether the wrong thing reaches a screen.

1. **A1** — add `read_at` to the wire and stop inventing it. Every day that passes writes
   more rows whose read instant can never be recovered. Until it ships, the narrower fix
   is worth having on its own: `partial_day_caveats` should not treat an unknown read time
   as "after the day closed", because that is the branch that suppresses a true caveat.
2. **B1** — the tier should read session records, not day cells. It is a live science
   violation of a directive the code elsewhere enforces structurally, and it has no test.
3. **B2** — one rule for the profile table. Latent, but it can silently erase the owner's
   date of birth, and nothing else holds it.
4. **B3, B4** — close the two remaining boundary coercions, both already half-argued in
   the docstrings that name them.
5. **B5** — naps mark their day affected.
6. **C1, C2, C3** — three flags that name something they did not measure. Cheap, and each
   is the honesty contract applied to provenance rather than to a number.
7. **D1** — delete the per-minute emit or name its consumer. It is the layer's largest
   write and it feeds nothing.
8. **C4, D2, D3, D4** — corrections.

`db/stale_derived.py --purge-stale` is the right tool for the rows B1 and B3 would orphan;
`steps_total` and `sleep_health_score_4dim` are both outside `GATED_METRICS`, so the purge
admits them. Nothing here should be run against production without the owner's word.
