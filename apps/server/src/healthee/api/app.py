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

from healthee.api.routers import health
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
    return app


app = create_app()
