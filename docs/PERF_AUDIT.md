# Performance audit — the server and the app against the standards' own budgets

The eighth and last item of the audit programme (`AUDIT_COVERAGE.md` item 6), and the
only one that was never *measured* rather than never *read*. `BACKEND_AUDIT.md` closed
with the sentence this document exists to replace:

> Performance against the standards' budgets. The read layer's batching comments are
> detailed and credible; **no measurement was taken.**

The measurement is taken. Every number below came off a throwaway TimescaleDB container
seeded to a realistic history; nothing touched production, a device, or a real database.
**Numbers, not adjectives.** Where a budget could not be measured from here, this says so
and says why rather than estimating.

Findings are marked **CONFIRMED** (measured, with the number) or **SUSPECTED** (reasoned
from code, not reproduced). Budgets that were **MET** are reported too — a met budget is a
result, and it is the only thing that makes "fast enough" a claim rather than a hope.

Nothing was changed by this audit. It recommends; it does not fix.

---

## 0. Counts

| Severity | Meaning | Count |
|---|---|---|
| **A — blows a budget today** | a shipped endpoint exceeds a stated budget on realistic data | 2 |
| **B — grows silently** | correct now, unbounded or superlinear as data accumulates | 4 |
| **C — waste with no budget consequence yet** | measured redundancy | 3 |
| **Within budget, measured** | budgets checked and met | 7 classes |
| **Could not measure** | needs a device, production, or load hardware | 5 |

CONFIRMED 11 · SUSPECTED 2 · Corrected from my own first reading 1 (the driver of
`/api/sleep`'s cost — my first hypothesis, chunk count, was wrong; the experiment that
killed it is in A1).

---

## 1. The budgets, quoted

`ENGINEERING_STANDARDS.md` section 1, "Performance is a requirement, not an aspiration":

> **Budgets (measured on typical real data, not empty DBs):**
>
> | Surface | Budget |
> |---|---|
> | Server read endpoints (non-LLM) | p95 < 100 ms |
> | Ingest push (one normal day of new data) | < 5 s end-to-end |
> | LLM endpoints | pre-warmed/cached per day; generation never blocks a sync or a read path |
> | App cold start → first meaningful paint | < 2 s (cache-first render) |
> | Tab switch / scroll | 60 fps — no dropped-frame jank; charts never rebuild on scroll |
> | Full incremental BLE sync (typical day) | < 30 s |

And the rules that keep them, quoted where a finding cites one:

> - **Bound the round-trips.** No N+1 queries; bulk writes use `executemany`/pipelining
>   … no per-item connections — the pool is the only way in.
> - **Unbounded data is windowed** — every list endpoint paginates; every chart query has
>   a range.
> - **Measure, don't guess.** Any PR claiming or affecting performance carries numbers.

One more figure is treated as a budget here because the standards state it as a fact about
the wire and a later rule leans on it:

> `/api/today` is ~20 KB of deeply nested, largely-optional structure
> (`ENGINEERING_STANDARDS.md` section 2, the pydantic-response exception)

and `analytics/correlations.py:MAX_REPORTED_PAIRS` sizes its own cap against it —
*"a payload that doubled to show detail nobody can see would be trading the app's
cold-start budget for nothing."*

---

## 2. The rig, so the numbers can be re-taken

**Server.** A throwaway `timescale/timescaledb:latest-pg17` container on a spare port,
torn down afterwards; never a real database, and a separate container per concurrent suite
(`tests/_isolation.py`'s rule — a private *database* is not enough, the app role is
cluster-level). The app ran as the least-privilege role with RLS live, exactly as the
suite does. Statement counts and per-statement timings came from wrapping
`psycopg.Cursor.execute` — the same instrument `tests/contracts/test_perf.py` already
uses, extended to record the SQL and the time.

Two datasets:

| | contract seed | scaled |
|---|---|---|
| `derived_daily` rows | 661 (30 days × ~22 metrics) | 8,801 → 64,241 (400 days → 8 years) |
| `sleep_session` | 8 | 401 → 1,461 |
| `sample` | 6,462 | 1,056,000 (400 days at 2,784/day) |
| `workout` | 1 | 200 |
| `manual_entry` | 5 | 800+ |

The scaled sample density (2,784/day) is **below** production's — the live database holds
540,420 samples over 143 days, i.e. ~3,776/day — so every server number here is
conservative rather than inflated.

**Mobile.** `flutter test` on the host, pumping the real `TodayScreen` and the real router
over an in-memory Drift store, using the repo's own `_today_host.dart` fixtures and the
committed `today.json` snapshot. **These are host numbers in a headless test binding, not
device numbers**, and section F says exactly what that does and does not license.

**Payloads.** Serialised byte counts of the committed snapshots in
`packages/contracts/snapshots/`, and of live responses at 200 days of history.

---

## A. Blows a budget today

### A1 — `/api/sleep` takes 16.5 seconds on a year of nights, and its default call is already over budget. ONE statement is the whole cost, and a metric predicate cuts it 32×. — CONFIRMED

`apps/server/src/healthee/read/sleep_page.py:218-263` (`_apply_physiology`).

Measured p50 for `GET /api/sleep`, history grown in place on one owner:

| owner's nights | `days=30` (the app's default) | `days=365` (the cap) |
|---|---|---|
| 30 | 12.8 ms | 121.8 ms |
| 90 | 124.2 ms | 1,007.2 ms |
| 180 | 127.8 ms | 4,129.9 ms |
| 365 | 10.0 ms † | **16,556.3 ms** |
| 730 | 125.2 ms | 16,481.3 ms (`days` clamps at 365) |
| 1,460 | 125.5 ms | 16,586.8 ms |

