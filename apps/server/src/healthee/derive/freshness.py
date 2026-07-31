"""Is the newest stored row a claim about the owner's TODAY? — the one answer.

## The defect this module exists to make impossible

A consumer reads the NEWEST row of a daily metric, drops its ``day``, and presents the
value as current. It has shipped live wrong numbers three times: a stale VO₂max as the
fitness hero (``read/vo2max.py``), a stale VO₂max spent as years inside the biological
age (``analytics/biological_age.py``), and the five sites closed alongside this module —
the SRI in the biological age and in ``/api/sleep/consistency``, sleep debt and "last
night's sleep" on the Today page, and a stale recovery score fed to the LLM as *today's*
readiness ceiling.

The shape is always identical, so the answer is one function rather than five date
checks. Five checks is how a metric ends up with two definitions of "current" —
the failure mode CLAUDE.md names explicitly.

## What "current" means here, and why it is a single rule

**A stored row is a claim about the day it is keyed to, and about no other day.** The
owner's today is therefore the only anchor: not "recent", not "within N days". A
tolerance would be a tunable, and a tunable in an honesty gate is a place to hide.

That rule has one visible consequence worth stating plainly: between an owner's local
midnight and their morning sync, today's rows do not exist yet, so these metrics read as
:data:`NOT_DERIVED_YET` — "sync the strap" — rather than showing yesterday's number.
That is the correct answer. We genuinely do not have today's yet, and the reason
vocabulary distinguishes *waiting on a sync* from a gate that has REFUSED, so the owner
is told which one they are looking at.

## The vocabulary (reason ids are shared, messages are not)

A **reason id** names a state, and one state has exactly one id — the ids below cover
conditions shared across metrics, and a metric adds its own only for a gate only it has
(e.g. ``derive/vo2max.py``'s RHR-noise withhold).

A **message** is the second-person "here is what we'd need", and it is deliberately
per-metric: what would restore a VO₂max is not what would restore an SRI. Each metric
owns a ``…_MESSAGES`` dict keyed by these ids. :data:`NOT_DERIVED_YET_MESSAGE` is the
default wording for metrics with nothing more specific to say.
"""

from __future__ import annotations

from collections.abc import Callable
from datetime import date

# ── shared reason ids ────────────────────────────────────────────────────────

# The newest row is not today's and no gate refused: the day simply has not been derived
# (nothing synced for it yet). Not a withhold any research note asks for — it shares the
# vocabulary because the USER-VISIBLE state is the same ("there is no number for today"),
# and a payload that names every other absence and shrugs at this one would be the same
# silence in a different place.
NOT_DERIVED_YET = "not_derived_yet"

# ``derive._common._load_profile`` returned None: height/sex/dob incomplete, or no
# logged weight. One id because it is one condition — the shared loader's one failure —
# however many metrics happen to depend on it.
PROFILE_INCOMPLETE = "profile_or_weight_missing"

# A rolling-window metric whose window contains no recorded nights at all. Distinct from
# NOT_DERIVED_YET: the derivation would run and still write nothing, because there is no
# sleep to compute over. "No data" and "not computed" are different states and must stay
# distinguishable to the caller (standards §1).
NO_NIGHTS_IN_WINDOW = "no_recorded_nights_in_window"

NOT_DERIVED_YET_MESSAGE = "Today's number has not been computed yet — sync the strap."


def unavailable_reason(
    today: date,
    last_day: date | None,
    gate: Callable[[], str | None] | None = None,
) -> str | None:
    """Why the newest stored row is not a claim about TODAY, or ``None`` when it is.

    ``last_day is None`` (no row at all) is the same answer as a stale one — there is no
    value for today either way, which is why ONE rule covers both. That matters: two
    treatments of one state is how a second definition gets in.

    ``gate`` is the metric's own "could today carry a value" check, and it is a callable
    so it stays UNEVALUATED on the common path: a row keyed to today short-circuits
    before any extra query runs, so freshness costs nothing when data is fresh. A metric
    with no gate of its own passes nothing and gets :data:`NOT_DERIVED_YET`.
    """
    if last_day == today:
        return None
    return (gate() if gate is not None else None) or NOT_DERIVED_YET


def withheld_block(
    reason: str,
    message: str,
    today: date,
    last_day: date | None,
    **extra: object,
) -> dict:
    """The ``withheld`` block: why there is no current value, and how old the last one is.

    The shape ``read/vo2max.py`` established and ``data_health`` uses for a dead feed —
    a reason an operator can filter on, a message a person can act on, and the age of
    what we *do* have. ``extra`` carries the metric's own last value (``last_estimate``,
    ``last_debt_min``, …) INSIDE this block, where nothing can mistake it for today's.

    The paired half of the contract lives at the call site and is not optional: the
    current-looking field itself must be ``None`` whenever this block is present. A dated
    field the UI may not render does not undo a confident current-looking number.
    """
    return {
        "reason": reason,
        "message": message,
        "last_as_of_date": last_day.isoformat() if last_day else None,
        "age_days": (today - last_day).days if last_day else None,
        **extra,
    }
