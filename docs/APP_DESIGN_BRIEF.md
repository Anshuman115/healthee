# Healthee — mobile app design brief

For a designer. Every field named here is real and already returned by the shipped API;
every number is from live production or the contract fixtures. Nothing below is
aspirational.

---

## 1. What this is, and the one rule that shapes every screen

A self-hosted health app built on data from a wrist strap the owner already bought. It
reads sleep, heart rate, HRV, SpO₂, steps, workouts and GPS, and turns them into a small
number of honest judgements.

**The rule: it never shows a number it cannot stand behind.**

That is not a tagline. It is enforced in code, and it is why this app must look different
from every other health app you have seen. Whoop, Oura and Garmin always show you a score
— they will interpolate, smooth, or quietly reuse yesterday's. This one refuses. When the
data is not there, the API returns a **withheld** block explaining what is missing and what
would restore it, and the app must render that as a **confident, designed state** — not an
error, not a spinner, not a greyed-out card that looks broken.

**Design consequence:** "no number" is a first-class screen state with as much care as the
happy path. If you design 20 beautiful cards and one sad empty state, you have designed the
wrong app.

---

## 2. Visual system

### DECIDED 2026-08-04: legacy structure, new skin

Two sources, and the split is deliberate:

| from the **legacy app** (`~/projects/healthee-legacy/app/lib/ui/`) | from the **new design** (`Healthee.html`) |
|---|---|
| screen set, navigation, information architecture | the entire colour system (below) |
| `instrument_charts.dart` — 704 lines of proven custom painters: `HArea` · `HBars` · `HStackedSleep` · `HHypnogram` · `HTimingChart` · `HDebtBars` | **Instrument Sans** as the single face |
| `theme.dart`'s shape — `HColors`, `HType`, and the tabular-numeral constant | the light/dark token pairs |
| the 24 shipped screens as the map of what exists | new components added since |

The legacy app is the **base**: it already knows the screen set and has real charts drawn
against real payloads. The new design supplies the **skin**. Do not re-derive either.

### Direction: modern instrument. Not editorial.

**Explicitly rejected** — an earlier internal doc proposed a "warm editorial" system with a
serif face and magazine-style layouts. **Do not use it.** No serif display type, no
drop-caps, no article-like measure, no paper textures, no beige.

**Do build:** a precise, quiet, modern instrument. Think a well-made measuring device or a
good trading terminal, not a lifestyle magazine.

### The token set — verbatim from the approved design, both themes

```
                        LIGHT                      DARK
--bg                    #f4f4f6                    #0a0a0e
--surface               #ffffff                    #141419
--surface-2             #fafafb                    #1a1a21
--chrome                #ffffff                    #141419
--ink                   #121217                    #f3f3f6
--ink-2                 #56565f                    #a2a2b0
--ink-3                 #6d6d7c                    #8d8d99
--line                  rgba(18,18,23,0.10)        rgba(255,255,255,0.10)
--line-2                rgba(18,18,23,0.06)        rgba(255,255,255,0.055)
--accent                #5145e5                    #8f87ff
--accent-2              #3f34c9                    #a9a2ff
--accent-soft           rgba(81,69,229,0.09)       rgba(143,135,255,0.14)
--fav      favourable   #1a7f57                    #4fc691
--fav-soft              rgba(26,127,87,0.10)       rgba(79,198,145,0.14)
--unf      unfavourable #a4680b                    #dfa550
--unf-soft              rgba(164,104,11,0.10)      rgba(223,165,80,0.14)
--alert    illness only #b8352a                    #ff7466
--alert-soft            rgba(184,53,42,0.08)       rgba(255,116,102,0.12)
--hole     WITHHELD     rgba(18,18,23,0.045)       rgba(255,255,255,0.05)
```

**`--hole` is the withheld state** (§3) — the number-shaped absence. It is a first-class
token in the design, not an afterthought, and that is exactly right for this product.
It is a **fill**, not a text colour: a dashed `--line` border around a `--hole`-filled box
where the number would have been, with the reason in `--ink-2` and the label in `--ink-3`.
A refusal spends no colour at all, because colour here is reserved for judgement.

> **The app and the public landing page deliberately DIVERGE — do not "fix" this.**
> The landing (`apps/landing`) is v5 "The Ledger": warm archival paper, clay/terracotta
> accent (`apps/landing/DESIGN.md` §3). The app is the indigo instrument above. Two
> surfaces, two looks, by the owner's choice. Any claim that the app's indigo matches
> the landing page is false and should be corrected wherever it appears.

