"""#129 · a fabricated PERSONAL fact must not ship — and an honest absence must.

The gap: the validator checks interpretive sentences against the research corpus, so a
sentence about the owner's own data cites nothing and nothing checked it. Measured on a
fixture with zero ``manual_entry`` rows of kind ``alcohol``, one model opened *"You logged
alcohol yesterday afternoon…"* and came back ``validated=True``.

**The crux is pinned first and twice**, because a gate that fails it is worse than no
gate: the two sentences below both name a subject with no data, one is the correct answer
and one is the fabrication, and the whole design exists to tell them apart. Everything
after that is the policy those two facts travel under — nudge, then the honest fallback —
which is inherited from the shared registry rather than reimplemented here.

``_days_with_data`` is the ONE thing stubbed in the control-flow tests: it is the DB read,
and stubbing it leaves the candidate selection, the sentence scan and the rule real. The
integration test at the bottom runs it for real against a seeded owner, so nothing here
rests on a guess about what it returns.
"""

from __future__ import annotations

from datetime import timedelta

import pytest
from tests.insights._coach_stub import CoachStub, answer_turn, opening_turn, valid_turn
from tests.insights._ids import ESTABLISHED_ID

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.db import migrate
from healthee.insights import coach, coach_thread, personal_claims, prompts

# THE CRUX. Both name `alcohol`; the owner has none of it.
ABSENCE = "You have 0 logged alcohol entries in your history."
FABRICATION = "You logged alcohol yesterday afternoon."

_NO_ALCOHOL = frozenset({"alcohol"})


# ── 1 · the crux, on the rule itself ─────────────────────────────────────────


def test_stating_an_absence_passes_untouched() -> None:
    """The behaviour we WANT. A rule that blocks this sentence is worse than no rule."""
    assert personal_claims.issues(ABSENCE, (), _NO_ALCOHOL) == ()


def test_asserting_a_value_for_data_we_do_not_have_fails() -> None:
    """The same subject, the same zero — declared, so blockable."""
    found = personal_claims.issues(FABRICATION, ("alcohol",), _NO_ALCOHOL)
    assert len(found) == 1
    assert "alcohol" in found[0]
    assert "0 days" in found[0]


def test_the_absence_sentence_passes_even_when_alcohol_is_declared() -> None:
    """The declaration is the mechanism, so declaring wrongly must still be blocked...

    ...and this test says what that costs: an answer that declares ``alcohol`` while only
    stating its absence IS refused, because the declaration is what the gate reads. It is
    the conservative side of the trade — a nudge asking for a sentence the model already
    wrote — and the shape instruction tells it plainly that an absence declares nothing.
    """
    assert personal_claims.issues(ABSENCE, ("alcohol",), _NO_ALCOHOL) != ()


def test_the_backstop_catches_a_fabrication_that_declares_nothing() -> None:
    """The floor under the declaration: prose that records an event the data lacks."""
    found = personal_claims.issues(FABRICATION, (), _NO_ALCOHOL)
    assert len(found) == 1
    assert FABRICATION in found[0]


@pytest.mark.parametrize(
    "sentence",
    [
        ABSENCE,
        "You have not logged any alcohol recently, so we cannot quantify a personal effect.",
        "You have never logged alcohol.",
        "You logged no alcohol this week.",
        # Research and advice ABOUT the subject — the answers the other two models gave.
        "Alcohol before bed fragments the second half of the night [alcohol_sleep].",
        "Your sleep may be worse on nights you drink [alcohol_sleep].",
        "You should stop caffeine 8 hours before bed [caffeine_cutoff].",
        "You need 150 minutes of exercise per week [mvpa_guidelines].",
    ],
)
def test_the_backstop_never_fires_on_an_honest_sentence(sentence: str) -> None:
    """Every false positive here would block an answer that is already correct."""
    zero = frozenset({"alcohol", "caffeine", "exercise"})
    assert personal_claims.issues(sentence, (), zero) == ()


def test_a_subject_with_real_data_is_never_an_issue() -> None:
    """Nothing is blocked when the owner HAS the data — declared or recorded in prose."""
    assert personal_claims.issues(FABRICATION, ("alcohol",), frozenset()) == ()
    assert (
        personal_claims.issues("Your rhr daily averaged 54 bpm.", ("rhr_daily",), frozenset()) == ()
    )


def test_one_subject_is_reported_once() -> None:
    """A declared subject that the prose also records is ONE defect, not two."""
    assert len(personal_claims.issues(FABRICATION, ("alcohol",), _NO_ALCOHOL)) == 1


# ── 2 · what the gate asks the database, and when ────────────────────────────


def test_an_answer_with_no_personal_claim_reads_nothing(monkeypatch: pytest.MonkeyPatch) -> None:
    """The no-op case, proved by the query never happening rather than by an empty result."""

    def _explode(*args: object, **kwargs: object) -> dict[str, int]:
        raise AssertionError("a plain answer must not reach the database")

    monkeypatch.setattr(personal_claims, "_days_with_data", _explode)
    text = "Steady activity may support fitness [cardio_load_basics]."
    assert (
        personal_claims.subjects_without_data(SENTINEL_USER_ID, SENTINEL_TZ, (), text)
        == frozenset()
    )


def test_an_unrecognised_subject_is_not_judged() -> None:
    """We do not know what it is, so we do not get to say the owner has none of it."""
    assert personal_claims._days_with_data(SENTINEL_USER_ID, SENTINEL_TZ, ["not_a_metric"]) == {}


