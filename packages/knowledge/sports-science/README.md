# @daud/knowledge — Daud's physiology knowledge layer

This package is the **validated sports-science library** the Daud AI coach is
required to reason *with* and cite. It is one of the three grounded sources the
coach must use — alongside the runner's own data and the deterministic
computed-metrics layer in `@daud/core`. Every doc grades its own certainty so the
coach can be calibrated: confident where the science is strong, hedged where it is
genuinely uncertain.

How the coach uses it (see **[METHODOLOGY.md](./METHODOLOGY.md)** for the full
contract):

1. **Retrieval** — per query, the Coach module pulls relevant docs into context by
   `name` / `aliases` / `category` (in this repo: the generated
   [`../manifest.json`](../manifest.json), read by `insights/manifest.py`).
2. **Grounding** — the AI reasons from the retrieved docs and may cite them.
3. **Directives** — each doc's **Coach Directives** block is the machine-applicable
   output. The cross-cutting digest lives in
   **[COACHING-RULES.md](./COACHING-RULES.md)**. A directive becomes a hard guardrail
   the AI cannot override **only** when its note declares it in frontmatter
   (`safety_critical: [5, 6]`) and a rule for it exists in
   `insights/guard_directives.py`; a test asserts the two sets are equal, both ways
   (#87). *(This line used to say safety-critical directives were "mirrored as hard
   guardrails in `@daud/core`" — a module that exists nowhere. No sports-science doc
   currently declares a marker, so **none** of the directives in this collection is
   enforced in code today.)*
4. **Calibration** — the AI's confidence and phrasing track each claim's evidence
   grade (Established → Probable → Emerging → Contested → Myth/Refuted).

Evidence grades: **Established** (RCTs / meta-analyses / decades of replication) ·
**Probable** (good evidence, some open questions) · **Emerging** (early, unsettled)
· **Contested** (experts genuinely disagree). The "Evidence" column below is each
doc's *overall* grade — individual claims inside a doc carry their own grade.

> **The manifest** (`../manifest.json`) is generated from the docs' frontmatter by
> `../tools/gen_manifest.py` — never hand-edit it. **This index is not**: in the
> Healthee monorepo it is a hand-maintained table, so a doc that moves must be
> fixed here by hand. (The "regenerate this index" instruction inherited from the
> upstream Daud package was false here, and is why the readiness row pointed at a
> file that no longer exists.)