**Type: `Instrument Sans`**, one face, system-ui fallback. Sizes run 10–18px for body and
labels, 26–34px for hero figures. Tabular figures **mandatory** on every number — the
legacy theme already has the constant for it.

| | |
|---|---|
| **Semantic colour** | Only `fav` / `unf` carry judgement; `alert` is reserved for the illness flag alone. Everything else is greyscale + accent. Never colour a card to decorate it. |
| **Theme** | Light default, full dark. Both are authored above — do not derive one by inverting the other. |
| **Surface** | Flat, hairline `line`/`line-2` dividers, generous radii, almost no shadow. Depth from spacing and contrast. |
| **Motion** | Charts animate **once** on first reveal, never on scroll-back. (Hard rule — §7.) |

### Never
- Card inside a card. Lists are **one** outer card with hairline `divide-y` rows. State
  accents go on a thin left border or content opacity, never a nested container.
- Rings/dials as the primary device. Everything uses them; they compress a rich signal into
  one arc and they are why every health app looks the same.
- Emoji, mascots, streak flames, confetti, "You crushed it!" Nothing in this product
  congratulates the user.
- Red for "bad." Unfavourable is a **signal**, not a scolding. Reserve true red for the
  illness/safety flag alone.

---

## 3. The honesty states — the part no other health app designs

Four states, all real fields on the API. They must be visually distinct at a glance.

| state | what it means | field | how it should feel |
|---|---|---|---|
| **ok** | a number we stand behind | `data_confidence: "ok"` | plain, confident |
| **withheld** | *you* can fix this | `withheld: {reason, message}` | calm, actionable, names the fix |
| **excluded** | *nobody* can price this | `excluded[]` | matter-of-fact, permanent |
| **caveat** | it IS in your number, here's the tilt | `caveats[]` | subtle, tappable, never alarming |

**Real withheld copy from production, to design against:**

> "Fewer than 3 nights of resting heart rate in the last week — wear the strap overnight for
> a few more nights and this comes back."

Design that as a **card with a number-shaped hole**, not a card that failed to load. Same
footprint, same title, same position — the value slot carries the reason and the remedy.
The user should read it as the app being careful, not broken.

**Caveats are the most interesting one.** Example live text:

> "The fitness term measures your VO₂max estimate against a reference for your age and sex.
> That reference is now the US standard — the median of 16,278 treadmill exercise tests in
> the FRIEND registry."

That is a footnote a serious user will love and a casual one will never open. Design it as
an unobtrusive marker on the number that expands — never a modal, never a badge that
demands attention.

### Provenance is part of the number

Some metrics carry **which instrument produced them** (`method`, `see_source`,
`measured_as_of`, `n_sessions`). VO₂max has three, with genuinely different error:

| method | means | error |
|---|---|---|
| `gps_graded` | fitted from a recorded session — the best we have | MAPE 6.85% |
| `hr_reserve` | inverted from heart-rate reserve on a run; **reads low** | modelled ±3.2 |
| `jurca_non_exercise` | a questionnaire model; measures no exertion | SEE 5.075 |

**These must never be averaged and must never be shown interchangeably.** The chart has to
say which one spoke, and the uncertainty band must visibly change width when the instrument
changes. That is a design opportunity nobody else has: a fitness number that is honest about
how it was obtained.

---

## 4. Screens

### 4.1 Today — the home screen

Endpoint `GET /api/today`. Real keys: `recovery`, `recovery_score`, `sleep_health`,
`sleep_debt`, `biological_age`, `cardio_load`, `mvpa`, `anomalies`, `illness_flag`,
`data_health`, `sparklines`, `today_hr_series`, `sleep_history_7d`, `recommendations`,
`action`.

Order by **what the user should act on**, not by metric family:

1. **Illness flag** — if present, it outranks everything. Deterministic, safety-critical, not AI.
2. **Recovery** — with its signal ladder (§5.1), not a bare score.
3. **Today's action** — one sentence, AI-generated, always cited.
4. **Sleep last night** — 4-dimension breakdown (§5.3), plus debt.
5. **Anomalies** — only when non-empty. "Outside your normal", per metric.
6. **Metric strip** — RHR, HRV, SpO₂, respiratory rate, steps, MVPA, calories. Sparkline + today vs baseline.
7. **Data health** — the freshness strip (§5.8). Quiet, always present.

