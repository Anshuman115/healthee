# Healthee — Pricing, Positioning & Unit Economics

What to charge for the premium (AI) tier, why, how we compare to Whoop/Oura, and
what it actually costs us to run. Companion to `docs/MULTI_USER.md` §12 (the gate
+ billing). **Prices decided 2026-08-02 — see §0.** The AI-cost math is no longer an
estimate: every per-surface figure in §3.1 is the provider's own `usage`, from real
requests replayed and counted. Plain-language version: `docs/MONEY_PLAIN.md`.

---

## 0. TL;DR — DECIDED 2026-08-02

> **This supersedes the 2026-07-16 prices.** They were set before anyone measured what a
> user costs. Every figure below is provider billing — real requests replayed and counted
> — not an estimate (§3.1). Plain-language working: `docs/MONEY_PLAIN.md`.

| | old (never measured) | **DECIDED** |
|---|---|---|
| Monthly | $3.99 | **$6.99** |
| Annual | $34.99 | **$69** (two months free, 18% off) |
| Lifetime | $99 | **dropped** |
| Free tier | 1 coach question / 7 days | **no AI at all** |
| Coach allowance | "unlimited (fair-use)" | **20 questions per rolling 30 days, stated** |

- **Free forever:** the whole honest **tracker** — every metric, chart, baseline, anomaly,
  personal finding, sleep/recovery/VO₂max number, logging. No forced sub to use hardware
  you bought. **And it now costs us exactly $0: the free tier has no AI surface at all.**
- **Premium:** **$6.99/month** or **$69/year**, including **20 coach questions per rolling
  30 days** — a question every day and a half. Insight cards, charts and everything
  deterministic stay unlimited; at $0.0084 a card they are free in practice.

> **The cap is 20, decided 2026-08-02**, and the window is a *rolling* 30 local days, not a
> calendar month — a calendar month lets somebody spend the cap on the 31st and the cap
> again on the 1st. Both numbers are executable in `api/gate.py`'s `PREMIUM_ALLOWANCE` and
> `PREMIUM_WINDOW_DAYS`, and `tests/premium/test_premium_cap.py` fails the build if this
> table and that one disagree.

### ⛔ #105 WAS RUN AND IT FAILED — the fallback is now the decision (2026-08-02)

A coach question costs **$0.179** because each of its ~3 calls re-sends the whole research
corpus. **#105 was the plan to stop that**: send the corpus only on the round that
actually writes the answer, since the tool rounds cite nothing. Projected ~$0.110.

**It was implemented and measured, and it saved nothing.** One repeat per arm through
`tests/grounding_eval` (INTELLIGENCE §9.3 has the full numbers): input tokens per question
**−2.9%, 95% CI −28.9k to +24.1k — sign not established**; **$0.77 on both arms**; and the
ship rate went **14/14 → 12/14** (2 pairs worse, 0 better, p=0.500 — not significant and
entirely one-directional). It was reverted.

Why, in one line: the round that *ends* gathering is a whole extra model call, break-even
is at one tool round and the measured mean is 1.2 — and the model responded to losing the
corpus by fetching it back with `get_knowledge` (7 → 18 invocations), one full-price round
at a time.

**So the cost of a coach question is $0.179 and there is no measured way down from it
today.** That is what decided the cap, and the arithmetic is why 30 was not survivable:

| at full use | **20 (DECIDED)** | 30 (rejected) |
|---|---|---|
| coach questions × $0.179 | **$3.58** | $5.37 |
| + nightly chain ($1.27) + 40 cards ($0.34) | **$5.19** | $6.98 |
| **$6.99/mo** margin | **+25%** | **−8%** ⛔ |
| **$69/yr** margin (≈$5.75/mo gross) | **+7%** | **−26%** ⛔ |

**⇒ DECIDED 2026-08-02: 20 questions per rolling 30 days at $6.99/$69.** The alternative
on the table was holding 30 and moving to $8.99/$99; it was rejected because the $69/year
figure *is* the wedge against Whoop's $199, and a cap that still allows a question every
day and a half costs the product almost nothing to state honestly. Live in
`api/gate.py::PREMIUM_ALLOWANCE`.

**Read the margins correctly**: they are the *worst case*, an owner using every question
AND opening 40 cards. At a realistic 10 questions the same $69/year runs ~51% margin. The
cap is the floor, not the expectation — what changed on 2026-08-02 is only that the floor
can no longer be argued away by a pending experiment.

**The path back to 30 at the same price is measured and unspent**: `DEFAULT_TOP_N` 6 → 4
— **−18.8% input tokens, sign established, ship rate flat** (INTELLIGENCE §9.1). Shrinking
the notes block beats moving it, and it was never landed. If it lands and holds, 30
questions costs what 24 does today and the cap can be raised without touching the price.
That is the path, not a promise: the cap moves when a measurement says it can, in the same
way it moved down.

### Why the rest

- **Lifetime is gone.** $99 covers ~23 months of normal use and then loses money forever.
  For a product pitched as "hardware you own for life", it makes your longest-tenured
  users your biggest losses. No version of it survives a per-question marginal cost.
