# Contributing to Healthee

This repo is a clean rebuild with binding quality gates. Read
[`docs/ENGINEERING_STANDARDS.md`](docs/ENGINEERING_STANDARDS.md) first — a diff
that violates a MUST is rejected in review even if it works. This file covers
the mechanics: commits, branches, and how to enable the local hooks.

## Getting set up

```sh
scripts/setup-dev.sh        # points git at .githooks and prints what it did
cd apps/server && uv sync   # server deps (Python 3.13 via uv)
```

`setup-dev.sh` sets `git config core.hooksPath .githooks`. The hooks are
dependency-free POSIX `sh` — no husky, lefthook, or node. Re-run it any time;
it is idempotent. From the repo root you can also use the [`Makefile`](Makefile)
targets: `make setup`, `make lint`, `make test`, `make fix`, `make ci`.

## Branch strategy

- **`main` stays green.** Every gate passes on `main` at all times; it is the
  branch CI and (eventually) prod deploy from.
- Work on short-lived branches: `phase-N/<topic>` (e.g. `phase-0/foundations`)
  for planned phase work, or `feat/<topic>` / `fix/<topic>` for standalone
  changes. Rebase or merge into `main` after review; delete the branch after.
- **Never commit directly to `main`.** Open a PR; the lead reviews against the
  standards doc before it lands.

## Commit conventions

We use [Conventional Commits](https://www.conventionalcommits.org/). The
`commit-msg` hook enforces the subject format and will reject anything else.

```
type(scope)?: short imperative description
```

- **types**: `feat` · `fix` · `docs` · `chore` · `refactor` · `test` · `perf` ·
  `ci` · `build` · `style` · `revert`
- **scope** (optional): the area touched — `server:` · `mobile:` · `knowledge:`
  · `infra:` (write it as `feat(server): ...`)
- Small, thematic commits: **one reviewable concern per commit.** Prefer several
  focused commits over one sprawling one.

Examples:

```
feat(server): add /healthz liveness endpoint
fix(mobile): stop chart replay on scroll
docs: document the backup restore drill
ci: cache uv across workflow runs
```

### The no-Claude-co-author rule

**Never** add a `Co-Authored-By: ... Claude` trailer (or any Claude/Anthropic
attribution) to a commit. The `commit-msg` hook rejects it. This is a hard repo
rule learned in the legacy repo.

## Local hooks

Enabled by `setup-dev.sh`. Both are fast (<2s) and dependency-free:

- **`commit-msg`** — validates the Conventional Commit subject and blocks the
  Claude co-author trailer.
- **`pre-commit`** — on staged files only: the 400-line file-length gate
  (`scripts/check_file_length.py`), an obvious-secret sanity grep, and (if
  `ruff` or `uv` is available) `ruff check` + `ruff format --check` on staged
  `.py` files.

The hooks are the fast first line. **CI is the thorough enforcement** — it runs
the gates repo-wide, plus `pyright`, `gitleaks` secret scanning, and the mobile
analyzer/tests once `apps/mobile` exists.

## Tests & coverage

- **Tests ship with the code.** A new module comes with tests in the same PR —
  no exceptions (standards §1). Parsers get golden-fixture tests, science
  functions get known-value tests, endpoints get contract tests.
- Coverage is **reported but not gated yet** — `pytest` runs with
  `--cov=healthee --cov-report=term`. A `--cov-fail-under` threshold lands in
  Phase 1 once there is real code to cover; adding it now would gate on a
  skeleton.

## Running the server suite — use a throwaway container

The integration tests need a TimescaleDB. `POSTGRES_*` comes from the **shell**,
not from `.env` (`.env` is gitignored, so `git worktree add` does not copy it, and
the main `apps/server/.env` holds only the LLM/Supabase keys). Without them
`Settings` will not build and every integration test silently auto-skips — which
looks exactly like a code break and isn't.

```sh
docker run -d --name healthee-test \
  -e POSTGRES_USER=healthee -e POSTGRES_PASSWORD=testpw -e POSTGRES_DB=healthee \
  -p 5599:5432 timescale/timescaledb:latest-pg17

cd apps/server
POSTGRES_HOST=localhost POSTGRES_PORT=5599 POSTGRES_DB=healthee \
POSTGRES_USER=healthee POSTGRES_PASSWORD=testpw \
REALTIME_INGEST_TOKEN=local-test-token uv run pytest

docker rm -f healthee-test          # when you're done
```

**Give each concurrent run its own CONTAINER, not just its own database.** The
suite creates a private database *and* a private login role per run
(`tests/_isolation.py`), so two runs against one container are safe today — but
that is a property the suite has to keep, and the reason it needs both halves is
the thing worth remembering:

> **A separate database is not enough, because a role is a cluster-level object.**
> Two suites pointed at different databases on the same PostgreSQL instance still
> meet the same role: the second run re-keys it with a fresh password out from
> under the first run's open pool, and whichever finishes first `DROP ROLE`s the
> login the other is still using.

Measured before that was fixed (2026-08-03, #119): two full suites, one container
— one finished 2205 passed in 3m44s, the other produced 14 errors and a wall of
failures, then sat at ~2% CPU with no DB sockets until it was killed at 15
minutes. The failures land in **unrelated code, in both directions**, so the noise
is indistinguishable from a real regression and the natural reaction is to go
debug an innocent diff. A private container costs nothing and removes the whole
question.

A run killed with `kill -9` skips its teardown and leaves `healthee_test_<pid>_<rand>`
behind — another reason the container is throwaway. On a long-lived local one:

```sh
docker exec healthee-test psql -U healthee -d healthee -tAc \
  "SELECT 'DROP DATABASE '||datname||' WITH (FORCE);' FROM pg_database WHERE datname LIKE 'healthee\_test\_%'"
```

**Run the full suite under BOTH timezones** before pushing — the dev box is IST
and CI is UTC, and they diverge for UTC 18:30–24:00. Anything asserting absolute
counts or dates must pass under `TZ=UTC` *and* `TZ=Asia/Kolkata`.

### Two test rules the suite now enforces for you

- **The suite leaves the database as it found it.** A run that ends with an
  `app_user` row it invented fails in session teardown, naming the ids. Owners
  arrive three ways — an explicit `INSERT`, a JIT provision on the first
  authenticated request, and `seed_owner_b` — and only the first is visible at the
  call site, so request the `owner_sweep` fixture rather than trying to remember.
  Left unwatched this reached ~1,288 stray rows, and `--user`-less ops tooling
  (`db/rederive.py`) walks every active owner it finds.
- **`caplog` assertions cannot be vacuous.** `core.logging.configure_logging`
  clears the root handlers on its first call in a process, taking pytest's capture
  handler with it — so a caplog assertion behind any `main()` used to pass or fail
  on test order, and an empty `caplog.text` made a *negative* assertion ("the token
  is not in the log") pass while proving nothing. `conftest._keep_caplog_capturing`
  pins the flag for the duration of every test. **A test that asserts on logs must
  carry at least one positive assertion**; a negative one alone cannot fail.

## Definition of done

Code + tests + every gate green + verified end-to-end (run the affected flow,
not just the tests) + docs updated. See standards §5.
