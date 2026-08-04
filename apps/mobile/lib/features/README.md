# `features/` — empty by design

Nothing here is built. This scaffold deliberately ships **no feature screens**;
its job was to make the foundation something a screen can be written against
without re-deciding anything.

One directory per feature, matching the information architecture fixed in
`docs/APP_DESIGN.md` §2 — five tabs, a Coach sheet, and Profile as a route:

```
today/  sleep/  activity/  insights/  actions/  coach/  profile/  workouts/
```

## The rules a feature is built under

- **Each feature owns** its `screen`, a `widgets/` folder, and its providers.
- **No feature reaches into another.** Shared logic moves down into `data/`,
  `analytics/` or `shared/` (Standards §3: "nothing reaches into another
  feature"). If two features want the same widget, it belongs in `shared/`.
- **Screens are composition.** A screen file lays out modules; each module widget
  lives in its own file. The 400-line gate applies, and a screen approaching it
  is a screen that has stopped delegating.
- **Every async consumer renders all three states** — use `AsyncView` from
  `shared/states/`, which supplies loading and a retryable error for free.
- **Every honesty-bearing value renders through `ReadingView`**, which makes the
  four-state switch exhaustive at compile time. See `data/honesty/reading.dart`.
- **Scrollable chart screens use `ListView.builder` + reveal-once**, or the charts
  replay their animation on every scroll-back (CLAUDE.md, flagged twice).

## Where to start

`lib/shared/foundation_screen.dart` renders all four honesty states as live
specimens. Read it before writing Today, then delete it when Today lands — it has
no other job.
