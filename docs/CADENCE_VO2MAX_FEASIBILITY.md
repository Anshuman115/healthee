# #109 — Can the submaximal VO₂max method run on ordinary walking?

**Verdict: No. Not on walking, and not for this owner.** Measured on the real prod dump
(2026-07-15, 110 days, ~459k samples), not reasoned. An honest "this does not work" was an
acceptable outcome for this task, and it is the outcome.

Research + design only. **No production code was written.** `derive/vo2max*.py` was read,
never touched (#108 is live in those files).

---

## 1. The feasibility verdict, with the numbers

### 1.1 The premise in the brief was wrong, and the correction matters

The brief said the shipped submaximal estimator "returns `null` for this owner **only
because he logs no GPS workouts**." He has **8 GPS tracks** (2026-06-11 → 06-18, 6,545
fixes). Running the *shipped* `vo2max_from_track` over them with the DEM grade lookup:

| Day | dist | dur | shipped GPS result |
|---|---|---|---|
| 06-11 | 1.38 km | 22 min | ✗ non-positive VO₂–HR slope |
| 06-12 | 3.40 km | 36 min | ✗ poor fit (r²=0.07) |
| 06-13 | 3.72 km | 38 min | ✗ poor fit (r²=0.07) |
| 06-14 | 0.01 km | 4 min | ✗ 0 steady windows |
| 06-14 | 3.27 km | 147 min | ✗ non-positive VO₂–HR slope |
| **06-15** | **2.18 km** | **18 min** | **✓ VO₂max 39.6** (n=31, r²=0.66, HR range 43) |
| 06-16 | 3.45 km | 36 min | ✗ poor fit (r²=0.00) |
| 06-18 | 4.48 km | 44 min | ✗ poor fit (r²=0.39) |

Two things follow.

1. **The method already fails 7 of 8 times on this owner even WITH GPS and a real DEM
   grade.** Cadence cannot rescue a method that measured speed does not rescue.
2. **The one real measurement of this owner's fitness is 39.6 mL/kg/min**, against the
   shipped Jurca figure of 51.1 that #108 is withdrawing. That is corroborating evidence
   for #108's direction from an independent instrument, and it is worth keeping.

Also worth flagging as a separate finding: `derive_vo2max_submax` is only reachable from
`read/gps.py` on track upload — it is **not in the nightly orchestrator**, and there are
**zero `vo2max_submax` rows** in prod. These 8 tracks have never been scored.

### 1.2 Does cadence give speed? Measured against his own GPS

322 clock-minutes inside the tracks had ≥45 s of GPS coverage; 198 were ambulating
(≥60 spm).

- Implied step length: median **0.821 m**, p5–p95 **0.603 – 0.969 m**.
- `speed_m_min = 1.066 × cadence − 28.9`, r² = 0.722, **residual SD 12.9 m/min (0.77 km/h)**.
- The corpus's own canonical constant ([[distance_from_steps]], 0.414 × height) gives
  **0.737 m** for this owner — noticeably below his measured median.

The r² of 0.72 looks encouraging and is misleading. Binned:

| cadence (spm) | n | median measured speed |
|---|---|---|
| 60–80 | 11 | 47.4 m/min |
| 80–100 | 7 | 69.0 m/min |
| **100–110** | **39** | **94.9 m/min** |
| **110–120** | **63** | **95.9 m/min** |
| **120–130** | **54** | **98.2 m/min** |
| **130–150** | **10** | **96.6 m/min** |
| 150–200 | 14 | 159.2 m/min |

**Across 100–150 spm — where essentially all of his walking lives — measured speed is flat
at ~96 m/min while cadence rises by 50%.** The correlation is carried entirely by the
slow-shuffle and running extremes. In the walking band, cadence carries almost no speed
information. (Mechanism is either the walk ratio's known breakdown at low speed, or wrist
step-detection artefacts, or both — the data cannot separate them.)

### 1.3 HR range is NOT the binding constraint — the slope is

The brief's hypothesis (#2) was that `MIN_HR_RANGE = 15` would be the binder. **Measured,
it is not.** Sweeping 64 ambulation bouts (≥10 min at ≥60 spm) across all 110 days, using
the shipped module's own gates and the corpus's canonical step length:

