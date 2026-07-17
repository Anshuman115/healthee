"""The WP5-deferred coaching one-liners: /api/today action + /api/sleep tonight.

Both are generated through the choke point (stubbed) and cached per day; the read
endpoints carry the cached text (and ``None`` when cold — the read path never
generates, standards §Performance).

The generation happens in the nightly chain's ``warm`` step. That wiring is what these
tests exist for: the warmers shipped with **zero production callers**, so both lines
were `null` forever while every test here passed — because the tests called
`warm_daily_action` themselves, which is precisely what production did not do. So
`test_the_chain_warms_the_lines_...` drives `run_chain`, not the warmer: a test that
calls the warmer directly cannot see the bug it is supposed to catch.
"""

from __future__ import annotations

import sys
from collections.abc import Iterator
from pathlib import Path
from uuid import UUID

import pytest
from fastapi.testclient import TestClient
from tests.insights._stub import VALID_TEXT, StubLLM

from healthee.api.app import create_app
from healthee.core.config import get_settings
from healthee.core.db import tenant_transaction, transaction
from healthee.core.tenancy import SENTINEL_TZ, SENTINEL_USER_ID
from healthee.db import migrate
from healthee.insights import coaching, grounded
from healthee.insights.cache import get_cached, today_iso
from healthee.jobs import chain

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "analytics"))
import _seed_db as sd  # type: ignore[import-not-found]  # noqa: E402 — shared v2 seed helpers

pytestmark = pytest.mark.integration

_TOKEN = "coaching-test-token"
_AUTH = {"Authorization": f"Bearer {_TOKEN}"}


@pytest.fixture
def stub(monkeypatch: pytest.MonkeyPatch) -> Iterator[StubLLM]:
    client = StubLLM()
    monkeypatch.setattr(grounded, "get_client", lambda: client)
    monkeypatch.setenv("REALTIME_INGEST_TOKEN", _TOKEN)
    get_settings.cache_clear()
    yield client
    get_settings.cache_clear()


def _seed() -> None:
    migrate.apply_migrations()
    days = sd.recent_days(30)
    sd.clean("kv")
    with tenant_transaction(SENTINEL_USER_ID) as cur:
        sd.seed_daily(cur, "recovery_score", {d: 70.0 for d in days})
        sd.seed_daily(cur, "sleep_regularity_index", {d: 74.0 for d in days})


def test_today_action_is_none_when_cold_then_filled_after_warming(db: None, stub: StubLLM) -> None:  # noqa: ARG001
    _seed()
    api = TestClient(create_app())
    assert api.get("/api/today", headers=_AUTH).json()["action"] is None  # cold: no LLM
    assert stub.calls == 0
    warmed = coaching.warm_daily_action(
        SENTINEL_USER_ID, SENTINEL_TZ
    )  # off the read path, through the choke point
    assert warmed["text"] == VALID_TEXT
    assert api.get("/api/today", headers=_AUTH).json()["action"] == VALID_TEXT
    assert stub.calls == 1  # generated once; the read served it from cache


def test_sleep_tonight_line_fills_after_warming(db: None, stub: StubLLM) -> None:  # noqa: ARG001
    _seed()
    api = TestClient(create_app())
    consistency = api.get("/api/sleep/consistency", headers=_AUTH)
    assert consistency.json()["tonight"] is None
    coaching.warm_sleep_tonight(SENTINEL_USER_ID, SENTINEL_TZ)
    again = api.get("/api/sleep/consistency", headers=_AUTH)
    assert again.json()["tonight"] == VALID_TEXT


def test_the_chain_warms_the_lines_and_no_read_ever_generates(
    db: None,  # noqa: ARG001
    stub: StubLLM,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The real production path: the nightly chain warms, the read serves cache only.

    ``correlate`` is stubbed to a no-op — its dependency on ``warm`` is asserted in the
    control-flow suite, and this test's subject is the wiring (does the chain warm at
    all?) plus the read-path rule, not correlate's own analytics.
    """
    _seed()
    monkeypatch.setattr(chain, "step_correlate", lambda *a, **kw: {"ok": True})  # noqa: ARG005
    api = TestClient(create_app())
    assert api.get("/api/today", headers=_AUTH).json()["action"] is None  # cold
    assert stub.calls == 0

    result = chain.run_chain(SENTINEL_USER_ID, SENTINEL_TZ, client=stub, force=True)

    warm = next(step for step in result.steps if step.name == "warm")
    assert warm.status == "ok", warm.error
    assert warm.detail is not None
    assert warm.detail["warmed"] == sorted([coaching.DAILY_ACTION_KEY, coaching.SLEEP_TONIGHT_KEY])

    generated = stub.calls
    assert generated > 0
    assert api.get("/api/today", headers=_AUTH).json()["action"] == VALID_TEXT
    assert api.get("/api/sleep/consistency", headers=_AUTH).json()["tonight"] == VALID_TEXT
    # The rule the whole cache-only design exists for: the reads served the warmed
    # text without a single additional LLM call (standards §Performance).
    assert stub.calls == generated


# Two owners 25 hours apart (UTC+14 / UTC-11): at EVERY instant their local calendar
# dates differ, so "the owner's local day" and "the server's day" can never coincide
# for both — which is what makes the anchoring assertion below non-vacuous.
_EAST = UUID("0e510e51-0000-0000-0000-000000000001")
_EAST_TZ = "Pacific/Kiritimati"
_WEST = UUID("0e510e51-0000-0000-0000-000000000002")
_WEST_TZ = "Pacific/Midway"


def _provision(user_id: UUID, tz: str) -> None:
    """An owner row (identity is un-scoped by design — see seed_owner_b)."""
    with transaction() as cur:
        cur.execute(
            "INSERT INTO app_user (id, email, timezone) VALUES (%s, %s, %s) "
            "ON CONFLICT (id) DO UPDATE SET timezone = EXCLUDED.timezone",
            (user_id, f"{user_id}@example.test", tz),
        )


def test_warming_is_per_owner_and_anchored_to_that_owners_local_day(
    db: None,  # noqa: ARG001
    stub: StubLLM,
) -> None:
    _seed()
    _provision(_EAST, _EAST_TZ)
    _provision(_WEST, _WEST_TZ)
    try:
        coaching.warm_lines(_EAST, _EAST_TZ, client=stub)
        # Per-OWNER: warming EAST filled EAST's card and nobody else's. A warmer that
        # leaked across tenants would have handed WEST a line generated from EAST's data.
        assert get_cached(_EAST, _EAST_TZ, coaching.DAILY_ACTION_KEY) is not None
        assert get_cached(_WEST, _WEST_TZ, coaching.DAILY_ACTION_KEY) is None

        coaching.warm_lines(_WEST, _WEST_TZ, client=stub)
        east = get_cached(_EAST, _EAST_TZ, coaching.DAILY_ACTION_KEY)
        west = get_cached(_WEST, _WEST_TZ, coaching.DAILY_ACTION_KEY)
        assert east is not None and west is not None
        # Per-owner-local-DAY: each payload is stamped with ITS owner's today, and the
        # two are necessarily different dates — so a shared/server-day anchor fails here.
        assert east["date"] == today_iso(_EAST_TZ)
        assert west["date"] == today_iso(_WEST_TZ)
        assert east["date"] != west["date"]
    finally:
        for owner in (_EAST, _WEST):
            with tenant_transaction(owner) as cur:
                cur.execute("DELETE FROM kv WHERE user_id = %s", (owner,))
        with transaction() as cur:
            cur.execute("DELETE FROM app_user WHERE id IN (%s, %s)", (_EAST, _WEST))
