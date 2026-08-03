"""The coach's pivot must name the INSTRUMENT behind a VO₂max (#120).

[[hr_reserve_vo2max]] Directive 4: "Never average the two methods … **State which one
produced the value.**" #117 put that on ``/api/today.vo2max``; the coach got a bare number
in ``context._recent_daily``'s compact pivot and could therefore call a questionnaire
estimate a measurement — the #108 conflation through a different door.

Three things are pinned here: the instrument reaches the context for each of the three
tiers, a Jurca-derived number cannot be described to the model in the vocabulary of a
measurement, and the compact format is still compact — the pivot's cost is bounded and
every unregistered cell is byte-identical to before.
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
from healthee.insights.coach_context import DEFAULT_COACH_DAYS
from healthee.insights.context import _RECENT_COLUMNS, _recent_daily
from healthee.insights.context_provenance import instrument_legends, instrument_tag

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "analytics"))
import _seed_db as sd  # type: ignore[import-not-found]  # noqa: E402 — shared v2 seed helpers

# The tags a measurement may carry. ``model`` is deliberately not among them: the whole
# point of the suffix is that these two categories cannot be swapped by a sentence.
_MEASURED_TAGS = {"graded", "reserve"}

# The longest suffix the pivot may append to one value, " reserve", INCLUDING its leading
# space. Measured with tiktoken/cl100k_base against the real cell text: "| 39.6 |" is 6
# tokens and "| 39.6 reserve |", "| 39.6 graded |" and "| 39.6 model |" are 7 — so the
# budget below is one token per tagged value, and this character bound is what a test can
# assert without pulling a tokenizer into the suite.
_MAX_SUFFIX_CHARS = len(" reserve")

# The legend's ceiling in characters. Measured at 58 cl100k tokens / 242 characters today;
# 260 leaves room for a wording fix and refuses a paragraph. The pivot rides inside EVERY
# prompt the product sends and #105 established prompt size as the dominant cost driver,
# so this number is a decision, not a formality.
_MAX_LEGEND_CHARS = 260

# The whole provenance addition, worst case: the legend plus a tagged VO₂max on every day
# of the coach's 30-day window. 500 characters ≈ **88 cl100k tokens** (58 + 30 × 1) — the
# number this change is allowed to add to a coach question, +0.11 % of the 80,435 #105
# measured. Raising it is a pricing decision and belongs in a PR that says so.
_WORST_CASE_BUDGET_CHARS = 500


def test_each_tier_reaches_the_context_under_its_own_name() -> None:
    """All three instruments are nameable, and no two share a word."""
    tags = {m: instrument_tag("vo2max_estimate", m) for m in (METHOD_GRADED, METHOD_RESERVE)}
    tags[METHOD_JURCA] = instrument_tag("vo2max_estimate", METHOD_JURCA)
    assert all(tags.values()), tags
    assert len(set(tags.values())) == 3, tags


def test_a_jurca_number_is_not_offered_in_the_vocabulary_of_a_measurement() -> None:
    """The model tier gets its own word, and the legend says it measured nothing."""
    assert instrument_tag("vo2max_estimate", METHOD_JURCA) not in _MEASURED_TAGS
    legend = instrument_legends(["vo2max_estimate"])[0]
    assert "measures no exertion" in legend
    # And the two that ARE measurements say so, or the distinction is only half-drawn.
    assert legend.count("measured on a") == 2


def test_a_row_written_before_the_tiered_writer_reads_as_the_model() -> None:
    """No stored ``method`` means Jurca — never blank, and never a measurement.

    ``vo2max_tier.method_of`` owns that default so the payload and this pivot cannot
    disagree; here we pin the consequence the coach sees.
    """
    assert instrument_tag("vo2max_estimate", None) == instrument_tag(
        "vo2max_estimate", METHOD_JURCA
    )
    assert instrument_tag("vo2max_estimate", "") not in _MEASURED_TAGS


def test_an_unregistered_metric_and_an_unknown_instrument_stay_silent() -> None:
    """Silence, not another instrument's word — and every other cell unchanged."""
    assert instrument_tag("rhr_daily", None) is None
    assert instrument_tag("steps_total", "strap_0x16") is None
    assert instrument_tag("vo2max_estimate", "some_future_instrument") is None


