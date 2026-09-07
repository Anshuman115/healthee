"""Pure shaping tests (no DB): the sleep stage timeline + totals, the sport-code
names, the trivial-finding filter, the PAI gap, and the recovery-guidance override."""

from __future__ import annotations

from datetime import UTC, datetime

from healthee.read.common import sport_name
from healthee.read.findings import _shape, is_trivial_finding
from healthee.read.recovery_guidance import _base_guidance
from healthee.read.sleep_common import STAGE_NAME, stage_timeline, stage_totals


def _ms(dt: datetime) -> int:
    return int(dt.timestamp() * 1000)


def test_stage_names_match_zeppos_codes() -> None:
    assert STAGE_NAME == {4: "light", 5: "deep", 7: "awake", 8: "rem"}


def test_stage_timeline_offsets() -> None:
    start = datetime(2026, 6, 20, 23, 0, tzinfo=UTC)
    stages = [
        [_ms(start), _ms(start) + 60_000 * 30, 4],  # 30 min light from 0
        [_ms(start) + 60_000 * 30, _ms(start) + 60_000 * 50, 8],  # 20 min REM from 30
    ]
    out = stage_timeline(stages, start)
    assert [s["stage"] for s in out] == ["light", "rem"]
    assert out[0]["start_offset_min"] == 0
    assert out[0]["end_offset_min"] == 30
    assert out[1]["duration_min"] == 20


def test_stage_timeline_skips_malformed() -> None:
    start = datetime(2026, 6, 20, 23, 0, tzinfo=UTC)
    assert stage_timeline([[1, 2]], start) == []  # too-short triple dropped
    assert stage_timeline(None, start) == []


def test_stage_totals_defaults_nulls_to_zero() -> None:
    assert stage_totals(200, None, 90, 0) == {"light": 200, "deep": 0, "rem": 90, "awake": 0}


def test_sport_name_known_and_fallback() -> None:
    assert sport_name(1) == "Outdoor run"
    assert sport_name(14) == "Strength"
    assert sport_name(9999) == "Activity"  # unknown → generic label
    assert sport_name(None) == "Activity"


def test_trivial_finding_definitional_pairs() -> None:
    assert is_trivial_finding(_f("steps_total", "distance_m_daily"))  # explicit pair
    assert is_trivial_finding(_f("steps_total", "active_calories"))  # movement cluster
    assert is_trivial_finding(_f("sleep_dim_timing", "sleep_dim_duration"))  # same prefix


def test_trivial_finding_keeps_real_cross_domain() -> None:
    assert not is_trivial_finding(_f("caffeine", "sleep_health_score_4dim", eff=-0.42, n=24))


def test_trivial_finding_rejects_near_perfect() -> None:
    assert is_trivial_finding(_f("mood", "energy", eff=0.97, n=40))  # too high
    assert is_trivial_finding(_f("mood", "energy", eff=0.88, n=12))  # high on small n


def test_finding_shape_keys() -> None:
    shaped = _shape(_f("caffeine", "sleep_health_score_4dim", eff=-0.42, n=24))
    assert set(shaped) == {
        "kind",
        "metric_a",
        "metric_b",
        "event_kind",
        "lag_days",
        "description_raw",
        "effect_size",
        "effect_metric",
        "q_value",
        "n_samples",
        "research_note_ids",
        "points",
        "points_n",
        "points_truncated",
    }


def _f(a: str, b: str, *, eff: float = 0.5, n: int = 30) -> dict:
    return {
        "kind": "pairwise_lag",
        "metric_a": a,
        "metric_b": b,
        "event_kind": None,
        "lag_days": 0,
        "description": f"{a} ↔ {b}",
        "effect_size": eff,
        "effect_metric": "rho",
        "q_value": 0.02,
        "n_samples": n,
        "research_note_ids": [],
    }


def test_illness_override_replaces_the_band_text() -> None:
    """Both real severities override; no severity leaves the ported band text alone."""
    assert _base_guidance("high", None).startswith("Well recovered — a good day to push")
    for severity in ("moderate", "high"):
        assert "illness signal is active" in _base_guidance("high", severity)
        assert "good day to push" not in _base_guidance("high", severity)


def test_unknown_illness_severity_fails_safe_toward_rest() -> None:
    """The fail-safe direction.

    The schema CHECK-constrains severity to moderate|high, so this is unreachable
    through the DB — which is exactly why it is asserted here. A severity the code does
    not recognise must never fall through to "a good day to push"; that silent
    fall-through is the bug class the override exists to kill, and a future migration
    adding a third severity must not quietly resurrect it.
    """
    guidance = _base_guidance("high", "catastrophic")
    assert "good day to push" not in guidance
    assert guidance == _base_guidance("high", "high")  # strictest wins
