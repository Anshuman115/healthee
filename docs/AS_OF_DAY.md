# Serving a past day truthfully

The owner: *"we need the backend to support the ui with data it needs … no made
up data, true to what data can be exact faithful, truthful data."*

The app can now browse to a past day. It shows that day's **measurements** and
**refuses** everything derived, because `/api/today` and `/api/activity` take no
day and relabelling today's judgements with an older date is the
stale-as-current failure this repo has swept three times.

This document establishes whether that refusal is *necessary* or merely
*current*, and what a truthful past-day answer would have to satisfy.

---

## 1. The finding: past-day derived values already exist

`derived_daily` is `(day, metric, value, flags, user_id, derived_at)` — **one
row per metric per day**, with the computation's own flags and the instant it
was computed. Every derived metric the app draws lives there:
`recovery_score`, `hrv_sleep_avg`, `rhr_daily`, `vo2max_estimate`,
`cardio_load`, `sleep_health_score_4dim`, `sleep_debt_min` and the rest.

So a past day's derived values are **stored facts, not reconstructions**.
Serving the row filed under 29 July as 29 July's answer is exact. It is the
opposite of invention — inventing is what we would be doing if we served
today's row under that date, which is precisely what the app refuses to do now.

**This is the whole basis for the work.** Where a row exists, we can answer.
Where it does not, we withhold, exactly as today.

## 2. The seam: "today" has one definition and eighteen callers

`core/tenancy.py` holds both forms and calls them the one definition of the
owner's day:

```
USER_TODAY_SQL = "(now() AT TIME ZONE %s)::date"
def user_today(tz: str) -> date
```

Eighteen modules under `read/`, `analytics/` and `derive/` call them — but they
call them *inside* the function, so the reference day is ambient rather than
passed. Every one of those functions **already takes `tz`**, so a day belongs
naturally beside it.

**One module already does it correctly.** `analytics/baselines.py:123`:

```python
end_date = end_date or user_today(tz)
```

An optional reference day, defaulting to today. That is the convention to
generalise, and it is not a guess — it is the codebase's own.

**Legacy agrees.** `healthee-legacy`'s `v2/api.py` passed the reference day into
every helper (`_today_daily(cur, today)`, `_baseline(cur, m, today)`,
`_trend(cur, m, today)`). It always passed *today*, so it gained nothing, but the
calling convention was right and the rebuild lost it by centralising the lookup
one level too deep.

## 3. The rule this creates, and the new way to get it wrong

Serving a past day introduces a failure mode the current code cannot have, and
it is the mirror of the one we already guard:

> **FUTURE LEAK.** An answer for day D must contain nothing measured, computed
> or observed after D.

It is easy to commit by accident, because "latest" is everywhere. Concretely:

- `read/vo2max.py` takes the **latest** estimate. As-of D that must be the
  latest estimate **with `day <= D`**, not the global latest.
- `analytics/biological_age.py` takes the latest VO₂max and a 14-night sleep
  average, then applies a **freshness horizon against today**. As-of D, every
  input must be bounded by D *and* the horizon measured from D — otherwise a day
  in June inherits a fitness value first measured in August.
- Baselines and trends must end at D.
- A finding discovered last week must not appear on a day before it existed.

**Stale-as-current and future-leak are the same error in opposite directions.**
One shows new data under an old date; the other shows old judgements under a new
one. Both are the app claiming to know something it did not.

## 4. What a truthful past-day payload must do

1. **Answer from the row filed under that day.** Not the newest row; not a
   recomputation that ignores the stored one.
2. **Bound every "latest" by the day.** See section 3.
3. **Measure every freshness horizon from the day**, not from now. A VO₂max
   that was 3 days old on 29 July was fresh then, and saying so is correct.
4. **Withhold on absence, with the same vocabulary as today.** A day with no row
   is `Withheld` with a reason — never a dash, never a neighbour's value, never
   an interpolation.
5. **Name the day it answers for**, in the payload, so the client cannot
   mislabel it.
6. **Carry `derived_at`.** A row for 29 July computed during a re-derive in
   September is still 29 July's answer, but the reader is entitled to know when
   it was computed. This is the same instinct as VO₂max naming its instrument.
7. **Never fabricate a composite from partial inputs.** If one required term is
   missing as-of D, the composite withholds, exactly as it does today.

## 5. What must NOT be claimed

A past-day answer is *"the best account of that day, from the data filed under
it, using today's model"*. It is **not** *"what the app told you that day"* —
re-derives and science fixes mean the two can differ, and #118 is the standing
proof that wrong rows can persist until purged.

So the payload may not imply it is a historical record of past advice. Where the
distinction could mislead, the honest phrasing is *as of that date*, not *on that
date*.

## 6. Scope

**In:** `/api/today`, `/api/activity`, `/api/sleep` accept an optional day; the
read layer takes a reference day beside `tz`; the guards in sections 3 and 4.

**Out for now:** the LLM surfaces. A written analysis or a daily action for a
past day would have to be either regenerated (a new claim, not a record) or
absent. Absent is the honest default and is what the app already shows.

---

## 7. What shipped, and the two things it turned out to need

Built as specified. `core/tenancy.py` gained `reference_day(day, tz)` and
`AS_OF_DAY_SQL`; the read layer's shared primitives took a **required**
`on_or_before` (a default would have been today, so a caller that forgot its own
day would silently get the unbounded behaviour back); every window gained a
closing edge; and the three endpoints take `day=YYYY-MM-DD`.

Two things the design did not anticipate, both discovered by building it:

**A payload about another day is not this day's answer, on the client either.**
Riverpod keeps the previous value through a refresh, so between the date control
moving and the response landing, the app holds the *old* day's payload while the
header already says the new date. Drawing it would be section 3's failure with a
shorter lifetime, which is not a smaller version of it. The client therefore
draws a payload only when it answers for the day being read
(`shared/instrument_screen.dart`), and the request always carries the selection
so the server's echo makes that comparison exact. The offline cache follows the
same rule: a past-day request falls back to **that day's row or to nothing**,
never to the newest one — reaching the lie through the cache is still the lie.

**Two fields describe *now* rather than a day, and they are absent on a past
one.** The live-feed trust card is a set of ages measured against the request
instant, so on an older date it would be reporting observations made *after* that
day as its facts; it moved to `read/data_health.py`, which takes no `day` at all,
because a signature that accepted one would invite the belief that this question
has a past tense. An open fast is the other: nothing records when its `end_ts`
became null, and its elapsed is measured from now, so neither half survives the
move backwards. Both are `null`, which is what "we have nothing to say here"
already means everywhere else in these payloads.

Stored recommendation rows ARE served for a past day. Section 6 puts the LLM
surfaces out of scope because *authoring* a past day's analysis now would be a new
claim rather than a record — but those rows are already written and already dated,
exactly as `derived_daily` is, so reading them is the same move this document is
built on. The daily action is not: its cache is keyed on the current day, so an
older one has nothing stored and nothing is generated for it.
