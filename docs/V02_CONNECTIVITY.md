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

## 0. How this was checked, and what the first pass got wrong

The first version of this document was produced by **reading** the prototype's
source — `grep`/`awk` over `screens-*.js`, `app.js` and `panels.js`, pulling out
`href="#…"` and the helper calls' route arguments. That was not good enough: a
static read cannot see which links actually render in a given state, and it
cannot see **what data a destination shows**, which is half of what the owner
asked for.

The prototype was then served and **walked** — all 33 screens opened, links
clicked, destinations and their content recorded. Six things the source read got
wrong or missed:

1. **The selected date is a URL query parameter**, not screen-local state.
   Choosing a night gives `?date=2026-07-29#sleep`, and the parameter
   **survives a tab switch** (`?date=2026-07-29#activity`) and **re-windows
   every chart on the destination** — Activity's series became `16 Jul to
   29 Jul` instead of `2 Jul to 31 Jul`. The header switches from
   `31 July · Latest sample` to `29 July · Selected day`. This is a global,
   URL-persisted view state, and it is a much bigger thing than "the date
   control appears on 14 screens".
2. **A past day renders honest absences.** On 29 July the overnight vitals show
   `—` for blood oxygen, breathing and skin temperature. The screen does not
   fall back to the latest reading.
3. **Today's entry points are three tappable hero summary rows** — `Recovery
   72/100 · 36 remaining`, `Sleep 6h 20m · 79% of 8h need`, `Movement 8,200 of
   9,000 target` — not the panel "Details" links the source read suggested.
   The recovery row is what opens `#recovery`.
4. **Insights has TWO relationship cards**, not one: `Caffeine ↔ sleep ·
   ρ −0.42 · 24 observations · Explore ↗` opens `#insight`, and `Fitness → age
   · −1.7 years · Model contribution · Understand ↗` opens `#body`. Both were
   verified by clicking.
5. **Recovery carries the same five `metric/:key` vital rows as Today** —
   resting heart, HRV, blood oxygen, breathing, skin temperature.
6. **`sleep-history`'s night rows are buttons, not links.** They set the view
   date and navigate to Sleep, which is what produces the `?date=` form above.

Everything below has been checked against the running prototype.

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
  day. Confirmed by walking: the day rides in the URL as `?date=YYYY-MM-DD`,
  persists across tab switches, re-windows every chart on the screen it lands
  on, and flips the header from `Latest sample` to `Selected day`. **The app has
  the date control on Today only, and does not carry a day in its routes at
  all.**

Tone is derived from the route, not passed by the caller (`panels.js:3`,
`H.toneFor`) — `sleep→sleep`, `recovery/fitness/body→fitness`,
`activity/workouts/route/record/challenge/program/outcomes→movement`,
`workout→heart`, and `metric/:key` from the metric's own definition. The app's
`ToneScope` already models this; nothing reads the route to set it.

## 2. Screen-by-screen: what links where

**All 33 screens were opened and their links followed.** Legend: ✅ built ·
⚠ partial · ❌ missing.

### The five tabs

**`today`** ✅ — the entry point for most of the graph. Three tappable **hero
summary rows**: `Recovery 72/100 · 36 remaining` → **`recovery`** ❌,
`Sleep 6h 20m · 79% of 8h need` → `sleep`, `Movement 8,200 of 9,000` →
`activity`. Bio-hero: eyebrow arrow and `Understand your biological age` →
**`body`** ❌, plus the two contribution rows `Fitness contribution −1.7 years`
→ **`fitness`** ❌ and `Sleep contribution 0.0 years` → `sleep`. Also
`See the contributors` → `body`, a device strip → `sync`, the avatar →
`settings`, a journal strip → `journal`, and three body tabs (Your night · Your
day · Longer view).

**`sleep`** ✅ — its two `Details` links (`How your night unfolded`, `Your week,
stage by stage`) both point at `sleep-history`, and five overnight vital rows go
to `metric/:key`. On a past day the absent vitals render `—`.

> **Correction.** An earlier revision of this line claimed Sleep carries bridges
> to `body` and `fitness`. **It does not** — `H.screens.sleep` is defined in
> `sleep-history-view.js` and contains no `H.bridge` call at all; the hrefs that
> produced the claim came from `screens-sleep.js`, which defines only the
> `H.sleepView` helper. The static extraction split a concatenation on
> `H.screens.` and attributed one file's links to another file's screen. The
> walk had already shown no such links on screen and the wrong line was carried
> over anyway. Caught by the agent that built these screens, not by me.

