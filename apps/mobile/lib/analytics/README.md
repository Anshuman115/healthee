# `analytics/` — the on-device engine

Empty. This is where the device re-derives what it can from the local 60-day tier
so the app renders offline and before the network answers.

## The rules it is built under

- **Pure functions.** No I/O, no providers, no `BuildContext` — inputs in,
  numbers out. That is what makes them parity-testable.
- **Parity-tested against server-exported golden fixtures** (Standards §1). The
  device and the server must not be able to disagree about a number; a parity
  test is how that stays true rather than being hoped for.
- **Science code is sacred.** Any function implementing a published method cites
  its knowledge note in the docstring and carries a known-value test. Port
  verbatim from the server or from legacy; a behaviour change is its own PR.
- **ONE canonical definition per metric.** If a value is computed here and on the
  server, they are the same formula or one of them is wrong. This is health data
  — CLAUDE.md names two definitions of "sleep debt" as "a lie waiting to surface".
- **Heavy parsing goes in a `compute()` isolate**, never on the UI isolate: the
  budget is 60 fps with no dropped frames (Standards §1).
