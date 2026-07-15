# Fasting × tracked-metrics — research dossier (WIP, verified evidence)

**Status:** raw verified evidence from the deep-research run of 2026-07-15. The
run reached the synthesis step but the session limit cut it before the final
merged note. **This dossier is the saved evidence, NOT the finished knowledge
note.** Next step (after session reset): author the unified-template note
`packages/knowledge/notes/intake/fasting.md` from this, verifying each citation
against its primary source (feedback: verify-primary-sources) and re-running the
5 unverified claims below.

Method: 5 search angles → 24 sources → 108 extracted claims → 25 adversarially
verified (3-vote). Result: **19 confirmed, 1 refuted, 5 unverified (errored on
session limit).** Raw journal + full output preserved (see end).

⚠ Coverage caveat: verification prioritized autonomic (HRV/RHR) + body-composition
claims. Sleep-architecture, temperature, respiratory-rate, VO₂max/Ramadan, and
safety/contraindication claims were extracted (in the raw journal) but mostly
NOT yet through the 3-vote gate — they must be verified before they enter the note.

---

## CONFIRMED (3-vote adversarial pass)

### Body weight & composition — IF is not superior to plain calorie restriction (STRONG)
- **TREAT RCT (Lowe 2020, JAMA Intern Med; n=116, 12wk):** 16:8 TRE gave no weight
  advantage over control — between-group −0.26 kg (P=.63). `PMC7522780` — vote 3-0.
- **Same RCT — lean-mass loss:** TRE lost significant lean mass; appendicular lean
  mass index between-group −0.16 kg/m² (P=.005); ~65% of weight lost was lean mass
  vs a normal 20–30%. `PMC7522780` — 3-0. *(This is the sharpest honest finding.)*
- **Same RCT — metabolic markers:** no significant improvement in fasting glucose,
  insulin, HbA1c, or lipids vs control over 12wk. `PMC7522780` — 3-0.
- **ADF vs daily CR (Trepanowski 2017, JAMA Intern Med; n=100, 12mo):** alternate-day
  fasting no better than daily calorie restriction (−6.0% vs −5.3%; diff −0.7%,
  95% CI −3.1 to 1.6). jamanetwork 2623528 — 3-0.
- **Same — body composition at 12mo:** fat-mass diff 0.0 kg (CI −2.4 to 2.4), lean
  diff 0.5 kg (CI −1.2 to 2.2) — no fat-loss or lean-sparing advantage over CR.
  jamanetwork 2623528 — 3-0.
- **TREAT-timing RCT (NEJM 2022, NEJMoa2114833; n=139, 12mo):** TRE (8am–4pm)+CR
  weight loss −8.0 kg vs CR-alone −6.3 kg, not significant (net −1.8 kg, P=0.11).
  — 3-0.
- **Same — everything else null:** body fat, lean mass, waist, BMI, BP, metabolic
  risk factors did not differ TRE+CR vs CR. — 3-0.
- **TRF magnitude (review PMC9696013):** TRF alone gives only 1–4% weight loss over
  1–12wk; clinically significant (>5%) loss needs TRF + calorie restriction. — 3-0.
- **Meta-analysis caveat (PMC12309044):** does NOT resolve lean-mass preservation or
  IF-vs-CR — lacked fat/lean breakdown and excluded direct CR comparisons. — 3-0.

### Glucose / insulin sensitivity (MODERATE)
- **TRF & insulin sensitivity (review PMC9696013):** TRF may improve insulin
  sensitivity and daytime glycemic variability in overweight/obese; early-TRF
  reduced HOMA-IR (Xie et al., n=82: −1.08 vs increases in controls). — 3-0.

### HRV — autonomic (the confounder the note must flag)
- **Acute fast raises vagal HRV (AJP-Regu 2021, ajpregu.00283.2021):** R-R rose
  992±30→1,059±37 ms; normalized HF power 55±3%→62±3% — higher parasympathetic tone
  during fasting. — 3-0.
- **Same — RHR down:** resting HR 69±2→65±2 bpm after fasting. — 3-0.
- **Same — mechanism:** muscle sympathetic nerve activity unchanged (16±11 vs 15±8
  bursts/min) → the shift is *increased vagal tone*, not reduced sympathetic outflow.
  — 2-0.
