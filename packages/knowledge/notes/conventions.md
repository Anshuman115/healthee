# Evidence note conventions

## Evidence grade

| grade | what qualifies |
|---|---|
| `★★★` | Multiple high-quality RCTs **and/or** systematic reviews / meta-analyses **and** independent replication. Consistent effect direction across studies. Plausible mechanism. |
| `★★` | One high-quality RCT or meta-analysis, but limited replication; *or* multiple replicated cohort studies with strong effects. |
| `★` | Single primary study, mechanism-only reasoning, or contested findings. **Default project policy:** do not ship `★` notes; if added, explicitly mark every downstream use as low-confidence. |

`★★★` is the default tier we ship and the LLM may cite without qualifiers.
For `★★` the LLM must include a "moderate-confidence" qualifier.
`★` notes are excluded from the LLM grounding context unless explicitly toggled on.

## Frontmatter schema

```yaml
---
id: <unique-snake-case-id>
topic: <one-line description>
evidence_grade: 3                       # 3 = ★★★, 2 = ★★, 1 = ★
applies_to_metrics: [hr, hrv_rmssd_ms]  # canonical metric names from metric_sample
applies_to_interventions: [meditation]   # session.kind values where relevant
tags: [sleep, autonomic, recovery]
last_reviewed: 2026-05-11
---
```

## Body structure

1. **Finding** — one paragraph, plain language, what the evidence shows.
2. **Effect size** — quantitative where possible (RR, OR, SMD, % change, raw delta).
3. **Evidence strength** — list of citations with what each contributes (meta-analysis, RCT, large cohort). Include first-author, year, journal, PMID/DOI.
4. **Caveats** — observational limitations, study population differences, why this might NOT apply to a specific individual (n=1).
5. **Operational use** — how this should inform what we surface to the user.

## Style rules

- Never overstate. If the meta-analysis effect size is small, say small.
- Distinguish acute vs chronic effects explicitly.
- Distinguish population-level vs individual-level inferences.
- If a finding is from observational data only, do not say "causes."
- For interventions: state minimum effective dose / duration where the literature has it; otherwise say "dose-response unclear."

## Sources we trust (default whitelist)

Meta-analyses + systematic reviews in:
Cochrane Database, BMJ, NEJM, JAMA / JAMA Internal Medicine, The Lancet
(+ specialty Lancet journals), Annals of Internal Medicine, Sleep, European
Heart Journal, Circulation, JACC, Diabetes Care, Sleep Medicine Reviews,
Frontiers in Physiology/Public Health, Psychosomatic Medicine.

Large prospective cohorts: UK Biobank, Framingham, Whitehall II, NHANES,
Nurses' Health Study, ARIC, Rotterdam, Finnish Kuopio cohort, EPIC.

Sources we treat with caution: pre-prints, podcast/influencer summaries,
single-lab specialty findings, industry-funded studies without independent
replication.
