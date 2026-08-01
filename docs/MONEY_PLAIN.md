# The money, in plain language

Written 2026-08-01. Every number here comes from **real billing** — actual requests
replayed through OpenRouter, counted by the provider, not estimated. Assumptions are
stated where they exist.

---

## 1. How the money works

Three things cost money. Only one of them matters.

| | cost | notes |
|---|---|---|
| **The AI (OpenRouter)** | the whole game | ~95% of what you spend |
| **The server (Contabo)** | $5/mo now → $15 at 1k users → $80 at 10k | flat, barely grows |
| **Payment fees** | 2.9% + $0.30 per charge | that $0.30 hurts on small amounts |

So: **your business is an AI-token business.** Everything else is a rounding error.

---

## 2. What one paying user costs you

| Thing | Cost | How often |
|---|---|---|
| **Nightly chain** (recommendations, briefing, daily action, sleep line) | **$1.27/month** | automatic, every night, whether they open the app or not |
| **One coach question** | **$0.179** | only when they ask |
| **One insight card** | **$0.0084** | basically free |

**The nightly chain is the floor.** A paying user who never opens the app still costs
$1.27/month, because we generate their briefing anyway.

**A coach question is the expensive thing** — 21× an insight card. Why: one question
is really **three** calls to the AI (find the data → read it → write the answer), and
each of those three sends the whole research library along with it. About **100,000
words of input to produce a paragraph.**

### So a paying user costs, per month:

| If they use it… | Cost |
|---|---|
| Lightly — 5 questions | **$2.25** |
| Normally — 15 questions | **$4.21** |
| Heavily — 40 questions | **$8.94** |

⚠️ **Compare that to what you charge: $3.99/month, or $2.92/month on the annual plan.**
A normal user already costs more than an annual subscriber pays.

---

## 3. What you charge vs what you keep

| Plan | Sticker | After payment fees |
|---|---|---|
| $3.99 / month | $3.99 | **$3.57** |
| $34.99 / year | $2.92/mo | **$2.81/mo** |
| $99 lifetime | $99 | **$95.83 once** |

The annual plan looks like a discount. It's actually **below cost** for a normal user.

---

## 4. ⚠️ The three places you lose money today

**1. The annual plan.** $2.81/month in, $4.21/month out for a normal user. **Every
annual subscriber who actually uses the coach loses you money** — and annual is the
plan you *want* people on.

**2. Lifetime $99.** It pays for about **23 months** of normal use. After that it loses
money forever. Your most loyal, longest-staying users become your biggest losses — the
opposite of how it should work.

**3. The free tier.** Free users get 1 coach question every week, forever. That's
**$0.81/month each, permanently.** At 5% conversion, every paying user is carrying 19
free users = **$15.39/month of giveaway** against $3.57 of revenue.

> A free question every week isn't a free sample. It's a subscription you give away.

---

## 5. "Cost optimised" — what it means

This is the one term in the tables that needs explaining.

**Today**, a coach question makes 3 calls, and **each one re-sends the entire research
library** (~23,000 words of research notes):

| Round | What it does | Sends |
|---|---|---|
| 1 | picks which of your numbers to look up | full library |
| 2 | reads the result | full library |
| 3 | writes the answer, with citations | full library |

But **only round 3 writes anything.** Rounds 1 and 2 just decide what to look up — they
produce no text and cite nothing. **They don't need the library.**

**The fix:** send the research library only on the round that actually writes the answer.

| | now | optimised |
|---|---|---|
| words sent per question | ~100,000 | **~55,000** |
| cost per question | $0.179 | **~$0.110** |

That's a **~40% cut on your single most expensive item**, and it changes nothing the
user sees.

### 🔴 Honest health warning

**This is not proven yet.** The token maths is solid, but there's a real risk:
the AI might use the research library to decide *what's worth looking up*. Take it away
in rounds 1–2 and it might fetch the wrong number — a cheaper answer that's less
accurate is a loss, not a saving.

**Cost to settle it: ~$3 and 30 minutes**, using the test harness built today. Until
then, treat every "optimised" column as *hopeful*, not banked.

---

## 6. 📊 100 users — the actual numbers

**Assumes:** 5% convert → 5 paying, 95 free. Paying users capped at 10 coach
questions/month (see §7). Server $5/month. Free users on a **one-time** trial, so they
cost nothing monthly.