- **A stated number beats "unlimited (fair-use)".** Unbounded cost against a fixed price
  is exactly why "we will never lose money" could not be promised as written. A limit that
  resets is honest; *"unlimited" with a silent throttle is the dishonest version of the
  same thing*, and this product does not do that. The stated number is **20 per rolling 30
  days**, it is enforced server-side, and the 402 that refuses a capped owner names the day
  it reopens rather than telling them to try later.
- **The old prices never cleared their own cost.** At a realistic 15 questions/month,
  $3.99 ran **−20%** and $34.99/yr ran **−53%**. Removing the free tier's AI deleted the
  19× giveaway multiplier but never touched that: premium had simply never been priced
  above what premium costs.
- **The wedge survives.** $69/year still reads as *"under $70 versus Whoop's $199"*, and
  everyone else still forces a subscription to see your own data.
- **⚠ The trade accepted deliberately.** With no AI in free, nobody converts having felt
  the coach. **Conversion will be lower than a trial model.** That is the price of a free
  tier that costs $0 — and it moves the selling job onto the landing page.

---

## 1. What we've built (the value being priced)

**Metrics & analytics (all free tier):**
- Vitals: resting HR, overnight HRV (RMSSD), SpO₂ (overnight + min), respiratory
  rate, skin temperature, device stress (framed honestly, see the stress note).
- Sleep: 4-dimension sleep-health score, stages, **sleep-regularity index (SRI)**,
  sleep need/debt + performance %, chronotype.
- Fitness: **VO₂max** (Jurca non-exercise *and* GPS-submaximal), **cardio load
  (Banister TRIMP)** + strain 0–21, MVPA vs WHO target, steps, distance,
  MET-by-state calories/TEE.
- Body & health: **biological age (Gompertz)**, weight/BMI, **illness early-warning
  flag** (RR/skin-temp/HRV deviation), recovery score + live readiness.
