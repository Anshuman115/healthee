---
name: <kebab-case-slug>            # unique id, matches the filename
title: <Human Readable Title>
category: cardiovascular | fitness | pace | form | load-recovery | principle | wellness | safety
aliases: [<search synonyms the coach might retrieve on>]
related: [<other-doc-name>, ...]   # cross-links to related docs
metrics: [<Healthee derived_daily metric name(s) this backs — [] if not computed>]
units: <e.g. bpm, ms, sec/km, %, AU — or n/a>
evidence_overall: Established | Probable | Emerging | Contested
last_reviewed: 2026-06-29
---

# <Title>

## Summary
2–4 sentences. What it is, and the single most important coaching takeaway. This
is what gets read first into the AI's context — make it dense and accurate.

## What it is
Plain-language definition. What does this metric/principle actually measure or
describe? What are its units and typical ranges (recreational vs trained vs
elite)?

## Physiology / mechanism
Why it works the way it does — the underlying biology or biomechanics.

## The evidence
The key findings, each tagged with an evidence grade AND the *type and strength*
of the underlying evidence — so the reader knows how conclusive it is. Lead with
the strongest, most conclusive evidence available (meta-analyses, systematic
reviews, RCTs) before lower-tier studies. For each claim state: the evidence base
(meta-analysis of N studies / RCT / cohort / observational / single study), the
population (elite vs recreational), the effect size, and whether findings are
**consistent or conflicting**. Cite inline as [Author Year]. Say plainly when the
evidence is thin or mixed — do not inflate it.

- **[Established]** <claim> — *meta-analysis / consistent RCTs* [Author Year]: <effect size, population>.
- **[Probable]** <claim> — *good but not definitive evidence* … [Author Year].
- **[Emerging]** / **[Contested]** / **[Myth]** as appropriate, with WHY the
  evidence is unsettled (small samples, conflicting trials, weak designs).

## How we compute it
The formula(s), inputs, and units. Name the real owner in THIS repo — a module
under `apps/server/src/healthee/derive/` — or write "not computed". **Never cite
`@daud/core`**: it is the upstream project this corpus was imported from and it
does not exist here or in `~/projects/healthee-legacy` (#83b). A number whose only
stated authority is a module nobody can open is an uncited number, and this repo's
rule is citations real-or-absent. If a figure came from the literature, cite the
paper; if it is our judgement, say so.

## How the coach uses it
The decision logic: thresholds, what action each reading drives, and how it
differs by **stage** (Stage 1 beginner → Stage 3 racing). Cross-check rules
(e.g. "weight effort and pace alongside HR in heat").

## Honesty & uncertainty
Confounders, individual variation, day-to-day noise, where the metric misleads,
and what the science still doesn't know. This section is mandatory.

## Safety bounds
Any hard limits the coach must respect (or "none"). **State the bound and its
SOURCE; do not claim it is enforced.** Enforcement in this repo lives in
`apps/server/src/healthee/insights/output_guard.py` (hand-compiled from doc lines) and
in `insights/guard_directives.py`, which compiles ONE blocking rule per directive a
note declares `safety_critical` in its frontmatter — a real mechanism, available to
this collection, and already used by `wellness/environmental-stress.md` D12.
*(Corrected 2026-09-08: this said "no note carries a `safety_critical` flag and the
manifest emits no directives", which taught every author working from this template
that the mechanism does not exist. **Five directives across four notes are marked and compiled today** — `napping` D5, `hydration_everyday` D5 and D6, `late_eating_sleep` D5, and `environmental_stress` D12, the last of which IS in this collection (`wellness/environmental-stress.md` declares `safety_critical: [12]` in its frontmatter and `insights/guard_directives.py` compiles `environmental_stress_D12_exertional_red_flags_to_urgent_care` from it).)*
Declaring a marker OBLIGES you to write its rule and its fire/no-fire tests in the
same PR. Writing "mirrored as a guardrail" in prose WITHOUT declaring the marker
still does not make it one
(Engineering Standards, section 4). A note that asserts enforcement it does not have is
worse than one that asserts none.

## Bottom line
The honest conclusiveness verdict, split two ways so the coach knows what it can
stand on:

- **Act on confidently (conclusive):** the claims backed by strong, consistent
  evidence that the coach should treat as settled.
- **Hold loosely (unsettled):** the claims that are plausible but not proven —
  the coach should hedge, individualise, and watch the runner's own response.

## Coach Directives
Explicit, machine-applicable rules distilled from the above — the operational
output. Each is an imperative the AI/engine honours.

- D1: <directive> — confidence: <Established|Probable|…>
- D2: …

## Key references
Full citations. Real papers only.

- Author, A., & Author, B. (Year). *Title*. Journal, vol(issue), pages. DOI/URL.
