"""Known-value tests for the two baselines the median unification MOVED.

``derive/robust.median`` is now the only median in the tree. Three of the four
modules that used to hand-roll one took the UPPER-middle value of an even-length
sample (``xs[len(xs) // 2]``), which is the (n/2 + 1)-th order statistic, not a
median — on six nights it reports the 4th-shortest, i.e. roughly the 67th percentile,
and calls it "your usual".

Two of those sites feed a number a person reads:

* ``derive/recovery.py::_recovery_baseline`` — the median AND the MAD behind every
  autonomic factor of ``recovery_score`` (HRV, resting HR, respiratory rate). Its
  median already interpolated; its MAD did not, so the two halves of one robust
  baseline disagreed with each other.
* ``read/recovery.py::_sleep_signal`` — the Today page's sleep-duration signal, whose
  ``baseline``, ``z`` and favourable/unfavourable ``direction`` all hang off it.

Every expected number below is computed by hand from the definition and shown with
its arithmetic, alongside what the upper-middle form returned for the same data. None
of them came out of the implementation.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_USER_ID
from healthee.derive.recovery import _AUTONOMIC_MIN_SD, _recovery_baseline
from healthee.derive.robust import MAD_TO_SD
from healthee.read.recovery import _SLEEP_MIN_SD_MIN, _sleep_signal

# ── the autonomic baseline (derive/recovery.py) ──────────────────────────────
#
# Six trailing HRV nights, deliberately EVEN so the two estimators diverge:
#
#   [10, 12, 14, 16, 18, 30]
#   median      = (14 + 16) / 2 = 15          upper-middle form: 16
#   |x - 15|    = [5, 3, 1, 1, 3, 15] -> sorted [1, 1, 3, 3, 5, 15] -> MAD = 3
#   upper-middle MAD (taken about ITS median, 16):
#               = [6, 4, 2, 0, 2, 14] -> sorted [0, 2, 2, 4, 6, 14] -> 4
#
# So the old pair was (16, 4) and the correct pair is (15, 3): the baseline was
# pulled toward the 30 ms outlier the MAD exists to resist, and the spread was
# inflated by a third.
_HRV_WINDOW = [10.0, 12.0, 14.0, 16.0, 18.0, 30.0]
_HRV_MEDIAN = 15.0
_HRV_MAD = 3.0

_DAY = date(2026, 3, 8)


def _seed_hrv(cur, values: list[float]) -> None:
    """One ``hrv_sleep_avg`` row per trailing day, oldest first, EXCLUDING ``_DAY``."""
    cur.execute("DELETE FROM derived_daily")
    for offset, value in enumerate(reversed(values), start=1):
        cur.execute(
            "INSERT INTO derived_daily (user_id, day, metric, value) VALUES (%s, %s, %s, %s)",
            (SENTINEL_USER_ID, _DAY - timedelta(days=offset), "hrv_sleep_avg", value),
        )


@pytest.mark.usefixtures("db")
def test_the_autonomic_baseline_is_the_interpolating_median_and_mad() -> None:
    """(15.0, 3 * 1.4826) — not the (16.0, 4 * 1.4826) the upper-middle form gave.

    The floor (0.5) is far below both, so it is a no-op here and the SD is the raw
    MAD scaled: 3 * 1.4826 = 4.4478 (was 4 * 1.4826 = 5.9304).
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed_hrv(cur, _HRV_WINDOW)
        med, sd = _recovery_baseline(cur, SENTINEL_USER_ID, "hrv_sleep_avg", _DAY)
    assert sd is not None  # (None, None) means "fewer than 5 points" — not the case here
    assert med == _HRV_MEDIAN
    assert sd == pytest.approx(_HRV_MAD * MAD_TO_SD, abs=1e-9)
    assert sd == pytest.approx(4.4478, abs=1e-9)
    assert sd > _AUTONOMIC_MIN_SD  # the degenerate-history floor did not bind


