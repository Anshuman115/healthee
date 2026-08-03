"""No statistic handed to the model is computed across two instruments (#125).

[[hr_reserve_vo2max]] Directive 4: "Never average the two methods. They are different
instruments; a blended number has no validation behind it." #117 made that structurally
impossible inside ``derive/vo2max_tier.py`` — one instrument is picked before any median
is taken. It was NOT true of what the coach was handed: ``insights/context`` reduced
``vo2max_estimate`` across whatever instruments the window held, in a z-score, a 7-day
mean and a 30-day median (plus the anomaly scan's own z).

Not theoretical for this owner: his graded 39.6 (2026-06-15) and reserve 41.7 (06-18) sit
three days apart, inside all three windows, and #117 measured their blend at **40.7**
against his single-instrument **40.6** — one tenth, invisible to inspection. So this file
pins the guarantee three ways: the pure guard blocks a mixed window, the assembled context
carries no reduced number for a blocked metric, and a single-instrument window still
reduces AND says whose number it is.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.derive.vo2max import METHOD_JURCA
from healthee.derive.vo2max_reserve import METHOD_RESERVE
from healthee.derive.vo2max_submax import METHOD_GRADED
from healthee.insights.context import (
    _INSTRUMENT_WINDOW_DAYS,
    _instrument_guard,
    build_context,
)
from healthee.insights.context_provenance import guard_from_rows, registered_metrics

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "analytics"))
import _seed_db as sd  # type: ignore[import-not-found]  # noqa: E402 — shared v2 seed helpers

# The suppression block's ceiling in characters. One heading plus one line per blocked
# metric; measured with tiktoken/cl100k_base at 319 characters / **71 tokens** for a
# two-instrument window and 329 / **73** for all three tiers at once, against the 80,435
# tokens #105 measured per coach question — **+0.09 %**, and only on a window that
# actually mixed. 380 leaves room for a wording fix and refuses a paragraph. Raising it is
# a pricing decision and belongs in a PR that says so.
_MAX_MIXED_BLOCK_CHARS = 380

# What the label costs when the window is CLEAN: " (graded)" is the longest of the three,
# appended to the metric name in each of the three tables. Three sections × one metric ×
# 9 characters ≈ 3 cl100k tokens for the whole context.
_MAX_LABEL_SUFFIX_CHARS = len(" (graded)")


def _rows(*pairs: tuple[str, object]) -> list[tuple[str, object]]:
    return list(pairs)


# ── the pure guard: the guarantee, testable without a database ──────────────────────


def test_two_instruments_in_the_window_block_every_reduction() -> None:
    guard = guard_from_rows(
        _rows(("vo2max_estimate", METHOD_GRADED), ("vo2max_estimate", METHOD_JURCA)), 44
    )
    assert guard.blocks("vo2max_estimate")
    # And it says so where the numbers would have been, naming both instruments.
    section = guard.section()
    assert "vo2max_estimate" in section
    assert "graded + model" in section
    assert "hr_reserve_vo2max" in section


def test_one_instrument_reduces_and_the_aggregate_names_it() -> None:
    guard = guard_from_rows(_rows(("vo2max_estimate", METHOD_JURCA)), 44)
    assert not guard.blocks("vo2max_estimate")
    assert guard.label("vo2max_estimate") == "vo2max_estimate (model)"
    assert guard.section() == ""


def test_an_unnamed_instrument_is_still_a_second_instrument() -> None:
    """A method this vocabulary has no word for must not be silently pooled with one it
    does — silence about the WORD is not permission to average the VALUES."""
    guard = guard_from_rows(
        _rows(("vo2max_estimate", METHOD_JURCA), ("vo2max_estimate", "future_instrument")), 44
    )
    assert guard.blocks("vo2max_estimate")
    assert "future_instrument" in guard.section()


def test_an_unregistered_metric_is_never_blocked() -> None:
    """Every metric this module cannot speak for reduces exactly as it did before."""
    guard = guard_from_rows(_rows(("rhr_daily", None), ("steps_total", "strap_0x16")), 44)
    assert not guard.blocks("rhr_daily")
    assert not guard.blocks("steps_total")
    assert guard.label("rhr_daily") == "rhr_daily"
    assert guard.section() == ""


def test_a_row_with_no_stamp_is_the_model_tier_not_a_second_instrument() -> None:
    """Pre-#117 rows carry no ``method`` and are all Jurca (``vo2max_tier.method_of``)."""
    guard = guard_from_rows(_rows(("vo2max_estimate", None), ("vo2max_estimate", METHOD_JURCA)), 44)
    assert not guard.blocks("vo2max_estimate")


