---
id: napping
name: "Daytime napping"
topic: What a short nap does and costs, why the nap/health literature disagrees with itself, and why a nap never enters a Healthee night-sleep metric
category: sleep
grade: Probable
summary: "A 10–20 minute afternoon nap appears to restore alertness for roughly two hours, and naps of 30 minutes or more buy that back with sleep inertia — a period of *worse* performance on waking. Whether habitual napping is good or bad for long-term health is genuinely disputed: the same literature contains a 1.82 CVD rate ratio for naps ≥60 min/day and a 0.52 hazard ratio for napping once or twice a week. Our strap tags naps itself and they are excluded from every night-sleep metric by design, so a nap is visible to the coach as a session but changes no number."
aliases: ["nap", "naps", "napping", "power nap", "power naps", "siesta", "afternoon nap", "cat nap", "daytime sleep", "daytime sleeping", "should i nap", "how long should i nap", "nap length", "nap duration", "sleep inertia", "groggy after a nap", "nap instead of sleep"]
applies_to_metrics: ["tst_min", "sleep_regularity_index", "sleep_health_score_4dim", "sleep_debt_min"]
applies_to_interventions: []
population: general
last_reviewed: 2026-08-01
related: ["sleep_need_debt", "sleep_regularity_index", "sleep_duration_mortality", "sleep_health_score_multidim", "recovery_readiness", "caffeine_sleep"]
tags: [sleep, nap, alertness, sleep inertia, cardiovascular]
---

# Daytime napping

## Summary

The **acute** picture is reasonably clear and reasonably small. In sleep-restricted
young adults, a nap of **10 minutes** of actual sleep produced immediate
improvements in alertness, fatigue, vigour and cognitive performance that lasted
about **155 minutes**; a 20-minute nap helped from ~35 minutes post-nap for about
**125 minutes**; a **30-minute** nap first *impaired* performance — sleep inertia —
before helping; and a 5-minute nap did almost nothing (Brooks & Lack 2006, n = 24).
Sleep inertia typically resolves "within 30 mins of awakening" but "full recovery
does not appear to be complete until at least an hour" (Hilditch & McHill 2019).

The **chronic-health** picture is genuinely disputed, and the two best-cited
observational answers disagree on which axis even matters. A dose-response
meta-analysis of 11 cohorts (n = 151,588) found naps **≥60 min/day** carried a
cardiovascular rate ratio of **1.82 (1.22–2.71)** and an all-cause mortality RR of
**1.27 (1.11–1.45)**, with shorter naps not associated with either (Yamada et al.
2015). A Swiss cohort (n = 3,462) found nap **frequency**, not duration, was the
signal — napping 1–2×/week carried **HR 0.52 (0.28–0.95)** for incident CVD, and
"no association was found between nap duration and CVD events" (Häusler et al.
2019). Both cannot be the whole story.

For Healthee the operational facts are narrow and worth stating first: **the strap
tags naps itself**, naps are **excluded from every night-sleep metric we compute**,
and the coach can see a nap as a session row but has no nap-derived number to
reason from.

## What it is

A nap is a sleep episode outside the main nocturnal sleep period. In our data it is
a `sleep_session` row with `kind = 'nap'`, tagged by the device and carried through
the parser — **not** re-derived from time of day or duration on the server (see
"Healthee implementation" for why that distinction was expensive to learn).

The literature splits naps by three axes, and they are not interchangeable:

- **Duration** — "brief" (≤10 min), "short" (~20–30 min), "long" (≥60 min).
- **Frequency** — occasional vs habitual/daily.
- **Timing relative to the night** — early afternoon vs late afternoon/evening.

Almost every disagreement below is two studies measuring different axes and
reporting them as if they were the same thing.

## Physiology / mechanism

Sleep pressure (process S) accumulates across waking and discharges during sleep,
predominantly as slow-wave activity. A nap discharges some of it. That single
mechanism explains both halves of the note:

- **The benefit** — pressure is lower after the nap, so alertness rises.
- **The cost, part one: sleep inertia.** Waking out of consolidated slow-wave sleep
  leaves a transitional state of degraded performance. Depth at awakening matters:
  "increasing sleep depth was associated with slower response speed. This was
  particularly evident for awakenings from slow wave Stage 4 sleep", and inertia
  "is worse under conditions of prior sleep loss" (Hilditch & McHill 2019). A short
  nap tends to end before deep sleep consolidates, which is the mechanistic reason
  for "sleep inertia is less likely to occur after short naps (≤30 mins)".
