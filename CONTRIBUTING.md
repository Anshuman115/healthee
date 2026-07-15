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

## Definition of done

Code + tests + every gate green + verified end-to-end (run the affected flow,
not just the tests) + docs updated. See standards §5.
