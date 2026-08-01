"""DATA COVERAGE — the one definition, and the third thing every answer carries.

INTELLIGENCE §3 has promised three pieces of response metadata since the choke point was
designed: ``citations[]``, an evidence grade floor, and **data coverage**. The first two
ship. The third had no definition anywhere and no surface carried it (#89), which is the
worst state for a promise to be in: a reader of §3 believes the answer is telling them how
much of their data it rests on, and it never was.

## The definition

    **Data coverage of a metric over a window is the number of days in that window on
    which the metric has a stored daily value, out of the number of days in the window.**

Days, not samples. Per metric, never blended. The window is the owner's local calendar
days ending on the owner's today, which is the same window everything else in this layer
is anchored to (``analytics.baselines``' note on ``user_today`` vs ``date.today()``).

Three decisions inside that sentence, each of which could have gone the other way:

* **Per metric, not one number for the answer.** "9 of 14 days covered" over a mixed
  context is a composite score, and a composite with no methodology is exactly what
  CLAUDE.md forbids: sleep metrics and step metrics are absent for different reasons and
  averaging them produces a number that means nothing about either.
* **Two integers, not a percentage.** 12/14 and 86% are the same fact, but the fraction
  cannot be rounded into a lie and it carries its own n — the same discipline
  ``grounding_eval`` prints every rate under.
* **Counted by ``analytics.baselines``, not by a new query.** ``Baseline.n`` is already
  "valid days for this metric in this window", already applies the canonical sentinel
  filter (an ``rhr_daily`` of 0 means *not measured*, and a coverage number that counted
  it would overstate every RHR window), and is already what the personal baselines the
  model reasons over were computed from. A second COUNT(*) here would be a second
  definition of "has data", and it would disagree the first time a sentinel changed.

## What it is NOT, so it stays out of the absence vocabulary's way

Coverage is a QUANTITY. It never says why something is missing, and it introduces no
reason ids, messages or states. The existing vocabulary keeps that job and none of it
changes:

* ``derive.freshness`` answers *is the newest row a claim about TODAY* — one day, a
  yes/no. A 13/14 window whose missing day is today is a freshness problem that coverage
  would call excellent, which is precisely why both exist.
* ``withheld`` (``freshness.withheld_block``) — there is no current value, here is the
  reason and what would restore it. An owner action might.
* ``excluded`` (``analytics.biological_age``) — permanently not part of the definition;
  no owner action brings it back.
* ``data_confidence`` — the outcome-ledger's ``ok`` / ``insufficient_data`` verdict on a
  specific derived number.

A metric at 0/14 is reported as 0/14 and nothing more. Whichever of those four states it
is in is stated where that metric is served, by the code that knows.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from uuid import UUID

from healthee.analytics.baselines import compute_baselines

# The window a coverage figure is quoted over when a surface does not name one. It is the
# insight surfaces' own default ``context_days``, so "coverage" and "the context the model
# saw" describe the same days rather than two nearby windows.
DEFAULT_COVERAGE_DAYS = 14


@dataclass(frozen=True)
class Coverage:
    """One metric's coverage over one window — two integers and the metric's name."""

    metric: str
    days_with_data: int
    window_days: int

    @property
    def fraction(self) -> float:
        """``days_with_data / window_days``; 0.0 for an empty window (no days, no data)."""
        return self.days_with_data / self.window_days if self.window_days else 0.0


def measure(
    user_id: UUID, tz: str, metrics: Sequence[str], window_days: int = DEFAULT_COVERAGE_DAYS
) -> list[Coverage]:
    """Coverage for each of ``metrics`` over the owner's trailing ``window_days``.

    Order follows ``metrics`` and duplicates collapse, so a surface's declared metric list
    reads back in the order it declared it. An unknown metric name is not an error here:
    it comes back 0/N, which is the true answer to "how many days of it do we have".
    """
    wanted = list(dict.fromkeys(metrics))
    if not wanted:
        return []
    baselines = compute_baselines(user_id, tz, wanted, window_days)
    return [Coverage(m, baselines[m].n, window_days) for m in wanted]


def payload(coverages: Sequence[Coverage], window_days: int) -> dict:
    """The wire shape: the window once, then days-with-data per metric.

    ``window_days`` is passed rather than read off the first entry so that an answer that
    scoped itself to NO metric still says what window it is talking about — an empty
    ``days_with_data`` map means "this answer read no metric directly", which is a
    different statement from "we have no data" and must not collapse into it.
    """
    return {
        "window_days": window_days,
        "days_with_data": {c.metric: c.days_with_data for c in coverages},
    }


def measured_payload(
    user_id: UUID, tz: str, metrics: Sequence[str], window_days: int = DEFAULT_COVERAGE_DAYS
) -> dict:
    """:func:`measure` straight into :func:`payload` — what every LLM surface calls."""
    return payload(measure(user_id, tz, metrics, window_days), window_days)
