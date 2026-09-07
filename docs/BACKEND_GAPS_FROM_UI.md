# Backend gaps, read off the UI we actually show

The owner: *"i would also want to know the gaps in our backend based on ui that
we show."*

Every item below was found by taking a built or specified screen and asking what
it needs from the API. Each is checked against the server source, with the file
and line. Nothing here is speculative, and nothing here is a request to build —
it is the list.

**The short version: the connectivity work is not blocked on any of this.** All
five missing screens are servable today. What follows is the separate question
of where the API is thinner than the UI, ranked by whether it can currently
mislead the owner.

---

## A. Correctness — these can put a wrong or unqualified number on screen

**A1. `naps[].stages` is structurally always empty.** `read/sleep_page.py:244`
ships the raw JSONB where `nights` ships shaped objects. Every nap stage bar
rendered blank. *Currently mitigated in the client* — the panel says the
breakdown is not sent — but the fix is a shape correction on the server, and
until then the app is apologising for a bug.

**A2. `rhr_daily` ships with no date and no freshness gate**
(`read/today_series.py::_derived_card`). An older night's resting heart rate can
render as today's. This is the same stale-as-current failure shape as issue #108, on a
different metric.

**A3. `anomalies` is `[]` unconditionally** (`read/today.py:83`). The real data
lives behind premium `/api/notable`, which the app does not call. An empty array
is indistinguishable from "nothing was anomalous" — the screen reads as a clean
bill of health that nothing computed.

**A4. `read/activity.py`, `read/fitness.py`, `read/vo2max.py` emit note
*aliases*, not ids.** Citation resolution is by id. An alias that stops matching
resolves to nothing, and the client correctly shows an unresolved marker — so a
rename on the corpus side silently degrades grounding on three surfaces.

---

## B. Screens the API can serve, but only thinly

**B1. Findings carry summary statistics only — no paired values.**
`read/findings.py:81-91` sends `effect_size`, `q_value`, `n_samples`,
`lag_days`; the underlying points never leave the server. So the finding-detail
screen cannot draw a scatter plot, which is the one chart that would let the
owner see *for themselves* that a correlation is not a cause.

The prototype already specifies the honest fallback, verbatim: *"The sample
response contains a summary, not the underlying paired values. A scatter plot
appears here when those values are available."* **Build the screen with that
sentence now.** The addition is cheap when it comes: `analytics/correlations.py:47`
already holds both full series in memory at compute time.

**B2. VO₂max history carries no per-point method metadata.**
`read/vo2max.py:180` builds `trend_90d` as `{date, value}` and discards the
third tuple element. The prototype states the consequence on the face of the
chart: *"a method change cannot be distinguished from a fitness change here."*
That is the correct disclosure, and it is also a chart the owner cannot fully
read. Emitting `method` per point turns a caveat into a legend.

**B3. `weekly_mvpa_min` is hardcoded `None`** in the VO₂max inputs block
(`read/vo2max.py:186`) while `/api/activity.mvpa.week_min` computes exactly that
number. One field, already derived, not wired.

**B4. No σ anywhere on `/api/today`** — only a centre and a precomputed `z`.
Exposing `Baseline.robust_sd` is ~4 lines plus a contract snapshot, and turns
three reference *lines* into *bands* with **zero client change**.

**B5. `/api/sleep` sends no need and no debt.** Those live in Today's block, so
Sleep computes a shortfall over measured nights and honestly labels the stat
`Nights counted`, never `Modelled nights`.

---

## C. Structural — the shape of the API against the shape of the design

**C1. The read endpoints have no notion of a day.** `/api/today` and
`/api/activity` take **no parameters at all** (`api/routers/today.py:30`,
`api/routers/activity.py:15`); `/api/sleep` takes a window (`days`), not a
target day.

The prototype makes **fourteen** screens date-aware (`history-data.js:10`):
`today, sleep, activity, insights, actions, recovery, body, fitness, metrics,
metric, sleep-history, workouts, journal, action-history`. Today they can only
be date-aware for *measurements*, via `/api/history`. Every interpretive
value — recovery and its factors, biological age, VO₂max, the findings — is
latest-only.

**This is the single largest gap between the design and the API, and the one
place where guessing would be dangerous:** relabelling today's judgements with
an older day's date is precisely the stale-as-current trap. Correct behaviour
until it is built is to show the measured half and say so — which is what the
app does.

**C2. The metric explorer would need 20 `/api/history` calls for one screen.**
Left latest-only, with the day named in the header. A batch history endpoint
would fix it.

**C3. Metric coverage does not reconcile, three ways.** The prototype lists
**25**, the app's `HistoryMetric` has **20**, the server's `KNOWN_METRICS` has a
*different* **25**.
- The prototype's five extras — HR, stress, sleep duration, sleep efficiency,
  skin temperature — have **no daily series on this server**. A tile for them
  would be a door onto a 422.
- The server already serves **five daily metrics the app does not list**:
  `spo2_overnight_min`, `sleep_dim_duration`, `sleep_dim_efficiency`,
  `sleep_dim_timing`, `sleep_dim_regularity`. **The app is one line of
  `HistoryMetric` away from five more working histories.**

**C4. `/api/coach` takes only `messages`** (`api/routers/coach.py:53`) — no
topic, no context id. The design routes to the coach from a finding, a workout,
a metric and a trend. Each of those *can* work by having the client seed the
opening message, so this is not a blocker — but the server never learns what the
question is *about*, so the grounding is whatever the model infers from prose.

---

## D. What is NOT a gap (checked, and better than expected)

- **Biological age is fully served.** `analytics/biological_age.py:219-286`
  sends `contributions[]` with `term`, `delta_years`, `hr`, `value`, `unit`,
  `target`, `compared_as` and `method`, plus `excluded` and `caveats`. The
  `body` screen needed no backend work at all.

  **Correction to an earlier claim here.** This section said the app "already
  parses every field". It did not: **`compared_as` was on the wire and absent
  from the Dart model**, as was the whole **`vo2max.submax`** block that the
  fitness screen's instrument panel needs. Both were added when those screens
  were built. The gap was never on the server — it was a client model quietly
  dropping fields nobody had needed yet, which is the same silence as a metric
  name falling back to its id.
- **Recovery's per-factor breakdown is served** and already modelled in
  `RecoveryScore` (sub-score, weight, value, baseline).
- **VO₂max sends its own instrument**: `method`, `method_caveat`,
  `measured_as_of`, `n_sessions`, `see_source`, `see_ml_kg_min`,
  `median_for_age`, `delta_from_median`, and a `submax` block with `last_r2` and
  `last_speed_kmh`. The `fitness` screen is assembly, not integration.

---

## E. Client-side, still open

- `metricName()` used to **fall back to the raw id** — `sleep_debt_min` reached
  Insights that way and nothing failed. Fixed;
  `test/shared/metric_names_coverage_test.dart` now asserts every
  `HistoryMetric` id resolves to something that is not the id.
- Citation chips on grounded prose (`shared/states/grounded_text.dart:106`,
  `grounded_markdown.dart`) — **queued as fix 2**. Moving them to the ⓘ must
  carry the evidence grade, the server's source sentence, personal findings
  (kept marked single-subject) and unresolved markers. A citation that resolves
  to nothing stays visible: a broken citation is our failure, not a fact about
  the owner's body.