- **The cost, part two: the night.** Pressure spent in the afternoon is not
  available at bedtime. Measured directly in a split-sleep experiment, slow-wave
  energy "significantly decreased for both split sleep groups, suggesting reduced
  sleep pressure", and "splitting sleep significantly reduced total sleep time
  (TST) by 6–21 min each day" (Cousins et al. 2021 — **adolescents**, see Honesty).

## The evidence

### Short naps restore alertness, and duration decides the shape of the curve [Probable]

Brooks & Lack 2006 remains the cleanest dose comparison. Design: repeated-measures,
"a no-nap control and naps of precisely 5, 10, 20, and 30 minutes of sleep",
24 healthy young adults who were good sleepers and **not regular nappers**, night
sleep restricted to ~5 h at home, naps at 15:00 followed by 3 h of laboratory
testing.

| Nap | Reported effect |
|---|---|
| 5 min | "few benefits in comparison with the no-nap control" |
| 10 min | immediate improvement across all measures, sustained ~155 min; "overall the most effective afternoon nap duration" |
| 20 min | improvements emerging ~35 min post-nap, lasting ~125 min |
| 30 min | "a period of impaired alertness and performance immediately after napping, indicative of sleep inertia", then improvement to ~155 min |

Graded **Probable, not Established**, deliberately: one laboratory study, n = 24,
young, non-napping, sleep-restricted. The *direction* is corroborated by review
(Milner & Cote 2009), but we could not verify an independent replication of the
minute-by-minute dose curve, and no cohort here resembles a middle-aged habitual
napper. *[abstract verified at publisher 2026-08-01; full text not read]*

### Sleep inertia is the real cost of a longer nap [Probable]

From the review (Hilditch & McHill 2019, full text read):

- Duration: "Studies comparing sleep inertia to pre-sleep values have typically
  shown a return to these levels within 30 mins of awakening", but "full recovery
  does not appear to be complete until at least an hour after awakening."
- Magnitude: in one cited experiment "performance on an addition test immediately
  after waking was significantly more impaired than after one night of sleep
  deprivation" (Wertz et al., as reported by the review — we did **not** read that
  primary).
- Modifiers: worse after prior sleep loss; worse waking from deep sleep; "sleep
  inertia effects are greatest during the biological night, near the circadian low
  in core body temperature."
- Countermeasure: "When taken before a short nap (eg 20 mins), caffeine has been
  shown to alleviate the symptoms of sleep inertia."

The caffeine point is a genuine finding and a genuine trap for us — a
pre-nap coffee is still an evening-caffeine dose if the nap is late. Defer the
timing arithmetic to [[caffeine_sleep]]; this note does not restate it.
*[full text verified via PMC 2026-08-01]*

### Naps and physical performance — one test, large effect [Probable]

A systematic review and meta-analysis of 18 studies (269 participants) of napping
**after normal night sleep** found napping improved the 5-m shuttle run test:
highest distance ES **1.026 (0.718–1.334)**, total distance **0.737 (0.488–0.985)**,
fatigue index **0.839 (0.211–1.458)**. Muscle force did **not** improve —
**0.175 (−0.134–0.483), p = 0.267**. Authors' conclusion: "Napping from 25 to
90 min, following normal night-time sleep, increases physical performance during
the 5-m shuttle run test" but the evidence "does not demonstrate that a diurnal nap
could improve muscle force"; no firm conclusion was possible for sprint, jump,
power, Wingate or endurance outcomes (Boukhris et al. 2023/2024).

Read that carefully before quoting the effect size. It is **one running test**,
269 participants across 18 small studies, and "only two studies used
polysomnography (the gold standard)". Meta-regression found nap duration had "no
impact" on the distance outcomes. *[full text verified via PMC 2026-08-01]*

### Napping and long-term health — the literature genuinely disagrees [Contested]

- **Duration is the axis** (Yamada et al. 2015, *Sleep*): 11 prospective cohorts,
  151,588 participants, mean 11-year follow-up. Naps ≥60 min/day vs no napping —
  CVD **RR 1.82 [1.22–2.71]**, all-cause mortality **RR 1.27 [1.11–1.45]**.
  "Napping for < 60 min/day was not associated with cardiovascular disease
  (P = 0.98) or all-cause mortality (P = 0.08)." The dose-response differs by
  outcome, and the difference matters: **CVD** was a J-curve — "the RR initially
  decreased from 0 to 30 min/day. Then it increased slightly until about
  45 min/day, followed by a sharp increase at longer nap times" — whereas
  **all-cause mortality was a positive linear relation**, rising about 4% per
  10-minute increment with no protective early segment. So the "short naps may
  help" reading is a CVD finding only; it does not transfer to mortality.
  The authors themselves name **reverse causality** — "persons with an increased
  risk (those who are sicker) are more likely to experience an outcome" — and
  confounding by depression and underlying illness.
  *[full text verified via PMC 2026-08-01]*
