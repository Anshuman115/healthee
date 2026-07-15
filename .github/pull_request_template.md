## What & why

<!-- One paragraph: what this changes and the reason. Link the phase/brief. -->

## Standards checklist

Every box must be true before review (see `docs/ENGINEERING_STANDARDS.md`).

- [ ] **File sizes** — no file over 400 lines; functions ≤ 40, widgets ≤ ~200
      (a 300+ line file has a comment explaining why it can't split).
- [ ] **No swallowed errors** — no bare `except`/`catch (_) {}`; every failure is
      logged with context and either handled or propagated.
- [ ] **Tests in this PR** — new modules ship with tests (parser goldens /
      science known-values / endpoint contracts as applicable).
- [ ] **Science is verbatim** — any published-method function ports unchanged
      from legacy, cites its knowledge note, and has a known-value test;
      behavior changes are their own PR.
- [ ] **One canonical definition** per metric; no undocumented composite scores.
- [ ] **Conventional Commits**; no `Co-Authored-By: Claude` trailer.
- [ ] **Verified end-to-end** — ran the affected flow, not just the tests.
- [ ] **Docs updated** — README/architecture/knowledge notes as needed.

## How verified

<!-- The actual commands/flows you ran and what you observed. -->
