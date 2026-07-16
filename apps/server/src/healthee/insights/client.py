"""OpenRouter chat client (OpenAI-compatible API) — the ONE LLM transport.

OpenRouter exposes Anthropic / OpenAI / Google models behind a single
OpenAI-compatible endpoint; we point the ``openai`` SDK at its base URL. Every
LLM surface reaches this through the grounded-ask choke point (``grounded.py``),
never directly (standards §2: "LLM access only via the grounded-ask choke point").

The API key is read once from ``core.config`` and never logged (standards
§Errors: no secret ever reaches a log line). Tests inject a stub implementing the
``LLMClient`` protocol, so no network call happens under pytest.
"""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from typing import Any, Protocol

from healthee.core.config import get_settings
from healthee.core.logging import get_logger

log = get_logger(__name__)

# Default model: a cheap, fast "Flash" tier (matches the legacy default), good at
# following the strict citation prompt. Overridable per call — model ids are
# config, not a hardcoded contract. Low temperature: health data wants factual,
# reproducible output, not creative tails.
DEFAULT_MODEL = "google/gemini-3-flash-preview"
DEFAULT_TEMPERATURE = 0.1
DEFAULT_TOP_P = 0.9
DEFAULT_MAX_TOKENS = 1200

_OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"


@dataclass(frozen=True)
class ChatResponse:
    """A single assistant turn: its text plus any tool calls it requested.

    ``tool_calls`` is the raw OpenAI-shaped list (or None); the coach tool-loop
    (WP5b) consumes it. Insight surfaces use only ``text``.
    """

    text: str
    tool_calls: list[Any] | None = None


class LLMClient(Protocol):
    """The one method the choke point needs. A stub implements this in tests."""

    def complete(
        self,
        messages: list[dict],
        *,
        tools: list[dict] | None = None,
        model: str = DEFAULT_MODEL,
        response_format: dict | None = None,
    ) -> ChatResponse: ...


class OpenRouterClient:
    """Real transport: the ``openai`` SDK pointed at OpenRouter. Constructed lazily
    so importing this module never requires a key or touches the network."""

    def __init__(self) -> None:
        self._sdk: Any | None = None

    def _client(self) -> Any:
        if self._sdk is None:
            key = get_settings().openrouter_api_key
            if not key:
                raise RuntimeError("OPENROUTER_API_KEY is unset — LLM features are unavailable")
            from openai import OpenAI  # local import: heavy SDK, only when a call happens

            self._sdk = OpenAI(api_key=key, base_url=_OPENROUTER_BASE_URL)
        return self._sdk

    def complete(
        self,
        messages: list[dict],
        *,
        tools: list[dict] | None = None,
        model: str = DEFAULT_MODEL,
        response_format: dict | None = None,
    ) -> ChatResponse:
        """One completion. Returns the assistant text + any tool calls.

        ``response_format`` (e.g. ``{"type": "json_object"}``) is forwarded to the
        SDK when supplied — the grounded-ask choke point sets it for JSON surfaces
        (recs) so the model returns a parseable object, not fenced prose. Default
        ``None`` leaves the request unchanged (prose path is byte-identical).

        Errors propagate (the endpoint layer degrades to an honest error body) —
        never swallowed. The key is passed to the SDK, never logged.
        """
        kwargs: dict[str, Any] = {
            "model": model,
            "messages": messages,
            "temperature": DEFAULT_TEMPERATURE,
            "top_p": DEFAULT_TOP_P,
            "max_tokens": DEFAULT_MAX_TOKENS,
            "extra_headers": {"X-Title": "healthee"},
        }
        if tools:
            kwargs["tools"] = tools
        if response_format is not None:
            kwargs["response_format"] = response_format
        message = self._client().chat.completions.create(**kwargs).choices[0].message
        log.info("llm completion: model=%s tools=%d", model, len(tools or []))
        return ChatResponse(
            text=message.content or "", tool_calls=getattr(message, "tool_calls", None)
        )


@lru_cache(maxsize=1)
def get_client() -> OpenRouterClient:
    """Process-wide real client. ``grounded_ask`` defaults to this; tests pass a stub."""
    return OpenRouterClient()
