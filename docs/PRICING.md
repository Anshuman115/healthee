# Healthee — Pricing, Positioning & Unit Economics

What to charge for the premium (AI) tier, why, how we compare to Whoop/Oura, and
what it actually costs us to run. Companion to `docs/MULTI_USER.md` §12 (the gate
+ billing). Prices/rates cited are current as of **2026-07** (sources at bottom);
the AI-cost math is an estimate with stated assumptions.

---

## 0. TL;DR recommendation

- **Free forever:** the whole honest **tracker** — every metric, chart, baseline,
  anomaly, personal finding, sleep/recovery/VO₂max number, logging. No forced sub
  to use the hardware you bought.
- **Premium (the AI layer):** **$3.99 / month** or **$34.99 / year** (~$2.92/mo),
  plus a **Lifetime "own-it" unlock $99** (fits the donation path and the
  anti-subscription brand).
- **Why it works:** our marginal cost is **~$1 / premium user / month** (almost all
  LLM; infra is near-free — Contabo + free Supabase/Cloudflare), so the premium tier
  runs **~60–70% gross margin** while sitting *far* under Whoop ($199+/yr, mandatory)
  and under Oura's $69.99/yr-plus-$349-ring. *"$35 a year vs Whoop's $199"* is the pitch.
- **The wedge:** everyone else forces a subscription to see your own data. We
  don't. Tracking is free on hardware you own for life; you pay only for the
  research-grounded AI that never lies. That's the story.

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
| **AI coach** | **teaser: 1 question / 7 days** (built, 6.6a-2) | ✓ unlimited (fair-use) |
| **Daily action line** | **teaser: revealed 1× / 7 days** (built, 6.6a-2 — `POST /api/today/action`) | ✓ daily |
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
- *A metered "taste of premium."* Free users get **1 coach question + 1 daily-action
  reveal per rolling 7 days** — enough to feel the value and convert, bounded so
  cost is trivial (~1–2 extra LLM calls / free user / week). Enforced server-side
  (see `MULTI_USER.md` §12.3: the gate is `require_ai_access(user, feature)` =
  premium **OR** within the free allowance).
  ✅ **BUILT (6.6a-2).** `core/allowance.py` is the ledger and `api/gate.py`'s
  `FREE_ALLOWANCE` is the only executable copy of the table above. Three things
  about it are decisions, not details:
  - **Rolling, not calendar.** The window is anchored to the *use* — a question
    asked at 21:00 Monday comes back at 21:00 the following Monday, in the owner's
    zone. It is a different mechanism from `core/rate_limit.py`'s per-local-day
    counter, which would have reset at midnight and handed out two questions to
    anyone who asked theirs in the evening.
  - **A use is a coach *turn* and a *reveal*, not an LLM call.** A tool-calling
    turn can make five calls; metering calls would charge a curious question five
    times. And a use is never spent on a refusal, a transport failure, or the
    honest fallback — those refund.
  - **The daily action needs a door.** The nightly chain does not generate a free
    owner's action line at all (the 6.6a cost skip), so revealing it means
    generating it on demand: `POST /api/today/action`, which is a POST the owner
    triggers and not a read. `/api/today` is unchanged and still omits the field —
    a page load must not be able to spend somebody's weekly taste.
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
> at the low end — the evidence block, which is the bulk, is owner-independent. The
> coach tier's list price is not public here, so its $ figures use the Flash rate.
> Two things were measured and are NOT levers: **implicit prompt caching fires on an
> exact repeat of a whole payload, not on a shared prefix** (three A/B rounds: an owner
> repeating themselves cached 40,925 of 42,132 tokens; two owners sharing 30k of
> evidence cached nothing, in either message order) — so reordering the prompt to put
> the stable corpus first buys nothing, and cross-owner corpus dedup would need an
> explicit provider cache. And **~40 % of nightly generations end in the honest
> fallback** on this seed (34/59 validated across a paired A/B), each having paid for a
> full-context call *and* its nudged retry — so answer quality is a cost lever roughly
> the size of the prompt itself.

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

On the prices §4 decided (2026-07-16) — **$3.99/mo · $34.99/yr**, not the $4.99/$39.99
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
| D | Merge `briefing` + `daily_action` (#95) | ~−26% of the nightly chain | a product change, and possibly a second definition of "today's action" |
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

### 6.5 Does the $99 lifetime lose money?

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