| gate | bouts surviving |
|---|---|
| bouts of ≥10 min at ≥60 spm | 64 |
| `MIN_WINDOWS = 6` steady windows | 60 |
| **`MIN_HR_RANGE = 15` bpm** | **41** ← clears comfortably |
| positive VO₂–HR slope | 22 ← **19 bouts have HR *falling* as cadence rises** |
| **`MIN_R2 = 0.5`** | **1** ← the real binder |
| plausibility `20 ≤ VO₂max ≤ 85` | 1 |

Raw HR span over whole bouts: median 24 bpm, 55/64 clear 15 bpm. **Heart rate does vary
during his walks. Workload does not.**

The VO₂ axis is the problem: within a bout, the VO₂ points have a **median standard
deviation of 0.28 mL/kg/min**, and **53 of 60 bouts are under 1.0**. Median r² among bouts
that reached a fit: **0.083**. You cannot fit a line to an axis that does not vary — and
when the slope collapses toward zero, `slope × HRmax + intercept` returns the mean VO₂ of
walking (~13 mL/kg/min ≈ 3.7 METs). **The method degenerates into reporting the metabolic
cost of walking as if it were a fitness ceiling.**

### 1.4 Isolating the cause: cadence, or the missing grade?

Four arms over identical 30-s windows and identical HR on the 8 GPS tracks:

| arm | 06-13 VO₂ axis SD | 06-13 result |
|---|---|---|
| A: GPS speed + DEM grade (shipped) | 3.44 | 19.0 |
| B: GPS speed, grade forced to 0 | **0.70** | 13.7 |
| C: cadence × stride, grade 0 | **0.69** | 13.1 |
| D: cadence × stride + DEM grade | 3.25 | 18.3 |

**A vs B is the whole story.** Removing grade collapses the workload axis by ~5×; swapping
GPS speed for cadence speed (B vs C) barely moves it. So cadence→speed is *not* the
dominant defect — **level walking simply has no metabolic dynamic range**, and on the GPS
path essentially all the apparent signal is the terrain term. That term is also what makes
the shipped method unstable here: it flips the slope's sign between days.

On 06-16 the cadence arm invents a slope of +0.257 (→ 29.4) where GPS says −0.026 (→ 11.6).
Cadence does not merely lose signal; it can fabricate it.

### 1.5 Walking-only: zero, at every threshold

Using the 140 spm walk-to-run transition [Chase 2023] to separate walking from running:
**54 of 64 bouts never exceed 140 spm.**

| gates | survivors | of which walking |
|---|---|---|
| r²≥0.5, range≥15 (shipped) | 2 | **0** |
| r²≥0.4 | 3–4 | 0–1 |
| r²≥0.3 | 4–5 | 0–1 |
| r²≥0.2 | 6–7 | 0–1 |
| **walking-only bouts, r²≥0.5 / 0.3 / 0.2** | **0 / 0 / 0** | **0** |

**Every survivor at every tuning is a running bout** (peak cadence 166–175 spm). Walking
produces nothing, and relaxing the gates only admits more running.

### 1.6 The stride constant swings the answer more than the physiology does

Same bout (2026-06-15), three defensible speed models:

| speed model | VO₂max |
|---|---|
| corpus canonical stride 0.737 m ([[distance_from_steps]]) | **28.2** |
| his own GPS-measured median stride 0.820 m | **34.3** |
| Sekiya walk-ratio form (step length = 0.0065 × cadence) | **47.7** |
| *shipped GPS method — measured speed + DEM grade* | *39.6* |

A **19.5 mL/kg/min** spread, driven entirely by an unmeasurable constant. That is 3.5× the
entire SEE of the Jurca model. **With the corpus's own canonical constant the method
yields 1 estimate in 110 days** — and it is a running bout.

This is exactly the failure mode the task was created to stop repeating: a number produced
by choosing a constant.

### 1.7 Error budget — worse than the thing it replaces

Three independent terms, in quadrature, on the only two bouts that survive every gate
(both running, using the *favourable* GPS-borrowed stride):

| term | 2026-06-10 | 2026-06-15 |
|---|---|---|
| regression extrapolation SE | ±1.53 | ±3.36 |
| HRmax uncertainty (SD 10 bpm, Tanaka 2001) | ±2.54 | ±4.24 |
| **stride length across his own p5–p95** | **±9.96** | **±14.47** |
| **combined 1 SD** | **±10.4** | **±15.5** |
| Jurca SEE (the model it would replace) | 5.6 | 5.6 |

