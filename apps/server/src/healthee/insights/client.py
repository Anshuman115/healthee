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

# Model ids live in settings (env: DEFAULT_MODEL / COACH_MODEL), NOT hardcoded here —
# the source never reveals which models we run; they're resolved per call. Per-surface
# tiers: default_model = the cheap, high-volume tier (recs/insights/notable/daily-
# action); coach_model = a stronger tier for the interactive coach (low volume, high
# engagement, where answer quality is most felt). Low temperature: health data wants
# factual, reproducible output, not creative tails. See docs/PRICING.md §6 / task #23.
DEFAULT_TEMPERATURE = 0.1
DEFAULT_TOP_P = 0.9
# A CEILING, not a spend: output is billed on tokens actually produced, so raising this
# costs nothing until an answer genuinely needs the room.
#
# 2000 was measured to be too small, and the old comment ("headroom so verbose/reasoning
# models aren't truncated") was wrong for the tier we actually run. A REASONING model
# spends its thinking out of this SAME budget: measured on the coach tier, one ordinary
# answer used 1068 completion tokens of which **892 were reasoning** — leaving ~180 for
# the visible reply. Longer answers then stopped mid-citation, the validator's truncation
# guard correctly refused them, and the coach shipped the honest fallback to ordinary
# questions. The failure read as "can't ground that" when the real cause was "ran out of
# room to finish the sentence".
DEFAULT_MAX_TOKENS = 10_000


def default_model() -> str:
    """The cheap, high-volume model tier (batch surfaces: recs/insights/notable/action)."""
    return get_settings().default_model


def coach_model() -> str:
    """The stronger model tier for the interactive coach (low volume, quality-first)."""
    return get_settings().coach_model


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
        model: str | None = None,
        response_format: dict | None = None,
    ) -> ChatResponse: ...


class OpenRouterClient:
    """Real transport: the ``openai`` SDK pointed at OpenRouter. Constructed lazily
    so importing this module never requires a key or touches the network."""

    def __init__(self) -> None:
        self._sdk: Any | None = None

    def _client(self) -> Any:
        """The SDK client, built once — with OUR limits, never the SDK's defaults.

        `timeout`/`max_retries` are passed explicitly because omitting them inherits
        `Timeout(read=600)` and `max_retries=2` — 30 minutes of hang for one stuck
        call, which the single-threaded scheduler tick pays for EVERY later owner
        (see `core.config.llm_timeout_s` for the numbers and why).
        """
        if self._sdk is None:
            settings = get_settings()
            if not settings.openrouter_api_key:
                raise RuntimeError("OPENROUTER_API_KEY is unset — LLM features are unavailable")
            from openai import OpenAI  # local import: heavy SDK, only when a call happens

            self._sdk = OpenAI(
                api_key=settings.openrouter_api_key,
                base_url=_OPENROUTER_BASE_URL,
                timeout=settings.llm_timeout_s,
                max_retries=settings.llm_max_retries,
            )
        return self._sdk

    def complete(
        self,
        messages: list[dict],
        *,
        tools: list[dict] | None = None,
        model: str | None = None,
        response_format: dict | None = None,
    ) -> ChatResponse:
        """One completion. Returns the assistant text + any tool calls.

        ``response_format`` (e.g. ``{"type": "json_object"}``) is forwarded to the
        SDK when supplied — the grounded-ask choke point sets it for JSON surfaces
        (recs) so the model returns a parseable object, not fenced prose. Default
        ``None`` leaves the request unchanged (prose path is byte-identical).

        Errors propagate (the endpoint layer degrades to an honest error body) —
        never swallowed. A timeout is one of them: the SDK raises
        ``openai.APITimeoutError`` once ``llm_timeout_s`` is exceeded and it travels
        out through the choke point untouched, so it lands on the chain's supervisor
        (logged + Telegram-notified) instead of quietly becoming an empty answer.
        A blank card and a broken transport are different states and must stay so
        (standards §Errors). The key is passed to the SDK, never logged.
        """
        model = model or get_settings().default_model  # resolve the env-configured default
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
        choice = self._client().chat.completions.create(**kwargs).choices[0]
        message = choice.message
        # The API says outright when it stopped because it ran out of room. We used to
        # drop the whole response object and keep only `.message`, so the ONLY signal
        # left was the validator noticing an unclosed '[' downstream — a string
        # heuristic standing in for a fact the transport already knew. A truncated
        # answer is a transport problem wearing a grounding problem's clothes, and it
        # cost a live debugging session to tell them apart. Log it loudly; the validator
        # still refuses the text, but now the cause is in the logs at the point it
        # happened rather than inferred three layers up.
        # `getattr` with a default, not `choice.finish_reason`: not every provider (or
        # test stub) sets it, and a missing stop-reason must not turn a good answer into
        # an AttributeError. Absent ⇒ we simply don't know, which is not "truncated".
        if getattr(choice, "finish_reason", None) == "length":
            log.warning(
                "llm answer TRUNCATED by max_tokens=%d (model=%s) — the answer stopped "
                "mid-sentence; raise DEFAULT_MAX_TOKENS rather than reading this as a "
                "grounding failure",
                DEFAULT_MAX_TOKENS,
                model,
            )
        log.info("llm completion: model=%s tools=%d", model, len(tools or []))
        return ChatResponse(
            text=message.content or "", tool_calls=getattr(message, "tool_calls", None)
        )


@lru_cache(maxsize=1)
def get_client() -> OpenRouterClient:
    """Process-wide real client. ``grounded_ask`` defaults to this; tests pass a stub."""
    return OpenRouterClient()
