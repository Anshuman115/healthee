---
name: training-load-acwr
title: Training Load & Acute:Chronic Workload Ratio (ACWR)
category: load-recovery
aliases: [acwr, acute chronic workload ratio, acute:chronic, workload ratio, training load ratio, acute load, chronic load, ewma acwr, rolling average acwr, sweet spot, 10 percent rule, ten percent rule, load spike, training monotony, workload management]
related: [fitness-fatigue-form, training-stress-score, sleep-and-recovery, heart-rate-variability, periodization, individualization]
metrics: [computeACWR, acuteLoad, chronicLoad, trainingLoad, weeklyLoadRamp]
units: ratio (AU/AU, dimensionless); load in AU (TSS, sRPE·min, km, or min)
evidence_overall: Contested
last_reviewed: 2026-06-29
---

# Training Load & Acute:Chronic Workload Ratio (ACWR)

## Summary
The Acute:Chronic Workload Ratio (ACWR) compares **recent** training load (the
"acute" window, typically the last 7 days) against **habitual** load (the
"chronic" window, typically the trailing ~28 days), as a single ratio. The intent
is to flag when a runner is doing much more than their body is prepared for. The
popularised reading is a **0.8–1.3 "sweet spot"** with **>1.5 = elevated injury
risk** [Gabbett 2016]. The single most important coaching takeaway: **ACWR is a
useful descriptive signal for spotting load spikes — never a verdict.** Its
original "injury-prediction" claim has been seriously discredited (mathematical
coupling, ratio artefacts, non-reproducible cut-offs, and an RCT showing managing
by ACWR did not reduce injuries [Impellizzeri 2020; Lolli 2019; Wang 2020;
Dalen-Lorentsen 2021]). Treat the underlying principle — *avoid sudden spikes,
build chronic load patiently* — as the durable truth, and the specific 0.8–1.3 /
1.5 numbers as soft heuristics, not guardrails.

## What it is
ACWR is a ratio of two rolling summaries of the same training-load stream:

- **Acute load** — the dose accumulated in a short, recent window (**7 days**),
  interpreted as *fatigue* / current demand.
- **Chronic load** — the average dose over a longer window (**~28 days**, i.e. 4
  weeks), interpreted as *fitness* / preparedness.

`ACWR = acute load / chronic load`

The "load" itself can be any quantified dose: session RPE × minutes (sRPE, the
most common in team sport), Training Stress Score (TSS), TRIMP, GPS distance, or
even raw kilometres/minutes for runners. ACWR is **load-currency agnostic** — the
ratio behaves similarly whatever you feed it, which is both its convenience and
part of its statistical fragility.

Interpretation bands as popularised [Gabbett 2016]:

| ACWR | Label | Narrative |
|---|---|---|
| < 0.8 | Undertraining / detraining zone | Doing less than habitual; "lost fitness" or recovering |
| **0.8 – 1.3** | **"Sweet spot"** | Load roughly matched to preparedness |
| 1.3 – 1.5 | Caution | Ramping faster than chronic base |
| **> 1.5** | **"Danger zone"** | Acute spike well beyond preparedness; flagged high-risk |

These bands are **descriptive conventions**, not validated thresholds — see *The
evidence* and *Honesty & uncertainty*.

## Physiology / mechanism
The conceptual appeal is real and rests on a sound principle: **tissues adapt to
the loads they are repeatedly exposed to**, and adaptation lags exposure. Bone,
tendon, muscle and the cardiovascular system remodel over weeks; a load the body
has been *chronically* exposed to is tolerated, while a sudden *acute* surge
outpaces the tissue's current remodelling capacity, raising mechanical and
metabolic strain before adaptation catches up. ACWR is an attempt to operationalise
the fitness–fatigue idea (see `fitness-fatigue-form`): chronic load ≈ fitness,
acute load ≈ fatigue, and their ratio ≈ relative readiness.

A genuinely important corollary that survives the critique: **a high chronic load
is protective** — well-trained athletes with a large chronic base tolerate the
same absolute acute spike far better than under-prepared athletes [Hulin 2016;
Gabbett 2016]. "Training smarter *and* harder" — building robustness through
consistent high chronic load — is the paper's enduring message, more so than any
specific ratio cut-off.

