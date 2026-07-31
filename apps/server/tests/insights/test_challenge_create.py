"""``create_challenge`` — and the proof that it does not fork the WP-C3 pipeline.

WP-C5, CHALLENGES.md §6a. Two tests carry the load and they are complements: one spies
on the call to ``generate.generate_challenges`` (so a fork stops being *reached*), the
other replaces the pipeline with a sentinel (so a fork could not *answer* even if it
existed). Between them a second set of gates cannot be added quietly, which is the whole
reason the seam exists — INTELLIGENCE §4's mirror rule is discharged by reuse, not by
vigilance.

The rest pin what the tool is allowed to say when nothing was built: an intent no metric
can express, an intent the corpus cannot ground, and the one shape the registry cannot
represent at all (a time-of-day cutoff), each refused with its own reason rather than
quietly degraded.
"""

from __future__ import annotations

import pytest
from tests.challenges import _gen
from tests.insights import _challenge_bed as bed

from healthee.challenges import generate
from healthee.insights import challenge_tools

pytestmark = pytest.mark.integration


# ── create_challenge: it must GO THROUGH the WP-C3 pipeline ───────────────────


def test_create_routes_through_generate_challenges(
    challenge_owner_with_history: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The CALL is the assertion. A forked pipeline would leave ``calls`` empty."""
    calls: list[dict] = []
    real = generate.generate_challenges

    def spy(user_id, tz, **kwargs):
        calls.append({"user_id": user_id, "tz": tz, **kwargs})
        return real(user_id, tz, **kwargs)

    monkeypatch.setattr(challenge_tools.generate, "generate_challenges", spy)
    bed.scripted_llm(monkeypatch, [_gen.response()])

    result = challenge_tools.create_challenge(bed.OWNER, bed.TZ, "make me a walking challenge")

    assert len(calls) == 1
    assert calls[0]["intent"] == "make me a walking challenge"
    assert calls[0]["max_new"] == 1
    assert calls[0]["replace_feed"] is False  # a chat turn must not wipe their feed
    assert result["ok"] is True
    assert bed.suggested_ids() == [int(result["challenge"]["id"])]


def test_create_cannot_produce_a_challenge_without_the_pipeline(
    challenge_owner_with_history: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Replace the pipeline with a sentinel: the tool's answer is ENTIRELY its answer.

    The complement of the spy above. That test proves the pipeline is called; this one
    proves nothing else can answer — a second, forked path would have to either ignore
    this refusal or write a row, and both are asserted against.
    """
    sentinel = {"ok": False, "reason": "sentinel_refusal", "error": "the pipeline said no"}
    monkeypatch.setattr(
        challenge_tools.generate, "generate_challenges", lambda *a, **kw: dict(sentinel)
    )
    stub = bed.scripted_llm(monkeypatch, [_gen.response()])

    result = challenge_tools.create_challenge(bed.OWNER, bed.TZ, "make me a walking challenge")

    assert result == sentinel
    assert bed.suggested_ids() == []
    assert stub.calls == 0  # no second route to a model, either


def test_the_reported_target_is_the_stored_one_not_the_first_proposed(
    challenge_owner_with_history: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Gate A REJECTS rather than clamps, so the retry's number is the one that ships.

    The coach therefore cannot report the target it "asked for": the only number it ever
    sees is the one that reached the database.
    """
    bed.scripted_llm(
        monkeypatch,
        [_gen.response(_gen.proposal(target_value=12000.0)), _gen.response()],
    )

    result = challenge_tools.create_challenge(bed.OWNER, bed.TZ, "help me walk more")

    assert result["ok"] is True
    assert result["challenge"]["target_value"] == _gen.IN_BAND != 12000.0
    assert bed.stored(int(result["challenge"]["id"]))["target_value"] == _gen.IN_BAND


def test_an_out_of_band_intent_still_loses_to_gate_a(
    challenge_owner_with_history: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Asking for the number in words buys nothing — the band is arithmetic, not tone."""
    bed.scripted_llm(monkeypatch, [_gen.response(_gen.proposal(target_value=12000.0))])

    result = challenge_tools.create_challenge(bed.OWNER, bed.TZ, "give me a 12000 step challenge")

    assert (result["ok"], result["reason"]) == (False, "rejected_by_gates")
    assert "progressive-overload band" in result["error"]
    assert bed.suggested_ids() == []


def test_an_unbindable_intent_refuses_honestly(
    challenge_owner_with_history: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """ "A challenge to feel happier" binds to no metric, so nothing is created."""
    bed.scripted_llm(monkeypatch, ['{"challenges": []}'])

    result = challenge_tools.create_challenge(bed.OWNER, bed.TZ, "make me happier")

    assert (result["ok"], result["reason"]) == (False, "not_trackable")
    assert "do not describe a challenge that was not created" in result["error"]
    assert bed.suggested_ids() == []


def test_an_ungroundable_intent_creates_nothing(
    challenge_owner_with_history: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Gate B is blocking: a fabricated citation costs the whole batch, twice, then stops."""
    fabricated = _gen.proposal(
        why="Walking may support fitness [not_a_real_note].",
        research_note_ids=["not_a_real_note"],
    )
    bed.scripted_llm(monkeypatch, [_gen.response(fabricated)])

    result = challenge_tools.create_challenge(bed.OWNER, bed.TZ, "help me walk more")

    assert (result["ok"], result["reason"]) == (False, "no_grounded_output")
    assert bed.suggested_ids() == []


def test_creating_keeps_the_suggestions_they_already_had(
    challenge_owner_with_history: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A chat message must not silently delete the feed they are looking at elsewhere."""
    existing = bed.suggest(title="Steadier bedtimes", metric="sri", target_value=60.0)
    bed.scripted_llm(monkeypatch, [_gen.response()])

    result = challenge_tools.create_challenge(bed.OWNER, bed.TZ, "help me walk more")

    assert result["ok"] is True
    assert set(bed.suggested_ids()) == {existing, int(result["challenge"]["id"])}


def test_creating_will_not_shadow_a_metric_already_on_the_menu(
    challenge_owner_with_history: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Keeping the feed means the dedup has to cover it, or the menu grows two of one."""
    bed.suggest(title="An existing steps suggestion", metric="steps_total")
    bed.scripted_llm(monkeypatch, [_gen.response()])

    result = challenge_tools.create_challenge(bed.OWNER, bed.TZ, "help me walk more")

    assert result["ok"] is False
    assert "already has a live or proposed challenge" in result["error"]


# ── the shape we cannot express, refused rather than degraded ─────────────────


def test_a_time_of_day_intent_refuses_with_its_actual_reason(
    challenge_owner_with_history: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The registry has no clock, and the DEGRADATION is the dangerous part.

    "No caffeine after 15:00" as a daily caffeine cap scores three morning coffees as a
    failure and one 23:00 coffee as a pass. The refusal has to say that, and it has to
    happen before a model is ever asked to have a go.
    """
    stub = bed.scripted_llm(monkeypatch, [_gen.response()])

    result = challenge_tools.create_challenge(
        bed.OWNER, bed.TZ, "challenge me to drink no caffeine after 15:00"
    )

    assert (result["ok"], result["reason"]) == (False, "no_time_of_day_predicate")
    assert "daily total" in result["error"]
    assert "do NOT offer the daily-total version" in result["error"]
    assert stub.calls == 0  # nothing was even asked to approximate it
    assert bed.suggested_ids() == []


@pytest.mark.parametrize(
    "intent",
    [
        "no caffeine after 3pm",
        "stop drinking after 21:00",
        "no alcohol before bed",
        "nothing to eat after dinner",
    ],
)
def test_the_cutoff_shapes_people_actually_ask_for_are_all_caught(intent: str) -> None:
    assert challenge_tools._TIME_OF_DAY_RE.search(intent) is not None


@pytest.mark.parametrize(
    "intent",
    [
        "walk more before my trip",
        "get me under 3 coffees a day",
        "help me hit 8000 steps",
    ],
)
def test_an_ordinary_intent_is_not_mistaken_for_a_cutoff(intent: str) -> None:
    assert challenge_tools._TIME_OF_DAY_RE.search(intent) is None


def test_an_empty_intent_refuses_before_anything_is_spent(
    challenge_owner_with_history: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    stub = bed.scripted_llm(monkeypatch, [_gen.response()])

    result = challenge_tools.create_challenge(bed.OWNER, bed.TZ, "   ")

    assert (result["ok"], result["reason"]) == (False, "no_intent")
    assert stub.calls == 0
