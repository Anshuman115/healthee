"""Inside one day, precedence — not recency (write-path audit B1).

``derived_daily``'s key is ``(user_id, day, metric)``, so a day holds exactly ONE
``vo2max_submax`` cell. ``score_day_tracks`` scores a day's tracks oldest-first and every
one of them landed in that cell, so **the last session of the day owned it** — and
``vo2max_tier.measured_sessions`` reads the measured tier out of those cells and nothing
else. A graded fit at 09:00 and a reserve inversion at 18:00 therefore left only the
reserve value, and the tier never saw the graded one.

That is the ordering ``test_precedence_is_not_recency`` forbids ACROSS days, broken WITHIN
one. Nor did a repair reach it: ``unscored_tracks`` skips a track that already carries an
estimate, so an ordinary re-derive leaves the losing session invisible and
``--rescore-tracks`` reproduces the same order.

The audit found no test covering two tracks in one day. These are it. They drive
``derive.gps._store`` — the ONE writer of that cell, which is where "which session wins"
is now decided — and then read the answer back through the tier, so the loop that made the
defect consequential is the loop under test.
"""

from __future__ import annotations

from datetime import date
from uuid import uuid4

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.derive.gps import _store
from healthee.derive.vo2max_reserve import METHOD_RESERVE
from healthee.derive.vo2max_submax import METHOD_GRADED
from healthee.derive.vo2max_tier import (
    MEASURED_PRECEDENCE,
    measured_tier,
    outranks,
    submax_method_of,
)

_DAY = date(2026, 6, 20)
_HRMAX = 187.0


def _score(cur, method: str, value: float) -> None:
    """One session landing in the day, exactly as ``derive_vo2max_submax`` lands it."""
    _store(cur, SENTINEL_USER_ID, _DAY, str(uuid4()), value, {"method": method}, _HRMAX, "dem", 0)


def _cell(cur) -> tuple[float, str]:
    cur.execute(
        "SELECT value, flags FROM derived_daily "
        "WHERE user_id = %s AND day = %s AND metric = 'vo2max_submax'",
        (SENTINEL_USER_ID, _DAY),
    )
    row = cur.fetchone()
    assert row is not None, "the day should carry a session measurement"
    return float(row[0]), submax_method_of(row[1])


def _clear(cur) -> None:
    cur.execute(
        "DELETE FROM derived_daily WHERE user_id = %s AND metric = 'vo2max_submax'",
        (SENTINEL_USER_ID,),
    )


# ── the ordering itself, with no database ────────────────────────────────────


def test_the_graded_fit_outranks_the_reserve_inversion() -> None:
    assert outranks(METHOD_GRADED, METHOD_RESERVE)
    assert not outranks(METHOD_RESERVE, METHOD_GRADED)


def test_an_equal_method_does_not_outrank_itself() -> None:
    """A re-score has to be able to move a value, so equal must NOT decline the write."""
    for method in MEASURED_PRECEDENCE:
        assert not outranks(method, method)


def test_an_unknown_instrument_ranks_last_rather_than_first() -> None:
    """The safe direction: never having heard of a method is not a reason to prefer it."""
    assert not outranks("some_future_estimator", METHOD_GRADED)
    assert outranks(METHOD_GRADED, "some_future_estimator")


def test_an_unstamped_submax_row_reads_as_a_graded_fit() -> None:
    """Rows written before #114 carry no `method` and are all graded fits.

    `vo2max_tier.method_of` defaults the OTHER way (Jurca) because it answers for
    `vo2max_estimate`; using one default for both would relabel every old measured session
    as a model estimate.
    """
    assert submax_method_of(None) == METHOD_GRADED
    assert submax_method_of({}) == METHOD_GRADED
    assert submax_method_of({"method": METHOD_RESERVE}) == METHOD_RESERVE


# ── the day cell, and the tier that reads it ─────────────────────────────────


@pytest.mark.usefixtures("db")
def test_a_later_reserve_session_does_not_displace_the_days_graded_fit() -> None:
    """THE defect: 09:00 graded, 18:00 reserve, and only the reserve survived the day."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _clear(cur)
        _score(cur, METHOD_GRADED, 39.6)
        _score(cur, METHOD_RESERVE, 41.7)
        value, method = _cell(cur)
        tier = measured_tier(cur, SENTINEL_USER_ID, _DAY)

    assert (value, method) == (39.6, METHOD_GRADED)
    assert tier is not None
    assert (tier.value, tier.method) == (39.6, METHOD_GRADED)


@pytest.mark.usefixtures("db")
def test_a_later_graded_fit_does_displace_the_days_reserve_inversion() -> None:
    """The other direction, and the one that proves this is precedence rather than "first
    write wins": the better instrument takes the day whichever order it arrives in."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _clear(cur)
        _score(cur, METHOD_RESERVE, 41.7)
        _score(cur, METHOD_GRADED, 39.6)
        value, method = _cell(cur)

    assert (value, method) == (39.6, METHOD_GRADED)


@pytest.mark.usefixtures("db")
def test_a_second_session_of_the_same_instrument_still_overwrites() -> None:
    """Equal rank must keep writing, or `--rescore-tracks` could never move a value.

    This is also the residual B1 does NOT close, recorded rather than implied: two graded
    sessions in one day still leave one cell, so the tier's median counts days rather than
    sessions there. Representing both needs a per-session home carrying the method, which
    `gps_track` has no column for.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _clear(cur)
        _score(cur, METHOD_GRADED, 39.6)
        _score(cur, METHOD_GRADED, 44.2)
        value, method = _cell(cur)

    assert (value, method) == (44.2, METHOD_GRADED)


@pytest.mark.usefixtures("db")
def test_the_first_session_of_a_day_always_writes() -> None:
    """No cell yet is not a better instrument."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _clear(cur)
        _score(cur, METHOD_RESERVE, 41.7)
        assert _cell(cur) == (41.7, METHOD_RESERVE)