- **Frequency is the axis** (Häusler et al. 2019, *Heart*): CoLaus, n = 3,462, 5.3
  years, 155 CVD events. Napping 1–2×/week carried **HR 0.52 (0.28–0.95)** versus
  no napping. Napping 6–7×/week was HR 1.67 (1.10–2.55) unadjusted but **0.89
  (0.58–1.38) adjusted**. And explicitly: "no association was found between nap
  duration and CVD events." *[abstract verified at publisher 2026-08-01]*
- **A causal-inference attempt** (Dashti et al. 2021, *Nat Commun*): GWAS of
  self-reported napping in UK Biobank (n = 452,633), replicated in 23andMe
  (n = 541,333). Mendelian randomisation found more frequent napping associated
  with higher diastolic BP (**0.25 SD [0.15, 0.34], P = 2.99 × 10⁻⁷**), systolic BP
  (**0.18 SD [0.09, 0.27], P = 5.15 × 10⁻⁵**) and waist circumference (**0.28 SD
  [0.11, 0.45], P = 1.3 × 10⁻³**). MR is designed to survive reverse causation, so
  this is the strongest reason to take the harm signal seriously — and the authors
  are blunt about its limit: "Our analyses are limited by the crude assessment of
  daytime napping frequency via questionnaire with no information on duration or
  timing." *[full text verified via PMC 2026-08-01]*
- **The framing** (Mantua & Spencer 2017, *Sleep Med*, narrative review): naps give
  "memory consolidation, preparation for subsequent learning, executive functioning
  enhancement, and a boost in emotional stability" even when night sleep is
  adequate, yet frequent napping tracks "cognitive decline, hypertension, diabetes"
  in older adults. They call it a paradox and say it is premature to recommend
  napping as a general health intervention. *[abstract verified at publisher
  2026-08-01; not a systematic review — carried for framing, not for effect sizes]*

**This is why the note as a whole cannot be graded Established.** The three
observational answers point in three directions, and none of them measured naps
objectively — all are self-report.

### Naps and the following night [Probable]

- Observational (Mograss et al. 2022, *J Sleep Res*, n = 62 healthy adults,
  mean age 23.5, 8 days of actigraphy): "frequent nappers had a significantly
  higher KRA [sleep fragmentation] than moderate nappers (p < 0.01) and non-nappers
  (p < 0.02)", and "late naps were associated with poorer measures of night sleep
  quality versus early naps (all p ≤ 0.02)" — late defined as **< 7 h** before
  night sleep. Nap **duration** was not associated with the outcomes.
  Cross-sectional within-person association, not an intervention.
  *[abstract verified at publisher 2026-08-01]*
- Experimental (Cousins et al. 2021, *Sci Rep*, 112 adolescents aged 15–19, two
  simulated school weeks of 8 h or 6.5 h sleep opportunity, continuous vs split
  with a 90-min afternoon nap): "splitting sleep significantly reduced total sleep
  time (TST) by 6–21 min each day"; slow-wave energy "significantly decreased for
  both split sleep groups"; and split-sleep groups had **better** memory for
  afternoon-learned material (d = 0.572 at 8 h, d = 0.709 at 6.5 h).
  *[full text verified via PMC 2026-08-01]*

So a nap does cost the night something measurable — a modest amount of total sleep
and some slow-wave pressure — and can still be worth it. The trade is real in both
directions; do not present only one side.

## How we compute it

**We compute nothing from naps.** A nap is stored as a `sleep_session` row with
`kind = 'nap'` and its own stage hypnogram, and is deliberately excluded from every
derived metric:

- it emits **no** per-minute sleep samples (`ingest/upsert.py`: `if s.kind != "nap"
  and should_emit(s)`), so it cannot leak into `tst_min` or the sleep-window
  physiology averages;
- it does not trigger a night's re-derivation (`ingest/service.py`,
  `ingest/upsert.py::build_fresh_predicate` both filter `kind != "nap"`);
