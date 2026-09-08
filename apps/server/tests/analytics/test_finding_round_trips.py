"""Persisting findings costs one round-trip, not one per finding (`PERF_AUDIT.md` B2).

`persist_findings` looped `cur.execute`, so a nightly chain issued **one `INSERT INTO
finding` per finding** — 774 statements on a year of an owner's data, the largest single
group of the whole chain. Standards section 1 names this exact shape and the outage it
caused: *"bulk writes use `executemany`/pipelining (the legacy push once did one
round-trip per sample and hit 180 s timeouts)"*.

Counting statements is the only way this can be checked. The rows are identical either
way, so every assertion about CONTENT passes against the loop — which is how the loop
survived a suite that already covered what it writes. `test_job_write_isolation.py`
covers the same function for who may write; this covers how many times it asks.

`replace_findings_of_kind` gets the empty case as well, because that is the one place the
rewrite could have changed behaviour: `executemany([])` is a no-op, and the DELETE in
front of it must still run — a kind whose findings all fell below significance must end
with no rows, not with last night's.
"""

from __future__ import annotations

import psycopg
import pytest

from healthee.analytics.finding import (
    EFFECT_SPEARMAN,
    Finding,
    get_significant_findings,
    persist_findings,
    replace_findings_of_kind,
)
from healthee.core.db import tenant_transaction
from healthee.core.tenancy import SENTINEL_USER_ID

pytestmark = pytest.mark.integration

_N = 40


def _finding(i: int, *, kind: str = "pairwise_lag", significant: bool = True) -> Finding:
    return Finding(
        kind=kind,
        description=f"synthetic finding {i}",
        metric_a=f"metric_{i}",
        metric_b="rhr_daily",
        event_kind=None,
        lag_days=0,
        effect_size=0.5 + i / 1000,
        effect_metric=EFFECT_SPEARMAN,
        p_value=0.001,
        q_value=0.01,
        n_samples=30,
        significant=significant,
    )


def _count_inserts(monkeypatch: pytest.MonkeyPatch, call) -> tuple[int, int]:
    """(INSERT statements issued, rows the call reported writing)."""
    inserts = 0
    real_execute = psycopg.Cursor.execute
    real_many = psycopg.Cursor.executemany

    def traced_execute(self, query, params=None, **kw):  # noqa: ANN001, ANN003, ANN202
        nonlocal inserts
        if "INSERT INTO finding" in str(query):
            inserts += 1
        return real_execute(self, query, params, **kw)

    def traced_many(self, query, params_seq, **kw):  # noqa: ANN001, ANN003, ANN202
        nonlocal inserts
        if "INSERT INTO finding" in str(query):
            inserts += 1
        return real_many(self, query, params_seq, **kw)

    monkeypatch.setattr(psycopg.Cursor, "execute", traced_execute)
    monkeypatch.setattr(psycopg.Cursor, "executemany", traced_many)
    try:
        written = call()
    finally:
        monkeypatch.setattr(psycopg.Cursor, "execute", real_execute)
        monkeypatch.setattr(psycopg.Cursor, "executemany", real_many)
    return inserts, written


def _reset() -> None:
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        cur.execute("DELETE FROM finding WHERE user_id = %s", (SENTINEL_USER_ID,))


@pytest.mark.usefixtures("db")
def test_persisting_forty_findings_is_one_insert_statement(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """One statement for forty rows — and all forty rows are there afterwards."""
    _reset()
    findings = [_finding(i) for i in range(_N)]

    inserts, written = _count_inserts(
        monkeypatch, lambda: persist_findings(SENTINEL_USER_ID, findings)
    )

    assert written == _N
    assert inserts == 1, (
        f"{_N} findings cost {inserts} INSERT round-trips. This is the per-item "
        "round-trip standards section 1 names a 180 s legacy outage for, and it grows "
        "with the SQUARE of the metric registry."
    )
    assert len(get_significant_findings(SENTINEL_USER_ID, limit=_N + 10)) == _N


@pytest.mark.usefixtures("db")
def test_replacing_a_kind_is_one_insert_statement(monkeypatch: pytest.MonkeyPatch) -> None:
    """Same for the replace path, which had the same loop."""
    _reset()
    findings = [_finding(i, kind="personal_cutoff") for i in range(_N)]

    inserts, written = _count_inserts(
        monkeypatch,
        lambda: replace_findings_of_kind(SENTINEL_USER_ID, "personal_cutoff", findings),
    )

    assert written == _N
    assert inserts == 1, f"{_N} findings cost {inserts} INSERT round-trips on the replace path"
    assert len(get_significant_findings(SENTINEL_USER_ID, limit=_N + 10)) == _N


@pytest.mark.usefixtures("db")
def test_replacing_a_kind_with_nothing_still_clears_it() -> None:
    """The empty case: `executemany([])` writes nothing, and the DELETE must still run.

    A pattern that no longer reaches significance has to DISAPPEAR — leaving last
    night's row is stale advice presented as current, which is the failure the
    replace-don't-upsert contract exists for.
    """
    _reset()
    persist_findings(SENTINEL_USER_ID, [_finding(i, kind="personal_cutoff") for i in range(3)])
    assert get_significant_findings(SENTINEL_USER_ID), "nothing to clear — fixture is wrong"

    written = replace_findings_of_kind(SENTINEL_USER_ID, "personal_cutoff", [])

    assert written == 0
    assert not get_significant_findings(SENTINEL_USER_ID), (
        "a kind replaced with nothing kept its old rows — the DELETE did not run"
    )
