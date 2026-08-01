"""#89 · the surfaces actually CARRY data coverage — the half that was missing.

``analytics/coverage.py`` defines the number and ``tests/analytics/test_coverage.py``
pins the definition. This file pins the thing the issue was actually about: INTELLIGENCE
§3 promised the metadata on the ANSWER, and no surface carried it. A definition nobody
publishes is the same silence in a different place.

What each test asserts is that the coverage a surface publishes is measured over the
metrics THAT surface declared and the window IT asked for — not a house default that
happens to look plausible.
"""

from __future__ import annotations

import sys
from datetime import timedelta
from pathlib import Path

import pytest
from tests.insights._stub import StubLLM

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.db import migrate
from healthee.insights import coach, coaching, grounded, surfaces
from healthee.insights.grounded import grounded_ask

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "analytics"))
import _seed_db as sd  # type: ignore[import-not-found]  # noqa: E402 — shared v2 seed helpers

pytestmark = pytest.mark.integration


def _seed_days(metric: str, n: int, value: float = 55.0) -> None:
    migrate.apply_migrations()
    sd.clean("kv")
    today = user_today(SENTINEL_TZ)
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily(cur, metric, {today - timedelta(days=i): value for i in range(n)})


def test_grounded_ask_reports_coverage_of_the_metrics_it_declared(
    db: None,  # noqa: ARG001 — gates on the DB
) -> None:
    _seed_days("rhr_daily", 5)
    result = grounded_ask(
        "How is my resting heart rate?",
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        metrics=["rhr_daily", "hrv_sleep_avg"],
        context_days=14,
        client=StubLLM(),
    )
    assert result.data_coverage == {
        "window_days": 14,
        "days_with_data": {"rhr_daily": 5, "hrv_sleep_avg": 0},
    }


def test_a_fallback_still_carries_coverage(db: None) -> None:  # noqa: ARG001
    """Coverage is a property of the DATA, not of whether the answer survived its gates.

    On a fallback it is the most useful field in the payload: it is what says whether
    asking again tomorrow would help.
    """
    _seed_days("rhr_daily", 5)
    result = grounded_ask(
        "How is my resting heart rate?",
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        metrics=["rhr_daily"],
        context_days=14,
        client=StubLLM(["Your low HRV is likely due to accumulated training load."]),
    )
    assert result.validated is False
    assert result.data_coverage == {"window_days": 14, "days_with_data": {"rhr_daily": 5}}


def test_a_pre_llm_refusal_carries_no_coverage(db: None) -> None:  # noqa: ARG001
    """Nothing was built, nothing was read — `None` says that, and 0/14 would lie."""
    _seed_days("rhr_daily", 5)
    result = grounded_ask(
        "I have crushing chest pain — what medication should I take?",
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        metrics=["rhr_daily"],
        client=StubLLM(),
    )
    assert result.refused is True
    assert result.data_coverage is None


def test_the_sleep_insight_card_publishes_coverage(
    db: None,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The surface's own metric list and its own 14-day window, straight into the payload."""
    _seed_days("sleep_regularity_index", 11, value=80.0)
    monkeypatch.setattr(grounded, "get_client", lambda: StubLLM())
    payload = surfaces.sleep_insight(SENTINEL_USER_ID, SENTINEL_TZ)
    assert payload["data_coverage"]["window_days"] == 14
    assert payload["data_coverage"]["days_with_data"]["sleep_regularity_index"] == 11


def test_a_warmed_coaching_line_publishes_coverage_over_its_own_window(
    db: None,  # noqa: ARG001
) -> None:
    """`sleep_tonight` asks for 28 days, so its coverage is quoted over 28 — not 14."""
    _seed_days("sleep_debt_min", 20, value=45.0)
    line = coaching.warm_sleep_tonight(SENTINEL_USER_ID, SENTINEL_TZ, client=StubLLM())
    assert line["data_coverage"]["window_days"] == 28
    assert line["data_coverage"]["days_with_data"]["sleep_debt_min"] == 20


def test_the_coach_reports_coverage_of_the_metrics_its_tools_read(
    db: None,  # noqa: ARG001
) -> None:
    """The coach declares no metric list; its numbers come only from tools, so they are it."""
    _seed_days("steps_total", 9, value=8000.0)
    invocations = [
        {"tool": "query_metric", "args": {"metric": "steps_total", "days": 30}, "result": {}},
        {"tool": "log_entry", "args": {"kind": "water"}, "result": {"ok": True}},
    ]
    metrics = coach._metrics_read(invocations)
    assert metrics == ["steps_total"]


def test_a_coach_turn_that_read_nothing_still_names_its_window(
    db: None,  # noqa: ARG001
) -> None:
    """An empty map is "read no metric directly", which is not "you have no data"."""
    _seed_days("steps_total", 9, value=8000.0)
    result = coach.run_coach(
        [{"role": "user", "content": "In general, how does alcohol before bed affect sleep?"}],
        SENTINEL_USER_ID,
        SENTINEL_TZ,
        client=StubLLM(),
    )
    assert result.data_coverage == {
        "window_days": coach.DEFAULT_COACH_DAYS,
        "days_with_data": {},
    }