The problem is the **leap from this plausible mechanism to a precise, ratio-based
injury predictor**. The mechanism justifies *"don't spike load; build a base"*; it
does **not** justify *"keep ACWR below 1.5 and you will avoid injury."* That leap
is where the science breaks down.

## The evidence

### Origin and supportive cohort studies
- **[Probable, as a principle]** Spikes in acute load and rapid load increases are
  associated with higher injury risk; high chronic load is protective — *prospective
  cohort studies, elite team athletes*. The seminal observations: elite cricket fast
  bowlers had higher injury risk in the week after acute-load spikes [Hulin 2014];
  elite rugby league players with ACWR >1.6 showed markedly elevated injury
  likelihood, while high chronic workload *reduced* risk [Hulin 2016]. Gabbett's
  narrative review synthesised these into the "sweet spot" figure and the 0.8–1.3 /
  >1.5 bands [Gabbett 2016, *BJSM*]. **Important caveat:** Gabbett 2016 is a
  **narrative review**, not a meta-analysis, and the headline figure has since been
  shown to be partly schematic rather than data-derived [Impellizzeri 2019/2020].

- **[Emerging]** A 2025 systematic review and meta-analysis (Qin et al., 22 single-arm
  cohort studies) found a statistically significant pooled association between
  elevated ACWR and injury (ES = 0.72, 95% CI 0.60–0.82), and lower injury incidence
  inside the 0.8–1.3 band (ES = 0.56) than below 0.8 (0.74) or above 1.3 (0.77).
  **But** the authors explicitly flagged wide confidence intervals and high
  heterogeneity, concluding ACWR "should be used with caution" and is **not** an
  absolute predictor [Qin 2025]. Meta-analysed *association* ≠ validated *prediction*.

### EWMA vs rolling average
- **[Probable]** When ACWR is computed, **exponentially weighted moving averages
  (EWMA)** are mechanistically preferable to simple rolling averages (RA) and
  empirically more sensitive to injury likelihood — *prospective cohort, elite
  Australian football* [Murray 2017, *BJSM*]; conceptual rationale in [Williams 2017,
  *BJSM*]. RA treats every day in the window equally and then drops it abruptly (the
  "switch-on/switch-off" artefact), ignoring that fitness and fatigue **decay
  progressively**. EWMA weights recent days more heavily via a decay constant
  (λ = 2/(N+1)), better matching the impulse–response model (see `fitness-fatigue-form`).
  **Caveat:** EWMA is a *better way to compute a flawed-concept metric* — it improves
  the arithmetic, not the underlying validity. Systematic comparison finds RA and EWMA
  often disagree and neither is clearly superior for prediction.

### The running-specific load literature (more relevant to Daud)
- **[Contested → Myth, as a fixed rule]** The **"10% per week" rule** (cap weekly
  mileage growth at 10%) has **no supporting evidence**. A systematic review found no
  justification for it [Damsted 2018, *IJSPT*]; an RCT in novice runners (Buist et al.,
  cited therein) found no difference in injury between a ~10% graded build and a ~24%
  build. The 10% figure is **practitioner folklore**, not a finding.
- **[Probable]** *Large* progressions do matter, even if 10% is arbitrary. Novice
  runners increasing weekly distance by **>30% over 2 weeks** had higher
  distance-related injury risk than those increasing <10% — *prospective cohort, ~870
  novices* [Nielsen 2014, *JOSPT*]. The signal is at large spikes, not fine-grained
  percentages.
- **[Emerging, important]** A large 18-month cohort (5,205 runners, 588,071 sessions)
  found the risk lives at the **single-session** level, not the weekly ratio: a spike
  of **>10% in a single run's distance vs the longest run in the prior 30 days** raised
  overuse-injury hazard (HRR ≈ 1.64 for 10–30%; 1.52 for 30–100%; 2.28 for >100%).
  Strikingly, **weekly ACWR-style metrics were *inversely* associated** with injury in
  this dataset (higher weekly spikes → lower risk) [Frandsen 2025, *BJSM*]. This
  directly challenges the weekly-ratio framing for runners and points instead to
  *long-run progression* as the actionable lever.

