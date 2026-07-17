"""Seeded-DB regression tests — proof the five legacy view-seam bugs are dead.

Each test seeds v2-native rows (``derived_daily`` / ``sleep_session`` /
``manual_entry`` with v2 metric names) and asserts the analytics produce real
results. On this exact data the legacy analytics returned nothing — the v1
``source='zepp_cloud'`` filter, the v1 metric names, and the NULL
``summary->>'tst_minutes'`` all read empty — so a non-empty result IS the proof
the seam is fixed. Auto-skips when no TimescaleDB is reachable.
"""

from __future__ import annotations

import sys
from datetime import date
from pathlib import Path

import pytest

from healthee.analytics import baselines, biological_age, correlations, cutoffs
from healthee.analytics.anomalies import detect
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _seed_db as sd  # noqa: E402 — shared v2-native seeding helpers

pytestmark = pytest.mark.integration


def _reset() -> None:
    migrate.apply_migrations()
    sd.clean()


# ── Bug 1 + 2: v1 metric names + source filter → baselines/anomalies empty ──


def test_baselines_and_anomalies_nonempty_on_v2_names(db: None) -> None:  # noqa: ARG001
    _reset()
    days = sd.recent_days(45)
    values = {d: 54.0 + (i % 3) for i, d in enumerate(days)}
    spike_day = days[-3]
    values[spike_day] = 95.0  # a clear high anomaly
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily(cur, "rhr_daily", values)

    # Baseline is non-empty on the v2 name (legacy read `metric_sample` → 0 rows).
    base = baselines.compute_baseline(SENTINEL_USER_ID, "rhr_daily", window_days=30)
    assert base.n > 0
    assert base.median is not None and 53 <= base.median <= 57

    anomalies = detect(
        SENTINEL_USER_ID, SENTINEL_TZ, metrics=("rhr_daily",), days_back=14, window_days=30
    )
    hits = [a for a in anomalies if a.metric == "rhr_daily" and a.direction == "high"]
    assert hits, "the seeded spike must surface as a high anomaly"
    assert hits[0].when == spike_day
    # Bug-adjacent proof: citations attach from the WP4 manifest (v2 metric name).
    assert hits[0].research_note_ids


def test_baseline_default_metrics_are_v2_native() -> None:
    # The default baseline set is the canonical v2 metric names — no v1 leftovers.
    assert "hrv_sleep_avg" in baselines.DEFAULT_DAILY_METRICS
    assert "hrv_sleep_avg_ms" not in baselines.DEFAULT_DAILY_METRICS
    assert "distance_m_daily" in baselines.DEFAULT_DAILY_METRICS
    assert "pai_today" not in baselines.DEFAULT_DAILY_METRICS


# ── Bug 3: the cutoff finder was dead on v2 (tst_minutes NULL) ───────────────