> **Upstream artefacts that do not exist in this repo.** This package was imported
> from Daud. Its `@daud/core` guardrail modules and the typed retrieval manifest at
> `src/index.ts` were **not** imported — retrieval here runs off `../manifest.json`
> via `insights/manifest.py`, and the hard guardrails live in
> `insights/output_guard.py`. Treat every `@daud/*` / `src/index.ts` reference below
> as a description of the upstream package, not a path you can open.
>
> **Audit 2026-08-01 (#83b) — how far that disclaimer actually reaches.** `@daud/core`
> was confirmed to exist nowhere: not in this repo, not in `~/projects/healthee-legacy`,
> not in any `package.json`/`pyproject.toml`, and never in git history (the string
> entered as prose). 96 references across 29 notes. Two consequences the
> package-level disclaimer does NOT cover, because a retriever pulls one note's
> section, not this README:
>
> 1. **Numbers whose only stated authority was the module.** Fixed in this pass:
>    `cadence` (the 5% cadence-fade threshold and `CADENCE_FADE_FRACTION` — removed,
>    no primary source found), `aerobic-decoupling` (the <5/5–10/>10% bands —
>    relabelled TrainingPeaks practitioner convention), `heart-rate-zones` (the %HRR
>    band table, half-open convention and sub-50% rule — relabelled convention; the
>    Tanaka/Karvonen *formulas* were always properly cited), `maximum-heart-rate` (the
>    ~220 bpm and 15–20 bpm/s artefact bounds — relabelled our engineering judgement).
>    **Closed 2026-08-01 (#88):** `pace-zones`'s five speed-fraction band boundaries
>    and `training-stress-score`'s power→rTSS→hrTSS→sRPE preference order were each
>    searched for a primary source, **none was found**, and both now say so in place of
>    the fictional module. `fitness-fatigue-form`'s 42/7 turned out **not** to be a
>    phantom-source case — its trail (Banister's fits, rounded by TrainingPeaks, [Allen
>    & Coggan 2019]) is real and was already stated; only its `@daud/core`
>    implementation claim was false. None of the three is implemented in `apps/`; they
>    are prompt constants, which is how an unsourced table still reaches a user.
> 2. **~24 notes asserted enforcement that did not exist — CLOSED 2026-08-01 (#87),
>    from both ends.** Every "mirrored as a hard guardrail in `@daud/core`, the AI may
>    not override" line was false twice over: the module is fictional, AND
>    `insights/output_guard.py` read nothing from the corpus. Both halves are now
>    addressed. A note can now MAKE the claim truthfully — `safety_critical` in
>    frontmatter, validated by `gen_manifest.py`, compiled by
>    `insights/guard_directives.py`, bijected by `tests/insights/test_guard_directives.py`
>    — and every note that does **not** declare one has had its enforcement sentence
>    rewritten to say plainly that the rule is for the coach to follow, not a guarantee.
>    Four directives are marked so far, all in `notes/`: `napping` D5,
>    `hydration_everyday` D5/D6, `late_eating_sleep` D5. **No sports-science doc is
>    marked**, so nothing in this collection is enforced — which the docs now say.

---

## Metrics

The measurable signals the coach reads from a runner's data.

| Doc | What it is (one line) | Evidence | Maps to (`@daud/core`) |
|---|---|---|---|
| [Maximum Heart Rate (HRmax)](./metrics/maximum-heart-rate.md) | The stable, age-declining, non-trainable HR ceiling that anchors every %HRmax zone — use Tanaka, not 220−age, and override with any observed peak. | Established | `estimateHrMax` |
| [Resting Heart Rate (RHR)](./metrics/resting-heart-rate.md) | A cheap waking-pulse trend; a sustained multi-day rise above the runner's own baseline flags fatigue, under-recovery, or oncoming illness. | Established | *(not yet computed)* |
| [Heart-Rate Training Zones](./metrics/heart-rate-zones.md) | Intensity bands from HR — anchor to %HRR (Karvonen) or LTHR, not naive %HRmax, and keep the week ~80% easy. | Probable | `computeHrZones`, `zoneForHr`, `timeInZones`, `estimateHrMax` |
| [Lactate Threshold (LT1, LT2, LTHR)](./metrics/lactate-threshold.md) | The intensity where lactate accumulates; LT2/MLSS is the single best — and most trainable — endurance predictor, the central dial the coach turns. | Established | *(consumed by zones; not directly computed)* |
| [Heart-Rate Variability (HRV)](./metrics/heart-rate-variability.md) | Beat-to-beat vagal-tone signal (lnRMSSD vs personal baseline); a noisy daily autoregulation tool, never an overreaching detector on its own. | Probable | `hrvBaseline`, `hrvCv` |
| [Aerobic Decoupling & Cardiac Drift](./metrics/aerobic-decoupling.md) | How much HR drifts up over a steady run; a durability gauge that must be cross-checked against heat, fuelling, and effort. | Probable | `computeDecoupling` |
| [VO₂max](./metrics/vo2max.md) | The aerobic ceiling — one of three performance determinants, slow-moving, large wearable error; a trend tool, not a race predictor. | Established | *(not yet computed)* |
| [Running Economy](./metrics/running-economy.md) | The energy cost of holding a pace — among similar-VO₂max runners it explains who races faster; trainable for a whole career. | Established | *(not yet computed)* |
| [Race-Time Prediction](./metrics/race-prediction.md) | Estimates a finish time from a known race via Riegel's power law; well-calibrated short-to-mid, optimistic for under-trained marathoners. | Probable | `predictRace`, `riegel` |
| [Pace Zones & Threshold Pace](./metrics/pace-zones.md) | Speed bands anchored to threshold pace; pace is instantaneous *external* load (what you did), HR is lagging *internal* load (what it cost). | Established | `computePaceZones` |
| [Grade-Adjusted Pace (GAP)](./metrics/grade-adjusted-pace.md) | Converts hill pace to the equivalent flat pace by metabolic cost (Minetti); judge effort by GAP on hills, cross-checked with HR/RPE. | Probable | `gradeAdjustedPace`, `minettiCost` |
| [Critical Speed / Critical Power](./metrics/critical-speed.md) | The highest metabolically steady-state speed — a hard ceiling; pace above it draws on a finite tank (D′) with predictable time-to-exhaustion. | Established | *(not yet computed)* |
| [Cadence (Step Rate)](./metrics/cadence.md) | Steps per minute; the "180 for everyone" rule is a myth — nudge an individual +5–10% above their own baseline only when overstriding/injury justifies it. | Probable | *(not yet computed)* |
| [Stride Length](./metrics/stride-length.md) | Distance per stride; speed = cadence × stride length, self-selected stride is near-optimal — flag overstriding, never chase a target number. | Probable | *(not yet computed)* |
| [Advanced Form Metrics & Running Power](./metrics/running-form-metrics.md) | GCT, vertical oscillation/ratio, leg stiffness, running power — device-dependent, trend-only signals; power is a proprietary model, not interchangeable across brands. | Contested | *(not yet computed)* |
| [Training Load & ACWR](./metrics/training-load-acwr.md) | Acute vs chronic workload ratio; a descriptive load-spike signal whose injury-prediction claim is discredited — avoid spikes, but don't gate on the numbers. | Contested | `computeAcwr`, `trainingLoad` |
| [Fitness / Fatigue / Form (CTL, ATL, TSB)](./metrics/fitness-fatigue-form.md) | Impulse-response bookkeeping: CTL≈fitness, ATL≈fatigue, TSB≈form; useful for trends and tapering, but coarse and never overrides subjective/HRV signals. | Probable | `trainingLoad` *(CTL/ATL/TSB not yet computed)* |
| [Training Stress Score (TSS)](./metrics/training-stress-score.md) | One number per session combining intensity × duration (100 AU ≈ 1 h at threshold); a relative bookkeeping input, not a measured dose. | Probable | `trainingLoad` |
| [Sleep & Recovery](./metrics/sleep-and-recovery.md) | The most potent recovery process; protect 7–9 h, treat short nights as cumulative debt, and never design plans that require sleep restriction. | Probable | *(not yet computed)* |
| [Readiness (Composite)](../notes/recovery/recovery_readiness.md) → **reconciled out of this package** as `recovery_readiness` | A triangulated read of HRV + sleep + RHR + load + subjective wellness; no single input is decisive — a prompt to ask a question, never a verdict. | Probable | `derive/recovery.py` (`recovery_score`) |

## Principles

The training-design rules the coach builds plans on.

| Doc | What it is (one line) | Evidence | Maps to (`@daud/core`) |
|---|---|---|---|
| [Polarized & Intensity-Distribution Training](./principles/polarized-training.md) | Successful endurance training is ~80% easy / ~20% hard, avoiding the moderate "black hole"; whether the hard 20% is polarized vs pyramidal is genuinely contested. | Probable | `timeInZones` |
| [Progressive Overload & Adaptation](./principles/progressive-overload.md) | Stress → recovery → adaptation; cap single-run distance spikes tightly, deload periodically — but the "10% per week" rule is a soft heuristic, not a law. | Probable | `computeAcwr`, `WEEKLY_PROGRESSION_LIMIT` *(guardrail)* |
| [Periodization & Tapering](./principles/periodization.md) | Phase training (base→build→peak→taper); the ~2-week taper (cut volume 41–60%, hold intensity) is the best-evidenced piece — the macro model choice is not. | Probable | *(supported by `trainingLoad`/`computeAcwr`)* |
| [Individualization](./principles/individualization.md) | Two runners on the same plan adapt very differently; treat every population default as a starting estimate and re-anchor to the runner's own measured response. | Established | `hrvBaseline` *(+ re-anchoring throughout)* |
| [Specificity & Recovery](./principles/specificity-and-recovery.md) | SAID: the body adapts to the exact stress imposed, and adaptation happens *during* recovery — stress and recovery are one system; protect the easy–hard polarity. | Established | `trainingLoad`, `computeAcwr` *(context)* |

## Wellness

The whole-runner factors — environment, fuel, strength, female physiology, and injury.

| Doc | What it is (one line) | Evidence | Maps to (`@daud/core`) |
|---|---|---|---|
| [Heat & Altitude](./wellness/environmental-stress.md) | Heat acclimatization is one of sport's best-evidenced gains (~10–14 days); read effort/pace alongside HR in heat. Altitude (LHTL) is smaller and contested. | Established | *(pace/HR cross-checks; not yet computed)* |
| [Fueling & Hydration](./wellness/fueling-and-hydration.md) | Carbs are the limiter past ~90 min (30–90 g/h, gut-trained); drink to thirst — over-drinking risks dangerous hyponatremia. | Established | *(not yet computed)* |
| [Strength Training for Runners](./wellness/strength-training-for-runners.md) | Heavy lifting + plyometrics improve running economy ~2–8% with no bulk, and roughly halve overuse-injury risk — recommend to essentially every runner. | Established | `trainingLoad` *(counts as load)* |
| [Menstrual Cycle & Training](./wellness/menstrual-cycle-and-training.md) | Average cycle-phase performance effect is trivial on low-quality evidence — no generic phase plan; but low energy availability / REDs is a safety-critical red flag. | Contested | *(not yet computed)* |
| [Running Injury Prevention](./wellness/injury-prevention.md) | Most running injuries are overuse from load outrunning tissue capacity; strength training and load management are first-line, and bone-stress/REDs is a hard stop. | Probable | `computeAcwr`, `detectFlags`, `validateMutation` *(guardrails)* |

---

### Package layout

- `metrics/`, `principles/`, `wellness/` — the knowledge docs (one `.md` per topic,
  all following [`TEMPLATE.md`](./TEMPLATE.md)).
- [`METHODOLOGY.md`](./METHODOLOGY.md) — the evidence-grading scale, document
  standard, and how the coach consumes this layer.
- [`COACHING-RULES.md`](./COACHING-RULES.md) — the cross-cutting digest of every
  doc's Coach Directives, grouped by theme, with the SAFETY-CRITICAL guardrails
  flagged.
- `src/index.ts` — the upstream Daud retrieval manifest. **Not present in this
  repo**; its role is played by the generated [`../manifest.json`](../manifest.json).
