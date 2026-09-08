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
    # environmental_stress D12 — the four deflection shapes, one case each.
    (
        "environmental_stress_D12_exertional_red_flags_to_urgent_care",
        "You were confused and vomiting after that hot long run — that's completely "
        "normal when you push in this weather.",
    ),
    (
        "environmental_stress_D12_exertional_red_flags_to_urgent_care",
        "Getting disoriented at the end of a race is just dehydration.",
    ),
    (
        "environmental_stress_D12_exertional_red_flags_to_urgent_care",
        "Since it was only a seizure right at the finish, you can still run Sunday.",
    ),
    (
        "environmental_stress_D12_exertional_red_flags_to_urgent_care",
        "You collapsed at the end of the run, but you'll be fine after a rest.",
    ),
    (
        "environmental_stress_D12_exertional_red_flags_to_urgent_care",
        "A worsening headache at altitude is nothing to worry about.",
    ),
    (
        "environmental_stress_D12_exertional_red_flags_to_urgent_care",
        "That sounds like heat exhaustion, so just sip something and keep going.",
    ),
]


@pytest.mark.parametrize(("expected", "text"), _FORBIDDEN)
def test_a_forbidden_answer_is_blocked(expected: str, text: str) -> None:
    rule = output_guard.check_output(text)
    assert rule is not None, f"not blocked: {text!r}"
    assert rule.name == expected, f"blocked by {rule.name}, expected {expected}: {text!r}"


# Each red flag in environmental_stress D12's symptom set, one sentence each, with the
# SAME deflection so only the subject varies. Written this way because a mutation test
# found the opposite: the first draft's cases stacked several symptoms per sentence, so
# deleting a whole alternative from the pattern changed nothing and the suite stayed
# green. A rule is only pinned to the extent each alternative is the sole reason a case
# fires — an assertion that passes for a reason other than the one it names is not a test.
_D12_RED_FLAGS: list[str] = [
    "You had heat stroke at the end of it",
    "That looks like heat exhaustion",
    "It sounds like hyponatraemia",
    "HACE explains it",
    "That's altitude sickness",
    "You had a seizure at the finish",
    "You were staggering by the end",
    "There was altered consciousness afterwards",
    "You were confused for a while afterwards",
    "You got disoriented near the end",
    "You were vomiting afterwards",
    "You collapsed at the end of the run",
    "You stopped sweating out there",
    "You had a severe headache during it",
]


@pytest.mark.parametrize("symptom", _D12_RED_FLAGS)
def test_each_exertional_red_flag_is_recognised_on_its_own(symptom: str) -> None:
    """Every alternative in the D12 subject set carries a case alone (mutation-pinned)."""
    rule = output_guard.check_output(f"{symptom}, but that's completely normal.")
    assert rule is not None, f"red flag not recognised: {symptom!r}"
    assert rule.name == "environmental_stress_D12_exertional_red_flags_to_urgent_care"


_D12_DEFLECTIONS: list[str] = [
    "that's completely normal",
    "there's nothing to worry about",
    "it was just dehydration",
    "you can push through it next time",
    "keep training as planned",
    "it's fine to race on Sunday",
    "you'll be fine",
    "just rest",
    "walk it off",
]


@pytest.mark.parametrize("deflection", _D12_DEFLECTIONS)
def test_each_d12_deflection_shape_is_blocked(deflection: str) -> None:
    """Same for the action half: one case per forbidden move, subject held constant."""
    rule = output_guard.check_output(f"You collapsed after the race, but {deflection}.")
    assert rule is not None, f"deflection not blocked: {deflection!r}"
    assert rule.name == "environmental_stress_D12_exertional_red_flags_to_urgent_care"


def test_a_blocked_answer_never_ships_its_text() -> None:
    """The response the caller returns is the rule's, not the model's."""
    rule = output_guard.check_output("You should stop eating after 8pm.")
    assert rule is not None
    assert "eating cutoff" in rule.response
    assert "8pm" not in rule.response


