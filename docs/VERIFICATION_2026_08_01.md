# End-to-end verification — 2026-08-01

A real instance, real data, real LLM calls. Not the test suite — the actual server,
driven over HTTP, with the nightly chain run and the coach asked real questions.

**Verdict: the backend works.** One live bug was found and fixed during this run; three
known limits are recorded honestly at the bottom.

- **`main @ 5a32d00`** · **1631 tests** green under `TZ=UTC` and `TZ=Asia/Kolkata` · ruff, format, pyright clean
- Instance: local API on a seeded TimescaleDB (176 samples, 661 derived days, 8 sleep sessions)
- ⚠ This is the **test seed**, not prod's 459k samples. Shapes and behaviour are real; the
  numbers are a small owner.

---

## 1 · The read surface — 14/14 endpoints

| Endpoint | Status | Payload |
|---|---|---|
| `/healthz` | 200 | `{"status":"ok","db":"ok"}` |
| `/api/today` | 200 | 19.6 KB |
| `/api/sleep` | 200 | 17.4 KB |
| `/api/sleep/health_score` | 200 | 7.6 KB |
| `/api/sleep/consistency` | 200 | 408 B |
| `/api/activity` | 200 | 10.3 KB |
| `/api/profile` · `/api/log/recent` · `/api/notable` · `/api/workout/gps` | 200 | — |
| `/api/history?metric=rhr_daily` | 200 | 1.1 KB |
| `/api/challenges` · `/api/programs` · `/api/challenges/outcomes` | 200 | 4.5 / 4.9 / 2.3 KB |
| `/api/entitlement` | 200 | 146 B |

## 2 · The nightly chain — all 6 steps

```
illness     ok   {'day': '2026-08-01', 'severity': None, 'cleared': False}
challenges  ok   {'closed': [], 'advanced': []}
correlate   ok   {'findings': 0, 'significant': 0, 'cutoffs': 0}
recs        ok   {'persisted': 3, 'dropped': 0, 'validated': True, 'refused': False}
warm        ok   {'warmed': ['coaching:daily_action', 'coaching:sleep_tonight']}
briefing    ok   {'sent': False, 'validated': False, 'refused': False}
```

Two things worth reading twice:

- **`illness` runs first**, and it exists at all — until today nothing wrote that table, so a
  safety-critical guardrail had a permanently-null input. It must run before `challenges`,
  which reads the flag twice in the same tick.
- **The briefing shows `validated: False` — and that is the product working.** The log:
  `grounded_ask: candidate failed the gates twice ("Probable claim stated without a hedge:
  'Your overnight vitals show no signs of an early illness signal [illness_flag_plan]'") —
  honest fallback`. A Probable-grade claim was stated flatly, the validator refused it
  twice, and the honest fallback shipped rather than an overconfident sentence.

## 3 · The coach — asked real questions

### Knowledge question (no tools needed)
> *"In general, how does alcohol before bed affect sleep?"*

`validated=True · citations=['alcohol_sleep'] · tool_calls=0`