def test_the_legend_ships_once_and_only_for_a_metric_that_tagged() -> None:
    assert instrument_legends([]) == []
    assert instrument_legends(["rhr_daily"]) == []
    assert len(instrument_legends(["vo2max_estimate", "vo2max_estimate"])) == 1


def test_the_added_prompt_cost_stays_inside_its_measured_budget() -> None:
    """The compact pivot stays compact: ≤ 88 cl100k tokens on the coach's widest window.

    Measured with tiktoken/cl100k_base: 58 tokens for the legend plus one token per tagged
    value, so a 30-day window carrying a VO₂max every day costs +88 input tokens against
    the 80,435 #105 measured per coach question — **+0.11 %**. A window with no VO₂max row
    costs zero. This test asserts the two components that make that arithmetic true.
    """
    legend = instrument_legends(["vo2max_estimate"])[0]
    assert len(legend) <= _MAX_LEGEND_CHARS, len(legend)
    for method in (METHOD_GRADED, METHOD_RESERVE, METHOD_JURCA):
        tag = instrument_tag("vo2max_estimate", method)
        assert tag is not None
        assert " " not in tag  # one WORD — one token, not a phrase
        assert len(f" {tag}") <= _MAX_SUFFIX_CHARS, tag
    worst_case_chars = len(legend) + DEFAULT_COACH_DAYS * _MAX_SUFFIX_CHARS
    assert worst_case_chars <= _WORST_CASE_BUDGET_CHARS, worst_case_chars


# ── the seeded-DB half: the instrument actually reaches the assembled context ────────


def _seed_three_instruments() -> list:
    """Three consecutive days of ``vo2max_estimate``, one per instrument."""
    migrate.apply_migrations()
    days = sd.recent_days(3)
    sd.clean()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily_with_flags(
            cur,
            "vo2max_estimate",
            {
                days[0]: (39.6, {"method": METHOD_GRADED}),
                days[1]: (41.7, {"method": METHOD_RESERVE}),
                days[2]: (40.6, {"method": METHOD_JURCA}),
            },
        )
    return days


@pytest.mark.integration
def test_the_pivot_names_the_instrument_for_every_tier(db: None) -> None:  # noqa: ARG001
    _seed_three_instruments()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        md = _recent_daily(cur, SENTINEL_USER_ID, SENTINEL_TZ, days=DEFAULT_COACH_DAYS)
    assert "39.6 graded" in md
    assert "41.7 reserve" in md
    assert "40.6 model" in md
    # The legend decodes them, exactly once.
    assert md.count("Never average them") == 1


@pytest.mark.integration
def test_the_tagged_pivot_still_parses_as_the_compact_table(db: None) -> None:  # noqa: ARG001
    """A suffix inside a cell must not change the table's shape."""
    _seed_three_instruments()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        md = _recent_daily(cur, SENTINEL_USER_ID, SENTINEL_TZ, days=DEFAULT_COACH_DAYS)
    rows = [ln for ln in md.splitlines() if ln.startswith("| ")]
    header, *body = rows
    width = header.count("|")
    assert width == len(_RECENT_COLUMNS) + 2
    assert body, md
    for line in body:
        assert line.count("|") == width, line


@pytest.mark.integration
def test_a_pivot_with_no_vo2max_row_costs_nothing(db: None) -> None:  # noqa: ARG001
    """No tagged value ⇒ no legend, no suffix — the unchanged prompt for most owners."""
    migrate.apply_migrations()
    days = sd.recent_days(3)
    sd.clean()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily(cur, "rhr_daily", dict.fromkeys(days, 54.0))
        md = _recent_daily(cur, SENTINEL_USER_ID, SENTINEL_TZ, days=DEFAULT_COACH_DAYS)
    assert "Recent daily metrics" in md
    assert "Never average them" not in md
    assert "model" not in md