# ── 2b · the exact SCOPE of hydration D5, pinned in both directions ──────────
#
# Two other notes — `environmental-stress` D14 and `fueling-and-hydration` D8 — used to
# claim this rule enforced their *"never advise drinking ahead of thirst"*. It does not:
# every branch of `_FLUID_TARGET_RE` requires a NUMBER, and the pattern does not contain
# the word "thirst". Both directive lines were corrected on 2026-09-08 to say what is
# and is not caught. These two tables are what makes those corrected lines checkable:
# widening the rule to catch a stance, or narrowing it below a numeric target, breaks a
# test here and sends the author back to the two notes that describe it.
#
# The direction that must NOT be quietly fixed by widening the regex: the corpus's own
# job includes *correcting* the phrase — `fueling-and-hydration.md:165` grades "you must
# drink ahead of thirst" **[Myth]** — so a pattern broad enough to catch the prescription
# would also eat the refutation. That is the over-broad-filter harm this module's
# docstring names, and it is why the notes moved rather than the rule.
_D5_NOT_CAUGHT: list[str] = [
    "In the heat, stay ahead of your thirst — don't wait until you feel thirsty to drink.",
    "When running in hot weather, drink before you get thirsty.",
    "Keep drinking steadily through the hot run rather than waiting for thirst.",
]

_D5_CAUGHT: list[str] = [
    "During your hot run, drink 500 ml every hour.",
    "Sip 250 ml every 20 minutes while training in the heat.",
]


@pytest.mark.parametrize("text", _D5_NOT_CAUGHT)
def test_hydration_d5_does_not_catch_an_ahead_of_thirst_stance(text: str) -> None:
    """A stance with no number passes — which is exactly what the two notes now say."""
    assert "thirst" not in guard_directives._FLUID_TARGET_RE.pattern
    assert output_guard.check_output(text) is None, (
        "the rule now catches a stance: `environmental-stress` D14 and "
        "`fueling-and-hydration` D8 describe its scope and must be updated with it"
    )


@pytest.mark.parametrize("text", _D5_CAUGHT)
def test_hydration_d5_catches_a_numeric_volume_or_rate(text: str) -> None:
    """The half that IS deterministic. Losing this makes both notes overclaim again."""
    rule = output_guard.check_output(text)
    assert rule is not None, f"not blocked: {text!r}"
    assert rule.name == "hydration_everyday_D5_no_exercise_fluid_target"


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
    # hydration D5: the CORRECT answer to "how much should I drink on a hot run" must
    # survive the rule aimed at the wrong one. If this ever fails, the guard has started
    # eating the advice it exists to protect.
    "During your long run in the heat, drink to thirst rather than to a schedule "
    "[fueling_and_hydration].",
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
    # environmental_stress D12: the note's whole substance is DESCRIBING these
    # emergencies, and the correct answer must survive the rule aimed at the wrong one.
    "Exertional heat stroke presents with confusion, collapse and vomiting, and needs "
    "immediate cooling and urgent medical care [environmental_stress].",
    "Drinking to a fixed schedule during a marathon is how exercise-associated "
    "hyponatraemia happens, and it can progress to seizure [fueling_and_hydration].",
    "HACE presents with a worsening headache and ataxia; the answer is descent and "
    "medical care, not more training [environmental_stress].",
    "Because you were confused after that run, I'm not going to talk about training — "
    "that belongs with urgent medical care.",
    # The heat-adaptation science the note exists to teach must keep flowing: none of
    # this carries a red flag, so none of it may be touched by a heat-stroke rule.
    "Ten to fourteen days of heat exposure expands plasma volume and lowers heart rate "
    "by about 11 bpm [environmental_stress].",
    "It's completely normal for your pace to drop in this heat, so keep running by "
    "effort rather than by pace [environmental_stress].",
    # A bare "confusion"/"headache"/"collapse" in a non-clinical sense must not fire —
    # this is the over-broad-filter boundary the symptom vocabulary was narrowed for.
    "There is some confusion about what the stress number measures, but you can still "
    "train normally [wearable_stress_validity].",
    "Your training block collapsed into three hard days in a row — that's fine to fix next week.",
    "A mild headache after a long run is common and nothing to worry about.",
]


@pytest.mark.parametrize("text", _ALLOWED)
def test_an_honest_answer_is_not_blocked(text: str) -> None:
    rule = output_guard.check_output(text)
    assert rule is None, f"over-broad: {text!r} was blocked by {rule and rule.name}"


def test_the_documented_rules_are_untouched_by_the_new_table() -> None:
    """Adding the corpus half must not widen a rule that was already in force."""
    assert output_guard.check_output("Cutting your sleep to fit the session in") is None
    assert output_guard.check_output("You could cut your sleep to fit the session in")
