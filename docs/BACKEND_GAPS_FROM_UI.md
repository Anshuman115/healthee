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
| Gaps that can put a wrong number on screen | **4** (section A) |

---

## A. Correctness — these can put a wrong or unqualified number on screen

**A1. `naps[].stages` is structurally always empty.** `read/sleep_page.py:244`
ships the raw JSONB where `nights` ships shaped objects. Every nap stage bar
rendered blank. The client now says the breakdown is not sent, so the app is
apologising for a server bug. **Fix is a shape correction on the server.**

**A2. `rhr_daily` ships with no date and no freshness gate**
(`read/today_series.py::_derived_card`). An older night's resting heart rate can
render as today's — the same stale-as-current shape as issue #108, on a
different metric.

**A3. `anomalies` is `[]` unconditionally** (`read/today.py:83`). The real data
is behind premium `/api/notable`. An empty array is indistinguishable from
"nothing was anomalous", so the screen reads as a clean bill of health that
nothing computed.

**A4. `read/activity.py`, `read/fitness.py` and `read/vo2max.py` emit note
*aliases*, not ids.** Citation resolution is by id, so a rename on the corpus
side silently degrades grounding on three surfaces. The client shows an
unresolved marker, which is correct and also a defect nobody caused today.

---

## B. Thin — the screen works, but shows less than it should

**B1. Findings carry summary statistics only — no paired values.**
`read/findings.py:81-91` sends `effect_size`, `q_value`, `n_samples`,
`lag_days`; the underlying points never leave the server. So the finding-detail
screen cannot draw the one chart that would let the owner see for themselves
that a correlation is not a cause. The prototype's own fallback sentence is
shipped instead. **Cheap to add**: `analytics/correlations.py:47` already holds
both full series in memory at compute time.

**B2. VO₂max history carries no per-point method metadata.**
`read/vo2max.py:180` builds `trend_90d` as `{date, value}` and discards the
third tuple element. The chart therefore says, correctly, that a method change
cannot be told from a fitness change. Emitting `method` per point turns a caveat
into a legend.

**B3. `weekly_mvpa_min` is hardcoded `None`** (`read/vo2max.py:186`) while
`/api/activity.mvpa.week_min` computes exactly that number.

**B4. No σ anywhere on `/api/today`** — only a centre and a precomputed `z`.
Exposing `Baseline.robust_sd` is ~4 lines plus a contract snapshot, and turns
three reference *lines* into *bands* with **zero client change**.

**B5. `/api/sleep` sends no need and no debt.** Those live in Today's block, so
Sleep computes a shortfall over measured nights and honestly labels the stat
`Nights counted`, never `Modelled nights`.

**B6. `/api/activity/workout` is the only payload with NO honesty envelope.**
It sends a bare nullable for every derived metric and no `withheld` block, so
nothing on the wire makes the screen explain an absence.
`data/workouts/workout_readings.dart` is what does, reading each reason off data
the app already holds. No remedy is invented, but the server should be saying it.

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