**`activity`** ✅ — per-panel `Details` → `metric/steps`, `metric/mvpa`,
`metric/load`, `workouts`, `program`, `fitness`; a bridge to `recovery`.

**`insights`** ✅ — **two** relationship cards: `Caffeine ↔ sleep · ρ −0.42 ·
24 observations · Explore ↗` → **`insight`** ✅ *(built)*, and `Fitness → age ·
−1.7 years · Model contribution · Understand ↗` → **`body`** ❌. Then a
heart-rate/stress dual chart with a scrubber, `Add your context` → `journal`,
`All metrics` → `metrics`, and four trend panels → `metric/:key`.

**`actions`** ✅ — today's suggestion with `I'll try this tonight` and
`Why this suggestion`; a challenge card → `challenge`; a program card →
`program`; `Open journal` → `journal`; `What changed?` → `outcomes`;
`Previous suggestions` → `action-history`.

### The Actions group — all four built, all reachable

- **`challenge`** ✅ — target, evidence sheet, `Adjust target`, `End challenge`,
  `See previous outcomes` → `outcomes`.
- **`program`** ✅ — week 3 of 4, two `Review outcome` links, `End program`,
  `Why daily movement`.
- **`outcomes`** ✅ — the honesty surface of this group. `Average daily steps
  8,900 · previously 8,200 · 6 of 7 days met the target`, a before/during pair,
  and *"This is an observation, not a proven effect of the challenge."* Then
  **`Other things moved too`** — HRV `45 → 46.5ms`, RHR `55 → 54bpm` — with
  *"We don't attribute them to walking."* Then **`The context matters`**, three
  confounders each linking out: `One illness day` → `recovery` ❌,
  `One concurrent challenge` → `actions`, `Your own context` → `journal`.
  Closes with *"One week can suggest a question; it cannot settle cause and
  effect."*
- **`action-history`** ✅ — *"Adopting a suggestion records your intention. It
  doesn't mean the action was completed."* Links to `challenge` and `outcomes`.

### Explore

- **`metrics`** ✅ (app: `Routes.history` with no query) — **exactly 25 rows**:
  heart rate, HRV, resting HR, stress, blood oxygen, breathing rate, steps,
  weight, training load, active energy, sleep duration, sleep efficiency, sleep
  regularity, skin temperature, active minutes, moderate activity, vigorous
  activity, total energy, resting energy, distance, VO₂max, recovery estimate,
  sleep debt, sleep need, sleep dimension count.
- **`metric/:key`** ✅ (app: `Routes.history?metric=`) — **four windows: 30 days
  / 90 days / 1 year / 5 years**, a scrubbable chart, `See dated readings`,
  `Your journal` → `journal`, `Ask about this trend` → `coach`, and
  `Source & limitations`.
- **`sleep-history`** ❌ — a 30-day duration chart, a seven-night stage chart,
  and a night list whose rows are **buttons**: they set the date and go to
  `sleep`, producing `?date=YYYY-MM-DD#sleep`.

### Workouts and GPS

- **`workouts`** ✅ — `Record a workout` → `record`, a day-grouped list with two
  row kinds: `Morning run` → `workout` and `GPS recording` → `route`.
- **`workout`** ✅ — three figures, a scrubbable HR trace, `About training
  load`, `Discuss this workout` → `coach`.
- **`route`** ✅ — schematic map, distance/duration/pace, a scrubbable elevation
  profile, `Record another route` → `record`.
- **`record`** ⚠ *(exists as `GpsScreen`, still a legacy `Scaffold`/`AppBar`)* —
  schematic map, timer, `Start demo`, `View saved route` → `route`.

### Coach and journal

- **`coach`** ⚠ — **a full screen with a back control in the design; a sheet in
  the app.** Three starter questions (*"What should I notice about my sleep?"*,
  *"How is activity affecting my recovery?"*, *"What does my HRV mean?"*), a
  free-text box and a send control. Reached from `today`, `insights`,
  `metric/:key`, `workout` and `insight`. A sheet cannot be deep linked and
  cannot carry the topic it was opened about.
- **`journal`** ✅ — **ten entry types**: caffeine, water, mood, meditation,
  exercise, weight, alcohol, fasting, habit, symptoms. Recent entries below.

