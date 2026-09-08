"""No note may claim a Coach Directive is enforced in code unless it declared it.

Engineering Standards section 4 is explicit: *"A note may no longer make that claim in
prose at all — it declares the marker or it says plainly that the rule is not enforced
in code."* #87 built the machinery for the first half — `gen_manifest.py` validates a
`safety_critical` marker against its directive's own text, `guard_directives.py`
compiles one rule per marker, and `test_guard_directives.py` bijects the two sets.

What nobody checked was the **second** half: a directive that asserts enforcement in
prose while declaring no marker. The 2026-09-08 knowledge audit found two, and they were
the worst-placed instances possible — `environmental-stress` D14 and
`fueling-and-hydration` D8 both said *"never advise drinking ahead of thirst … enforced
in code"*, when every branch of the compiled rule requires a NUMBER and the pattern does
not contain the word *thirst*. A false safety claim inside the safety system is the one
the standards single out, because an auditor reads it and stops looking.

This is a **derived** check, not a list of the two known bad lines: it walks every
directive in the corpus and holds each enforcement claim to the same rule. A list cannot
cover what nobody thought to add (`HOW_WE_VERIFY.md` section 4), and this class survived
three prior passes precisely because each one only looked where the last defect was.

The rule, stated once:

    A directive line that claims enforcement **without qualifying it** must NAME the
    live rule it rests on, by the rule's own `name`, and that name must be in
    `output_guard.output_rules()`. Failing that, its own note must declare the marker.

    A directive whose enforcement is partial, or absent, says so in words. "PARTLY",
    "not enforced", "only the X limb is enforced" and "no code behind" are the
    qualifications this accepts, and each one is then expected to state what is and is
    not caught — prose a test cannot grade, which is why the qualified branch is
    trusted rather than parsed further.

Naming the rule is the discriminating requirement, and cross-note claims are legitimate
under it: `fueling-and-hydration` D12 and `injury-prevention` D8/D9 both rest on a rule
compiled elsewhere and both name it, which is how a reader can go and read the pattern.

**What this cannot check, said plainly.** It cannot read a compiled pattern and decide
whether it forbids the move the directive forbids. That is exactly how B2 got in — D14
and D8 named a rule that really does compile, and its forbidden move was the wrong one.
The guard for THAT class is the scope table in `test_guard_directives.py`, which pins
what `hydration_everyday` D5 does and does not catch, sentence by sentence. This file
catches the coarser and more common failure: a guardrail nobody wrote.
"""

from __future__ import annotations

import re
from pathlib import Path

from healthee.insights import output_guard

_KNOWLEDGE_ROOT = Path(__file__).resolve().parents[4] / "packages" / "knowledge"

# `- **D14:** …` — the corpus's one directive-line shape in the sports-science
# collection, and the only place an enforcement claim has ever been written.
_DIRECTIVE_LINE = re.compile(r"^\s*[-*]\s+\*\*D(\d+)\b", re.MULTILINE)

# `safety_critical: [5, 6]` in frontmatter.
_MARKER = re.compile(r"^safety_critical:\s*\[([^\]]*)\]", re.MULTILINE)

# The claim itself, in every spelling the corpus uses.
_CLAIMS_ENFORCEMENT = re.compile(r"enforced\s+in\s+code|compiled\s+into\s+a\s+rule", re.I)

# An honest qualification. Each of these commits the line to saying what the compiled
# rule does and does not recognise; none of them can be written by accident.
# `recovery_readiness` D7 is the reference for the third form — three limbs, one of them
# enforced in `derive/`, and it names which two are not.
_QUALIFIED = re.compile(
    r"\bPARTLY\b|not\s+enforced|no\s+code\s+behind|\bOnly\b[^.]{0,90}\benforced\b",
    re.I,
)


def _corpus_notes() -> list[Path]:
    return sorted(
        p
        for p in _KNOWLEDGE_ROOT.rglob("*.md")
        if "tools" not in p.parts and p.parent.name != "protocol"
    )


def _markers(text: str) -> set[int]:
    m = _MARKER.search(text)
    if not m:
        return set()
    return {int(n) for n in re.findall(r"\d+", m.group(1))}


def _directive_blocks(text: str) -> list[tuple[int, str]]:
    """Each ``(directive_number, its full text)`` — the line and its continuations."""
    starts = list(_DIRECTIVE_LINE.finditer(text))
    blocks: list[tuple[int, str]] = []
    for i, match in enumerate(starts):
        end = starts[i + 1].start() if i + 1 < len(starts) else len(text)
        blocks.append((int(match.group(1)), text[match.start() : end]))
    return blocks


def test_no_directive_claims_an_enforcement_it_did_not_declare() -> None:
    """The rule above, over every note in the corpus.

    A failure names the file, the directive and the two ways out: declare the marker
    (which compiles a real rule and is bijected by `test_guard_directives.py`), or say
    plainly what the rule does not catch.
    """
    live = {rule.name for rule in output_guard.output_rules()}
    assert live, "no output rules at all — this test would then pass vacuously"
    offenders: list[str] = []
    for path in _corpus_notes():
        text = path.read_text()
        marked = _markers(text)
        for number, block in _directive_blocks(text):
            if not _CLAIMS_ENFORCEMENT.search(block):
                continue
            if _QUALIFIED.search(block):
                continue
            if any(name in block for name in live):
                continue
            if number in marked:
                continue
            rel = path.relative_to(_KNOWLEDGE_ROOT)
            offenders.append(
                f"{rel} D{number}: claims enforcement, names no live rule, "
                f"and this note declares markers {sorted(marked)}"
            )
    assert not offenders, (
        "a note claims a guardrail nobody compiled for it — name the rule, declare the "
        "marker, or say what is not enforced:\n  " + "\n  ".join(offenders)
    )


def test_the_check_is_not_vacuous() -> None:
    """There ARE enforcement claims in the corpus, so the sweep above found something.

    Without this the test passes just as happily on a corpus where the phrase was
    globally deleted — which is the shape of every guard that quietly stopped guarding.
    """
    claiming = [
        path.relative_to(_KNOWLEDGE_ROOT)
        for path in _corpus_notes()
        for _number, block in _directive_blocks(path.read_text())
        if _CLAIMS_ENFORCEMENT.search(block)
    ]
    assert len(claiming) >= 3, (
        f"only {len(claiming)} enforcement claims found — is the directive shape still "
        "`- **Dn:**`? If it changed, this whole file stopped looking."
    )


def test_the_two_audited_directives_say_what_the_rule_misses() -> None:
    """`environmental-stress` D14 and `fueling-and-hydration` D8, named individually.

    The derived sweep above would pass on a line that merely said "not enforced" and
    stopped. These two lines are the ones the audit read both ends of, and what makes
    them honest is the *specific* thing they now admit: the compiled rule wants a number
    and does not know the word "thirst". A reviewer who trips this should read why.
    """
    env = (_KNOWLEDGE_ROOT / "sports-science/wellness/environmental-stress.md").read_text()
    fuel = (_KNOWLEDGE_ROOT / "sports-science/wellness/fueling-and-hydration.md").read_text()
    for name, text in (("environmental-stress D14", env), ("fueling-and-hydration D8", fuel)):
        blocks = {n: b for n, b in _directive_blocks(text)}
        block = blocks[14] if "environmental" in name else blocks[8]
        assert "PARTLY" in block, f"{name} claims unqualified enforcement again"
        assert "thirst" in block.lower(), f"{name} no longer names the move that is not caught"
        assert re.search(r"volume|rate|numeric", block, re.I), (
            f"{name} does not say what the compiled rule DOES catch"
        )