**Roughly 2–3× worse than the model it replaces, in the best case available.** And the two
survivors — 5 days apart — differ by **5.8 mL/kg/min**, which no real VO₂max does in 5 days.
That spread *is* the noise floor.

Note the trap in the extrapolation term: on flat-slope walking bouts, `SE_extrap` computes
as small as ±0.4, because a tight fit around a flat line has low residual scatter. **Low
standard error with a wrong answer** — precision reported as accuracy — is precisely the
confident-wrongness this product exists to prevent. Any design must gate on the *slope's*
identifiability, never on r² or SE alone.

### 1.8 What the literature does and does not support

- **No validated cadence→speed relation exists for free-living walking** at the precision a
  regression slope needs. The walk ratio [Sekiya 1996/1998] says step length *rises with*
  cadence — so the corpus's own `speed = cadence × stride_length` phrasing in
  [[submaximal_vo2max]] is wrong by construction — and its constancy breaks below ~62 m/min
  / ~98 spm [Murakami & Otaka 2017], which is most free-living ambulation.
- **No published validation of submaximal HR-vs-workload extrapolation from cadence-derived
  speed** was found. The 6.85% MAPE / CCC 0.70 figures in the corpus are from GPS-paced
  *running*.
- **The device-native model that works does not use this chain.** Neshitov 2023 (Sci Rep
  13:15808) uses cadence-to-HR ratio quartiles and 15 coefficients from piecewise quantile
  regressions of HR *response* to cadence — no speed estimate anywhere. Its error against
  **laboratory** VO₂max is **4.98** mL/kg/min (n=10), not the 3.946 quoted in the brief
  (that is the held-out test set against model-derived labels). Against Jurca's 5.6 that is
  a ~0.6 mL/kg/min improvement, and the model and data are **not public** — Welltory Inc.,
  on request only. Reconstructing it from the paper would be fabrication.

---

## 2. Design

### 2.1 What is NOT built

No cadence-derived VO₂max. No new stride constant. No relaxation of `MIN_R2`. The
measurement says the input cannot carry the inference, so the design is to **withhold**,
and to make the withholding informative.

### 2.2 What IS worth building (small, and each independently useful)

**(a) Score the 8 existing GPS tracks.** `derive_vo2max_submax` is reachable only from
`read/gps.py` on upload; prod has 8 unscored tracks and 0 `vo2max_submax` rows. A one-off
backfill would put one real measurement (39.6, 2026-06-15) on the board and give #108's
withdrawal of 51.1 an independent corroborating number. This is the single highest-value
item in this task and it needs no new science.

**(b) A `submax_unavailable_reason` seam** — mirroring the existing
`derive/vo2max.py::withhold_reason_for_day` pattern exactly (recomputed, not persisted, so
no migration and no backfill). It answers "why is there no measurement today" from the same
inputs already in the DB, in this precedence order:

| reason | condition | what the owner is told |
|---|---|---|
| `no_ambulation_bout` | no bout ≥10 min at ≥60 spm | "No sustained activity recorded." |
| `walking_only` | no bout reached ~140 spm and no GPS track | "Walking alone can't measure this — the effort has to be hard enough to move your heart rate with your pace." |
| `no_measured_speed` | bout qualified on cadence but no GPS track | "This needs a recorded outdoor session — cadence alone can't measure your speed." |
| `workload_range_too_narrow` | VO₂ axis SD < 1.0 mL/kg/min | "Your pace was too steady to read a slope from." |
| `slope_not_identified` | slope ≤ 0, or its 95% CI includes 0 | "Heart rate didn't track effort in this session." |
| `poor_fit` | r² < 0.5 | existing reason, unchanged |

**(c) The withhold rule — fail closed, and on the slope.** A fit is untrustworthy, and the
value is withheld, when **any** of:

1. fewer than `MIN_WINDOWS` steady windows;
2. HR range < `MIN_HR_RANGE`;
3. **VO₂-axis SD < 1.0 mL/kg/min** — *new, and the one that actually bites*. Measured: 53
   of 60 of this owner's bouts fail here. This is the gate that stops a flat line being
   extrapolated;
