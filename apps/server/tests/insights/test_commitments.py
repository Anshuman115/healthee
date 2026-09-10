"""The coach's memory: what it stores, what it refuses to infer, and whose it is.

C1's honesty guard is the whole design here — *memory is observations, never
fabrications*. Two things follow, and both are asserted below rather than trusted:

* a commitment's outcome moves only on the OWNER's word. Nothing in this app
  observes whether somebody did a thing, so there is no `succeeded`, no inference
  from a metric moving, and an unanswered commitment stays `open` for ever. That
  is honest: we asked, and we do not know.
* a remembered claim is a claim about the past, not a number. The coach re-queries
  numbers; it never recalls them.
"""

from __future__ import annotations

from datetime import date, timedelta
from uuid import UUID, uuid4

import pytest

from healthee.core.db import transaction
from healthee.db import migrate
from healthee.insights import commitments

pytestmark = [pytest.mark.integration, pytest.mark.usefixtures("owner_sweep")]

_TZ = "Asia/Kolkata"


def _owner() -> UUID:
    uid = uuid4()
    with transaction() as cur:
        cur.execute("INSERT INTO app_user (id, email) VALUES (%s, NULL)", (str(uid),))
    return uid


def test_a_recorded_commitment_comes_back_on_the_next_turn(db: None) -> None:  # noqa: ARG001
    """The cold start this exists to end."""
    migrate.apply_migrations()
    uid = _owner()
    stored = commitments.record(uid, _TZ, "move coffee before 2pm", "caffeine_mg", 10)
    assert stored["ok"] is True

    remembered = commitments.open_commitments(uid)
    assert [c.stated for c in remembered] == ["move coffee before 2pm"]
    assert remembered[0].metric == "caffeine_mg"


def test_a_commitment_with_no_metric_is_a_real_commitment(db: None) -> None:  # noqa: ARG001
    """ "I'll get to bed earlier" names no metric this app tracks.

    Forcing one would invent an attribution — a later reading credited to a change
    nobody measured. Remembered and asked about; never scored.
    """
    migrate.apply_migrations()
    uid = _owner()
    stored = commitments.record(uid, _TZ, "get to bed earlier", None, 7)
    assert stored["ok"] is True
    assert commitments.open_commitments(uid)[0].metric is None


def test_the_horizon_is_clamped_rather_than_refused(db: None) -> None:  # noqa: ARG001
    """Losing the agreement over a bad number is the worse outcome."""
    migrate.apply_migrations()
    uid = _owner()
    commitments.record(uid, _TZ, "a year from now", None, 9999)
    due = commitments.open_commitments(uid)[0].check_in_on
    assert due <= date.today() + timedelta(days=commitments.MAX_HORIZON_DAYS + 1)


def test_a_due_commitment_says_it_is_due_and_an_early_one_does_not(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    uid = _owner()
    commitments.record(uid, _TZ, "walk after dinner", None, 3)
    c = commitments.open_commitments(uid)[0]
    assert c.due(c.check_in_on) is True
    assert c.due(c.check_in_on - timedelta(days=1)) is False


def test_there_is_no_succeeded_status(db: None) -> None:  # noqa: ARG001
    """`kept` is what a person said. `succeeded` would be a verdict nothing measured.

    The vocabulary is the guard: a status this app could not have observed is not
    spellable, so no future caller can set one by being careless.
    """
    migrate.apply_migrations()
    uid = _owner()
    commitments.record(uid, _TZ, "walk after dinner", None, 7)
    cid = commitments.open_commitments(uid)[0].id

    refused = commitments.resolve(uid, cid, "succeeded")
    assert refused["ok"] is False
    assert refused["reason"] == "bad_status"
    # still open — a refused resolution changes nothing
    assert len(commitments.open_commitments(uid)) == 1

    assert commitments.resolve(uid, cid, "kept")["ok"] is True
    assert commitments.open_commitments(uid) == []


def test_resolving_twice_is_refused_so_the_first_answer_stands(db: None) -> None:  # noqa: ARG001
    migrate.apply_migrations()
    uid = _owner()
    commitments.record(uid, _TZ, "walk after dinner", None, 7)
    cid = commitments.open_commitments(uid)[0].id
    assert commitments.resolve(uid, cid, "missed")["ok"] is True
    again = commitments.resolve(uid, cid, "kept")
    assert again["ok"] is False
    assert again["reason"] == "not_open"


def test_one_owner_cannot_touch_anothers_commitment(db: None) -> None:  # noqa: ARG001
    """The owner is a predicate on the UPDATE, so this matches no row at all."""
    migrate.apply_migrations()
    mine, theirs = _owner(), _owner()
    commitments.record(theirs, _TZ, "their commitment", None, 7)
    cid = commitments.open_commitments(theirs)[0].id

    assert commitments.resolve(mine, cid, "kept")["ok"] is False
    # and theirs is untouched, which is the half a False alone would not prove
    assert len(commitments.open_commitments(theirs)) == 1
    # nor can they even see it
    assert commitments.open_commitments(mine) == []


def test_the_open_list_is_bounded_and_says_what_to_do(db: None) -> None:  # noqa: ARG001
    """Five things you have agreed to change at once is a list you stopped reading."""
    migrate.apply_migrations()
    uid = _owner()
    for i in range(commitments.MAX_OPEN):
        assert commitments.record(uid, _TZ, f"commitment {i}", None, 7)["ok"] is True
    refused = commitments.record(uid, _TZ, "one too many", None, 7)
    assert refused["ok"] is False
    assert refused["reason"] == "too_many_open"
    assert "which one to drop" in refused["error"]


def test_an_empty_commitment_is_refused(db: None) -> None:  # noqa: ARG001
    assert commitments.record(_owner(), _TZ, "   ", None, 7)["ok"] is False