### Settings and onboarding — all built

`settings` ✅ → `profile` ✅ · `device` ✅ · `sync` ✅ · `appearance` ✅ ·
`reminders` ✅ · `background` ✅ · `journal` ✅ · `account` ⚠ · `about` ✅.

- **`account`** ⚠ — **not the app's `/server` sign-in.** A server-address field,
  `Test sample connection`, and two links out: `View sign-in design` →
  `welcome`, `Your data & privacy` → `about`.
- **`device`** ✅ — note it renders `Battery unavailable —%`: the em dash is a
  *value* with a label that explains it, not a placeholder the widget invented.
- **`sync`** ✅ — strap → phone → server, `Try a sample sync`,
  `Background preferences` → `background`.
- **`background`** ✅ — four switches, two interval selects, `View sync status`
  → `sync`.
- **`reminders`** ✅ — three switches, two time fields.
- **`appearance`** ✅ — **Light / Dark / System only.** No accent picker in the
  design.
- **`welcome`** ✅ — `Continue with Google`, `Connect your server`,
  `Already have a Helio Strap?` → `pairing`.
- **`pairing`** ✅ — `Find my strap`.
- **`profile`** ✅ — name, date of birth, height, sex, activity level,
  `Log a new weigh-in`, `Save profile`.

## 3. What it costs

| | count |
|---|---|
| Screens missing outright | **0** — `body`, `fitness`, `recovery` and `sleep-history` are built; `insight` before them |
| Screens needing new backend data | **0** |
| Existing screens reachable but unlinked | `metrics`, `metric/:key`, `outcomes`, `action-history`, `sync`, `journal` from several parents |
| Screens where the app's shape differs | **1** — `account` (a server form, not the app's sign-in). `coach` is a route now. |
| Screens built but still on the legacy frame | **0** — `record`, `route` and the saved-route list are on `DetailPage` |
| Structural gaps | the **`?date=` view state** carried in the route · route-derived tone. The `parents` back-map is built. |

The connectivity was not blocked on the server. The coach, the GPS frame, the
back-map and the links are done; **the date in the route is what is left**, and
it is the largest single piece: fourteen screens are date-aware in the
prototype, the day survives tab switches, and it re-windows every chart it lands
on. The app has no day in any route.

### Resolved since this walk

- **`insight`** — built (`be09b3f`). The Insights relationship card opens it and
  carries the finding with it.
- **`workout`** — reachable. `workout_history_screen.dart:136` pushes it, and
  the same screen draws the prototype's link to GPS recording.
- **The coach is a route.** `Routes.coach` on `DetailPage`; the sheet is gone
  rather than left beside it. All five callers push it, and the two that ask
  about something specific carry their subject in `?topic=` — which
  `coach_screen.dart` writes into the prototype's own `.coach-form` rather than
  sending, because a question costs one of twenty and a navigation must not
  spend one.
- **`record`, `route` and the saved-route list are on the v02 frame.** No legacy
  `Scaffold`/`AppBar` screen is left in the app. The map is a schematic drawn
  from the owner's own coordinates: the prototype's park, water and road shapes
  are fixture geometry and are not drawn under a real track, and the tile layer
  went with them (`flutter_map`, `latlong2` and `url_launcher` are gone).
- **The `parents` back-map is built** — `core/parent_tabs.dart`. `DetailPage`
  pops when there is a stack and otherwise goes to the mapped tab, and the
  system back gesture takes the same door. `SettingsPage` took the rule too.
- **The links are drawn**, except two that have nowhere to go and say so where
  they are: Today's heart-rate/stress panel (`metric/hr` — this build keeps no
  daily heart-rate or stress series) and sleep-history's duration panel
  (`metric/sleep` — no sleep-DURATION series; it silently fell back to HRV).

### Still open

- **The `?date=` view state.** Fourteen screens are date-aware in the prototype
  and the day survives a tab switch; the app carries no day in any route. This
  is the largest remaining piece and nothing above touched it.
- **Route-derived tone.** `ToneScope` is declared per screen; nothing reads the
  route to set it. The GPS screens declare `Tone.movement` explicitly, which is
  what `panels.js:3` would have derived for them.
- **The fitness screen's `workout` and `program` Details links**, and Today's
  `insight` entry card where the app draws a coach card. Both need an id or a
  content decision rather than a wire.
