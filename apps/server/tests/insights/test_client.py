"""Transport unit tests — the JSON output-format seam is forwarded to the SDK.

No network: the OpenAI SDK object is replaced by a fake that records the kwargs
handed to ``chat.completions.create`` so we can assert ``response_format`` is (and
is NOT) forwarded, without changing the prose path.
"""

from __future__ import annotations

from types import SimpleNamespace
from typing import Any

from healthee.insights.client import OpenRouterClient


class _FakeCompletions:
    def __init__(self) -> None:
        self.kwargs: dict[str, Any] | None = None

    def create(self, **kwargs: Any) -> Any:
        self.kwargs = kwargs
        message = SimpleNamespace(content="ok", tool_calls=None)
        return SimpleNamespace(choices=[SimpleNamespace(message=message)])


class _FakeSDK:
    def __init__(self) -> None:
        self.chat = SimpleNamespace(completions=_FakeCompletions())


def _client_with_fake() -> tuple[OpenRouterClient, _FakeSDK]:
    client = OpenRouterClient()
    fake = _FakeSDK()
    client._client = lambda: fake  # type: ignore[method-assign]  # inject the fake SDK
    return client, fake


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