† One of six readings of the `days=30` form came in at 10.0 ms rather than ~125 ms. It is
recorded, not smoothed away. Four of the six sat at 124-128 ms with a spread under 4 ms, so
the ~125 ms figure is the one to plan against; a separate rig (below) reproduced 123-126 ms
across nine consecutive calls at three different data shapes. In the same 400-day sweep the
`days=30` form's **p95 was 118.7 ms** — over budget on its own.

Against a budget of **p95 < 100 ms**. The 365-night call is **165× over**. The default
30-night call — the one the app actually makes — is **~125 ms, over budget**, from 90
nights of history onward.

**It is one statement.** Per-statement trace of a single `/api/sleep` request:

| dataset | the physiology statement | whole request |
|---|---|---|
| 31 nights, 83,696 samples | **121.4 ms** | 125.1 ms |
| 366 nights, 152,336 samples, `days=365` | **1,533.5 ms** | 1,555.7 ms |

Every other statement in the endpoint is under 3.1 ms. The batching this function was
written to do is real — the statement **count** is a fixed 11 whether the owner has 10
nights or 200, and `test_perf.py::test_sleep_query_count_does_not_grow_with_history`
holds it there. What was never measured is that the one statement it collapsed to grows
with the product of nights and in-window samples.

**Why.** `EXPLAIN (ANALYZE, BUFFERS)` on the 365-night form:

```
HashAggregate (actual rows=365 loops=1)
  ->  Nested Loop Left Join (actual rows=266912 loops=1)
        ->  Function Scan on w (actual rows=365 loops=1)
        ->  Custom Scan (ChunkAppend) on sample s (actual rows=731 loops=365)
              ->  Index Scan using _hyper_1_1_chunk_sample_ts_idx on _hyper_1_1_chunk s_1
                    Index Cond: ((ts >= w.start_ts) AND (ts < w.end_ts) AND …)
                    Filter: (user_id = '…'::uuid)
```

The join carries **no `metric` predicate**. It pulls every metric's samples inside each
night window — 731 rows per night, 266,912 rows for 365 nights — and only then discards
the ones it does not want, in the four `CASE WHEN s.metric=…` expressions. Three metrics
are wanted (`spo2`, `respiratory_rate`, `skin_temp_c`); on this dataset that is under a
quarter of what is read.

The index note matters too: the per-chunk seek uses the hypertable's **`ts`-only** index
and applies `user_id` as a filter. `sample_user_idx (user_id, metric, ts DESC)` cannot be
used at all, because the predicate never names a metric (see section E).

**What drives it, isolated — and my first answer was wrong.** The hypertable's chunk count
looked like the obvious culprit (`ChunkAppend` re-deciding which chunks to touch on every
one of the outer rows), so it was tested rather than assumed. Three stages, each changing
exactly one variable:

| stage | nights | `sample` rows | chunks | `days=30` | `days=365` |
|---|---|---|---|---|---|
| A — 30 nights, samples on those 30 days | 31 | 83,696 | **5** | 125.0 ms | 127.6 ms |
| B — same nights, samples now span 4 years sparsely | 31 | 152,336 | **209** | 124.8 ms | 123.9 ms |
| C — same sparse samples, now 365 nights | **366** | 152,336 | 209 | 124.4 ms | **1,558.6 ms** |

**A → B multiplies the chunk count by 42 and changes nothing.** Chunk count is not the
driver, and my first reading of the plan was wrong. **B → C multiplies the nights by 12 and
multiplies the time by 12.6.** Nights drive it, and the second multiplier is in-window
sample volume: stage C's 366 nights over *sparse* samples cost 1,559 ms where the same 365
nights over a realistic year of samples cost 16,556 ms.

**The decisive experiment.** Same query, same data, same connection, one added line:

```sql
AND s.metric IN ('spo2','respiratory_rate','skin_temp_c')
```

| variant | best of 3, 365 windows |
|---|---|
| as shipped | 1,530.5 ms |
| plus the metric predicate | **47.5 ms** |

**32× faster, no schema change, no index change, no behaviour change** — the three metric
names are already in the SELECT list two lines above.

The module's own docstring is the thing to correct along with the code. It says the array
form is *"a LATERAL-free join that keeps the per-window index seeks"*. The plan says the
seeks are on the wrong index and read four times the rows they need. That comment is
exactly the class `BACKEND_AUDIT.md` D-b names: a reader who checks it stops looking.

**Recommend:** add the metric predicate. Then re-measure `days=365` — 47.5 ms for the
statement puts the whole endpoint inside budget on the dataset that produced 16.5 s. If it
is still short, the second move is a `sample (user_id, ts)` index (section E), but the
predicate is free and comes first.

### A2 — `/api/today` is measured at 29.8 KB, not the "~20 KB" the standards state, and the biggest single block is one series it also ships on a second endpoint — CONFIRMED

Serialised bytes, all minified unless stated:

| payload | committed snapshot (on disk) | minified | gzip | live at 200 days |
|---|---|---|---|---|
| `today.json` | 40,769 | 25,423 | 6,325 | **29,777** |
| `sleep.json` | 29,129 | 18,494 | 1,505 | 19,802 (`days=30`) |
| `activity.json` | 23,252 | 13,851 | 2,360 | 22,401 |
| `sleep_health_score.json` | 10,913 | 7,628 | 497 | — |
| all 21 snapshots | 137,147 | 86,454 | 16,599 | — |

