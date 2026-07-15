# packages/knowledge — the evidence base

Everything interpretive Healthee says must trace to a note in this package.
Two collections, one destination format:

## `sports-science/` — imported corpus (the target standard)

~29 docs (metrics / principles / wellness) imported 2026-07-15 from the daud
project's knowledge layer. **Its conventions are the standard this whole
package converges on** (see `sports-science/METHODOLOGY.md` and
`ENGINEERING_STANDARDS.md` §4):

- per-claim evidence grades with calibrated language
  (Established · Probable · Emerging · Contested · Myth/Refuted)
- citations real or absent — verified primary sources only
- mandatory Honesty section (confounders, individual variation, limits)
- a Coach Directives block per doc; safety-critical directives are mirrored as
  hard guardrails in server code and can never be overridden by the LLM
- docs follow `sports-science/TEMPLATE.md`; `COACHING-RULES.md` is the
  cross-cutting directives digest

Provenance note: imported from a running-focused coach, so some directives are
runner-specific — generalize on use, don't apply blindly. The original
`README.md`'s "Maps to `@daud/core`" column refers to that project's compute
layer; Healthee's equivalents live in `apps/server/src/healthee/derive`.

## `notes/` — legacy Healthee corpus (to be upgraded)

The 55 notes carried over from the legacy repo (activity, sleep, hrv, metrics,
recovery, intake, meditation, recs, protocol). Written to the older convention
(numeric grades: 2 → Established, 3 → Probable; no Honesty/Directives sections
yet). Phase 5 migrates these to the template above — until then they remain
citable as-is.

## Planned (Phase 5)

A generated typed manifest (id, name, aliases, category, grade) over BOTH
collections so server retrieval and the on-device `research_summaries.json`
are built from one index. Generated, never hand-edited.
