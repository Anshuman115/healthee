"""The shipped coach system prompt is docs/COACH_PROMPT.md's SYSTEM PROMPT verbatim.

Re-extracts the SYSTEM PROMPT section from the markdown and asserts byte-for-byte
equality with the constant the coach ships — so paraphrasing or drift fails CI (the
prompt is where the "never lies" contract becomes behaviour; it is the lead's text).

It also pins the prompt's TOOL list against ``COACH_TOOLS``. That is not tidiness: for
the whole of WP5b→WP-C5 the persona told the coach it had an ``adopt_challenge`` tool
that was not in ``COACH_TOOLS`` at all. A prompt promising a capability the loop cannot
offer is an anti-hallucination hazard by construction — the model is invited to say it
did something there is no way for it to have done.
"""

from __future__ import annotations

import re
from pathlib import Path

from healthee.insights.coach_prompt import COACH_SYSTEM_PROMPT
from healthee.insights.coach_tools import COACH_TOOLS

_DOC = Path(__file__).resolve().parents[4] / "docs" / "COACH_PROMPT.md"
_MARKER = "## SYSTEM PROMPT (verbatim)\n"
_TOOLS_HEADING = "### Tools (use them; never fake them)\n"
_BACKTICKED = re.compile(r"`([a-z][a-z0-9_]+)`")


def _section_from_doc() -> str:
    text = _DOC.read_text(encoding="utf-8")
    return text[text.index(_MARKER) + len(_MARKER) :].lstrip("\n")


def _tools_named_in_prompt() -> set[str]:
    """Every backticked identifier under the prompt's Tools heading."""
    tail = COACH_SYSTEM_PROMPT[COACH_SYSTEM_PROMPT.index(_TOOLS_HEADING) + len(_TOOLS_HEADING) :]
    section = tail[: tail.index("\n### ")]
    return set(_BACKTICKED.findall(section))


def test_the_prompt_names_exactly_the_live_tools() -> None:
    assert _tools_named_in_prompt() == {t["function"]["name"] for t in COACH_TOOLS}


def test_prompt_is_byte_identical_to_the_doc() -> None:
    assert _section_from_doc() == COACH_SYSTEM_PROMPT


def test_prompt_boundaries() -> None:
    assert COACH_SYSTEM_PROMPT.startswith("You are the Healthee coach.")
    assert COACH_SYSTEM_PROMPT.rstrip("\n").endswith("Lead with what matters.")
