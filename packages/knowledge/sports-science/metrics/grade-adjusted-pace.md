---
id: grade_adjusted_pace
name: "Grade-Adjusted Pace (GAP)"
category: metrics
grade: Probable
evidence_grade: 2
summary: "Converts hill pace to the equivalent flat pace by metabolic cost (Minetti); judge effort by GAP on hills, cross-checked with HR/RPE."
population: runners
aliases: ["grade-adjusted-pace", "GAP", "grade adjusted pace", "gradient adjusted pace", "hill-adjusted pace", "equivalent flat pace", "cost of transport", "metabolic cost of gradient running", "Minetti curve", "NGP", "normalized graded pace"]
applies_to_metrics: []
applies_to_interventions: []
last_reviewed: 2026-06-29
related: ["running-economy", "pace-zones", "training-load", "heart-rate-zones", "vertical-gain"]
units: "sec/km, %, J·kg⁻¹·m⁻¹"
---
# Grade-Adjusted Pace (GAP)

## Summary
Grade-Adjusted Pace converts your pace on a hill into the *equivalent flat pace*
that would have cost the same metabolic energy, so effort can be compared across
rolling terrain. The science is solid that the metabolic cost of running rises
steeply on uphills and falls on gentle downhills — bottoming out around −18 to
−20% grade before rising again — but it is **asymmetric**: uphills cost far more
than downhills save. The single most important coaching takeaway: **on hilly
runs, judge effort and prescribe pace by GAP (cross-checked with heart rate and
RPE), not by raw GPS pace** — but treat GAP as a population estimate that
degrades on steep, technical, or long descents and is only as good as the noisy
elevation data feeding it.

## What it is
GAP answers a practical question: "I ran this kilometre at 5:30/km up a 6% hill —
how hard was that *really*?" It maps your actual pace on a given gradient to the
flat-ground pace that would have demanded the same rate of energy expenditure
(metabolic cost of transport, *Cr*, in joules per kg of bodyweight per metre
travelled).

- **Inputs:** instantaneous pace + instantaneous grade (rise/run, as a %), usually
  sampled per GPS point or per segment.
- **Output:** an equivalent flat pace (sec/km), and/or a dimensionless
  *adjustment factor* `f(g) = Cr(g)/Cr(0)`.
- **Direction of the correction:**
  - **Uphill** → GAP is *faster* than actual pace (your slow uphill grind is
    "worth" a quicker flat pace).
  - **Gentle downhill** → GAP is *slower* than actual pace (gravity did some of
    the work).
  - **Steep downhill** (beyond roughly −15 to −20%) → the saving reverses and GAP
    creeps back toward / past actual pace because braking is metabolically and
    mechanically expensive.

Typical magnitude: on the Minetti metabolic curve a +10% grade roughly **doubles**
cost per metre while −10% roughly **halves** it (see table below). "Vanity-pace"
warning: GAP often makes hilly runs look faster than the watch did, because most
real-world routes spend more vertical metres climbing slowly than descending fast.

## Physiology / mechanism
Running on a gradient changes the balance of mechanical work the muscles must do:

- **Uphill** demands net **positive (concentric) work** to lift the centre of mass
  against gravity. Muscle does positive work at an efficiency of only ~25%, so
  raising bodyweight is metabolically expensive and cost climbs sharply and
  roughly linearly with grade once past ~+15% [Margaria 1968; Minetti 2002].
- **Downhill** requires net **negative (eccentric) work** to brake the descent.
  Eccentric contractions are extraordinarily cheap — Margaria measured an
  apparent efficiency near −120% — so a *gentle* descent lets gravity assist and
  lowers cost. But you cannot bank the saving indefinitely: as the descent
  steepens, braking forces, increased aerial time, and the muscular cost of
  absorbing impact rise, so cost passes through a minimum (~−18 to −20% on the
  Minetti curve) and then increases again [Minetti 2002; Vernillo 2017].
