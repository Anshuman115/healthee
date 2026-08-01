"""Transport unit tests — the JSON output-format seam, and the model id stays unlogged.

No network: the OpenAI SDK object is replaced by a fake that records the kwargs
handed to ``chat.completions.create`` so we can assert ``response_format`` is (and
is NOT) forwarded, without changing the prose path.

The second concern here is a standing owner constraint: **the model we run must not be
discoverable**. Keeping the ids out of git (they resolve from ``DEFAULT_MODEL`` /
``COACH_MODEL``) is undone by a runtime log line that prints them, which is what
``llm completion: model=…`` did on every single call. The tests below capture the log
records and assert the id is absent and the TIER is present, so an operator keeps the
diagnostic and nobody reading logs learns the id.
"""

from __future__ import annotations

import logging
from types import SimpleNamespace
from typing import Any

import pytest

from healthee.core.config import get_settings
from healthee.insights.client import OpenRouterClient, tier_of


class _FakeCompletions:
    def __init__(self, finish_reason: str | None = None, usage: Any = None) -> None:
        self.kwargs: dict[str, Any] | None = None
        self._finish_reason = finish_reason
        self._usage = usage

    def create(self, **kwargs: Any) -> Any:
        self.kwargs = kwargs
        message = SimpleNamespace(content="ok", tool_calls=None)
        choice = SimpleNamespace(message=message, finish_reason=self._finish_reason)
        return SimpleNamespace(choices=[choice], usage=self._usage)


class _FakeSDK:
    def __init__(self, finish_reason: str | None = None, usage: Any = None) -> None:
        self.chat = SimpleNamespace(completions=_FakeCompletions(finish_reason, usage))


def _client_with_fake(
    finish_reason: str | None = None, usage: Any = None
) -> tuple[OpenRouterClient, _FakeSDK]:
    client = OpenRouterClient()
    fake = _FakeSDK(finish_reason, usage)
    client._client = lambda: fake  # type: ignore[method-assign]  # inject the fake SDK
    return client, fake


# A value that could not plausibly be anything but the id we passed, so "the id is
# absent" is a real assertion rather than a coincidence of short strings.
_SECRET_MODEL = "vendor-x/never-log-me-9000"


@pytest.fixture
def configured_models(monkeypatch: pytest.MonkeyPatch) -> Any:
    """Point both tiers at known ids so ``tier_of`` has something to resolve against."""
    monkeypatch.setenv("COACH_MODEL", _SECRET_MODEL)
    monkeypatch.setenv("DEFAULT_MODEL", "vendor-x/cheap-tier-1")
    monkeypatch.setenv("OPENROUTER_API_KEY", "test-key")
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def test_response_format_is_forwarded_to_the_sdk() -> None:
    client, fake = _client_with_fake()
    client.complete([{"role": "user", "content": "x"}], response_format={"type": "json_object"})
    assert fake.chat.completions.kwargs is not None
    assert fake.chat.completions.kwargs["response_format"] == {"type": "json_object"}


def test_response_format_absent_by_default_keeps_prose_path_unchanged() -> None:
    client, fake = _client_with_fake()
    client.complete([{"role": "user", "content": "x"}])
    assert fake.chat.completions.kwargs is not None
    assert "response_format" not in fake.chat.completions.kwargs


# ── the model id must not be discoverable from the logs ──────────────────────


def test_the_completion_log_names_the_tier_not_the_model_id(
    caplog: pytest.LogCaptureFixture, configured_models: None
) -> None:  # noqa: ARG001 — the fixture is the environment
    client, _ = _client_with_fake()
    with caplog.at_level(logging.INFO):
        client.complete([{"role": "user", "content": "x"}], model=_SECRET_MODEL)
    logged = "\n".join(record.getMessage() for record in caplog.records)
    assert "tier=coach" in logged
    assert _SECRET_MODEL not in logged


def test_the_truncation_warning_names_the_tier_not_the_model_id(
    caplog: pytest.LogCaptureFixture, configured_models: None
) -> None:  # noqa: ARG001 — the fixture is the environment
    """The same leak was in the warning added when the reasoning-token trap was found."""
    client, _ = _client_with_fake(finish_reason="length")
    with caplog.at_level(logging.WARNING):
        client.complete([{"role": "user", "content": "x"}], model=_SECRET_MODEL)
    warnings = "\n".join(r.getMessage() for r in caplog.records if r.levelno >= logging.WARNING)
    assert "TRUNCATED" in warnings
    assert "tier=coach" in warnings
    assert _SECRET_MODEL not in warnings


def test_tier_of_distinguishes_the_two_configured_tiers(configured_models: None) -> None:  # noqa: ARG001
    """Operators need "which surface's model", and both tiers must be tellable apart."""
    assert tier_of(_SECRET_MODEL) == "coach"
    assert tier_of("vendor-x/cheap-tier-1") == "default"


# ── provider-counted usage reaches the caller (the eval harness reads it) ────


def test_the_providers_token_counts_are_carried_on_the_response() -> None:
    """Including reasoning tokens — the field that made the max_tokens trap unreadable."""
    usage = SimpleNamespace(
        prompt_tokens=33_446,
        completion_tokens=1068,
        completion_tokens_details=SimpleNamespace(reasoning_tokens=892),
    )
    client, _ = _client_with_fake(usage=usage)
    response = client.complete([{"role": "user", "content": "x"}])
    assert response.usage is not None
    assert response.usage.prompt_tokens == 33_446
    assert response.usage.completion_tokens == 1068
    assert response.usage.reasoning_tokens == 892


def test_a_provider_that_reports_no_usage_is_unknown_not_zero() -> None:
    """ "We don't know" and "it cost nothing" are different states (standards §Errors)."""
    client, _ = _client_with_fake(usage=None)
    assert client.complete([{"role": "user", "content": "x"}]).usage is None


def test_a_usage_block_without_a_reasoning_breakdown_still_reports_what_it_has() -> None:
    """Not every provider breaks reasoning out; a missing detail is 0, never a crash."""
    usage = SimpleNamespace(prompt_tokens=100, completion_tokens=20)
    client, _ = _client_with_fake(usage=usage)
    response = client.complete([{"role": "user", "content": "x"}])
    assert response.usage is not None
    assert (response.usage.prompt_tokens, response.usage.reasoning_tokens) == (100, 0)


def test_an_id_matching_neither_setting_is_reported_as_unconfigured(
    configured_models: None,
) -> None:  # noqa: ARG001
    """A caller passing an explicit model, or an env changed under a running process."""
    assert tier_of("vendor-x/some-other-model") == "unconfigured"
    assert tier_of("") == "unset"
