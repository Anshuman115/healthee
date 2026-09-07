# The prototype's navigation graph, and what the app is missing

The owner: *"our design is well connected with each other which we havent build
in app you can click on links in design and see where it takes what data it
shows to build the same thing."*

This is that walk. Every link in `design/mobile-preview/` was followed, recorded
with the data it carries, and checked against `lib/core/router.dart` and
`lib/core/settings_routes.dart`.

**The headline: the app has 13 of the prototype's 33 screens missing no data.**
Five screens do not exist, one exists only as a sheet, and roughly forty links
between screens that do exist are simply not drawn. Almost none of this is
blocked on the backend — see "What it costs" at the end.

## 1. How the prototype navigates

`app.js` is a hash router with three parts worth copying:

- **Five tabs** — `today · sleep · activity · insights · actions`.
- **A `parents` map** (`app.js:8`) giving every detail screen a home tab, so
  Back from a deep link lands somewhere sensible instead of dead-ending:

  ```
  recovery→today   sleep-history→sleep   metric,metrics,insight→insights
  workouts,workout,route,record,fitness,body→activity
  challenge,program,outcomes,action-history,journal→actions
  ```

  `H.back()` uses real history when there is any and falls back to this map
  otherwise. **The app has no equivalent** — a pushed detail screen with an
  empty stack has nowhere to go.

- **A date-aware route set** (`history-data.js:10`): `today, sleep, activity,
  insights, actions, recovery, body, fitness, metrics, metric, sleep-history,
  workouts, journal, action-history` — **fourteen** screens carry the selected
  day in their header. The app has the date control on Today only.

Tone is derived from the route, not passed by the caller (`panels.js:3`,
`H.toneFor`) — `sleep→sleep`, `recovery/fitness/body→fitness`,
`activity/workouts/route/record/challenge/program/outcomes→movement`,
`workout→heart`, and `metric/:key` from the metric's own definition. The app's
`ToneScope` already models this; nothing reads the route to set it.

## 2. Screen-by-screen: what links where

Legend: ✅ built · ⚠ partial · ❌ missing

### today → `Routes.today`  ✅
| link | target | status |
|---|---|---|
| `H.link('View sync status','sync')` | sync | ✅ route exists, link not drawn |
| bio-hero eyebrow arrow → `#body` | **body** | ❌ target missing |
| bio-divider "Fitness contribution −1.7 years" | **fitness** | ❌ target missing |
| bio-divider "Sleep contribution 0.0 years" | sleep | ❌ link not drawn |
| recovery panel "Details" | **recovery** | ❌ target missing |
| finding block | **insight** | ❌ target missing — *the inert block the owner reported* |
| section see-all | actions | ⚠ |
| journal strip `#journal` | journal | ✅ |
| vitals rows | `metric/:key` ×6 | ❌ not drawn |

### sleep → `Routes.sleep`  ✅
Links to `body`, `fitness`, `sleep-history`, `metric/:key`, and a
`H.bridge('fitness', …, 'body')`. **None are drawn in the app.**

### activity → `Routes.activity`  ✅
Panels carry "Details" to `metric/steps`, `metric/mvpa`, `metric/load`,
`workouts`, `program`, `fitness`; a bridge to `recovery`. `workouts` and
`program` are reachable; the rest are not.

### insights → `Routes.insights`  ✅
| link | target | status |
|---|---|---|
| correlation block | **insight** | ❌ **inert — no tap handler at all** |
| `H.row('moon','Sleep history',…)` | **sleep-history** | ❌ target missing |
| `H.row('activity','Fitness estimates',…)` | **fitness** | ❌ target missing |
| section see-all "All metrics" | metrics | ✅ target (`Routes.history`), link not drawn |
| `H.row('journal','Your journal',…)` | journal | ❌ not drawn |
| `H.row('coach','Ask about this trend',…)` | coach | ⚠ coach is a sheet |

### actions → `Routes.actions`  ✅
Rows to `challenge`, `program`, `outcomes`, `action-history`, `journal` — all
five targets exist in the app. The rows are drawn for challenges and programs;
`outcomes` and `action-history` are reachable but under-linked.

### Detail screens the app does not have

