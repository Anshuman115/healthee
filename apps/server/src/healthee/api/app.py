"""FastAPI application wiring — construction only.

No business logic and no SQL live here (standards §2: "app.py (wiring only)").
It configures logging, opens/closes the DB pool around the app lifetime, and
mounts the routers. Domain routers are added as later work packages land.

Serve it with:

    uv run uvicorn healthee.api.app:app
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from healthee.api.routers import (
    activity,
    auth,
    challenges,
    coach,
    gps,
    health,
    history,
    ingest,
    insights,
    logs,
    programs,
    sleep,
    today,
    workouts,
)
from healthee.core.db import close_pool
from healthee.core.logging import configure_logging, get_logger

log = get_logger(__name__)


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    """Startup/shutdown: configure logging on the way up, close the pool on the
    way down. The pool itself opens lazily on first query."""
    configure_logging()
    log.info("healthee server starting")
    yield
    close_pool()
    log.info("healthee server stopped")


def create_app() -> FastAPI:
    """Build the FastAPI app and mount routers. A factory so tests can construct
    isolated instances."""
    app = FastAPI(title="Healthee", version="0.1.0", lifespan=lifespan)
    app.include_router(health.router)
    # WP8 note: the daily chain runs on the scheduler timer (jobs.scheduler).
    # An optional future one-line wire — call jobs.chain.run_chain(day) after a
    # successful ingest push — would make recs refresh event-driven too; the
    # frozen ingest/ router is intentionally left untouched for now.
    app.include_router(ingest.router)
    # WP7 read routers (today / sleep / activity / workouts / history+profile / logs / gps).
    for read_router in (today, sleep, activity, workouts, history, logs, gps):
        app.include_router(read_router.router)
    # WP5 grounded insight surfaces (sleep/activity/metric/workout/notable) + coach.
    app.include_router(insights.router)
    app.include_router(coach.router)
    # WP-C2 challenges: the feed, the lifecycle writes, and the outcome ledger.
    # Deterministic only — generation (WP-C3) and the coach tools (WP-C5) are later,
    # and 6.6's premium gate threads through when it exists (see the router).
    app.include_router(challenges.router)
    # WP-C4 programs: the multi-week ladder over those challenges. Mounted beside
    # them rather than inside them because a rung's own lifecycle is the challenges
    # router's (adapt, abandon), while the ladder's is this one's.
    app.include_router(programs.router)
    # Phase 6.1 identity — Supabase-JWT-authed /api/me + /api/device. Additive:
    # existing routers keep their shared-token guard until the 6.4 flip.
    app.include_router(auth.router)
    return app


app = create_app()
