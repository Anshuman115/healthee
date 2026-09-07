# Backend gaps, read off the UI we actually show

The owner: *"give me the full gap report backend vs ui"*.

Every item was found by taking a built screen and asking what it needs from the
API, then checking the answer against the server source. File and line are given
so each can be confirmed. Nothing here is speculative.

**The design is complete and installed.** So this is no longer a list of things
blocking the build — it is the list of places where the API is thinner than the
screens, ranked by whether it can mislead the owner.

---

## 0. The shape of it

| | |
|---|---|
| Endpoints the server exposes | 41 |
| Endpoints the app calls | 25 |
| Exposed but never called | `/api/sleep/health_score`, `/api/today/action`, the challenge/program/recommendation mutation routes the app reaches by other means, `/device`, `/me`, `/healthz`, `/readyz` |
| Screens blocked on missing data | **0** |
| Gaps that can put a wrong number on screen | **0** — all four of section A are CLOSED |

---

## A. Correctness — these can put a wrong or unqualified number on screen

**All four are CLOSED.** What each was, and what closing it turned out to need:

**A1. `naps[].stages` was structurally always empty** — `read/sleep_page.py`
shipped the raw hypnogram JSONB under the key a *night* uses for per-stage minute
TOTALS, so a client reading totals got an array it could make nothing of and
every nap bar rendered blank. The typed minute columns were on the row the whole
time and were not selected. A nap now shapes through `stage_totals` and
`stage_timeline` — the same two helpers a night uses, because a second shaping of
one thing is how the two drift.

**A2. `rhr_daily` shipped with no date and no freshness gate** — CLOSED, and it
was never only RHR: `_derived_card` unpacked `latest_derived` as `_day, value,
flags` and threw the date away for **every** metric in the Today row. The card
carries `as_of_date` always, and past `freshness.unavailable_reason` its `value`
goes null behind a `withheld` block carrying the last reading.

> **`read/fitness.py::activity_metric` needed the same gate**, and that was found
> by a test rather than by reading. The Activity tab dated its value and served it
> anyway while the Today card did neither — half the contract on each side, which
> is how a stale number moves one tab across instead of disappearing. Two surfaces
> render the same row and now answer "is this current" with the same function.

**A3. `anomalies` was `[]` unconditionally** — it is `null` now, with an
`anomalies_withheld` block naming the reason and pointing at `/api/notable`.
Serving the shifts from `/api/today` instead was considered and refused, on two
grounds recorded at the site: `analytics.anomalies.detect` anchors its window on
`USER_TODAY_SQL` and opens a transaction per metric, so it would be a future leak
on any past day *and* a per-metric connection fan-out on the request path; and
`/api/notable` already owns the question, deduped and with a grounded meaning per
shift, so a second scan would be a second definition of "notable for this owner".

**A4. Three read modules emitted note *aliases*, not ids** — fixed, and the sweep
found **two more the report had not**: `read/recovery.py` shipped
`resting_hr_health_marker` and `hrv_recovery_marker`, aliases of
`resting_heart_rate` and `heart_rate_variability`. Five sites, not three.

> The durable half is the guard, not the rename.
> `tests/read/test_wire_honesty.py::test_every_note_id_on_the_wire_resolves_to_a_manifest_id`
> walks `/api/today`, `/api/activity` and `/api/sleep`, collects every note
> reference under any of the six keys the read layer files them under, and fails
> on anything that is not a manifest id. It is the wire counterpart of
> `tests/test_source_citations.py`, which holds the same rule for `[[id]]`
> citations in source — and which says why an alias must not count: nothing that
> consumes a cited id reads the alias list, so an alias resolves to nothing *in
> the behaviour that matters* and the explainer sheet opens blank.

---

## B. Thin — the screen works, but shows less than it should

**B1, B2, B3, B4 and B6 are CLOSED. B5 stands**, and is left as it is because the
Sleep page's shortfall is already honest about what it counts.

**B1. Findings carried summary statistics only — no paired values.** — **CLOSED.**