### 4.2 Sleep

`GET /api/sleep` — `nights`, `naps`, `findings`, `cutoffs`, `research_notes`.

The 4-dimension score is **explicitly not a validated single number** and the app must say
so. Show four independent judgements against their real published cutoffs:

| dimension | cutoff (real, from the API) |
|---|---|
| duration | 7–9 h |
| efficiency | ≥ 85% |
| regularity (SRI) | ≥ 70 |
| timing (midpoint) | 02:00–04:00 |

### 4.3 Activity & fitness

`GET /api/activity` — `steps`, `distance`, `mvpa`, `cardio_load`, `acwr`, `vo2max`,
`workouts`, `fitness_plan`, `active_calories`, `total_calories`.

Hero is **VO₂max with its instrument** (§5.5). Then ACWR (§5.6), MVPA vs the WHO 150
min/week floor, and workouts with GPS routes.

### 4.4 Body & age

`biological_age` with `contributions[]` — each term has a name, a `delta_years`, and its own
`method`. This is a **waterfall**, not a score (§5.7). Live example: biological age **31.8**
against a chronological **32**, from a fitness term of **−0.5 y** and a sleep-duration term
of **+0.3 y**, with regularity **excluded** and three caveats attached.

### 4.5 Coach

Premium. Free-text questions, answers always cited, `grade_floor` and `data_coverage` on
every reply.

- Render `[note_id]` citations as **tappable chips** that open the research note. Sources
  are a feature, not clutter.
- `grade_floor` (Established / Probable / Emerging / Contested) is the **weakest** grade the
  answer rests on. Show it plainly.
- **Questions remaining** comes from `GET /api/entitlement.included[]` →
  `{feature, limit, used, remaining, window_days, resets_at}`. Show it always, not only when
  exhausted. A free user gets `included: []` — show **nothing**, never "0 of 20".

---

## 5. The charts — every one earns its place by making a real comparison

No chart may exist to decorate. Each must answer a question the number alone cannot.
**Custom-drawn, not a charting library's defaults.**

### 5.1 Recovery signal ladder ★ the signature chart
Replaces the ring everyone else uses. Real field: `recovery.signals[]`, each with
`{name, value, baseline, z, direction, unit, research_note_id}`.

A horizontal ladder, one row per signal (sleep duration, HRV, RHR, respiratory rate). Each
row plots **today's value against that signal's own baseline**, positioned by `z`. Centre
line = your normal. Favourable side and unfavourable side.

**Why it beats a score:** it shows *which* signal moved and by how much. A 72 tells you
nothing; "HRV is 1.4σ below your normal, everything else is at baseline" tells you what to
do. Tap a row → the research note behind it.

### 5.2 RHR / HRV baseline band
Line over 30–90 days, with a **shaded band** at your own rolling median ±1 MAD. The
insight is not the value, it is **multi-day departure**: highlight runs of ≥3 consecutive
days outside the band, because that is what actually predicts illness. Population norms are
irrelevant here and must not appear.

### 5.3 Sleep four-dimension bar
Four independent bars — duration, efficiency, timing, regularity — each against its real
cutoff, each pass/fail. **Never sum them into one number in the UI.** The API returns
`point_*` fields (0/1) and `max_score: 4` precisely so the app can show four judgements
rather than a fake composite.

### 5.4 Sleep debt accumulation
Cumulative area of nightly deficit against the `need_min` line (480 = 8 h). Live shape:
**debt 120 min over 14 nights, 12 of them below need, average 380 min slept.** The area
makes "small nightly shortfall, large monthly cost" visible in a way a single "sleep debt:
120 min" never does.

### 5.5 VO₂max instrument timeline ★ nothing else has this
Line over time where **each point is coloured and shaped by its `method`**, and the
uncertainty band **changes width** with the instrument — narrow for `gps_graded`, wider for
`hr_reserve`, widest for `jurca_non_exercise`.

Overlay the **population median for age and sex** (`median_for_age`, real value 39.7 from
the FRIEND registry) as a reference line, with `delta_from_median` called out.

Live example worth designing around: measured **39.6** on 06-15 (graded), **41.7** on 06-18
(reserve), then a 14-day gap where both expire and the model takes over at **40.6**. The
chart should make that handover legible and honest.

