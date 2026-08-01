---
id: behavior_change_and_personalization
name: "Behavior change & personalization (recs design basis)"
topic: What actually changes health behavior — BCT taxonomy, self-monitoring, and personalization effect sizes
category: recs
grade: Established
summary: "Generic information barely moves health behavior; what works is personalized, data-anchored feedback plus self-monitoring + goal-setting + discrepancy, with multi-technique interventions ~2× single-technique — the evidence basis for the recs engine's design rules (personalize not inform, progress-frame, cite, ≤3 actions/day, track adoption)."
aliases: ["behavior change", "BCT", "behavior change techniques", "personalization", "methodology", "self-monitoring"]
applies_to_metrics: []
applies_to_interventions: []
population: general
last_reviewed: 2026-07-15
related: ["recommendations_engine_plan", "llm_health_advice_safety"]
tags: [recs, behavior-change, methodology, personalization]
---

# Behavior change & personalization (recs design basis)

## Summary

The behavior-change literature converges on a small set of techniques that
reliably move health-related behavior in self-monitoring contexts. **Generic
information delivery** (e.g., "exercise more", "drink less caffeine") has
**near-zero effect size**; **personalized** feedback anchored to the individual's
own data has **medium effect sizes**; and **multi-technique** interventions
outperform single-technique ones. This is a **process note** (`applies_to_metrics:
[]`): it is the evidence basis for the recs engine's design rules, not a metric.

## What it is

The **Behavior Change Technique (BCT) Taxonomy v1** (Michie et al., 93
hierarchically clustered techniques) is the reference vocabulary for what an
intervention actually *does*. The subset most relevant to a self-tracking app like
this project:

| BCT code | Technique                              | Why it matters here              |
|----------|----------------------------------------|----------------------------------|
| 2.3      | Self-monitoring of behavior            | Core to the whole project        |
| 2.4      | Self-monitoring of outcome             | Sleep score, RHR, HRV, VO2max    |
| 1.1      | Goal-setting (behavior)                | "150 min MVPA/week" target       |
| 1.5      | Review behavior goals                  | Weekly progress card             |
| 1.6      | Discrepancy between current and goal   | Sleep-debt, MVPA-gap visuals     |
| 6.1      | Demonstration of behavior              | Research notes shown inline      |
| 7.1      | Prompts/cues                           | Bedtime nudges, caffeine cutoffs |
| 5.1      | Information about health consequences  | Citation chips on recommendations|
| 5.3      | Information about social/environmental | Lower-impact; deprioritize       |
| 13.2     | Framing/reframing (e.g., loss-frame)   | "Sleep debt building" framing    |

## Physiology / mechanism

Not physiological — the "mechanism" is psychological: self-monitoring closes a
feedback loop, explicit goals plus a visible current-vs-target discrepancy create
motivational tension, and data-anchored personalization raises perceived relevance
and self-efficacy. Information alone changes knowledge but not behavior; the
behavioral techniques are what convert intent into action.

## The evidence

### Multi-technique beats single-technique (~2×) [Established]
**Michie 2009 meta-regression** (n=122 studies of physical-activity and diet
interventions): interventions including BCT 2.3 (self-monitoring of behavior) AND
at least one other goal/feedback BCT (1.1, 1.5, 1.6) had **~2× the effect size** of
interventions without these. Effect sizes from **g=0.20 (single-technique) up to
g=0.45 (multi-technique** combining self-monitoring + goals + feedback).