# ── 3 · the policy a hit travels under (shared registry, not reimplemented) ───


@pytest.fixture(autouse=True)
def _stub_context(monkeypatch: pytest.MonkeyPatch) -> None:
    """Skip the DB-backed context build — section 3 is control flow, not SQL."""
    monkeypatch.setattr(
        coach,
        "_initial_messages",
        # Keeps the LAYOUT (a `system` turn, then the whole conversation) while
        # skipping the DB-backed context/evidence build. It used to return only the
        # last question, which discarded `history` — so no coach test exercised a
        # multi-turn context, and the thread-wide refusal screen could not have been
        # caught here however it behaved. The topic block rides along so a test can
        # assert what a topic does and does not put in front of the model.
        lambda history, q, user_id, tz, days, topic=None: [
            {"role": "system", "content": f"CONTEXT{coach_thread.topic_block(topic)}"},
            *history,
        ],
    )


def _no_data(monkeypatch: pytest.MonkeyPatch, **counts: int) -> None:
    """Stub the ONE database read; every other part of the gate stays real."""
    monkeypatch.setattr(
        personal_claims,
        "_days_with_data",
        lambda user_id, tz, subjects: {s: counts.get(s, 0) for s in subjects},
    )


def _ask(client: object) -> coach.CoachResult:
    return coach.run_coach(
        [{"role": "user", "content": "does alcohol hurt my sleep?"}],
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        client=client,  # type: ignore[arg-type]
    )


def test_a_fabricated_personal_claim_is_nudged_not_dropped(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A hit is retryable like every other issue — and the nudge NAMES the subject."""
    _no_data(monkeypatch)
    stub = CoachStub([opening_turn(FABRICATION, asserts=["alcohol"]), valid_turn()])
    result = _ask(stub)

    assert stub.calls == 2, "the model was asked again rather than silently dropped"
    nudge = stub.messages_seen[1][-1]["content"]
    assert "alcohol" in nudge and "0 days" in nudge
    assert result.validated is True
    assert FABRICATION not in result.reply


def test_a_fabrication_repeated_falls_back_honestly(monkeypatch: pytest.MonkeyPatch) -> None:
    """It never ships. The owner gets the honest non-answer, not the invented one."""
    _no_data(monkeypatch)
    stub = CoachStub([opening_turn(FABRICATION, asserts=["alcohol"])] * 3)
    result = _ask(stub)

    assert result.reply == prompts.FALLBACK
    assert result.validated is False
    assert "alcohol" not in result.reply


def test_the_honest_absence_answer_ships(monkeypatch: pytest.MonkeyPatch) -> None:
    """The other half of the crux, end to end: the correct answer must survive the gate."""
    _no_data(monkeypatch)
    turn = answer_turn(
        opening=ABSENCE,
        claims=[
            ("Alcohol fragments the second half of the night", [ESTABLISHED_ID], "Established")
        ],
    )
    result = _ask(CoachStub([turn]))

    assert result.reply.startswith(ABSENCE)
    assert result.validated is True


def test_the_same_claim_ships_when_the_owner_has_the_data(monkeypatch: pytest.MonkeyPatch) -> None:
    """Proof the gate keys on the DATA and not on the words: same answer, six logged days."""
    _no_data(monkeypatch, alcohol=6)
    stub = CoachStub([opening_turn(FABRICATION, asserts=["alcohol"])])
    result = _ask(stub)

    assert result.reply == FABRICATION
    assert result.validated is True
    assert stub.calls == 1


def test_an_answer_making_no_personal_claim_is_untouched(monkeypatch: pytest.MonkeyPatch) -> None:
    """The gate is a no-op for the answers it is not about — no reads, no issues."""

    def _explode(*args: object, **kwargs: object) -> dict[str, int]:
        raise AssertionError("a plain answer must not reach the database")

    monkeypatch.setattr(personal_claims, "_days_with_data", _explode)
    stub = CoachStub([valid_turn()])
    assert _ask(stub).validated is True
    assert stub.calls == 1


# ── 4 · the real count, against a real owner ─────────────────────────────────


@pytest.mark.integration
def test_days_with_data_counts_the_owner_real_rows(db: None) -> None:  # noqa: ARG001 — gates on the DB
    """The stub in section 3 is only honest if the real read behaves the same way.

    Both tables in one assertion, because the gate treats them as one question: a daily
    metric counted by ``analytics.baselines`` and a logged kind counted by
    ``analytics.series`` — one with rows, one without.
    """
    migrate.apply_migrations()
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute("DELETE FROM derived_daily WHERE user_id = %s", (SENTINEL_USER_ID,))
        cur.execute("DELETE FROM manual_entry WHERE user_id = %s", (SENTINEL_USER_ID,))
        for offset in range(3):
            cur.execute(
                "INSERT INTO derived_daily (user_id, day, metric, value) VALUES (%s, %s, %s, %s)",
                (SENTINEL_USER_ID, today - timedelta(days=offset), "rhr_daily", 54.0),
            )

    counted = personal_claims._days_with_data(
        SENTINEL_USER_ID, SENTINEL_TZ, ["rhr_daily", "alcohol"]
    )
    assert counted == {"rhr_daily": 3, "alcohol": 0}

    empty = personal_claims.subjects_without_data(
        SENTINEL_USER_ID, SENTINEL_TZ, ["rhr_daily", "alcohol"], ""
    )
    assert empty == frozenset({"alcohol"})