4. **the slope's 95% CI includes zero** — *new*. Gates on identifiability rather than on
   r², which §1.7 shows can look fine while the slope is meaningless;
5. r² < `MIN_R2`, slope ≤ 0, or the result outside `[VO2MAX_LO, VO2MAX_HI]` (unchanged);
6. **speed was not measured** — a hard precondition, not a quality gate. No GPS ⇒ no
   submaximal estimate, full stop.

Gates 3 and 4 are worth adding *even to the GPS path*, since §1.1 shows it produces
r²=0.07 fits on this owner and §1.4 shows its apparent signal is mostly terrain.

**(d) Tests that would pin it** (all pure, no DB):

- **Known-value**: the 2026-06-15 track → 39.6 exactly (golden fixture from the real dump).
- **Flat-workload rejection**: a synthetic bout with constant cadence and rising HR (cardiac
  drift) MUST withhold with `workload_range_too_narrow` — this is the degenerate case that
  returns "the VO₂ of walking" and it must never produce a number.
- **Stride-invariance guard** (the anti-fabrication test): assert that no shipped code path
  converts cadence to speed for a VO₂max input. An AST/grep guard in the spirit of
  `tests/db/test_tenant_read_scoping.py`. This is what stops #109's conclusion from being
  quietly re-litigated by a future agent, the same way the Jurca SRPA substitution was.
- **Slope-CI gate**: a fit whose slope CI straddles zero withholds even when r² ≥ 0.5.
- **Reason precedence**: a bout failing several gates reports the *most actionable* reason,
  and the table above is asserted in order.

### 2.3 Minimum viable input — the honest answer to "what WOULD work"

From this owner's own data, a bout produced a usable fit only when **all** of:

- **peak cadence ≥ ~160 spm** (both survivors: 166 and 175) — comfortably above the 140 spm
  walk-to-run transition, i.e. **running, not brisk walking**;
- **HR range ≥ ~40 bpm** across steady windows (survivors: 43 and 81);
- **a measured speed** (GPS), because the stride constant otherwise swings the result by
  ±14 mL/kg/min;
- ≥15 steady windows after warm-up.

So the truthful product answer is: **a recorded outdoor run.** Not a walk, however long or
brisk. His 147-minute walk on 06-14 failed; his 18-minute run on 06-15 succeeded.

---

## 3. The precedence question (raised mid-task by the coordinator)

Today `read/vo2max.py::vo2max_payload` makes Jurca the headline and `submax` a secondary
block with a `vs_jurca` delta. The proposal is to invert it: the measurement leads, the
estimate falls back.

**Agreed in principle, with one hard condition.** Inverting is right — a measurement should
outrank a proxy — and it does not breach the one-canonical-definition law provided
`vo2max` remains **one metric with a documented precedence and a stated method**, never two
numbers both called "your VO₂max". The rule should be written into
[[submaximal_vo2max]]'s implementation section as: *`vo2max` is the submaximal measurement
when one is available under the precedence rule below; otherwise the non-exercise estimate;
otherwise withheld. The payload always names which.*

**The method-jump problem is real and this owner's data makes it concrete**, not
hypothetical: 51.1 (Jurca, being withdrawn) → 39.6 (GPS submax, 06-15) → withheld. Those
moves encode a change of instrument. Presenting them as fitness change is the
stale-as-current class in a new form.

**Recommendation — options 1 + 2 together, i.e. median plus hysteresis.** Ranking the
coordinator's three options against this data:

- **Option 3 (always show both)** is the most honest and the weakest product. It also does
  not solve the problem it is meant to: bio-age must still consume exactly one number, so
  the precedence decision merely moves somewhere less visible. **Reject as the primary
  mechanism**, keep as the *presentation* (both remain visible and labelled).
- **Option 1 (promote the median, not the latest)** is necessary but **not sufficient on
  its own**. `_submax_block` already computes it, and it is the right robustness move — but
  with n=2 sessions 5 days apart differing by 5.8 mL/kg/min, a 2-point median is not
  stable. It needs a minimum count behind it.
- **Option 2 (hysteresis)** is what actually prevents flip-flopping, and it is the one the
  data demands.

**Concretely:**

1. The headline is the **submax median over a 90-day window**, never the latest session.
2. It is promoted to headline only once there are **≥3 sessions in the window** (this owner
   has 1 — so under this rule he correctly stays on the fallback, or on withheld, today).