- it is excluded from `sleep_regularity_index` by design — the reasoning and the
  device-coverage caveat live in [[sleep_regularity_index]], which owns that
  decision; this note does not restate it.

Naps are read back only by `read/sleep_page.py::_naps` (sessions tagged `'nap'`,
≥5 min, with duration, local midpoint and stages) for the Sleep page, and they
appear in the coach's context as rows of the sleep-sessions table, where the `kind`
column distinguishes them.

## How the coach uses it

- **A nap is visible, not measured.** The coach can see that a nap happened, when,
  how long, and its stage split. It cannot see a nap trend, a nap baseline or a nap
  score, because none exists. Do not speak as if one did.
- **Never explain a low `tst_min` with a nap, and never add a nap to it.** Night
  sleep and naps are separate by construction. If the owner napped 90 minutes and
  slept 4 hours, the honest sentence names both numbers separately — it does not
  add them into "5.5 hours of sleep".
- **If asked how long to nap**, the citable answer is the dose curve: ~10–20 minutes
  of sleep appears to give a couple of hours of alertness, and past ~30 minutes the
  first thing that arrives is grogginess, not benefit — hedged, and attributed to a
  single small study in young adults.
- **If asked whether napping is healthy**, present it as debated, name both
  directions with their numbers, and say that no study cited here measured naps
  objectively. Do not resolve it.
- **Never present a nap as repayment of sleep debt.** [[sleep_need_debt]] owns the
  debt model; nothing in this note licenses a conversion from nap minutes to debt
  minutes, and we could source no such conversion at all.
- **The one timing caution worth offering** is that a nap taken less than ~7 h
  before bedtime tracked worse night sleep in one actigraphy cohort — offered as an
  association in young adults, not a rule.

## Safety bounds

- **A new or growing need to nap is a symptom, not a habit, and we do not diagnose
  it.** Sudden excessive daytime sleepiness can indicate sleep apnoea, narcolepsy,
  anaemia, thyroid disease, depression or medication effects. The coach must say
  plainly that this is a clinician's question and must not reassure the owner that
  it is fine, and must not name a cause. **SAFETY-CRITICAL** — see Coach Directive 5.
- Never tell someone to nap instead of seeking sleep for a chronic short-sleep
  pattern; a nap is not a treatment for insufficient sleep.
- Never present any CVD or mortality figure in this note as a statement about the
  owner. Every one of them is a population association from self-reported napping.

## Honesty & uncertainty

- **Nothing here was measured with a wearable.** Every long-term-health figure —
  Yamada, Häusler, Dashti — rests on **self-reported** napping. Dashti says it
  outright: "no information on duration or timing", and that self-report correlated
  only moderately with accelerometer-derived daytime inactivity. Our own nap data is
  device-detected and therefore is *not* the exposure any of these studies measured.
- **Reverse causation is the whole problem with the harm signal.** Yamada names it.
  Illness causes napping at least as plausibly as napping causes illness. The
  Mendelian-randomisation result is the one piece of evidence that partly escapes
  this, and it speaks only to blood pressure and waist circumference, not to events
  or death.
- **The two headline cohorts disagree about which axis matters** — duration
  (Yamada) versus frequency (Häusler) — and each reports the other's axis as null.
  We surface both rather than picking. Anyone quoting one of these numbers without
  the other is quoting half a literature.
- **The acute dose curve is one study of 24 young non-nappers who had been sleep
  restricted.** It is the best comparison of nap lengths we could verify, and it is
  thin. Habitual nappers may differ: Milner & Cote 2009 reviewed experience with
  napping as a moderator, but we did not read that full text and quote no figure
  from it.
- **Age is almost certainly a modifier and we have no numbers for it.** The harm
  associations concentrate in older adults; the benefit experiments are in young
  adults and adolescents. We could source no study that measured the same nap
  protocol across ages.
- **We could not source a nap-to-sleep-debt conversion.** No study we found
  quantifies how much of a night's sleep loss a nap of a given length repays. This
  is a genuine gap and it is exactly the question a chronic short sleeper asks. The
  honest answer is that we do not know.
- **We could not source anything about naps and overnight HRV, resting heart rate,
  or recovery.** [[recovery_readiness]] lists a range of confounders for a
  low-recovery morning; napping is not among the ones this note can support either
  way.
- **The split-sleep experiment is in adolescents (15–19).** Its TST and slow-wave
  numbers should not be quoted as adult figures.
