"""A2 · the personal-claims gate on every surface. B3, C3, C5 · the smaller repairs.

**A2 is the one that matters.** ``personal_claims`` is #129's fix for a measured defect —
a model wrote *"You logged alcohol yesterday afternoon"* for an owner with zero such rows
and came back ``validated=True``, because every RESEARCH sentence in it was correctly
cited. The gate was registered in the shared registry and read ``without_data`` off the
context; ``without_data`` was computed by the coach and by nothing else, so
``personal_claims.issues`` returned on its first line for the daily action, the briefing,
every insight card, recs and challenge generation. A registered gate that could not fire.

The declared half stays coach-only — no other surface has a claims contract to declare
with, and inventing one would be worse than not checking. The TEXTUAL backstop was built
to be independent of the declaration ("an answer that fabricates a drink and declares
nothing still gets its claim counted") and it now runs on both entry points.
"""

from __future__ import annotations

import pytest
from tests.insights._ids import ESTABLISHED_ID
from tests.insights._stub import StubLLM

from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.insights import cache, grounded, manifest, personal_claims, prompts, surfaces
from healthee.insights import validator as validator_mod
from healthee.read import meta

# A fabricated personal claim in the shape the textual backstop reads: a past-tense
# reporting verb, in the second person, in the same sentence as the subject.
FABRICATION = "You logged alcohol yesterday afternoon."
ABSENCE = "You have 0 logged alcohol entries in your history."


def _no_data(monkeypatch: pytest.MonkeyPatch, **counts: int) -> None:
    """Stub the ONE database read. Candidate selection, the scan and the rule stay real."""
    monkeypatch.setattr(
        personal_claims,
        "_days_with_data",
        lambda user_id, tz, subjects: {s: counts.get(s, 0) for s in subjects},
    )


def _stub_context(monkeypatch: pytest.MonkeyPatch) -> None:
    """No DB behind the prompt build — this file is about the gates, not the SQL."""
    monkeypatch.setattr(
        grounded,
        "_build_messages",
        lambda q, user_id, tz, metrics, days: [{"role": "user", "content": q}],
    )
    monkeypatch.setattr(
        grounded.coverage, "measured_payload", lambda user_id, tz, metrics, days: {}
    )


def _ask(answer: str) -> grounded.GroundedResult:
    return grounded.grounded_ask(
        "What should I do today?",
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        client=StubLLM([answer] * 4),
    )


# ── A2 · the gate now fires on grounded_ask ──────────────────────────────────