3. Once promoted it **stays** until the window empties below 2 sessions, rather than
   switching back on the first quiet week.
4. The payload states `method: "submaximal" | "non_exercise"` on every response, plus a
   `method_changed_on` date whenever the method differs from the previous day's.

On the **constraints**:

- **Never blend.** Endorsed without qualification. §1.6 shows the two methods disagree by
  11.5 mL/kg/min on the same owner (39.6 vs 51.1); averaging them would produce a third
  number with no validation, which is #86/#108 again.
- **Visible, not silent.** A method switch should surface in the existing payload
  vocabulary. The right word here is a new one: `withheld` means "you can fix it",
  `excluded` means "nobody can price it", `caveats` means "it's in your number" — a method
  change is none of those. Suggest **`method_change`**: *"This number now comes from a
  measured session rather than an estimate. The change reflects the instrument, not your
  fitness."*
- **Bio-age must consume ONE number, and it should be the same headline number**, for the
  same reason there is one canonical definition per metric: a bio-age computed off a
  different VO₂max than the one displayed is two definitions of fitness in one product.
  Given the ≈1.8 y per 3.5 mL/kg/min amplification, the hysteresis rule above is what keeps
  bio-age from inheriting an instrument jump. **Additional recommendation:** on any day the
  method changes, bio-age should carry the `caveats` marker naming the switch — this is
  exactly the vocabulary #101 established, and this is the case it was built for.

**This is a product decision and is presented as a recommendation, not a fait accompli.**
The owner decides; the measurement above is offered as the input to that decision.

---

## 4. What could not be sourced

- **A cadence→speed relation validated for free-living walking** at the precision a
  regression slope requires. The walk ratio is the closest and it is a *within-person
  invariant with a low-speed floor*, not a population constant. **No constant was invented**
  — this is the finding, and it is why the design withholds.
- **Any peer-reviewed validation of submaximal VO₂max extrapolation from cadence-derived
  speed.** Absence stated as absence.
- **The Neshitov 2023 model or weights** — not public (confirmed in the paper's data
  availability statement). Not reconstructed, per the brief's instruction.
- ~~**An individual SEE from Tanaka 2001 itself**~~ — **RETRACTED by #112 (2026-08-02).**
  This section originally claimed the paper publishes only the group regression (r = −0.90)
  and that the ±10–12 bpm figure traces to Robergs & Landwehr 2002. That was wrong, and it
  was reached from the abstract rather than the full text. Tanaka 2001 has **two halves**:
  the meta-analysis regresses group means, but the 514-subject laboratory cross-validation
  reports "standard deviations ranging from 7 to 11 beats/min", and the discussion states
  "the wide range of individual subject values around the regression line for HRmax
  (SD ∼10 beats/min)". Robergs & Landwehr 2002 report Sxy 7–11 b/min across age-based
  equations generally and list **no** Sxy for Tanaka (Table 3: N/A) — they corroborate the
  magnitude, they are not its source. The corpus cites Tanaka.

---

## 5. Reproducing the measurements

Scripts are scratch (not committed). Restore the dump into a scratch Timescale container
and run against `apps/server` with `uv run python`:

| script | what it measures | § |
|---|---|---|
| `a1_gps_reference.py` | shipped GPS method over the 8 real tracks | 1.1 |
| `a2_cadence_speed.py` | cadence↔GPS speed, implied stride distribution | 1.2 |
| `a3_cadence_only_sweep.py` | HR range + steady windows over all 110 days | 1.3 |
| `a4_headtohead.py` | cadence-only vs GPS on identical windows; extrapolation variance | 1.7 |
| `a5_decompose.py` | 4-arm decomposition (speed source × grade source) | 1.4 |
| `a6_full_gates.py` | full pipeline, every shipped gate | 1.3 |
| `a7_sensitivity.py` | stride and gate sensitivity; walking-only arm | 1.5 |
| `a8_error_budget.py` | 3-term error budget vs Jurca SEE | 1.7 |
| `a9_canonical_stride.py` | corpus canonical constant vs alternatives | 1.6 |

Knowledge note added: `packages/knowledge/notes/activity/cadence_derived_speed.md`
(grade **Probable**), manifest regenerated (77 records).
