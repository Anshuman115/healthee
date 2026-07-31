"""The generation task handed to the choke point, and the nudge for a rejected batch.

The choke point owns the system prompt, the ranked EVIDENCE NOTES and the citation /
grade-calibration rules (``insights.prompts.SYSTEM_PROMPT``); nothing here restates
them, because a second copy of a rule is a second thing that can drift from the
validator that enforces it. What lives here is only what is specific to authoring a
challenge: the output shape, the vocabularies, and the two gates stated as the rules
they actually are — "instruct AND enforce" (CHALLENGES.md §5.1), with this file as the
instruct half and ``bounds`` / ``generate`` as the enforce half.

The copy rules are worth reading twice. ``why`` and ``expected_outcome`` are the
interpretive fields and carry the citations; ``how_to`` is a directive and is grounded
at the challenge level, exactly as a rec's ``action`` is (``insights.validator``'s
``_RECS_DIRECTIVE_FIELDS`` argues that exemption). The ban on restating the target
number outside ``how_to`` is what makes "the stored number and the shipped prose cannot
disagree" checkable rather than hoped for.
"""

from __future__ import annotations

# Vocabularies the persisted row must use. `total` is absent from the cadence list on
# purpose — `bounds.GENERATABLE_CADENCES` says why (its baseline and its target are in
# different units for any window that is not seven days).
CATEGORIES: frozenset[str] = frozenset({"fitness", "activity", "sleep", "recovery", "movement"})
DIFFICULTIES: frozenset[str] = frozenset({"easy", "standard", "hard"})

# Bounds on the commitment's length. Legacy accepted 1–90 days while instructing 3–30;
# this WP's whole theme is that an instruction nobody enforces is decoration, so the
# accepted range IS the instructed one. Under three days measures nothing; beyond thirty
# is a program (WP-C4), not a challenge.
MIN_WINDOW_DAYS = 3
MAX_WINDOW_DAYS = 30

GENERATION_TASK = f"""\
Act as the challenge generator. Design up to {{max_new}} distinct, measurable challenges
this owner could commit to, each bound to ONE metric from the calibration table so the
app can score it automatically from their own data.

HOW TO CHOOSE
- **Start from YOUR BIGGEST LEVERS.** That ranking is computed, not suggested: it is the
  gap between where this owner is and where the evidence says the returns are largest,
  and it already accounts for what they abandoned and how recovered they are. Take the
  metrics from the top of it. Do not substitute your own judgement of what matters — a
  metric further down is a metric where they have less to gain.
- Then read the calibration table, the sleep-timing block, the challenge history and the
  personal findings for the SHAPE of the challenge. That judgement is still yours: a
  chronically short sleeper with a wide onset spread needs a sleep REGULARITY challenge,
  not a sleep-duration one.
- A metric listed OFF THE MENU is rejected on arrival — never propose one. A metric
  listed NOT RANKED has no dose-response evidence behind it: you may propose one, but do
  not promise a health payoff for it, because we cannot cite one.
- A metric named like `caffeine_after_16` is a TIME WINDOW: it counts only what they
  logged at or after 16:00 in their own timezone, and it is on the menu ONLY when their
  own data found a cutoff at that hour. A day they logged nothing at all does not count
  as a clean day — it counts as no data — so `how_to` should say to keep logging.
- Build on what the frozen outcomes say worked FOR THEM.
- No two proposals may share a metric, or the same behaviour: a window is part of the
  same quantity as the daily total it slices, so `caffeine_after_16` and `caffeine_mg`
  are one commitment and only one of them may be proposed.

THE TARGET (this is enforced after you answer, not negotiated)
- `target_value` MUST fall inside the allowed range for the (metric, cadence) row you
  picked. A target outside it is rejected and that whole challenge is discarded — it is
  never quietly adjusted, so an out-of-range number costs the proposal.
- Round it to that row's "round to" step so it reads as a human number.
- Never propose a metric the table marks UNAVAILABLE.
- `comparator` follows the metric: ">=" when more is better, "<=" for a cap.

THE COPY
- `why` and `expected_outcome` are interpretive: every claim carries a real `[note_id]`,
  matched to that note's grade. A pattern from THEIR data is `[personal_finding:<name>]`
  and never substitutes for a note id.
- Do NOT write the target number, their baseline, or any other quantity of that size in
  `title`, `why` or `expected_outcome`. The app renders the stored target beside your
  words; a number repeated in prose is a second source of truth that can only disagree.
  Percentages and clock times are fine.
- `how_to` is the practical method — 2–4 concrete steps (sessions, timing, technique).
  Numbers about METHOD belong here.

OUTPUT ONLY a JSON object (JSON mode is on — no prose, no code fences):
{{{{"challenges": [
  {{{{"title": "<=6 words, no digits>",
   "why": "<=2 sentences, each interpretive clause carrying an inline [note_id]>",
   "expected_outcome": "<the concrete payoff, cited>",
   "how_to": "<2-4 concrete steps>",
   "category": "{"|".join(sorted(CATEGORIES))}",
   "difficulty": "{"|".join(sorted(DIFFICULTIES))}",
   "metric": "<one metric key from the calibration table>",
   "comparator": ">=|<=",
   "target_value": <number inside the allowed range>,
   "cadence": "daily|weekly",
   "window_days": <integer {MIN_WINDOW_DAYS}-{MAX_WINDOW_DAYS}>,
   "research_note_ids": ["<id>", ...]}}}}
]}}}}
If their data cannot support a calibrated, citable challenge, return {{{{"challenges": []}}}}
— an empty feed is the honest answer and costs nothing."""

# Appended when EVERY proposal was rejected by the deterministic gates. It names the
# violations rather than describing them, so the retry is a correction and not a reroll
# (`generate` retries the batch at most once — see its module docstring).
REJECTION_NUDGE = """\

YOUR PREVIOUS PROPOSALS WERE ALL REJECTED BY THE DETERMINISTIC GATES:
{issues}

Fix exactly those problems. Re-read the calibration table: `target_value` must sit
inside the allowed range for the (metric, cadence) row you chose, and `title` / `why` /
`expected_outcome` must not restate the target or any number of that size."""


def generation_task(max_new: int, intent: str | None = None) -> str:
    """The task text for one generation run, with the caller's intent when there is one.

    ``intent`` is the WP-C5 seam (CHALLENGES.md §6a): the coach passes what the owner
    asked for and the SAME pipeline authors, bounds and grounds it. It is appended as a
    constraint on selection, never as permission — an intent that resolves to no
    trackable metric, or to a metric with no calibratable baseline, still produces
    nothing, which is what the coach then reports honestly.
    """
    task = GENERATION_TASK.format(max_new=max_new)
    if not intent:
        return task
    return (
        f"{task}\n\nTHE OWNER ASKED FOR THIS SPECIFICALLY:\n{intent}\n"
        "Honour it if a metric in the calibration table can express it. If none can, "
        'return {"challenges": []} — do not substitute something they did not ask for.'
    )
