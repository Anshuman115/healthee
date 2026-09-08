"""Grounded insight reads — the LLM surfaces, all behind the §3 choke point.

Thin (standards §2): authorize + gate → call one insight service → return its payload.
No prompt-building, grounding, or SQL here — that lives in ``healthee.insights``.
Each surface caches per day, so a second same-day call returns the cached text
without a second LLM generation.

Every route here is PREMIUM (``PRICING.md`` §1a lists the four AI insight cards and the
Notable feed as fully paid), so each takes a gated identity from ``api.gate`` instead of
``CurrentUser`` — a non-premium owner gets 402 and the app renders a locked card. The
gate runs before the cache lookup, which is the point: §12.7's "read pre-generated AI
content from another path" loophole is closed by the job not generating for a free owner
*and* by this endpoint refusing to serve a card that predates their lapse.
"""

from __future__ import annotations

from fastapi import APIRouter

from healthee.api.gate import InsightUser, NotableUser
from healthee.api.validation import require_known_metric
from healthee.insights import surfaces
from healthee.insights.notable import notable

router = APIRouter(tags=["insights"])


@router.get("/api/sleep/insight")
def get_sleep_insight(user: InsightUser, refresh: bool = False) -> dict:
    """Grounded analysis of recent sleep (cached per day)."""
    return surfaces.sleep_insight(user.id, user.timezone, refresh=refresh)


@router.get("/api/activity/insight")
def get_activity_insight(user: InsightUser, refresh: bool = False) -> dict:
    """Grounded activity/fitness coaching (cached per day)."""
    return surfaces.activity_insight(user.id, user.timezone, refresh=refresh)


@router.get("/api/metric/insight")
def get_metric_insight(user: InsightUser, metric: str, refresh: bool = False) -> dict:
    """Grounded per-metric interpretation; empty text when data is too thin.

    ``metric`` is the only input, and ``require_known_metric`` validates it against the
    derived-metric registry before anything else runs. There used to be a second one — a
    free-text ``label`` query parameter, validated by nothing, interpolated straight into
    the task sentence of the prompt ("interpret my {label} for me right now"). Two things
    were wrong with it and one fix removes both: it was an unvalidated string inside an
    instruction, and it was **not in the cache key**, so a text generated from one label
    was served for the rest of the day whatever label the next caller sent. The label is
    a display string this server already owns (``read.meta.METRIC_META``), so nothing is
    lost by reading it rather than being told it.
    """
    require_known_metric(metric)
    return surfaces.metric_insight(user.id, user.timezone, metric, refresh=refresh)


@router.get("/api/activity/workout/insight")
def get_workout_insight(user: InsightUser, start: str, refresh: bool = False) -> dict:
    """Grounded coach review of one workout (cached per workout)."""
    return surfaces.workout_insight(user.id, user.timezone, start, refresh=refresh)


@router.get("/api/notable")
def get_notable(user: NotableUser, refresh: bool = False) -> dict:
    """Notable shifts across daily metrics, each with a grounded meaning (cached/day)."""
    return notable(user.id, user.timezone, refresh=refresh)
