---
id: cardio_load_trimp
topic: Quantifying daily cardiovascular load (training impulse) from heart rate — the evidence-based alternative to a proprietary "Strain" score
evidence_grade: 2
applies_to_metrics: [hr, cardio_load, hr_zone_minutes]
applies_to_interventions: [exercise]
tags: [activity, cardiovascular, training-load, heart-rate]
last_reviewed: 2026-06-05
---

## Finding

Cardiovascular **load** — how much physiological stress the heart accumulated over
a session or a day — can be quantified from heart rate alone using **TRIMP
(Training Impulse)**. This is the transparent, peer-published basis for what
commercial wearables market as "Strain" (Whoop) or "Training Load" (Garmin). We
compute and label it honestly as *cardio load*, never as a proprietary 0–21 score
([[feedback-no-composite-score]]).

Two established methods:

- **Banister TRIMP (primary).** Weights every minute by how hard the heart was
  working, using heart-rate reserve and a lactate-derived exponential so that
  high-intensity minutes count disproportionately (matching the non-linear
  blood-lactate response):

  ```
  ΔHR  = (HR_ex − HR_rest) / (HR_max − HR_rest)        # Karvonen HR-reserve fraction, 0–1
  y    = 0.64 · e^(1.92 · ΔHR)   (men)                 # lactate weighting
         0.86 · e^(1.67 · ΔHR)   (women)
  TRIMP = Σ_minutes ( 1 min · ΔHR · y )
  ```

- **Edwards summated HR-zone score (secondary, for a readable zone breakdown).**
  Minutes in five zones by %HR_max, each weighted 1–5:

  | zone | %HR_max | weight |
  |------|---------|--------|
  | 1 | 50–60% | 1 |
  | 2 | 60–70% | 2 |
  | 3 | 70–80% | 3 |
  | 4 | 80–90% | 4 |
  | 5 | 90–100% | 5 |

  `Edwards TL = Σ_z (minutes_in_zone_z · weight_z)`.

**Inputs we already have:** per-minute HR (`hr`), measured resting HR
(`rhr_daily`, from the sleep window — preferred over a generic 60). **HR_max** is
estimated from **Tanaka (2001): HR_max = 208 − 0.7 × age**, which is materially
more accurate than the old Fox `220 − age` (the latter overestimates in the young
and underestimates in the old).

## Effect size / what it quantifies

TRIMP is a *quantification method*, not a health-outcome metric — it has no RR/HR
of its own. Its validity is **convergent**: Banister and Edwards TRIMP correlate
strongly with each other (r ≈ 0.7–0.95 across cohorts) and with session-RPE load,
and Banister TRIMP tracks the lactate / training-adaptation response it was
derived from. Tanaka HR_max: predicted vs measured regression slope ≈ 1, SEE ≈
6–7 bpm across 18,712 subjects.

## Evidence strength

- **Banister (1991)** *Modeling elite athletic performance* — original TRIMP
  formulation; the HRR × lactate-weighting model. Method foundation. (Also Morton,
  Fitz-Clarke & Banister 1990, *J Appl Physiol* — the systems model.)
- **Edwards (1993)** *The Heart Rate Monitor Book* — summated-zone TL. Widely
  used; **caveat: the 1→5 zone weights are arbitrary, with no physiological
  derivation** — so we treat Edwards only as a readable zone *breakdown*, and use
  Banister as the headline load value.
- **Tanaka, Monahan & Seals (2001)** *J Am Coll Cardiol* 37(1):153-156 — HR_max =
  208 − 0.7·age; meta-regression of 351 studies / 18,712 subjects + a validation
  cohort. **★★★** for the HR_max estimate specifically.
- Convergent-validity studies (e.g. taekwondo/karate/ballet internal-load
  validations, PMC9536392) show TRIMP variants agree with each other and with
  sRPE — supporting TRIMP as an internal-load measure. **★★** overall for the
  load construct.

## Caveats

- TRIMP captures **cardiovascular** load only — it under-credits resistance
  training, isometrics, and very short maximal efforts where HR lags. Pair it with
  the device-measured workout calories / strength minutes, don't replace them.
- HR_max is *estimated* (population equation, ±~7 bpm). An individual's true HR_max
  can differ; the load is therefore a personal-trend signal, best read against the
  user's own baseline, not an absolute cross-person number.
- Wrist HR is less accurate during high-intensity intervals (motion artefact) —
  see [[wearable-hr-validity]]. Daily aggregate load is robust; single hard
  intervals may be undercounted.
- Banister's lactate weighting was derived in trained adults; absolute values for
  an untrained user are approximate. Direction and day-to-day change are the
  trustworthy parts.

## Operational use

- Surface a **daily cardio load** (Banister TRIMP, summed over all non-sleep HR
  minutes) plus a **time-in-zones** strip (Edwards zones, in minutes), and the
  personal **7-/30-day baseline** ("today is above your usual").
- **Strain 0–21** (added on informed user request) is the SAME load rescaled onto
  a personal 0–21 scale: **0 = zero load, the user's own 90-day P95 = 21**, with a
  mild concave curve (`21·(load/P95)^0.75`) so it tracks perceived exertion. It is
  anchored to P95 — NOT the personal min/max — so a quiet or partial day reads low,
  never a misleading 0. It is a single-signal rescale of one measured metric, not a
  multi-marker composite, so it stays within the no-composite rule.
- Acute:chronic style context (today vs 7-day average) is fine as a *ratio of our
  own measured loads* — that is descriptive, not a proprietary composite.
- Evidence label in the UI: **★★ moderate** (validated load-quantification method;
  not a health-outcome score). HR_max basis (Tanaka) is ★★★.
