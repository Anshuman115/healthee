"""A withdrawn figure may appear in the corpus only as a withdrawal.

Two numbers have been retracted from this corpus against their primary sources, and both
came back — not in the note that retracted them, but in a note, a table, a summary or a
docstring the retraction did not look at:

* **the SpO2 "±2–3% RMSE"** (#98, 2026-08-01) — the FDA bar for *cleared medical
  oximeters*, mis-attributed to an uncleared wellness wearable. Withdrawn in
  ``wearable_spo2_validity.md``, and still printed in **five** other places in that same
  file on 2026-09-08, including the frontmatter ``summary`` that ships to
  ``research_summaries.json`` and an honesty rule *instructing the coach to state it*.
* **Jurca's "SEE ≈ 5.6"** (#108, 2026-08-02) — a number that appears nowhere in Jurca
  2005, whose published NASA-model SEE is 1.45 METs = **5.075** mL/kg/min. Withdrawn in
  ``non_exercise_vo2max.md``, and still standing in ``submaximal_vo2max.md``'s
  method-comparison table, in ``cadence_derived_speed.md``'s error budget, and in a
  ``derive/vo2max.py`` docstring, 220 lines below the constant that corrects it.

Both errors point the same way — they make an instrument sound **more precise than the
evidence allows**, which is the #108 flattery shape.

``KNOWLEDGE_AUDIT.md`` section 6 asks for exactly this: *"a withdrawn number is worth
pinning by test, the way MEASURED_HORIZON and the bio-age regularity deletion already
are."* A one-off edit fixes the places someone thought to look; this fails the build
wherever the string returns.

**The rule is not "the string must not appear."** It has to appear — a corpus that
silently deleted a retracted figure would lose the correction along with it, and the next
author would reintroduce it in good faith. The rule is that **every occurrence sits on a
line that marks it as withdrawn**. That is what separates the correction from the claim,
and it is checkable.

Scope is deliberately narrow and stated per entry: a bare "5.6" means many things in a
corpus full of effect sizes, so each pattern names the files it governs rather than
sweeping for a digit string and generating noise nobody will read.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

_KNOWLEDGE_ROOT = Path(__file__).resolve().parents[4] / "packages" / "knowledge"
_SERVER_SRC = Path(__file__).resolve().parents[2] / "src" / "healthee"

# Words that mark a line as talking ABOUT a retraction rather than making the claim.
# "Never state" counts: a directive forbidding the figure has to quote it to forbid it.
_WITHDRAWAL = re.compile(
    r"withdrew|withdrawn|retract\w*|corrected|correction|mis-attribut\w*|"
    r"used to|appears nowhere|is nobody's|not a claim anyone|never state|no longer|"
    r"none of those|nobody's SEE",
    re.I,
)


@dataclass(frozen=True)
class Withdrawn:
    """One retracted figure, the pattern that finds it, and where it may be discussed."""

    label: str
    pattern: re.Pattern[str]
    files: tuple[Path, ...]
    replacement: str


_NOTES = _KNOWLEDGE_ROOT / "notes"

_WITHDRAWN_FIGURES: tuple[Withdrawn, ...] = (
    Withdrawn(
        label='SpO2 "±2–3% RMSE" / "sub-2%" precision (#98)',
        pattern=re.compile(r"±\s?2[-–]3\s?%|sub-2\s?%"),
        files=(_NOTES / "metrics" / "wearable_spo2_validity.md",),
        replacement="unquantified and at least ±3.5%",
    ),
    Withdrawn(
        label='Jurca "SEE 5.6" (#108)',
        pattern=re.compile(r"(?<!\d)5\.6(?!\d)"),
        files=(
            _NOTES / "activity" / "non_exercise_vo2max.md",
            _NOTES / "activity" / "submaximal_vo2max.md",
            _NOTES / "activity" / "cadence_derived_speed.md",
            _SERVER_SRC / "derive" / "vo2max.py",
        ),
        replacement="5.075 (1.45 METs x 3.5)",
    ),
)


def _offending_lines(entry: Withdrawn) -> list[str]:
    out: list[str] = []
    for path in entry.files:
        assert path.exists(), f"{path} moved — this check stopped looking at it"
        for number, line in enumerate(path.read_text().splitlines(), start=1):
            if entry.pattern.search(line) and not _WITHDRAWAL.search(line):
                out.append(f"{path.name}:{number}: {line.strip()[:160]}")
    return out


def test_no_withdrawn_figure_is_stated_as_current() -> None:
    """Every occurrence is a withdrawal, or the build fails naming the line."""
    problems: list[str] = []
    for entry in _WITHDRAWN_FIGURES:
        for line in _offending_lines(entry):
            problems.append(f"[{entry.label} — use {entry.replacement}] {line}")
    assert not problems, "a withdrawn figure is stated as current:\n  " + "\n  ".join(problems)


def test_each_withdrawn_figure_is_still_discussed_somewhere() -> None:
    """The correction itself must survive, or this file is guarding an empty set.

    A corpus that deleted every mention would pass the test above trivially, and the next
    author would reintroduce the figure in good faith with nothing to stop them. The
    retraction is the thing worth keeping.
    """
    for entry in _WITHDRAWN_FIGURES:
        found = any(entry.pattern.search(path.read_text()) for path in entry.files)
        assert found, (
            f"{entry.label} is discussed nowhere — the correction was deleted along with "
            "the claim, so nothing now explains why the number is wrong"
        )


def test_the_spo2_summary_that_ships_carries_the_honest_error() -> None:
    """The frontmatter ``summary``, named because of where it goes.

    ``gen_manifest.py`` writes this field into ``manifest.json`` and
    ``research_summaries.json``, and ``retrieval.py`` lists every note that misses the
    top-6 by exactly this string — so a withdrawn figure here is in the prompt on nearly
    every LLM call, not merely available to be read.
    """
    text = (_NOTES / "metrics" / "wearable_spo2_validity.md").read_text()
    summary = next(line for line in text.splitlines() if line.startswith("summary:"))
    assert "±3.5%" in summary, summary
    assert "±2–3%" not in summary, "the withdrawn figure is back in the shipped summary"


def test_the_spo2_honesty_rule_no_longer_instructs_the_coach_to_state_it() -> None:
    """The worst of the five: not a leftover number, an instruction to repeat one.

    ``## Healthee implementation & honesty policy`` is inside ``prompt_body``, so the
    model reads it as a rule about what to say.
    """
    text = (_NOTES / "metrics" / "wearable_spo2_validity.md").read_text()
    rule = next(line for line in text.splitlines() if "Honesty rules (carry into UI" in line)
    assert "unquantified and at least ±3.5%" in rule, rule
    assert _WITHDRAWAL.search(rule), "the ±2–3% mention here must be marked as withdrawn"