- **The physical-performance meta-analysis is dominated by one test** (5-m shuttle
  run) in small, mostly athletic samples, with polysomnography in only two of 18
  studies. The effect size is large; the evidence base is narrow.
- **Our nap capture is a device behaviour, not a specification.** The strap tags
  naps itself and short ones do not appear at all; the coverage caveat is stated in
  [[sleep_regularity_index]] and we defer to it rather than restating a threshold
  this note did not measure.

## Bottom line

**Act on confidently:** a nap and a night are different things and we never mix
them; a nap of ~30 minutes or more will usually cost you a few groggy minutes on
waking; and we compute no number from naps at all.

**Hold loosely:** the exact nap length that suits a given person; whether habitual
napping is good or bad for long-term health (genuinely unresolved, and confounded by
illness); how much a nap gives back against a short night (unknown); and every
minute-count in the dose curve, which comes from one small study.

## Coach Directives

1. Never add nap minutes to night sleep, and never explain a low `tst_min` by a nap.
   Report the two separately, by their own numbers. *(confidence: high)*
2. When asked how long to nap, give the dose curve with its hedge and its source —
   ~10–20 min of sleep for alertness without inertia, ≥30 min brings grogginess
   first (Brooks & Lack 2006, n = 24, young sleep-restricted adults) — and never
   state it as a rule that fits this person. *(confidence: moderate)*
3. When asked whether napping is healthy, present it as debated and give both
   directions with numbers (Yamada et al. 2015: ≥60 min/day RR 1.82 for CVD;
   Häusler et al. 2019: 1–2 naps/week HR 0.52, duration null). Do not resolve the
   disagreement and do not apply either to this person. *(confidence: high)*
4. Never present a nap as repaying sleep debt — no source we could verify quantifies
   that conversion. *(confidence: high)*
5. **SAFETY-CRITICAL:** if the owner reports a new, worsening or uncontrollable need
   to nap, or falling asleep unintentionally, say plainly that this belongs with a
   clinician. Do not reassure, do not offer a cause, do not offer a nap-length fix.
   *(confidence: high)*
6. State that our nap data is device-tagged and enters no derived metric whenever a
   nap is discussed as evidence for anything. *(confidence: high)*

## References

- Brooks A, Lack L. *A brief afternoon nap following nocturnal sleep restriction:
  which nap duration is most recuperative?* Sleep 2006;29(6):831–840.
  doi:10.1093/sleep/29.6.831. PMID 16796222. n = 24; 0/5/10/20/30 min of sleep,
  15:00 nap after ~5 h night. Source of every minute figure in the dose curve.
  *[abstract verified at publisher 2026-08-01; full text not read]*
- Hilditch CJ, McHill AW. *Sleep inertia: current insights.* Nat Sci Sleep
  2019;11:155–165. doi:10.2147/NSS.S188911. PMID 31692489. PMC6710480. Review;
  source of the inertia duration, the depth/circadian/sleep-loss modifiers, the
  "≤30 mins" observation and the pre-nap-caffeine countermeasure.
  *[full text verified via PMC 2026-08-01]*
- Boukhris O, Trabelsi K, Suppiah H, et al. *The impact of daytime napping
  following normal night-time sleep on physical performance: a systematic review,
  meta-analysis and meta-regression.* Sports Med 2024;54(2):323–345.
  doi:10.1007/s40279-023-01920-2. PMID 37700141. 18 studies, 269 participants;
  source of the 5-m shuttle-run effect sizes and the null muscle-force result.
  *[full text verified via PMC 2026-08-01]*
- Yamada T, Hara K, Shojima N, Yamauchi T, Kadowaki T. *Daytime napping and the
  risk of cardiovascular disease and all-cause mortality: a prospective study and
  dose-response meta-analysis.* Sleep 2015;38(12):1945–1953.
  doi:10.5665/sleep.5246. PMID 26158892. PMC4667384. 11 cohorts, n = 151,588;
  source of RR 1.82 / RR 1.27 and the J-curve. *[full text verified via PMC
  2026-08-01]*
- Häusler N, Haba-Rubio J, Heinzer R, Marques-Vidal P. *Association of napping with
  incident cardiovascular events in a prospective cohort study.* Heart
  2019;105(23):1793–1798. doi:10.1136/heartjnl-2019-314999. PMID 31501230.
  CoLaus, n = 3,462, 5.3 y, 155 events; source of HR 0.52 for 1–2 naps/week and of
  the null for nap duration. *[abstract verified at publisher 2026-08-01]*