The doc says `/api/today` is "~20 KB". The committed snapshot is **40,769 bytes as
committed** and **25,423 minified**; the live payload at 200 days of history is
**29,777 bytes** — 49% over the stated figure. It is not runaway, and it compresses well
(6.3 KB gzipped), but the number the standards quote is no longer the number on the wire,
and `MAX_REPORTED_PAIRS`' own sizing argument is written against it.

Where it goes, live at 200 days:

| block | bytes | share |
|---|---|---|
| `vo2max` | 7,467 | 25.0% |
| `sparklines` | 4,154 | 13.9% |
| `biological_age` | 3,703 | 12.4% |
| `today_step_buckets` | 1,921 | 6.4% |
| `metrics` | 1,819 | 6.1% |
| `cardio_load` | 1,324 | 4.4% |
| `top_findings` | 1,278 | 4.3% |
| the other 21 keys | 8,111 | 27.2% |

Two blocks are worth naming:

* **`vo2max.trend_90d` is 6,233 bytes — 21% of the whole Today payload** — a 96-point
  series of `{date, method, value}` objects. It is the single largest thing on the page,
  and section C1 shows `/api/activity` ships the identical array **twice**.
* **`biological_age.caveats` is 2,533 bytes** (of the block's 3,703) — static explanatory
  prose about the FRIEND registry, re-serialised on every request of every day. The
  honesty contract requires it to reach the screen; it does not require it to travel from
  the database on every poll.

**Recommend:** update the standards' figure to the measured one (a stale budget is worse
than a loose one), and fix C1's duplicate, which is the only free byte on the list.

---

## B. Grows silently

### B1 — `/api/activity` is 55.6% one duplicated series, and computes it twice — CONFIRMED

`apps/server/src/healthee/read/activity.py:41-42` calls `vo2max_payload` and
`fitness_plan_payload`; `read/fitness_plan.py:128` calls `vo2max_payload` again, and
`:167` copies its `trend_90d` out.

Measured on the live payload at 200 days:

```
BLOCKS activity wire=22401 minified=22424
   vo2max        7467  33.3%
   fitness_plan  7055  31.5%
   trend_90d in vo2max: 6233 B (96 pts); in fitness_plan: 6233 B (96 pts); identical=True
```

**12,466 of 22,401 bytes — 55.6% of the payload — is one 96-point array shipped twice,
byte for byte.** It also costs the queries twice: 11 of `/api/activity`'s 22 statements
are exact repeats of another statement in the same request, four of them the
`derived_daily … metric=%s … ORDER BY day DESC LIMIT 1` shape `vo2max_payload` issues.

The array grows with `_WINDOW_DAYS = 95`, not with history, so this is bounded — but it is
bounded at twice what it should be, and both copies grow together.

**Recommend:** pass the already-built `vo2max` block into `fitness_plan_payload` instead
of rebuilding it, and let `fitness_plan` reference the trend rather than repeat it. That
is one payload key and one function argument.

### B2 — `persist_findings` writes one row per round-trip: 96 INSERTs per nightly chain — CONFIRMED

`apps/server/src/healthee/analytics/finding.py:96-99`

```python
with tenant_transaction(user_id) as cur:
    for f in findings:
        cur.execute(_INSERT_SQL + _UPSERT_TAIL, _params(user_id, f))
```

Measured: the correlate step produces **96 findings** and issues **96 separate
`INSERT INTO finding` statements**, at every history length from 30 days to 8 years. They
are 96 of the step's 133 statements, and the largest single group of the whole chain's 612.

The standards' rule is quoted exactly at this shape: *"bulk writes use
`executemany`/pipelining (the legacy push once did one round-trip per sample and hit 180 s
timeouts)"*. `ingest/upsert.py` obeys it and says so in its own docstring; this path did
not inherit it. `replace_findings_of_kind` at `:108-112` has the same loop.

It is not a budget breach today — the whole chain is 382 ms and this is a background job,
not a read path — but it is a per-item round-trip in the one place the standards name a
past outage for, and it scales with the number of findings, which scales with the square
of the metric registry.

**Recommend:** `cur.executemany(_INSERT_SQL + _UPSERT_TAIL, [_params(user_id, f) for f in findings])`.
Same transaction, same SQL, one round-trip.

### B3 — the nightly chain's cost is CPU in `correlate`, and it is linear in history and serial in owners — CONFIRMED

`jobs/correlate.py` → `analytics/correlations.compute_all_findings`.

Measured, one owner, clean box, history grown in place:

| history | `derived_daily` rows | statements | DB time | **wall** | findings |
|---|---|---|---|---|---|
| 30 d | 661 | 133 | 15.8 ms | 155.5 ms | 96 |
| 90 d | 1,981 | 133 | 45.4 ms | 203.9 ms | 96 |
| 180 d | 3,961 | 133 | 14.7 ms | 195.4 ms | 96 |
| 365 d | 8,031 | 133 | 14.6 ms | 254.1 ms | 96 |
| 730 d | 16,061 | 133 | 21.0 ms | 354.0 ms | 96 |
| 1,460 d | 32,121 | 133 | 29.5 ms | 581.2 ms | 96 |
| 2,920 d | 64,241 | 133 | 57.6 ms | 1,034.9 ms | 96 |

Three facts, and the third is the one that was never established:

1. **The statement count is a fixed 133 at every history length.** 24 series reads + 5
   event reads + 96 finding INSERTs + the transaction set-ups. No N+1 with history.
2. **The database is not the cost.** 15-58 ms of a 155-1,035 ms wall — **95% of
   `correlate` is Python and scipy**, not SQL. Any attempt to speed it up in SQL would be
   aimed at 5% of it.
