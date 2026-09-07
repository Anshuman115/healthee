# API contracts

The regression bed that guarantees the mobile app's expectations of the read API
don't silently break. At Phase-6 cutover the installed app calls these endpoints,
so their JSON response **shapes** (keys, nesting, value types) must stay stable.

## What's here

- **`snapshots/*.json`** — one committed example response per read endpoint,
  produced from a known seeded database. Each file is a *representative* payload:
  the contract test asserts a live response has the **same nested key set and the
  same value types** (values themselves may differ run-to-run; a handful of
  deterministic derived numbers are asserted exactly in the test).

| Snapshot | Endpoint |
|---|---|
| `today.json` | `GET /api/today` |
| `sleep.json` | `GET /api/sleep` |
| `sleep_health_score.json` | `GET /api/sleep/health_score` |
| `sleep_consistency.json` | `GET /api/sleep/consistency` |
| `activity.json` | `GET /api/activity` |
| `workout.json` | `GET /api/activity/workout?start=…` |
| `history.json` | `GET /api/history?metric=…` |
| `history_batch.json` | `GET /api/history?metrics=a,b,c` |
| `profile.json` | `GET /api/profile` |
| `entitlement.json` | `GET /api/entitlement` |
| `log_recent.json` | `GET /api/log/recent` |
| `log_post.json` | `POST /api/log` |
| `gps_list.json` | `GET /api/workout/gps` |
| `gps_detail.json` | `GET /api/workout/gps/{track_id}` |
| `challenges.json` | `GET /api/challenges` |
| `challenge_outcomes.json` | `GET /api/challenges/outcomes` |
| `challenge_adopt.json` | `POST /api/challenges/{id}/adopt` |

## The harness

Lives in `apps/server/tests/contracts/` (runs under `uv run pytest`):

- `seed.py` — seeds a deterministic v2 dataset into every table the read layer
  reads (profile, samples, sleep sessions + a nap, a workout, `derived_daily`
  rows with the flags the payloads read, manual entries + an open fast, an
  illness flag, a recommendation, a finding, a GPS track).
- `seed_challenges.py` — the WP-C2 slice: a suggested, an active and a
  completed challenge plus a fully-populated frozen outcome. Its own module
  because `seed.py` is at the 400-line gate, and because the ledger's
  `confounds` / `co_occurring` / `data_confidence` fields ARE the contract
  (CHALLENGES.md §7 decision 1) — a snapshot generated from nulls would let a
  client render a co-occurring delta with no concurrency count beside it.
- `endpoints.py` — the endpoint list + a helper that calls every one (resolving
  the two dynamic ids: a workout start and a GPS track id).
- `shape.py` — the structural conformance check (same keys + types; union/
  heterogeneous object-lists supported; numbers are `int`/`float`-interchangeable;
  nulls accepted on either side).
- `test_contracts.py` — asserts each live response conforms to its snapshot, plus
  exact deterministic derived values (strain, sleep-performance %, ACWR, VO2max).
- `test_perf.py` — bounds the `/api/today` query count (no N+1) + a latency check.

These tests are marked `integration` and auto-skip when no TimescaleDB is
reachable, so `pytest` stays green on a laptop with no database and exercises the
real DB in CI.

## Regenerating the snapshots

After an intentional, reviewed shape change, regenerate against a reachable DB:

```bash
cd apps/server
POSTGRES_HOST=… POSTGRES_PORT=… POSTGRES_DB=… POSTGRES_USER=… POSTGRES_PASSWORD=… \
  REALTIME_INGEST_TOKEN=contract-token \
  uv run python -m tests.contracts.generate
```

Review the diff — a snapshot change is a wire-contract change and must be a
deliberate, reviewed commit (the installed app depends on it).

### A shape change is not a date change

`generate.py` seeds from `now()`, so a full regeneration rewrites **every date in
every snapshot** — the payload dates, the trend points, the night list. That is
not a wire-contract change and it is not free: `apps/mobile`'s suite is
calibrated to these dates (`test/features/_today_host.dart`'s `todayDate`,
`_screen_data.dart`'s pinned `now`, and the golden test that reads `today.json`
straight out of this directory), so a regeneration run purely to add a key turned
273 mobile tests red while changing nothing about the contract.

So: regenerate to SEE the new shape, then apply that shape to the committed files
and leave their dates alone. The diff a reviewer should get for a new key is the
new key. Note also that the committed files carry literal `—` and `₂` where
`generate.py` writes `—` and `₂`, so a hand-applied edit wants
`ensure_ascii=False`.
