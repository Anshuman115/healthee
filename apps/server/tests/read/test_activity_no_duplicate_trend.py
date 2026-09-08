"""`/api/activity` builds its VO2max block ONCE and ships its trend once (audit B1/C1).

`read/activity.py` called `vo2max_payload`, and `fitness_plan_payload` called it again.
Measured: **11 of the endpoint's 22 statements were exact repeats** of another statement
in the same request, and the identical 96-point `trend_90d` array travelled twice, byte
for byte — 12,466 of 22,401 bytes, 55.6% of the payload.

Both halves are asserted, because either alone would pass against half the defect:

* the STATEMENT half — no `vo2max_estimate` read is issued twice with the same
  arguments, plus a ratchet on the whole count (22 before, 12 after). This is the
  property that fails the moment anyone rebuilds the block instead of taking it.
* the PAYLOAD half — no other block carries a copy of `vo2max.trend_90d`, found by
  COMPARING VALUES rather than by naming the key it used to live under. A copy that came
  back under a new name is the same 6,233 bytes and would slip a key-name check
  (`HOW_WE_VERIFY.md` section 4: a derived check beats a listed one).

And the pointer that replaced it has to point somewhere: `trend_source` is resolved
against the live payload, so an alias-shaped value — a dotted path that reads fine and
resolves to nothing, the exact failure `research_notes` shipped for months — fails here.
"""

from __future__ import annotations

from datetime import timedelta

import psycopg
import pytest
from tests.read._severity_a_seed import daily, reset

from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID, user_today
from healthee.read.activity import activity_snapshot

pytestmark = pytest.mark.integration

# Enough of a trend that a duplicated copy is unmistakable, and an age + sex so the
# projection is computed rather than withheld (a withheld plan ships no trend at all).
_TREND_DAYS = 20
_VO2MAX_FLAGS = {"age_years": 35, "sex": "male", "see_ml_kg_min": 5.075, "srpa": 2}


def _seed(cur) -> None:
    reset(cur)
    today = user_today(SENTINEL_TZ)
    for n in range(_TREND_DAYS):
        daily(cur, today - timedelta(days=n), "vo2max_estimate", 40.0 + n * 0.1, _VO2MAX_FLAGS)


def _snapshot_and_statements(monkeypatch: pytest.MonkeyPatch) -> tuple[dict, list[str]]:
    """`activity_snapshot` plus every statement it issued, as SQL **and its parameters**.

    The parameters are part of the identity on purpose. `/api/activity` legitimately
    issues one SQL text several times with different arguments — `activity_metric` asks
    the same question of steps, active calories, total calories and distance — and
    counting text alone would call four different answers a repeat. A repeat is the same
    question asked twice, which is what a rebuilt block is.
    """
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        _seed(cur)
    seen: list[str] = []
    real = psycopg.Cursor.execute

    def traced(self, query, params=None, **kw):  # noqa: ANN001, ANN003, ANN202
        seen.append(f"{query} :: {params!r}")
        return real(self, query, params, **kw)

    monkeypatch.setattr(psycopg.Cursor, "execute", traced)
    try:
        with tenant_transaction(SENTINEL_USER_ID) as cur:
            del seen[:]  # drop the transaction set-up the context manager issues
            snapshot = activity_snapshot(cur, SENTINEL_USER_ID, SENTINEL_TZ)
    finally:
        monkeypatch.setattr(psycopg.Cursor, "execute", real)
    return snapshot, seen


def test_the_vo2max_block_is_read_once_per_request(monkeypatch: pytest.MonkeyPatch) -> None:
    """No `vo2max_estimate` read is issued twice with the same arguments.

    Every statement `vo2max_payload` issues names that metric, so a second call to it
    doubles this count and nothing else can. Asserted on the metric rather than on the
    whole statement list because the endpoint has ONE other same-arguments repeat, which
    this change did not cause and does not fix: `weekly_mvpa_rows` is read by both
    `mvpa_payload` (a fixed 8-day window) and `fitness_plan._week_to_date_mvpa` (week to
    date), and on a day where those two windows happen to be the same length the second
    read asks a question the first already answered. It is one statement of twelve, its
    windows genuinely differ on six days in seven, and folding them together means
    deciding which module owns the week's moderate/vigorous split — a definition question,
    not a performance one.
    """
    _snapshot, statements = _snapshot_and_statements(monkeypatch)

    vo2max_reads = [sql for sql in statements if "vo2max_estimate" in sql]
    repeats = sorted({sql for sql in vo2max_reads if vo2max_reads.count(sql) > 1})

    assert vo2max_reads, "the fixture stopped exercising the VO2max block at all"
    assert not repeats, (
        f"{len(vo2max_reads)} `vo2max_estimate` reads, {len(repeats)} of them issued "
        f"twice with the same arguments — the block is being built more than once:\n"
        f"{repeats[0][:200] if repeats else ''}"
    )


def test_the_endpoint_stays_at_twelve_statements(monkeypatch: pytest.MonkeyPatch) -> None:
    """A ratchet on the measured count, so the next doubling is visible without a bench.

    Twenty-two before this change, twelve after. The number is an upper bound on the
    fixture above, not a law — raising it is fine, raising it without knowing why is the
    thing this stops.
    """
    _snapshot, statements = _snapshot_and_statements(monkeypatch)

    assert len(statements) <= 12, (
        f"`activity_snapshot` now issues {len(statements)} statements, up from 12. "
        "If that is an honest new read, raise this number and say so; if a block is "
        "being built twice, it is the shape audit B1 named."
    )


def test_the_vo2max_trend_travels_exactly_once(monkeypatch: pytest.MonkeyPatch) -> None:
    """No other block on the payload holds a copy of it, under ANY key name."""
    snapshot, _statements = _snapshot_and_statements(monkeypatch)

    trend = snapshot["vo2max"]["trend_90d"]
    assert len(trend) == _TREND_DAYS, "the fixture has to produce a trend worth copying"

    copies = [
        (block, key)
        for block, body in snapshot.items()
        if block != "vo2max" and isinstance(body, dict)
        for key, value in body.items()
        if value == trend
    ]

    assert not copies, (
        f"the 90-day trend is on the wire more than once — also at {copies}. It was "
        "55.6% of this payload when `fitness_plan` carried its own copy."
    )


def test_the_trend_pointer_resolves_on_the_same_payload(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """`fitness_plan.trend_source` is a path, not a label — so it is walked, not read."""
    snapshot, _statements = _snapshot_and_statements(monkeypatch)

    source = snapshot["fitness_plan"]["trend_source"]
    node: object = snapshot
    for segment in source.split("."):
        assert isinstance(node, dict) and segment in node, (
            f"`fitness_plan.trend_source` is {source!r} and stops resolving at "
            f"{segment!r}. A pointer that resolves to nothing is worse than no pointer: "
            "it reads as a working reference."
        )
        node = node[segment]

    assert node == snapshot["vo2max"]["trend_90d"]
    assert node, "the pointer resolves, but to an empty list"
