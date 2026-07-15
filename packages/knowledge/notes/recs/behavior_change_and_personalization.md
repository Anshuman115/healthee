---
id: behavior_change_and_personalization
topic: What actually changes health behavior — BCT taxonomy, self-monitoring, and personalization effect sizes
evidence_grade: 3
applies_to_metrics: []
applies_to_interventions: []
tags: [recs, behavior-change, methodology, personalization]
last_reviewed: 2026-05-15
---

## Finding

The behavior-change literature converges on a small set of techniques
that reliably move health-related behavior in self-monitoring contexts.
Generic information delivery (e.g., "exercise more", "drink less
caffeine") has near-zero effect size in meta-analyses; **personalized**
feedback anchored to the individual's own data has medium effect sizes,
and **multi-technique** interventions outperform single-technique ones.

The most evidence-supported techniques for a self-tracking app like
this project (from Michie et al. BCT Taxonomy v1, 93 techniques):

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

## Effect size

- **Michie 2009 meta-regression** (n=122 studies of physical-activity
  and diet interventions): interventions including BCT 2.3 (self-
  monitoring of behavior) AND at least one other goal/feedback BCT
  (1.1, 1.5, 1.6) had ~2× the effect size of interventions without
  these. Effect sizes from g=0.20 (single-technique) up to g=0.45
  (multi-technique combining self-monitoring + goals + feedback).
- **Kelly & Barker 2016** synthesis: knowledge-based interventions
  ("inform the user") have effect sizes near zero; the techniques that
  work are behavioral, not informational.
- **Krebs 2010 meta-analysis** (Prev Med, n=88 computer-tailored
  intervention studies): tailored interventions had a small but
  consistent effect (mean d=0.07–0.17 depending on outcome) over
  non-tailored controls. Effect compounds with adherence and depth
  of personalization (data-driven > demographic > generic).
- **Lustria 2013 meta-analysis** (J Health Commun, n=40 trials): web-
  based tailored health communication d=0.139 (95% CI 0.111–0.166)
  on outcomes vs untailored.
- **Patel 2017** (Lancet Pub Health, n=797 RCT): financial-incentive
  + step-goal interventions had ~+1,200 daily-step difference vs
  control at 13 weeks; persistence after incentive removal was
  partial (BCT 10.7 self-incentive sustains but weaker than active).

## Evidence strength

- **Michie S, Richardson M, Johnston M, et al.** *The Behavior Change
  Technique Taxonomy (v1) of 93 hierarchically clustered techniques:
  building an international consensus for the reporting of behavior
  change interventions.* Ann Behav Med 2013;46(1):81–95. The
  reference taxonomy.
- **Michie S, Abraham C, Whittington C, McAteer J, Gupta S.**
  *Effective techniques in healthy eating and physical activity
  interventions: a meta-regression.* Health Psychol 2009;28(6):690–701.
- **Kelly MP, Barker M.** *Why is changing health-related behaviour so
  difficult?* Public Health 2016;136:109–116. Argues information
  alone fails; behavior frameworks matter.
- **Krebs P, Prochaska JO, Rossi JS.** *A meta-analysis of computer-
  tailored interventions for health behavior change.* Prev Med 2010;
  51(3-4):214–221.
- **Lustria ML, Noar SM, Cortese J, et al.** *A meta-analytic review
  of stand-alone interventions to improve health outcomes through
  computer-tailored health communications.* J Health Commun 2013;
  18(9):1039–1069.
- **Locke EA, Latham GP.** *Building a practically useful theory of
  goal setting and task motivation.* Am Psychol 2002;57(9):705–717.
  Goal-setting theory; the empirical basis for SMART goals.

## Caveats

- Most BCT-effect-size meta-analyses are on diet + physical activity;
  generalization to sleep timing, alcohol cutoffs, stress management
  is weaker but mechanistically similar.
- **Engagement decay**: tailored interventions lose effect when users
  stop opening the app. Effect sizes above are conditional on
  continued use.
- **Backfire risk**: framing recommendations as "you failed your goal"
  reduces motivation in low-self-efficacy users (Bandura 1977).
  Prefer "progress" framing to "deficit" framing.
- The BCT taxonomy was developed for designed interventions, not
  automated tools. Mapping LLM-generated recommendations to BCT codes
  helps consistency but doesn't guarantee fidelity.

## Operational use — design rules for the recs engine

1. **Personalize, don't inform.** Every recommendation must be
   anchored to the user's own data, not generic guidance. ✅
   "Your caffeine after 14:30 lost ~24 min TST (n=22)" — ❌ "caffeine
   affects sleep."
2. **Self-monitor + goal + discrepancy (BCT 2.3 + 1.1 + 1.6).**
   Every recommendation should have: current state, target, gap.
3. **Prefer progress frame to deficit frame** (BCT 13.2). "You're 87
   of 150 weekly MVPA min — 25 min today closes the gap" beats "You
   are 63 min short."
4. **Cite the research** (BCT 5.1, 6.1). Every recommendation must
   surface the research note ID(s) it derives from; UI shows the
   citation chip; tap → full note text. No uncited recommendations.
5. **One-to-three actions/day max.** Too many actions reduces
   adherence (choice paralysis). Top-3 by signal strength.
6. **Track adoption** (closes the loop on BCT 2.4). Users mark a
   recommendation as adopted / dismissed; system learns which
   recommendation types resonate.
7. **Avoid backfire**: never frame as "you're failing"; prefer "here's
   what would help."
8. **Mention dose-response, not absolutes.** "30 min of additional
   moderate activity tonight" beats "exercise more."
9. **Never present mortality numbers as personal prognosis.** Even
   research-grounded HRs are population-level. Frame as "associated
   with" not "will cause."
