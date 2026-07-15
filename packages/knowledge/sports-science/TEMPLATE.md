---
name: <kebab-case-slug>            # unique id, matches the filename
title: <Human Readable Title>
category: cardiovascular | fitness | pace | form | load-recovery | principle | wellness | safety
aliases: [<search synonyms the coach might retrieve on>]
related: [<other-doc-name>, ...]   # cross-links to related docs
metrics: [<@daud/core function or metric this maps to, if any>]
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
The formula(s), inputs, and units. Note which `@daud/core` function owns it (or
"not yet computed"). Flag estimation error vs lab-measured ground truth.

## How the coach uses it
The decision logic: thresholds, what action each reading drives, and how it
differs by **stage** (Stage 1 beginner → Stage 3 racing). Cross-check rules
(e.g. "weight effort and pace alongside HR in heat").

## Honesty & uncertainty
Confounders, individual variation, day-to-day noise, where the metric misleads,
and what the science still doesn't know. This section is mandatory.

## Safety bounds
Any hard limits the coach must respect (or "none"). Safety-critical bounds are
mirrored as guardrails in `@daud/core`.

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