### Information alone barely works [Established]
**Kelly & Barker 2016** synthesis: knowledge-based interventions ("inform the
user") have effect sizes **near zero**; the techniques that work are behavioral,
not informational.

### Tailoring gives a small but consistent edge [Probable]
- **Krebs 2010 meta-analysis** (Prev Med, n=88 computer-tailored intervention
  studies): tailored interventions had a small but consistent effect (**mean
  d=0.07–0.17** depending on outcome) over non-tailored controls. Effect compounds
  with adherence and depth of personalization (data-driven > demographic > generic).
- **Lustria 2013 meta-analysis** (J Health Commun, n=40 trials): web-based tailored
  health communication **d=0.139 (95% CI 0.111–0.166)** on outcomes vs untailored.

### Goals + incentives move behavior, but persistence is partial [Probable]
**Patel 2017** (Lancet Pub Health, n=797 RCT): financial-incentive + step-goal
interventions had **~+1,200 daily-step difference** vs control at 13 weeks;
persistence after incentive removal was partial (BCT 10.7 self-incentive sustains
but weaker than active).

### Goal-setting theory [Established]
**Locke & Latham 2002** provides the empirical basis for SMART goals — the theory
underpinning the goal-setting BCTs above.

## How we compute it

Not a computed metric — this note supplies the **design rules** the recs engine
(`recommendations_engine_plan`) implements. The BCT codes above map directly to
recs-engine features (self-monitoring dashboard, weekly targets, discrepancy
visuals, citation chips, adoption tracking, progress framing).

## How the coach uses it — design rules for the recs engine

1. **Personalize, don't inform.** Every recommendation must be anchored to the
   user's own data, not generic guidance. ✅ "Your caffeine after 14:30 lost ~24 min
   TST (n=22)" — ❌ "caffeine affects sleep."
2. **Self-monitor + goal + discrepancy (BCT 2.3 + 1.1 + 1.6).** Every recommendation
   should have: current state, target, gap.
3. **Prefer progress frame to deficit frame** (BCT 13.2). "You're 87 of 150 weekly
   MVPA min — 25 min today closes the gap" beats "You are 63 min short."
4. **Cite the research** (BCT 5.1, 6.1). Every recommendation must surface the
   research note ID(s) it derives from; UI shows the citation chip; tap → full note
   text. No uncited recommendations.
5. **One-to-three actions/day max.** Too many actions reduces adherence (choice
   paralysis). Top-3 by signal strength.
6. **Track adoption** (closes the loop on BCT 2.4). Users mark a recommendation as
   adopted / dismissed; system learns which recommendation types resonate.
7. **Avoid backfire**: never frame as "you're failing"; prefer "here's what would
   help."
8. **Mention dose-response, not absolutes.** "30 min of additional moderate activity
   tonight" beats "exercise more."
9. **Never present mortality numbers as personal prognosis.** Even research-grounded
   HRs are population-level. Frame as "associated with" not "will cause."

## Safety bounds

- **SAFETY-CRITICAL (rule 9):** never present a mortality number or population HR as
  a personal prognosis — "associated with," never "will cause." This mirrors the
  hard guardrail in `llm_health_advice_safety`, and unlike most such sentences in this
  corpus **it is true**: `insights/output_guard.py`'s hand-compiled rules
  `personal_death_risk_number` and `personal_life_expectancy_projection` block the
  answer — regardless of citations, grade or validator outcome — when a sentence carries
  both a second person ("you"/"your") and a death-risk figure or a life-expectancy
  projection. Population science without a "you" in the sentence still ships, by design.
  (Verified against the code 2026-08-01, #87.)
- Never use deficit/"you failed" framing for low-self-efficacy users (backfire risk).
  **Not enforced in code** — a rule for the coach, not a guardrail. (Corrected
  2026-08-01, #87; see *Healthee implementation* for which of the 9 rules do have code
  behind them.)

## Honesty & uncertainty

- **Most BCT-effect-size meta-analyses are on diet + physical activity**;
  generalization to sleep timing, alcohol cutoffs, stress management is weaker but
  mechanistically similar.
- **Engagement decay**: tailored interventions lose effect when users stop opening
  the app. Effect sizes above are conditional on continued use.
- **Backfire risk**: framing recommendations as "you failed your goal" reduces
  motivation in low-self-efficacy users (Bandura 1977). Prefer "progress" framing to
  "deficit" framing.
- **The BCT taxonomy was developed for designed interventions, not automated tools.**
  Mapping LLM-generated recommendations to BCT codes helps consistency but doesn't
  guarantee fidelity.

## Bottom line

**Act on confidently:** personalize to the user's own data, combine self-monitoring
+ goals + discrepancy, cite the research, cap at 1–3 progress-framed actions, and
track adoption. Generic "inform the user" advice barely works.

**Hold loosely:** the exact tailoring effect size for sleep/alcohol/stress domains
(extrapolated from diet+PA); persistence after engagement drops; BCT-fidelity of
LLM-generated (vs designed) recommendations.

## Coach Directives

1. Anchor every recommendation to the user's own data; never ship generic "inform"
   guidance. *(confidence: high)*
2. Use progress framing, never deficit/"you failed" framing (backfire risk). *(high)*
3. Cite the research note for every recommendation; no uncited items. *(high)*
4. Cap at 1–3 actions/day, ordered by signal strength. *(high)*
5. Prefer dose-response phrasing over absolutes. *(moderate)*
6. **SAFETY-CRITICAL:** never present a mortality number/population HR as personal
   prognosis — "associated with," not "will cause." *(high; **enforced in code** on
   every LLM surface by `insights/output_guard.py`'s `personal_death_risk_number` and
   `personal_life_expectancy_projection`, which fire on a death-risk figure or a
   life-expectancy claim in a second-person sentence. The second person is the gate, so
   citing the population hazard ratio plainly stays shippable — which is the point. #100)*

## References
- **Michie S, Richardson M, Johnston M, et al.** *The Behavior Change Technique
  Taxonomy (v1) of 93 hierarchically clustered techniques: building an international
  consensus for the reporting of behavior change interventions.* Ann Behav Med
  2013;46(1):81–95. The reference taxonomy.
- **Michie S, Abraham C, Whittington C, McAteer J, Gupta S.** *Effective techniques
  in healthy eating and physical activity interventions: a meta-regression.* Health
  Psychol 2009;28(6):690–701.
- **Kelly MP, Barker M.** *Why is changing health-related behaviour so difficult?*
  Public Health 2016;136:109–116. Argues information alone fails; behavior
  frameworks matter.
- **Krebs P, Prochaska JO, Rossi JS.** *A meta-analysis of computer-tailored
  interventions for health behavior change.* Prev Med 2010;51(3-4):214–221.
- **Lustria ML, Noar SM, Cortese J, et al.** *A meta-analytic review of stand-alone
  interventions to improve health outcomes through computer-tailored health
  communications.* J Health Commun 2013;18(9):1039–1069.
- **Locke EA, Latham GP.** *Building a practically useful theory of goal setting and
  task motivation.* Am Psychol 2002;57(9):705–717. Goal-setting theory; the
  empirical basis for SMART goals.
- **Patel MS et al.** step-goal + financial-incentive RCT (n=797). *Lancet Public
  Health* 2017. ~+1,200 daily-step difference vs control at 13 weeks.
- **Bandura A.** *Self-efficacy: toward a unifying theory of behavioral change.*
  Psychol Rev 1977 — basis for the backfire/self-efficacy caution.

## Healthee implementation & honesty policy

- **No `applies_to_metrics`** — this note governs how recs/coach *phrase and
  structure* advice, not a derived metric. It is the design basis consumed by
  `recommendations_engine_plan`.
- The 9 design rules are the enforceable contract: personalize-not-inform,
  self-monitor+goal+discrepancy, progress-not-deficit framing, cite-every-claim,
  ≤3 actions/day, track-adoption, no-backfire, dose-response-not-absolutes, and
  **no mortality-as-personal-prognosis** (rule 9). **Three of the nine are actually
  enforced (#87):** rule 9 by `insights/output_guard.py`, cite-every-claim by the
  citation validator plus `jobs/recs.py`'s inline-`[note_id]` and known-note checks
  (an uncited rec is dropped), and ≤3 actions/day by `jobs/recs.py::_MAX_RECS = 3`. The
  other six — personalize-not-inform, self-monitor+goal+discrepancy,
  progress-not-deficit, track-adoption, no-backfire, dose-response-not-absolutes — are
  rules for the coach to follow, not guardrails.
- Honesty rule: effect-size claims here are graded and mostly extrapolated from
  diet+PA meta-analyses; the coach states the moderate/small-but-consistent
  magnitudes plainly and never oversells tailoring.
