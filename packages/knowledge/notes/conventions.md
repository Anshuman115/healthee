# Evidence note conventions

## Evidence grade

One field, `grade`, one vocabulary, both collections. *(The `★★★/★★/★` and numeric
`evidence_grade` spellings this file used to carry were retired in #83 — three
spellings of one concept is three chances to disagree. The numeric rank code needs
is derived from the string in `insights/manifest.py::GRADE_RANK`.)*

| `grade` | what qualifies | how the coach must say it |
|---|---|---|
| `Established` | Multiple high-quality RCTs **and/or** systematic reviews / meta-analyses **and** independent replication. Consistent effect direction across studies. Plausible mechanism. | state plainly |
| `Probable` | One high-quality RCT or meta-analysis, but limited replication; *or* multiple replicated cohort studies with strong effects. | light hedge |
| `Emerging` | Single primary study or mechanism-only reasoning. | flag the uncertainty |
| `Contested` | The literature genuinely disagrees. | present as debated |
| `Myth` / `Refuted` | The claim is popular and wrong. | correct gently |

`Established` and `Probable` are the tiers that may drive an action
(`insights/manifest.py::MIN_ACTIONABLE_RANK`). `Emerging`, `Contested` and `Myth`
stay fully retrievable — the coach may still discuss or correct them — but they do
not get to prescribe. Calibration is enforced per sentence by
`insights/validator.py::_grade_issue`, against this grade.

## Frontmatter schema

```yaml
---
id: <unique-snake-case-id>
topic: <one-line description>
grade: Established                      # the ONLY grade — Established | Probable |
                                        # Emerging | Contested | Myth | Refuted.
                                        # The old numeric `evidence_grade` mirror was
                                        # removed in #83 (it could disagree with
                                        # `grade`, and could not express Contested or
                                        # Myth). `make knowledge` rejects it.
safety_critical: [5, 6]                 # OPTIONAL — Coach Directive numbers this note
                                        # claims as HARD GUARDRAILS. Validated by
                                        # `make knowledge` and bijected against
                                        # `insights/guard_directives.py` by a test
                                        # (#87). Never write "mirrored as a guardrail"
                                        # in prose instead of declaring it here.
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