- **The elastic "bounce" of level/rolling running degrades on steep slopes.** On
  level ground the leg acts like a spring storing and returning elastic energy;
  near ±20% this spring-mass mechanism is largely lost (foot-strike pattern,
  contact time, step frequency and duty factor all shift), which is why graded
  economy stops behaving like level economy at the extremes [Vernillo 2017;
  Lemire 2021].
- **Downhill leaves a hangover.** Eccentric braking causes exercise-induced muscle
  damage (EIMD) and DOMS, which can *raise* the metabolic cost of subsequent
  running — a fatigue effect a single static GAP curve does not capture
  [Vernillo 2017; Lu 2025].

## The evidence

- **[Established]** The metabolic cost of running varies strongly and
  predictably with gradient: it rises on uphills, falls on gentle downhills, and
  has a minimum on a moderate downhill. Measured on 10 competitive male mountain
  runners on a treadmill across an exceptional range of −45% to +45%, the
  directly-measured level running cost ≈ **3.40 J·kg⁻¹·m⁻¹** (speed-independent),
  rising to ~18.9 at +45% and falling to a minimum of ~**1.7 J·kg⁻¹·m⁻¹ near
  −20%** [Minetti 2002]. (Note the best-fit *polynomial* intercept used by GAP
  implementations is **3.6**, slightly above the directly-measured level value of
  ~3.4 — this is a fitting artefact of forcing one curve across −45% to +45%, and
  GAP uses the polynomial's own `Cr(0)=3.6` as the denominator so the adjustment
  factor stays self-consistent.)
- **[Established]** The relationship is captured by Minetti's 5th-order
  polynomial for the cost of running *Cr* as a function of gradient *g* (fraction,
  not %):
  `Cr(g) = 155.4·g⁵ − 30.4·g⁴ − 43.3·g³ + 46.3·g² + 19.5·g + 3.6` (J·kg⁻¹·m⁻¹).
  This curve is the scientific backbone of essentially every GAP implementation
  [Minetti 2002].
- **[Established]** Uphill and downhill are **asymmetric**: the cost penalty of
  climbing is much larger than the cost saving of descending. From the Minetti
  curve, +10% grade ≈ **+66%** cost while −10% grade ≈ **−40%** cost (see table)
  [Minetti 2002].
- **[Probable]** The Minetti equations predict metabolic rate well on the level
  but lose precision on slopes. A large pooled re-analysis (original dataset n=62,
  plus 26 individual-subject studies n=424 and 12 group-mean studies n=187)
  reported RMSD ≈ **1.44 W·kg⁻¹ level**, **2.18 W·kg⁻¹ uphill**, and
  **1.57 W·kg⁻¹ downhill** for the Minetti equation, and proposed updated equations
  (RE3 / Hoogkamer–Taboga–Kram) that fit graded running better — e.g. the new RE3
  cut downhill RMSD to **1.45 W·kg⁻¹** [Looney, Hoogkamer & Kram 2025].
- **[Probable]** Across individuals, level, uphill and downhill running economy
  are *correlated* on shallow-to-moderate slopes — i.e. an economical flat runner
  tends to be economical on hills — **but the correlation breaks down near ±20%**,
  where graded energetics are governed by different factors [Lemire 2021, n=29].
  This is the core reason a single universal GAP curve cannot be accurate for
  everyone on steep terrain.
- **[Probable]** Commercial GAP (Strava) is built on the same Minetti foundation
  but refined empirically from very large activity datasets (Strava cites ~240,000
  athletes / millions of runs) using **heart-rate-equivalent** effort rather than
  pure metabolic cost. Strava's effective curve is *gentler on the uphill* than
  raw Minetti and its downhill benefit peaks around −10% before easing
  [Strava Support; Schroeder reverse-engineering]. Strava's exact formula is
  proprietary and unpublished.
