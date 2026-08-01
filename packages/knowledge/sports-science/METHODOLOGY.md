# Knowledge Base Methodology

This package is Daud's **physiology knowledge layer** — the validated sports
science the AI coach reasons *with* and cites. It is one of the three grounded
sources the AI must use (alongside the runner's real data and the deterministic
computed-metrics layer), per the technical architecture.

The coach is **AI-first but never runs on intuition.** Every claim it makes about
training should trace to a document here, and every document grades its own
certainty so the coach can be calibrated — confident where the science is strong,
hedged where it is genuinely uncertain. *A coach that is confidently wrong loses
trust the first time it's caught; a calibrated coach earns it.*

---

## Evidence grading scale

Every claim in a knowledge doc is tagged with one of these. The coach must weight
its language and confidence accordingly.

| Grade | Meaning | How the coach should speak |
|---|---|---|
| **Established** | Strong consensus; RCTs / meta-analyses / decades of replication. | State plainly. "Easy running builds your aerobic base." |
| **Probable** | Good evidence, broadly accepted, some open questions. | State with light hedging. "This usually means…" |
| **Emerging** | Early or limited evidence; promising but unsettled. | Flag the uncertainty. "Early research suggests…" |
| **Contested** | Conflicting findings; experts genuinely disagree. | Present honestly as debated. "The science here is mixed…" |
| **Myth / Refuted** | Popular belief not supported (or contradicted) by evidence. | Correct it gently, explain why. e.g. the "180 cadence for everyone" myth. |

## Document standard

- Every doc follows `TEMPLATE.md` exactly (frontmatter + the fixed sections).
- **Citations are real or absent.** Every reference must be a real, locatable
  paper (author, year, journal, DOI/URL). If a claim can't be sourced, it is
  labelled as practitioner consensus or omitted — never dressed up as a study.
- Prefer **systematic reviews, meta-analyses, and seminal primary studies** over
  blogs. Note sample size / population (elite vs recreational) where it matters.
- **Individualisation over population defaults.** Every threshold is a starting
  estimate to be refined from the runner's own data, never gospel.
- **Honesty section is mandatory** — confounders, individual variation, and the
  limits of the metric (e.g. HR drifts in heat; HRV is noisy day-to-day).

## How the coach consumes this

1. **Retrieval:** per query, the Coach module retrieves the relevant docs (by
   `name`/`aliases`/`category`) into context.
2. **Grounding:** the AI must reason from the retrieved docs and may cite them.
3. **Directives:** each doc's **Coach Directives** block is a list of explicit,
   machine-applicable rules — these are the operational output the engine and AI
   honour. *Upstream, safety-critical directives were said to be mirrored as hard
   guardrails in `@daud/core`. **That was never true in Healthee** (#83b): `@daud/core`
   exists nowhere. Since #87 (2026-08-01) a directive CAN be genuinely enforced, but
   only by opting in: its note declares `safety_critical: [5, 6]` in frontmatter,
   `gen_manifest.py` validates the marker against the directive's own text,
   `insights/guard_directives.py` compiles a blocking rule for it, and
   `tests/insights/test_guard_directives.py` asserts the two sets are equal in both
   directions. **A directive is still not enforced by virtue of being written**, and
   **no doc in this collection declares a marker**, so nothing here is enforced today.
   The hand-compiled `output_guard._DOCUMENTED_RULES` table still exists alongside it,
   fed by doc lines rather than note markers; a new rule in either table needs a
   documented origin.*
4. **Calibration:** the AI's confidence and phrasing track the evidence grade of
   the claim it is leaning on.

## Maintenance

- `last_reviewed` in frontmatter tracks freshness; science moves, so docs are
  living. Re-review when a major meta-analysis lands.
- ~~The master index (`README.md`) and `src/manifest.ts` are generated from the
  docs — don't hand-edit them.~~ **False here (#83b).** `src/manifest.ts` does not
  exist in this repo; the generated index is `../manifest.json`, built by
  `packages/knowledge/tools/gen_manifest.py` (`make knowledge`). `README.md` in this
  directory is **hand-maintained** — believing this inherited line is what left the
  readiness row pointing at a module nobody could open (see this package's README).