3. **The work is `O(metrics² × lags × history)`.** 24 correlated metrics
   (`V2_DAILY_METRICS` 22 + `FLAG_DERIVED_METRICS` 2) give 24×23 ordered pairs; lag 0 is
   halved and lag 1 is not, so **828 Spearman tests**, plus 5 event kinds × 24 metrics × 2
   lags = **240 Mann-Whitney tests** — 1,068 statistical tests per owner per night, each
   over the owner's whole history. Adding one metric to the registry adds ~90 tests.

`analytics/series.daily_series` reads the entire history deliberately and documents why
(*"the correlation engine needs every day it has"*). That read is cheap and measured:
`EXPLAIN` on the 4-year form is an index scan on `derived_daily_user_idx`, **784 buffers,
0.634 ms** for 1,460 rows. The unbounded read is fine; the arithmetic over it is what
grows.

**Owners scale linearly and serially.** `jobs/scheduler.py:133-140` loops `active_users()`
and runs each owner's chain in-process, back to back, in one tick. At the measured 382 ms
per free owner, 100 owners is ~38 s of one tick; at 8 years of history each, ~2 minutes.
That is fine and worth writing down before someone assumes it is parallel.

**One measurement disagreed with another and I am recording both.** The same curve taken
inside the long scaling run read 220 / 226 / 371 / 832 / 2,475 / **9,200 ms** — superlinear
and 15× the clean figure at 1,460 days. That run had just executed eight consecutive
16.5-second `/api/sleep` queries (finding A1) on the same box, and its own DB time stayed
at 85 ms, so the extra wall was contention, not correlate. The table above is the clean
instrument. I state the discrepancy rather than dropping it, because a number taken on a
saturated box is exactly the kind of measurement that later reads as a regression.

**Recommend:** nothing urgent. Record the shape in the module docstring — 1,068 tests,
linear in history, quadratic in the metric registry — so the next metric added is a
priced decision rather than a surprise.

### B4 — three endpoints take a client-supplied bound and never clamp it — CONFIRMED

The standards: *"Unbounded data is windowed — every list endpoint paginates; every chart
query has a range."* Where a bound is clamped, it is clamped in the read layer, and the
pattern is good — it just is not everywhere.

| endpoint | client parameter | clamped? | where |
|---|---|---|---|
| `/api/history` | `days` | **yes**, 1-1825 | router, `Query(ge=1, le=1825)` |
| `/api/history` | `metrics` | **yes**, `MAX_METRIC_LIST` | `api/validation.py` |
| `/api/sleep` | `days` | **yes**, 1-365 | `read/sleep_page.py:30` |
| `/api/sleep/health_score` | `days` | **yes**, 1-365 | same `_clamp_days` |
| `/api/sleep/consistency` | `days` | **yes**, 7-90 | `read/sleep_extras.py:229` |
| `/api/workout/gps` | `limit` | **yes**, 1-100 | `read/gps.py:90` |
| `/api/recommendations` | `days`, `offset` | **yes** | router `Query(...)` |
| **`/api/challenges/outcomes`** | `limit` | **no** | `challenges/ledger.py:302` — reaches `LIMIT %s` raw |
| **`/api/log/recent`** | `days` | **no** | `read/logs.py:171` — reaches an `interval` raw |
| **`/api/workout/gps/{id}`** | — | **no read-side bound** | `derive/gps.py:113-123` returns every point |

The first two are small: `log_recent` still has a hard `LIMIT 80` on rows, so a huge
`days` widens the scan without widening the answer; `outcomes` is bounded by how many
frozen outcomes the owner has. Both are one `max(1, min(x, N))` from matching
`list_gps_tracks`, which does exactly that eight lines away.

The third is the real one. `gps_track_detail` selects **every** `gps_point` of a track and
ships every one with an interpolated HR and a per-segment pace. The only bound anywhere is
at ingest: `read/gps_request.py:15` caps a submitted track at `max_length=28800` points
(8 h at 1 Hz). So a maximal track is ~28,800 objects on a **p95 < 100 ms read endpoint**.
The contract snapshot's 21-point track is 3,177 bytes; the byte figure at the cap is
**SUSPECTED** — I did not synthesise a 28,800-point track — but the absence of any
read-side bound is CONFIRMED from the query.

**Recommend:** clamp `outcomes.limit` and `log_recent.days` the way `list_gps_tracks`
already clamps. For the GPS detail, either paginate or decimate for the map view (the
route map cannot draw 28,800 separable points any more than the finding scatter can draw
1,100 — the argument `MAX_REPORTED_PAIRS` already makes, applied to the other series).

---

## C. Waste, measured, with no budget consequence yet

### C1 — half of `/api/activity`'s statements are exact repeats of another in the same request — CONFIRMED

Counting identical SQL text within a single request. Not every repeat is waste — six of
Today's are the data-health probes, which are a measured and argued trade (D3) — so the
column that matters is the last one:

| endpoint | statements | exact repeats | of those, deliberate | unexplained |
|---|---|---|---|---|
| `/api/today` | 49 | 10 | 6 (the D3 probes) + 2 transaction set-ups | **2** — the illness row and the MVPA flags, each read twice |
| `/api/activity` | 22 | 11 | 0 | **11** — B1's doubled `vo2max_payload` |
| `/api/entitlement` | 9 | 5 | 0 | **5** — the same `subscription` row 3×, in 4 transactions |
| `/api/challenges` | 13 | 7 | 1 transaction set-up | **6** |
| `/api/programs` | 12 | 4 | 1 transaction set-up | **3** |
| `/api/sleep` | 11 | 1 | 0 | **1** |

`/api/entitlement` is the sharp one: **9 statements and 4 separate transactions for a
263-byte payload**, reading one `subscription` row three times. It is the paywall meter the
app polls; at 9.2 ms p50 it is nowhere near budget, but it is 9 round-trips for one row.