- **[Contested]** What happens on **steep downhills** and how to weight braking
  cost is genuinely debated. Minetti shows a clear minimum near −20%; Strava caps
  the downhill benefit nearer −10%; practitioners note that **almost no runner can
  actually realise the modelled downhill savings** because of braking, footing,
  and quad fatigue. Power meters (e.g. Stryd) are reported to *underestimate*
  downhill cost. The "true" downhill correction is the least settled part of GAP
  [fellrnr; running practitioner consensus].
- **[Myth]** "GAP tells me my fitness/performance on hills." GAP normalises
  *energetic effort*, not race performance. It assumes you are a trained hill
  runner with intact muscles and ignores technical terrain, surface, wind,
  altitude and cumulative fatigue — so it systematically flatters downhills and
  cannot stand in for a field performance test.

### Cost & adjustment by grade (derived from the Minetti 2002 running polynomial)

| Grade | Cr (J·kg⁻¹·m⁻¹) | Cost vs level | GAP factor `f(g)` |
|------:|----------------:|--------------:|------------------:|
| −30%  | 2.46 | −32% | 0.68 |
| −20%  | 1.80 | −50% (minimum) | 0.50 |
| −15%  | 1.84 | −49% | 0.51 |
| −10%  | 2.15 | −40% | 0.60 |
|  −5%  | 2.75 | −24% | 0.76 |
|   0%  | 3.60 |   0% | 1.00 |
|  +5%  | 4.69 | +30% | 1.30 |
| +10%  | 5.97 | +66% | 1.66 |
| +15%  | 7.42 | +106% | 2.06 |
| +20%  | 9.01 | +150% | 2.50 |
| +30%  | 12.58 | +249% | 3.49 |

*`f(g)` is the multiplier on running **speed**: flat-equivalent speed ≈ actual
speed × f(g). Note these are raw-Minetti (metabolic) factors; Strava's
HR-equivalent uphill factors are noticeably smaller (~+2.5–3% effort per +1%
grade vs Minetti's ~+6%/1% near the level).*

## How we compute it
Owner: `@daud/core` `gradeAdjustedPace` (status: **to be implemented** — currently
a documented spec, not yet a shipped function).

1. **Grade** per sample: `g = Δelevation / Δhorizontal_distance`. Smooth elevation
   first (GPS/barometric noise dominates raw grade). Clamp `g` to a sane window
   (e.g. ±35%) before applying the curve.
2. **Adjustment factor:** `f(g) = Cr(g) / Cr(0)` using the Minetti polynomial,
   `Cr(0) = 3.6`. (A Strava-style HR-equivalent curve can be swapped in as an
   alternative model; keep the model choice explicit.)
3. **GAP speed:** `v_flat_equiv = v_actual × f(g)`; **GAP pace** = inverse.
4. **Aggregate** per segment/run by averaging flat-equivalent *speed* (or
   energy), weighted by time or distance — never by naively averaging pace.
5. **GPS correction:** at steep grades, horizontal GPS speed understates true
   path speed; apply a Pythagorean correction (`v_path = v_horizontal / cos θ`)
   where it matters (>~15%).

**Ground-truth caveat:** the polynomial is lab-measured *mean* cost on a treadmill
for trained runners; field GAP inherits both the model's population error (RMSD
~1.4–2.2 W·kg⁻¹) and the elevation sensor's error, which compounds on the grade
term.

## How the coach uses it
GAP is an **effort-normalisation lens**, applied differently by stage:

- **All stages — interpretation:** When a run is hilly (cumulative gain or any
  segment grade beyond ±3%), report and reason about effort using GAP, and say so
  ("your flat pace was 5:50 but grade-adjusted you were working at ~5:15"). Always
  **triangulate GAP with heart rate and RPE** — if HR/RPE disagree with GAP
  (common on long climbs, heat, or fatigue), trust the physiological signals.