def test_the_suppression_block_stays_inside_its_measured_budget() -> None:
    guard = guard_from_rows(
        _rows(
            ("vo2max_estimate", METHOD_GRADED),
            ("vo2max_estimate", METHOD_RESERVE),
            ("vo2max_estimate", METHOD_JURCA),
        ),
        44,
    )
    assert len(guard.section()) <= _MAX_MIXED_BLOCK_CHARS, len(guard.section())
    clean = guard_from_rows(_rows(("vo2max_estimate", METHOD_GRADED)), 44)
    suffix = clean.label("vo2max_estimate").removeprefix("vo2max_estimate")
    assert len(suffix) <= _MAX_LABEL_SUFFIX_CHARS, suffix


# ── the seeded-DB half: no blended number reaches the assembled context ──────────────


def _seed(rows: dict, extra: dict | None = None) -> None:
    migrate.apply_migrations()
    sd.clean()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily_with_flags(cur, "vo2max_estimate", rows)
        for metric, values in (extra or {}).items():
            sd.seed_daily(cur, metric, values)


def _mixed_window() -> dict:
    """The owner's real pair — a graded 39.6 and a reserve 41.7, three days apart."""
    days = sd.recent_days(4)
    return {days[0]: (39.6, {"method": METHOD_GRADED}), days[3]: (41.7, {"method": METHOD_RESERVE})}


@pytest.mark.integration
def test_a_mixed_window_yields_no_mean_median_or_z_score(db: None) -> None:  # noqa: ARG001
    _seed(_mixed_window())
    md = build_context(SENTINEL_USER_ID, SENTINEL_TZ, days=30)
    # The blend of that pair is 40.65 → 40.7 or 40.6 depending on the reduction. Neither
    # may appear, and neither may any aggregate ROW for the metric.
    for section in ("Today snapshot", "Trend summary", "Personal baselines"):
        table = _section(md, section)
        assert "vo2max_estimate" not in table, f"{section}:\n{table}"
    assert "Not reduced to one number" in md
    assert "graded + reserve" in md


@pytest.mark.integration
def test_a_mixed_window_reports_no_anomaly_either(db: None) -> None:  # noqa: ARG001
    """An anomaly is a z-score against the same mixed baseline — same defect, same fix.

    The graded days carry real spread on purpose: a flat history has MAD 0, ``z_score``
    returns ``None``, and the scan would find nothing whatever the guard did — a seed that
    cannot produce the anomaly cannot prove it was suppressed.
    """
    days = sd.recent_days(20)
    rows = {d: (39.0 + (i % 4) * 0.4, {"method": METHOD_GRADED}) for i, d in enumerate(days[:-1])}
    rows[days[-1]] = (60.0, {"method": METHOD_JURCA})  # a |z| ≥ 2 outlier, on the OTHER tier
    # The POSITIVE CONTROL: the same shape on an unregistered metric, which must still be
    # flagged. Without it "no anomaly" would pass on a seed that produces no anomaly at all.
    control = {d: 50.0 + (i % 4) * 0.4 for i, d in enumerate(days[:-1])} | {days[-1]: 80.0}
    _seed(rows, extra={"rhr_daily": control})
    md = build_context(SENTINEL_USER_ID, SENTINEL_TZ, days=30)
    anomalies = _section(md, "Recent anomalies")
    assert "rhr_daily" in anomalies, md
    assert "vo2max_estimate" not in anomalies, anomalies
    assert "Not reduced to one number" in md


@pytest.mark.integration
def test_a_clean_window_still_reduces_and_names_its_instrument(db: None) -> None:  # noqa: ARG001
    days = sd.recent_days(20)
    _seed({d: (40.6 + (i % 3) * 0.1, {"method": METHOD_JURCA}) for i, d in enumerate(days)})
    md = build_context(SENTINEL_USER_ID, SENTINEL_TZ, days=30)
    assert "Not reduced to one number" not in md
    for section in ("Today snapshot", "Trend summary", "Personal baselines"):
        table = _section(md, section)
        assert "vo2max_estimate (model)" in table, f"{section}:\n{table}"


@pytest.mark.integration
def test_the_guard_reads_every_registered_metric_over_one_window(db: None) -> None:  # noqa: ARG001
    """One window for all four sections — two would be two answers to one question."""
    days = sd.recent_days(_INSTRUMENT_WINDOW_DAYS)
    _seed(
        {days[0]: (39.6, {"method": METHOD_GRADED}), days[-1]: (40.6, {"method": METHOD_JURCA})},
        extra={"rhr_daily": dict.fromkeys(days, 54.0)},
    )
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        guard = _instrument_guard(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert guard.window_days == _INSTRUMENT_WINDOW_DAYS
    assert set(guard.by_metric) <= set(registered_metrics())
    # The oldest day is inside the window an anomaly's own baseline can reach, so it counts.
    assert guard.blocks("vo2max_estimate")


def _section(md: str, heading: str) -> str:
    """The markdown between ``heading`` and the next ``##``, or '' when it is absent."""
    blocks = [b for b in md.split("\n\n") if b.lstrip().startswith("## ") and heading in b]
    return "\n".join(blocks)
