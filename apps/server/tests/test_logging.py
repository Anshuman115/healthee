"""Unit tests for core.logging — the one configured logging path.

The load-bearing assertion here is a SECURITY one: httpx logs every request line
at INFO as `HTTP Request: POST <full url>`, and the Telegram bot token lives in
the URL path (`api.telegram.org/bot<TOKEN>/sendMessage`). If httpx is allowed to
log at INFO, the token is printed into the scheduler log on every notification —
which is exactly what happened in prod. `configure_logging` must pin httpx to
WARNING so the request line (and the secret in it) is never emitted.
"""

from __future__ import annotations

import logging

import healthee.core.logging as logging_module
from healthee.core.logging import configure_logging


def _reset_configured() -> None:
    """`configure_logging` is idempotent via a module global; clear it so a test
    exercises the real configuration rather than a prior call's no-op."""
    logging_module._configured = False


def test_httpx_logger_is_pinned_to_warning() -> None:
    _reset_configured()
    logging.getLogger("httpx").setLevel(logging.INFO)  # simulate a leaky default
    configure_logging(level="INFO")
    # At INFO, httpx would emit `HTTP Request: POST https://api.telegram.org/bot<TOKEN>/…`.
    # WARNING suppresses that line, so the token never reaches a handler.
    assert logging.getLogger("httpx").level >= logging.WARNING


def test_httpx_stays_quiet_even_when_the_root_is_debug() -> None:
    _reset_configured()
    configure_logging(level="DEBUG")
    # The root going verbose must not drag httpx's request line (and the token) back
    # into the stream — the pin is unconditional, not relative to the root level.
    assert logging.getLogger("httpx").level >= logging.WARNING
    assert logging.getLogger().level == logging.DEBUG
