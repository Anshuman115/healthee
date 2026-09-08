"""The SLEEP half of ``docs/BACKEND_AUDIT.md`` section A.

Split from ``test_honesty_severity_a.py`` at the 400-line gate, and it is the right split
rather than an arbitrary one: A5, A6 and A12 are one chain about what the strap recorded
overnight, and they share a seeded night. The other suite is about load, fitness, recovery
and history and shares nothing with them but the database.

Each test asserts the PROPERTY the defect violated, not the shape of the fix. The paired
mutations are in ``tests/read/mutations.sh``.

A5  a session with no stage breakdown yields no stage totals and no TST, rather than a
    night of zero sleep. The zeros were born at INGEST, not in ``read/``: the columns were
    ``NOT NULL DEFAULT 0`` until `0018`, so the guards downstream were dead code.
A6  a partial re-push cannot replace a measured value with a model default.
A12 the bedtime-band verdict needs the seven nights the SRI needs — the same payload
    refused the cited statistic and published an invented one in its place.
"""

from __future__ import annotations

from datetime import timedelta

import pytest
from tests.read._severity_a_seed import STAGED_MINUTES, daily, night, reset

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.ingest.models import SleepIn
from healthee.ingest.upsert import upsert_sleep
from healthee.read.sleep_extras import last_sleep, latest_main_session, sleep_consistency
from healthee.read.sleep_page import sleep_page

pytestmark = pytest.mark.integration


# ── A5. an unstaged night is not a night of zero sleep ───────────────────────


@pytest.mark.usefixtures("db")
def test_a_night_with_no_stage_breakdown_reports_no_stages_and_no_total() -> None:
    """The defect end to end: zeros here became four zero-height bars on the chart.

    `duration_min` is the loud one — summing three absent stages gave a measured **0
    minutes of sleep** for a night nobody staged, and the app's fallback then substituted
    that for a correct withhold of `tst_min`.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        night(cur, today, staged=False)
        block = last_sleep(latest_main_session(cur, SENTINEL_USER_ID, SENTINEL_TZ))

    assert block is not None
    assert block["totals"] is None
    assert block["duration_min"] is None


@pytest.mark.usefixtures("db")
def test_a_staged_night_still_reports_its_totals_and_its_tst() -> None:
    """The withhold must be about the absence, not about the metric."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        night(cur, today, staged=True)
        block = last_sleep(latest_main_session(cur, SENTINEL_USER_ID, SENTINEL_TZ))

    assert block is not None
    assert block["totals"] == {"light": 240, "deep": 120, "rem": 60, "awake": 20}
    assert block["duration_min"] == 420


@pytest.mark.usefixtures("db")
def test_a_date_with_no_session_at_all_sends_no_stage_object() -> None:
    """C1, the same remedy: absence of a session is not a measurement of four zeros."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        daily(cur, today, "rhr_daily", 55.0)
        nights = sleep_page(cur, SENTINEL_USER_ID, SENTINEL_TZ)["nights"]

    stub = next(n for n in nights if n["date"] == today.isoformat())
    assert stub["stages"] is None
    assert stub["tst_min"] is None  # `duration_min` was renamed by C2


# ── A6. a partial re-push cannot clobber a complete row ──────────────────────


@pytest.mark.usefixtures("db")
def test_a_repush_without_the_stage_breakdown_keeps_the_one_on_file() -> None:
    """`ON CONFLICT … SET col = EXCLUDED.col` replaced measured data with defaults.

    Latent rather than live — the shipped client sends complete records — but
    `/ingest/helio` is reachable by any device token including an older build, and this is
    the mechanism by which A5's zeros could overwrite a night recorded correctly.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        start_utc = night(cur, today, staged=True)
        partial = SleepIn(
            start_ts=int(start_utc.timestamp() * 1000),
            end_ts=int((start_utc + timedelta(hours=7)).timestamp() * 1000),
            kind="main",
        )
        upsert_sleep(cur, SENTINEL_USER_ID, [partial], lambda _s: False)
        cur.execute(
            "SELECT rem_min, light_min, deep_min, wake_min FROM sleep_session "
            "WHERE user_id = %s AND start_ts = %s",
            (SENTINEL_USER_ID, start_utc),
        )
        row = cur.fetchone()

    # From the seed, never a literal here: the assertion and what was written have to
    # move together, or a re-seeded fixture would quietly stop testing the clobber.
    assert row == STAGED_MINUTES


# ── A12. the band verdict needs the SRI's seven nights ───────────────────────


@pytest.mark.usefixtures("db")
def test_three_nights_publish_no_band_verdict_beside_a_withheld_sri() -> None:
    """The endpoint refused the cited statistic and substituted an invented one.

    `_sri_block` withholds the SRI under seven days per Directive 4, and the same payload
    then published an ungraded, uncited regularity verdict from three nights — including
    "top-quintile territory", a population claim with no reference distribution behind it.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        for back in range(3):
            night(cur, today - timedelta(days=back), staged=True)
        payload = sleep_consistency(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload["nights"] == 3
    assert payload["onset_band"] is None
    assert payload["onset_band_h"] is None
    assert payload["late"] is None
    assert payload["band_min_nights"] == 7
    # The raw range is still served, under the name that describes it.
    assert payload["onset_range_h_raw"] is not None


@pytest.mark.usefixtures("db")
def test_seven_nights_earn_a_band_and_it_claims_no_population_percentile() -> None:
    """The floor admits at seven, and the verdict cites behaviour rather than a quintile."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        reset(cur)
        for back in range(7):
            night(cur, today - timedelta(days=back), staged=True)
        payload = sleep_consistency(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload["nights"] == 7
    assert isinstance(payload["onset_band"], str)
    assert "quintile" not in payload["onset_band"]
