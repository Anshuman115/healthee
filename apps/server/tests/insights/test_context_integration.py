"""Seeded-DB regression test for the v2-native context builder (seam bug, hole #3).

The legacy "Recent daily metrics" section filtered ``source='zepp_cloud'`` and used
v1 metric names, so on v2 data it returned EMPTY (INTELLIGENCE §5.4). Here we seed
v2 ``derived_daily`` rows and assert the rebuilt builder produces a non-empty table
carrying those numbers — a non-empty result IS the proof the seam is fixed.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from healthee.core.db import transaction
from healthee.db import migrate
from healthee.insights.context import _recent_daily, build_context

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "analytics"))
import _seed_db as sd  # type: ignore[import-not-found]  # noqa: E402 — shared v2 seed helpers

pytestmark = pytest.mark.integration


def _seed_recent() -> None:
    migrate.apply_migrations()
    days = sd.recent_days(20)
    with transaction() as cur:
        sd.clean(cur)
        sd.seed_daily(cur, "rhr_daily", {d: 54.0 + (i % 3) for i, d in enumerate(days)})
        sd.seed_daily(cur, "steps_total", {d: 6000.0 + 100 * i for i, d in enumerate(days)})
        sd.seed_daily(cur, "hrv_sleep_avg", {d: 40.0 + (i % 4) for i, d in enumerate(days)})
        sd.seed_daily(
            cur, "sleep_health_score_4dim", {d: 2.0 + (i % 2) for i, d in enumerate(days)}
        )


def test_recent_daily_metrics_nonempty_on_v2_data(db: None) -> None:  # noqa: ARG001
    _seed_recent()
    with transaction() as cur:
        md = _recent_daily(cur, days=20)
    assert md  # legacy returned "" here on v2 data — non-empty is the regression proof
    assert "Recent daily metrics" in md
    assert "RHR" in md and "steps" in md
    # a seeded value must actually appear in the table
    assert "54" in md


def test_build_context_is_nonempty_on_v2_data(db: None) -> None:  # noqa: ARG001
    _seed_recent()
    md = build_context(days=20, question="how is my resting heart rate?")
    assert md
    assert "Recent daily metrics" in md
    assert "Personal baselines" in md
