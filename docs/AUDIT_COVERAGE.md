# Audit coverage — the whole surface, and what is left

Written because "is it 100% yet?" kept getting a different answer. That was a
failure of scoping, not of the work: each pass was scoped reactively, so a new
gap surfaced every time the question was asked. This is the complete map,
derived from the module tree rather than remembered, so the answer stops moving.

**200 server modules across ten packages**, plus the mobile data layer.

## Audited and fixed

| area | modules | audit | findings | status |
|---|---|---|---|---|
| `read/` | 30 | `BACKEND_AUDIT.md` | 30 | **all fixed** |
| `insights/` (LLM) | 39 | `LLM_AUDIT.md` | 16 | **fixing now** |
| `challenges/` — targets, gates, outcomes | 29 | `LLM_AUDIT.md` | covered in the 16 | **fixing now** |
| `analytics/` | 14 | partially, via both | — | correlations, baselines, bio-age covered |
| `derive/` | 27 | partially | — | touched by fixes; **not audited as a layer** |

## Programme status — 2026-09-08

**ALL EIGHT AUDITED — the programme is complete.** `read/` · `insights/`+`challenges/` · `api/` auth ·
`ingest/`+`derive/` · `packages/knowledge/` bodies · `db/`+`jobs/`+contracts+
internals. Performance was the last, and the only one *measured* rather than read.

Findings so far: **30 + 16 + 20 + 15 + 38 + 21 = 140**, of which 46 are fixed and
merged (the read layer and the LLM layer). The rest await the fix pass.

## Originally not audited — the programme, in priority order

**1. `api/` — auth, tenancy, RLS (26 modules).** The only unaudited area where a
defect is worse than a wrong number: it is someone else's data. Neither audit
went past noting that `provision_app_role` revokes `TRUNCATE`.

**2. `ingest/` (5) and `derive/` (27) as layers.** Where values are *born*. The
sleep-zeros defect proved this matters: the read layer was innocent and the fix
was at ingest. A value that is wrong on arrival is wrong everywhere downstream.

**3. `packages/knowledge/` note BODIES.** The manifest's grades and
`safety_critical` markers were checked; **the prose making the claims was not**.
The ACWR case showed a note can assert a rule the product does not have — that
was found by accident, not by audit.

**4. `db/` (7) — migrations, the purge tool, retention.** `#118` and `#121` both
began here.

**5. `jobs/` (9) — the scheduler.** Nightly chains that write derived rows.

**6. Performance against the standards' budgets.** No measurement has ever been
taken; the batching comments were called "credible", which is not the same.

**7. The five `today.json` models** spot-checked rather than diffed key by key —
explicitly *not certified clean*.

**8. `insights/credits.py` arithmetic and alert thresholds**; `challenges/`
`levers.py`, `ladder.py`, `program_store.py`, `windowed.py` line by line.

## Deliberately out of scope, permanently

**Prompt quality** — whether the prompts elicit good answers. An audit can ask
what the code *enforces*, not what a model *tends to write*. Holding code to a
standard is possible; holding prose to one is not.

## Needs production or a device — cannot be settled from here

1. Whether the coach's 10-second timeout has actually charged the owner.
2. Whether a forced back-fill has ever run.
3. The magnitude of the historical TRIMP inflation (depends on strap cadence).
4. Whether a future-dated `derived_daily` row exists.

**The owner's decision: device checks happen after the audit programme, not
during it.**

## Then, and only then

Deploy — which needs the merge to `main`, migration `0018` applied, and `infra/`
given the geocache volume and `MAP_TILE_*` settings. Then the UI refinements.

## The honest caveat

Completing this programme means **every area has been examined against the
honesty standard**. It does not mean no defect remains — audits sample judgement,
and three of the sharpest findings so far came from agents correcting earlier
readings. What it does mean is that no area is *unexamined*, which is the only
claim worth making.
