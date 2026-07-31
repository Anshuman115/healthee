"""Shared request-input validation for the thin HTTP routers (standards §2).

Routers validate input before calling a domain function; this keeps that check in
ONE place so ``/api/history`` and ``/api/metric/insight`` cannot drift on what a
valid ``metric`` is.
"""

from __future__ import annotations

from fastapi import HTTPException

from healthee.analytics.metrics import is_known_metric

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
