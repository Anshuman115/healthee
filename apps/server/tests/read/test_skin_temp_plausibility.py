"""One night's skin temperature, one answer, on both surfaces (audit C7).

``skin_temp_signals`` specifies the plausibility filter at BOTH call sites — *"surfaced
by averaging over the sleep window at read time (`read/sleep_extras.py`,
`read/sleep_page.py` — `AVG(skin_temp_c)` over the night, **filtered to plausible
values, e.g. `value>25`**)"*. ``sleep_page`` had it; ``sleep_extras`` did not, and took a
raw average.

This is the ACWR shape: a well-sourced note, code that disagrees, and **the code yields**.
No note changed here.

Why it matters beyond tidiness. A sentinel or off-wrist sample is far below body surface
temperature, so leaving it in drags the overnight mean DOWN — and the same metric is the
weaker limb of the illness early-warning flag, where a sustained **rise** over the 14-day
median is what contributes. A surface that reads low for a bad reason is a surface that
cannot see the signal it exists to carry, and the two surfaces disagreeing about the same
night is the shape ``CLAUDE.md``'s "ONE canonical definition per metric" forbids.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.read.sleep_extras import last_sleep_extras

pytestmark = pytest.mark.integration

ZONE = ZoneInfo(SENTINEL_TZ)


def _reset(cur) -> None:
    cur.execute("DELETE FROM sample")


def _night(day: date) -> tuple[datetime, datetime]:
    start = datetime.combine(day, time(23, 0), tzinfo=ZONE).astimezone(UTC)
    return start, start + timedelta(hours=7)


def _temps(cur, start: datetime, values: list[float]) -> None:
    for i, value in enumerate(values):
        cur.execute(
            "INSERT INTO sample (user_id, ts, metric, value) VALUES (%s, %s, 'skin_temp_c', %s)",
            (SENTINEL_USER_ID, start + timedelta(minutes=i), value),
        )


def test_an_off_wrist_sample_does_not_drag_the_night_down() -> None:
    """Four real readings averaging 33.0, plus one sentinel 0.0 that must not count.

    Hand-computed both ways so the failure message is unambiguous: filtered = 33.0,
    unfiltered = 26.4. The old behaviour is a whole night reading nearly seven degrees
    cold, on the surface the Today card draws from.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        start, end = _night(user_today(SENTINEL_TZ) - timedelta(days=1))
        _temps(cur, start, [32.0, 33.0, 33.0, 34.0, 0.0])
        extras = last_sleep_extras(cur, SENTINEL_USER_ID, start, end)

    assert float(extras["skin_temp_c"]) == 33.0, extras
    assert float(extras["skin_temp_c"]) != 26.4, "the sentinel is still in the average"


def test_a_night_of_only_implausible_samples_reports_nothing() -> None:
    """Filtered to nothing is an absence, not a zero — the honesty contract's core case."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        start, end = _night(user_today(SENTINEL_TZ) - timedelta(days=1))
        _temps(cur, start, [0.0, 0.0, 15.0])
        extras = last_sleep_extras(cur, SENTINEL_USER_ID, start, end)

    assert extras["skin_temp_c"] is None, extras


def test_a_clean_night_is_untouched_by_the_filter() -> None:
    """The gate must not eat real readings; 25 is a floor, not a band."""
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        start, end = _night(user_today(SENTINEL_TZ) - timedelta(days=1))
        _temps(cur, start, [31.0, 32.0, 33.0])
        extras = last_sleep_extras(cur, SENTINEL_USER_ID, start, end)

    assert float(extras["skin_temp_c"]) == 32.0, extras
