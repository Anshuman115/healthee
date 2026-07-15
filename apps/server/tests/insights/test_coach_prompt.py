"""The shipped coach system prompt is docs/COACH_PROMPT.md's SYSTEM PROMPT verbatim.

Re-extracts the SYSTEM PROMPT section from the markdown and asserts byte-for-byte
equality with the constant the coach ships — so paraphrasing or drift fails CI (the
prompt is where the "never lies" contract becomes behaviour; it is the lead's text).
"""

from __future__ import annotations

from pathlib import Path

from healthee.insights.coach_prompt import COACH_SYSTEM_PROMPT

_DOC = Path(__file__).resolve().parents[4] / "docs" / "COACH_PROMPT.md"
_MARKER = "## SYSTEM PROMPT (verbatim)\n"


def _section_from_doc() -> str:
    text = _DOC.read_text(encoding="utf-8")
    return text[text.index(_MARKER) + len(_MARKER) :].lstrip("\n")


def test_prompt_is_byte_identical_to_the_doc() -> None:
    assert _section_from_doc() == COACH_SYSTEM_PROMPT


def test_prompt_boundaries() -> None:
    assert COACH_SYSTEM_PROMPT.startswith("You are the Healthee coach.")
    assert COACH_SYSTEM_PROMPT.rstrip("\n").endswith("Lead with what matters.")
