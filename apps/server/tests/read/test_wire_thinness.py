"""Where the payload showed less than the data supports.

``docs/BACKEND_GAPS_FROM_UI.md`` section B. Every item here is a screen that works and
tells the truth about its own limits — and every one of those limits was the server's,
not the data's. The tests assert the number is the SAME number the other surface already
computes, or that the emitted metadata actually varies, because a key that always says
one thing is a key that proves nothing.

B1  a finding carries the paired days it was measured on, bounded and flagged.
B2  a VO₂max trend point names the instrument that read it.
B3  ``weekly_mvpa_min`` is the number ``/api/activity.mvpa.week_min`` reports.
B4  a recovery signal ships the σ its own ``z`` was divided by.
B6  a workout names why each derived figure it lacks is missing.
"""

from __future__ import annotations

import json
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

import pytest

from healthee.analytics.correlations import MAX_REPORTED_PAIRS
from healthee.analytics.stats import MIN_N, aligned_pairs
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.derive.vo2max import METHOD_JURCA
from healthee.derive.vo2max_submax import METHOD_GRADED
from healthee.read.findings import top_findings
from healthee.read.fitness import mvpa_payload
from healthee.read.recovery_signals import recovery_signals
from healthee.read.vo2max import vo2max_payload

pytestmark = pytest.mark.integration

_ZONE = ZoneInfo(SENTINEL_TZ)


def _reset(cur) -> None:
    for table in (
        "derived_daily",
        "sleep_session",
        "workout",
        "sample",
        "weight_log",
        "profile",
        "finding",
    ):
        cur.execute(f"DELETE FROM {table}")  # noqa: S608 — hardcoded table names


def _daily(cur, day: date, metric: str, value: float, flags: str = "{}") -> None:
    cur.execute(
        "INSERT INTO derived_daily (user_id, day, metric, value, flags) "
        "VALUES (%s, %s, %s, %s, %s::jsonb) "
        "ON CONFLICT (user_id, day, metric) DO UPDATE SET value = EXCLUDED.value, "
        "  flags = EXCLUDED.flags",
        (SENTINEL_USER_ID, day, metric, value, flags),
    )


def _finding(cur, points: list[dict], *, truncated: bool = False) -> None:
    cur.execute(
        "INSERT INTO finding (user_id, kind, description, metric_a, metric_b, lag_days, "
        "effect_size, effect_metric, p_value, q_value, n_samples, significant, "
        "research_note_ids, details) "
        "VALUES (%s,'pairwise_lag','caffeine ↔ sleep','caffeine','sleep_health_score_4dim',0,"
        "-0.42,'rho',0.01,0.03,%s,true,%s,%s::jsonb)",
        (
            SENTINEL_USER_ID,
            len(points),
            ["caffeine_sleep"],
            json.dumps({"points": points, "points_truncated": truncated}),
        ),
    )


def _points(end: date, n: int) -> list[dict]:
    return [
        {"date": (end - timedelta(days=n - 1 - i)).isoformat(), "a": float(i), "b": float(100 - i)}
        for i in range(n)
    ]


# ── B1. the points behind a finding ──────────────────────────────────────────


def test_the_reported_pairs_are_the_pairs_the_statistic_was_computed_from() -> None:
    """One alignment rule, so a scatter cannot disagree with the number above it.

    Pure: the lag alignment ``spearman_lag`` uses IS ``aligned_pairs``, and a day with no
    partner at the lag is in neither.
    """
    a = {date(2026, 7, d): float(d) for d in range(1, 11)}
    b = {date(2026, 7, d): float(100 - d) for d in range(2, 11)}
    same_day = aligned_pairs(a, b, 0)
    assert [p[0] for p in same_day] == [date(2026, 7, d) for d in range(2, 11)]
    lagged = aligned_pairs(a, b, 1)
    assert lagged[0] == (date(2026, 7, 1), 1.0, 98.0)
    assert len(lagged) == 9