On `/api/today` two of the repeats are a genuine double-read of the same value: the illness
row is fetched by `illness_flag_payload` and again by `active_illness_severity`
(`read/health_metrics.py:222` and `:230`, both calling `_latest_active_illness` with the
same anchor, in the same transaction), and the MVPA flags query runs twice.

**Recommend:** thread the illness row through `TodayReads` the way the latest-value and
baseline reads already are — the mechanism exists, these two call sites simply do not use
it. Give `/api/entitlement` one transaction and one read.

### C2 — the `/api/today` query-count ratchet has one statement of headroom — CONFIRMED

`apps/server/tests/contracts/test_perf.py:_MAX_TODAY_QUERIES = 50`, asserted as
`counter["n"] < 50`. Measured today: **49**.

The guard works and its comment is honest about why it moved from 45 to 50. But at 49 of
50, the next block added to Today fails a test whose message says "N+1?" when the truth
will be "the aggregator grew by one honest query". A ratchet with one notch left teaches
the next author to raise it rather than to think about it.

**Recommend:** nothing to fix; note the headroom in the constant's comment so the next
raise is a decision rather than a reflex.

### C3 — the vendored font total in `pubspec.yaml` is stated as ~1.1 MB and measures 463 KB — CONFIRMED

`apps/mobile/pubspec.yaml`: *"Figtree, vendored rather than fetched … ~1.1 MB total."*
Measured: `Figtree.ttf` 62,712 B + `InterFallback.ttf` 411,640 B = **474,352 B (463 KiB)**
of typeface, 483,120 B (472 KiB) with the two licence files. The comment predates the
Manrope → Figtree/Inter swap. Harmless in itself, and it is the kind of number a
cold-start argument gets built on.

---

## D. Within budget — measured, and reported because a met budget is a result

### D1 — statement counts do not grow with history, on ANY endpoint — CONFIRMED, and this is the headline good news

The read layer's batching claim was the thing `BACKEND_AUDIT.md` called "credible" without
measuring. It holds. Same 17 endpoints, 30 days of history versus 400 days (1.06 M
samples, 8,801 derived rows, 401 nights):

| endpoint | stmts @30d | stmts @400d | p50 @30d | p50 @400d | bytes @30d | bytes @400d |
|---|---|---|---|---|---|---|
| today | 49 | **49** | 10.9 ms | 20.1 ms | 25,392 | 32,186 |
| activity | 22 | **22** | 18.5 ms | 18.5 ms | 13,821 | 39,231 |
| sleep (`days=30`) | 11 | **11** | 8.0 ms | 10.6 ms | 17,709 | 19,744 |
| challenges | 13 | **13** | 14.6 ms | 3.3 ms | 4,414 | 4,414 |
| programs | 12 | **12** | 13.8 ms | 3.1 ms | 4,828 | 4,828 |
| entitlement | 9 | **9** | 10.7 ms | 9.2 ms | 263 | 263 |
| sleep_consistency | 8 | **8** | 10.9 ms | 10.4 ms | 427 | 428 |
| workout | 7 | **7** | 12.2 ms | 2.5 ms | 1,431 | 1,431 |
| gps_detail | 6 | **6** | 2.5 ms | 2.3 ms | 1,911 | 1,879 |
| log_recent | 5 | **5** | 8.5 ms | 9.1 ms | 417 | 1,698 |
| history_batch | 5 | **5** | 9.5 ms | 3.7 ms | 2,203 | 2,355 |
| challenge_outcomes | 5 | **5** | 9.4 ms | 2.0 ms | 2,242 | 2,242 |
| profile | 4 | **4** | 1.9 ms | 7.7 ms | 175 | 175 |
| history | 3 | **3** | 7.6 ms | 7.5 ms | 1,115 | 1,115 |
| sleep_health_score | 3 | **3** | 11.8 ms | 2.9 ms | 7,628 | 7,628 |
| gps_list | 3 | **3** | 7.4 ms | 1.7 ms | 250 | 250 |
| map | 1 | **1** | 6.0 ms | 1.2 ms | 115 | 115 |

**Not one endpoint issued a single extra statement for 13× the data.** `/api/history` costs
**3 statements whether `days` is 30 or 3,650**, and the batched form costs **5 for three
metrics** — including one metric carried inside another's `flags` and one that comes from
`weight_log`. The batched-history work's claim that a multi-metric read is a small fixed
number of queries rather than one per metric is checkable, and it checks out.

**Sixteen of seventeen endpoints are inside the p95 < 100 ms budget at 400 days of
history** — the highest p95 among them is `/api/today` at 30.9 ms. The exception is A1's
`/api/sleep`, whose p95 was 118.7 ms in its default form and 15,508.7 ms at `days=365`.

Payload growth is bounded by window length, not by history: `/api/activity` settles at
~39 KB once its 90-day series fill, `/api/today` at ~32 KB, and neither moves after.

### D2 — no endpoint borrows a second connection — CONFIRMED

The pool-of-one fixture from `test_perf.py` (which makes a nested borrow a deterministic
`PoolTimeout` rather than a concurrency race), applied to **every** read endpoint rather
than the two it covers:

```
today 200 · sleep 200 · sleep_health_score 200 · sleep_consistency 200 · activity 200
history 200 · history_batch 200 · profile 200 · entitlement 200 · log_recent 200
map 200 · gps_list 200 · challenges 200 · challenge_outcomes 200 · programs 200
log_post 200 · workout 200 · gps_detail 200
```

