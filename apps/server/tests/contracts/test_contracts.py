"""Contract tests: every read endpoint's live response must CONFORM to its committed
snapshot (same keys + value types), and a set of deterministic derived numbers must
match exactly. This is the regression bed guarding the mobile app's expectations.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from tests.contracts.endpoints import call_all
from tests.contracts.shape import assert_conforms

pytestmark = pytest.mark.integration

_SNAPSHOT_DIR = Path(__file__).resolve().parents[4] / "packages" / "contracts" / "snapshots"


def _snapshot(name: str) -> dict:
    return json.loads((_SNAPSHOT_DIR / f"{name}.json").read_text())


@pytest.fixture
def responses(seeded_client: tuple) -> dict:
    client, headers = seeded_client
    return call_all(client, headers)


_ENDPOINTS = [
    "today",
    "sleep",
    "sleep_health_score",
    "sleep_consistency",
    "activity",
    "history",
    "profile",
    "log_recent",
    "gps_list",
    "log_post",
    "workout",
    "gps_detail",
]


@pytest.mark.parametrize("name", _ENDPOINTS)
def test_response_conforms_to_snapshot(responses: dict, name: str) -> None:
    """The live response has the same nested key set + value types as the snapshot."""
    assert_conforms(responses[name], _snapshot(name), name)


def test_deterministic_derived_values(responses: dict) -> None:
    """Numbers computed deterministically from the seed match exactly (guards the
    computed-on-read formulas + the v2-native reads, not just the shape)."""
    today = responses["today"]
    assert today["vo2max"]["estimate"] == 41.5
    assert today["sleep_debt"]["performance_pct"] == 79  # 100·380/480, capped
    assert today["cardio_load"]["strain"] == 21.0  # every day is P95 → full strain
    assert today["mvpa"]["week_moderate_min"] >= 24  # from mvpa_min flags (seam fix)
    assert responses["activity"]["acwr"]["ratio"] == 1.0  # flat 30-day load
    assert responses["profile"]["weight_kg"] == 72.5


def test_today_has_every_legacy_key(responses: dict) -> None:
    """Every top-level Today key the installed app reads is present (wire-compat)."""
    expected = set(_snapshot("today"))
    assert set(responses["today"]) == expected