- **BUT acute 48h total fast LOWERS HRV (Chan/female subjects 2013, PMID 23403876):**
  SDNN and RMSSD both fell baseline→48h (P<0.001) — parasympathetic *withdrawal* with
  sympathetic activation. — 3-0. **← the key tension: short overnight fast ≠ prolonged
  total fast; direction of HRV depends on fast length.**
- **Same 48h study — sympathovagal shift:** reduced RMSSD + log-HF on head-up tilt =
  shift toward sympathetic dominance. — 3-0.
- **Prolonged 12-day fast RAISES vagal tone (GENESIS/Buchinger, Int J Obes 2025,
  s41366-025-01843-0 / PMC12532600):** RMSSD 27.16±10.5→32.92±17.65 ms (p=0.01)
  after vs before. — 2-1 and 2-0. ⚠ mislabeled "habitual" in extraction — it's a
  single supervised 12-day near-total fast (n=16, single-arm, no control) = WEAK
  design; reclassify as *prolonged fasting*, distinct from TRE/IF a wearable user does.
- **Same study — biphasic sympathetic:** early-fast sympathetic activation (p<0.05)
  then significant SNS decrease after (p=0.00007). — 3-0.
- **Same study — RHR acute vs habitual:** HR *down* after the fasting block
  (62.79→58.44 bpm, p<0.001) but only a slight non-significant rise *during* the fast
  (67.2→69.2, p=0.52). — 2-1. ⚠ verifier flagged instrument conflation (Polar H10 vs
  sphygmomanometer, different baselines) — must be checked before use.

## REFUTED (do NOT use)
- ✗ "IF produced clinically meaningful weight loss MD −3.73 kg vs control across 15
  RCTs (n=758)" — vote 0-3, source `PMC12309044`. The meta-analysis does not support
  this figure as stated.

## UNVERIFIED — errored on session limit, RE-RUN before use (not refuted)
1. SNS index decreased significantly over the 12-day fast (p=0.00007). — nature s41366-025-01843-0
2. Autonomic response to fasting is biphasic (early sympathetic → later parasympathetic). — nature s41366-025-01843-0
3. Acute 48h total fast lowers overnight HRV (SDNN & RMSSD, P<0.001) — vagal withdrawal. — researchgate 235604122
4. 48h fast → parasympathetic withdrawal + sympathetic activation as a stress response (wearable readiness during a long fast can reflect stress, not recovery). — researchgate 235604122
5. Systematic review of 6 RCTs (548 enrolled) — short/mid-term TRE does not typically worsen sleep. — PMC11322763

## STILL TO RESEARCH (extracted but not verified; in raw journal)
Sleep architecture (early vs late TRE — early-TRE improved actigraphy sleep efficiency;
late dinner PSG null in healthy young), temperature, respiratory rate, VO₂max /
Ramadan performance meta-analysis (Cherif/Chtourou 2020, Sports Med, PMID 31960369),
and safety/contraindications (disordered-eating risk — Clinical Diabetes & Endocrinology
2023, PMC10589984). These need the 3-vote pass before entering the note.

## Primary sources (verified quality = primary unless noted)
- PMC7522780 — Lowe 2020 TREAT RCT (JAMA Intern Med)
- jamanetwork 2623528 — Trepanowski 2017 ADF vs CR (JAMA Intern Med)
- nejm NEJMoa2114833 — Liu/Chen 2022 TRE timing RCT (NEJM)
- PMC12309044 — IF meta-analysis (caveated)
- PMC9696013 — TRF review
- PMC12532600 / nature s41366-025-01843-0 — GENESIS 12-day fast (Int J Obes 2025)
- PMID 23403876 — 48h fast HRV, female subjects 2013
- ajpregu.00283.2021 — acute fast vagal HRV (AJP-Regu 2022)
- PMC11322763 — TRE sleep systematic review
- icr-heart.com — flagged UNRELIABLE by the harness; do not cite
- researchgate 235604122 — 48h fast HRV/cortisol (verify via primary journal, not RG)
- Additional (unverified): frontiersin 1823259, PMC8131073, PMC12199060, PMC9634110,
  medrxiv 2024.10.05, springer s40279-020-01257-0 (Ramadan meta), PMC7284994,
  PMID 20100529, PMID 34198990, PMC10589984 (disordered-eating risk),
  sciencedirect S1471015322000873, PMC8295756

---
Raw run: journal + full output under the workflow transcript dir
`wf_2cb1cb7f-2a9` (resumable via the workflow script with resumeFromRunId to
re-run just the 5 unverified + synthesis after the session resets).