@pytest.mark.usefixtures("db")
def test_the_moved_baseline_changes_the_recovery_factor_it_feeds() -> None:
    """A 20 ms night scores 72/100 on this history, where it used to score 63.

    ``_personal_factor`` scores HRV as ``50 + 20*z`` (higher is better):
        old: z = (20 - 16) / 5.9304 = 0.67449 -> 50 + 13.490 = 63.49 -> 63
        new: z = (20 - 15) / 4.4478 = 1.12415 -> 50 + 22.483 = 72.48 -> 72
    The new number is the right one because 15 ms is the value half this person's
    nights fall below — 16 ms is the 4th of 6, dragged up by a single 30 ms outlier
    that a median exists to ignore.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed_hrv(cur, _HRV_WINDOW)
        med, sd = _recovery_baseline(cur, SENTINEL_USER_ID, "hrv_sleep_avg", _DAY)
    assert med is not None and sd is not None
    z = (20.0 - med) / sd
    assert z == pytest.approx(1.124151, abs=1e-6)
    assert round(50 + 20 * z) == 72
    # What the same night scored against the upper-middle pair (16.0, 4 * 1.4826).
    assert round(50 + 20 * (20.0 - 16.0) / (4.0 * MAD_TO_SD)) == 63


# ── the Today-page sleep signal (read/recovery.py) ───────────────────────────
#
# Six nights of total sleep time, newest LAST (the newest is what gets scored):
#
#   [480, 450, 420, 360, 330, 320]  -> sorted [320, 330, 360, 420, 450, 480]
#   median      = (360 + 420) / 2 = 390       upper-middle form: 420
#   |x - 390|   = [90, 60, 30, 30, 60, 70] -> sorted [30, 30, 60, 60, 70, 90] -> MAD 60
#   upper-middle MAD (about ITS median, 420):
#               = [100, 90, 60, 0, 30, 60] -> sorted [0, 30, 60, 60, 90, 100] -> 60
#
# The MAD happens to agree (60) on this window, which isolates the median move:
#   robust_sd(60, floor=1.0) = 60 * 1.4826 = 88.956
#   z_old = (320 - 420) / 88.956 = -1.12415   -> z < -1  -> "unfavorable"
#   z_new = (320 - 390) / 88.956 = -0.78691   -> neither -> "neutral"
#
# That is a label a person reads, flipped by an estimator that overstated their own
# usual night by half an hour.
_NIGHTS_OLDEST_FIRST = [480.0, 450.0, 420.0, 360.0, 330.0, 320.0]
_SLEEP_MEDIAN = 390.0
_SLEEP_MAD = 60.0
_LAST_NIGHT = 320.0


def _seed_nights(cur, durations: list[float]) -> None:
    """One ``main`` sleep session per trailing day, oldest first — all light minutes,
    so ``light_min + deep_min + rem_min`` is exactly the duration under test.

    Anchored to ``now()`` because ``_sleep_signal``'s history window is
    ``start_ts > now() - interval '30 days'`` — a fixed calendar date would fall out
    of the window the moment the suite is run on a later day, which is the flake this
    repo has already paid for twice.
    """
    cur.execute("DELETE FROM sleep_session")
    start = datetime.now(tz=UTC) - timedelta(days=len(durations), hours=1)
    for offset, minutes in enumerate(durations):
        session_start = start + timedelta(days=offset)
        cur.execute(
            "INSERT INTO sleep_session "
            "(user_id, start_ts, end_ts, kind, light_min, deep_min, rem_min) "
            "VALUES (%s, %s, %s, 'main', %s, 0, 0)",
            (
                SENTINEL_USER_ID,
                session_start,
                session_start + timedelta(minutes=minutes),
                int(minutes),
            ),
        )


@pytest.mark.usefixtures("db")
def test_the_sleep_signal_baseline_is_the_interpolating_median() -> None:
    """baseline 390 min, z -0.78691, direction "neutral" — was 420 / -1.12414 /
    "unfavorable"."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed_nights(cur, _NIGHTS_OLDEST_FIRST)
        signal = _sleep_signal(cur, SENTINEL_USER_ID)
    assert signal is not None
    assert signal["value"] == _LAST_NIGHT
    assert signal["baseline"] == _SLEEP_MEDIAN
    assert signal["z"] == pytest.approx(-0.786906, abs=1e-6)
    assert signal["direction"] == "neutral"


def test_the_sleep_signals_arithmetic_is_the_notes_and_not_the_codes() -> None:
    """Recompute the z above from the definition, with no DB and no read layer.

    z = (last_night - median) / robust_sd(MAD, floor). Written out so a reviewer can
    check the DB test's expectation with a calculator rather than trusting it.
    """
    sd = max(_SLEEP_MAD * MAD_TO_SD, _SLEEP_MIN_SD_MIN)
    assert sd == pytest.approx(88.956, abs=1e-9)
    assert (_LAST_NIGHT - _SLEEP_MEDIAN) / sd == pytest.approx(-0.786906, abs=1e-6)
    # And what the upper-middle baseline used to report for the same six nights.
    assert (_LAST_NIGHT - 420.0) / sd == pytest.approx(-1.124151, abs=1e-6)