Each pairwise finding now travels with `points: [{date, a, b}]`, `points_n` and
`points_truncated`. They are not reconstructed at read time: `stats.aligned_pairs`
is the pairing loop lifted out of `spearman_lag` itself, so the scatter cannot
show a different set of days than the number above it was computed from, and
`correlations._attach_pairs` records them in `details` — the JSONB column that
already carried an event finding's group sizes and that `_SELECT_KEYS` never read.

Bounded three ways, because `daily_series` reads the owner's **entire** history:
attached only after significance is marked and only to findings that survive it;
capped at `MAX_REPORTED_PAIRS` keeping the most recent; and re-bounded by the
reference day at read time rather than inheriting the finding's own `computed_at`
gate — relying on another place's bound is how "latest" leaks. When the served set
is partial the payload says so, because a scatter silently showing fewer points
than its own `n_samples` invites a check it cannot support.

> **The cap is 90 and it is argued against the surface, not chosen.** The scatter
> is ~320 px wide with a 3 px dot radius, so the x-axis holds roughly 50 separable
> columns; at 90 points the cloud is already ~2 dots per column, and denser is a
> smear. At ~39 bytes a pair that bounds the worst case at ~18 KB on a Today
> payload this report measures at ~20 KB — the first draft used 180, which would
> have doubled the payload to draw detail nobody can see.

Event findings get no points, deliberately: a Mann-Whitney effect compares two
groups, so an x-axis for it would be a chart the statistic does not license.

**B2. VO₂max history carried no per-point method.** — **CLOSED.** `trend_90d` and
`submax.trend` both name their instrument per point. The two default an undated
row *differently* on purpose — a `vo2max_estimate` row without a method predates
#117 and is Jurca, a `vo2max_submax` row without one predates #114 and is a graded
fit — so one shared default would mislabel one of the two series.

**B3. `weekly_mvpa_min` was hardcoded `None`.** — **CLOSED**, and not by a second
sum. The summing moved to `read/mvpa_week.py` and both surfaces read it, because
`read/fitness.py` imports `read/vo2max.py` and the arrow only points one way. Null
survives only where there is genuinely nothing to sum — never `0`, which would
read as a measured week of stillness.

