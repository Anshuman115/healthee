# Coaching Rules — cross-cutting digest of Coach Directives

This is the de-duplicated, themed roll-up of every **Coach Directives** block in
the knowledge base. Each doc owns its directives in full (with rationale); this
file is the operational cross-reference so the engine and the AI can see the rules
together and spot where they overlap.

How to read it:

- Rules are grouped by **theme**. Source directives are cited like `[cadence D3]`
  (doc id + directive id); a rule fused from several docs lists all sources.
  Most ids are the hyphenated slug of a file in `sports-science/` (`[cadence D3]`
  → `metrics/cadence.md`). **One is not:** readiness was reconciled out of
  `sports-science/metrics/readiness.md` into the Healthee corpus, so it is cited
  by its manifest id — `[recovery_readiness D7]` → `notes/recovery/recovery_readiness.md`.
  The reconciliation inserted a new D4, which shifted that note's later directive
  numbers; every citation below was re-checked against the directive text it
  claims, not renumbered mechanically.
- **Confidence** tags mirror the source (Established / Probable / Emerging /
  Contested / Myth-corrected). The coach's phrasing must track this.
- 🛑 **SAFETY-CRITICAL** marks rules that **ought to be** hard guardrails — the AI
  must never override them. None of them is compiled into one yet (see the box below);
  the marker is an intent, and the honesty of saying so is the point of #87. They are collected up front, then repeated in-theme for
  context. Everything else is advisory and individualised.

---

## 🛑 Safety-critical guardrails

