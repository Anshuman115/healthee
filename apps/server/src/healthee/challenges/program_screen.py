"""The gates applied to ONE generated ladder — WP-C4b's whole design problem.

``screen`` is this module's twin for a standalone challenge, and the reason there are two
is the one thing WP-C4 could not resolve and deferred:

    **Gate A cannot bind every rung at design time.** Rung 3 is *meant* to sit above
    today's band — that is what a ladder IS — so a strict per-rung bounds check would
    reject every legitimate program.

The resolution, and it is a split rather than a relaxation:

* **Gate A binds rung 1 only.** It starts within days of the ladder being adopted, so the
  owner's current baseline is exactly the right thing to bound it against.
* **Every LATER rung is bounded AT ACTIVATION**, by ``rung.recalibrated_target`` reading
  ``bounds.calibrate`` at the moment the rung starts — code that already exists and
  already runs on every advancement. A rung above today's band comes DOWN to the band's
  demanding end; a rung the owner has already passed goes UP. So **no rung is ever RUN
  outside the owner's then-current band**, which is the property that protects a person.
  Design-time bounding could only ever have protected them against a four-week-old
  version of themselves.
* **The ladder's SHAPE is gated here instead**, and the shape is what design time can
  actually judge: one metric, ``>=`` only on a metric where more is better, strictly
  climbing, capped at the evidence target, bounded in time, and every rung's prose through
  Gate B and the copy check like any other challenge.

## The `<=` cap ladder is refused, and stays refused

A ladder's failure branch is ``adapt.deload_target`` — the adapter's ease — and the
adapter leaves ``<=`` caps alone because the corpus supplies no rule for loosening one
(CHALLENGES.md §5.2). A cap rung is therefore a step whose failure could not be answered,
and a ladder without a deload is legacy's forward-only staircase wearing a new column.
**A progressive caffeine-cut ladder is not expressible today.** Making it work quietly
would need a grounded rule for easing a cap, and that is a knowledge question before it
is a code one. The refusal is the SAME rule ``programs.rung_shape_issue`` enforces at
adopt, read here rather than restated — so anything this module ships, ``adopt`` accepts.

## Why "no evidence target ⇒ no ladder" is stricter than the deferral note asked for

The note said "capped at the evidence target". That leaves open what happens on a metric
with no target at all (``active_calories``, ``cardio_load``, ``workouts_week`` — the ones
``levers`` reports as NOT RANKED, saying plainly that we cannot say what moving them is
worth). Uncapped, such a ladder would climb toward a number with nothing behind it, and
``program.goal`` would be exactly the invented population figure §5.1a refuses to write a
floor from. A four-week commitment is a bigger ask than a one-week one, so the bar goes
UP, not down: **a ladder needs a goal we can cite.** A standalone challenge on those
metrics is still generatable — bounded by the owner's own baseline, which is an honest
bound — and that is the right shape for them.
"""

from __future__ import annotations

import math
from typing import Any

from healthee.challenges import programs
from healthee.challenges.bounds import Calibration
from healthee.challenges.gen_prompt import CATEGORIES, MAX_WINDOW_DAYS
from healthee.challenges.metrics import spec
from healthee.challenges.program_prompt import (
    MAX_PROGRAM_DAYS,
    MAX_RUNGS,
    MIN_RUNG_DAYS,
    MIN_RUNGS,
)
from healthee.challenges.screen import CalibrationMap, proposal_issue

# What the model must state once, for the whole ladder.
_PROGRAM_FIELDS = ("title", "why", "category", "metric", "comparator", "cadence", "rungs")

# The fields the program supplies to every rung, so a rung reaching `screen.proposal_issue`
# is a complete challenge proposal. A rung IS a challenge (`programs.py`), and the moment
# this module builds a rung that is only *nearly* one is the moment the two surfaces are
# free to disagree about what a commitment must carry.
_INHERITED = ("metric", "comparator", "cadence", "category")

# The prefix a shape refusal carries, so the name travels to the caller and reads the same
# as `programs.adopt`'s own `not_ladderable` refusal — one vocabulary, two doors.
NOT_LADDERABLE = "not_ladderable"

