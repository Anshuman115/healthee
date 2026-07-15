"""Logging setup — one configured root for the whole app.

Every module logs through the stdlib `logging` tree (`get_logger(__name__)`);
this is the single place the root handler and level are configured. Level comes
from `Settings.log_level` (the one config path — no direct env reads). Format is
concise and carries the logger name so failures are traceable to their module
(standards §1: "errors logged with context through the one logging path").
"""

from __future__ import annotations

import logging

from healthee.core.config import get_settings

_LOG_FORMAT = "%(asctime)s %(levelname)-7s %(name)s: %(message)s"
_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"
_configured = False


def configure_logging(level: str | None = None) -> None:
    """Configure the root logger once. Idempotent — repeat calls are no-ops.

    `level` overrides `Settings.log_level` when given (tests, one-off scripts).
    Called at app startup; anything logging before this still works via stdlib
    defaults, it just isn't formatted yet.
    """
    global _configured
    if _configured:
        return
    resolved = (level or get_settings().log_level).upper()
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter(_LOG_FORMAT, datefmt=_DATE_FORMAT))
    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(resolved)
    _configured = True


def get_logger(name: str) -> logging.Logger:
    """Return a named logger. Use `__name__` at each call site so log lines
    identify their originating module."""
    return logging.getLogger(name)