> ⚠️ **Enforcement status, stated honestly (#83b, 2026-08-01).** This section used to
> say these rules "are mirrored as deterministic guardrails in `@daud/core`
> (`guardrails.ts`, `flags.ts`, `validateMutation`)". **`@daud/core` does not exist**
> — not in this repo, not in `~/projects/healthee-legacy`, not in any dependency or
> anywhere in git history. It is the upstream project this corpus was imported from.
> Healthee's real enforcement is `apps/server/src/healthee/insights/output_guard.py`,
> which blocks regardless of citations or validation, plus (since #87, 2026-08-01)
> `insights/guard_directives.py`, which compiles a blocking rule from every note that
> declares a directive `safety_critical` in its frontmatter — with a test asserting
> the markers and the rules match in both directions.
>
> **That does not change what is enforced below.** No sports-science doc declares a
> marker, so **nothing in this section is automatically enforced by virtue of being
> written here.** Read it as *what the guardrails must be*, and check
> `output_guard.py` + `guard_directives.py` for what they *are*. A rule that is
> genuinely load-bearing gets added there deliberately, with a documented origin —
> and if its home is a note directive, by marking that directive and writing its
> pattern and its fire/no-fire tests in the same PR.

These are the rules that protect the runner from harm. They **take precedence over
any AI suggestion, plan, or "green" readiness/form score.**

1. 🛑 **Single-run distance spike cap.** Do not prescribe a run more than **~10%
   longer than the runner's longest run in the prior 30 days**; warn at **>30%**;
   treat a **doubling (>100%)** as a near-hard stop. Require explicit confirmation
   to exceed. — *Probable (conservative low-cost default)* — `[progressive-overload D2]`,
   `[training-load-acwr D2/D3]`, `[injury-prevention D2]`.
2. 🛑 **ACWR / chronic-load ceiling.** Avoid acute load spiking far above the
   chronic base; cap sustained CTL increases at **~5–7 TSS/day/week**. Treat ACWR
   only as a *soft* monitoring flag (loose 0.8–1.3), **never** as a hard injury
   gate — but the engine still enforces the spike ceiling above. — *Established
   (build chronic load) / Contested (ACWR cut-offs)* — `[fitness-fatigue-form D2]`,
   `[progressive-overload D4/D9]`, `[training-load-acwr D4]`.
3. 🛑 **The "10% per week" rule is NOT a safety guarantee.** Discourage large weekly
   jumps, but never present "10%/week" as an evidence-based injury-prevention law
   (its RCT failed). — *Myth/Refuted as a protective rule* — `[progressive-overload D3]`,
   `[training-load-acwr D9]`, `[injury-prevention D7]`, `[specificity-and-recovery D10]`.
4. 🛑 **Injury / pain pause.** Any reported pain, niggle, or red-flag wellness signal
   **overrides** a "safe" ACWR/readiness reading. On suspected **bone-stress injury**
   (localised bony tenderness, pain on hopping, pain worsening through/after a run or
   at rest) **stop running and refer** — never advise running through it. — *Established*
   — `[injury-prevention D8/D9]`, `[training-load-acwr D8]`, `[recovery_readiness D7]`,
   `[strength-training-for-runners D12]`.
5. 🛑 **Graduated return-to-run after bone-stress injury.** Gate return on resolved
   bony tenderness and pain-free walking (plus confirmed healing for high-risk sites),
   then use a **walk-run, distance-before-speed, repeat-each-level, symptom-guided**
   progression — slower for females/high-risk sites. Do **not** apply a generic
   10%/week ramp. — *Probable* — `[injury-prevention D10]`.
6. 🛑 **Illness pause.** When a sustained RHR elevation co-occurs with illness signs
   (fever, malaise, systemic symptoms), **do not train through it — default to rest**
   (cardiac risk of exercising while acutely ill). Illness symptoms veto hard training
   regardless of fresh form. — *Established* — `[resting-heart-rate D10]`,
   `[recovery_readiness D6/D7]`, `[fitness-fatigue-form D6]`.
7. 🛑 **Symptomatic bradycardia.** On a low RHR *with* symptoms (dizziness, syncope,
   chest discomfort, exertional intolerance, irregular beats) advise medical
   evaluation; never dismiss as "athlete heart." — *Established* — `[resting-heart-rate D9]`.
8. 🛑 **Heat-illness stop-and-cool.** On heat-illness red flags (confusion, collapse,
   disorientation, vomiting, altered behaviour) during/after hot exercise, **stop
   training advice and direct to immediate cooling + urgent medical care.** In extreme
   heat/WBGT, scale back intensity/duration, move cooler, or postpone — especially for
   the unacclimatized. Rising decoupling + heat-illness signs always defer to this. —
   *Established* — `[environmental-stress D11/D12]`, `[aerobic-decoupling D9]`.
9. 🛑 **Hyponatremia / over-drinking.** **Never** advise drinking ahead of thirst or in
   excess of sweat losses (even in heat); flag in-run weight *gain* as an
   exercise-associated-hyponatremia risk. — *Established* — `[fueling-and-hydration D8]`,
   `[environmental-stress D14]`.
10. 🛑 **Fuelling/altitude emergencies.** On confusion, severe headache, vomiting,
    seizure, or altered consciousness during/after long or hot efforts, stop fuelling
    advice and direct to urgent medical care. On altitude-illness symptoms (worsening
    headache, severe breathlessness, confusion, ataxia) advise **descent** and care, not
    continued training. — *Established* — `[fueling-and-hydration D12]`,
    `[environmental-stress D13]`.
11. 🛑 **Low energy availability / REDs.** Screen for restrictive eating, rapid weight
    loss, menstrual dysfunction, or repeated bone-stress injuries; on any flag **do not
    increase load and refer** to a sports physician/dietitian — **never** advise further
    restriction, and never normalise weight loss/low EA as a performance strategy. —
    *Established* — `[injury-prevention D8]`, `[menstrual-cycle-and-training D5/D6]`.
12. 🛑 **Menstrual red flag.** Flag any missing or newly irregular menstruation in a
    non-hormonally-contracepting runner as a REDs/health red flag; explain the
    energy-availability and bone-health link and recommend clinician evaluation. Do not
    advise training through it. A withdrawal bleed on contraception is **not** evidence
    of energy adequacy. — *Established* — `[menstrual-cycle-and-training D5/D7/D10]`.
13. 🛑 **Readiness hard overrides are not votes.** Illness-symptom + elevated RHR, acute
    sleep deprivation, and any reported pain/injury **force modify/rest regardless of
    the composite or a positive TSB.** Never let high/green readiness or fresh form
    clear a runner reporting rising fatigue, poor sleep, mood decline, illness, or pain
    — vagal markers can *rise* when overreached. — *Established* — `[recovery_readiness D6/D7]`,
    `[fitness-fatigue-form D6]`, `[heart-rate-variability D5]`.
14. 🛑 **Don't test or push at-risk/beginner runners.** Do not prescribe maximal
    HR/threshold/VO₂max/critical-speed field tests or sustained severe-domain efforts to
    Stage-1 beginners or to injured/ill/fatigued runners; flag sustained near-max HR
    during easy running as a health red flag. — *Established* — `[heart-rate-zones D11]`,
    `[lactate-threshold D9]`, `[vo2max D10]`, `[critical-speed D11]`,
    `[maximum-heart-rate D7]`.
15. 🛑 **Medication & sensor sanity.** If a rate-limiting medication (e.g. β-blocker) is
    flagged, disable formula-HRmax/zone prescription and fall back to RPE/talk-test.
    Reject HR implying adult HRmax > ~220 bpm or > ~15–20 bpm/s jumps as sensor artefact
    before acting. — *Established* — `[maximum-heart-rate D8/D9]`, `[heart-rate-zones D10]`.
16. 🛑 **Never require sleep restriction.** Do not prescribe, endorse, or design plans
    that require habitual sleep restriction to fit training in. — *Established* —
    `[sleep-and-recovery D2]`.
17. 🛑 **Descents & downhill load.** Never prescribe pace targets on descents; cap
    descent effort for impact/muscle-damage control. Beyond ±20–25% grade, stop
    prescribing pace and switch to effort/HR/RPE (allow power-hiking). — *Established
    (validity bound) / Probable (safety)* — `[grade-adjusted-pace D6/D7]`.
18. 🛑 **No ≥2 consecutive hard days** for typical recreational runners; require easy or
    rest between hard sessions so each lands on a recovered baseline. — *Established* —
    `[specificity-and-recovery D3]`, `[polarized-training D3]`.

---

## Intensity & zones

- **Keep the week ~80% easy / ~20% hard.** Hold weekly low-intensity volume near ~80%
  (Z1–Z2 by effort/HR); treat persistent easy-day drift into the moderate "black hole"
  as the primary error to correct — that grey-zone running is the real "junk miles."
  The ~80% easy floor is *Established*; whether the hard 20% is strictly *polarized* vs
  *pyramidal* is a smaller, individualised, event-specific choice — do not dogmatically
  forbid threshold work. — *Established (≈80% easy) / Contested (polarized-specific)* —
  `[polarized-training D1/D2/D4]`, `[heart-rate-zones D5]`, `[pace-zones D7]`,
  `[specificity-and-recovery D4]`.
- **Cap hard sessions at ~2/week.** Allow a 3rd Z3 session only with strong recovery
  markers and never by cutting the easy base. — *Probable (safety-mirrored)* —
  `[polarized-training D3]`.
- **Anchor zones to the runner's own thresholds, not a guessed max.** Default HR zones
  to **Karvonen %HRR** (not %HRmax, which over-loads less-fit runners); anchor pace zones
  to a current **threshold pace** (~LT2 / ~60-min race pace); prefer field-tested
  **LTHR** for tempo/threshold once available. Treat LT2/LTHR as the primary dial and
  report threshold *velocity* gains as the headline adaptation. — *Established* —
  `[heart-rate-zones D1/D4]`, `[pace-zones D1]`, `[lactate-threshold D1/D2]`,
  `[critical-speed D1]`.
- **Estimate HRmax with Tanaka `208 − 0.7·age`, never `220 − age`;** attach a ±10–12 bpm
  band and **override with any observed peak.** HRmax is not trainable — a flat HRmax is
  not lost fitness. — *Established* — `[maximum-heart-rate D1/D2/D3/D4/D6]`,
  `[heart-rate-zones D2]`.
- **Treat every zone boundary as soft (±1 zone at edges);** quote thresholds and zone
  edges as bands, not exact numbers, reflecting genuine estimate noise. — *Established*
  — `[heart-rate-zones D3]`, `[pace-zones D11]`, `[lactate-threshold D6]`.
- **Pace = external load, HR = internal load.** Prescribe in pace, police in effort/HR.
  Judge short/flat reps (<~2 min) by pace/RPE (HR lags); lead long aerobic runs with
  HR/effort. — *Established / Probable* — `[pace-zones D3/D8]`, `[heart-rate-zones D9]`.
- **Critical Speed is a sustainable-pace ceiling.** Prescribe sustained efforts at/just
  below CS, aerobic-power intervals at ~110–130% CS; model time-to-exhaustion above CS
  as `t = D′/(v − CS)` to flag unsustainable goal paces. Re-estimate CS at the `lactate-threshold` D11 cadence (~6–12 weeks).
  — *Established / Probable* — `[critical-speed D2/D3/D7/D8/D9]`.
- **Keep above-LT2 / severe-domain work a small, recovery-gated fraction** of the week;
  never prescribe it as steady-state training. — *Established* — `[lactate-threshold D10]`,
  `[critical-speed D7]`, `[vo2max D10]`.
- **Don't oversell Zone 2 or VO₂max.** Frame Z2 as best adaptation per unit fatigue, not
  as uniquely superior for mitochondria; treat VO₂max as a ceiling/context metric, never
  predict race times from it, and don't chase it once it plateaus (credit threshold/economy
  gains instead). — *Established / Contested* — `[heart-rate-zones D7]`, `[vo2max D1/D2/D3/D4]`.
- **Race prediction: always a range, never a number.** Default to Riegel `k=1.06` (use the
  runner's own exponent with ≥2 races); trust only to ~2× the input distance; bias marathon
  extrapolations slower and never surface a raw optimistic first-marathon number. —
  *Established / Probable* — `[race-prediction D1/D2/D3/D4/D5/D8]`.

## Load & recovery

- **Progress one variable at a time, gradually.** Never raise volume, intensity and
  frequency together in the same microcycle; grow chronic load steadily so high loads
  become protective. — *Established* — `[progressive-overload D1/D4]`,
  `[injury-prevention D3]`.
- 🛑 **Single-run spike cap & chronic-ceiling** — see Safety #1–#2. — `[progressive-overload D2]`,
  `[training-load-acwr D2/D3]`, `[fitness-fatigue-form D2]`.
- **Deload regularly.** Insert a reduced-volume recovery/down week (~40–50% cut)
  roughly **every ~3–5 weeks** of progressive loading (nearer 3 weeks for beginners),
  framed as part of the plan — without claiming it boosts adaptation.
  — *Emerging / practitioner consensus* — `[progressive-overload D5]` (which owns the
  cadence and its provenance), `[periodization D7]`, `[specificity-and-recovery D5]`.
  *(Corrected 2026-08-01, #81: this line said "every 3–4 weeks" at confidence
  "Probable / Emerging" while citing D5, which says ~3–5 weeks at Emerging — a
  synthesis that contradicted the directive it cited, and the sharpest instance of the
  three-cadences defect.)*
- **Sequence stress → recovery → next stimulus.** Recovery is *when adaptation happens* —
  program rest/easy days as deliberately as hard days, and never assume more stimulus
  alone produces more fitness. No ≥2 consecutive hard days (Safety #18). — *Established*
  — `[specificity-and-recovery D2/D3]`, `[progressive-overload D6]`.
- **Re-enter below pre-break load after a layoff** (chronic load has decayed). — *Probable*
  — `[injury-prevention D4]`.
- **Treat the load model (TSS/CTL/ATL/TSB/ACWR) as trends, not scores.** Validate the TSS
  input (stale threshold, heat, trails, treadmills, non-running load all corrupt it);
  compute every session as `duration_h × IF² × 100` choosing power → rTSS → hrTSS → sRPE;
  grade-adjust pace (Minetti) before normalizing; never compare TSS between runners; and
  always cross-check computed load against the runner's sRPE/feel. — *Established / Probable*
  — `[training-stress-score D1/D2/D3/D4/D6]`, `[fitness-fatigue-form D8/D9]`.
- **Don't let a tidy number override the runner.** Equal TSS is not equal training effect
  or recovery cost (weight interval/eccentric-downhill work as costlier); a low computed
  TSS never justifies more load when readiness is red. — *Probable / Established (safety
  mirror)* — `[training-stress-score D7/D8]`.
- **Taper with confidence.** Before a goal race cut weekly volume **by 41–60%**,
  progressively, **holding intensity** and keeping frequency ~80–100% of normal; taper
  ~10–14 days (half/marathon) or ~7–10 days (5K–10K). Never seek new fitness in the final
  ~10–14 days. **Hard cap:** do not cut volume by >60% or zero-out intensity (both reverse
  the benefit). — *Established* — `[periodization D1/D2/D3/D8]`, `[specificity-and-recovery D6]`,
  `[fitness-fatigue-form D3]`.
- **Form/TSB bands are population defaults to individualise.** Target race-day TSB ~+5 to
  +25; treat TSB below −30 as a heightened-risk zone (briefly, never with negative HRV/
  subjective signals); TSB above +25 outside a taper is detraining. — *Probable* —
  `[fitness-fatigue-form D3/D4/D5]`.
- **Functional-overreaching blocks are experienced-athlete-only,** monitored, time-boxed
  to ≤~2 weeks, always followed by recovery — never for Stage 1. Surveil for NFOR/OTS:
  on a multi-week pattern of unexplained performance decline + fatigue/mood/sleep/RHR
  disturbance, **reduce load and recover — do not progress.** — *Probable / Established* —
  `[progressive-overload D7/D8]`, `[periodization D9]`, `[specificity-and-recovery D8]`.
- **After heavy eccentric load** (downhill racing, hard long runs) allow ~3–7 days before
  an equivalent stress. — *Probable* — `[specificity-and-recovery D11]`,
  `[training-stress-score D9]`.
- **Count strength as real load.** Heavy lower-body and plyometric sessions are training
  load when scheduling hard runs (running-only TSS/ACWR misses them). — *Probable* —
  `[strength-training-for-runners D10]`.
- **Don't mistake rest for detraining.** 1–3 rest days are well inside the no-decay window
  — reassure, don't flag as lost fitness. — *Established* — `[specificity-and-recovery D7]`.

## Form

- **Cadence: nudge, never mandate.** Never prescribe 180 spm (or any fixed absolute
  cadence) — it's a myth; express cadence only relative to the runner's own baseline at a
  comparable pace. When intervening, prescribe **+5–10% above habitual cadence, capped at
  ≤10%,** phased in gradually on easy runs, **never combined with a same-week load increase.**
  — *Established (myth) / Probable (safety bound, mirrored in `@daud/core`)* —
  `[cadence D1/D2/D3]`, `[stride-length D5/D6/D9]`, `[injury-prevention D6]`.
- **Target overstriding, not stride length.** Self-selected stride is near-optimal for
  economy; flag overstriding (foot landing well ahead of CoM), which you can only *infer*
  (low cadence-at-pace + impact symptoms), not measure from GPS. Intervene with a cadence
  nudge only when overstriding is suspected **and** symptomatic; prioritise it for
  patellofemoral/shin pain (benefit is mainly at the knee/PFJ). — *Established / Probable*
  — `[stride-length D2/D3/D4/D5]`, `[cadence D4]`, `[injury-prevention D6]`.
- **Don't force form on healthy runners.** Forcing cadence/stride away from self-selected
  raises energy cost for no benefit; don't do it during racing/intervals or in
  asymptomatic runners, and don't prescribe a universal "economical" form. — *Probable /
  Contested* — `[cadence D8]`, `[stride-length D7]`, `[running-economy D7]`.
- **Don't claim cadence prevents injury / cuts impact in healthy runners** — evidence is
  non-significant; frame any bone benefit as plausible-but-modest. — *Contested* —
  `[cadence D7]`.
- **speed = cadence × stride length** is ground truth — attribute any pace change to the
  cadence/stride split first; expect stride (not cadence) to dominate at fast paces, and
  to shorten uphill, on soft ground, and with fatigue. Suspect a **unit error** before
  suspecting form on an anomalous reading. — *Established* — `[stride-length D1/D8/D10/D11]`.
- **Advanced form metrics & power are secondary, trend-only, single-device signals.**
  Never let GCT/VO/vertical ratio/leg stiffness/power override pace, HR, RPE, or load;
  only reference a metric the device actually records; reset baselines on device change;
  **never pool running power across brands** (Garmin/Polar read ~30% higher than
  Stryd/COROS/Apple). Don't prescribe target numbers. When power disagrees with HR/RPE,
  trust the physiology. Permit power as a pacing governor only for Stage-3 athletes already
  training with it. — *Established / Probable* — `[running-form-metrics D1/D2/D3/D4/D5/D10/D11/D12]`.
- **Within-run form drift is a fatigue signature, not a fault to fix mid-run** (rising GCT,
  falling stride/stiffness; cadence-fade >5%). Use GCT *balance/symmetry* rather than
  absolute GCT as the flag. — *Probable* — `[running-form-metrics D8/D9]`, `[cadence D6]`.
- **Form metrics explain little of economy (~4–12%);** weight them lightly — favour aerobic
  volume, strength, and footwear first. — *Established* — `[running-form-metrics D7]`,
  `[running-economy D1]`.

## Readiness & recovery

- **Triangulate ≥3 signals; no single input is decisive.** Compute readiness from HRV
  trend + sleep + RHR trend + prior load + subjective wellness; never present a readiness
  number without its component breakdown, and scale coaching confidence to how many inputs
  agree. — *Established* — `[recovery_readiness D1/D3]`.
- **Always include a subjective morning check-in** (fatigue/soreness/stress/mood) and treat
  it as at least as sensitive as the sensors — weight it (and any pain) highest when signals
  conflict. — *Established* — `[recovery_readiness D2]`, `[sleep-and-recovery D7]`.
- **Act on multi-day trends, never single readings.** HRV: use lnRMSSD vs a 7-day rolling
  baseline, flag only outside mean ±1 SD; an isolated low reading is noise. RHR: flag only a
  sustained ≥~5 bpm (≥~1.5–2 SD) rise for ≥2–3 days. Each needs the baseline window its own
  note defines before it is trusted — HRV ≥2–3 weeks [`heart-rate-variability` D7], RHR ≥1–2
  weeks [`resting-heart-rate` D12]. *(This said "~2–3 weeks" for both while citing D12, which
  says ≥1–2: a digest contradicting the directive on its own line. The two windows are
  genuinely different — HRV is the noisier signal — so they are named separately rather than
  merged. Both are unsourced methodological conventions; neither note carries a citation. #100)* — *Established / Probable* —
  `[heart-rate-variability D1/D4/D7]`, `[resting-heart-rate D1/D2/D3/D12]`,
  `[specificity-and-recovery D8]`.
- **Screen confounders before attributing fatigue.** Alcohol, short/poor sleep, late hard
  session, stress, heat, dehydration, illness, travel, menstrual phase, new device — a
  confound-explained dip is not a training trigger; suppress/down-weight readiness when an
  obvious confounder explains it. — *Established* — `[resting-heart-rate D4/D11]`,
  `[recovery_readiness D10]`, `[menstrual-cycle-and-training D9]`.
- 🛑 **Safety inputs are hard overrides** (illness+RHR, acute sleep loss, pain) — see
  Safety #6, #13. — `[recovery_readiness D6/D7]`.
- **HRV/RHR alone cannot detect overreaching.** Never use either as a standalone
  overtraining test or to clear a fatigued athlete (vagal markers can rise paradoxically);
  always read in a panel. Never compare HRV/RHR between runners or use absolute population
  thresholds. — *Established / Probable* — `[heart-rate-variability D5/D6]`,
  `[resting-heart-rate D6]`.
- **Readiness eases or holds — it never escalates.** Map to go / modify / rest as a
  *suggestion the runner can override*, explaining which components drove it; keep it opt-in
  and non-moralised (imposed daily verdicts can cause the stress they measure). — *Probable*
  — `[recovery_readiness D5/D8/D11]`.
- **Sleep is the strongest recovery lever.** Set a personal nightly target (default
  7–9 h — the NSF figure `sleep-and-recovery` D1 cites; this read "7.5–9 h", the unsourced
  lower bound #98 removed at the source and did not propagate here); after one severely short night keep easy work but downgrade/postpone hard
  sessions (expect inflated RPE); track 7-day sleep debt and treat a run of short nights as
  cumulative — cut intensity first, then volume. Bank sleep before key sessions/races. Flag
  habitual <8 h in youth athletes as injury risk. — *Established / Probable* —
  `[sleep-and-recovery D1/D3/D4/D5/D6]`.
- **Don't coach off wearable sleep-stage or "economy"/recovery percentages;** use total
  sleep-duration trends + subjective rest, and treat commercial composite scores as
  unvalidated black boxes (the underlying HRV/RHR/sleep signals are valid; the algorithms
  are not). — *Probable* — `[sleep-and-recovery D8]`, `[recovery_readiness D9]`,
  `[running-economy D8]`.
- **Recovery is multifactorial;** pair sleep guidance with fuelling and stress management,
  and never imply sleep alone offsets under-fuelling or overload. — *Probable* —
  `[sleep-and-recovery D9]`.
- **Decoupling & HRR as durability trends.** Compute decoupling only on a sustained,
  single-intensity block (≥45–60 min); bands <5% / 5–10% / >10% are starting heuristics;
  treat it as a multi-run trend, never a one-session verdict, and **never** override pacing
  or stop a session on decoupling/HRR alone. Track HRR as a personal-baseline trend. —
  *Established / Probable* — `[aerobic-decoupling D1/D2/D5/D7/D9]`.

## Environment & fuelling

- **Read effort/pace alongside HR in heat.** Expect HR to drift up at constant effort in
  heat/dehydration or after ~30 min of a long run — weight pace and RPE over HR; don't slow
  below target effort just to hold an HR cap, and don't read an elevated hot-weather HR as
  overreaching. Permit (don't penalise) slower hot-day paces. — *Established* —
  `[environmental-stress D1/D2]`, `[heart-rate-zones D8]`, `[pace-zones D4/D6]`,
  `[lactate-threshold D8]`, `[aerobic-decoupling D6]`.
- **Heat acclimatization for hot goal races.** Prescribe ~10–14 days of repeated heat
  exposure (~60 min/day) starting ~2 weeks out; progress conservatively, using falling
  HR-at-effort as the adaptation signal; top up every ~3–5 days if the race is still weeks
  off. Don't claim it improves cool-weather performance (contested). — *Established /
  Probable / Contested* — `[environmental-stress D3/D4/D5/D6]`.
- **Altitude (LHTL) is an advanced Stage-3 tool only.** If used, target live ~2000–2500 m /
  train low / ≥3–4 weeks / ≥22 h-day; set honest expectations (~1–4% mean sea-level gain,
  real chance of no response — never promise it); ensure adequate **iron status** first; cut
  intensity on first arrival. — *Probable / Contested / Established (iron)* —
  `[environmental-stress D7/D8/D9/D10]`.
- **Grade-adjust pace on hills.** When a run/segment exceeds ±3% grade, reason about effort
  via **GAP** (Minetti cost curve) rather than raw pace, cross-checked with HR/RPE (trust
  physiology when they conflict); credit climbs but **discount modelled downhill savings**;
  smooth elevation and aggregate by flat-equivalent speed/energy. See Safety #17 for descents
  and the ±20–25% pace cut-off. — *Established (relationship) / Probable (point accuracy)* —
  `[grade-adjusted-pace D1/D2/D3/D4/D5]`, `[pace-zones D5]`.
- **Carbohydrate by duration.** <~60 min: none (optional mouth-rinse for hard efforts);
  ~60–150 min: ~30–60 g/h started early; >~2.5–3 h: up to ~90 g/h **only** as
  glucose+fructose (~2:1) and **only** if gut-trained. Periodise daily carbs to load
  (~3–12 g/kg/day). For goal runs ≥~90 min ensure high pre-run glycogen + a fuelling plan
  (the marathon "wall" is preventable). **Rehearse race fuelling in training — never debut on
  race day.** — *Established / Probable* — `[fueling-and-hydration D1/D2/D3/D4/D5/D6]`.
- **Hydration: drink to thirst** (no forced schedules for general training); recommend sodium
  for long/hot efforts and salty/heavy sweaters (for comfort, not as a guaranteed EAH
  prophylactic). See Safety #9 on over-drinking. — *Established* —
  `[fueling-and-hydration D7/D9]`.
- **Fasted/low-carb has a narrow role; chronic keto/LCHF does not.** Permit occasional
  low-carb/fasted *easy* sessions for experienced runners, but always fuel key quality
  sessions/races with high carbohydrate availability; don't recommend chronic ketogenic diets
  for performance (economy cost). Intakes >~90 g/h are experimental (ultra only). — *Emerging
  / Established* — `[fueling-and-hydration D10/D11/D13]`.

## Strength & individualization (supporting)

- **Recommend strength training to essentially every runner: 2–3 sessions/week,** heavy
  (~80–90% 1RM, 3–6 reps) and/or plyometric — not light high-rep "toning." Frame the benefit
  as ~2–8% better running economy + durability **with no loss of VO₂max and no bulk** (reassure
  mass-averse runners), and roughly halved overuse-injury risk. Expect economy gains over
  8–14+ weeks. Maintain heavy/explosive work through the racing season. — *Established /
  Probable* — `[strength-training-for-runners D1/D2/D3/D5/D6]`, `[running-economy D3]`,
  `[injury-prevention D5]`.
- **Protect key runs from strength fatigue:** lift on/near hard days, keep easy days easy,
  prefer separate sessions (≥3–6 h apart); progress load gradually and prioritise technique,
  especially for novices/youth/post-injury — avoid stacking heavy impact on a bone-stress
  history (see Safety #11). — *Probable / Established (safety)* —
  `[strength-training-for-runners D8/D9/D11]`.
- **Footwear:** advanced carbon-plate shoes give ~2–4% energy saving for races/key sessions —
  but test in training first (individual response varies). — *Established (mean) / Emerging
  (individual)* — `[running-economy D5]`.
- **Individualise everything.** Treat every population default (zones, paces, volume rules,
  TSB bands, the 42/7-day constants) as a *starting estimate*; re-anchor to the runner's own
  measured baselines as soon as ≥2–4 weeks of clean data exist, and require any inferred change
  to exceed the runner's own day-to-day variation before acting. — *Established* —
  `[individualization D1/D2/D5]`, `[fitness-fatigue-form D7]`, `[progressive-overload D11]`.
- **Never declare a "non-responder" from a flat trend.** Run the ladder first — dose,
  measurement noise, recovery/life load, modality fit — and raise the dose (volume then
  intensity) within load-ramp limits before concluding anything. Never promise an outcome
  magnitude from population averages or "genetic potential." — *Probable / Established* —
  `[individualization D3/D4/D9]`, `[vo2max D5/D6]`.
- **Calibrate language to the evidence.** Speak plainly on Established science; hedge on
  Probable; flag Emerging/Contested as genuinely unsettled (HRV-guidance, ACWR, the 10% rule,
  cycle-syncing, periodization-model superiority); say "I'm still learning how you respond"
  when extrapolating to the individual. — *Established (calibration rule)* —
  `[individualization D6]`, `[specificity-and-recovery D12]`,
  `[menstrual-cycle-and-training D11]`, `[periodization D6]`, `[training-load-acwr D4]`.

## Menstrual cycle (individualised, symptom-led)

- **No generic phase-based template.** The average cycle-phase performance effect is trivial
  with large individual variation; treat oral/hormonal contraception as performance-neutral on
  average. Instead, treat logged menstrual symptoms like any other readiness input and offer
  the same session flexibility; support adjusting *her own* hard sessions around a *consistent
  personal* symptom pattern, framed as individual response with explicit uncertainty. Stay in
  scope — refer contraceptive choice, suspected REDs, or persistent/severe symptoms to a
  clinician. See Safety #11–#12 for the energy-availability red flags. — *Contested / Probable
  / Emerging* — `[menstrual-cycle-and-training D1/D2/D3/D4/D8/D10]`.

---

### Stage-gating (cross-cutting)

Most docs phase complexity by coaching **stage**: Stage 1 (beginner) governs by
effort/RPE/talk-test, hides load scores (TSS/CTL/ATL/TSB/ACWR) and form metrics,
and keeps almost all running easy; Stage 2 introduces light autoregulation
(HRV/readiness) and economy work; Stage 3 (racing) unlocks threshold/CS/VO₂max
testing, running-power pacing, tapering, and altitude — always read through the
plan's intent and the safety guardrails above.
*(e.g. `[heart-rate-variability D10]`, `[recovery_readiness D12]`, `[training-load-acwr D10]`,
`[fitness-fatigue-form D10]`, `[running-form-metrics D10]`, `[periodization D10]`,
`[strength-training-for-runners D4/D5]`.)*
