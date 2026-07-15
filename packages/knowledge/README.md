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
(numeric grades: 3 (★★★) → Established, 2 (★★) → Probable, 1 → Emerging; no Honesty/Directives sections
yet). Phase 5 migrates these to the template above — until then they remain
citable as-is.

## Unified frontmatter schema

Both collections normalize to one record shape. Authored frontmatter differs
per collection (see below); the generator maps both onto these fields:

| Field | Legacy source (`notes/`) | Sports-science source |
|---|---|---|
| `id` | `id` (already snake_case) | `id` (snake_case, e.g. `heart_rate_zones`) |
| `name` | `topic` (→ `title` → `id`) | `name` |
| `category` | parent directory | parent directory (`metrics`/`principles`/`wellness`) |
| `grade` | `evidence_grade` 3→Established · 2→Probable · 1→Emerging | `grade` (Established/Probable/Emerging/Contested/Myth) |
| `summary` | `topic`/`title`, else first body line | `summary` (one line) |
| `aliases` | `tags` | original hyphenated slug + existing synonyms |
| `applies_to_metrics` | `applies_to_metrics` | mapped per `docs/INTELLIGENCE.md` §7.1 (`[]` if not-yet-computed) |
| `applies_to_interventions` | `applies_to_interventions` | where natural (e.g. `strength`, `sauna`, `heat`) |
| `population` | — | `runners` on runner-specific docs |
| `last_reviewed` | `last_reviewed` (optional) | `last_reviewed` (optional) |

Sports-science docs also keep `related`, `daud_metrics` (the origin project's
compute-fn names — *not* Healthee metrics), and `units` as provenance; the
manifest ignores them. Ids must match `[a-z0-9_]+` (the citation regex) or they
are uncitable. Notes in `notes/protocol/` carry no `id`/`evidence_grade` and are
skipped as non-citable engineering references (surfaced, not silently dropped).

## Manifest (generated)

`tools/gen_manifest.py` parses every doc in both collections, validates the
whole corpus (duplicate id across collections, id format, unknown grade, and
missing required fields each fail loudly with the file listed), and writes two
**generated, never-hand-edited** artifacts:

- `manifest.json` — full records, for server retrieval.
- `research_summaries.json` — compact `{id, name, grade, summary,
  applies_to_metrics}`, for the bundled mobile asset.

Output is deterministic (sorted, no timestamps) so regeneration is diff-stable.

```
make knowledge        # regenerate both artifacts
make knowledge-check  # fail if the committed files are stale / hand-edited (CI runs this)
```

The generator uses PyYAML (declared in `apps/server`'s dev group), so it runs
under that environment: `cd apps/server && uv run python
../../packages/knowledge/tools/gen_manifest.py`. Current corpus: 76 records
(46 legacy evidence notes + 30 sports-science docs).