**B4. No σ anywhere on `/api/today`.** — **CLOSED.** The three recovery signals
ship `baseline_sd`, the exact divisor their own `z` was computed with (including
the sleep signal's *floored* form — the unfloored MAD would not reproduce its z),
and the secondary cards ship `sd_30d` alongside `median_30d` for the same reason.

**B5. `/api/sleep` sends no need and no debt.** Those live in Today's block, so
Sleep computes a shortfall over measured nights and honestly labels the stat
`Nights counted`, never `Modelled nights`.

**B6. `/api/activity/workout` was the only payload with NO honesty envelope.** —
**CLOSED.** `metrics_withheld` is `{metric: {reason, message}}` for every derived
figure the session could not carry, built in `read/workout_absence.py` for exactly
the keys `_metrics` did not produce.

The gain over the client-side reconstruction is the one the app's own docstring
named: **the server can see which input was missing.** A session TRIMP needs an
HRmax, a resting heart rate, the owner's sex and heart-rate samples, and the
middle two are not on that payload at all — so `workout_readings.dart` could only
list all four and hope. The server names the one that failed.

No remedy is invented, and that is a rule rather than an omission: `withheld_block`
earns its second-person "do this and it comes back" for a stale weight, but a
treadmill run recorded no distance and never will, so each message states the
precondition and stops. `zones` is keyed here too — an all-zero zone list is a
real reading about an easy session when an HRmax exists and a structural blank
when one does not, and only the server can tell those apart.

---

## C. Structural — the shape of the API against the shape of the screens

**C1. `/api/history` serves ONE metric, windowed from today.** — **CLOSED.**

`?metrics=a,b,c` answers `{days, series: {metric: […]}}`; `?metric=` is
unchanged and its snapshot proves it. Both forms are shaped from
`read/history.py::history_series`, so there is one definition of a day's value,
and the plain `derived_daily` metrics are read in ONE statement — naming the
whole registry costs four queries, not twenty-five. An unknown id refuses the
whole call rather than being dropped from the answer. Snapshot:
`packages/contracts/snapshots/history_batch.json`.

**Still no `end=` date, and none is needed** — a client asking for enough
`days` and slicing at the chosen date is what both the metric screen and the
dated panels do.

The report as it stood:

Two consequences, and they are the biggest items in this report:

- **The metric explorer needs 20 calls for one screen**, so it stays
  latest-only with the day named in the header. *(Still true: the explorer has
  not been moved onto the batched read. It now could be, off the same cached
  provider the panels use.)*
- **A past day cannot show the prototype's dated history panels.** — **CLOSED.**
  All six screens draw them, windowed on the day chosen. *(A client can already
  slice — asking for enough `days` and cutting at the chosen date works — so
  this was a call-count problem, not a windowing one.)*

**C2. `/api/today` and `/api/activity` take no parameters at all**
(`api/routers/today.py:30`, `api/routers/activity.py:15`); `/api/sleep` takes a
window, not a target day. So on a past day the **measured** half can be shown
and the **derived** half cannot.

The client now handles this correctly — the day rides in the route, thirteen
paths re-window or refuse, and nothing relabels today's judgements with an older
date. **The refusal is the right behaviour until the server can answer for a
day**, and making it answer is a much larger job than C1.

**C3. Metric coverage does not reconcile.** — **CLOSED.** Both sides now list
**25**: `HistoryMetric` gained `spo2_overnight_min` and the four sleep-health
dimensions, which is the whole of `KNOWN_METRICS`.

The four dimensions were also **renamed**. They are 0-or-1 points — did the
night clear that dimension's published cutoff — and three of them carried the
name of the quantity instead, so `sleep_dim_efficiency` and `efficiency_pct`
were both "sleep efficiency" and a chart of ones and zeroes would have sat
under a heading the owner reads as a percentage. They end in "check" now.

The report as it stood:

- Server `V2_DAILY_METRICS` — **22**
- App `HistoryMetric` — **20**
- Prototype's explorer — **25**

The prototype's five extras — HR, stress, sleep duration, sleep efficiency, skin
temperature — have **no daily series on this server**, so a tile for them would
be a door onto a 422.

**C4. `/api/coach` takes only `messages`** (`api/routers/coach.py:53`) — no
topic, no context id. The coach is now reached from five surfaces, two of them
about something specific. The client seeds the opening message, so nothing is
blocked, but the server never learns what the question is *about*.

---

## D. Checked, and better than expected — not gaps

- **Biological age is fully served**: `contributions[]` with `term`,
  `delta_years`, `hr`, `value`, `unit`, `target`, `compared_as`, `method`, plus
  `excluded` and `caveats`.
- **Recovery's per-factor breakdown is served** — sub-score, weight, value,
  baseline.
- **VO₂max names its own instrument**: `method`, `method_caveat`,
  `measured_as_of`, `n_sessions`, `see_source`, `see_ml_kg_min`,
  `median_for_age`, `delta_from_median`, and a `submax` block with `last_r2` and
  `last_speed_kmh`.

*(An earlier revision of this file claimed the app "already parses every field".
It did not: `compared_as` and the whole `submax` block were on the wire and
missing from the Dart models. Both were added when those screens were built. The
gap was never the server's.)*

---

## E. Client-side, still open

- ~~**Five daily metrics unlisted**~~ — closed, see C3.
- **47 unreachable files** in `lib/`, the pre-v02 widget set and chart library
  the redesign superseded. Dead weight that misleads every future grep.
- **GPS recording keeps no track.** `GpsRecordingState` holds a fix *count* and
  a distance, not coordinates, so the recording screen cannot draw a route. This
  is the client's own gap, not the server's — `/api/workout/gps` accepts a
  track.

---

## F. What the three outstanding requests need

| request | needs | where |
|---|---|---|
| ~~**Dated history on past days**~~ | ~~the batched history endpoint (C1), then per-screen wiring~~ | **DONE.** Three of the prototype's panels are named and not drawn — sleep duration, sleep efficiency and skin temperature have no daily series here (C3), and the screens say so |
| **A proper map on the recording screen** | `GpsRecordingState` to retain coordinates (E) · a decision on tiles vs schematic | client only |
| **Delete the dead code** | 47 files plus their tests and mutation entries | client only |