_DAYS_PER_WEEK = 7


def screen_program(
    payload: dict,
    calibrations: CalibrationMap,
    taken: set[str],
    blocked: dict[str, str] | None = None,
) -> tuple[dict | None, list[str]]:
    """Apply every gate to a parsed ladder. Returns (what may ship, why it may not).

    ``None`` for the design means nothing ships — a ladder is one object, so unlike a
    batch of challenges there is no partial answer to keep. The issues list is the answer
    in that case, not a log line (CHALLENGES.md §2.5).

    The returned design is ``{"program": {...}, "rungs": [...]}`` with the derived fields
    already computed: ``goal``, ``goal_metric`` and ``weeks`` are ours, not the model's
    (``program_prompt``).
    """
    program = payload.get("program")
    if not isinstance(program, dict):
        return None, ["payload has no 'program' object"]
    issue = _ladder_issue(program, calibrations, taken, blocked or {})
    if issue is not None:
        return None, [issue]
    return _design(program, calibrations), []


def _ladder_issue(
    program: dict, calibrations: CalibrationMap, taken: set[str], blocked: dict[str, str]
) -> str | None:
    """The first reason this ladder may not ship, most fundamental first.

    The order is ``screen``'s: could this shape ever be a ladder (true whoever is asking)
    → is it well-formed → does the corpus give it a goal → is each rung a shippable
    challenge → does the sequence climb honestly.
    """
    structural = _structural_issue(program)
    if structural is not None:
        return structural
    rungs = merged_rungs(program)
    ladderable = programs.rung_shape_issue(rungs[0])
    if ladderable is not None:
        return f"{NOT_LADDERABLE}: {ladderable}"
    if spec(program["metric"]).good != "up":
        return (
            f"{NOT_LADDERABLE}: rung 1: {program['metric']} is a metric where LESS is "
            "better, so a '>=' ladder on it would climb the wrong way — and a '<=' one "
            "has no evidenced rule for easing a rung that timed out unmet"
        )
    calibration = calibrations.get((program["metric"], program["cadence"]))
    if calibration is None:
        return f"{program['metric']}/{program['cadence']} is not a calibratable pair"
    if calibration.target is None:
        return (
            f"{program['metric']} has no evidence target we can cite, so there is no goal "
            "to climb toward — a ladder needs one (challenges/program_screen.py)"
        )
    return _rungs_issue(rungs, calibrations, taken, blocked) or _progression_issue(
        rungs, calibration
    )


def _structural_issue(program: dict) -> str | None:
    """Shape and vocabulary — the checks that make the ladder well-formed at all."""
    missing = [f for f in _PROGRAM_FIELDS if f not in program]
    if missing:
        return f"program is missing {missing}"
    if program["category"] not in CATEGORIES:
        return f"category {program['category']!r} is not in the vocabulary"
    rungs = program["rungs"]
    if not isinstance(rungs, list) or not MIN_RUNGS <= len(rungs) <= MAX_RUNGS:
        count = len(rungs) if isinstance(rungs, list) else "no"
        return f"a ladder has {MIN_RUNGS}-{MAX_RUNGS} rungs, and this one has {count}"
    if any(not isinstance(rung, dict) for rung in rungs):
        return "every rung must be an object"
    return None


def _rungs_issue(
    rungs: list[dict], calibrations: CalibrationMap, taken: set[str], blocked: dict[str, str]
) -> str | None:
    """Every rung run through the CHALLENGE gates — Gate A on the first one only.

    ``taken`` is passed unchanged to each rung and never added to, because the rungs share
    one metric by construction and a ladder is ONE commitment. Growing the set per rung
    (which is right for a batch of independent challenges) would have rung 2 refuse itself
    as a duplicate of rung 1.
    """
    for index, rung in enumerate(rungs):
        window = _window_issue(rung)
        issue = window or proposal_issue(rung, calibrations, taken, blocked, bind_target=index == 0)
        if issue is not None:
            return f"rung {index + 1}: {issue}"
    return None


