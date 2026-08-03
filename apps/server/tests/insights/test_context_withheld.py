"""A withheld metric must not reach the model as a bare dash (#126).

Three states used to arrive identically — as ``-`` or as nothing at all: *a gate refused
and here is what would restore it*, *it has not synced yet*, and *this owner has never had
it*. ``docs/COACH_PROMPT.md`` tells the coach to say *"what you'd need"*, and the context
structurally could not support it; a persona asked for a behaviour its context cannot
support is resolved by the model, which is invention.

Pinned here: a refusal is named with its restoring sentence, a never-recorded metric stays
silent (so the legend's account of the remaining silence is true), a current metric costs
nothing, and the whole block stays inside a measured token budget.
"""

from __future__ import annotations

import sys
from datetime import date
from pathlib import Path
from typing import cast

import pytest

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.derive._common import Cur
from healthee.derive.freshness import PROFILE_INCOMPLETE
from healthee.derive.sleep_score import SRI_WINDOW_TOO_SHORT
from healthee.insights.context import build_context
from healthee.insights.context_withheld import (
    _GATES,
    _HEADING,
    _LEGEND,
    _entry,
    _Gate,
    withheld_section,
)

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "analytics"))
import _seed_db as sd  # type: ignore[import-not-found]  # noqa: E402 — shared v2 seed helpers

# The block's ceiling in characters. Measured with tiktoken/cl100k_base: the heading plus
# the legend are 204 characters / **43 tokens** of fixed cost, and the worst case — all
# three gates refusing at once, each with its longest reason — is 940 characters / **196
# tokens**, i.e. **+0.24 %** of the 80,435-token coach question #105 measured. End to end
# over the real assembled coach prompt (``coach._initial_messages``) a stale VO₂max plus a
# refused SRI cost **+128 tokens**, and an owner with nothing withheld pays **nothing**.
# 1,050 leaves room for a wording fix and refuses a
# fourth paragraph; raising it is a pricing decision and belongs in a PR that says so.
_MAX_BLOCK_CHARS = 1050
_MAX_FIXED_CHARS = 240

# ``_entry`` only touches the cursor through the gate it is handed, so a stub gate never
# reaches it — these two cases are pure and want no database.
_NO_CURSOR = cast("Cur", None)


def test_the_fixed_half_of_the_block_stays_inside_its_measured_budget() -> None:
    """Heading + legend ride whenever ANYTHING is withheld, so they are the standing cost."""
    assert len(_HEADING) + len(_LEGEND) <= _MAX_FIXED_CHARS


def test_the_worst_case_block_stays_inside_its_measured_budget() -> None:
    """Every gate refusing at once, each with its longest sentence."""
    worst = [
        f"- {metric}: {reason} — {message}"
        for metric, gate in _GATES.items()
        for reason, message in [max(gate.messages.items(), key=lambda kv: len(kv[0]) + len(kv[1]))]
    ]
    block = "\n".join([_HEADING, *worst, _LEGEND])
    assert len(block) <= _MAX_BLOCK_CHARS, len(block)


def test_every_reason_a_gate_can_name_has_a_restoring_sentence() -> None:
    """The line's value is the remedy; a reason with no sentence would be a bare id.

    Not a completeness proof (a gate could invent a reason at runtime — :func:`_entry`
    logs and degrades if one does), but it fails the build if a message table is trimmed
    below the vocabulary it serves.
    """
    for metric, gate in _GATES.items():
        assert gate.messages, metric
        assert all(m.strip() for m in gate.messages.values()), metric


def test_an_unknown_reason_degrades_to_the_id_and_says_so(caplog) -> None:  # noqa: ANN001
    """A reason with no sentence must not invent one, and must not pass silently."""
    gate = _Gate(reason_of=lambda *_: "some_new_gate", messages={})
    with caplog.at_level("WARNING"):
        line = _entry(
            _NO_CURSOR,
            SENTINEL_USER_ID,
            SENTINEL_TZ,
            date(2026, 8, 3),
            {"m": date(2026, 8, 1)},
            "m",
            gate,
        )
    assert line == "- m: some_new_gate"
    assert "some_new_gate" in caplog.text


def test_a_metric_that_was_never_recorded_produces_no_line() -> None:
    """No stored row ⇒ absent, never 'refused' — the state the legend accounts for."""
    gate = _Gate(reason_of=lambda *_: "would_have_refused", messages={"would_have_refused": "x"})
    assert _entry(_NO_CURSOR, SENTINEL_USER_ID, SENTINEL_TZ, date(2026, 8, 3), {}, "m", gate) == ""


# ── the seeded-DB half: the block reaches the assembled context ──────────────────────


def _seed(rows: dict[str, dict[date, float]]) -> None:
    migrate.apply_migrations()
    sd.clean()
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        for metric, values in rows.items():
            sd.seed_daily(cur, metric, values)


@pytest.mark.integration
def test_a_refused_metric_arrives_named_with_what_would_restore_it(db: None) -> None:  # noqa: ARG001
    """The two gates a seeded owner with no profile and no sleep sessions actually trips."""
    old = sd.recent_days(3, end_offset=5)
    _seed(
        {
            "vo2max_estimate": dict.fromkeys(old, 40.6),
            "sleep_regularity_index": dict.fromkeys(old, 71.0),
        }
    )
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        block = withheld_section(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    assert _HEADING in block
    assert f"- vo2max_estimate: {PROFILE_INCOMPLETE} — " in block
    assert f"- sleep_regularity_index: {SRI_WINDOW_TOO_SHORT} — " in block
    # The restoring step is the point: the sentence, not just the id.
    assert "seven consecutive nights" in block
    assert _LEGEND in block


@pytest.mark.integration
def test_withheld_is_distinguishable_from_a_dash_in_the_same_context(db: None) -> None:  # noqa: ARG001
    """The pivot still prints ``-`` for the missing days; the block says which are refusals."""
    old = sd.recent_days(3, end_offset=5)
    _seed(
        {
            "vo2max_estimate": dict.fromkeys(old, 40.6),
            "rhr_daily": dict.fromkeys(sd.recent_days(8), 54.0),
        }
    )
    md = build_context(SENTINEL_USER_ID, SENTINEL_TZ, days=14)
    assert "| - |" in md  # the dash is still there — this block explains it, it does not hide it
    assert "Withheld today" in md
    assert "vo2max_estimate" in md.split("Withheld today", 1)[1].split("\n\n", 1)[0]
    # And never-recorded metrics are NOT claimed as refusals.
    assert "sleep_debt_min" not in md.split("Withheld today", 1)[1].split("\n\n", 1)[0]


@pytest.mark.integration
def test_a_current_metric_costs_nothing(db: None) -> None:  # noqa: ARG001
    """Today's row short-circuits the gate — the common path adds zero tokens."""
    today = sd.recent_days(1)
    _seed({"vo2max_estimate": dict.fromkeys(today, 40.6)})
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        assert withheld_section(cur, SENTINEL_USER_ID, SENTINEL_TZ) == ""


@pytest.mark.integration
def test_an_owner_with_no_data_at_all_is_not_told_three_things_are_refused(db: None) -> None:  # noqa: ARG001
    _seed({})
    md = build_context(SENTINEL_USER_ID, SENTINEL_TZ, days=14)
    assert "Withheld today" not in md
