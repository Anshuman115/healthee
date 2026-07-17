# End-to-end code review prompt (agent-driven)

A reusable brief for reviewing the **whole codebase** with an agent, one dimension at a
time. It exists because the built-in review tools review a *diff* — this is for when the
work is already merged and you want a standing audit of `main`.

**Use `/code-review` instead when** you have uncommitted work or a branch: it reviews your
working diff. `/code-review ultra` runs a multi-agent cloud review of the branch, or
`/code-review ultra <PR#>` for a GitHub PR. Reach for *this* file only for whole-codebase
passes, where there is no diff to anchor on.

## How to run it

Copy the prompt below, replace `{DIMENSION}` with **one** row from the table, and hand it to
an agent. **Run one agent per dimension** — a single agent told to "review everything"
produces shallow mush; a dimension-scoped one goes deep. They can run in parallel.

| Dimension | Why it earns a pass |
|---|---|
| **Security & tenancy** | auth paths, RLS bypasses, injection, secret handling, `MULTI_USER.md` §12.7 anti-bypass |
| **Correctness & data integrity** | the science layer, `derive/`, `analytics/` — hunting silent wrongness |
| **The honesty contract** | grounded-ask choke point, validator, citations, calibrated language, composite scores |
| **Error handling & operability** | swallowed errors, job supervision, does a failure actually reach the health surface |
| **Test quality** | do the tests test anything? weak assertions, mutation-resistance, coverage gaps |
| **Performance** | the `ENGINEERING_STANDARDS.md` budgets, N+1, the perf-tuned `/api/today` path |
| **Standards & structure** | file/fn size, layering, dead code, duplication, config drift |

**Test quality is usually the highest-yield.** During Phase 6 we found four cross-tenant
leakage tests that passed with the owner filter *removed* — they were testing nothing, and
only mutation testing exposed it. Whatever else is weak in that way, we haven't found yet.

## ⚠ Maintaining the "already known" list

The prompt carries a **suppression list**. That list is a liability as much as a
convenience: **a stale entry silently hides a real finding**. Prune it whenever something on
it gets fixed, and never add anything to it that hasn't genuinely been decided or tracked.
If you find yourself adding an entry to quiet a report you don't want to read, that is the
signal to fix the thing instead.

Likewise the test baseline and the guard inventory below drift as the code moves — check
them before a run rather than trusting the numbers.

---

## The prompt

````markdown
You are performing an end-to-end review of the Healthee monorepo.
**REVIEW ONLY — do not fix, edit, or commit anything.** Your output is a report.

## Read IN FULL before reviewing (do not skim, do not work from a summary)
- `CLAUDE.md` — hard rules
- `docs/ENGINEERING_STANDARDS.md` — **binding**: a MUST violation is a finding even if the code works
- `docs/ARCHITECTURE.md` — the honesty contract (this product's one promise is that it never lies)
- `docs/MULTI_USER.md` — the tenancy model (§3.3 RLS, §4 auth, §12.7 anti-bypass)

## Scope
`apps/server/src/healthee` + `apps/server/tests`. Also `packages/knowledge`,
`packages/contracts`, `infra/` where your dimension touches them.

## YOUR DIMENSION: {DIMENSION}
Go deep on this one dimension only. Depth beats breadth — another agent has the rest.

## What counts as a finding
- **Evidence required**: `file:line` + a concrete failure scenario (specific inputs/state → wrong
  output, crash, or leak). "Consider refactoring" is not a finding.
- Health data is the product. Rank **silent wrongness** (a wrong number shipped confidently)
  above a crash — a crash is honest, a wrong number is not.
- No style opinions. No speculative "might be slow" without a measurement or a clear mechanism.

## Verify before you report (this is the important part)
For every candidate finding, actively try to **REFUTE** it: read the surrounding code, check
whether a test already covers it, check whether an existing guard already prevents it, and run
the code if you can. Report only what survives. **When uncertain, drop it and say you dropped it.**
For each finding, state what you did to verify it. A short verified list beats a long plausible one.

## Already GUARDED — don't re-derive these; find GAPS in them instead
- `tests/db/test_tenant_read_scoping.py` — an AST guard that **fails the build** on any tenant-table
  SQL not referencing `user_id`. Don't report "this query might forget the owner" without first
  showing the guard misses it.
- **RLS** is live on all 16 tenant tables, and the app connects as a **non-superuser** role, so a
  forgotten filter is also blocked at runtime.
- Cross-tenant leakage suites exist at **service level and HTTP level**, plus a two-owner seed.
Attacking the *guards themselves* (a way around the AST scanner, a path that bypasses RLS, a
leakage test that passes with the filter removed) is HIGH-value and explicitly in scope.

## Already KNOWN and tracked — do NOT report
- 3 science fns over the 40-line gate: `derive_vo2max_submax`(46), `derive_vo2max`(44),
  `compute_biological_age`(41) — need their own science PR.
- The legacy shared-token branch in `core/request_auth.py` — deliberate, transitional, blocked on
  the Phase-2 mobile rebuild. (A way to *escalate* through it IS a finding.)
- `python -m` CLIs hang ~20s on exit (`main()` never calls `close_pool()`).
- `infra/deploy.sh` doesn't run migrations and only recreates `api`.
- `docs/ARCHITECTURE.md`'s phase table and `docs/MULTI_USER.md` line 8 are stale.

## Test environment — READ THIS OR YOU WILL MISREAD THE SUITE
`.env` is gitignored and holds only LLM/Supabase keys; **POSTGRES_* comes from the SHELL**.
Without it, `Settings` won't build and every integration test **silently skips** — which looks
like breakage but isn't.
```sh
export POSTGRES_HOST=localhost POSTGRES_PORT=5544 POSTGRES_DB=healthee POSTGRES_USER=healthee
export POSTGRES_PASSWORD="$(docker inspect healthee-timescaledb --format '{{range .Config.Env}}{{println .}}{{end}}' | grep '^POSTGRES_PASSWORD=' | cut -d= -f2-)"
export REALTIME_INGEST_TOKEN=local-test-token
set -a; . /home/ashish/projects/healthee/apps/server/.env; set +a
```
Baseline (as of 2026-07-16): **480 passed** under both `TZ=UTC` and `TZ=Asia/Kolkata`. Confirm the
current number yourself rather than trusting this one.
⚠ Do NOT run `pytest` if another agent may be running it — the DB on 5544 is shared and the
seed/TRUNCATE will race. Prefer read-only analysis; if you must execute, use a throwaway database
you create and drop. Never print secrets.

## Output
Ranked most-severe first. For each finding:
`severity · file:line · the defect in ONE sentence · concrete failure scenario · how you verified it`
Then: what you examined but found clean, and anything you couldn't verify (say so — don't guess).
**An empty list is a valid, respectable result.** Do not pad.
````
