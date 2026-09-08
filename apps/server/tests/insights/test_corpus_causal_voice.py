"""An observational finding does not say "causes" in the sentences that ship.

``packages/knowledge/notes/conventions.md:62`` is binding and unambiguous: *"If a
finding is from observational data only, do not say 'causes.'"* The 2026-09-08 audit
found four notes breaking it — `strength_training_mortality`, `sedentary_mortality`,
`exercise_mortality` and `sleep_consistency` — each with evidence bullets that say
"associated with" and an Honesty section opening "Observational", and each with a causal
verb in exactly the two places that leave the note:

* the frontmatter ``topic`` / ``summary``, which ``gen_manifest.py`` writes into
  ``manifest.json`` and ``research_summaries.json``, and which ``retrieval.py:234`` puts
  in the prompt for every note outside the top-6; and
* the **"Act on confidently"** line, which is what tells the model it may state a claim
  plainly. All four are ``Established`` (rank 3) and above ``MIN_ACTIONABLE_RANK``, so
  those sentences may drive a daily recommendation.

**The standard is demonstrably achievable in this corpus**, which is what makes this a
defect and not house style: ``steps_mortality`` says "track progressively lower",
``resting-heart-rate`` says "tracks", ``sauna_cv_benefits`` says "associated with" in its
summary too, and ``sleep_duration_mortality`` goes further — "marker, **not a cause**".

## The scope, stated honestly

This checks the **shipping** surfaces only: `topic`, `summary`, and the "Act on
confidently" line. Body prose is deliberately out of scope, because a note's job includes
DISCUSSING causality — the mechanism sections say "the plausible route by which", the
Honesty sections say "causality (all observational)", and a sweep that flagged those
would be an over-broad filter eating the corpus's own care. Restricting to the three
surfaces is what keeps the check precise enough that a failure is always a real defect.

Notes that genuinely rest on interventional evidence are exempted by name below, with
the reason, rather than by loosening the pattern.
"""

from __future__ import annotations

import re
from pathlib import Path

_KNOWLEDGE_ROOT = Path(__file__).resolve().parents[4] / "packages" / "knowledge"

# Causal VERBS only — the inflected forms, never the bare comparative adjective.
# "lower mortality" is the corpus's own correct phrasing and must pass; "lowers
# mortality" is the claim `conventions.md` forbids. That one letter is the whole
# distinction, and getting it wrong in the first draft of this file flagged
# `steps_mortality` — the note the docstring holds up as the reference.
_CAUSAL = re.compile(
    # NOT a bare "cause": `-` is a word boundary, so `\bcause\b` matches inside
    # "all-cause mortality" and flags every mortality note in the corpus. The verb
    # forms are what the rule is about.
    r"\b(?:causes|caused|causing|lowers|lowered|lowering|raises|raised|raising|"
    r"reduces|reduced|reducing|cuts|increases|increased|increasing|decreases|"
    r"decreased|elevates|elevated|improves|improved|worsens|worsened|prevents|"
    r"protects\s+against)\b",
    re.I,
)

# The verb only matters when its object is a health outcome. Without this a note
# saying the illness flag "raises a moderate flag" trips a rule about epidemiology.
_OUTCOME = re.compile(
    r"\bmortality|\brisk\b|\bdisease|\blongevity|\bblood\s+pressure|\bglucose|"
    r"\bcardiovascular|\bcardiometabolic|\bhealth\b|\bHRV\b|\bdeath",
    re.I,
)

# A note may say a causal thing about itself when it is DENYING one, or when it is
# naming the limitation. Those are the sentences we want more of, not fewer.
_DISCLAIMED = re.compile(
    r"\bnot\s+a\s+cause\b|observational|associat\w+|correlat\w+|"
    # Discussing reverse causation is the corpus at its most careful, not its
    # least: `napping_chronic_health` names it as the central unresolved confound.
    r"reverse\s+causation|causal[\s-]inference|confound\w*",
    re.I,
)

# Interventional evidence exists for these, so a causal verb is earned. Each is listed
# with its warrant; adding one without a warrant is the thing this list must not become.
_INTERVENTIONAL: dict[str, str] = {
    # RCTs of caffeine timing vs polysomnography (Drake 2013 and successors).
    "caffeine_sleep": "randomised crossover trials",
    # Alcohol dosing studies with within-subject wearable and PSG outcomes.
    "alcohol_sleep": "within-subject dosing experiments",
    # Light exposure is manipulated experimentally in circadian-phase studies.
    "morning_light_circadian": "phase-shifting light experiments",
    # Paced-breathing protocols are administered; the HRV response is the measured
    # outcome of the manipulation, within-subject.
    "slow_breathing_hrv_acute": "administered paced-breathing protocols",
}


def _citable_notes() -> list[Path]:
    return sorted(
        p
        for p in (_KNOWLEDGE_ROOT / "notes").rglob("*.md")
        if p.parent.name != "protocol" and p.name != "conventions.md"
    )


def _shipping_lines(text: str) -> list[str]:
    """The three surfaces a note's claims leave it by."""
    lines = text.splitlines()
    out = [ln for ln in lines if ln.startswith(("topic:", "summary:"))]
    for i, line in enumerate(lines):
        if "Act on confidently" not in line:
            continue
        # The claim can run over several wrapped lines up to the next blank one.
        j = i
        while j < len(lines) and lines[j].strip():
            out.append(lines[j])
            j += 1
    return out


def test_no_observational_note_ships_a_causal_verb() -> None:
    """`conventions.md:62`, enforced on the surfaces that leave the note."""
    offenders: list[str] = []
    for path in _citable_notes():
        text = path.read_text()
        note_id = next(
            (ln.split(":", 1)[1].strip() for ln in text.splitlines() if ln.startswith("id:")),
            path.stem,
        )
        if note_id in _INTERVENTIONAL:
            continue
        for line in _shipping_lines(text):
            if not _OUTCOME.search(line):
                continue
            if _CAUSAL.search(line) and not _DISCLAIMED.search(line):
                offenders.append(f"{path.relative_to(_KNOWLEDGE_ROOT)}: {line.strip()[:150]}")
    assert not offenders, (
        "an observational claim ships in causal voice — use 'associated with', 'tracks "
        "with' or 'predicts', as steps_mortality and resting-heart-rate already do:\n  "
        + "\n  ".join(offenders)
    )


def test_the_four_audited_notes_still_say_it_the_corpus_way() -> None:
    """Named individually, because the sweep above can only see the shape.

    A note could satisfy the sweep by deleting its "Act on confidently" line, which
    would lose the claim rather than fix its voice. These assert the claim survives.
    """
    expected = {
        "notes/activity/strength_training_mortality.md": "associated with lower mortality",
        "notes/activity/sedentary_mortality.md": "tracks with higher mortality",
        "notes/activity/exercise_mortality.md": "associated with",
        "notes/sleep/sleep_consistency.md": "timing consistency matters",
    }
    for rel, phrase in expected.items():
        text = (_KNOWLEDGE_ROOT / rel).read_text()
        assert "Act on confidently" in text, f"{rel} lost its Act-on-confidently line"
        assert phrase in text, f"{rel} no longer states the claim as '{phrase}'"


def test_the_exemptions_are_few_and_warranted() -> None:
    """A list that can quietly absorb every failure is not a check.

    Three notes, each naming the interventional evidence that earns the verb. If this
    grows, the growth is the thing to review — not the assertion.
    """
    assert len(_INTERVENTIONAL) <= 5, _INTERVENTIONAL
    assert all(reason for reason in _INTERVENTIONAL.values())
