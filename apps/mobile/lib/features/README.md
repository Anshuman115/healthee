# `features/`

`pairing/` is built. **None of the tabs are** — the foundation's job was to make
a screen writable without re-deciding anything, and pairing was the first screen
that had to exist, because an app with no strap credentials has no data to show.

One directory per feature, matching the information architecture fixed in
`docs/APP_DESIGN.md` §2 — five tabs, a Coach sheet, and Profile as a route:

```
pairing/ ← built
today/  sleep/  activity/  insights/  actions/  coach/  profile/  workouts/
```

`pairing/` is worth reading before writing a tab: it is a sealed step union, a
Riverpod notifier that is the only thing holding logic, and widgets that only
draw — which is the shape Standards §3 asks for, in a size small enough to see
all at once.

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

- **A failure names itself.** "Something went wrong" is banned. See
  `data/pairing/pairing_failure.dart` for the pattern: a sealed union where every
  case carries a headline saying *which* failure this is and a remedy saying what
  to do, and a test that fails on vague copy.

## Where to start

`lib/shared/foundation_screen.dart` renders all four honesty states as live
specimens. Read it before writing Today, then delete it when Today lands — it has
no other job.