@pytest.mark.usefixtures("db")
def test_a_served_finding_carries_the_days_behind_it() -> None:
    """Summary statistics alone are what the finding-detail screen apologised for."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _finding(cur, _points(today - timedelta(days=1), 24))
        found = top_findings(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert len(found) == 1
    assert found[0]["points_n"] == 24
    assert found[0]["points_truncated"] is False
    assert found[0]["points"][0]["a"] == 0.0
    assert found[0]["points"][-1]["b"] == 77.0


@pytest.mark.usefixtures("db")
def test_a_finding_never_plots_a_day_after_the_one_it_answers_for() -> None:
    """``docs/AS_OF_DAY.md`` section 3, applied to the points as well as to the finding.

    The bound is structural rather than inherited from the finding's own ``computed_at``
    gate: relying on another place's bound is exactly how "latest" leaks.
    """
    today = user_today(SENTINEL_TZ)
    as_of = today - timedelta(days=10)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        cur.execute(
            "UPDATE finding SET computed_at = computed_at WHERE user_id = %s", (SENTINEL_USER_ID,)
        )
        _finding(cur, _points(today, 30))
        cur.execute(
            "UPDATE finding SET computed_at = %s WHERE user_id = %s",
            (datetime.combine(as_of - timedelta(days=1), time(3), tzinfo=UTC), SENTINEL_USER_ID),
        )
        found = top_findings(cur, SENTINEL_USER_ID, SENTINEL_TZ, day=as_of)

    assert len(found) == 1
    assert found[0]["points"], "the as-of bound must not empty the plot"
    assert max(p["date"] for p in found[0]["points"]) <= as_of.isoformat()
    # Fewer points than the effect size was computed from, and the payload says so.
    assert found[0]["points_n"] < found[0]["n_samples"]
    assert found[0]["points_truncated"] is True


def test_the_payload_cap_is_a_bound_not_a_default() -> None:
    """Big enough to be a real plot, small enough to bound an unbounded history.

    The upper bound is the one that matters and it is a BUDGET, not a taste: at ~39 bytes
    a pair, ten findings on ``/api/sleep`` is 39 KB per hundred pairs, against a Today
    payload the gap report measures at ~20 KB. Raising this needs the argument at the
    constant re-made, not a bigger number.
    """
    assert MAX_REPORTED_PAIRS >= MIN_N
    assert MAX_REPORTED_PAIRS <= 120


# ── B2. a trend point names its instrument ───────────────────────────────────


@pytest.mark.usefixtures("db")
def test_a_vo2max_trend_point_names_the_instrument_that_read_it() -> None:
    """A change of ruler must not read as a change in the owner.

    The two seeded days are read by DIFFERENT instruments, so a payload that hardcoded
    one method — or defaulted every point to the same one — fails here rather than
    passing on a series that happens to be uniform.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _daily(
            cur,
            today - timedelta(days=1),
            "vo2max_estimate",
            41.0,
            json.dumps({"method": METHOD_JURCA, "age_years": 36, "sex": "male"}),
        )
        _daily(
            cur,
            today,
            "vo2max_estimate",
            46.0,
            json.dumps({"method": METHOD_GRADED, "age_years": 36, "sex": "male"}),
        )
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    assert [p["method"] for p in payload["trend_90d"]] == [METHOD_JURCA, METHOD_GRADED]


@pytest.mark.usefixtures("db")
def test_a_trend_point_with_no_stored_method_defaults_per_series() -> None:
    """An undated estimate row is Jurca (pre-#117); an undated submax row is a graded fit
    (pre-#114). One shared default would mislabel one of the two series."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _daily(
            cur,
            today,
            "vo2max_estimate",
            41.0,
            json.dumps({"age_years": 36, "sex": "male"}),
        )
        _daily(cur, today, "vo2max_submax", 43.0, "{}")
        payload = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert payload is not None
    assert payload["trend_90d"][0]["method"] == METHOD_JURCA
    assert payload["submax"]["trend"][0]["method"] == METHOD_GRADED


# ── B3. one definition of this week's MVPA ───────────────────────────────────


@pytest.mark.usefixtures("db")
def test_weekly_mvpa_is_the_number_the_activity_tab_already_reports() -> None:
    """Not a null, and not a second sum that could drift from the first.

    Two days inside the week and a day before it, so a payload that summed the whole
    8-day window rather than the week gets a different answer and fails.
    """
    today = user_today(SENTINEL_TZ)
    monday = today - timedelta(days=today.weekday())
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _daily(cur, monday - timedelta(days=1), "mvpa_min", 40.0, json.dumps({"moderate": 40}))
        _daily(cur, monday, "mvpa_min", 25.0, json.dumps({"moderate": 25}))
        _daily(cur, today, "mvpa_min", 35.0, json.dumps({"moderate": 30, "vigorous": 5}))
        _daily(
            cur,
            today,
            "vo2max_estimate",
            41.0,
            json.dumps({"method": METHOD_JURCA, "age_years": 36, "sex": "male"}),
        )
        mvpa = mvpa_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)
        vo2 = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert mvpa is not None and vo2 is not None
    expected = 25 + 35 if monday != today else 35
    assert mvpa["week_min"] == expected
    assert vo2["inputs"]["weekly_mvpa_min"] == mvpa["week_min"]


@pytest.mark.usefixtures("db")
def test_no_mvpa_rows_is_null_and_never_zero() -> None:
    """A week we cannot account for is not a week of measured stillness."""
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        _daily(
            cur,
            today,
            "vo2max_estimate",
            41.0,
            json.dumps({"method": METHOD_JURCA, "age_years": 36, "sex": "male"}),
        )
        vo2 = vo2max_payload(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert vo2 is not None
    assert vo2["inputs"]["weekly_mvpa_min"] is None


# ── B4. the spread behind a z ────────────────────────────────────────────────


@pytest.mark.usefixtures("db")
def test_a_recovery_signal_ships_the_sigma_its_z_was_divided_by() -> None:
    """Value, baseline, σ and z reconcile on the wire, so a band is drawable.

    Asserted as arithmetic rather than as presence: a σ that does not reproduce the z it
    sits beside would let a client draw a band the score was never measured against.
    """
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _reset(cur)
        for n in range(30):
            _daily(cur, today - timedelta(days=n), "rhr_daily", 55.0 + (n % 5))
        _daily(cur, today, "rhr_daily", 62.0)
        signals = recovery_signals(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert signals is not None
    rhr = next(s for s in signals["signals"] if s["name"] == "Resting HR")
    assert rhr["baseline_sd"] > 0
    assert rhr["z"] == pytest.approx((rhr["value"] - rhr["baseline"]) / rhr["baseline_sd"])
