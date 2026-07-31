"""The ladder-design task handed to the choke point (WP-C4b).

``gen_prompt``'s twin, and it restates nothing that module or the choke point already
says: the system prompt owns the citation and grade-calibration rules, ``gen_prompt``
owns the copy rules a challenge's prose follows, and this file owns the one thing that is
specific to authoring a LADDER — its shape.

## Why the model authors so little of the ladder

It authors the metric, the comparator, the cadence, the rung targets, the rung windows
and every word. It does **not** author ``goal``, ``goal_metric`` or ``weeks``:

* ``goal`` is the corpus's evidence target for that metric (``targets.EVIDENCE_TARGET``)
  in the ladder's own units, and it is OURS. A model writing "toward 10,000 steps a day"
  would be inventing a population number beside a table that already states one — the
  exact overclaim ``jobs.recs._provable_grade`` corrects downward elsewhere.
* ``goal_metric`` is the rungs' own metric; a second field for it is a second definition.
* ``weeks`` is the sum of the rung windows. It is arithmetic, and arithmetic the model
  gets wrong is a number nobody checked.

So the shape is stated once, at the PROGRAM level, and the rungs carry only their target,
their window and their copy. A ladder whose rungs sit on different metrics is therefore
not something the shape gates catch — it is something this format cannot express, which
is the same choice #67 made for a weekly ``sri`` (unrepresentable rather than unreached).
"""

from __future__ import annotations

from healthee.challenges.gen_prompt import CATEGORIES, DIFFICULTIES, MAX_WINDOW_DAYS

# How many rungs a ladder may have. Under three is not a ladder — it is a challenge with
# an extra step, and the deload/stall machinery has nothing to be a ladder ABOUT. Over six
# is a plan somebody stops believing in: `MAX_PROGRAM_DAYS` bounds it in time anyway, so
# this bounds it in *promises*, which is what the owner actually has to hold in their head.
MIN_RUNGS = 3
MAX_RUNGS = 6

# A rung is at least a week. `gen_prompt.MIN_WINDOW_DAYS` is three days, which is right for
# a standalone challenge and wrong here: a rung is closed by `elapsed > window_days` and
# then RECALIBRATED against the owner's trailing baseline, and a three-day rung would
# re-read a baseline that still contains most of the rung before it. Seven days is also
# what makes `weeks` an honest name for the number below.
MIN_RUNG_DAYS = 7

# The whole ladder, end to end. Twelve weeks is a season; beyond that the design-time copy
# is describing a person who will have moved on before they get there, and the honest
# answer is a second ladder generated then, against who they are then.
MAX_PROGRAM_DAYS = 84

PROGRAM_TASK = f"""\
Act as the program designer. Design ONE multi-week ladder: a single metric this owner
climbs in {MIN_RUNGS}-{MAX_RUNGS} steps, each step a challenge the app scores automatically
from their own data.

CHOOSING THE METRIC — one metric for the whole ladder
- Take it from the TOP of the lever ranking, exactly as you would for a challenge.
- It MUST be a metric the lever table gives an `evidence target` for. A ladder is a climb
  toward a goal, and a goal we cannot cite is a number we invented — so a metric listed
  NOT RANKED cannot be a program, however reasonable it looks. Propose a plain challenge
  instead if that is where their gap is; this task will simply return nothing.
- It MUST be a metric where MORE is better, and `comparator` is therefore ">=".
  A cap ("<=", less caffeine) is NOT expressible as a ladder: when a rung runs out of time
  unmet the engine answers by EASING it, and the research base supplies no rule for
  loosening a cap — so a cap rung is a step whose failure we could not answer. That is a
  real limit of the product and you must not work around it.
- Never a metric the calibration table marks UNAVAILABLE, and never one listed OFF THE MENU.

THE RUNGS — this is enforced after you answer, not negotiated
- `target_value` rises on EVERY rung. Rung 1 must sit inside the allowed range in the
  calibration table (it starts within days). Later rungs are MEANT to sit above that range
  — that is what a ladder is — and each one is re-checked against the owner's own baseline
  at the moment it actually starts, weeks from now.
- No rung may ask for more than the metric's `evidence target`. Past that number the
  research does not say the extra is worth anything, so a ladder that climbs past it is
  selling something we cannot cite.
- `window_days` is at least {MIN_RUNG_DAYS} and at most {MAX_WINDOW_DAYS}, and the rungs
  together must not exceed {MAX_PROGRAM_DAYS} days.
- Round every target to the calibration table's "round to" step.

THE COPY — the same rules a challenge's copy follows
- The program's `why` and every rung's `why`/`expected_outcome` are interpretive: every
  claim carries a real `[note_id]` matched to that note's grade. A pattern from THEIR data
  is `[personal_finding:<name>]` and never substitutes for a note id.
- Do NOT write any target, their baseline, or any other quantity of that size in a `title`,
  a `why` or an `expected_outcome`. The app renders the stored number beside your words.
- Each rung's `how_to` is the practical method for THAT step — numbers about method go here.
- Write each rung as its own commitment. A rung that only makes sense as "step 3 of 4" reads
  as nonsense on the day it starts, because a deload rung may be inserted before it.

OUTPUT ONLY a JSON object (JSON mode is on — no prose, no code fences):
{{{{"program": {{{{
  "title": "<=6 words, no digits>",
  "why": "<=2 sentences on why this ladder, each interpretive clause carrying [note_id]>",
  "category": "{"|".join(sorted(CATEGORIES))}",
  "metric": "<one metric key from the calibration table>",
  "comparator": ">=",
  "cadence": "daily|weekly",
  "rungs": [
    {{{{"title": "<=6 words, no digits>",
     "why": "<why THIS step, cited>",
     "expected_outcome": "<the concrete payoff of this step, cited>",
     "how_to": "<2-4 concrete steps>",
     "difficulty": "{"|".join(sorted(DIFFICULTIES))}",
     "target_value": <number>,
     "window_days": <integer {MIN_RUNG_DAYS}-{MAX_WINDOW_DAYS}>,
     "research_note_ids": ["<id>", ...]}}}}
  ]}}}}}}}}
If their data cannot support a calibrated, citable ladder, return {{{{"program": null}}}} —
no program is the honest answer and costs them nothing."""


def program_task(intent: str | None = None) -> str:
    """The task text for one ladder design, with the caller's intent when there is one.

    ``intent`` mirrors ``gen_prompt.generation_task``'s seam exactly, and means the same
    thing: a constraint on selection, never permission. An intent that resolves to a
    metric with no citable goal still produces nothing.
    """
    if not intent:
        return PROGRAM_TASK
    return (
        f"{PROGRAM_TASK}\n\nTHE OWNER ASKED FOR THIS SPECIFICALLY:\n{intent}\n"
        "Honour it if a metric in the calibration table can express it as a ladder. If "
        'none can, return {"program": null} — do not substitute something they did not '
        "ask for, and do not turn a cap into a ladder."
    )
