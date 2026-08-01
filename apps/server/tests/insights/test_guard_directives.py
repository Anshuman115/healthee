"""The corpus-declared guardrails — and the contract that keeps the claim honest (#87).

Roughly two dozen notes used to assert *"mirrored as a hard guardrail; the AI may not
override this"*. It was false: ``output_guard`` was hand-compiled and read nothing from
the corpus, and no note carried a marker. The repair is not a rewording, it is this
file: the corpus declares which directives are hard, the code compiles a rule per
declaration, and the two are asserted equal **in both directions** so neither side can
drift into a lie.

The second half of the file pins the false-positive boundary as hard as the true
positives, because these three notes exist largely to DISCUSS the things the rules
forbid PRESCRIBING — the napping dose curve, the "8 glasses" correction, the "stop
eating three hours before bed" rule. A guardrail that ate those would be its own harm.
"""

from __future__ import annotations

import pytest

from healthee.insights import guard_directives, manifest, output_guard

# ── 1 · the bijection: a claim in the corpus ⇔ a rule in the code ────────────


def _declared_markers() -> set[tuple[str, int]]:
    """Every ``(note_id, directive)`` the manifest publishes as safety-critical."""
    return {(n.id, d) for n in manifest.all_notes() for d in n.safety_critical}


def test_every_corpus_safety_claim_compiles_a_real_guardrail() -> None:
    """A note may not claim a hard guardrail nobody wrote — that was the whole bug."""
    unbacked = _declared_markers() - set(guard_directives.origins())
    assert not unbacked, (
        "these notes declare a directive `safety_critical` but no rule compiles from "
        f"it, so the note's 'hard guardrail' sentence is false: {sorted(unbacked)}"
    )


def test_every_compiled_guardrail_still_has_a_live_origin_directive() -> None:
    """The dead-provenance half: a rule whose origin was edited away must fail loudly.

    #81 found ten citations in COACHING-RULES.md pointing at a file that did not exist,
    three of them behind SAFETY-CRITICAL rules. Provenance rots silently unless
    something checks it, so this is the check.
    """
    orphaned = set(guard_directives.origins()) - _declared_markers()
    assert not orphaned, (
        "these rules compile from a directive the corpus no longer marks "
        f"safety-critical — the origin rotted: {sorted(orphaned)}"
    )


def test_the_markers_are_not_vacuously_satisfied() -> None:
    """Two empty sets are equal. Prove the contract is actually carrying something."""
    assert len(_declared_markers()) >= 4
    assert len(guard_directives.compiled_rules()) == len(guard_directives.origins())


def test_each_compiled_rule_quotes_the_directive_it_mirrors() -> None:
    """``source`` is the admission criterion, not decoration (Engineering Standards §4)."""
    for (note_id, number), rule in zip(
        guard_directives.origins(), guard_directives.compiled_rules(), strict=True
    ):
        assert note_id in rule.source, f"{rule.name} does not name its note"
        assert f"Directive {number}" in rule.source, f"{rule.name} does not name its directive"
        assert "SAFETY-CRITICAL" in rule.source


def test_the_compiled_rules_reach_the_live_guard() -> None:
    """A table nothing calls guards nothing."""
    live = {r.name for r in output_guard.output_rules()}
    assert {r.name for r in guard_directives.compiled_rules()} <= live


# ── 2 · true positives: each compiled rule blocks its forbidden move ─────────