### The critique — why ACWR is not a verdict
- **[Established, methodological]** **Mathematical coupling.** Because the acute window
  is a *subset* of (or shares input with) the chronic window, numerator and denominator
  are not independent; this induces **spurious correlation** with injury regardless of
  any true relationship [Lolli 2019, *BJSM*]. "Uncoupling" the windows changes results.
- **[Established, methodological]** **Conceptual and statistical pitfalls.** ACWR
  magnifies the effect of acute load **without adding predictive value** beyond acute
  load alone; ratios are unstable when chronic load is low (a small denominator
  inflates the ratio); discretising ACWR into bands and choosing cut-offs invites false
  precision and analytical flexibility [Impellizzeri 2020, *IJSPP*]. The widely
  reproduced "sweet-spot" figure was shown to be **schematic, not data-derived**
  [Impellizzeri 2019, SportRxiv preprint].
- **[Established, re-analysis]** **The association is fragile.** When ACWR is modelled
  as a continuous variable and outliers handled properly, the ACWR–injury relationship
  **weakens or disappears**; reported odds ratios are inflated by the methodology
  itself [Wang 2020, *Sports Medicine*]. *Association does not equal prediction.*
- **[Probable — the only RCT, and it is null]** **No demonstrated benefit as an
  intervention.** In a cluster RCT of 482 elite youth footballers, teams whose loads were
  managed according to published ACWR principles for a full season had **no fewer**
  injuries or illnesses than control teams [Dalen-Lorentsen 2021, *BJSM*]. (Limitations:
  high dropout and low adherence — so this is **"no demonstrated benefit," not proof of
  uselessness**. It is a *single* trial, so it cannot by itself be graded Established;
  but it is the only RCT to date and its result is null, which is why no firm "manage by
  ACWR" directive can be supported.)

**Consistency verdict:** the *principle* (avoid spikes, build chronic load, high base
is protective) is **broadly consistent** across cohorts. The *specific ratio metric as
an injury predictor or management tool* is **inconsistent and largely refuted** —
significant in some cohorts, null or reversed in others, and failing its one RCT.

## How we compute it
Owned by `@daud/core` (`computeACWR`, `acuteLoad`, `chronicLoad`). Daud computes
ACWR from its internal load currency (TSS-equivalent; see `training-stress-score`)
and also surfaces a **simpler, more defensible running-specific ramp signal**.

**Rolling-average ACWR (reference/legacy):**
```
acute   = sum of daily load over last 7 days
chronic = (sum of daily load over last 28 days) / 4     # 4 weeks, same units as acute
ACWR_RA = acute / chronic
```

**EWMA ACWR (preferred when ACWR is shown):**
```
λ_acute    = 2 / (7  + 1) = 0.250
λ_chronic  = 2 / (28 + 1) ≈ 0.069
EWMA_today = load_today · λ + EWMA_yesterday · (1 − λ)
ACWR_EWMA  = EWMA_acute / EWMA_chronic
```

**Running ramp (the signal Daud should lean on):**
```
weekly_ramp   = (this_week_load − last_week_load) / last_week_load
longrun_spike = (planned_long_run_km − max_long_run_km_prior_30d) / max_long_run_km_prior_30d
```

**Estimation-error flags:**
- ACWR is **undefined/unstable for the first ~28 days** of data and whenever chronic
  load is near zero (post-layoff, new user) — a small denominator manufactures scary
  ratios. Suppress or heavily down-weight ACWR until ≥4 weeks of data exist.
- The metric inherits all error in the load estimate (sRPE recall bias, TSS pacing/HR
  noise). Garbage-in propagates directly to the ratio.

## How the coach uses it
ACWR is a **conversation-starter and a guardrail-of-last-resort**, never the basis
of a confident injury claim. Use it to *notice* and *ask*, not to *diagnose*.

**By stage:**
- **Stage 1 (beginner):** Do **not** show or reason from ACWR — chronic load is tiny,
  the ratio is meaningless and alarmist. Govern progression with the **long-run spike**
  and **weekly ramp** signals instead, and absolute rest-day rules. Coach line: "Let's
  add a little each week and keep your longest run from jumping too much."
- **Stage 2 (developing):** ACWR becomes a **soft monitoring trend**. A sustained climb
  toward ~1.5+ is a prompt to *check in* ("big jump this week — how are the legs?"),
  cross-referenced against HRV, sleep, RPE and soreness — not an automatic cutback.
- **Stage 3 (racing/peaking):** ACWR is most useful for **context**: deliberate
  overload blocks will push it >1.3 by design, and a taper will push it <0.8 by design.
  The coach must read ACWR *through the plan's intent*, never flagging an intended taper
  as "detraining" or an intended overload as "danger."

**Cross-check rules (mandatory):**
- Never act on ACWR alone. Weight it **below** the runner's subjective wellness, HRV
  trend, sleep, and pain/soreness reports (see `heart-rate-variability`,
  `sleep-and-recovery`). A pain report at ACWR 1.0 outranks a clean ACWR every time.
- For runners specifically, prefer **long-run progression** and **weekly ramp** over the
  weekly ratio — the strongest running data point there [Frandsen 2025; Nielsen 2014].
- Treat any single ACWR number as ±wide uncertainty; act on **trends over ~2–3 weeks**,
  not day-to-day wobble.

## Honesty & uncertainty
This is the section that matters most for this metric.

- **The numbers are soft.** 0.8–1.3 and 1.5 are **convention, not validated cut-offs**.
  They originated largely from team-sport (rugby, cricket, football, AFL) populations
  with very different loading patterns to distance runners, and even there they don't
  reproduce reliably.
- **Mathematical coupling and ratio instability** mean ACWR can flag "danger" purely as
  an arithmetic artefact — especially when chronic load is low (returning from injury,
  new runner, post-taper) [Lolli 2019; Impellizzeri 2020].
- **Association ≠ prediction ≠ causation.** Even where ACWR correlates with injury, it
  has not been shown to *predict* individual injuries usefully, and managing by it did
  not *prevent* them in the one RCT [Wang 2020; Dalen-Lorentsen 2021].
- **Reverse causation / confounding.** Fitter, more robust athletes both train more
  (higher chronic load) and get injured less — so "high chronic load is protective" may
  partly reflect *who survives to train hard*, not a cleanly manipulable lever.
- **The 10% rule is folklore.** Do not present it as evidence-based; the evidence is that
  *very large* jumps raise risk, with no magic percentage [Damsted 2018].
- **It says nothing about *what* you did.** Two identical ACWRs can hide totally different
  risk — a long-run distance spike vs an interval-intensity spike load identically but
  differ in tissue risk. Load monotony, intensity distribution, surface, footwear and
  biomechanics are all invisible to the ratio.
- **What we still don't know:** the right window lengths for runners, whether
  individualised baselines beat population bands, and whether *session-level* spike
  monitoring (the emerging running signal) outperforms any weekly ratio. Daud should
  treat session-level long-run progression as the more promising lever and keep ACWR as
  a secondary, clearly-hedged context signal.

## Safety bounds
ACWR is **not** a safety-critical guardrail and must not be used as a hard gate that
blocks training, because its false-positive and false-negative rates are unacceptable
for that role. The defensible hard bounds Daud mirrors in `@daud/core` come from the
*running progression* literature, not from the ratio:

- **Hard:** Flag and require explicit user confirmation before prescribing a **long run
  >10% longer than the longest run in the prior 30 days** (down-weight, suggest a smaller
  step) [Frandsen 2025] — and never auto-prescribe a single-run jump >30% to a runner
  with <6 months consistent base.
- **Hard:** Suppress ACWR-driven warnings entirely when chronic-load history < 28 days or
  chronic load ≈ 0 (ratio undefined/unstable).
- **Soft:** Surface a *gentle* check-in (not a block) if EWMA-ACWR trends above ~1.5 for
  multiple days, always cross-checked with wellness/HRV/pain.
- **Override:** Any reported pain, injury, or red-flag wellness signal overrides every
  "safe" ACWR reading.

## Bottom line

**Act on confidently (conclusive):**
- Avoid **sudden large spikes** in training load; *large* progressions (e.g. >30% over two
  weeks) raise injury risk — this is the well-supported, multi-cohort core principle
  [Nielsen 2014]. The newer, *emerging* refinement that the risk concentrates at the single
  **long-run distance jump** is promising but rests on one large cohort [Frandsen 2025].
- **Build chronic load patiently and consistently.** This is the safe, actionable lever.
  A higher, well-earned chronic base is *associated* with better load tolerance and lower
  injury risk [Hulin 2016; Gabbett 2016] — though note this comes from **observational
  cohorts and a narrative review**, and the "protective" effect is partly confounded by
  who survives to train hard (see *Honesty & uncertainty*), so treat "build a base" as the
  confident takeaway and "chronic load *causally* protects" as the looser one.
- The **"10% per week" rule is not evidence-based** — don't present it as such, while still
  discouraging very large jumps [Damsted 2018].

*(Implementation preference, not conclusive: if you compute ACWR at all, EWMA is
mechanistically preferable to rolling averages [Murray 2017] — but this only improves the
arithmetic, and neither method is clearly superior for actually predicting injury. Graded
[Probable], so it lives here as a footnote, not in the confident column.)*

**Hold loosely (unsettled):**
- The specific **0.8–1.3 sweet spot and >1.5 danger** thresholds — descriptive heuristics,
  not validated predictors [Impellizzeri 2020; Qin 2025].
- ACWR as an **injury predictor or management tool** — refuted by re-analysis and a null RCT
  [Wang 2020; Lolli 2019; Dalen-Lorentsen 2021]. Use it as a *signal to ask questions*, not
  a decision rule.
- Whether weekly ratios beat **session-level progression monitoring** for runners — emerging
  evidence favours the latter [Frandsen 2025].

## Coach Directives

- **D1 — [Probable]** Discourage sudden large increases in training load; prioritise gradual,
  consistent progression. *Principle is well-supported; exact rate is not.*
- **D2 — [Emerging, running-specific]** Flag any planned long run **>10% longer** than the
  runner's longest run in the prior 30 days and propose a smaller step; require explicit
  confirmation before exceeding it. Mirror in `@daud/core`. *(Evidence is a single large
  cohort [Frandsen 2025], not yet replicated — this is a low-cost, conservative default
  rather than a settled threshold.)*
- **D3 — [Probable]** Never auto-prescribe a **>30% single-run or 2-week distance jump** to a
  runner without ≥6 months consistent base. [Nielsen 2014]
- **D4 — [Established, methodological]** Do **not** treat ACWR as an injury predictor or a hard
  training gate; use it only as a hedged, secondary monitoring signal. [Impellizzeri 2020;
  Wang 2020; Dalen-Lorentsen 2021]
- **D5 — [Probable]** When ACWR is shown, compute it with **EWMA** (λ_acute=0.25,
  λ_chronic≈0.069), not rolling averages. [Murray 2017]
- **D6 — [Established]** Suppress all ACWR output when chronic history < 28 days or chronic
  load ≈ 0 (ratio unstable/undefined).
- **D7 — [Probable]** If EWMA-ACWR trends > ~1.5 for several days, raise a **non-blocking
  check-in**, cross-checked against HRV, sleep, RPE and pain — never an automatic cutback.
- **D8 — [Established]** Any reported pain/injury or red-flag wellness signal **overrides** a
  "safe" ACWR reading. [practitioner consensus + safety principle]
- **D9 — [Myth/Refuted]** Do **not** cite the "10% per week" rule as evidence-based; discourage
  *large* jumps without quoting a false-precision percentage. [Damsted 2018]
- **D10 — [Probable]** In Stage 1 (beginner), do not surface or reason from ACWR at all; govern
  progression by long-run spike and weekly-ramp signals plus rest-day rules.

## Key references

- Gabbett, T. J. (2016). *The training–injury prevention paradox: should athletes be training
  smarter and harder?* British Journal of Sports Medicine, 50(5), 273–280.
  https://doi.org/10.1136/bjsports-2015-095788
- Hulin, B. T., Gabbett, T. J., Caputi, P., Lawson, D. W., & Sampson, J. A. (2016). *Low chronic
  workload and the acute:chronic workload ratio are more predictive of injury than between-match
  recovery time: a two-season prospective cohort study in elite rugby league players.* British
  Journal of Sports Medicine, 50(16), 1008–1012. https://doi.org/10.1136/bjsports-2015-095364
- Hulin, B. T., Gabbett, T. J., Blanch, P., Chapman, P., Bailey, D., & Orchard, J. W. (2014).
  *Spikes in acute workload are associated with increased injury risk in elite cricket fast
  bowlers.* British Journal of Sports Medicine, 48(8), 708–712.
  https://doi.org/10.1136/bjsports-2013-092524
- Murray, N. B., Gabbett, T. J., Townshend, A. D., & Blanch, P. (2017). *Calculating
  acute:chronic workload ratios using exponentially weighted moving averages provides a more
  sensitive indicator of injury likelihood than rolling averages.* British Journal of Sports
  Medicine, 51(9), 749–754. https://doi.org/10.1136/bjsports-2016-097152
- Williams, S., West, S., Cross, M. J., & Stokes, K. A. (2017). *Better way to determine the
  acute:chronic workload ratio?* British Journal of Sports Medicine, 51(3), 209–210.
  https://doi.org/10.1136/bjsports-2016-096589
- Impellizzeri, F. M., Tenan, M. S., Kempton, T., Novak, A., & Coutts, A. J. (2020).
  *Acute:Chronic Workload Ratio: Conceptual Issues and Fundamental Pitfalls.* International
  Journal of Sports Physiology and Performance, 15(6), 907–913.
  https://doi.org/10.1123/ijspp.2019-0864
- Lolli, L., Batterham, A. M., Hawkins, R., Kelly, D. M., Strudwick, A. J., Thorpe, R., Gregson,
  W., & Atkinson, G. (2019). *Mathematical coupling causes spurious correlation within the
  conventional acute-to-chronic workload ratio calculations.* British Journal of Sports
  Medicine, 53(15), 921–922. https://doi.org/10.1136/bjsports-2017-098110
- Wang, C., Vargas, J. T., Stokes, T., Steele, R., & Shrier, I. (2020). *Analyzing Activity and
  Injury: Lessons Learned from the Acute:Chronic Workload Ratio.* Sports Medicine, 50(7),
  1243–1254. https://doi.org/10.1007/s40279-020-01280-1
- Dalen-Lorentsen, T., Bjørneboe, J., Clarsen, B., Vagle, M., Fagerland, M. W., & Andersen, T. E.
  (2021). *Does load management using the acute:chronic workload ratio prevent health problems? A
  cluster randomised trial of 482 elite youth footballers of both sexes.* British Journal of
  Sports Medicine, 55(2), 108–114. https://doi.org/10.1136/bjsports-2020-103003
- Qin, W., Li, R., & Chen, L. (2025). *Acute to chronic workload ratio (ACWR) for predicting
  sports injury risk: a systematic review and meta-analysis.* BMC Sports Science, Medicine and
  Rehabilitation, 17, 285. https://doi.org/10.1186/s13102-025-01332-x
- Nielsen, R. O., Parner, E. T., Nohr, E. A., Sørensen, H., Lind, M., & Rasmussen, S. (2014).
  *Excessive progression in weekly running distance and risk of running-related injuries: an
  association which varies according to type of injury.* Journal of Orthopaedic & Sports Physical
  Therapy, 44(10), 739–747. https://doi.org/10.2519/jospt.2014.5164
- Damsted, C., Glad, S., Nielsen, R. O., Sørensen, H., & Malisoux, L. (2018). *Is there evidence
  for an association between changes in training load and running-related injuries? A systematic
  review.* International Journal of Sports Physical Therapy, 13(6), 931–942.
  https://doi.org/10.26603/ijspt20180931
- Frandsen, J. S. B., Hulme, A., Parner, E. T., et al. (2025). *How much running is too much?
  Identifying high-risk running sessions in a 5200-person cohort study.* British Journal of Sports
  Medicine, 59(17), e109380. https://doi.org/10.1136/bjsports-2024-109380
- Impellizzeri, F. M., Woodcock, S., McCall, A., Ward, P., & Coutts, A. J. (2019). *The
  acute-chronic workload ratio-injury figure and its 'sweet spot' are flawed.* SportRxiv preprint.
  https://doi.org/10.31236/osf.io/gs8yu
