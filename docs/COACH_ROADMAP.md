# Coach roadmap — from grounded Q&A to a companion that changes your health

The baseline coach (WP5b) is grounded, honest, historical, tool-driven, and runs
through the WP5a choke point (blocking validator, cite-or-refuse, refusal
domains). That's the floor. These four enhancements — all chosen 2026-07-15 —
turn it into a companion. They build on the baseline coach and on `jobs/` (WP8);
they are Phase-5 "companion intelligence" work, sequenced after Phase 1 is
deployable. Each is its own reviewed WP.

The four compose: **memory** captures what was said and committed → the
**outcome ledger** measures whether it worked and becomes personal evidence →
**proactive** delivers that evidence and nudges at the right moment → all of it
serves the **goal**. Build order follows that dependency.

## C1 — Memory & continuity
The coach remembers past conversations, what it already told you, and what you
committed to — no cold starts.
- **Data:** `coach_memory` (per-conversation grounded summary + extracted
  commitments: "will move caffeine before 14:00"), `coach_commitment` (the
  commitment, the metric it should move, a check-in date, status).
- **Behavior:** each turn loads relevant memory + open commitments into context;
  after a conversation the coach extracts a summary + any commitments (through
  the choke point, so the summary is grounded too). When a commitment's metric
  has enough post-commitment data, it surfaces for follow-up.
- **Honesty guard:** memory is *observations*, not fabrications — a remembered
  claim still carries its original citation; the coach never "remembers" a number
  it can re-query, it re-queries.
- **Depends on:** baseline coach.

## C2 — Outcome ledger (it learns what works *for you*)
The coach tracks whether its advice actually moved your metrics and builds your
personal cause-and-effect, cited as `[personal_finding:...]`.
- **Data:** unify the existing signals into one personal-evidence store the coach
  reads — the analytics `finding` table (correlations), the `challenge_outcome`
  ledger (measured before→after), and commitment outcomes from C1. A
  `personal_finding` view/table with: statement, metric(s), effect size,
  direction, n, confidence, source (correlation | challenge | commitment).
- **Behavior:** when a behavior change is adopted or advised, record it; later
  measure the delta (compare_event-style, robust to confounds); store the
  finding. The coach cites these as the strongest honest motivator ("when your
  MVPA rose 20%, your HRV followed in ~10 days") — always distinguished from
  population research `[note_id]`.
- **Honesty guard:** single-subject, observational — the ledger stores
  confidence and the coach speaks it ("a personal pattern, not proof"); a weak or
  confounded finding is labelled weak, never dressed up.
- **Depends on:** C1 (commitments) + the challenges subsystem.

## C3 — Proactive coaching (doesn't wait to be asked)
The coach initiates: a weekly review and data-triggered nudges.
- **Weekly review** (already in the Phase-5 blueprint): Sunday digest — the week
  vs your baselines, what measurably improved/regressed/held, outcome-ledger
  wins, and *one* focus for next week. Generated through the choke point
  (grounded, validator-checked), delivered in-app + Telegram. Unflinching by
  design — a bad week is reported as a bad week with the mechanism and the
  smallest next step.
- **Triggered nudges:** the scheduler scans for conditions (HRV trend down N
  weeks, sleep debt over threshold, a C1 commitment due for check-in, an
  anomaly), and sends a grounded message when one fires — not spam, rate-limited,
  only when there's something true and useful to say.
- **Depends on:** `jobs/` (WP8) for scheduling + the existing `notify.py`
  Telegram sink; C1/C2 for the content.

## C4 — Goal-oriented planning
You set a goal; the coach orients everything to it and designs/adapts a
structured plan.
- **Data:** `goal` (type: fat-loss | endurance-event | sleep | longevity |
  strength…, target, horizon, priority), read into every coach context.
- **Behavior:** recommendations and the "biggest lever" are chosen *relative to
  the goal*; the coach designs a multi-week plan on the programs/ladders system
  (progressive overload, periodization, deload), tracks adherence, and adapts
  when the data says to. The weekly review reports progress toward the goal.
- **Honesty guard:** projections are labelled projections; if a goal is
  unrealistic or unsafe on the person's data (e.g. a race plan that requires
  ignoring a rising RHR), the coach says so.
- **Depends on:** the programs/challenges subsystem + C1/C2/C3.

## Sequencing
Phase 1 (server deployable) finishes first: WP5b (baseline coach) → WP8 (jobs).
Then the challenges/programs subsystem (its own feature WP), which C2/C4 need.
Then the coach-companion track C1 → C2 → C3 → C4 in dependency order, each a
reviewed WP with its own tests. Nothing here weakens the honesty contract — every
new surface still passes through the WP5a choke point.