- Personal science: robust per-metric baselines (median/MAD), anomaly detection,
  **FDR-validated correlations + personal cutoffs** ("your caffeine after 3pm →
  −40 min sleep") — a rigor most consumer apps don't attempt.
- GPS workouts with route + submax VO₂max.

**AI layer (the premium tier):**
- A **grounded, citation-validated coach** that answers from *your* data + a
  69-note graded research corpus, refuses medical/diagnostic questions, and ships
  an honest fallback rather than an ungrounded claim.
- Daily **recommendations** (1–3, cite-or-drop), a daily **action** line, per-surface
  **insight cards** (sleep/activity/metric/workout), and **notable-shift** narratives.
- Everything carries evidence grades and confidence; nothing flatters.

**The three differentiators no competitor has all of:**
1. **Free hardware-life + free tracking** — pay only for intelligence.
2. **The honesty contract** — every interpretive claim is cited or it doesn't ship;
   "not enough data" beats an optimistic guess. Whoop/Oura AI coaches don't cite.
3. **Own-your-data / self-hostable** foundation.

---

## 1a. Tier split — AUTHORITATIVE (decided 2026-07-16)

**The line:** *Free = the numbers + the evidence* (what happened, vs your baseline,
with the research notes to read yourself). *Premium = the interpretation + the coach
+ the guidance* (what it means for you, and what to do). Never paywall data or
safety.

| Feature | Free | Premium |
|---|---|---|
| All metrics + charts + **full history** + trends/sparklines | ✓ | ✓ |
| Personal baselines + anomaly flags ("vs your normal") | ✓ | ✓ |
| Recovery score + live readiness + **deterministic** guidance string | ✓ | ✓ |
| **Illness early-warning flag** (deterministic; safety-critical) | ✓ | ✓ |
| Data-health / confidence chips | ✓ | ✓ |
| Manual logging · workouts · GPS routes | ✓ | ✓ |
| ⓘ **research notes** (read the evidence yourself) · offline evidence | ✓ | ✓ |
| Data **export** / own-your-data | ✓ | ✓ |
| **Personal findings** (FDR correlations + cutoffs) | ✓ shown as plain stats | ✓ + the coach **explains & acts on** them |
| **Challenges / programs** (adopt · track · outcome ledger · AI suggestions) | — (premium) | ✓ |
| **Notable-shift feed** (`/api/notable`) | — (premium) | ✓ |
| Per-metric anomaly flags on individual cards ("outside your normal") | ✓ | ✓ |
| **AI coach** | **— (no AI in free)** | ✓ **20 questions / rolling 30 days** |
| **Daily action line** | **— (no AI in free)** | ✓ daily |
| Sleep `tonight` line (this table never named it; same generator, same entitlement) | — (locked field) | ✓ daily |
| **Daily recommendations** (1–3 cite-or-drop) | — (locked card) | ✓ |
| **AI insight cards** (sleep · activity · metric · workout) | — (locked card) | ✓ |
| **Coach-companion** (memory · outcome-ledger narration · proactive nudges · goals, Phase 5) | — | ✓ |

**Design rules baked in:**
- *Detection is free, interpretation is premium — with two fully-premium surfaces.*
  The **findings** engine detection stays free as plain stats (the coach that
  explains/acts on them is premium). **Challenges/programs** (the whole system) and
  the **Notable-shift feed** (`/api/notable`) are **fully premium** (owner decision,
  2026-07-16). But the underlying per-metric **anomaly flags** on individual cards
  stay free — a free user still sees "this reading is outside your normal", just not
  the curated Notable feed or the challenge system.
- *Deterministic honest text stays free.* Recovery guidance and the illness
  framing are rule-based (not LLM) and illness is safety-critical → free.
- *No AI in the free tier — at all.* **Superseded 2026-08-02 (owner decision).** This
  rule used to grant free users 1 coach question + 1 daily-action reveal per rolling 7
  days as a "taste of premium". Measured, that taste cost **$0.81/owner/month FOREVER**,
  and at 5% conversion each paying user carried ~19 of them: **$15.39/month of giveaway
  against $3.12 of net revenue**. A weekly free LLM call is not a sample, it is a
  subscription given away — no amount of prompt-shaving fixes a recurring giveaway.
  The free tier now costs **exactly $0**. `core/allowance.py` and `api/gate.py`'s
  `FREE_ALLOWANCE` remain the executable table; the allowance is simply empty — **every
  entry is `0` as of 2026-08-02**, which is what makes re-granting a taste a number rather
  than a rewrite. The paid counterpart is `PREMIUM_ALLOWANCE`, and the two tables have
  opposite defaults: a feature absent from the free table is hard-locked, a feature absent
  from the premium one is unlimited.
  ⚠ **The cost of this:** nobody converts having felt the coach. That job moves to the
  landing page. Revisit if conversion proves worse than the giveaway was.

- *Full history stays free.* The anti-Whoop brand ("we don't hold your data
  hostage") is worth more than the freemium history-lock lever.

---

## 2. Competitive landscape

### 2.1 Data / feature comparison

| Capability | Healthee (Helio) | Whoop | Oura |
|---|---|---|---|
| HR · HRV · sleep stages · SpO₂ · skin-temp · resp-rate · stress | ✓ | ✓ | ✓ |
| Recovery / readiness score | ✓ | ✓ (recovery) | ✓ (readiness) |
| Strain / training load | ✓ (TRIMP + 0–21) | ✓ (strain) | — |
| VO₂max | ✓ (non-exercise + GPS submax) | ~ | — |
| Sleep regularity (SRI) + need/debt | ✓ | ✓ | ✓ |
| Biological age | ✓ (Gompertz) | ~ (Peak "healthspan") | ✓ (Oura age) |
| Illness early-warning | ✓ | ~ (health monitor) | ✓ |
| Personal cause-hints (FDR correlations/cutoffs) | ✓ **(rare)** | ~ | ~ |
| GPS workouts + route | ✓ | limited | — |
| **AI coach that cites its sources & refuses medical** | ✓ **(unique)** | coach, uncited | Advisor, uncited |
| **Hardware model** | one-time buy, **no forced sub** | **sub-only** ($199–359/yr) | ring $349+ **+ sub** |

We're at parity-or-better on the *metrics* and ahead on *honesty* + *personal
causality* — on hardware that doesn't hold your data hostage behind a subscription.

### 2.2 Pricing-model comparison

| | Hardware | Mandatory sub to see data? | Sub price |
|---|---|---|---|
| **Whoop** | "included" (locked to sub) | **Yes** | $199 / $239 / $359 per yr |
| **Oura** | $349+ ring | Core works free; insights paid | $5.99/mo · $69.99/yr |
| **Fitbit** | device | Premium optional | ~$9.99/mo |
| **Garmin** | device | Base free; "Connect+" AI paid | ~$6.99/mo |
| **Healthee (us)** | one-time (Helio), **no sub for tracking** | **No** — tracking free | **AI only: $3.99/mo · $34.99/yr · $99 lifetime** |

Whoop is the sharpest contrast: it *is* a subscription with a wearable attached.
Our whole pitch is the inverse.

---

## 3. Cost structure (what a user actually costs us)

### 3.1 AI / LLM — the only real marginal cost

All LLM goes through OpenRouter; default model **Gemini 3 Flash** ($0.50/M input,
$3.00/M output).

> ### ⚠ MEASURED 2026-08-01 (task #23) — the per-call assumption below was ~4× low
>
> This section used to assume "~**8k input tokens** … and ~**700 output tokens** per
> call". Both halves are wrong, in opposite directions, and the input half is the one
> that matters. Every surface's real request was captured and replayed through
> OpenRouter, so these are the **provider's own** `usage` counts, not an estimate:
>
> | Surface | input tok | output tok | tier |
> |---|---|---|---|
> | recs (nightly, JSON) | 33,426 | 543 | default |
> | briefing (nightly) | 35,304 | 158 | default |
> | daily action (nightly warm) | 33,780 | 93 | default |
> | sleep-tonight (nightly warm) | 31,582 | 110 | default |
> | sleep insight (on demand, cached/day) | 26,477 | 306 | default |
> | metric insight (on demand, cached/day **per metric**) | 27,100 | 109 | default |
> | coach — **per LLM call**, and a question is 3 typical / 22 worst | 33,446 | ~1,000–1,540 (≈99 % reasoning) | coach |
>
> **Input is 97–99 % of the tokens and ~85–95 % of the cost on every batch surface.**
> Output is a rounding error: the daily-action line bills 33,780 in to produce 93 out.
> Inside that input, **65–83 % is the EVIDENCE NOTES section** — the six full research
> notes retrieval embeds. The owner's own data is 9–12 %; the system prompt and the
> task together are under 2 %.
>
> What that does to the model above: **the nightly chain alone (4 calls) is
> ~$2.09/premium owner/month**, against this section's ~$1.77 for *everything*. Add the
> insight cards an engaged owner opens and the coach, and a premium owner is well past
> the §6.1 planning line. A **free** owner's teaser measures ~**$0.34/month** (one coach
> question ≈ $0.061 + one action reveal ≈ $0.021, both per 7 days) against §6.1's
> −$0.05 optimized budget — ~7× over.
>
> Caveats, stated: measured on the test seed (a small owner), so the *context* block is
> at the low end — the evidence block, which is the bulk, is owner-independent.
>
> ### ⛔ The coach-tier stand-in was wrong, and it understated (provider billing, same day)
>
> The line above used to end "the coach tier's list price is not public here, so its $
> figures use the Flash rate." The provider's own daily billing settles it, and the
> stand-in was not conservative:
>
> | tier | one day's spend | share |
> |---|---|---|
> | coach tier | **$19.20** | **85.2 %** |
> | batch/default tier | $3.33 | 14.8 % |
> | (lite, unused by us) | $0.0002 | ~0 % |
>
> That day's traffic was **84 % coach-surface prompt tokens** — so the split is a tier
> price difference, not a volume one: **the coach tier cost ~5.8× the batch tier for
> proportionally the same work.** Every coach figure above and in §6.1a is therefore a
> FLOOR, including the free tier's "one coach question per 7 days" — the lever the
> recommendation already singles out, now worse than it was scored.
>
> Do not re-derive a blended rate from this box: it is one day of mixed traffic (a
> grounding-eval harness plus normal use), not a rate card. It is recorded to kill the
> assumption, not to replace it with a second guess. The honest next step is to read the
> two tiers' published rates and price each surface at its own — the per-surface token
> counts above are already split by tier and need no re-measurement.
>
> Operational note from the same day: eval and production shared ONE OpenRouter account,
> which hit its $200 ceiling and 402'd the live AI layer while `/healthz` stayed green.
> **The alert half is now built (#104)** — the scheduler polls the *free* credits endpoint
> hourly and Telegrams a low-balance warning, plus an outage alert on 3 consecutive
> transport failures, and `GET /readyz` reports both without ever making a paid call. The
> two account-side halves stay a HUMAN task and are written up in `infra/DEPLOY.md` §E:
> **set a spend limit on the production key**, and **use a separate, small-limit key for
> eval/dev work** — the harness at ~$3/arm is what drained it, and no amount of alerting
> stops that from a key that is allowed to.
> Two things were measured and are NOT levers: **implicit prompt caching fires on an
> exact repeat of a whole payload, not on a shared prefix** (three A/B rounds: an owner
> repeating themselves cached 40,925 of 42,132 tokens; two owners sharing 30k of
> evidence cached nothing, in either message order) — so reordering the prompt to put
> the stable corpus first buys nothing, and cross-owner corpus dedup would need an
> explicit provider cache. And **~40 % of nightly generations end in the honest
> fallback** on this seed (34/59 validated across a paired A/B), each having paid for a
> full-context call *and* its nudged retry — so answer quality is a cost lever roughly
> the size of the prompt itself.

> ### ✅ #95 SHIPPED — the briefing and the daily action are ONE call (2026-08-02)
>
> The two rows above are no longer two calls. `briefing` asked, in its own words, for
> "today's single most useful action" and `daily action` asked for that line and nothing
> else, so the product paid twice for one answer. `insights/morning.py` now makes ONE
> JSON-mode call whose two fields become the Telegram briefing and `/api/today`'s action.
>
> **⚠ These figures are COUNTED, NOT BILLED** — and that is the one thing that must not
> blur into the table above, whose numbers are the provider's own `usage`. They come from
> a local dry run that assembles the real prompts (same system prompt, same v2 context,
> same manifest-ranked evidence) and tokenises them with `tiktoken/cl100k_base`, on a
> 40-day seeded owner. No provider call was made; no money was spent. The counter is not
> the provider's, so treat the RATIO as the measurement and the absolute counts as ±5 %
> (as a check on that: the same script counts the two old prompts at 72,103 where the
> provider counted 69,084 — 4.4 % high).
>
> | | input tokens (counted) |
> |---|---|
> | briefing, pre-#95 | 35,728 |
> | daily action, pre-#95 | 36,375 |
> | **the pair** | **72,103** |
> | **the merged call** | **37,787** |
> | **saved, per owner per shipping night** | **34,316 — −47.6 %** |
>
> Against the nightly chain's four calls (134,092 provider-counted input tokens, the rows
> above), that is **~24 % off the night**. At this section's Gemini 3 Flash rate
> ($0.50/M input) it is **~$0.017/owner/night ≈ $0.52/premium owner/month**; at the
> Flash-Lite rate the batch tier actually runs on today ($0.30/M) it is **~$0.31/month**.
> The token count is measured, **the rate is the assumption** — the billed figure is owed
> after the deploy, from the provider's own daily spend, exactly as the table above was.
>
> What the merge ADDS is counted too: +2,059 tokens on the briefing call, of which 1,360
> is widening its context window from 14 to 30 days (the daily action's window, kept
> because the action is calibrated from whole local days) and ~700 the JSON task plus the
> union of both surfaces' `metrics`. Output is unchanged in substance — both texts are
> still written once each, ~250 tokens together, ~1 % of the cost.
>
> **The failure tail is priced, not hidden.** The merged call is an optimisation, never a
> dependency: when it cannot ground itself, each surface falls back to the independent
> generation it made before #95, so neither can go dark because of the other's sentence.
> That costs one extra attempt on a failing night. The break-even is arithmetic: with a
> gate failure costing one nudged retry, the merge is cheaper whenever the merged call's
> total-failure rate is under **50 %** — measured at 0 % on current main (§9.3's arm,
> 14/14) and 31 % at the 2026-08-01 baseline.

Assumptions per active user (the original planning model, kept for continuity — the
box above is what to plan on now):

- ~**9 grounded calls/day** batch (recs + one retry, briefing, notable, daily
  action, ~4 cached insight cards) + ~**20 coach turns/month** (typical).
- ~**8k input tokens** (system + v2 context + top-6 full research notes) and
  ~**700 output tokens** per call.

| Scenario | Input $/mo | Output $/mo | **Total /user/mo** |
|---|---|---|---|
| Gemini 3 Flash, no caching | ~$1.16 | ~$0.61 | **~$1.77** |
| + prompt caching (stable system+corpus @10%) | ~$0.53 | ~$0.61 | **~$1.14** |
| Flash-Lite ($0.25/$1.50) + caching + batch API for nightly jobs | — | — | **~$0.55–0.80** |
| Power user (~150 coach turns/mo) | — | — | **+$0.50–1.00** |

**Planning number: ~$1–2 / user / month**, with a clear path to **<$1** via
caching + Flash-Lite + the Batch API (nightly jobs aren't latency-sensitive).
Levers already in the architecture: manifest-ranked retrieval bounds context,
per-day caching means insight cards generate once, and the jobs skip non-premium
users entirely (§12.3) so we never spend on locked output — **built in 6.6a**: a free
owner's nightly chain makes zero LLM calls (it keeps the two deterministic steps), so
today's cost per FREE user is infra only, below §6.1's −$0.05 line, until the teaser
of §1a lands in 6.6a-2.

### 3.2 Backend / infra — near-flat, tiny per user

Chosen stack (see `MULTI_USER.md` §0a): **Contabo VPS** (FastAPI + TimescaleDB +
scheduler, same compose as today), **Supabase** (managed auth), **Cloudflare**
(DNS/CDN/WAF + Pages for the web app).

| Component | Cost | Notes |
|---|---|---|
| Contabo VPS | **$4.95/mo** (4 vCPU/8 GB) → ~$8–15/mo (VPS 20/30) → $59/mo (18-core beast) | *unlimited traffic + free DDoS*; one cheap box serves hundreds of users; per-user health data is small, reads cheap (the `/api/today` fix helps) |
| Supabase (auth) | **$0** (free ≤50k MAU) → **$25/mo** Pro (≤100k MAU) | auth only; not the health DB |
| Cloudflare | **$0** (Pages + free plan) | CDN/TLS/WAF/rate-limit + web hosting |

Fixed infra total steps ~**$5–8/mo (early, Contabo entry + free Supabase/CF)** →
~**$60–100/mo (at ~50–100k users:** a bigger Contabo box + Supabase Pro) — so
**~$0.01–0.05 / user / month**. Infra is a **rounding error** next to the AI cost;
the LLM is essentially the whole cost line.

### 3.3 Payment fees

On the prices §4 decided (2026-07-16) — **$6.99/mo · $69/yr** (2026-08-02; was $3.99/$34.99), not the $4.99/$39.99
this section was originally written against:

- **Stripe:** 2.9% + $0.30/txn. On $3.99/mo → 0.029 × 3.99 = $0.116, + $0.30 =
  **~$0.42 (~10.4%)**; on $34.99/yr → 0.029 × 34.99 = $1.015, + $0.30 =
  **~$1.31 (~3.8%)**. Annual billing is dramatically more fee-efficient, and *more*
  so at the lower price: the fixed $0.30 is now **7.5%** of a monthly charge (it was
  6.0% at $4.99), which is the whole argument for pushing annual.
- **Polar (MoR):** ~4% + fee, but handles global sales-tax/VAT compliance for you.

### 3.4 Total marginal cost per user

| Plan | AI | Infra | Fees | **Total** |
|---|---|---|---|---|
| Monthly $3.99 | ~$1–2 | ~$0.20 | ~$0.42 | **~$1.6–2.6 / mo** |
| Annual $34.99 | ~$12–24/yr | ~$2.4/yr | ~$1.3/yr | **~$16–28 / yr** |

The totals round to the same band as the $4.99/$39.99 version, because a price change
moves the FEE (by 2¢/mo and 15¢/yr) and not the cost — which is the point worth taking
from this table: **cost is ~$1–2 of AI and a rounding error of everything else, at any
price we would plausibly charge.** What the price does change is the margin, and that
is §6.1's line, computed on the decided prices (blended fees −$0.23/mo: 60% × $0.110
annual-per-month + 40% × $0.416 monthly).

---

## 4. Pricing recommendation

| Tier | Price | Effective /mo | Gross margin* |
|---|---|---|---|
| **Monthly** | **$3.99 / mo** | $3.99 | ~55–62% |
| **Annual** (push this) | **$34.99 / yr** | $2.92 | **~65–72% optimized** |
| **Lifetime "own-it"** (donation path) | **one-time $99** | — | pays back ~2.8 yrs vs annual; brand-fit |
| Free trial | 14 days (card-on-file) | — | — |

\* margin widens materially once caching + Flash-Lite land (§3.1).

**Rationale (decided 2026-07-16):**
- **Under-$4 is the no-brainer threshold.** $3.99/mo maximizes the impulse-cheap,
  anti-Whoop framing that *is* the moat. Annual **$34.99/yr (~$2.92/mo)** beats
  Oura's $69.99 anchor and makes Whoop's $199+ look absurd — *"$35 a year vs Whoop's
  $199"* is the pitch.
- **Push annual hard.** It's ~27% off monthly AND far more fee-efficient — the fixed
  $0.30 Stripe fee is ~7.5% of a $3.99 monthly charge but under 1% of $34.99/yr, and
  all-in fees are ~10.4% vs ~3.8% (§3.3). (The ~3.7% this line used to attach to the
  *fixed* fee was the all-in rate.)
- **Lifetime $99** mirrors the free-for-life hardware ethos and maps to the
  donation/one-time path (`MULTI_USER.md` §12.4); it pays back in ~25 months vs
  monthly — great for the most enthusiastic early adopters.
- **Price-change asymmetry.** It's easy to discount *down* later, hard to raise
  *up*. Starting at $3.99 is right; if you ever raise it for new users, **grandfather
  the early cohort** at $3.99 to keep your first, most-loyal users happy.

**What NOT to do:** don't paywall the *tracking* (that would make us Whoop);
don't gate safety-critical honesty behind price; keep the free tier genuinely
excellent so premium is an upgrade, not a ransom.

---

## 5. Sensitivity, levers & risks

- **AI cost scales with engagement, not seats.** Heavy coach users cost more —
  the Batch API + caching + Flash-Lite keep even power users under ~$3/mo. If a
  whale emerges, soft rate-limits on coach turns/day protect margin.
- **Fixed-fee drag on monthly.** The $0.30 Stripe fee is **7.5% of $3.99** (all-in,
  ~10.4%) — another reason to push annual and the lifetime option.
- **FX / global tax.** Polar (MoR) removes VAT/tax-compliance risk for a slightly
  higher fee; worth it if selling internationally.
- **Model price moves.** Flash-tier prices trend down over time; our choke point
  makes swapping the model a one-line config change, so cost only improves.
- **Break-even.** At ~$2/user/mo cost ($24/yr) and **$34.99/yr** revenue, an annual
  subscriber covers their own cost ~**1.5×** — and ~**2.9×** once the optimized ~$1/mo
  lands. (This bullet used to claim "~15× over", which was never true at any price we
  considered: $39.99 ÷ $24 is 1.7. The business is still profitable at very low user
  counts, but on the margin per *premium* user carrying ~19 free ones — §6.1 — not on
  a 15× that does not exist.)

---

## 6. Profit & spend model (P&L)

Freemium math: **premium users pay, free users cost a little** (their weekly AI
"taste" + infra). The two dials that decide profitability are **conversion rate**
and **free-tier AI cost** — not the headline price.

### 6.1 Per-user unit economics (per month)

> ⚠ **The two cost rows below are the un-measured planning figures.** §3.1's measured
> box puts the nightly chain alone at ~$2.09/premium owner/month and a free owner's
> teaser at ~$0.34 — i.e. the premium row is optimistic and the free row is ~7× under.
> The tables here are deliberately NOT recomputed on the measurement: what to charge and
> which levers to take are the owner's call, not a measurement's, and quietly rewriting
> a P&L to match one night's numbers is how a doc ends up contradicting itself. Read
> §3.1 for what a user costs; read this for the shape of the business.

| | Planning (today) | Optimized (caching + Flash-Lite + Batch) |
|---|---|---|
| Blended premium revenue ($3.99/mo · $34.99/yr, 60% annual / 40% monthly) | $3.35 | $3.35 |
| − payment fees (blended) | −$0.23 | −$0.23 |
| − AI + infra cost (premium user) | −$1.70 | −$1.00 |
| **= profit per PREMIUM user** | **≈ $1.42** | **≈ $2.12** |
| Cost per FREE user (weekly teaser + infra) | −$0.12 | **−$0.05** |

The free-user cost looks tiny, but at 5% conversion each premium user "carries"
~19 free users — so **free-tier cost control is existential**. The teaser MUST run
on the cheap path (Flash-Lite + cache), or free users eat the margin.

### 6.1a What the measurement does to that math (2026-08-01) — ⛔ OWNER DECISION

Run §3.1's measured costs through §6.1's own structure and the base case does not
survive. Per cohort of 20 users at 5% conversion, per month:

| | Planning row | Measured |
|---|---|---|
| Premium revenue net of fees (×1) | +$3.12 | +$3.12 |
| Premium AI cost (×1) | −$1.70 | **−$2.09 nightly alone**, before any card or coach question |
| Free-tier cost (×19) | −$2.28 | **−$6.46** |
| **Net per cohort** | **≈ −$0.86** | **≈ −$5.43** |

The planning case was already slightly negative at 5%; the measured one is
**~6× worse, and the free tier is ~70% of the hole** — not the premium user's
nightly chain. That inverts the intuition the section was written on: the
expensive thing is not what we do for people who pay, it is what we give away
19 times over.

**The single biggest lever is the shape of the free teaser, not its efficiency.**
One coach question *per 7 days* is a recurring LLM subscription given away for
free — no amount of prompt-shaving fixes a recurring giveaway, it only makes each
instance cheaper. The options, with measured effects:

| # | Lever | Effect | Costs us |
|---|---|---|---|
| A | Free coach taste becomes **one-time** (N total on signup) rather than weekly | free ≈ $0.34 → **≈$0.09/mo** and it *decays to ~$0* | the weekly re-hook; conversion may drop |
| B | Free taste to 1 per **30 days** | free ≈ $0.34 → **≈$0.11/mo** | weaker hook, keeps the habit |
| C | Evidence block top-6 → **top-4** | **−18.8% input on every surface** (sign established, 95% CI −35,173 to −3,083; ship rate unchanged at n=42, p=1.0) | needs ~200 pairs (~$15/arm) to exclude a small quality loss — see #94/§9.1 |
| D | Merge `briefing` + `daily_action` (#95) — **SHIPPED 2026-08-02** | **−34,316 input tok/owner/night, −47.6% of the two calls, ~−24% of the nightly chain** (counted not billed, §3.1) | the canonical-definition risk went the OTHER way: the two surfaces now render ONE generated action instead of two that could disagree |
| E | Raise price | $3.99 → $5.99 adds ~$1.88 net/premium | competitive position (§5: Fitbit ~$9.99, Whoop bundles hardware) |
| F | Accept as CAC | nothing changes | needs a conversion target and a runway number |

**Recommendation (the owner decides; this is a recommendation, not a change):**
**A + C.** A attacks 70% of the hole at its root and is the only lever whose cost
*decays* rather than recurring — a one-time taste still demonstrates the product,
which is what a teaser is for. C is free money if the powered eval clears it,
since it cuts every surface at once. Together they take the cohort from ≈ −$5.43
to roughly break-even **without touching the price**, which preserves §5's
positioning and keeps the honest-and-cheap story intact.

Deliberately *not* recommended first: E, because the measurement is a reason to
fix the cost structure before asking users to fund it; and D, because it trades a
canonical-definition risk for a saving that A and C already cover.

> **D was implemented anyway, on 2026-08-02, and the reservation above did not survive
> contact.** The "possibly a second definition of today's action" risk was inverted, not
> accepted: before the merge the briefing's action and `/api/today`'s action were two
> independent generations that could disagree on the same morning; after it they are one
> generated sentence rendered on two surfaces. The availability risk — one failure darking
> both — is handled by construction rather than noted (§3.1's box). This changes nothing
> about the recommendation: **A + C are still the levers that close the hole**, because D
> only touches the premium owner's nightly chain and §6.1a's finding is that the free tier
> is ~70 % of it.

**Not decided here, and not to be silently implemented** — the tables above stay
as they are until the owner picks. What is settled is the measurement.

### 6.2 Monthly profit by scale (base case: 5% conversion, OPTIMIZED costs)

| Total users | Premium (5%) | Net revenue/mo | Cost/mo (AI+infra+fees+fixed) | **Profit/mo** | **Profit/yr** |
|---|---|---|---|---|---|
| 1,000 | 50 | $155 | ~$105 | **~$50** | ~$0.6k |
| 5,000 | 250 | $778 | ~$503 | **~$275** | ~$3.3k |
| 10,000 | 500 | $1,555 | ~$1,000 | **~$555** | ~$6.7k |
| 50,000 | 2,500 | $7,775 | ~$4,935 | **~$2,840** | ~$34k |
| 100,000 | 5,000 | $15,550 | ~$9,850 | **~$5,700** | ~$68k |

Net revenue/premium ≈ $3.11/mo (after fees); free-tier cost ≈ $0.05; fixed infra
~$8 → ~$100. The $3.99/$34.99 prices trade ~30–40% of the $4.99 case's absolute
profit **at the same conversion** — the bet is that under-$4 + the "$35 vs $199"
story lifts conversion enough to more than offset (and grows the base faster). It
is a **volume + conversion** game; infra is a rounding error.

### 6.3 The two dials — sensitivity (per 100 total users/mo)

| | Planning cost | Optimized cost |
|---|---|---|
| 3% conversion | **−$7.4** (loss) | +$1.5 |
| 5% conversion | −$4.4 (loss) | **+$5.8** |
| 8% conversion | +$0.2 (breakeven) | +$12.3 |
| 10% conversion | +$3.3 | +$16.6 |

Read-off: at $3.99, **un-optimized cost needs ~8% conversion just to break even** —
but once the AI-cost levers land (all in the architecture already), even 3% is
profitable and 5–10% is comfortable. At the lower price the margin for error is
thinner, so this is now a hard rule: **ship the AI cost optimizations + keep the
free teaser on the cheap model path BEFORE scaling the free tier.**

### 6.4 What moves the number (in priority order)
1. **Free-tier AI cost → near-zero.** Teaser on Flash-Lite + prompt caching; cap
   at 1 coach Q + 1 action / 7 days. This alone flips the base case positive.
2. **Conversion.** A good teaser + a coach that visibly earns its keep is the #1
   growth lever — every point of conversion is worth more than a price hike.
3. **Push annual + lifetime.** Better fees, better cash flow, and the lifetime
   unlock front-loads revenue from your most enthusiastic users.
4. **Premium AI cost → ~$1.** Caching + Batch API for the nightly jobs.
5. **Niche-audience upside.** Helio owners are already health-obsessed (they bought
   the strap) — freemium for a paid-hardware audience often converts **10–20%**,
   not 3–5%. At 15% conversion the whole table roughly triples.

**Honest takeaway:** margins per paying user are strong (~60–70% at $3.99/$34.99
optimized), and the business is profitable at low user counts *if* the free tier is
cheap and conversion clears ~5%. It is a volume + conversion game — the levers to
win it (cheap teaser, cost optimization, a coach worth paying for) are all things we
control, not market forces.

### 6.5 Does the $99 lifetime lose money? — ⛔ SUPERSEDED, lifetime was dropped 2026-08-02

> Kept as the working, not as a recommendation. It answers "no" from a **$1/mo**
> optimized cost that the measurement later put at **$0.179 a coach question** alone;
> §0 dropped the SKU on exactly that. Read it for the reasoning, not for the SKU.


**Short answer: no, not on any realistic user.** A premium user costs ~**$1/mo ≈
$12/yr** (optimized AI + near-free infra), so:

- **$99 ÷ $12/yr ≈ ~8 years** of continuous *active* use before it even breaks even
  against cost. It only goes cost-negative if someone stays actively engaged **8+
  years** — rare in consumer health (strap breakage, life changes, and normal churn
  cap active life far sooner).
- **AI cost trends *down*** over time (LLM prices keep falling; the choke point makes
  swapping to a cheaper model a config change), so that $12/yr shrinks — pushing
  break-even further out, likely past any real engagement horizon.
- **vs the annual plan:** $99 = ~2.8 years of $34.99. If a buyer would have stayed on
  annual *longer* than that, lifetime is a mild **opportunity cost** (not a loss); if
  *shorter*, lifetime earned us **more**. Median engaged consumer-app life is ~1–3
  years → roughly a wash — and we get the **cash upfront**, which is worth more than
  revenue trickled over years and funds growth exactly when we need it.

**The only risk** is a small tail of decade-long super-users, where the "loss" is
~$12/yr — trivially offset by the upfront cash, falling model costs, and the
word-of-mouth value of a superfan.

**Recommended guardrail:** run lifetime as a **limited founder / early-adopter offer**
(time- or quantity-capped), not a permanent SKU. It caps the long-tail liability,
creates urgency, and front-loads cash in the early days when it matters most. Word
it in the ToS as *"lifetime of the product / fair use,"* not a literal legal
forever-guarantee.

---

## Sources (2026-07)
- Whoop membership tiers/prices: https://www.whoop.com/us/en/membership/ ·
  https://trackervs.com/pricing/whoop-pricing/
- Oura membership ($5.99/mo · $69.99/yr): https://ouraring.com/membership
- Gemini API pricing (Flash $0.50/$3.00, Flash-Lite $0.25/$1.50, cache 10%,
  Batch ~50%): https://ai.google.dev/gemini-api/docs/pricing
- Stripe fees: 2.9% + $0.30 (standard US card). Polar: Merchant-of-Record, ~4%+fee.
