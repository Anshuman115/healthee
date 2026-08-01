"""A scriptable offline LLM stub for the coach control-flow tests.

Unlike ``_stub.StubLLM`` (text-only), this one can emit OpenAI-shaped tool calls,
so a test can script "call query_metric, then answer" without any network. It also
records the ``tools`` passed on each call (to assert tools were/weren't offered), the
``messages`` each call was asked with (to assert what the loop put in the prompt), and
counts calls (to prove a refusal never reaches the model).
"""

from __future__ import annotations

from dataclasses import dataclass, field

from healthee.insights.client import ChatResponse


@dataclass
class StubFunction:
    name: str
    arguments: str


@dataclass
class StubToolCall:
    id: str
    function: StubFunction
    type: str = "function"


def tool_call(call_id: str, name: str, arguments: str) -> StubToolCall:
    return StubToolCall(id=call_id, function=StubFunction(name=name, arguments=arguments))


def text_turn(text: str) -> ChatResponse:
    return ChatResponse(text=text)


def tool_turn(*calls: StubToolCall) -> ChatResponse:
    return ChatResponse(text="", tool_calls=list(calls))


@dataclass
class CoachStub:
    """Returns each scripted ChatResponse in turn (repeats the last one)."""

    script: list[ChatResponse]
    calls: int = 0
    tools_seen: list = field(default_factory=list)
    messages_seen: list[list[dict]] = field(default_factory=list)

    def complete(  # noqa: ARG002
        self, messages: list[dict], *, tools=None, model: str | None = None, response_format=None
    ) -> ChatResponse:
        self.tools_seen.append(tools)
        self.messages_seen.append(list(messages))
        response = self.script[min(self.calls, len(self.script) - 1)]
        self.calls += 1
        return response


class NoCallStub:
    """Fails if the model is ever called — proves a refusal short-circuits pre-LLM."""

    calls = 0

    def complete(  # noqa: ARG002
        self, messages: list[dict], *, tools=None, model: str | None = None, response_format=None
    ) -> ChatResponse:
        raise AssertionError("the LLM must not be called for a refused question")