All 18 served on a one-connection pool. The self-deadlock class `test_perf.py` was written
for exists nowhere else in the read layer. *(Several endpoints do open more than one
sequential transaction on that one connection — `/api/entitlement` four, `/api/today`
three — which is C1's waste, not this failure.)*

### D3 — the data-health probes cost what their comment claims — CONFIRMED

`read/data_health.py:41-66` argues, at length, that six targeted probes beat one grouped
scan by ~580×, at 3 buffers each. Verified independently on 1.06 M samples across 209
chunks:

```
last_seen_probe: Index Only Scan … Heap Fetches: 0   Buffers: shared hit=3
                 every older chunk "never executed"
max_ts:          Result → InitPlan → Limit … Buffers: shared hit=3
```

Three buffers each, exactly as documented, and the min/max index rewrite on the bare
`max(ts)` is confirmed too. This is the one place in the repo where a performance claim was
already written down with numbers, and the numbers are right.

### D4 — ingest push, one ordinary day: 208 ms against a 5 s budget — CONFIRMED

A realistic single-day push — 2,640 samples, one staged night, one workout, the daily
totals — as a 148,981-byte `POST /ingest/helio`, on 180 days of prior history:

```
status 200 · samples_accepted 2640 · sleep 1 · workouts 1 · daily_totals 1 · days_derived 3
wall 208.0 ms · 168 statements · 48.1 ms in the database
```

**24× inside the < 5 s budget**, and that includes the derive chain the push triggers (3
days re-derived). The `executemany` path holds: 2,640 samples cost a handful of statements,
not 2,640. The most expensive statements are the two
`generate_series … INSERT INTO sample` calls that materialise the hypnogram's per-minute
stream, at 3.9 ms and 3.8 ms.

### D5 — the nightly chain's deterministic half: 382 ms — CONFIRMED

`chain.run_chain` for a free owner at 180 days of history:

```
wall 381.5 ms · 612 statements · 56.7 ms in the database
illness ok · challenges ok · correlate ok · recs skipped · warm skipped · briefing skipped
```

The three skipped steps are the LLM ones, correctly gated off for a non-premium owner
(6.6a). The LLM budget — *"pre-warmed/cached per day; generation never blocks a sync or a
read path"* — is structurally satisfied on the read side and was verified by reading rather
than by calling a model: `insights/coaching.cached_line` is cache-only, and the read
routers reach it and never the client. Cost and latency of the generation itself are out of
scope here and priced in `PRICING.md`.

### D6 — the mobile app's parse and build costs, in the test host — CONFIRMED (host, not device)

| measurement | value |
|---|---|
| `today.json` | 40,769 B on disk, 40,734 characters decoded |
| `jsonDecode` of it | **255.7 µs** per call |
| `TodaySnapshot.fromJson` on the decoded map | **77.4 µs** per call |
| decode + parse together | **254.7 µs** per call |
| `TodayScreen` first frame, warm process | **20.7 ms** |
| `TodayScreen` pumped to settled | **53.4 ms** |
| whole routed app, first frame | **68.4 ms** |
| whole routed app, settled | **94.3 ms** |
| steady-state `pump` | **57-89 µs** per frame |

A quarter of a millisecond to turn the wire into typed models. The standards' rule about
`compute()` isolates for heavy parsing is not needed here and the numbers say so — this
payload is nowhere near an isolate's own overhead.

The first `pumpWidget` in a cold test process measured 182.9 ms against 20.7 ms for the
second in the same process; the ~162 ms difference is Flutter's own binding warm-up in the
test host, not app code. That distinction is why the warm number is the one quoted.

### D7 — `ListView.builder` really does recycle on Today, and nothing synchronous sits on the startup path — CONFIRMED

Widget count in the live element tree, same screen:

| state | widgets |
|---|---|
| settled, before scrolling | 692 |
| mid-scroll | 1,124 |
| scrolled to the bottom | **768** |

The count comes back down — off-screen children are disposed, which is the property the
standards' `ListView.builder` rule and `feedback_scroll_reveal_once` exist for. A screen
building all its cards would only ever grow.

The cold-start path is clean by inspection, and every candidate was checked:

* `main.dart` does exactly two things before `runApp`. `registerAssetLicences()` hands
  `LicenseRegistry` a stream *builder*; `rootBundle.loadString` runs only when someone
  opens the licence page.
* `data/store/connection.dart` wraps the database in a `LazyDatabase`, so
  `getApplicationSupportDirectory()` and the Drift schema-5 migration are deferred past
  the first frame — and the file says that is why.
* A sweep of `lib/` for `readAsStringSync`, `readAsBytesSync`, `existsSync` and
  `rootBundle` finds **no synchronous file read anywhere in the app**. Every hit in the
  repo is under `test/`, where reading the committed snapshot from disk is the point.
* There is no large bundled JSON: `assets/` is four files, all fonts and licences.

**Tab switching keeps every branch alive, by design.** Widget count across a full circuit:
1,088 (Today) → 1,599 (Sleep) → 2,122 (Activity) → 2,471 (Insights) → 3,009 (Actions) →
3,067 (back to Today). `StatefulShellRoute.indexedStack` holds all five, which is what
preserves scroll offset and chart reveals (`core/router.dart` argues it). It is bounded at
five branches and the memory is the price of the behaviour — recorded so nobody later reads
the growth as a leak.

---

## E. Index coverage for the hot predicates

Read off `db/schema.sql` against the predicates the read layer actually issues.

| hot predicate | index | verdict |
|---|---|---|
| `sample WHERE user_id AND metric ORDER BY ts DESC LIMIT 1` | `sample_user_idx (user_id, metric, ts DESC)` | **covered** — index-only, 3 buffers, 0 heap fetches (D3) |
| `sample WHERE user_id` → `max(ts)` | ditto, via the min/max rewrite | **covered** — 3 buffers |
| `sample WHERE user_id AND metric AND ts BETWEEN …` (the intraday series, `derive/`) | ditto | **covered** |
| **`sample WHERE user_id AND ts BETWEEN … `, no metric** | **none** | **NOT covered** — falls to the chunk's `ts`-only index with `user_id` as a filter (A1) |
| `derived_daily WHERE user_id AND metric [AND day …]` | `derived_daily_user_idx (user_id, metric, day DESC)` | **covered** — 784 buffers / 0.63 ms for a 4-year whole-metric read |
| `derived_daily WHERE user_id AND metric = ANY(...) AND day <= …` (`DISTINCT ON`) | ditto | **covered** |
| `sleep_session WHERE user_id AND kind ORDER BY start_ts DESC` | `sleep_session_user_idx (user_id, start_ts DESC)` | **covered** (`kind` filtered, low cardinality) |
| `workout WHERE user_id AND start_ts …` | `workout_user_idx (user_id, start_ts DESC)` | **covered** |
| `manual_entry WHERE user_id AND kind AND ts …` | `manual_entry_user_idx (user_id, ts DESC)` | **covered** for the range; `kind` filtered |
| `weight_log WHERE user_id ORDER BY ts DESC LIMIT 1` | `weight_log_user_idx (user_id, ts DESC)` | **covered** |
| `illness_flag`, `recommendation`, `finding`, `challenge`, `program`, `challenge_outcome`, `gps_track`, `kv` | each has a `(user_id, …)` index | **covered** |

**One gap, and it is A1's gap.** Every owner-scoped query in the repo names a metric except
the night-physiology join, and that is the one that is slow. Two indexes exist on `sample`
beyond the primary key, and neither begins `(user_id, ts)`.

The gap is worth closing **only if** the metric predicate (A1) does not close it first. The
predicate is free; an index on a 500 k-row-per-year hypertable is not, and adding one to
paper over a missing `WHERE` clause would be the expensive fix to the cheap problem.

---

## F. Could not measure, and why

Stated rather than estimated, per this audit's own rule.

1. **App cold start → first meaningful paint (< 2 s).** Needs a real device; this audit is
   forbidden from touching the owner's phone, and a test-host `pumpWidget` is not a cold
   start — it skips process spawn, Dart VM start, engine init, plugin registration, the
   platform channel round-trips and the first raster. What D6/D7 establish is that the
   *app's own* pre-paint work is small and non-blocking; what remains unmeasured is
   everything the OS and engine do around it.
2. **60 fps on tab switch and scroll.** Same reason. A headless test binding has no
   rasteriser and no vsync, so its 57-89 µs `pump` is a rebuild cost, not a frame time.
   The halo is also disabled under `reducedMotion` in every fixture that pumps Today, and
   it is the one thing on that screen that runs a ticker.
3. **Full incremental BLE sync (< 30 s).** Needs a strap and a radio.
4. **p95 under concurrency, on production hardware.** Every latency here is a single
   sequential caller against a local container. p95 as the standards mean it — many
   clients, the real VPS, a warm-but-shared buffer cache — is a load test, and a load test
   against the production database is exactly what this audit may not run. Read the
   latencies as a **lower bound**: the ordering and the scaling shapes hold; the absolute
   numbers on prod will be worse.
5. **LLM endpoint cost and latency.** No key was used and no model was called. The half of
   that budget which is structural — *"generation never blocks a sync or a read path"* —
   was verified by reading the read routers and `insights/coaching.cached_line`; the other
   half is `PRICING.md`'s territory and was measured there.

One thing inside the audit's reach was measured twice and disagreed with itself: the
`correlate` curve (B3). Both readings are printed there, with the reason the slow one is
the contaminated one.

---

## G. What to do first

Ordered by measured benefit per line of diff.

1. **A1's metric predicate.** One line in `read/sleep_page.py`. 1,530 ms → 47.5 ms,
   measured. It takes the only endpoint that blows a budget back inside it, and it fixes
   the default 30-night call too.
2. **B1's duplicate `trend_90d`.** One argument and one key. Removes 6,233 bytes — 28% —
   from `/api/activity`, and stops `vo2max_payload` running twice per request.
3. **B2's `executemany`.** One line in `analytics/finding.py`. 96 round-trips → 1.
4. **B4's two missing clamps.** `max(1, min(x, N))`, twice, copied from `list_gps_tracks`
   eight lines away. Then decide what the GPS detail endpoint does about 28,800 points.
5. **Correct the two stale numbers**: the standards' "~20 KB" for `/api/today` (measured
   29.8 KB) and `_apply_physiology`'s claim that it "keeps the per-window index seeks"
   (the plan says otherwise). A wrong number in a standards doc is a budget nobody is
   actually held to.