def test_cutoff_finder_reads_v2_tst(db: None) -> None:  # noqa: ARG001
    """THE named seam: legacy read TST from the always-NULL
    ``summary->>'tst_minutes'`` so EVERY night was discarded (``nights == []``)
    and the finder returned nothing. v2 reads TST from ``sleep_session`` stage
    minutes — so nights load with real TST and the finder fires end-to-end.

    The seed is the realistically-directioned effect (caffeine → SHORTER, worse
    sleep + lower HRV + higher RHR — Drake 2013): with the corrected rank-biserial
    sign, the direction gate now ACCEPTS this (the earlier inverted-sign gate only
    accepted the *wrong* direction). Proves the TST read seam AND that the finder
    fires on a realistic effect.
    """
    _reset()
    nights = sd.recent_days(30, end_offset=1)
    caffeine_nights, control_nights = nights[:15], nights[15:]
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        for d in caffeine_nights:
            sd.seed_night(cur, d, rem=60, light=200, deep=40, wake=60)  # caffeine → worse
            sd.seed_caffeine(cur, d, hour_ist=21)
        for d in control_nights:
            sd.seed_night(cur, d, rem=100, light=300, deep=100, wake=20)  # better
        _seed_night_vitals(cur, caffeine_nights, hrv=40.0, rhr=60.0)  # lower HRV, higher RHR
        _seed_night_vitals(cur, control_nights, hrv=55.0, rhr=52.0)

    # Direct proof of the exact bug: nights now load carrying real TST.
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        loaded = cutoffs._load_sleep_nights(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert loaded, "sleep nights must load (legacy discarded all — tst_minutes NULL)"
    assert all(n["tst_min"] and n["tst_min"] > 0 for n in loaded)

    # End-to-end: the finder now emits + persists a caffeine personal_cutoff.
    findings = cutoffs.compute_cutoff_findings(SENTINEL_USER_ID, SENTINEL_TZ)
    caffeine = [f for f in findings if f.event_kind == "caffeine" and f.kind == "personal_cutoff"]
    assert caffeine, "the caffeine cutoff must be found (this is the dead-bug proof)"
    tst = next(f for f in caffeine if f.details["outcome"] == "tst_min")
    # The corrected sign fix: the accepted effect goes the *realistic* way —
    # caffeine nights sleep less (median_after < median_other), and the standard
    # rank-biserial is negative (after-H group smaller). The old inverted gate
    # would have skipped this and only accepted caffeine→longer.
    assert tst.details["median_after"] < tst.details["median_other"]
    assert tst.effect_size < 0

    written = cutoffs.persist_cutoff_findings(SENTINEL_USER_ID, findings)
    assert written == len(findings)


def _seed_night_vitals(cur, nights: list[date], hrv: float, rhr: float) -> None:
    """Per-night HRV + RHR in derived_daily (the finder's other outcomes)."""
    sd.seed_daily(cur, "hrv_sleep_avg", dict.fromkeys(nights, hrv))
    sd.seed_daily(cur, "rhr_daily", dict.fromkeys(nights, rhr))


# ── Bug 4 + 5: correlations write findings from v2-native series ─────────────


def test_correlations_write_findings_from_derived_daily(db: None) -> None:  # noqa: ARG001
    _reset()
    days = sd.recent_days(25)
    steps = {d: 5000.0 + i * 100 for i, d in enumerate(days)}
    active = {d: v * 0.04 for d, v in steps.items()}  # perfectly rank-correlated
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily(cur, "steps_total", steps)
        sd.seed_daily(cur, "active_calories", active)

    findings = correlations.compute_all_findings(SENTINEL_USER_ID, SENTINEL_TZ)
    assert findings, "v2-native series must yield candidate findings"
    pair = [
        f
        for f in findings
        if {f.metric_a, f.metric_b} == {"steps_total", "active_calories"} and f.significant
    ]
    assert pair, "the strong steps↔active-calories correlation should be significant"

    from healthee.analytics.finding import get_significant_findings, persist_findings

    assert persist_findings(SENTINEL_USER_ID, findings) == len(findings)
    assert any(
        {r["metric_a"], r["metric_b"]} == {"steps_total", "active_calories"}
        for r in get_significant_findings(SENTINEL_USER_ID)
    )


# ── Biological age computes from v2 derived_daily rows ───────────────────────


def test_biological_age_from_v2_derived_daily(db: None) -> None:  # noqa: ARG001
    _reset()
    today = date.today()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_profile(cur, dob=date(1990, 6, 15), sex="male")
        sd.seed_daily(cur, "vo2max_estimate", {today: 45.0})
        sd.seed_daily(cur, "sleep_regularity_index", {today: 80.0})
        tst_rows = {d: (2.0, {"tst_min": 450}) for d in sd.recent_days(14)}
        sd.seed_daily_with_flags(cur, "sleep_health_score_4dim", tst_rows)
        result = biological_age.compute_biological_age(cur, SENTINEL_USER_ID, SENTINEL_TZ)

    assert result is not None
    terms = {c["term"] for c in result["contributions"]}
    assert {"fitness", "sleep duration", "regularity"} <= terms
    assert "biological_age" in result and "chronological_age" in result
    # VO₂max 45 > the ~41 median for the 30s bucket → the fitness term is younger.
    fitness = next(c for c in result["contributions"] if c["term"] == "fitness")
    assert fitness["delta_years"] < 0
