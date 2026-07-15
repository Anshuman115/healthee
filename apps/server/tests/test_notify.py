"""Unit tests for core.notify — the fire-and-forget Telegram sink.

The contract under test: never raise, always log a failure (never a silent
swallow), and return True only on a 2xx.
"""

from __future__ import annotations

import logging

import httpx
import pytest

from healthee.core import notify
from healthee.core.config import get_settings


@pytest.fixture
def configured(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("POSTGRES_PASSWORD", "pw")
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "bot-token")
    monkeypatch.setenv("TELEGRAM_CHAT_ID", "12345")
    get_settings.cache_clear()


class _FakeResponse:
    def __init__(self, status_code: int, text: str = "") -> None:
        self.status_code = status_code
        self.text = text

    @property
    def is_success(self) -> bool:
        return 200 <= self.status_code < 300


def test_success_returns_true(
    configured: None,
    monkeypatch: pytest.MonkeyPatch,  # noqa: ARG001
) -> None:
    monkeypatch.setattr(notify.httpx, "post", lambda *a, **k: _FakeResponse(200))
    assert notify.send_telegram("hello") is True
    get_settings.cache_clear()


def test_network_error_is_logged_and_swallowed(
    configured: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    def _boom(*_args: object, **_kwargs: object) -> object:
        raise httpx.ConnectError("no route to host")

    monkeypatch.setattr(notify.httpx, "post", _boom)
    with caplog.at_level(logging.WARNING):
        result = notify.send_telegram("hello")  # must NOT raise
    assert result is False
    assert any("telegram send failed" in r.message for r in caplog.records)
    get_settings.cache_clear()


def test_http_error_is_logged_and_returns_false(
    configured: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    monkeypatch.setattr(notify.httpx, "post", lambda *a, **k: _FakeResponse(403, "forbidden"))
    with caplog.at_level(logging.WARNING):
        assert notify.send_telegram("hello") is False
    assert any("telegram HTTP 403" in r.message for r in caplog.records)
    get_settings.cache_clear()


def test_unconfigured_no_ops_without_raising(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("POSTGRES_PASSWORD", "pw")
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "")
    monkeypatch.setenv("TELEGRAM_CHAT_ID", "")
    get_settings.cache_clear()
    assert notify.send_telegram("hello") is False
    get_settings.cache_clear()