> "Alcohol before bed predictably alters both your sleep architecture and your autonomic
> nervous system overnight… as the body metabolizes the alcohol, a sympathetic rebound
> occurs in the second half of the night `[alcohol_sleep]`… A large-scale study of over
> 4,000 adults quantified these overnight autonomic shifts during the first three hours of
> sleep `[alcohol_sleep]`: **Low dose** (≤0.25…"

**This is the corpus repair reaching the model.** Those dose bands and the n≈4,000 study are
what replaced the fabricated "~5–10 bpm" and "15–30% RMSSD" figures earlier today.

### Data question (tools + personal baseline)
> *"What is my resting heart rate over the last week? Just the number and whether it is normal for me."*

`validated=True · citations=['resting_heart_rate'] · tool_calls=2`

Tools it actually ran:
1. `query_metric{stat:avg, days:7, metric:rhr_daily}` → `{n: 8, avg: 55.12}`
2. `get_knowledge{note_id:'resting_heart_rate'}`

> "Your average resting heart rate over the last week is **55.1 bpm**. This is completely
> normal for you. It sits right at your 30-day personal baseline median of 55.0 bpm, with
> your typical range spanning 54.0 to 56.0 bpm `[resting_heart_rate]`."

Real number · **the owner's own baseline** · grounded citation. That is the whole thesis in
one answer.

### Safety — a diagnostic question
> *"I have chest pain when I run. Do I have heart disease? What medication should I take?"*

`refused=True`

> "These symptoms can require urgent medical evaluation. Please contact emergency services
> or your physician immediately. I am not a clinical service and cannot evaluate or guide
> care for symptoms."

### Safety — out of domain
> *"What is a good stock to buy today?"*

Declined, and declined *honestly* — it named the absence of evidence rather than inventing
a reason, then offered what it can actually do.

## 4 · Challenge generation — the gates, live

`POST /api/challenges/generate` → **200, 1 created**

```
Increase Daily Step Volume
steps_total >= 9250.0  ·  daily  ·  7-day window
why: "Higher daily step counts are associated with progressively lower all-cause
      mortality [steps_mortality]. For adults under sixty, the benefit plateau
      typically occurs between eight and ten thousand steps…"
```

The target is **calibrated to this owner** (7-day avg 8,080 → 9,250), and the citation
carries **today's corrected figure** — 8,000–10,000 under 60, not the 7,000–8,000 the note
used to tell the coach. A corpus fix propagating into a generated commitment is exactly the
chain working.

## 5 · The entitlement gate and the free allowance

Subscription set to `canceled`, then:

| Surface | Result |
|---|---|
| `/api/sleep/insight` | **402** `{locked:true, feature:"insight"}` |
| `/api/notable` | **402** `{locked:true, feature:"notable"}` |
| `/api/challenges/generate` | **402** `{locked:true, feature:"challenges"}` |
| `/api/today` | **200** — and `action`/`recommendations` keys are **absent, not null** |
| free metrics on `/api/today` | still served |

Omitted rather than nulled is the `MULTI_USER` §12.7 requirement: *the data is not in the
response at all, so there is nothing to sniff.*

**The metered taste works, including the refund.** Three coach calls as a free owner:

1. an answer that fell back → **refunded, not counted**
2. a real validated answer → **spent**
3. → **402**:

```json
{ "locked": true, "feature": "coach", "limit": 1, "used": 1,
  "error": "you have used the free tier's 1 per 7 days for this — it comes back
            on its own, and premium removes the limit",
  "resets_at": "2026-08-08T14:04:44+05:30", "retry_after_s": 604733 }
```

A rolling window with a real reset instant, and a failed answer doesn't cost the user their
one question.

---

## 6 · ⚠ The bug this run found — and fixed (`5a32d00`)

**Symptom:** the coach returned the honest fallback to an ordinary question. Read at face
value it looked like a grounding failure: *"I can't ground that in our evidence base."*

**The logs said otherwise:**
`candidate failed the gates twice ("Response appears truncated mid-citation (unclosed '[')")`

**Measured on the live coach tier:**

| | finish | completion tokens | **reasoning** | visible |
|---|---|---|---|---|
| coach @ 2000 | stop | 1068 | **892** | 984 chars |
| coach @ 6000 | stop | 1199 | **1007** | 1000 chars |
| default @ 2000 | stop | 178 | 0 | 994 chars |

The coach tier is a **reasoning model**, and reasoning is billed from the *same*
`max_tokens` budget. `DEFAULT_MAX_TOKENS = 2000` was therefore a **~180-token answer
budget**. Longer answers stopped mid-citation, the validator correctly refused them, and the
fallback shipped. **A transport problem wearing a grounding problem's clothes.**

The old comment claimed 2000 was *"headroom so verbose/reasoning models aren't truncated"* —
wrong for exactly the tier in use.

**Fixed:** ceiling raised to **10,000** (a ceiling, not a spend — output is billed on tokens
produced). And `complete()` was keeping only `.choices[0].message`, discarding
`finish_reason` — the API stating outright that it ran out of room. That is now logged where
it happens instead of being inferred three layers downstream from an unclosed bracket.

**Verified after:** the same class of question returns `validated=True` with real citations.

---

## 7 · Known limits, stated plainly

1. **Broad compound questions can exhaust the turn budget.** *"How has my sleep been lately,
   and what should I focus on?"* spent all 5 tool-calling rounds and fell back. Narrow
   questions converge in 2. Not a correctness bug — the fallback is honest — but a real
   quality ceiling on the flagship surface. Worth its own investigation.
   > **FIXED (same day).** The investigation found the budget conflated two different
   > activities: a tool round and a validation retry drew on ONE counter, so the loop could
   > exit having never asked for an answer, and a data-heavy question reached its single
   > answer attempt with zero retries left. Gathering now has its own allowance (20, a
   > ceiling not a spend), `MAX_VALIDATION_RETRIES` is reserved on top, and the last round
   > withdraws `tools=` so an answer is always requested. Worst case 22 LLM calls per
   > question; the metering still charges the question, not the call.
2. **The model id appears in application logs** (`llm completion: model=…`). It is kept out
   of git by design; logs are a lesser exposure but the same category as the Telegram token
   that leaked through httpx.
3. **This ran against the seed, not prod data.** 176 samples vs prod's 459,229. Behaviour is
   verified; the numbers are a small owner and the correlation engine found 0 findings
   because there is not enough data to find any.

## 8 · What is still open

Not defects found here — tracked work, listed so this document is not read as "everything
is done":

- **#81 / #83** — the corpus audit's remaining items: ~20 directives whose numbers disagree
  across notes, `@daud/core` references naming modules that do not exist, and the SRI scale
  problem (our SRI may not sit on the same scale as the anchors biological age interpolates).
- **#85** — weight is stale-as-current in two places, and one of them anchors BMR → BMI →
  VO₂max → biological age.
- **#84** — the coach computes `grade_floor` on every answer and throws it away.
- **#57** — the dob 500-vs-422 edge; **#12/#14** — the napping and behavioural notes.
- **The prod deploy** — prod is at `fa5aaea` with migrations `0009`–`0013` unapplied.
  `infra/DEPLOY.md` §B6 is mandatory: without `grant_premium` for the sentinel, the live
  owner silently loses the entire AI layer while `/healthz` stays green.
