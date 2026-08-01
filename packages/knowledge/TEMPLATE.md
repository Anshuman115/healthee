# Knowledge note — unified template

Every reconciled note follows this structure. It is the sports-science template
(the richer of the two) plus the legacy notes' Healthee-specific frontmatter and a
mandatory **Healthee implementation & honesty policy** section — so migrating a
legacy note here makes it *gain* structure and *lose nothing*. See
`docs/KNOWLEDGE_RECONCILIATION.md` for the reconciliation method and the
no-degradation rule.

Copy the skeleton below. Delete the parenthetical guidance, not the sections.

---

```
---
id: snake_case_id                     # citable id — must match [a-z0-9_]+
name: "Human Readable Name"
category: metrics | principles | wellness | activity | sleep | hrv | metrics | intake | recovery | meditation
grade: Established | Probable | Emerging | Contested | Myth | Refuted   # the ONLY grade
safety_critical: [5, 6]               # OPTIONAL. Coach Directive numbers this note
                                      # claims are HARD GUARDRAILS. Each must exist and
                                      # say SAFETY-CRITICAL in its own text, and each
                                      # must have a compiled rule in
                                      # insights/guard_directives.py — a test asserts
                                      # the bijection both ways, so the claim cannot
                                      # rot into a lie (#87). Omit unless you are also
                                      # writing the rule.
summary: "One line: what it is and the single most useful takeaway."
aliases: ["other-name", "hyphenated-slug", "synonym"]
applies_to_metrics: ["derived_daily metric name(s) this backs"]   # [] if not-yet-computed
applies_to_interventions: ["fasting", "caffeine", ...]            # where natural
population: general | runners       # flag runner-specific guidance
last_reviewed: YYYY-MM-DD
---

# Name

## Summary
(Dense, context-first abstract. The one paragraph a coach reads first.)

## What it is
(Plain-language definition + typical ranges by level/population.)

## Physiology / mechanism
(Why the number is what it is. Legacy evidence notes often lack this — add it.)

## The evidence
(Each claim carries its OWN grade inline: [Established] / [Probable] / [Emerging] /
[Contested]. Real citations only — author, year, journal, DOI/PMID. Never a figure
without a source.)

## How we compute it
(The Healthee derivation at a glance: the formula + the metric it writes. Detail
lives in the implementation section below; this is the science-facing summary.)

## How the coach uses it
(Staged, decision-oriented: what the coach does at each level of the signal.)

## Safety bounds
(Hard limits. **Do not write that a limit is "mirrored as a code guardrail" unless
this note declares the directive in `safety_critical` and a rule for it exists in
`insights/guard_directives.py`.** ~24 notes made that claim about `@daud/core`, a
module that exists nowhere, and a false safety claim inside the safety system is the
worst kind — an auditor reads it and stops looking. If it is not enforced, say so:
"a rule for the coach, not a guarantee". #87.)

## Honesty & uncertainty
(Confounders, individual variation, the metric's limits, what it CANNOT tell you.
Mandatory — a note without this is incomplete.)

## Bottom line
**Act on confidently:** (well-evidenced, actionable.)
**Hold loosely:** (uncertain, individual, or thin.)

## Coach Directives
(Numbered, machine-applicable imperatives, each with a confidence. A directive marked
**SAFETY-CRITICAL** in its text AND named in the frontmatter's `safety_critical` list
compiles into a hard guardrail; marking one obliges you to write its rule and its
fire/no-fire tests in the same PR.)
1. ...  *(confidence: high)*

## References
(Every cited paper: Author et al. Year. Title. Journal vol(issue):pages. DOI/PMID.)

## Healthee implementation & honesty policy
(The product-specific payload legacy notes carry and the SS template has no home
for — THIS is what prevents degradation. Include, as applicable:
 - the real derived_daily field name(s) and the `derive/` provenance,
 - the exact formula/constants + any threshold tied to our data,
 - any composite-score exception + its required per-factor breakdown,
 - device-ingestion specifics,
 - honesty rules ("never show a death-risk number", "score vs absolute need not
   personal baseline", the confound the coach must name).)
```

---

## Reconciliation rules (binding)

- **No unit is dropped silently.** Every claim, citation, formula, directive, and
  Healthee-impl detail from *both* source docs is either carried into the canonical
  note or explicitly marked superseded with a one-line reason (the PR's coverage
  checklist proves this). A unit that is neither = a blocked merge.
- **Citations are preserved faithfully; new figures are verified.** Carry existing
  (author, year) citations as-is; do not introduce a figure without a primary
  source; flag any claim lacking one.
- **Grade calibration:** language matches the per-claim grade — Established stated
  plainly, Probable hedged, Emerging flagged, Contested presented as debated, Myth
  corrected gently.
- **ONE grade field.** `grade` is the note's only grade. There used to be a second,
  numeric `evidence_grade` "mirror"; it was removed in #83 because a mirror that can
  disagree is not a mirror. The two could contradict each other, and which one the
  manifest published depended on the note's *directory* — `notes/` was built from
  `evidence_grade` and `sports-science/` from `grade` — so a note authored `Myth`
  with `evidence_grade: 3` would have shipped as **Established**, i.e. the corpus
  telling the coach to state a debunked claim plainly. The numeric field also could
  not express `Contested` or `Myth` at all (it spanned 3/2/1 only), which forced
  `running_form_metrics` to write a number contradicting its own grade. `make
  knowledge` now REJECTS any note carrying `evidence_grade`. Where code needs a
  numeric rank, it derives one from the string in `insights/manifest.py::GRADE_RANK`
  — the one place that mapping lives.
- **Complementary topics stay two cross-linked notes** (e.g. cadence-as-MVPA vs
  cadence-as-running-form); only genuine near-duplicates merge into one.
- Ids stay `snake_case`; `make knowledge` regenerates the manifest from frontmatter.