**`recovery`** — *"Recovery, in context."* Header, scenario notice, the recovery
panel, a baseline-comparison panel (`metrics`), a bridge to `sleep`, an
overnight-vitals panel (`sleep`), a "Capacity changes through the day" panel
with `72/100 overnight` vs `36/100 remaining readiness` (`activity`), and the
`recovery_readiness` evidence sheet. **Data: `/api/today.recovery` already
carries `factors` with sub-scores, weights, values and baselines** — the app
models them in `RecoveryScore` and renders them on Today's panel. Nothing new
on the wire; the screen and route are the whole job.

**`body`** — *"Biological age & its contributors."* The bio-hero, a bridge to
`fitness`, an age-waterfall panel (`36 chronological − 1.7 fitness + 0.0 sleep
= 34.3`), a fitness-contribution panel, a sleep-contribution panel with the
wearable-vs-`compared_as` comparison bars, an **"Excluded, not counted as
zero"** panel rendering `excluded[0].message`, and a confidence panel listing
`caveats` behind a disclosure. **Every field is already on the wire** —
`analytics/biological_age.py:219-286` sends `contributions[]` with `term`,
`delta_years`, `hr`, `value`, `unit`, `target`, `compared_as`, `method`, plus
`excluded` and `caveats` — **and the app already parses all of it**
(`data/models/biological_age.dart`). `AgeWaterfall` is already built
(`shared/v02/instruments/age_waterfall.dart`). This screen is assembly.

**`fitness`** — *"Capacity · workload · consistency."* VO₂max with its supplied
error magnitude (±2.95, MAPE 6.85%, *"not a confidence interval"*), the stored
estimate history with the honest note that **method metadata is not supplied
historically so a method change cannot be told from a fitness change**, a
"Which instrument produced it?" panel (`last_r2`, `last_speed_kmh`,
`method_caveat`), a bridge to `body`, a training-load panel, and a weekly-rhythm
panel linking to `program`. **All served** by `/api/activity.vo2max` and
`.cardio_load`.

**`insight`** — the finding detail. **BUILT** (`be09b3f`): the route is
`/insight/:key`, the card opens it, and the block is no longer inert. Badge `Observational · N samples`; the
observation *"They moved together. That doesn't tell us why."*; a caveat
paragraph; a two-stat card (ρ and paired observations) with `Adjusted q-value ·
same-day association` under a divider; a focus-card next step linking to
`journal`; the evidence sheet; and `H.link('Talk this through','coach')`.
**Already queued as fix 1.** Every field is on the wire. *The prototype itself
declares one gap here* — see backend note B1.

**`sleep-history`** — a 30-day history panel, a seven-nights stage chart, and an
"Open a night" list where each row selects that night's date and returns to
Sleep. Served by `/api/history` and `/api/sleep`.

### `coach` — a screen in the design, a sheet in the app  ⚠
The prototype routes to `#coach` from Today, Insights, workout detail
(`'Discuss this workout'`), the finding detail (`'Talk this through'`) and a
metric row. The app has `showCoachSheet()` and no route. A sheet cannot be deep
linked, cannot carry a topic in its URL, and vanishes on rotation.

### `record` — exists, still legacy  ⚠
`GpsScreen` is a plain `Scaffold`/`AppBar`. The GPS group (`record`, `route`,
`routes`) is the last unported screen set.

### `account` vs `serverSignIn`  ⚠
The prototype's `account` is *"Your data, on your server"* reached from
Settings; the app's `/server` is the sign-in form. Related, not the same screen.

## 3. What it costs

| | count |
|---|---|
| Screens missing outright | **4** (`recovery`, `body`, `fitness`, `sleep-history`) — `insight` is now built |
| Screens needing new backend data | **0** |
| Existing screens reachable but unlinked | `metrics`, `metric/:key`, `outcomes`, `action-history`, `sync`, `journal` from several parents |
| Structural gaps | the `parents` back-map · route-derived tone · the date control on 14 screens, not 1 |

The connectivity is not blocked on the server. It is four remaining screens, one
back-map, and about forty links.

### Resolved since this walk

- **`insight`** — built (`be09b3f`). The Insights relationship card opens it and
  carries the finding with it.
- **`workout`** — reachable. `workout_history_screen.dart:136` pushes it, and
  the same screen draws the prototype's link to GPS recording.