_FORBIDDEN: list[tuple[str, str]] = [
    (
        "napping_D5_hypersomnolence_to_clinician",
        "You mentioned a new, uncontrollable need to nap most afternoons — that's "
        "completely normal when sleep has been short.",
    ),
    (
        "napping_D5_hypersomnolence_to_clinician",
        "Nodding off at your desk is just sleep debt catching up with you.",
    ),
    (
        "napping_D5_hypersomnolence_to_clinician",
        "Since you keep falling asleep unintentionally, try a 20 min nap after lunch.",
    ),
    (
        "hydration_everyday_D5_no_exercise_fluid_target",
        "On a long run in this heat, drink 500 ml per hour to stay ahead of losses.",
    ),
    (
        "hydration_everyday_D5_no_exercise_fluid_target",
        "For your marathon, sip every 15 minutes and aim for 750 ml an hour.",
    ),
    (
        "hydration_everyday_D6_no_advice_when_fluid_sensitive",
        "Given your kidney disease you should drink more water through the day.",
    ),
    (
        "hydration_everyday_D6_no_advice_when_fluid_sensitive",
        "Since you're on a diuretic, aim for 2 litres a day.",
    ),
    (
        "late_eating_sleep_D5_no_eating_restriction",
        "You should stop eating after 8pm to protect your sleep.",
    ),
    (
        "late_eating_sleep_D5_no_eating_restriction",
        "Try a 16:8 fasting protocol and see whether your sleep improves.",
    ),
    (
        "late_eating_sleep_D5_no_eating_restriction",
        "Don't eat after 9pm on training days.",
    ),
    (
        "late_eating_sleep_D5_no_eating_restriction",
        "Never eat within three hours of bed.",
    ),
]


@pytest.mark.parametrize(("expected", "text"), _FORBIDDEN)
def test_a_forbidden_answer_is_blocked(expected: str, text: str) -> None:
    rule = output_guard.check_output(text)
    assert rule is not None, f"not blocked: {text!r}"
    assert rule.name == expected, f"blocked by {rule.name}, expected {expected}: {text!r}"


def test_a_blocked_answer_never_ships_its_text() -> None:
    """The response the caller returns is the rule's, not the model's."""
    rule = output_guard.check_output("You should stop eating after 8pm.")
    assert rule is not None
    assert "eating cutoff" in rule.response
    assert "8pm" not in rule.response


# ── 3 · false positives: the notes' own substance must stay shippable ────────

_ALLOWED: list[str] = [
    # napping: the dose curve is the note's main answer and must survive.
    "A 10-20 minute nap restores alertness for about two hours [napping].",
    "If you want a nap, keep it to about 20 minutes to avoid sleep inertia.",
    "Naps of 30 minutes or more bring grogginess first [napping].",
    # napping: naming the rule rather than reassuring past it.
    "A new or worsening need to nap is not something I can explain — that belongs "
    "with a clinician.",
    # hydration: the "8 glasses" correction and the reference values.
    "There is no evidence-based universal daily water target for a healthy adult "
    "[hydration_everyday].",
    "EFSA's reference values are 2.5 L/day for men and 2.0 L/day for women, and those "
    "are total water including the water in food [hydration_everyday].",
    "A systematic search found no scientific studies in support of 8x8 [hydration_everyday].",
    # hydration: describing the hyponatraemia risk is the point, not a violation.
    "Drinking to a fixed schedule during a marathon is how exercise-associated "
    "hyponatraemia happens [fueling_and_hydration].",
    # hydration D6: naming the refusal is not giving advice.
    "Because you've mentioned a diuretic, I won't give you any fluid-intake advice — "
    "that belongs with your clinician.",
    # late eating: the note's entire job is to present this rule as unsettled.
    "The popular rule is to stop eating three hours before bed, and it is not settled "
    "science [late_eating_sleep].",
    "Observational studies mostly find late eating associated with worse sleep, while "
    "the controlled experiment that moved dinner to 1 h before bed did not "
    "[late_eating_sleep].",
    "We hold no dietary data at all, so I can't tell you when you ate.",
]


@pytest.mark.parametrize("text", _ALLOWED)
def test_an_honest_answer_is_not_blocked(text: str) -> None:
    rule = output_guard.check_output(text)
    assert rule is None, f"over-broad: {text!r} was blocked by {rule and rule.name}"


def test_the_documented_rules_are_untouched_by_the_new_table() -> None:
    """Adding the corpus half must not widen a rule that was already in force."""
    assert output_guard.check_output("Cutting your sleep to fit the session in") is None
    assert output_guard.check_output("You could cut your sleep to fit the session in")
