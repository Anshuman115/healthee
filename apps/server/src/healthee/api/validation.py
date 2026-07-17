"""Shared request-input validation for the thin HTTP routers (standards §2).

Routers validate input before calling a domain function; this keeps that check in
ONE place so ``/api/history`` and ``/api/metric/insight`` cannot drift on what a
valid ``metric`` is.
"""

from __future__ import annotations

from fastapi import HTTPException

from healthee.analytics.metrics import is_known_metric


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