| Plan | Revenue/mo | AI cost | Server | **Profit/mo** | **Profit/yr** |
|---|---|---|---|---|---|
| $3.99/month *(now)* | $17.87 | $16.99 | $5.00 | **−$4.12** | −$49 |
| $3.99/month *(optimised)* | $17.87 | $13.55 | $5.00 | **−$0.68** | −$8 |
| $34.99/year *(now)* | $14.03 | $16.99 | $5.00 | **−$7.96** | −$96 |
| $34.99/year *(optimised)* | $14.03 | $13.55 | $5.00 | **−$4.52** | −$54 |
| **$5.99/month** *(now)* | $27.58 | $16.99 | $5.00 | **+$5.59** | **+$67** |
| **$5.99/month** *(optimised)* | $27.58 | $13.55 | $5.00 | **+$9.03** | **+$108** |
| **$59/year** *(now)* | $23.75 | $16.99 | $5.00 | **+$1.75** | **+$21** |
| **$59/year** *(optimised)* | $23.75 | $13.55 | $5.00 | **+$5.19** | **+$62** |

**Read this carefully: at 100 users, today's prices lose money even after the
optimisation.** The reason is the $5/month server split across only 5 paying users —
$1 each. Small scale is brutal on flat costs.

### Plus a one-time cost

95 free signups × a 3-question trial = **$54 once** (or $34 optimised).
Compare: today's weekly free question would be **$77 every month — $923/year, forever.**

---

## 7. 📈 Does it get better with scale? Yes — but only above $3.99

Monthly profit at 5% conversion:

| Plan | 100 users | 1,000 users | 10,000 users |
|---|---|---|---|
| $3.99/mo *(now)* | −$4 | −$6 | +$8 |
| $3.99/mo *(optimised)* | −$1 | +$28 | +$352 |
| $34.99/yr *(now)* | −$8 | −$45 | **−$376** |
| $34.99/yr *(optimised)* | −$5 | −$10 | −$32 |
| **$5.99/mo** *(now)* | +$6 | +$91 | **+$979** |
| **$5.99/mo** *(optimised)* | +$9 | +$125 | **+$1,323** |
| **$59/yr** *(now)* | +$2 | +$53 | **+$595** |
| **$59/yr** *(optimised)* | +$5 | +$87 | **+$939** |

**The line to notice:** at $34.99/year you lose *more* the bigger you get — **−$376/month
at 10,000 users.** A plan that's underwater per-user doesn't improve with volume; it
scales the loss. That's the single most important number in this document.

---

## 8. ✅ What I'd actually do

### Do these now — no measurement needed, both are certain losses

**1. Make the free trial one-time, not weekly.**
3 coach questions + 3 daily-action reveals when you sign up. Never renewed. Then the
tracker stays free forever, exactly as promised.
> **$0.57 once** instead of **$0.81/month forever.** At 100 users: $54 once instead of
> $923/year.
> A taste exists to show what the product does — that's a one-time job. Someone on their
> 30th free question in seven months isn't converting; the free tier has *replaced*
> converting.

**2. Drop the $99 lifetime plan** (or reprice it near $299).
It pays for 23 months and then loses forever. You cannot sell a lifetime AI subscription
against a per-question cost.

### Then decide the price

**Safe today, no experiment needed: $5.99/month and $59/year.** Profitable at every
scale, in both cost scenarios, at worst-case usage.

**Or, if you want to protect the "$35 vs Whoop's $199" pitch:** spend the $3 to run the
optimisation experiment first. Even if it works, note the table — **$3.99/month gets to
break-even-ish, and $34.99/year still doesn't.** You'd need roughly **$44/year minimum**
even in the good case.

### And put a real number on "unlimited"

The docs currently promise "unlimited (fair-use)" coach questions. That's an unbounded
cost against a fixed price — it's the reason "we will never lose money" can't be
promised as written. **10 questions/month included, then it waits for the reset**, is
honest and safe. All of it (charts, metrics, baselines, insight cards, illness warnings)
stays unlimited — those are nearly free.

> An honest stated limit is better than "unlimited" with a silent throttle. This product's
> whole promise is that it doesn't do the second thing.

---

## 9. The one-line summary

**Your costs are fine. Your prices are the problem — specifically the annual plan and
the lifetime plan, both of which lose money by design, and a free tier that gives away
a recurring subscription.** Fix the free tier and kill lifetime today; then either move
to $5.99/$59, or spend $3 proving the optimisation and keep $3.99 with a slightly
higher annual price.
