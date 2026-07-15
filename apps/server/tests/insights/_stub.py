"""A deterministic, offline stub LLM client for the insights tests.

Implements the ``LLMClient`` protocol (``complete``) and counts calls, so tests
prove things like "the second endpoint call is served from cache — no second LLM
call" without any network.
"""

from __future__ import annotations

from healthee.insights.client import ChatResponse

# A response that passes the blocking validator: one descriptive sentence + one
# interpretive sentence citing a real Established note (plain wording is fine).
VALID_TEXT = (
    "Your recent numbers look steady. Consistent activity may support fitness "
    "[hrv_recovery_marker]."
)


class StubLLM:
    """Scripted LLM: returns each queued response in turn (repeats the last)."""

    def __init__(self, responses: list[str] | None = None) -> None:
        self._responses = list(responses or [VALID_TEXT])
        self.calls = 0

    def complete(self, messages: list[dict], *, tools=None, model: str = "stub") -> ChatResponse:  # noqa: ARG002
        idx = min(self.calls, len(self._responses) - 1)
        self.calls += 1
        return ChatResponse(text=self._responses[idx])