def _window_issue(rung: dict) -> str | None:
    """A rung is at least a week (``program_prompt.MIN_RUNG_DAYS`` argues why)."""
    try:
        window = int(rung["window_days"])
    except (KeyError, TypeError, ValueError):
        return None  # `proposal_issue` reports a missing/unreadable window properly
    if not MIN_RUNG_DAYS <= window <= MAX_WINDOW_DAYS:
        return f"window_days {window} is outside a rung's {MIN_RUNG_DAYS}-{MAX_WINDOW_DAYS}"
    return None


def _progression_issue(rungs: list[dict], calibration: Calibration) -> str | None:
    """The sequence itself: it climbs, it stops at the evidence, and it ends this season.

    Strictly increasing, because a rung that repeats or lowers the one before it is either
    a deload (which only the ENGINE may insert, after a real failure — ``ladder``) or a
    step that asks for nothing. ``>=`` and ``good="up"`` are already established, so
    "climbing" is plain ``>``.
    """
    targets = [float(rung["target_value"]) for rung in rungs]
    for index, (lower, higher) in enumerate(zip(targets, targets[1:], strict=False)):
        if higher <= lower:
            return (
                f"rung {index + 2} asks for {higher:g}, which is not a step up from rung "
                f"{index + 1}'s {lower:g} — a ladder that does not climb is not a ladder"
            )
    cap = calibration.target
    if cap is not None and targets[-1] > cap:
        return (
            f"rung {len(targets)} asks for {targets[-1]:g}, past the evidence target of "
            f"{cap:g} [{calibration.target_note}] — beyond it the research says nothing "
            "about what the extra is worth"
        )
    total = sum(int(rung["window_days"]) for rung in rungs)
    if total > MAX_PROGRAM_DAYS:
        return f"the ladder runs {total} days, past the {MAX_PROGRAM_DAYS}-day limit"
    return None


def merged_rungs(program: dict) -> list[dict[str, Any]]:
    """Each rung as a COMPLETE challenge proposal, with the ladder's shape folded in.

    Public because ``program_generate`` persists exactly these rows: the dict screened and
    the dict written must be the same dict, or the gates would have judged something other
    than what landed.
    """
    shape = {field: program[field] for field in _INHERITED}
    return [rung | shape | {"rung_index": index} for index, rung in enumerate(program["rungs"])]


def _design(program: dict, calibrations: CalibrationMap) -> dict:
    """The ladder as it will be stored, with the three derived fields computed here."""
    rungs = merged_rungs(program)
    calibration = calibrations[(program["metric"], program["cadence"])]
    days = sum(int(rung["window_days"]) for rung in rungs)
    return {
        "program": {
            "title": program["title"],
            "why": program["why"],
            "goal": _goal(program, calibration),
            "goal_metric": program["metric"],
            "category": program["category"],
            "weeks": math.ceil(days / _DAYS_PER_WEEK),
        },
        "rungs": rungs,
    }


def _goal(program: dict, calibration: Calibration) -> str:
    """Where this ladder is climbing to, in the corpus's words and units — never the model's.

    ``calibration.target`` is the evidence target already converted into this cadence's
    units by ``targets.in_cadence``, and it is non-``None`` by the time this runs
    (:func:`_ladder_issue` refuses a metric without one). The note id rides along for the
    same reason it does in a challenge's ``why``: a number about a population that does not
    say where it came from is the thing this product exists not to publish.
    """
    if calibration.target is None:  # `_ladder_issue` has already refused this ladder
        raise RuntimeError(f"{calibration.metric} reached _goal with no evidence target")
    metric = spec(program["metric"])
    # `unit` is empty for the metrics whose LABEL is the unit (`steps_total` is "Steps"
    # with unit ""), so the label is the fallback rather than a blank in the sentence.
    noun = metric.unit or metric.label.lower()
    period = "a day" if program["cadence"] == "daily" else "a week"
    return f"{calibration.target:g} {noun} {period} [{calibration.target_note}]"