None of these is a redesign. The read layer's architecture came through this audit intact:
the batching is real, the round-trips are bounded, the connection discipline is clean, and
the one endpoint that is slow is slow for a reason that fits on one line.

---

## H. Addendum — what the fixes measured (2026-09-09, `feat/perf-fixes`)

Nothing above was edited. Every number in sections A-G is the reading that was taken
then, and this section is what happened when each recommendation was carried out and
re-measured on the same rig. Where a prediction did not hold, the prediction is left
standing above and the disagreement is explained here — a prediction quietly overwritten
by its outcome is a record nobody can audit.

| finding | before | after |
|---|---|---|
| A1 `/api/sleep?days=365` p50 | 15,363.0 ms | **92.0 ms** |
| A1 the physiology statement | 15,316.1 ms | 84.4 ms (all 11 statements) |
| A1 `/api/sleep?days=30` p50 | 11.3 ms | 8.2 ms |
| B1 `/api/activity` wire bytes | 22,823 | **16,611** (−27.2%) |
| B1 `/api/activity` statements | 22 | 19 |
| B2 `persist_findings` INSERT round-trips | 774 | **1** |
| B3 `correlate` wall, 1,460 days | 623.0 ms | **422.1 ms** (−32%) |
| B3 `correlate` wall, 365 days | 288.4 ms | 239.7 ms (−17%) |
| B4 `/api/workout/gps/{id}` wire bytes at the ingest cap | 2,282,548 | **158,913** (14.4×) |
| B4 `/api/workout/gps/{id}` p50 at the ingest cap | 144.9 ms | 148.5 ms (unchanged) |

