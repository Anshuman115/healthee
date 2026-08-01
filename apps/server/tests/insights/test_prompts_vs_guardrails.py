"""#99 · a surface may not ASK for what a hard output guardrail forbids.

``output_guard`` blocks a personal death-risk number or life-expectancy projection
regardless of citations or validation — it is a safety floor, not a quality rule. So a
prompt that requests one is not a safety problem, it is a *waste* problem: the surface
pays for a full-context generation, its retry, and ships the honest fallback every time
the model complies. ``_ACTIVITY_PROMPT`` asked for "what the gap means for healthspan"
and the guardrail fired on 2 of 3 of its generations in a paid eval arm.

The rule this file enforces is one-directional and mechanical: a shipped prompt may
mention mortality/life-expectancy vocabulary only to FORBID it. That leaves the honest
population science reachable (the corpus is full of mortality notes and the guard lets
their population claims through) while making "and tell me what it means for my
healthspan" fail a test instead of a generation.
"""

from __future__ import annotations

import re

from healthee.insights import coaching, prompts, surfaces

# The vocabulary the guardrail's `personal_death_risk_number` / life-projection rules key
# on. A prompt using any of it is asking the model to walk toward a blocked output.
_RISK_WORDS = re.compile(
    r"\bhealthspan\b|\bmortality\b|\blife expectancy\b|\brisk of (?:dying|death)\b|"
    r"\byears? (?:off|of) (?:your |my )?life\b|\bdeath risk\b",
    re.IGNORECASE,
)
# What makes such a mention legitimate: the clause it sits in tells the model NOT to.
_PROHIBITION = re.compile(r"\bnever\b|\bdo not\b|\bdon't\b|\bno\b|\bwithout\b", re.IGNORECASE)

# Every prompt the product actually sends on a non-conversational surface, taken from the
# modules that send them so a new one cannot be added without appearing here.
SHIPPED_PROMPTS: dict[str, str] = {
    "sleep_insight": surfaces._SLEEP_PROMPT,
    "activity_insight": surfaces._ACTIVITY_PROMPT,
    "daily_action": coaching._DAILY_ACTION_PROMPT,
    "sleep_tonight": coaching._SLEEP_TONIGHT_PROMPT,
    "system": prompts.SYSTEM_PROMPT,
}


def _clauses(text: str) -> list[str]:
    """Split on the punctuation that separates one instruction from the next."""
    return [c for c in re.split(r"[.;\n]", text) if c.strip()]


def test_no_shipped_prompt_asks_for_a_personal_risk_projection() -> None:
    offenders = [
        (name, clause.strip())
        for name, prompt in SHIPPED_PROMPTS.items()
        for clause in _clauses(prompt)
        if _RISK_WORDS.search(clause) and not _PROHIBITION.search(clause)
    ]
    assert offenders == [], (
        "a shipped prompt asks for output the hard guardrail blocks — the answer is paid "
        f"for and never ships: {offenders}"
    )


def test_the_activity_prompt_no_longer_asks_what_the_gap_means_for_healthspan() -> None:
    """The exact ask that was measured tripping the guardrail."""
    assert "healthspan" not in surfaces._ACTIVITY_PROMPT
    assert "life-expectancy number" in surfaces._ACTIVITY_PROMPT


def test_the_system_prompt_states_the_guardrail_the_code_enforces() -> None:
    """The guard existed; the model was never told about it — so it kept walking into it."""
    assert _RISK_WORDS.search(prompts.SYSTEM_PROMPT)
    assert "NEVER attach a risk-of-death" in prompts.SYSTEM_PROMPT