- Dashti HS, Daghlas I, Lane JM, et al. *Genetic determinants of daytime napping
  and effects on cardiometabolic health.* Nat Commun 2021;12:900.
  doi:10.1038/s41467-020-20585-3. PMID 33568662. PMC7876146. GWAS n = 452,633 +
  541,333; source of the Mendelian-randomisation BP and waist-circumference
  estimates. *[full text verified via PMC 2026-08-01]*
- Mograss M, Abi-Jaoude J, Frimpong E, et al. *The effects of napping on night-time
  sleep in healthy young adults.* J Sleep Res 2022;31(5):e13578.
  doi:10.1111/jsr.13578. PMID 35253300. n = 62, 8 days actigraphy; source of the
  frequent-napper fragmentation result and the late-nap (< 7 h) association.
  *[abstract verified at publisher 2026-08-01]*
- Cousins JN, Leong RLF, Jamaluddin SA, Ng ASC, Ong JL, Chee MWL. *Splitting sleep
  between the night and a daytime nap reduces homeostatic sleep pressure and
  enhances long-term memory.* Sci Rep 2021;11:5275.
  doi:10.1038/s41598-021-84625-8. PMID 33674679. **112 adolescents aged 15–19**;
  source of the 6–21 min TST cost, the slow-wave-energy reduction and the memory
  effect sizes. *[full text verified via PMC 2026-08-01]*
- Mantua J, Spencer RMC. *Exploring the nap paradox: are mid-day sleep bouts a
  friend or foe?* Sleep Med 2017;37:88–97. doi:10.1016/j.sleep.2017.01.019.
  PMID 28899546. **Narrative review** — carried for framing only.
  *[abstract verified at publisher 2026-08-01]*
- Milner CE, Cote KA. *Benefits of napping in healthy adults: impact of nap length,
  time of day, age, and experience with napping.* J Sleep Res 2009;18(2):272–281.
  doi:10.1111/j.1365-2869.2008.00718.x. PMID 19645971. Review; cited only as
  corroboration that nap length, timing, age and napping experience are the
  moderators — **no figure is taken from it, we did not read the full text**.

## Healthee implementation & honesty policy

- **No `derived_daily` field.** A nap is a `sleep_session` row
  (`kind = 'nap'`, schema default `'main'`) with its own `stages` hypnogram and
  stage minutes. Nothing aggregates naps into a metric.
- **Naps are TAGGED by the device, never re-detected server-side.** This is load
  bearing for this owner specifically: a short night that ends early looks exactly
  like a nap to a time-of-day heuristic, and re-detection previously promoted a nap
  to "main sleep" and reported the night as 0.55 h. The tag flows
  parser → push (`kind`) → `sleep_session.kind` → every consumer's filter.
- **Three separate places exclude naps, and each is a different failure they
  prevent:**
  - `ingest/upsert.py` — `if s.kind != "nap" and should_emit(s)`: a nap emits no
    per-minute sleep samples, so it cannot contaminate `tst_min` or the
    sleep-window physiology averages (`hrv_sleep_avg`, `rhr_daily`, SpO₂,
    respiratory rate, skin temperature are all averaged over the *night* window).
  - `ingest/upsert.py::build_fresh_predicate` and `ingest/service.py` — a nap does
    not mark a day for re-derivation, so a nap cannot overwrite a night's derived
    row.
  - `sleep_regularity_index` — night-only by design; that note owns the reasoning
    and the device-coverage caveat.
- **Read path**: `read/sleep_page.py::_naps` returns naps ≥5 min for `/api/sleep`
  with `duration_min`, `midpoint_local` and `stages` (the mini-hypnogram the Sleep
  tab renders). The 5-minute floor is a display filter, not the device's capture
  threshold.
- **Coach visibility**: `insights/context_sessions.py::sleep_section` selects all
  sessions with their `kind`, so naps DO reach the coach's context as rows —
  with start, end, score and stage minutes — while contributing to no aggregate.
  The coach may therefore say *that* a nap happened and may not say what it did to
  any metric.
- **Honesty rules (binding):**
  - Never sum a nap into night sleep, in any surface, in any sentence.
  - Never state or imply a nap-to-sleep-debt conversion; none is sourced.
  - Never present a napping/health association as a statement about this owner —
    all of them are self-report population associations and they disagree.
  - When the owner reports a new or growing need to nap, route to a clinician
    without offering a cause or a reassurance.