### 5.6 Training load — acute vs chronic
Real fields: `acwr: {acute_7d, chronic_28d, ratio, state}`. Two lines (7-day and 28-day
load) plus the ratio, with the **optimal band shaded**. `state` is already one of
optimal/under/over — colour from that, do not re-derive it.

### 5.7 Biological-age waterfall
Start at chronological age, one bar per contributing term with its `delta_years`, land on
biological age. Terms carry their own `method`, and some are **excluded** — show excluded
terms as an explicit gap with a reason, not by omitting them silently.

### 5.8 Data-health freshness strip
`data_health.items[]` → `{label, metric, status, age_h, last_iso}`. A thin horizontal strip,
one segment per stream (HR, steps, HRV, SpO₂, sleep), coloured by staleness.

**This is the owner-facing operational view** and it matters: production has served stale
data behind a healthy-looking screen before. The strip must make "this number is 85 hours
old" impossible to miss without being alarming.

### 5.9 Personal findings — scatter with cutoff
`findings` and `cutoffs` from `/api/sleep`. Scatter of the two correlated metrics with the
discovered cutoff drawn as a line. These are **single-subject, observational** and the label
must say so. This is the app's most personal insight — "when your MVPA rose 20%, your deep
sleep rose 12 min" — and the scatter earns its place by showing the spread, not just the
claim.

---

## 6. Tone

- Second person, plain, specific. **"Your RHR has been 3 bpm above your normal for four
  nights."** Not "Your recovery needs attention!"
- Never congratulate. Never scold. Never use urgency to drive engagement.
- Uncertainty is stated, not hidden: "estimate", "±5 ml/kg/min", "measured 7 weeks ago".
- When the app cannot answer, it says exactly what it would need.

---

## 7. Hard technical constraints

1. **Scrollable chart screens must use `ListView.builder` + reveal-once animation.** Charts
   replay on every scroll otherwise — a known, expensive bug in this codebase.
2. **Tabular figures everywhere.** Non-tabular numerals in a metric column is a defect.
3. **Every metric that can be withheld must have a designed withheld state.** Assume any
   number can be absent on any given day, because it can.
4. **Offline-first, and 60 days is a HARD boundary.** The on-device store holds **60 days**
   (`CLAUDE.md`); the app must be fully readable with no network.

   **This constrains the charts and the designer must know it.** Any window longer than 60
   days cannot be drawn from local data:

   | chart | window | offline? |
   |---|---|---|
   | RHR / HRV baseline band (§5.2) | 30 d | ✅ |
   | sleep debt accumulation (§5.4) | 14 d | ✅ |
   | training load ACWR (§5.6) | 28 d | ✅ |
   | personal findings (§5.9) | 30–60 d | ✅ |
   | **VO₂max instrument timeline (§5.5)** | **90 d** | ❌ needs network |
   | **any 90-day trend** | **90 d** | ❌ needs network |

   So: **default every chart to a window that fits in 60 days.** Where a longer view is
   genuinely worth it, the extra range is a deliberate, network-backed action — and when
   it is unavailable the chart shows its 60 days and *says* that is what it is showing.
   Silently drawing a shorter line and labelling it "90 days" is the same class of lie
   this whole product exists to refuse.
5. Flutter · Riverpod. ~~`apps/mobile/` is empty — this is genuine greenfield.~~
   **Superseded 2026-08-04:** the foundation is merged (`c24dabc`). There are still
   **no feature screens** — that part is greenfield — but the scaffold below already
   exists and must be built on rather than re-derived:
   - the token set of §2, both themes, in `lib/core/theme/`;
   - `Reading<T>`, a sealed union over the four honesty states of §3, which makes
     forgetting one a **compile error** (`lib/data/honesty/`);
   - `ValueHole` — the number-shaped hole of §3 — plus the shared loading /
     error-with-retry / empty states (`lib/shared/states/`);
   - one dio client, the drift 60-day store, and a golden test parsing the real
     contract snapshot.

---

## 8. What "good" looks like

A user opens the app and in three seconds knows: **can I train hard today, did I sleep
enough, is anything off.** A user who wants depth can reach the research note behind every
single claim in two taps. And on a day the strap did not sync, the app says so plainly and
still looks like the most trustworthy thing on their phone.
