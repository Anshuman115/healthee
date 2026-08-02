"""The coach's message LAYOUT — what each round of the conversation is given.

``coach.py``'s docstring has always said the module contributes exactly two things
``grounded_ask`` cannot: a message layout and a bounded tool loop. They are two
responsibilities and this is the first one, split out when #105 gave the layout a second
shape and the file passed the 400-line gate. The loop owns the SEQUENCE of rounds; this
module owns what a round SAYS.

There are two shapes because the tool loop has two phases (#105, argued in ``coach.py``):

  * :func:`initial_messages` opens the GATHERING rounds — persona, the owner's data, the
    corpus INDEX (one line per note) and :data:`GATHERING_NOTICE`. No note bodies: a
    round that picks a tool cites nothing, and the bodies were 65–83% of its prompt.
  * :func:`evidence_turn` opens the ANSWERING round — the full ranked notes, appended
    once as a trailing user turn.

Retrieval itself is not here and must not be: both blocks come from
``coach_context``, which reaches the corpus through ``pipeline`` like every other
surface (the AST guard in ``tests/insights/test_pipeline_shared.py`` enforces it).
"""

from __future__ import annotations

from typing import Any

from healthee.insights.coach_context import (
    DEFAULT_COACH_DAYS,
    build_coach_context,
    coach_evidence,
    coach_evidence_index,
)
from healthee.insights.coach_prompt import COACH_SYSTEM_PROMPT

HISTORY_LIMIT = 12  # last N conversation turns kept (context-window discipline)

GREETING = "Ask me anything about your sleep, activity, recovery, or logged routines."

# Said once, when the gathering allowance runs out (or the loop stalls) and the tools are
# withdrawn. Without it the model would face a silent, unexplained loss of its tools; with
# it the last round is a real answer attempt instead of a wasted one. It asks for honesty
# about the gap rather than a guess — the validator would refuse the guess anyway, but a
# refused answer the owner never sees is a worse outcome than a plainly stated limit.
ANSWER_NOW = (
    "You have no more tool calls available. Answer the question now using only the data "
    "already in this conversation. If something you wanted is missing, say plainly what "
    "you could not check — do not estimate or invent a number."
)

# Closes the system turn during GATHERING. It says plainly that the notes are not here
# yet, which is the honest description of the prompt the model is holding — and it makes
# the round that ends the phase cheap on OUTPUT too: a model told to write nothing writes
# a word instead of an answer we were always going to throw away. Nothing PARSES the word
# READY; any round that returns text instead of a tool call ends the phase, so a model
# that ignores this instruction costs a little more and behaves identically.
GATHERING_NOTICE = (
    "# THIS IS A DATA-GATHERING ROUND\n"
    "The evidence notes above are listed by title only — their text is not in this "
    "prompt. Do not write the answer in this round and do not cite anything: whatever "
    "you write here is discarded. Call the tools you need (including `get_knowledge` "
    "for a note you want to read early). When you have what you need, reply with the "
    "single word READY — the full text of the relevant notes is then given to you and "
    "you write the answer with it in front of you."
)

# Opens the ANSWERING round, immediately above the full notes. Said once per question.
ANSWER_WITH_EVIDENCE = (
    "The gathering phase is over. Below are the full research notes for this question — "
    "this is the material you cite from, and no further tool calls are available. Write "
    "the answer now. Every number must come from a tool result already in this "
    "conversation; if something you wanted is missing, say plainly what you could not "
    "check rather than estimating it."
)


def initial_messages(
    history: list[dict],
    question: str,
    user_id: Any,
    tz: str,
    context_days: int = DEFAULT_COACH_DAYS,
) -> list[dict]:
    """System (coach prompt + context + the evidence INDEX) followed by the conversation.

    The index, not the notes: the rounds this message opens are gathering rounds, and the
    notes arrive in :func:`evidence_turn` on the round that uses them.
    """
    context = build_coach_context(question, user_id, tz, days=context_days)
    index = coach_evidence_index(question)
    system = (
        f"{COACH_SYSTEM_PROMPT}\n\n# THE USER'S DATA (CONTEXT)\n\n{context}\n\n"
        f"{index}\n\n{GATHERING_NOTICE}"
    )
    return [{"role": "system", "content": system}, *history]


def evidence_turn(question: str) -> dict:
    """The one message carrying the FULL ranked notes — appended before the first answer.

    A trailing user turn rather than a rewritten system turn on purpose: the gathering
    prefix then stays byte-stable across every round (whatever prompt caching a provider
    does keeps working), and the notes land immediately before the instruction to write,
    which is where a model reads most carefully.
    """
    return {"role": "user", "content": f"{ANSWER_WITH_EVIDENCE}\n\n{coach_evidence(question)}"}


def assistant_tool_message(response: Any) -> dict:
    """Rebuild the assistant turn that requested tools (OpenAI tool-call shape)."""
    return {
        "role": "assistant",
        "content": response.text or "",
        "tool_calls": [
            {
                "id": call.id,
                "type": "function",
                "function": {"name": call.function.name, "arguments": call.function.arguments},
            }
            for call in response.tool_calls
        ],
    }


def recent_turns(messages: list[dict]) -> list[dict]:
    """Keep the last N well-formed turns (role+content) — bound the token cost."""
    clean = [
        {"role": m["role"], "content": m["content"]}
        for m in messages
        if m.get("role") in ("user", "assistant") and m.get("content")
    ]
    return clean[-HISTORY_LIMIT:]


def last_user(history: list[dict]) -> str:
    """The most recent user message text, or '' if there is none."""
    return next((m["content"] for m in reversed(history) if m["role"] == "user"), "")