def test_a_fabricated_personal_claim_no_longer_ships_from_grounded_ask(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """THE finding. This is the daily action, the briefing, every insight card and recs.

    It is meant to start catching things — the gate was inert here, not absent, so the
    change in behaviour IS the fix rather than a regression.
    """
    _stub_context(monkeypatch)
    _no_data(monkeypatch)
    result = _ask(f"{FABRICATION} Alcohol fragments sleep [{ESTABLISHED_ID}].")

    assert FABRICATION not in result.text
    assert result.text == prompts.FALLBACK
    assert result.validated is False


def test_the_honest_absence_sentence_still_ships_from_grounded_ask(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The crux, on this surface too. A rule that blocks this is worse than no rule."""
    _stub_context(monkeypatch)
    _no_data(monkeypatch)
    result = _ask(f"{ABSENCE} Alcohol fragments sleep [{ESTABLISHED_ID}].")

    assert result.validated is True
    assert ABSENCE in result.text


def test_the_same_sentence_ships_when_the_owner_has_the_data(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Proof it keys on the data and not on the words."""
    _stub_context(monkeypatch)
    _no_data(monkeypatch, alcohol=6)
    result = _ask(f"{FABRICATION} Alcohol fragments sleep [{ESTABLISHED_ID}].")

    assert result.validated is True
    assert FABRICATION in result.text


def test_an_answer_making_no_personal_claim_never_reaches_the_database(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The gate must stay free for the common answer, or it is a cost on every surface."""
    _stub_context(monkeypatch)

    def _explode(*args: object, **kwargs: object) -> dict[str, int]:
        raise AssertionError("a plain answer must not reach the database")

    monkeypatch.setattr(personal_claims, "_days_with_data", _explode)
    result = _ask(f"Consistent activity may support fitness [{ESTABLISHED_ID}].")
    assert result.validated is True


def test_the_gate_is_recomputed_per_attempt(monkeypatch: pytest.MonkeyPatch) -> None:
    """A nudged rewrite is a different answer that may talk about different subjects."""
    _stub_context(monkeypatch)
    _no_data(monkeypatch)
    stub = StubLLM(
        [
            f"{FABRICATION} Alcohol fragments sleep [{ESTABLISHED_ID}].",
            f"{ABSENCE} Alcohol fragments sleep [{ESTABLISHED_ID}].",
        ]
    )
    result = grounded.grounded_ask(
        "What should I do today?", SENTINEL_USER_ID, SENTINEL_TZ, client=stub
    )

    assert result.validated is True, "the rewrite was judged against the first attempt's facts"
    assert ABSENCE in result.text


# ── B3 · the metric label is the server's, not the caller's ──────────────────


def test_the_metric_insight_prompt_reads_its_label_from_the_metric(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """No caller-supplied string in the task sentence, and none absent from the cache key."""
    monkeypatch.setattr(surfaces, "get_cached", lambda user_id, tz, key: None)
    monkeypatch.setattr(surfaces, "set_cached", lambda user_id, key, value: None)
    monkeypatch.setattr(surfaces, "_metric_numbers", lambda user_id, metric: "Latest 54.")
    seen: list[str] = []

    def _capture(question: str, user_id, tz, **kwargs) -> grounded.GroundedResult:  # noqa: ANN001, ARG001
        seen.append(question)
        return grounded.GroundedResult(text="ok")

    monkeypatch.setattr(surfaces, "grounded_ask", _capture)
    surfaces.metric_insight(SENTINEL_USER_ID, SENTINEL_TZ, "rhr_daily")

    assert "Resting HR" in seen[0]
    assert meta.metric_label("rhr_daily") == "Resting HR"


def test_the_metric_insight_route_takes_no_label_parameter() -> None:
    """The parameter is GONE, not merely ignored — an ignored one still gets sent."""
    import inspect

    from healthee.api.routers import insights as insights_router

    params = inspect.signature(insights_router.get_metric_insight).parameters
    assert "label" not in params
    assert "label" not in inspect.signature(surfaces.metric_insight).parameters


def test_an_unmapped_metric_still_gets_a_readable_name() -> None:
    """A blank where a name belongs is the one thing a sentence cannot survive."""
    assert meta.metric_label("sleep_regularity_index") == "sleep regularity index"


# ── C3 · a review of a fixed past workout is not rewritten every day ─────────


def test_the_workout_review_is_stored_by_the_workout_not_by_the_day(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """``get_cached`` serves only a payload dated today, so this regenerated daily —
    each time against a DIFFERENT week of context, for one unchanging session."""
    stored: dict[str, dict] = {}
    monkeypatch.setattr(surfaces, "_workout_numbers", lambda user_id, start: "5 km, 30 min")
    monkeypatch.setattr(surfaces, "get_stored", lambda user_id, key: stored.get(key))
    monkeypatch.setattr(
        surfaces, "set_cached", lambda user_id, key, value: stored.update({key: value})
    )
    calls: list[int] = []

    def _once(question: str, user_id, tz, **kwargs) -> grounded.GroundedResult:  # noqa: ANN001, ARG001
        calls.append(1)
        return grounded.GroundedResult(text="A steady session.")

    monkeypatch.setattr(surfaces, "grounded_ask", _once)
    surfaces.workout_insight(SENTINEL_USER_ID, SENTINEL_TZ, "2026-08-01T06:00:00+00:00")
    surfaces.workout_insight(SENTINEL_USER_ID, SENTINEL_TZ, "2026-08-01T06:00:00+00:00")

    assert len(calls) == 1, "the same fixed session was reviewed twice"


def test_the_workout_prompt_names_the_window_it_actually_has(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The context is the last 7 days ending TODAY, whatever day the workout was."""
    monkeypatch.setattr(surfaces, "_workout_numbers", lambda user_id, start: "5 km, 30 min")
    monkeypatch.setattr(surfaces, "get_stored", lambda user_id, key: None)
    monkeypatch.setattr(surfaces, "set_cached", lambda user_id, key, value: None)
    seen: list[str] = []

    def _capture(question: str, user_id, tz, **kwargs) -> grounded.GroundedResult:  # noqa: ANN001, ARG001
        seen.append(question)
        return grounded.GroundedResult(text="ok")

    monkeypatch.setattr(surfaces, "grounded_ask", _capture)
    surfaces.workout_insight(SENTINEL_USER_ID, SENTINEL_TZ, "2026-08-01T06:00:00+00:00")

    assert "LAST 7 DAYS UP TO TODAY" in seen[0]
    assert "may be long after this session" in seen[0]


def test_get_stored_and_get_cached_are_different_questions() -> None:
    """One is "is this today's?"; the other is "is this about a fixed past thing?"."""
    assert cache.get_stored is not cache.get_cached


# ── C5 · the same grade lookup fails closed everywhere ───────────────────────


def test_an_unrecognised_grade_ranks_strictest_in_the_validator() -> None:
    """It ranked 3 — Established, the MOST permissive branch — inside the strictest module.

    Unreachable today (``gen_manifest`` pins the vocabulary and aborts on an unknown
    grade). The point is which branch a seventh grade would fall into.
    """
    assert manifest.GRADE_RANK.get("Speculative", 0) == 0
    issue = validator_mod._grade_issue.__doc__ or ""
    assert "0" in issue

    sentence = "Cold plunges raise metabolic rate [x]."
    unknown = {"unknown-grade-id"}
    original = manifest.grade_of
    try:
        manifest.grade_of = lambda note_id: "Speculative"  # type: ignore[assignment]
        assert validator_mod._grade_issue(sentence, unknown) is not None, (
            "an unknown grade satisfied the plain-voice branch"
        )
        assert validator_mod._grade_floor(unknown) == "Speculative"
    finally:
        manifest.grade_of = original  # type: ignore[assignment]