- **Stage 1 (beginner):** Use GAP mainly to *reassure and prevent over-pacing* —
  explain that a slow uphill at high effort is appropriate and expected; do not
  push beginners to "hit GAP targets" on descents. Keep them on
  effort/HR-led easy running; GAP is explanatory, not prescriptive.
- **Stage 2 (developing):** Use GAP to **prescribe and audit** workouts on rolling
  terrain — e.g. set a tempo by grade-adjusted pace so the climb isn't accidentally
  a VO2 effort and the descent isn't junk. Flag when raw pace flatters or punishes
  a session.
- **Stage 3 (racing / trail):** Use GAP for **pacing strategy and load** — convert
  a goal flat pace into expected hill splits, and budget effort so the runner
  doesn't overspend on climbs. For **trail/ultra**, prefer a personalised or
  HR/power-anchored model and explicitly warn that modelled downhill savings are
  rarely realisable and that long descents accrue muscle damage that slows later
  km.
- **Load accounting:** Prefer GAP (or HR/power) over raw pace when estimating the
  intensity contribution of hilly runs to training load, so a hard hill session
  isn't logged as "easy" just because the watch pace was slow.

## Honesty & uncertainty
This section is mandatory — GAP is a useful estimate wrapped in real uncertainty.

- **Population model, individual runner.** The Minetti curve is the mean of 10
  trained male mountain runners; graded economy varies between people and
  *decorrelates from level economy near ±20%* [Lemire 2021]. Your true curve may
  differ, especially on steep slopes.
- **Asymmetry of error.** Models broadly agree on uphill cost but **disagree most
  on downhill**, and steeper-than-treadmill, technical, or off-camber descents are
  not represented at all. GAP almost always **over-credits descents** relative to
  what a runner can actually exploit.
- **Sensor noise dominates.** GAP is only as good as the grade signal. Raw GPS
  elevation and even barometric altimetry are noisy; small grade errors propagate
  strongly through the steep cost curve, so unsmoothed GAP can be wildly jumpy.
- **Fatigue & muscle damage are unmodelled.** Eccentric downhill loading causes
  EIMD/DOMS that raises the cost of later running; a static curve assumes fresh,
  intact muscle [Vernillo 2017; Lu 2025].
- **Run-and-walk reality.** Past roughly +20–25% (and on technical descents) people
  power-hike rather than run; the running cost curve no longer applies, and
  walking economy (cheaper at steep up, different at steep down) takes over
  [Minetti 2002].
- **Ignores everything non-gradient.** Surface (mud, sand, rock), wind, altitude,
  heat, footwear, and cumulative course profile all change real effort and are
  outside GAP. Strava itself states GAP "does not account for the technical
  difficulty or condition of the terrain."
- **Model disagreement is the honest headline.** Minetti, Strava, RE3/HTK, and
  power meters give materially different numbers on hills — converging on the flat
  and on gentle grades, diverging on the steep, especially downhill. Treat any
  single GAP number on steep terrain as ±a meaningful band, not a point truth.

## Safety bounds
- **Do not let GAP push pace on steep or long descents.** Downhill braking is the
  primary driver of impact load, EIMD and injury; the coach must cap *descent*
  prescriptions by effort/control, never by hitting a grade-adjusted pace target.
- **Beyond ±20–25% grade, suspend pace prescription** and default to
  effort/HR/RPE and walk-allowance; the running cost model is out of its validated
  range and most runners hike here.
- **GAP never overrides heart-rate or RPE ceilings.** On a long climb, an
  in-range GAP can still sit above a safe physiological intensity; the HR/RPE
  guardrail wins. (Mirrored in `@daud/core` intensity guardrails.)

## Bottom line