Measured on 366 nights / 988,211 samples / 8,031 `derived_daily` rows, throwaway
container, app running as the least-privilege role with RLS live.

### A1's 32× did not reproduce, and finding out why found a second defect

Section A1's decisive experiment measured the metric predicate at 1,530.5 ms → 47.5 ms.
Adding that predicate to the shipped code gave **15,363.0 → 1,517.1 ms** — a tenth of the
predicted improvement, and still 15× over budget. The predicate was not wrong; it was
half of the problem.

Twenty consecutive `days=365` calls, predicate in place:

```
calls  1-10     83 -  90 ms      custom plan
calls 11-20   1506 -1530 ms      generic plan
```

psycopg PREPAREs a statement after `prepare_threshold` (5) executions on a pooled
connection, and PostgreSQL's `plan_cache_mode = auto` then promotes it to a **generic
plan** — one built without the parameter values. This query cannot survive that: the
planner has to see the `unnest` arrays to know there are 365 windows and to prune the
hypertable's chunks against the outer `ts` bound. `force_custom_plan` held all twenty
calls at 82-127 ms; `force_generic_plan` held all twenty at 1,503-1,559 ms.

**That reconciles the audit's own two readings.** 47.5 ms was measured on a fresh cursor
(a custom plan) and 16,556 ms through a warm pool (a generic one). Both were honest
readings of the same statement, and the difference between them was never the predicate.
The fix is the predicate *and* `prepare=False`; the predicate is still worth having on
its own, because it cuts the statement's buffer reads 133,193 → 5,476 (24×) whichever
plan PostgreSQL picks.

### Section E's index gap does not need closing — measured, not reasoned

Section E said the `sample (user_id, ts)` gap was worth closing "**only if** the metric
predicate does not close it first". It was built and measured, with and without the
predicate, on the app role with RLS live: **the plan, the buffer counts and the times
were identical to three significant figures in every combination**, at 27 MB per year of
samples. No migration was written.

### B4's byte figure is confirmed; its latency is not fixed

The 28,800-point track was synthesised, so the SUSPECTED byte figure is now CONFIRMED at
2,282,548 bytes. Thinning the map's points to 2,000 (`RouteMap.maxDrawnPoints`, the app's
own constant — it was already discarding ~26,800 of the points it downloaded) takes that
to 158,913. **The latency does not move and the endpoint is still outside p95 < 100 ms at
that cap.** Serialising was never the cost: loading 28,800 rows, a DEM lookup per point,
an interpolated heart rate per point and a segment walk for pace all happen before
anything can thin the result. Moving the bound into `_load_points` would fix it and was
refused: every summary figure is computed over the points that were loaded, so a strided
load would silently change the distance, moving time, pace and elevation the endpoint
reports — a science change, which `CLAUDE.md` requires be its own PR.

Bounding that array also reached the app, which is the part worth remembering. It printed
`Phone GPS · ${route.points.length} fixes` and counted matched heart-rate points off the
same array — correct only while the array was the whole track. Left alone, the
performance fix would have described a 28,800-fix run to the person who made it as a
2,000-fix one. The summary now carries `n_hr_points` beside `n_points` (both over every
fix) plus `points_returned` and `points_decimated`, and the app reads its counts from
there.

### C1's repeat count, re-measured

B1's fix removed the doubled `vo2max_payload`. **One same-arguments repeat remains** on
`/api/activity` and was left: `weekly_mvpa_rows` is read by both `mvpa_payload` (a fixed
8-day window) and `fitness_plan._week_to_date_mvpa` (week to date), whose windows differ
on six days in seven and coincide on the seventh. Folding them means deciding which
module owns the week's moderate/vigorous split — a definition question, not a performance
one. C1's other entries (`/api/entitlement`'s four transactions, `/api/today`'s illness
double-read) were not in this job's worklist and are untouched.

### B3: what was taken, and what was refused

Profiling `correlate` found the largest single cost is not a statistical kernel:
`stats.aligned_pairs` was **0.464 s of the step's 1.044 s at four years — 44%, more than
all of scipy together**. Two loop-invariants came out of its body (a `timedelta`
constructed on every one of ~1.2 million iterations, and a double dict probe), and
`notes_for` is memoised. 774 findings before and after.

The statistics are untouched: no test dropped, no threshold moved, no sampling, no
approximation. `tests/analytics/test_aligned_pairs_equivalence.py` holds the pre-change
loop verbatim and asserts the two agree element for element and in order across lags,
densities, disjoint and empty series, and a legitimate `0.0`. Nothing moved into SQL
(31-44 ms of a 240-422 ms wall is the database) and the owner sweep stays serial. The
`O(metrics² × lags × history)` shape is now in `correlations.py`'s module docstring with
the measured table, so the next metric added is a priced decision — about 90 more tests.
