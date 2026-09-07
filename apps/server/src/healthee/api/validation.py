"""Shared request-input validation for the thin HTTP routers (standards §2).

Routers validate input before calling a domain function; this keeps that check in
ONE place so ``/api/history`` and ``/api/metric/insight`` cannot drift on what a
valid ``metric`` is.
"""

from __future__ import annotations

from datetime import date

from fastapi import HTTPException

from healthee.analytics.metrics import KNOWN_METRICS, is_known_metric
from healthee.core.tenancy import user_today

# The most metrics one batched read may name. It is the size of the registry
# itself: asking for more than the server serves is a malformed request, not a
# bigger question, and an unbounded list is an unbounded query (standards
# section 1, "unbounded data is windowed"). Deriving it rather than writing a
# number means a new metric raises the ceiling by exactly one, automatically.
MAX_METRIC_LIST: int = len(KNOWN_METRICS)

# Domain refusal reason -> HTTP status. A rule outcome is a real answer, so it is not
# a 500 and not a 200-with-an-error-field; mapping it here keeps the routers thin and
# keeps ONE place deciding what "the owner already has three of these" looks like on
# the wire. An unlisted reason falls to 409: a state conflict is the safe reading of
# "the domain said no", and it is visible rather than silently a success.
_REFUSAL_STATUS: dict[str, int] = {
    "not_found": 404,
    "not_suggested": 409,
    "not_active": 409,
    "too_many_active": 409,
    # #72. A conflict like the cap's, and listed separately rather than left to the
    # fallback because a client has to be able to tell the two apart: "you are already
    # doing that" and "you are full" call for different things from the owner, and the
    # `reason` in the body is what says which.
    "duplicate_commitment": 409,
    "no_adaptation": 409,
    # WP-C3b/C4b — the generation refusals. All 409, and each is listed rather than left
    # to the fallback so the choice is a decision somebody made:
    #
    # A generation refusal is a statement about the STATE the owner's data is in, never a
    # server error and never a silent 200-with-nothing. 5xx would be wrong (nothing
    # failed — the pipeline worked and its answer was "no"), and 200 would be worse: an
    # empty feed with no reason is the exact degraded state CHALLENGES.md §2.5 forbids.
    # The `reason` in the body is what lets a client say WHICH — "you are already running
    # three", "there is not enough of your data yet", "the evidence base could not ground
    # one" and "you are already climbing a ladder" call for four different sentences.
    "no_calibratable_metric": 409,
    "no_grounded_output": 409,
    "program_active": 409,
    "not_ladderable": 409,
}


def require_known_metric(metric: str) -> str:
    """Return ``metric`` unchanged, or raise 422 if the server does not recognize it.

    An unknown name (e.g. ``bogus``) must be an explicit error, not a 200 with an
    empty series — for an honesty-first product, "that isn't a metric" must never
    read as "you have no data". The accepted set is the single registry in
    ``analytics.metrics`` (``KNOWN_METRICS``), so it stays in step with what the
    server actually serves.
    """
    if not is_known_metric(metric):
        raise HTTPException(status_code=422, detail=f"unknown metric: {metric!r}")
    return metric


def require_metric_list(metrics: str) -> tuple[str, ...]:
    """Split ``a,b,c`` into validated canonical names, or raise 422.

    **An unknown id refuses the whole call.** The tempting alternative is to drop
    it and answer with the rest, and that is the failure this product cannot
    afford: a client that asked for nine series and got eight cannot tell which
    name the server did not recognise, and the missing key reads exactly like
    "you have no readings for that". Every entry therefore goes through
    :func:`require_known_metric`, which is the same gate the single-metric form
    passes — one definition of a valid metric, not two.

    Repeats collapse (a client naming a metric twice asked one question), order
    is kept so the caller can pair the answer with what it sent, and the list is
    capped at :data:`MAX_METRIC_LIST`.
    """
    wanted = tuple(dict.fromkeys(part.strip() for part in metrics.split(",") if part.strip()))
    if not wanted:
        raise HTTPException(status_code=422, detail="'metrics' must name at least one metric")
    if len(wanted) > MAX_METRIC_LIST:
        raise HTTPException(
            status_code=422,
            detail=f"at most {MAX_METRIC_LIST} metrics per call, got {len(wanted)}",
        )
    for metric in wanted:
        require_known_metric(metric)
    return wanted


def require_reference_day(day: str | None, tz: str) -> date | None:
    """Parse the optional ``day=YYYY-MM-DD`` query parameter, or raise 422.

    ``None`` in, ``None`` out — the read services then resolve it to the owner's today
    themselves (``core.tenancy.reference_day``), so absence keeps meaning "answer for
    now" and the default lives in ONE place rather than being re-decided at each router.

    Two refusals, and both are the honesty contract rather than input hygiene:

    * **A malformed date is a 422, never a silent fallback to today.** Answering a
      request for ``2026-07-3`` with today's numbers under no date at all is the
      stale-as-current failure arriving through the front door.
    * **A day in the owner's FUTURE is a 422.** Every window would be bounded by it and
      every surface would withhold, so the payload would technically be honest — but it
      would read as "we have nothing for you" when the truth is "that day has not
      happened". Those are different states and must stay distinguishable (standards
      §1). Today itself is allowed, which is the default.
    """
    if day is None:
        return None
    try:
        parsed = date.fromisoformat(day)
    except ValueError as exc:
        raise HTTPException(
            status_code=422, detail=f"'day' must be YYYY-MM-DD, got {day!r}"
        ) from exc
    today = user_today(tz)
    if parsed > today:
        raise HTTPException(
            status_code=422,
            detail=f"'day' {parsed.isoformat()} is in the future (your today is {today})",
        )
    return parsed


def require_ok(result: dict) -> dict:
    """Return a domain result unchanged, or raise the HTTP status its refusal means.

    The lifecycle services answer with ``{"ok": False, "reason": …, "error": …}`` for
    a rule outcome (standards §Errors — a refusal is a distinguishable state, never an
    empty success). Turning that into a status code is response shaping, which is a
    router's job; doing it here rather than in each handler keeps every challenge
    endpoint answering the same way.
    """
    if result.get("ok", True):
        return result
    reason = str(result.get("reason", ""))
    raise HTTPException(
        status_code=_REFUSAL_STATUS.get(reason, 409),
        detail={"reason": reason, "error": result.get("error")},
    )