- **Act on confidently (conclusive):**
  - The metabolic cost of running rises steeply on uphills and falls on gentle
    downhills, with a minimum around −20% before rising again — a settled,
    well-replicated relationship [Minetti 2002; Vernillo 2017].
  - Uphill and downhill are **asymmetric**: climbing costs far more than
    descending saves (+10% ≈ +66% cost, −10% ≈ −40% cost on the Minetti curve).
  - On hilly terrain, **GAP (or HR/power) beats raw GPS pace** for judging effort
    and accounting training load; pace alone mis-rates climbs as easy and descents
    as hard.
  - **Method matters:** smooth/clamp grade before applying the curve and aggregate
    by flat-equivalent speed/energy, never by averaging pace.
  - Beyond ~±20–25% grade and on technical descents, the running-cost model is out
    of range and runners hike — suspend pace prescription there.

- **Hold loosely (unsettled):**
  - The **exact point accuracy** of any GAP number on a slope (Minetti RMSD ≈
    1.4–2.2 W·kg⁻¹; models diverge most on steep ground) — treat steep-terrain GAP
    as a band, not a point [Looney 2025].
  - The **true downhill correction**: Minetti's modelled savings (min near −20%)
    are larger and steeper than Strava's HR-derived curve (benefit peaks ≈ −10%)
    and larger than most runners can actually realise [Strava; fellrnr — contested].
  - **Individualisation on steep slopes:** graded economy decorrelates from level
    economy near ±20%, so the population curve may not fit a given runner there
    [Lemire 2021].
  - **Fatigue/muscle-damage effects** of long or repeated descents on later-km cost
    — real but not captured by any static GAP curve [Vernillo 2017].

## Coach Directives
- **D1:** When a run or segment exceeds ±3% grade (or has meaningful cumulative
  gain), compute and reason about effort using GAP rather than raw GPS pace —
  confidence: **Probable**.
- **D2:** Apply the Minetti 2002 running polynomial
  `Cr(g)=155.4g⁵−30.4g⁴−43.3g³+46.3g²+19.5g+3.6` as the default cost model;
  flat-equivalent speed = actual speed × `Cr(g)/3.6` — confidence: **Established**
  (relationship) / **Probable** (point accuracy).
- **D3:** Always cross-check GAP against heart rate and RPE; if they conflict
  (long climbs, heat, fatigue), trust the physiological signals over GAP —
  confidence: **Probable**.
- **D4:** Treat uphill/downhill as asymmetric — credit climbs near the modelled
  cost but **discount modelled downhill savings**, since most runners cannot
  realise them — confidence: **Probable** (downhill magnitude **Contested**).
- **D5:** Smooth/clamp the elevation-derived grade before applying the curve, and
  aggregate by flat-equivalent speed or energy (never by averaging pace) —
  confidence: **Established** (method).
- **D6:** Beyond ±20–25% grade, stop prescribing pace; switch to effort/HR/RPE and
  allow power-hiking — confidence: **Established** (safety/validity bound).
- **D7:** Never prescribe pace targets on descents; cap descent effort for impact
  and muscle-damage control, and warn that long downhills raise the cost of later
  kilometres — confidence: **Probable** (safety-critical).
- **D8:** Refine the gradient response from the runner's own HR-vs-GAP data over
  time rather than assuming the population curve fits them, especially on steep
  terrain — confidence: **Probable**.
- **D9:** Frame GAP to the runner as an effort-comparison tool, not a fitness or
  performance verdict, and disclose its uncertainty on steep/technical/long-descent
  terrain — confidence: **Established** (communication).

## Key references
- Minetti, A. E., Moia, C., Roi, G. S., Susta, D., & Ferretti, G. (2002).
  *Energy cost of walking and running at extreme uphill and downhill slopes.*
  Journal of Applied Physiology, 93(3), 1039–1046.
  https://doi.org/10.1152/japplphysiol.01177.2001
- Vernillo, G., Giandolini, M., Edwards, W. B., Morin, J.-B., Samozino, P.,
  Horvais, N., & Millet, G. Y. (2017). *Biomechanics and Physiology of Uphill and
  Downhill Running.* Sports Medicine, 47(4), 615–629.
  https://doi.org/10.1007/s40279-016-0605-y
- Looney, D. P., Hoogkamer, W., & Kram, R. (2025). *Metabolic energy expenditure
  during level, uphill, and downhill running.* European Journal of Applied
  Physiology. https://doi.org/10.1007/s00421-025-05999-5 (preprint:
  https://doi.org/10.1101/2025.06.05.658094; PubMed 41057734)
- Lemire, M., Falbriard, M., Aminian, K., Millet, G. P., & Meyer, F. (2021).
  *Level, Uphill, and Downhill Running Economy Values Are Correlated Except on
  Steep Slopes.* Frontiers in Physiology, 12, 697315.
  https://doi.org/10.3389/fphys.2021.697315
- Lu, Z., Suo, B., Deng, L., et al. (2025). *A review of uphill and downhill
  running: biomechanics, physiology and modulating factors.* Frontiers in
  Bioengineering and Biotechnology, 13, 1690023.
  https://doi.org/10.3389/fbioe.2025.1690023
- Margaria, R. (1968). *Positive and negative work performances and their
  efficiencies in human locomotion.* Internationale Zeitschrift für angewandte
  Physiologie, 25(4), 339–351. https://doi.org/10.1007/BF00699624
  (also https://www.semanticscholar.org/paper/Positive-and-negative-work-performances-and-their-Margaria/ebbb20ddd489725e601a0c3f18c2c21bb3944ae0)
- Strava Support. *Grade Adjusted Pace (GAP).*
  https://support.strava.com/hc/en-us/articles/216917067-Grade-Adjusted-Pace-GAP
- Schroeder, A. *Reverse-engineering Strava's Grade Adjusted Pace.*
  https://aaron-schroeder.github.io/reverse-engineering/grade-adjusted-pace.html
- fellrnr. *Grade Adjusted Pace.* https://fellrnr.com/wiki/Grade_Adjusted_Pace

## Healthee implementation & honesty policy
- **Not surfaced as a standalone metric — but the core math is already in-repo.**
  Healthee does not write a grade-adjusted-pace `derived_daily` field. However,
  the **Minetti 2002 gradient-cost model this note describes is already
  implemented** and used internally: `derive/vo2max_submax.py::_vo2_speed_grade`
  scales the ACSM level VO₂ by the Minetti gradient-cost ratio (correct uphill
  *and* downhill), with per-point grade taken from a terrain DEM
  (`derive/dem.py`, not noisy GPS altitude) and the gradient clamped to Minetti's
  **±0.45** validity range — inside the submaximal-VO₂max estimator, not as a
  user-facing GAP number. So the note is **reference science + a strong,
  low-effort future-metric candidate**: the validated cost model is ported and
  tested; surfacing a flat-equivalent pace per GPS segment is a small addition.
  (`applies_to_metrics: []` today; `daud_metrics` provenance dropped — the
  `gradeAdjustedPace`/`gradeAdjustmentFactor` helpers are the legacy `@daud/core`
  naming.)
- **Future-metric candidate (feasible from existing data).** `derive/gps.py`
  already yields per-segment speed and DEM-corrected grade over a recorded
  workout; feeding those through the existing Minetti ratio gives GAP directly,
  and it would immediately feed grade-aware `pace-zones` and `aerobic-decoupling`.
- **Population: runners** (and grade-affected walking); applies to graded outdoor
  GPS efforts, not to the flat step/MVPA activity Healthee derives today.
- **Honesty rules (carry into any future UI + the coach today):**
  - GAP is **valid only within ±45% grade** and **overstates achievable downhill
    speed** — it captures metabolic cost, not the eccentric/braking limit — so on
    steep descents cross-check with HR/RPE, never trust GAP alone.
  - GAP answers *what the flat-equivalent effort was*, not what it cost
    physiologically that day; pair with HR/effort as heat and fatigue accumulate.
